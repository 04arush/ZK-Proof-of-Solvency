// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IVerifier {
    function verify(
        bytes calldata _proof,
        bytes32[] calldata _publicInputs
    ) external view returns (bool);
}

contract ProofOfSolvency {

    // ==================== State Variables ====================

    IVerifier public immutable verifier;
    bytes32 public merkleRoot;
    address public owner;

    
    // ======================== Events =========================

    event SolvencyProven(
        bytes32 indexed merkleRoot,
        uint256 totalAssets,
        address indexed prover
    );


    // ======================== Errors =========================

    error InvalidProof();
    error RootMismatch();
    error NotOwner();


    // ======================= Functions =======================

    // ---------------------- Constructor ----------------------

    constructor(address _verifier, bytes32 _merkleRoot) {
        verifier = IVerifier(_verifier);
        merkleRoot = _merkleRoot;
        owner = msg.sender;
    }

    // ------------------ Exeternal Functions ------------------

    function updateRoot(bytes32 _newRoot) external {
        if (msg.sender != owner) revert NotOwner();
        merkleRoot = _newRoot;
    }

    function proveAndRecord(
        bytes calldata proof,
        bytes32 claimedRoot,
        uint256 claimedTotal
    ) external {
        if (claimedRoot != merkleRoot) revert RootMismatch();

        bytes32[] memory publicInputs = new bytes32[](2);
        publicInputs[0] = claimedRoot;
        publicInputs[1] = bytes32(claimedTotal);

        if (!verifier.verify(proof, publicInputs)) revert InvalidProof();
        emit SolvencyProven(claimedRoot, claimedTotal, msg.sender);
    }
}