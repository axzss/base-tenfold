// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Minimal} from "../src/Minimal.sol";

/// @title  DeployScript
/// @notice Deploys 10 instances of `Minimal` under a single broadcast frame.
///         Each `new Minimal()` is a separate on-chain transaction; they all
///         share the same `startBroadcast` / `stopBroadcast` envelope and
///         run on consecutive nonces.
contract DeployScript is Script {
    uint256 internal constant DEPLOY_COUNT = 10;

    function run() external returns (Minimal[] memory deployed) {
        // Read PK from `.env` via Foundry's auto-loaded env file.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("Deployer:        ", deployer);
        console2.log("Chain ID:        ", block.chainid);
        console2.log("Deploy count:    ", DEPLOY_COUNT);
        console2.log("------------------------------------------");

        deployed = new Minimal[](DEPLOY_COUNT);

        // ---- Single broadcast: one signer, nonce i, nonce i+1, ... ----
        vm.startBroadcast(deployerPrivateKey);

        for (uint256 i = 0; i < DEPLOY_COUNT; ) {
            deployed[i] = new Minimal();
            console2.log("Deployed Minimal #", i, "->", address(deployed[i]));
            unchecked {
                ++i;
            }
        }

        vm.stopBroadcast();

        console2.log("------------------------------------------");
        console2.log("All", DEPLOY_COUNT, "contracts deployed in a single broadcast.");
        return deployed;
    }
}
