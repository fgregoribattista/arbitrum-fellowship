// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std-1.9.6/src/Test.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {CommunityVaultScript} from "../script/CommunityVault.s.sol";
import {CommunityVault} from "../src/CommunityVault.sol";

contract ScriptsTest is Test {
    // =========================================================================
    // HelperConfig — constructor
    // =========================================================================

    function test_ConstructorPrePopulatesAnvil() external {
        HelperConfig hc = new HelperConfig();
        HelperConfig.NetworkConfig memory nc = hc.getConfig();

        // grouping justified: three fields of the same struct under a single invariant
        assertEq(nc.vaultConfig.goal, 1 ether);
        assertEq(nc.vaultConfig.owner, 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        assertTrue(nc.vaultConfig.deadline > block.timestamp);
    }

    function test_ConstructorPrePopulatesArbitrumSepolia() external {
        vm.chainId(421614);
        HelperConfig hc = new HelperConfig();
        HelperConfig.NetworkConfig memory nc = hc.getConfig();

        assertEq(nc.vaultConfig.goal, 0.01 ether);
        assertTrue(nc.vaultConfig.owner != address(0));
    }

    function test_ConstructorPrePopulatesEthereumSepolia() external {
        vm.chainId(11155111);
        HelperConfig hc = new HelperConfig();
        HelperConfig.NetworkConfig memory nc = hc.getConfig();

        assertEq(nc.vaultConfig.goal, 0.01 ether);
        assertTrue(nc.vaultConfig.owner != address(0));
    }

    // =========================================================================
    // HelperConfig — getConfig()
    // =========================================================================

    function test_GetConfigReturnsAnvilConfig() external {
        HelperConfig hc = new HelperConfig();
        HelperConfig.NetworkConfig memory fromGet     = hc.getConfig();
        HelperConfig.NetworkConfig memory fromBuilder = hc.getAnvilConfig();

        // grouping justified: exhaustive field-by-field struct comparison
        assertEq(fromGet.vaultConfig.goal,     fromBuilder.vaultConfig.goal);
        assertEq(fromGet.vaultConfig.deadline, fromBuilder.vaultConfig.deadline);
        assertEq(fromGet.vaultConfig.owner,    fromBuilder.vaultConfig.owner);
    }

    function test_RevertWhen_GetConfigOnUnconfiguredChain() external {
        // vm.chainId must be set *before* constructing HelperConfig so that getConfig()
        // later dispatches on chainId 999, which was never registered in the constructor.
        vm.chainId(999);
        HelperConfig hc = new HelperConfig();

        vm.expectRevert(abi.encodeWithSelector(HelperConfig.ChainNotConfigured.selector, 999));
        hc.getConfig();
    }

    // =========================================================================
    // HelperConfig — setConfig()
    // =========================================================================

    function test_SetConfigStoresAndIsRetrievable() external {
        HelperConfig hc = new HelperConfig();

        HelperConfig.NetworkConfig memory cfg = HelperConfig.NetworkConfig({
            vaultConfig: HelperConfig.VaultConfig({
                goal:     2 ether,
                deadline: block.timestamp + 14 days,
                owner:    address(1)
            })
        });

        hc.setConfig(999, cfg);
        vm.chainId(999);

        HelperConfig.NetworkConfig memory stored = hc.getConfig();
        // grouping justified: exhaustive struct comparison
        assertEq(stored.vaultConfig.goal,     cfg.vaultConfig.goal);
        assertEq(stored.vaultConfig.deadline, cfg.vaultConfig.deadline);
        assertEq(stored.vaultConfig.owner,    cfg.vaultConfig.owner);
    }

    function test_RevertWhen_SetConfigChainIdIsZero() external {
        HelperConfig hc = new HelperConfig();

        HelperConfig.NetworkConfig memory validConfig = HelperConfig.NetworkConfig({
            vaultConfig: HelperConfig.VaultConfig({
                goal:     1 ether,
                deadline: block.timestamp + 7 days,
                owner:    address(1)
            })
        });

        // require(chainId != 0, "…") encodes as Error(string), not a raw bytes cast
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "HelperConfig: chainId is 0"));
        hc.setConfig(0, validConfig);
    }

    function test_RevertWhen_SetConfigOwnerIsZero() external {
        HelperConfig hc = new HelperConfig();

        // address(0) owner is the "not configured" sentinel in getConfig() —
        // allowing it through setConfig() would silently poison the mapping.
        HelperConfig.NetworkConfig memory configWithZeroOwner = HelperConfig.NetworkConfig({
            vaultConfig: HelperConfig.VaultConfig({
                goal:     1 ether,
                deadline: block.timestamp + 7 days,
                owner:    address(0)
            })
        });

        vm.expectRevert(abi.encodeWithSignature("Error(string)", "HelperConfig: owner not set"));
        hc.setConfig(999, configWithZeroOwner);
    }

    function test_RevertWhen_SetConfigGoalIsZero() external {
        HelperConfig hc = new HelperConfig();

        // zero goal would pass setConfig but then fail CommunityVault's constructor guard later
        HelperConfig.NetworkConfig memory configWithZeroGoal = HelperConfig.NetworkConfig({
            vaultConfig: HelperConfig.VaultConfig({
                goal:     0,
                deadline: block.timestamp + 7 days,
                owner:    address(1)
            })
        });

        vm.expectRevert(abi.encodeWithSignature("Error(string)", "HelperConfig: goal is 0"));
        hc.setConfig(999, configWithZeroGoal);
    }

    // =========================================================================
    // HelperConfig — per-network builders
    // =========================================================================

    function test_AnvilConfigValues() external {
        HelperConfig hc = new HelperConfig();
        HelperConfig.NetworkConfig memory nc = hc.getAnvilConfig();

        // grouping justified: all three are fields of the same struct invariant
        assertEq(nc.vaultConfig.goal,     1 ether);
        assertEq(nc.vaultConfig.deadline, block.timestamp + 7 days);
        assertEq(nc.vaultConfig.owner,    0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
    }

    function test_ArbitrumSepoliaConfigValues() external {
        HelperConfig hc = new HelperConfig();
        HelperConfig.NetworkConfig memory nc = hc.getArbitrumSepoliaConfig();

        assertEq(nc.vaultConfig.goal,     0.01 ether);
        assertEq(nc.vaultConfig.deadline, block.timestamp + 30 days);
        assertTrue(nc.vaultConfig.owner != address(0));
    }

    function test_SepoliaConfigValues() external {
        HelperConfig hc = new HelperConfig();
        HelperConfig.NetworkConfig memory nc = hc.getSepoliaConfig();

        assertEq(nc.vaultConfig.goal,     0.01 ether);
        assertEq(nc.vaultConfig.deadline, block.timestamp + 30 days);
        assertTrue(nc.vaultConfig.owner != address(0));
    }

    // =========================================================================
    // CommunityVaultScript — deployment smoke test
    // =========================================================================

    function test_RunDeploysVaultWithAnvilConfig() external {
        // Anvil account #0 private key — well-known deterministic test key generated by
        // `anvil` for local development only. NEVER use this key in production or with
        // real funds; it is public knowledge and any assets sent to it are immediately at risk.
        vm.setEnv("PRIVATE_KEY", "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80");

        CommunityVault vault = new CommunityVaultScript().run();

        // grouping justified: four assertions validate the same deployed-contract invariant
        assertEq(vault.goal(),  1 ether);
        assertEq(vault.owner(), 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        assertTrue(vault.deadline()    > block.timestamp);
        assertTrue(address(vault)     != address(0));
    }
}