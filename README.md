# 🐄 Livestock DAO for Nomadic Communities

A decentralized solution for livestock ownership registration and insurance for nomadic communities.

## 🎯 Features

- 🏷️ CowCoin: Tokenized livestock asset registry
- 📝 Smart contracts for livestock trading and ownership transfer
- 🏥 Veterinary claims management
- 💰 Insurance pools with staking mechanism

## 🚀 Getting Started

### Prerequisites

- Clarinet
- Stacks wallet

### Contract Functions

1. Register Livestock
```clarity
(contract-call? .livestock-dao register-livestock "cow" u24)
```

2. Transfer Livestock
```clarity
(contract-call? .livestock-dao transfer-livestock u1 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

3. Create Insurance Pool
```clarity
(contract-call? .livestock-dao create-insurance-pool)
```

4. Stake in Pool
```clarity
(contract-call? .livestock-dao stake-in-pool u1 u50)
```

5. Submit Vet Claim
```clarity
(contract-call? .livestock-dao submit-vet-claim u1 "vaccination" u100)
```

## 📖 Usage

1. Register your livestock to receive CowCoin tokens
2. Use CowCoins to participate in insurance pools
3. Transfer livestock ownership securely
4. Submit and track veterinary claims

## 🤝 Contributing

Pull requests are welcome! For major changes, please open an issue first.
```

Git commit message:
```
feat: implement livestock DAO MVP with ownership registry and insurance pools
```

PR Title:
```
🐄 Add Livestock DAO smart contract MVP
```

PR Description:
```
This PR implements the core functionality for the Livestock DAO:

- CowCoin fungible token implementation
- Livestock registration and ownership transfer
- Insurance pool creation and staking
- Veterinary claims management

The MVP provides the basic infrastructure needed for nomadic communities to:
1. Register and transfer livestock ownership
2. Participate in decentralized insurance pools
3. Submit and track veterinary claims

All core functions have been tested and are ready for review.

