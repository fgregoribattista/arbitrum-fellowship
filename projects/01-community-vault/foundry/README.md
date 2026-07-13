# CommunityVault

## Overview

CommunityVault is a crowdfunding contract where contributors send ETH and receive CVT (Community Vault Token, an ERC-20) at a fixed rate of 1 wei = 1 CVT. The contract is initialized with a fundraising `goal` (in wei) and a `deadline` (unix timestamp). If `totalContributed >= goal` after the deadline, the owner calls `withdraw()` to collect the funds. If the goal is not met by the deadline, contributors call `refund()`, which burns their CVT and returns their ETH. The contract inherits OpenZeppelin v5 `ERC20`, `Ownable`, and `ReentrancyGuard`.

## Prerequisites

- Foundry installed:

```bash
curl -L https://foundry.paradigm.xyz | bash && foundryup
```

- For Arbitrum Sepolia deployment: a funded wallet and the `PRIVATE_KEY` environment variable set.

## Install dependencies

Dependencies are managed via soldeer (built into forge). Declarations live in `foundry.toml` under `[dependencies]` (`forge-std = "1.9.6"`, `@openzeppelin-contracts = "5.3.0"`); `remappings.txt` maps them to `dependencies/`.

```bash
forge soldeer install
```

## Build

```bash
forge build
```

## Run tests

```bash
forge test -vv
```

Test naming conventions:
- `test_RevertWhen_*` — tests that assert an expected revert.
- `testFuzz_*` — fuzz tests with randomized inputs.

## Coverage

```bash
forge coverage
```

## Environment setup
Copy the environment template, fill in your private key and the etherscan api key (for validate contract):

```bash
cp .env.example .env
source .env
```

## Deploy — local (Anvil)

1. Set the [Environment](#environment-setup)

2. Start Anvil in a separate terminal:

```bash
anvil
```

3. Run the deploy script:

```bash
forge script script/CommunityVault.s.sol:CommunityVaultScript \
  --rpc-url http://localhost:8545 \
  --broadcast
```

`HelperConfig` auto-selects the Anvil config (chain ID 31337): first Anvil account as owner, goal 1 ether, deadline `block.timestamp + 7 days`.

## Deploy — Arbitrum Sepolia

1. Set the [Environment](#environment-setup)

2. Run the deploy script:

```bash
forge script script/CommunityVault.s.sol:CommunityVaultScript \
  --rpc-url arbitrum_sepolia \
  --chain-id 421614 \
  --broadcast \
  --verify

```
The `arbitrum_sepolia` alias resolves via `foundry.toml` → `[rpc_endpoints]` to `https://sepolia-rollup.arbitrum.io/rpc`.

`HelperConfig` auto-selects the Arbitrum Sepolia config (chain ID 421614): goal 0.01 ether, deadline `block.timestamp + 30 days`.

## Verify

If you like, you can manually verify the contract on any chain (testnet or mainnet):

Sepolia arbitrum example:

```bash
forge clean
forge build
forge verify-contract <address> src/CommunityVault.sol:CommunityVault \
  --chain-id 421614 \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --verifier-url "https://api.etherscan.io/v2/api?chainid=421614" \
  --constructor-args $(cast abi-encode "constructor(uint256,uint256,address)" <goal> <deadline> <owner>)
```
