# Coopsave - Cooperative Savings Escrow 🗂️

A decentralized cooperative savings platform built on the Stacks blockchain using Clarity smart contracts. Coopsave enables groups to pool funds together with consensus-based release mechanisms, creating a secure and transparent savings escrow system.

## 🎯 Overview

Coopsave is a cooperative savings escrow system that allows groups of people to:
- Pool funds together in a shared escrow account
- Set consensus requirements for fund release
- Vote on withdrawal proposals with democratic decision-making
- Maintain transparent records of all transactions and votes
- Earn collective interest on pooled savings

## 🔧 Features

### Group Formation & Management
- **Dynamic Group Creation**: Anyone can create a savings group and invite members
- **Flexible Membership**: Support for groups of varying sizes (2-20 members)
- **Role Management**: Group creators act as administrators with special privileges
- **Member Verification**: Secure member onboarding and verification process

### Consensus-Based Fund Release
- **Democratic Voting**: All fund releases require group consensus through voting
- **Configurable Thresholds**: Groups can set their own consensus requirements (simple majority, supermajority, unanimity)
- **Proposal System**: Members can create withdrawal proposals with detailed descriptions
- **Time-Locked Voting**: Proposals have voting periods to ensure all members can participate

### Savings Management
- **Secure Escrow**: All funds are held in smart contract escrows with multi-signature requirements
- **Contribution Tracking**: Individual member contributions are tracked and recorded
- **Flexible Deposits**: Members can contribute varying amounts based on group rules
- **Emergency Withdrawals**: Mechanisms for emergency fund access with higher consensus requirements

## 🏗️ Architecture

The Coopsave system consists of two main smart contracts:

1. **Group Manager Contract** (`group-manager.clar`)
   - Manages group creation, membership, and configuration
   - Handles group settings and consensus thresholds
   - Tracks member roles and permissions

2. **Savings Escrow Contract** (`savings-escrow.clar`)
   - Manages fund deposits, storage, and withdrawals
   - Implements voting mechanisms for fund release
   - Handles proposal creation and consensus tracking
   - Executes approved withdrawals and distributions

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Node.js and npm
- Git
- Stacks wallet for interaction

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd coopsave
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Check contract syntax:
   ```bash
   clarinet check
   ```

4. Run tests:
   ```bash
   npm test
   ```

## 📋 Usage

### Creating a Savings Group
1. Call `create-group` function with group parameters
2. Set consensus threshold and voting period
3. Invite members to join the group

### Making Contributions
1. Members deposit STX tokens using `contribute-funds`
2. Contributions are recorded and escrowed
3. Individual balances are tracked within the group

### Proposing Withdrawals
1. Any member can create a withdrawal proposal
2. Specify amount, recipient, and purpose
3. Proposal enters voting period automatically

### Voting Process
1. All group members can vote on active proposals
2. Votes are recorded immutably on the blockchain
3. Proposals execute automatically when consensus is reached

## 🧪 Testing

The system includes comprehensive tests for:

```bash
clarinet test
npm test
```

- Group creation and management
- Member onboarding and verification
- Contribution tracking and validation
- Proposal creation and voting
- Consensus calculation and execution
- Emergency withdrawal scenarios

## 📄 Smart Contracts

- `contracts/group-manager.clar` - Group and membership management
- `contracts/savings-escrow.clar` - Funds and consensus management

## 🔐 Security Features

- **Multi-signature Requirements**: All major operations require consensus
- **Time-locked Operations**: Important actions have mandatory waiting periods
- **Immutable Records**: All transactions and votes are permanently recorded
- **Access Control**: Role-based permissions prevent unauthorized actions
- **Emergency Safeguards**: Built-in mechanisms for crisis situations

## 🎭 Use Cases

- **Family Savings**: Families can pool money for major purchases or emergencies
- **Friend Groups**: Groups of friends saving for vacations or shared experiences
- **Investment Clubs**: Small investment groups making collective decisions
- **Community Projects**: Local communities funding shared initiatives
- **Business Partnerships**: Partners managing shared business expenses

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests
5. Submit a pull request

## 📜 License

This project is open source and available under the MIT License.

## 🛡️ Disclaimer

This is experimental software. Users should understand the risks involved with smart contracts and only use funds they can afford to lose. Always test thoroughly on testnets before using with real funds.

---

*Built with ❤️ on the Stacks blockchain for transparent cooperative savings*
