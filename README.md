# Community Governance DAO

A decentralized autonomous organization platform that enables communities to make collective decisions through transparent voting mechanisms. This project features proposal submission, stake-weighted voting, treasury management, and automated governance execution.

## 🏗️ Architecture Overview

The Community Governance DAO consists of two main smart contracts:

### 1. Governance Voting System (`governance-voting-system.clar`)
- **Proposal Management**: Handles community proposal submission and voting processes
- **Stake-Weighted Voting**: Implements voting mechanisms with delegation options
- **Automated Execution**: Processes governance proposal execution through smart contracts
- **Participation Records**: Maintains voting history and participation tracking
- **Audit Trails**: Provides transparent decision-making audit trails

### 2. Community Treasury Manager (`community-treasury-manager.clar`)
- **Multi-Signature Security**: Manages community treasury with enhanced security controls
- **Governance Integration**: Processes approved spending through governance proposals
- **Grant Distribution**: Handles community grants and funding allocation
- **Financial Reporting**: Maintains transparent budget tracking and reporting
- **Compliance Automation**: Ensures automated compliance with governance decisions

## 🚀 Key Features

- **Transparent Decision Making**: All proposals and votes are recorded on-chain
- **Stake-Weighted Governance**: Voting power proportional to community stake
- **Treasury Management**: Secure handling of community funds
- **Proposal Lifecycle**: Complete workflow from submission to execution
- **Delegation Support**: Members can delegate voting power
- **Multi-Signature Security**: Enhanced security for treasury operations
- **Automated Compliance**: Smart contract enforcement of governance rules

## 🛠️ Technology Stack

- **Blockchain**: Stacks Blockchain
- **Smart Contracts**: Clarity Language
- **Development Framework**: Clarinet
- **Testing**: Clarinet Test Suite

## 📋 Prerequisites

- [Clarinet](https://docs.hiro.so/clarinet) - Clarity smart contract development tool
- [Node.js](https://nodejs.org/) - JavaScript runtime
- [Git](https://git-scm.com/) - Version control

## 🏃‍♂️ Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/divinee947/community-governance-dao.git
   cd community-governance-dao
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Check contract syntax**
   ```bash
   clarinet check
   ```

4. **Run tests**
   ```bash
   clarinet test
   ```

5. **Deploy to devnet**
   ```bash
   clarinet integrate
   ```

## 📁 Project Structure

```
community-governance-dao/
├── contracts/
│   ├── governance-voting-system.clar    # Core voting and proposal logic
│   └── community-treasury-manager.clar  # Treasury and fund management
├── tests/
│   ├── governance-voting-system_test.ts
│   └── community-treasury-manager_test.ts
├── settings/
│   ├── Devnet.toml
│   ├── Testnet.toml
│   └── Mainnet.toml
├── Clarinet.toml                        # Project configuration
├── package.json                         # Node.js dependencies
└── README.md                           # This file
```

## 🔧 Configuration

The project uses Clarinet configuration files located in the `settings/` directory:

- **Devnet.toml**: Local development network settings
- **Testnet.toml**: Stacks testnet configuration
- **Mainnet.toml**: Production mainnet settings

## 🧪 Testing

Run the comprehensive test suite:

```bash
# Check syntax
clarinet check

# Run all tests
clarinet test

# Run specific test file
clarinet test tests/governance-voting-system_test.ts
```

## 📊 Contract Functions

### Governance Voting System
- `submit-proposal`: Submit new governance proposals
- `cast-vote`: Vote on active proposals
- `delegate-voting-power`: Delegate voting power to another member
- `execute-proposal`: Execute approved proposals
- `get-proposal`: Retrieve proposal details

### Community Treasury Manager
- `deposit-funds`: Add funds to community treasury
- `request-funds`: Request treasury funds through governance
- `execute-payment`: Process approved payments
- `get-treasury-balance`: Check current treasury balance
- `get-spending-history`: View transaction history

## 🔐 Security Features

- **Multi-signature requirements** for treasury operations
- **Stake-weighted voting** prevents manipulation
- **Time-locked proposals** allow proper review periods
- **Automated execution** reduces human error
- **Transparent audit trails** for all operations

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass (`clarinet check && clarinet test`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## 📜 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 📞 Support

For questions and support, please open an issue in the GitHub repository.

## 🔗 Links

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Language Reference](https://docs.stacks.co/clarity)
- [Clarinet Documentation](https://docs.hiro.so/clarinet)
- [Community Discord](#) (Add your community link)

---

Built with ❤️ by the Community Governance DAO Team
