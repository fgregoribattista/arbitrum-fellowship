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

## Deploy — local (Anvil)

1. Start Anvil in a separate terminal:

```bash
anvil
```

2. Export the first Anvil private key:

```bash
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

3. Run the deploy script:

```bash
forge script script/CommunityVault.s.sol:CommunityVaultScript \
  --rpc-url http://localhost:8545 \
  --broadcast
```

`HelperConfig` auto-selects the Anvil config (chain ID 31337): first Anvil account as owner, goal 1 ether, deadline `block.timestamp + 7 days`.

## Deploy — Arbitrum Sepolia

1. Export your funded wallet private key:

```bash
export PRIVATE_KEY=<your_private_key>
```

2. Run the deploy script:

```bash
forge script script/CommunityVault.s.sol:CommunityVaultScript \
  --rpc-url arbitrum_sepolia \
  --chain-id 421614 \
  --broadcast
```

The `arbitrum_sepolia` alias resolves via `foundry.toml` → `[rpc_endpoints]` to `https://sepolia-rollup.arbitrum.io/rpc`.

`HelperConfig` auto-selects the Arbitrum Sepolia config (chain ID 421614): goal 0.01 ether, deadline `block.timestamp + 30 days`.
