# 🚩 Ethernaut Challenges Solutions & Writeups

Solutions and writeups for [OpenZeppelin's Ethernaut](https://ethernaut.openzeppelin.com/) smart contract security challenges, implemented and tested using **Foundry**.

- **Player Address:** [`0xf511E1029dE5295f6D0dE05f4431DdA203e63607`](https://sepolia.etherscan.io/address/0xf511E1029dE5295f6D0dE05f4431DdA203e63607)
- **Network:** Sepolia Testnet

Each completed challenge is documented with the target smart contract, an in-depth writeup explaining the vulnerability and exploit mechanics, and verifiable on-chain proof of completion.

## 📊 Completed Challenges

| # | Challenge | Objective | Status | Writeup | Instance Address | Proof (Sepolia Tx) |
|---|-----------|-----------|:------:|:-------:|:----------------:|:------------------:|
| 00 | [Hello Ethernaut](https://ethernaut.openzeppelin.com/level/0) | Find the password & authenticate to clear the level | Completed ✅ | [Writeup](src/00-hello-ethernaut/README.md) | [`0xc366...2bEd`](https://sepolia.etherscan.io/address/0xc3662ddbD8cFAbe3a557311EcF489CF0cD5E2bEd) | [Sepolia Tx](https://sepolia.etherscan.io/tx/0x9433f397edb532f1b9603dac72ef73b4e1f8371ee7ad747484ba9c5cec0b8103) |
| 01 | [Fallback](https://ethernaut.openzeppelin.com/level/1) | Claim ownership & reduce contract balance to 0 | Completed ✅ | [Writeup](src/01-fallback/README.md) | [`0xAcF3...3979`](https://sepolia.etherscan.io/address/0xAcF384d2700663050622313970Ef853e99A43979) | [Sepolia Tx](https://sepolia.etherscan.io/tx/0xf425febbc049817be1c7ac5ec53ea004f8ac87407611f0ff50643eeb0c169650) |
| 02 | [Fallout](https://ethernaut.openzeppelin.com/level/2) | Claim ownership of the contract | Completed ✅ | [Writeup](src/02-fallout/README.md) | [`0x3cdd...3b31`](https://sepolia.etherscan.io/address/0x3cdd4575f0ff0948c6cdcc7ffcb573e832733b31) | [Sepolia Tx](https://sepolia.etherscan.io/tx/0xbdd20cd7b59cd49b05c21da737caf1eab1d8bd4cd377f53943505146890d6cc4) |
| 03 | [Coin Flip](https://ethernaut.openzeppelin.com/level/3) | Guess the coin flip outcome 10 consecutive times | Completed ✅ | [Writeup](src/03-coin-flip/README.md) | [`0xDDd8...bd8A`](https://sepolia.etherscan.io/address/0xDDd84EA1C0e72dca7Bc6146FE2e33fA62dC7bd8A) | [Sepolia Tx](https://sepolia.etherscan.io/tx/0x42a159f442411137da8d2d6105726e7b438447f2fe0d2d8fd385c0af41d062da) |
| 04 | [Telephone](https://ethernaut.openzeppelin.com/level/4) | Claim ownership of the contract | Completed ✅ | [Writeup](src/04-Telephone/README.md) | [`0x1cac...f11f`](https://sepolia.etherscan.io/address/0x1cac52d22f9fe803fed16f1cc513dec729b3f11f) | [Sepolia Tx](https://sepolia.etherscan.io/tx/0xf23b4902060f55910c8591938d1707e328a8795ebb68c25ab8ec3ad49db43ddc) |
| 05 | [Token](https://ethernaut.openzeppelin.com/level/5) | Hack token balance to acquire extra tokens | Completed ✅ | [Writeup](src/05-Token/README.md) | [`0x804c...caFC`](https://sepolia.etherscan.io/address/0x804ceF2ba55E1219D6F4D9c34e648A195a86caFC) | [Sepolia Tx](https://sepolia.etherscan.io/tx/0xb78ae9d6452149c6a5b148d6cbdd4da35d7a0cc73ce705b659a844a7331f2ce5) |
| 06 | [Delegation](https://ethernaut.openzeppelin.com/level/6) | Claim ownership of the delegation instance | Completed ✅ | [Writeup](src/06-delegation/README.md) | [`0x836a...5750`](https://sepolia.etherscan.io/address/0x836a094abf84924E15154b04de5845Fd2ecd5750) | [Sepolia Tx](https://sepolia.etherscan.io/tx/0x1b12ec4f45a13f1c99de631fb91820ea084a16757ae7e85abb45d7dee49454a0) |
| 07 | [Force](https://ethernaut.openzeppelin.com/level/7) | Make contract balance greater than 0 | Completed ✅ | [Writeup](src/07-force/README.md) | [`0xc5b7...bb20`](https://sepolia.etherscan.io/address/0xc5b7386b3629201ad080bf05d5eeb34724bebb20) | [Sepolia Tx](https://sepolia.etherscan.io/tx/0x2dbe6ee5896a17805b99d707af0bbc937d24c4d52f7c9d28d452eac0841b1055) |
| 08 | [Vault](https://ethernaut.openzeppelin.com/level/8) | Unlock the vault by setting locked to false | Completed ✅ | [Writeup](src/08-vault/README.md) | [`0xe1a0...ce85`](https://sepolia.etherscan.io/address/0xe1a0354874905f90c0dc99d60ad321ae291fce85) | [Sepolia Tx](https://sepolia.etherscan.io/tx/0x4e95fa4c561a59e25bec6f86e42d9ce14a6f63a98c8c30c21ac94e2a059e337f) |
| 09 | [King](https://ethernaut.openzeppelin.com/level/9) | Prevent the level from reclaiming kingship | Completed ✅ | [Writeup](src/09-king/README.md) | [`0x3595...1B6f`](https://sepolia.etherscan.io/address/0x3595bb7e136B61aD00B2aB92CA75bE23D1b41B6f) | [Sepolia Tx](https://sepolia.etherscan.io/tx/0xf8a68b9dc481619e2a59e1be05f0686d44431b62ed6845668e177a21215d8347) |
| 10 | [Re-entrancy](https://ethernaut.openzeppelin.com/level/10) | Drain all funds from the contract | Completed ✅ | [Writeup](src/10-re-entrancy/README.md) | [`0x39fd...0220`](https://sepolia.etherscan.io/address/0x39fd8a00708ff6b6fc48e1c4971aeb46a2a00220) | [Sepolia Tx](https://sepolia.etherscan.io/tx/0x97a1f08e25bc0e56e700fbe10e7e206db913a2a43af7b67eeadf14d0abd76b51) |
| 11 | [Elevator](https://ethernaut.openzeppelin.com/level/11) | Reach the top of the building (set top to true) | Completed ✅ | [Writeup](src/11-elevator/README.md) | [`0x3A97...f27B`](https://sepolia.etherscan.io/address/0x3A972992078d0F3994b2deade57Aa99198AAf27B) | [Sepolia Tx](https://sepolia.etherscan.io/tx/0x609a6e2f08cf37bdbef576003649dd75b14e8c1675bbd44dff2c310aa5f5bb91) |
| 12 | [Privacy](https://ethernaut.openzeppelin.com/level/12) | Unlock the contract by setting locked to false | Completed ✅ | [Writeup](src/12-privacy/README.md) | [`0x4dd4...517D`](https://sepolia.etherscan.io/address/0x4dd4d658B208Bf93945e3b4D8b681EE54557517D) | [Sepolia Tx](https://sepolia.etherscan.io/tx/0x204d8d1789dc786550927cf8bdbe1996584dbab40256812002dbd05c335da4f6) |
| 13 | [Gatekeeper One](https://ethernaut.openzeppelin.com/level/13) | Bypass all 3 gates and register as entrant | Completed ✅ | [Writeup](src/13-gatekeeper-one/README.md) | [`0x8187...09c0`](https://sepolia.etherscan.io/address/0x818790ee6d5472c61178c2a9d312f8383b6e09c0) | [Sepolia Tx](https://sepolia.etherscan.io/tx/0xf8702032241225daa106b9ae188d00dff914af365acfda2af22118662054d828) |
| 14 | [Gatekeeper Two](https://ethernaut.openzeppelin.com/level/14) | Bypass all 3 gates and register as entrant | Completed ✅ | [Writeup](src/14-gatekeeper-two/README.md) | [`0x76A2...90a5`](https://sepolia.etherscan.io/address/0x76A2C8F1E53a53b42Db2E8F01C492C095A3D90a5) | [Sepolia Tx](https://sepolia.etherscan.io/tx/0x4d893ab445749002e4e0eabd9c11322ccbc307cb8aa415d74b4d82d2073381b8) |

---

## 📁 Repository Structure

```text
├── src/
│   ├── 00-hello-ethernaut/
│   │   ├── HelloEthernaut.sol  # Challenge contract
│   │   └── README.md           # Detailed writeup & solution
│   ├── 01-fallback/
│   │   ├── Fallback.sol        # Challenge contract
│   │   └── README.md           # Detailed writeup & solution
│   ├── ...                     # Subsequent challenges follow the same pattern
│   └── helpers/                # Shared helper libraries (e.g., SafeMath)
├── script/                     # Foundry deployment & attack scripts
├── test/                       # Foundry tests simulating exploits locally
└── foundry.toml                # Foundry configuration
```

---

## 🛠️ Getting Started with Foundry

### Prerequisites

Ensure you have [Foundry](https://book.getfoundry.sh/getting-started/installation) installed:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Build

```bash
forge build
```

### Test

```bash
forge test -vvvv
```

---

## 📜 Disclaimer

These solutions and writeups are intended solely for educational purposes and learning EVM / smart contract security concepts.
