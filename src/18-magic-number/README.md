# 18 - MagicNumber

## Overview

- **Difficulty:** 9/10
- **Network:** Sepolia Testnet
- **Instance Address:** [`0x5D62335E8A64519257277C8675d952140F5b39E5`](https://sepolia.etherscan.io/address/0x5D62335E8A64519257277C8675d952140F5b39E5)
- **Solver Contract:** [`0x6069abafb63a5198dedfc8f3d2df96d534adf195`](https://sepolia.etherscan.io/address/0x6069abafb63a5198dedfc8f3d2df96d534adf195)
- **Transactions:**
  - **1. Deploy Raw Bytecode Solver:** [`0xfb4286ea2138fd93a29bf08ab56e10d4d7514afc757e5ced8840a64741939d41`](https://sepolia.etherscan.io/tx/0xfb4286ea2138fd93a29bf08ab56e10d4d7514afc757e5ced8840a64741939d41)
  - **2. Register Solver (`setSolver()`):** [`0x14ed53886396e5359d8c07fb06119f0f9323bab1bf66c52efa497202f12bef50`](https://sepolia.etherscan.io/tx/0x14ed53886396e5359d8c07fb06119f0f9323bab1bf66c52efa497202f12bef50)
  - **3. Level Submission:** [`0xaaa7c64cbc5d30e5c42e3d55313c068810e261e7d40593a1855acd355dc2cbd5`](https://sepolia.etherscan.io/tx/0xaaa7c64cbc5d30e5c42e3d55313c068810e261e7d40593a1855acd355dc2cbd5)

---

## Objective

To complete the level, we must deploy a `Solver` contract and provide its address to `MagicNum.setSolver(address)`.

The solver must satisfy two strict conditions:

1. When `whatIsTheMeaningOfLife()` is invoked on the solver, it must return `42` (`0x2a`).
2. The deployed solver's **runtime bytecode size must be at most 10 bytes** (`size <= 10`).

---

## Contract Analysis

The target contract is located in [`src/18-magic-number/MagicNum.sol`](./MagicNum.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MagicNum {
    address public solver;

    constructor() {}

    function setSolver(address _solver) public {
        solver = _solver;
    }
}
```

### Why Standard Solidity Fails

If we write a normal Solidity contract:

```solidity
contract Solver {
    function whatIsTheMeaningOfLife() external pure returns (uint256) {
        return 42;
    }
}
```

The Solidity compiler outputs over **100+ bytes** of runtime bytecode due to mandatory language boilerplate:

- Memory pointer initialization (`0x80` to memory position `0x40`).
- Function selector dispatch logic (calldata sizing and selector switching).
- Revert handling and panic codes.
- CBOR auxiliary metadata appended to the end of the bytecode.

Because the runtime code must be $\le 10$ bytes, writing high-level Solidity is impossible. We must drop down to **raw EVM opcodes and bytecode**.

---

## EVM Mechanics: Designing the Solver

### Part 1: The 10-Byte Runtime Code

The solver contract does not need to validate function selectors or calldata length. By unconditionally writing `42` (`0x2a`) to memory and returning 32 bytes, the contract will satisfy any caller, including `whatIsTheMeaningOfLife()`.

To return a value in the EVM:

1. Store `42` (`0x2a`) in memory at offset `0x00` using `MSTORE`.
2. Return 32 bytes (`0x20`) from memory offset `0x00` using `RETURN`.

| Opcode       | Hex     | Stack (top $\to$ bottom) | Description                          |
| :----------- | :------ | :----------------------- | :----------------------------------- |
| `PUSH1 0x2a` | `60 2a` | `[0x2a]`                 | Push 42                              |
| `PUSH1 0x00` | `60 00` | `[0x00, 0x2a]`           | Push memory offset 0                 |
| `MSTORE`     | `52`    | `[]`                     | Memory[0x00..0x20] = `0x2a`          |
| `PUSH1 0x20` | `60 20` | `[0x20]`                 | Push return size (32 bytes)          |
| `PUSH1 0x00` | `60 00` | `[0x00, 0x20]`           | Push memory offset 0                 |
| `RETURN`     | `f3`    | `[]`                     | Return 32 bytes from memory offset 0 |

**Runtime Bytecode:**

```text
60 2a 60 00 52 60 20 60 00 f3  (Exactly 10 bytes!)
```

---

### Part 2: Creation (Initialization) Code

When deploying a contract via a standard deployment transaction (`CREATE`), the EVM does **not** store the transaction data directly as runtime code. Instead:

1. The EVM executes the transaction's payload as **Initialization Code** (the constructor).
2. The initialization code loads the desired runtime bytecode into memory and executes `RETURN(offset, size)`.
3. The returned memory slice is stored on-chain at the newly created contract address.

#### The `PUSH10` + `MSTORE` Technique

While the traditional approach uses `CODECOPY`, we can construct a minimal deployment payload using `PUSH10` and `MSTORE`:

1. **`PUSH10 602a60005260206000f3` (`69 602a60005260206000f3`)**:
   - Pushes the 10 runtime bytes onto the stack as a 32-byte unsigned integer.
   - In EVM words, numeric literals are right-aligned (occupying the lowest 10 bytes):
     ```text
     0x0000000000000000000000000000000000000000000000602a60005260206000f3
     ```
2. **`PUSH1 0x00` (`60 00`) & `MSTORE` (`52`)**:
   - Stores the 32-byte word starting at memory offset `0x00`.
   - Offsets `0x00` to `0x15` (22 bytes, where $22 = 32 - 10$) contain zeroes: `0x00...00`.
   - Offsets `0x16` to `0x1f` (10 bytes) contain our runtime code: `602a60005260206000f3`.
3. **`PUSH1 0x0a` (`60 0a`)**:
   - Pushes the return size: `10` bytes (`0x0a`).
4. **`PUSH1 0x16` (`60 16`)**:
   - Pushes the memory offset: `22` bytes (`0x16`), pointing directly to where the 10 runtime bytes begin.
5. **`RETURN` (`f3`)**:
   - Stack layout: `[offset (0x16), size (0x0a)]`.
   - Returns the 10 bytes from memory to the EVM to deploy as the contract's runtime bytecode.

#### Complete Bytecode Breakdown

```text
[ Initialization Code ]
69 602a60005260206000f3   ; PUSH10 (10-byte runtime code)
60 00                     ; PUSH1 0x00
52                        ; MSTORE (writes to memory offset 0x00)
60 0a                     ; PUSH1 0x0a (size: 10 bytes)
60 16                     ; PUSH1 0x16 (offset: 22 / 0x16)
f3                        ; RETURN (deploy runtime code)

Full Bytecode: 0x69602a60005260206000f3600052600a6016f3
```

---

## Step-by-Step Exploit Walkthrough

### 1. Deploy the Solver Contract

Deploy the raw bytecode directly using `cast send --create`.

> [!IMPORTANT]
> Flags such as `--rpc-url` and `--account` must be placed **before** `--create` so Foundry's CLI parser recognizes them as options rather than function arguments.

```bash
cast send --rpc-url sepolia --account <ACCOUNT_NAME> \
  --create 0x69602a60005260206000f3600052600a6016f3
```

- **Deploy Tx:** [`0xfb4286ea2138fd93a29bf08ab56e10d4d7514afc757e5ced8840a64741939d41`](https://sepolia.etherscan.io/tx/0xfb4286ea2138fd93a29bf08ab56e10d4d7514afc757e5ced8840a64741939d41)
- **Deployed Solver Address:** [`0x6069abafb63a5198dedfc8f3d2df96d534adf195`](https://sepolia.etherscan.io/address/0x6069abafb63a5198dedfc8f3d2df96d534adf195)

### 2. Verify Solver Contract Properties

Verify the deployed contract bytecode size is exactly 10 bytes:

```bash
cast codesize 0x6069aBafB63a5198dEDfC8F3D2Df96D534ADf195 --rpc-url sepolia
# Output: 10
```

Verify that calling the contract returns `42` (`0x2a`):

```bash
cast call 0x6069aBafB63a5198dEDfC8F3D2Df96D534ADf195 "whatIsTheMeaningOfLife()(uint256)" --rpc-url sepolia
# Output: 42
```

### 3. Register the Solver in `MagicNum`

Call `setSolver(address)` on the `MagicNum` contract instance:

```bash
cast send 0x5D62335E8A64519257277C8675d952140F5b39E5 \
  "setSolver(address)" 0x6069aBafB63a5198dEDfC8F3D2Df96D534ADf195 \
  --rpc-url sepolia \
  --account <ACCOUNT_NAME>
```

- **Tx Hash:** [`0x14ed53886396e5359d8c07fb06119f0f9323bab1bf66c52efa497202f12bef50`](https://sepolia.etherscan.io/tx/0x14ed53886396e5359d8c07fb06119f0f9323bab1bf66c52efa497202f12bef50)

Confirm `solver` state variable is updated:

```bash
cast call 0x5D62335E8A64519257277C8675d952140F5b39E5 "solver()(address)" --rpc-url sepolia
# Output: 0x6069aBafB63a5198dEDfC8F3D2Df96D534ADf195
```

### 4. Submit Level

Submit the level on the Ethernaut dashboard:

- **Submission Tx:** [`0xaaa7c64cbc5d30e5c42e3d55313c068810e261e7d40593a1855acd355dc2cbd5`](https://sepolia.etherscan.io/tx/0xaaa7c64cbc5d30e5c42e3d55313c068810e261e7d40593a1855acd355dc2cbd5)

---

## Key Security & EVM Takeaways

1. **Separation of Creation vs. Runtime Bytecode:**
   Understanding that a deployment transaction executes initialization bytecode to produce and return runtime bytecode is fundamental to understanding EVM architecture, proxy deployments, and factory patterns.
2. **Solidity Compiler Overhead:**
   High-level Solidity adds significant infrastructure (dispatch tables, free memory pointers, safety reverts, metadata hashes). For extreme gas optimization or size-constrained code, raw Yul or EVM opcodes provide total control over execution.
3. **Omitting Function Selectors:**
   If a contract only needs to serve a single purpose or return a constant response, omitting the 4-byte selector check and fallback routing saves execution gas and contract code size.
