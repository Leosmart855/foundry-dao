
---

#  DAO Governance System

A production-ready DAO governance system built with Foundry. This project implements a complete on-chain governance system with ERC20Votes token, Timelock controller, and Governor contract for decentralized decision-making.

##  Table of Contents

- Overview
- Features
- Deployments
- Getting Started
- Smart Contracts
- Governance Flow
- Testing
- Deployment
- Versioning
- Future Improvements
- License

---

## 📖 Overview

This DAO system allows token holders to propose, vote on, and execute changes to the protocol. All governance actions are subject to a timelock delay, providing security and transparency.

##  Features

- **ERC20Votes Governance Token (GVT)**
  - 1,000,000 total supply
  - Delegated voting power
  - Snapshot-based voting

- **Timelock Controller**
  - 1 hour delay on Sepolia
  - PROPOSER_ROLE for Governor
  - EXECUTOR_ROLE for anyone

- **Governor Contract**
  - Proposal creation
  - Voting with quorum (10%)
  - Execute proposal (manual)
  - 300 block voting delay (~1 hour)

- **Executable Actions**
  - Store numbers
  - Change name
  - Change treasury
  - Pause/unpause
  - Grant/revoke allowances
  - Withdraw funds
  - Execute arbitrary transactions

##  Deployments

### Sepolia Testnet

