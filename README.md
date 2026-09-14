# 🚩 Ethernaut Challenges Solutions & Writeups

Solutions and writeups for [OpenZeppelin's Ethernaut](https://ethernaut.openzeppelin.com/) smart contract security challenges, implemented and tested using **Foundry**.

- **Player Address:** [`0xf511E1029dE5295f6D0dE05f4431DdA203e63607`](https://sepolia.etherscan.io/address/0xf511E1029dE5295f6D0dE05f4431DdA203e63607)
- **Network:** Sepolia Testnet

Each completed challenge is documented with the target smart contract, an in-depth writeup explaining the vulnerability and exploit mechanics, and verifiable on-chain proof of completion.

## 📊 Completed Challenges

| # | Challenge | Status | Writeup | Instance Address | Proof (Sepolia Tx) |
|---|-----------|:------:|:-------:|:----------------:|:------------------:|
| 00 | [Hello Ethernaut](https://ethernaut.openzeppelin.com/level/0) | Completed ✅ | [Writeup](src/00-hello-ethernaut/README.md) | [`0xc366...2bEd`](https://sepolia.etherscan.io/address/0xc3662ddbD8cFAbe3a557311EcF489CF0cD5E2bEd) | [Sepolia Tx](https://sepolia.etherscan.io/tx/0x9433f397edb532f1b9603dac72ef73b4e1f8371ee7ad747484ba9c5cec0b8103) |
| 01 | [Fallback](https://ethernaut.openzeppelin.com/level/1) | Completed ✅ | [Writeup](src/01-fallback/README.md) | [`0xAcF3...3979`](https://sepolia.etherscan.io/address/0xAcF384d2700663050622313970Ef853e99A43979) | [Sepolia Tx](https://sepolia.etherscan.io/tx/0xf425febbc049817be1c7ac5ec53ea004f8ac87407611f0ff50643eeb0c169650) |
| 02 | [Fallout](https://ethernaut.openzeppelin.com/level/2) | Completed ✅ | [Writeup](src/02-fallout/README.md) | [`0x3cdd...3b31`](https://sepolia.etherscan.io/address/0x3cdd4575f0ff0948c6cdcc7ffcb573e832733b31) | [Sepolia Tx](https://sepolia.etherscan.io/tx/0xbdd20cd7b59cd49b05c21da737caf1eab1d8bd4cd377f53943505146890d6cc4) |
| 03 | [Coin Flip](https://ethernaut.openzeppelin.com/level/3) | Completed ✅ | [Writeup](src/03-coin-flip/README.md) | [`0xDDd8...bd8A`](https://sepolia.etherscan.io/address/0xDDd84EA1C0e72dca7Bc6146FE2e33fA62dC7bd8A) | [Sepolia Tx](https://sepolia.etherscan.io/tx/0x42a159f442411137da8d2d6105726e7b438447f2fe0d2d8fd385c0af41d062da) |
| 04 | [Telephone](https://ethernaut.openzeppelin.com/level/4) | Completed ✅ | [Writeup](src/04-Telephone/README.md) | [`0x1cac...f11f`](https://sepolia.etherscan.io/address/0x1cac52d22f9fe803fed16f1cc513dec729b3f11f) | [Sepolia Tx](https://sepolia.etherscan.io/tx/0xf23b4902060f55910c8591938d1707e328a8795ebb68c25ab8ec3ad49db43ddc) |

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
