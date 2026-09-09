# 00 - Hello Ethernaut

## Overview

- **Difficulty:** 0/10 (Tutorial)
- **Network:** Sepolia Testnet
- **Instance Address:** [`0xc3662ddbD8cFAbe3a557311EcF489CF0cD5E2bEd`](https://sepolia.etherscan.io/address/0xc3662ddbD8cFAbe3a557311EcF489CF0cD5E2bEd)
- **Completed Tx:** [`0x9433f397edb532f1b9603dac72ef73b4e1f8371ee7ad747484ba9c5cec0b8103`](https://sepolia.etherscan.io/tx/0x9433f397edb532f1b9603dac72ef73b4e1f8371ee7ad747484ba9c5cec0b8103)

---

## Objective

The goal of this introductory level is to get familiar with the Ethernaut game interface, interacting with smart contracts via the console or CLI, reading contract properties, and calling state-changing functions.

To complete this challenge:
1. Find the hidden password stored in the contract.
2. Call `authenticate(string passkey)` with the correct password.
3. Verify that `getCleared()` returns `true`.
4. Submit the instance back to Ethernaut.

---

## Contract Analysis

The contract source code is located at [`src/00-hello-ethernaut/HelloEthernaut.sol`](./HelloEthernaut.sol).

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Instance {
    string public password;
    uint8 public infoNum = 42;
    string public theMethodName = "The method name is method7123949.";
    bool private cleared = false;

    constructor(string memory _password) {
        password = _password;
    }

    function info() public pure returns (string memory) {
        return "You will find what you need in info1().";
    }

    function info1() public pure returns (string memory) {
        return 'Try info2(), but with "hello" as a parameter.';
    }

    function info2(string memory param) public pure returns (string memory) {
        if (keccak256(abi.encodePacked(param)) == keccak256(abi.encodePacked("hello"))) {
            return "The property infoNum holds the number of the next info method to call.";
        }
        return "Wrong parameter.";
    }

    function info42() public pure returns (string memory) {
        return "theMethodName is the name of the next method.";
    }

    function method7123949() public pure returns (string memory) {
        return "If you know the password, submit it to authenticate().";
    }

    function authenticate(string memory passkey) public {
        if (keccak256(abi.encodePacked(passkey)) == keccak256(abi.encodePacked(password))) {
            cleared = true;
        }
    }

    function getCleared() public view returns (bool) {
        return cleared;
    }
}
```

### Key Observations:
- **`password`**: Public state variable initialized in the constructor. Because it is `public`, Solidity automatically generates a getter function `password()`.
- **`cleared`**: Private boolean variable holding the completion status. It only flips to `true` when `authenticate(password)` is called with the matching passkey.
- **Breadcrumb trail**: The `info*()` helper functions guide the player through the contract's interface.

---

## Step-by-Step Solution

### 1. Follow the Breadcrumb Trail

Interacting through either the browser developer console or Foundry's `cast`:

1. Call `info()`:
   ```javascript
   await contract.info()
   // -> "You will find what you need in info1()."
   ```

2. Call `info1()`:
   ```javascript
   await contract.info1()
   // -> 'Try info2(), but with "hello" as a parameter.'
   ```

3. Call `info2("hello")`:
   ```javascript
   await contract.info2("hello")
   // -> "The property infoNum holds the number of the next info method to call."
   ```

4. Read `infoNum`:
   ```javascript
   await contract.infoNum()
   // -> 42
   ```

5. Call `info42()`:
   ```javascript
   await contract.info42()
   // -> "theMethodName is the name of the next method."
   ```

6. Read `theMethodName`:
   ```javascript
   await contract.theMethodName()
   // -> "The method name is method7123949."
   ```

7. Call `method7123949()`:
   ```javascript
   await contract.method7123949()
   // -> "If you know the password, submit it to authenticate()."
   ```

### 2. Retrieve the Password

Since `password` is declared as a `public` variable, call the auto-generated getter:

```javascript
await contract.password()
// -> Returns the stored password string (e.g. "ethernaut0")
```

> **Note:** Even if `password` was declared `private`, all data stored on Ethereum is publicly readable via storage slot inspection (e.g., using `cast storage <INSTANCE_ADDRESS> 0`).

### 3. Authenticate

Send the transaction with the retrieved password:

```javascript
await contract.authenticate(await contract.password())
```

### 4. Verify & Submit

Confirm that the challenge is cleared:

```javascript
await contract.getCleared()
// -> true
```

Finally, click **"Submit instance"** in the Ethernaut UI to claim completion!

---

## Solving via Foundry (`cast`)

You can also solve this entirely via the command line using Foundry's `cast`:

```bash
# 1. Read the password directly
cast call 0xc3662ddbD8cFAbe3a557311EcF489CF0cD5E2bEd "password()(string)" --rpc-url $SEPOLIA_RPC_URL

# 2. Authenticate with the password
cast send 0xc3662ddbD8cFAbe3a557311EcF489CF0cD5E2bEd "authenticate(string)" "<PASSWORD>" \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY

# 3. Check completion status
cast call 0xc3662ddbD8cFAbe3a557311EcF489CF0cD5E2bEd "getCleared()(bool)" --rpc-url $SEPOLIA_RPC_URL
# Output: true
```

---

## Key Security Takeaways

1. **Everything on Ethereum is Public:** Marking a variable `private` does not protect confidential data. It only prevents other smart contracts from reading it on-chain; anyone can inspect contract storage from off-chain.
2. **Public State Variables:** Public variables automatically receive compiler-generated getter functions with the same name.
3. **Strings & Hashes:** String comparison in Solidity is typically performed using `keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b))`, because Solidity cannot directly compare dynamically-sized string types using `==`.
