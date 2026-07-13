// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";

abstract contract CodeConstants {
    address public constant ANVIL_FIRST_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    uint256 public constant ETHEREUM_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ARBITRUM_SEPOLIA_CHAIN_ID = 421614;
    uint256 public constant ANVIL_CHAIN_ID = 31337;
}

// / @title HelperConfig contract
// / @notice This contract provides a way to manage network-specific configurations for the CommunityVault contract
// TODO: Refact the hardcoded addresses and values to be more flexible and secure per network config.
contract HelperConfig is CodeConstants, Script {
    // Types
    struct VaultConfig {
        uint256 goal;      // wei
        uint256 deadline;  // unix timestamp
        address owner;
    }

    struct NetworkConfig {
        VaultConfig vaultConfig;
    }

    // Errors
    error ChainNotConfigured(uint256 chainId);

    // State
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETHEREUM_SEPOLIA_CHAIN_ID] = getSepoliaConfig();
        networkConfigs[ARBITRUM_SEPOLIA_CHAIN_ID] = getArbitrumSepoliaConfig();
        networkConfigs[ANVIL_CHAIN_ID] = getAnvilConfig();
    }

    // Config accessors

    function getConfig() public view returns (NetworkConfig memory) {
        // address(0) owner signals the chain was never registered
        if (networkConfigs[block.chainid].vaultConfig.owner == address(0)) {
            revert ChainNotConfigured(block.chainid);
        }
        return networkConfigs[block.chainid];
    }

    function setConfig(uint256 chainId, NetworkConfig memory networkConfig) public {
        require(chainId != uint256(0), "HelperConfig: chainId is 0");
        require(networkConfig.vaultConfig.owner != address(0), "HelperConfig: owner not set");
        require(networkConfig.vaultConfig.goal != 0, "HelperConfig: goal is 0");
        networkConfigs[chainId] = networkConfig;
    }

    // Per-network config builders

    function getSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            vaultConfig: VaultConfig({
                goal: 0.01 ether,
                deadline: block.timestamp + 30 days,
                owner: 0x27598400A96D4EE85f86b0931e49cBc02adD6dF0
            })
        });
    }

    function getArbitrumSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            vaultConfig: VaultConfig({
                goal: 0.01 ether,
                deadline: block.timestamp + 30 days,
                owner: 0x27598400A96D4EE85f86b0931e49cBc02adD6dF0
            })
        });
    }

    function getAnvilConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            vaultConfig: VaultConfig({
                goal: 1 ether,
                deadline: block.timestamp + 7 days,
                owner: ANVIL_FIRST_ACCOUNT
            })
        });
    }
}