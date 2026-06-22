// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Minimal} from "../src/Minimal.sol";

/// @title  DeploySingle
/// @notice Deploys a single instance of `Minimal`. Used by the
///         rate-limited Makefile targets, which loop this script 10
///         times with a 15-30 second sleep between iterations. The
///         spacing keeps block explorers from flagging ten back-to-back
///         transactions as spam.
/// @dev    Run with `--broadcast --verify` to deploy and auto-verify
///         in one call. Each invocation produces one new broadcast
///         file in `broadcast/DeploySingle.s.sol/<chainid>/run-*.json`.
contract DeploySingle is Script {
    function run() external returns (Minimal deployed) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("Deployer:    ", deployer);
        console2.log("Chain ID:    ", block.chainid);

        vm.startBroadcast(deployerPrivateKey);
        deployed = new Minimal();
        vm.stopBroadcast();

        console2.log("Deployed:    ", address(deployed));
        return deployed;
    }
}
