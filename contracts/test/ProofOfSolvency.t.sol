// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { HonkVerifier } from "../src/UltraHonkVerifier.sol";
import { ProofOfSolvency } from "../src/ProofOfSolvency.sol";

contract FalseVerifier {
    function verify(bytes calldata, bytes32[] calldata) external pure returns (bool) {
        return false;
    }
}

contract ProofOfSolvencyTest is Test {

    HonkVerifier verifier;
    ProofOfSolvency pos;

    bytes proof;
    bytes32 root;
    uint256 total;


    // ====================== Test Setup ======================

    function setUp() public {
        
        // Load scripts/proof.json
        string memory json = vm.readFile("../scripts/proof.json");

        // Parse proof bytes from the uint array
        uint256[] memory proofUints = abi.decode(
            vm.parseJson(json, ".proof"),
            (uint256[])
        );
        proof = new bytes(proofUints.length);
        for (uint256 i = 0; i < proofUints.length; i++) {
            proof[i] = bytes1(uint8(proofUints[i]));
        }

        // Parse public inputs
        bytes32[] memory pubs = abi.decode(
            vm.parseJson(json, ".publicInputs"), (bytes32[])
        );
        root = pubs[0];
        total = uint256(pubs[1]);

        verifier = new HonkVerifier();
        pos = new ProofOfSolvency(address(verifier), root);
    }


    // =================== proveAndRecord() ===================

    // ----------------- Successful Execution -----------------

    function test_proveAndRecord_succeeds() public {
        vm.expectEmit(true, false, true, true);
        emit ProofOfSolvency.SolvencyProven(root, total, address(this));
        pos.proveAndRecord(proof, root, total);
    }

    // ----------------------- Reverts ------------------------

    function test_proveAndRecord_revertsOnRootMismatch() public {
        bytes32 wrongRoot = bytes32(uint256(root) + 1);
        vm.expectRevert(ProofOfSolvency.RootMismatch.selector);
        pos.proveAndRecord(proof, wrongRoot, total);
    }

    function test_proveAndRecord_revertsOnInvalidProof() public {
        bytes memory badProof = proof;
        badProof[badProof.length - 33] = badProof[badProof.length - 33] ^ 0xff;
        vm.expectRevert(ProofOfSolvency.InvalidProof.selector);
        pos.proveAndRecord(badProof, root, total);
    }

    function test_proveAndRecord_revertsWhenVerifierReturnsFalse() public {
        // Use a mock verifier that returns false instead of reverting
        ProofOfSolvency posWithFalseVerifier = new ProofOfSolvency(
            address(new FalseVerifier()), root
        );
        vm.expectRevert(ProofOfSolvency.InvalidProof.selector);
        posWithFalseVerifier.proveAndRecord(proof, root, total);
    }


    // ===================== updateRoot() =====================

    // ----------------------- Reverts ------------------------

    function test_updateRoot_revertsIfNotOwner() public {
        vm.prank(address(0xdead));
        vm.expectRevert(ProofOfSolvency.NotOwner.selector);
        pos.updateRoot(bytes32(0));
    }

    // -------------------- State changes ---------------------

    function test_updateRoot_succeeds() public {
        bytes32 newRoot = bytes32(uint256(1));
        pos.updateRoot(newRoot);
        assertEq(pos.merkleRoot(), newRoot);
    }
}
