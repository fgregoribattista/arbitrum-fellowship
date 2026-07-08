// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {CommunityVault} from "../src/CommunityVault.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract CommunityVaultScript is Script {
    function run() external returns (CommunityVault) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.VaultConfig memory config = helperConfig.getConfig().vaultConfig;

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        CommunityVault vault = new CommunityVault(
            config.goal,
            config.deadline,
            config.owner
        );

        vm.stopBroadcast();

        console.log("CommunityVault deployed at:", address(vault));
        console.log("Goal (wei):                ", config.goal);
        console.log("Deadline (unix):           ", config.deadline);
        console.log("Owner:                     ", config.owner);

        return vault;
    }
}