| Contract       | Address                                      | Etherscan                                                                               |
| -------------- | -------------------------------------------- | --------------------------------------------------------------------------------------- |
| **GovToken**   | `0x48fD2AF1fD8d547A87b73Fc0E1D79bEF53D7d33f` | [View](https://sepolia.etherscan.io/address/0x48fD2AF1fD8d547A87b73Fc0E1D79bEF53D7d33f) |
| **TimeLock**   | `0x9DF77C58b60691ABa44cBDFc7EBD8D3770D76732` | [View](https://sepolia.etherscan.io/address/0x9DF77C58b60691ABa44cBDFc7EBD8D3770D76732) |
| **MyGovernor** | `0xE13C7262b2C959C78C188784AA3B753035AE09f1` | [View](https://sepolia.etherscan.io/address/0xE13C7262b2C959C78C188784AA3B753035AE09f1) |
| **Box**        | `0xc14011A22F93a6C8Be419356196bD90F14bB7c7D` | [View](https://sepolia.etherscan.io/address/0xc14011A22F93a6C8Be419356196bD90F14bB7c7D) |

### Configuration

| Parameter     | Sepolia                 | Mainnet (Planned)        |
| ------------- | ----------------------- | ------------------------ |
| Min Delay     | 3600 seconds (1 hour)   | 86400 seconds (24 hours) |
| Voting Delay  | 300 blocks (~1 hour)    | 7200 blocks (~1 day)     |
| Voting Period | 750 blocks (~2.5 hours) | 50400 blocks (1 week)    |
| Quorum        | 10%                     | 10%                      |
| Token Supply  | 1,000,000 GVT           | 1,000,000 GVT            |

##  Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js (for dependencies)
- Sepolia ETH (for testnet deployment)

### Installation

```bash
# Clone the repository
git clone <repo-url>
cd <project-directory>

# Install dependencies
forge install

# Build the contracts
forge build

# Run tests
forge test
```

### Environment Setup

Create a `.env` file:

```bash
# RPC URLs
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2

# Private Key (best to use foundry keystore)
PRIVATE_KEY=your_private_key_here

# Etherscan API Key
ETHERSCAN_API_KEY=your_etherscan_api_key_here

# Wallet Address
SEPOLIA_WALLET_ADDRESS=0xYourWalletAddress
MAINNET_WALLET_ADDRESS=0xYourWalletAddress
```

##  Smart Contracts

### GovToken.sol
ERC20 token with voting capabilities (ERC20Votes). Users hold and delegate GVT tokens to gain voting power.

**Key Functions:**
- `delegate(address)` - Delegate votes to an address
- `getVotes(address)` - Get current voting power
- `balanceOf(address)` - Get token balance

### TimeLock.sol
Timelock controller that delays execution of governance actions. Extends OpenZeppelin's TimelockController.

**Key Functions:**
- `schedule()` - Schedule an operation
- `execute()` - Execute a scheduled operation
- `getMinDelay()` - Get minimum delay

### MyGovernor.sol
Main governance contract handling proposals, voting, and execution.

**Key Functions:**
- `propose()` - Create a new proposal
- `castVote()` - Vote on a proposal
- `queue()` - Queue a successful proposal
- `execute()` - Execute a queued proposal
- `state()` - Get proposal state

### Box.sol
Executable contract controlled by governance. All state-changing functions are protected by `onlyOwner`.

**Key Functions:**
- `storeNumber()` - Store a number
- `changeName()` - Change contract name
- `changeTreasury()` - Change treasury address
- `pause()` - Pause the contract
- `executeTransaction()` - Execute arbitrary transactions


##  Governance Flow (Sepolia Testnet)

### Step 1: Delegate Votes (REQUIRED!)
```bash
# You must delegate to yourself before you can vote
cast send $GOV_TOKEN "delegate(address)" $YOUR_ADDRESS \
    --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

### Step 2: Check Voting Power
```bash
cast call $GOV_TOKEN "getVotes(address)(uint256)" $YOUR_ADDRESS \
    --rpc-url $SEPOLIA_RPC_URL
# Should show your voting power (1,000,000 GVT if you're the deployer)
```

### Step 3: Create a Proposal
```bash
cast send $GOVERNOR "propose(address[],uint256[],bytes[],string)" \
    "[$BOX]" "[0]" "[$(cast calldata "storeNumber(uint256)" 123)]" "Store 123 in Box" \
    --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

### Step 4: Get Proposal ID
```bash
# Extract the proposal ID from the proposal transaction hash
PROPOSAL_ID=$(cast receipt $TX_HASH --rpc-url $SEPOLIA_RPC_URL --json | jq -r '.logs[0].data' | cut -c 3-66 | xargs cast to-dec)
echo "Proposal ID: $PROPOSAL_ID"
```

### Step 5: Start Voting (After ~1 Hour)
```bash
# Voting delay is 300 blocks (~1 hour on Sepolia)
# Wait 1 hour, then check state
cast call $GOVERNOR "state(uint256)(uint8)" $PROPOSAL_ID --rpc-url $SEPOLIA_RPC_URL
# Should return: 1 (Active)
```

### Step 6: Vote
```bash
cast send $GOVERNOR "castVote(uint256,uint8)" $PROPOSAL_ID 1 \
    --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

### Step 7: Wait for Voting Period (~2.5 Hours)
```bash
# Voting period is 750 blocks (~2.5 hours on Sepolia)
# Wait 2.5 hours, then check state
cast call $GOVERNOR "state(uint256)(uint8)" $PROPOSAL_ID --rpc-url $SEPOLIA_RPC_URL
# Should return: 4 (Succeeded)
```

### Step 8: Queue the Proposal
```bash
cast send $GOVERNOR "queue(address[],uint256[],bytes[],bytes32)" \
    "[$BOX]" "[0]" "[$(cast calldata "storeNumber(uint256)" 123)]" "$(cast keccak "Store 123 in Box")" \
    --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

### Step 9: Wait for Timelock (1 Hour)
```bash
# Min delay is 3600 seconds (1 hour on Sepolia)
# Wait 1 hour, then execute
```

### Step 10: Execute the Proposal
```bash
cast send $GOVERNOR "execute(address[],uint256[],bytes[],bytes32)" \
    "[$BOX]" "[0]" "[$DATA]" "$DESCRIPTION_HASH" \
    --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

### Step 11: Verify
```bash
cast call $BOX "getNumber()" --rpc-url $SEPOLIA_RPC_URL
# Should return: 123
```

## View on Etherscan

```bash
# Open the Governor contract on Sepolia
open "https://sepolia.etherscan.io/address/$GOVERNOR"

# Look for the ProposalCreated event to see your proposal
```

---

## 🧪 Testing

### Run All Tests
```bash
forge test
```

### Run Specific Test
```bash
forge test --mt testGovernanceUpdatesBox -vvvv
```

##  Deployment

### Deploy to Anvil (Local)
```bash
make anvil                    # Start Anvil in one terminal
make deploy                   # Deploy in another terminal
```

### Deploy to Sepolia
```bash
make deploy ARGS="--network sepolia"
```

### Deploy to Mainnet
```bash
make deploy ARGS="--network mainnet"
```


##  Future Improvements

| Feature                   | Description                                | Priority |
| ------------------------- | ------------------------------------------ | -------- |
| **Multi-sig Integration** | Add Safe multi-sig for critical operations | High     |
| **Upgradeable Contracts** | Make Box upgradeable with UUPS proxy       | High     |
| **Delegate Portal**       | UI for users to delegate votes             | Medium   |

##  Security

- **Timelock**: All governance actions have a delay period
- **Quorum**: 10% of total supply (100,000 GVT) required for a proposal to pass
- **Role Management**: PROPOSER_ROLE controlled by Governor
- **Pausable**: Emergency pause mechanism
- **OnlyOwner**: Box functions protected from unauthorized access

##  License

MIT


---

##  Verification Checklist

-  All contracts deployed and verified on Sepolia
-  Roles properly configured
-  Governor has PROPOSER_ROLE
-  Anyone can execute (EXECUTOR_ROLE = address(0))
-  Deployer DEFAULT_ADMIN_ROLE revoked
-  All tests passing

---

**Built with Foundry** 

---

 ## Author
 Chimezie Obi


