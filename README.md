# 🚩 Ethernaut Challenges Solutions & Writeups

Solutions and writeups for [OpenZeppelin's Ethernaut](https://ethernaut.openzeppelin.com/) smart contract security challenges, implemented and tested using **Foundry**.

Each completed challenge is documented with the target smart contract, an in-depth writeup explaining the vulnerability and exploit mechanics, and verifiable on-chain proof of completion.

## 📊 Completed Challenges

| # | Challenge | Status | Writeup | Instance Address | Proof (Sepolia Tx) |
|---|-----------|:------:|:-------:|:----------------:|:------------------:|
| 01 | [Hello Ethernaut](https://ethernaut.openzeppelin.com/level/0) | Completed ✅ | [Writeup](src/01-hello-ethernaut/README.md) | [`0xc366...2bEd`](https://sepolia.etherscan.io/address/0xc3662ddbD8cFAbe3a557311EcF489CF0cD5E2bEd) | [Sepolia Tx](https://sepolia.etherscan.io/tx/0x9433f397edb532f1b9603dac72ef73b4e1f8371ee7ad747484ba9c5cec0b8103) |

---

## 📁 Repository Structure

```text
├── src/
│   └── 01-hello-ethernaut/
│       ├── HelloEthernaut.sol  # Challenge contract
│       └── README.md           # Detailed writeup & solution
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
