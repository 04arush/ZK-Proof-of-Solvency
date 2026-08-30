// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Script } from "forge-std/Script.sol";
import { HonkVerifier } from "../src/UltraHonkVerifier.sol";
import { ProofOfSolvency } from "../src/ProofOfSolvency.sol";

contract Deploy is Script {

    uint256 root_hash = 18257237824409374571232224204969554156633458997522455585510909277740193481569;

    function run() external {
        bytes32 root = bytes32(root_hash);

        vm.startBroadcast();
        HonkVerifier verifier = new HonkVerifier();
        new ProofOfSolvency(address(verifier), root);
        vm.stopBroadcast();
    }
}