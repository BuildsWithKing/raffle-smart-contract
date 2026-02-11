# Provably Fair Raffle Smart Contract
A decentralized, provably fair lottery system built with Solidity and Foundry, leveraging Chainlink VRF for verifiable randomness and Chainlink Automation for automated winner selection.

## Table of Contents

- [Provably Fair Raffle Smart Contract](#provably-fair-raffle-smart-contract)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Features](#features)
  - [Technology Stack](#technology-stack)
  - [Getting Started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Installation](#installation)
  - [Usage](#usage)
    - [Deploy](#deploy)
    - [Testing](#testing)
    - [Interact](#interact)
  - [How It Works](#how-it-works)
  - [Smart Contract Functions](#smart-contract-functions)
    - [Main Functions](#main-functions)
    - [View Functions](#view-functions)
  - [Configuration](#configuration)
  - [Project Structure](#project-structure)
  - [Security Considerations](#security-considerations)
  - [Gas Optimization](#gas-optimization)
  - [Author](#author)
  - [Acknowledgments](#acknowledgments)
  - [License](#license)
  - [Resources](#resources)
  - [Contributing](#contributing)
    - [Built as part of the Cyfrin Foundry Solidity Course](#built-as-part-of-the-cyfrin-foundry-solidity-course)


## Overview

This project implements a transparent and trustless raffle/lottery system on the blockchain where:
- Users can enter by paying an entrance fee
- Winners are selected randomly using Chainlink VRF (Verifiable Random Function)
- Winner selection is automated using Chainlink Automation (formerly Keepers)
- The entire prize pool is automatically transferred to the winner

## Features

- **Provably Fair Randomness**: Utilizes Chainlink VRF V2 to generate verifiable random numbers for winner selection
- **Automated Execution**: Chainlink Automation triggers winner selection at predetermined intervals
- **Transparent & Trustless**: All logic is on-chain and verifiable
- **Gas Optimized**: Built with best practices for gas efficiency
- **Comprehensive Testing**: Includes unit tests, integration tests, and fork tests

## Technology Stack

- **Solidity** - Smart contract programming language
- **Foundry** - Development framework and testing suite
- **Chainlink VRF V2** - Verifiable random number generation
- **Chainlink Automation** - Decentralized automation network

## Getting Started

### Prerequisites

- [Git](https://git-scm.com/)
- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Installation

1. Clone the repository
```bash
git clone https://github.com/BuildsWithKing/raffle-contract
cd raffle-contract
```

2. Install dependencies
```bash
make install
```

3. Build the project
```bash
make build
```

## Usage

### Deploy

Deploy to Sepolia testnet:
```bash
make deploy-sepolia
```

### Testing

Run all tests:
```bash
make test
```

Run tests with verbosity:
```bash
make test -vvv
```

Run specific test:
```bash
forge test --match-test testFunctionName
```

Test coverage:
```bash
make coverage
```

### Interact

Enter the raffle:
```bash
cast send <RAFFLE_ADDRESS> "enterRaffle()" --value 0.01ether --rpc-url $SEPOLIA_RPC_URL --account myaccount
```

Check raffle state:
```bash
cast call <RAFFLE_ADDRESS> "getRaffleState()" --rpc-url $SEPOLIA_RPC_URL
```

## How It Works

1. **Entry Phase**: Users call `enterRaffle()` and pay the entrance fee. Their addresses are stored in an array.

2. **Upkeep Check**: Chainlink Automation nodes continuously call `checkUpkeep()` to determine if it's time to pick a winner based on:
   - Time interval has passed
   - Raffle is in OPEN state
   - Contract has ETH balance (at least two player)
   - Subscription is funded with LINK

3. **Winner Selection**: When conditions are met, `performUpkeep()` is called:
   - Raffle state changes to CALCULATING
   - Request is sent to Chainlink VRF for random number

4. **Fulfillment**: Chainlink VRF calls `fulfillRandomWords()`:
   - Random winner is selected using modulo operation
   - Prize pool is transferred to winner
   - Raffle resets for next round

## Smart Contract Functions

### Main Functions
- `enterRaffle()` - Enter the lottery by paying entrance fee
- `checkUpkeep()` - Check if conditions are met for winner selection
- `performUpkeep()` - Trigger the winner selection process
- `fulfillRandomWords()` - Callback function for Chainlink VRF

### View Functions
- `getEntranceFee()` - Get the entrance fee amount
- `getRaffleState()` - Get current raffle state (OPEN/CALCULATING)
- `getPlayer(uint256)` - Get player address at index
- `getRecentWinner()` - Get the most recent winner

## Configuration

Create a `.env` file with the following variables:
```
SEPOLIA_RPC_URL=your_sepolia_rpc_url
ETHERSCAN_API_KEY=your_etherscan_api_key
```

## Project Structure

```
    ├── script
    │   ├── DeployRaffle.s.sol
    │   ├── HelperConfig.s.sol
    │   └── Interaction.s.sol
    ├── src
    │   └── Raffle.sol
    └── test
        ├── integration
        │   └── IntegrationTest.t.sol
        ├── mocks
        │   └── LinkToken.sol
        └── unit
            └── RaffleTest.t.sol
        ├── foundry.toml
        └── README.md
```

## Security Considerations

- Uses Chainlink VRF for cryptographically secure randomness
- Implements checks-effects-interactions pattern
- State changes before external calls to prevent reentrancy
- Comprehensive test coverage
- Audited Chainlink contracts

## Gas Optimization

- Uses custom errors instead of require strings
- Efficient storage patterns
- Optimized loops and array operations

## Author

**Michealking**  
- GitHub: [@BuildsWithKing](https://github.com/BuildsWithKing)
- Twitter: [@BuildsWithKing](https://x.com/BuildsWithKing)
- Discord: [@BuildsWithKing](https://discord.gg/6fnfy8Rs)

## Acknowledgments

- [Cyfrin Updraft](https://updraft.cyfrin.io/) - Foundry Solidity Course
- [Patrick Collins](https://github.com/PatrickAlphaC) - Course instructor
- [Chainlink](https://chain.link/) - VRF and Automation services

## License

This project is licensed under the MIT License.

## Resources

- [Foundry Book](https://book.getfoundry.sh/)
- [Chainlink VRF Documentation](https://docs.chain.link/vrf/v2/introduction)
- [Chainlink Automation Documentation](https://docs.chain.link/chainlink-automation/introduction)
- [Cyfrin Updraft Course](https://updraft.cyfrin.io/)

## Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the issues page.

---
 ### Built as part of the Cyfrin Foundry Solidity Course 