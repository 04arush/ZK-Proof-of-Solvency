# System Architecture & Design Decisions

This document provides a technical deep-dive into the cryptographic and engineering architecture of the Zero-Knowledge Proof of Solvency (ZK-PoS) system.

---

## 1. Plain Merkle Trees vs. Merkle Sum Trees

In a standard Merkle tree (such as those used in simple membership proofs or token airdrops), every node carries only a cryptographic hash. While this is sufficient to verify that a particular leaf belongs to a tree, it cannot represent or verify cumulative numeric properties.

A **Merkle Sum Tree** extends this structure by requiring every node to store both a **hash** and a **running sum** of all balances beneath it:
- A leaf node is defined as: `leafHash = Poseidon(userSecret, balance)` and `leafSum = balance`.
- An internal parent node is defined as:
  - `parentSum = leftChild.sum + rightChild.sum`
  - `parentHash = Poseidon(leftChild.hash, leftChild.sum, rightChild.hash, rightChild.sum)`

```
                    +-----------------------------+
                    |          Root Node          |
                    |  hash: parent_hash(AB, CD)  |
                    |  sum:  300 (total reserves) |
                    +--------------+--------------+
                                   |
                  +----------------+----------------+
                  |                                 |
        +---------v-----------+           +---------v-----------+
        |     Node AB         |           |     Node CD         |
        |  hash: node_h(A, B) |           |  hash: node_h(C, D) |
        |  sum:  150          |           |  sum:  150          |
        +----+-----------+----+           +----+-----------+----+
             |           |                     |           |
        +----v---+   +---v----+           +----v---+   +---v----+
        | Leaf A |   | Leaf B |           | Leaf C |   | Leaf D |
        | sum:100|   | sum:50 |           | sum:80 |   | sum:70 |
        +--------+   +--------+           +--------+   +--------+
```

### The Security Guarantee of Sum Hashing
By passing both child hashes and child sums into the parent Poseidon hash function, the sums are cryptographically bound inside the hash chain. An operator cannot maliciously swap or modify sums between sibling nodes to misrepresent liabilities without changing the resulting parent hash. This ensures the structural and mathematical integrity of the tree from bottom to top.

---

## 2. The Crucial Role of Range Proofs

The core security threat in any proof-of-solvency protocol is the **Negative Balance Attack**. 

### The Attack Vector
Suppose an exchange has real user liabilities totaling **1,000 ETH**, but only holds **600 ETH** in custody—leaving a **400 ETH** deficit. To falsely prove solvency, a malicious operator could insert a fake "dummy" user account into the Merkle tree with a balance of **-400 ETH**. 

When the tree is built, the negative balance is aggregated into the parent sums. The cumulative root sum calculation becomes:
$$\text{Total Liabilities} = 1,000 \text{ ETH} + (-400 \text{ ETH}) = 600 \text{ ETH}$$

The operator can now commit to a total liability of 600 ETH on-chain, which perfectly matches their 600 ETH of actual reserves, falsely claiming full solvency.

Because user accounts are kept confidential, honest users who verify their individual inclusion can only see their own path. They have no visibility into other leaves and cannot detect that a fake negative balance has been injected elsewhere in the tree.

### The Mitigation: In-Circuit Range Checks
To prevent this attack, the system must mathematically prove that every single user balance and sibling sum along the inclusion path is non-negative. 

In our Noir circuit, this is enforced by:
1. Declaring the user's `balance` input as an unsigned 64-bit integer type (`u64`). Noir's compiler automatically enforces range-proof constraints in the arithmetic circuit, ensuring that the witness value lies strictly in the range `[0, 2^64)` and cannot underflow or overflow the field size.
2. Walking the path upward and ensuring that sibling sums are carried and constrained as valid positive values. This guarantees that no negative leaf or internal node can be injected, forcing the root sum to represent a mathematically honest sum of non-negative liabilities.

---

## 3. High-Level Data Flow

The following diagram traces how data moves through the off-chain preparation, circuit proving, and on-chain verification phases:

```
+-------------------------------------------------------+
|                Off-Chain (TypeScript)                 |
|  1. Collect database of (userSecret, balance) pairs.  |
|  2. Pad with dummy leaves to a power of 2.            |
|  3. Build Merkle Sum Tree using Poseidon hashing.     |
|  4. Extract individual user's Merkle path & sums.     |
+---------------------------+---------------------------+
                            |
                            | Output: Merkle path, sibling sums,
                            | root hash & root sum
                            v
+-------------------------------------------------------+
|                Witness Generation (ACVM)              |
|  1. Load circuit constraints from compiled JSON.      |
|  2. Run ACVM to evaluate inputs & solve wires.        |
|  3. Export resolved witness payload (witness.json).   |
+---------------------------+---------------------------+
                            |
                            | Output: witness.json
                            v
+-------------------------------------------------------+
|               Proving Backend (bb.js)                 |
|  1. Process witness using UltraHonk backend.          |
|  2. Generate ZK proof targeting EVM verification.     |
|  3. Export flat proof bytes & public inputs.          |
+---------------------------+---------------------------+
                            |
                            | Output: proof.json
                            v
+-------------------------------------------------------+
|              On-Chain Solidity Verifier               |
|  1. User calls ProofOfSolvency.sol:proveAndRecord().  |
|  2. Guard: claimedRoot matches the committed root.    |
|  3. Reconstruct positional public inputs array.       |
|  4. Call UltraHonkVerifier:verify() via try/catch.    |
|  5. Emit SolvencyProven event upon success.           |
+-------------------------------------------------------+
```

---

## 4. Engineering Decisions

### Hashing Parity & Noir Poseidon Library Versioning
One of the most common friction points in zero-knowledge applications is aligning off-chain hashes with in-circuit hashes. 

During development, early documentation incorrectly assumed classic Poseidon hashing was removed from the Noir standard library, leading to a complex, hand-rolled Poseidon2 sponge permutation. This custom permutation was cryptographically distinct and did not match the standard output of the off-chain `poseidon-lite` package.

I resolved this by:
1. Identifying that classic Poseidon was moved to the official external package `github.com/noir-lang/poseidon`.
2. Resolving a dependency conflict where the library's README cited an outdated version (`v0.1.1`), while the active stable release had advanced to `v0.3.0`.
3. Pining the circuit dependency to `v0.3.0` and using the standard `hash_2` (for 2 inputs) and `hash_4` (for 4 inputs) functions.

This achieved perfect compatibility with `poseidon-lite`'s arity-based hashing off-chain, eliminating custom sponge complexity and maintaining a clean, standard implementation on both sides.

### Exclusion of Witness Data from Version Control
Intermediate compilation and execution artifacts (such as `witness.json`, and manual inputs in `Prover.toml`) contain plaintext **user balances**, personal **secrets**, and public node hashes. 
- Committing these files poses a major security and confidentiality risk for users, which would have killed the point of "Zero-Knowledge Proofs".
- They are excluded from version control using `.gitignore` patterns to preserve privacy and keep the repository state clean of transient, user-specific data.

### Smart Contract Coverage and Exclusions
I maintain a strict testing discipline — achieving 100% line, function, and branch coverage on the custom integration logic in `ProofOfSolvency.sol`. 

I intentionally excluded two specific contracts from this target:
- **`UltraHonkVerifier.sol`**: This is a machine-generated contract produced automatically by the Barretenberg compiler. It consists of thousands of lines of low-level pairing and sumcheck assembly. Writing unit tests to hit every assembly branch is redundant, as its cryptographic correctness is mathematically guaranteed by the backend compiler.
- **`Deploy.s.sol`**: This is a local deployment script used to instantiate the environment on Anvil. It does not contain any persistent on-chain business logic or state-modifying edge cases, so excluding it ensures the coverage report reflects only active contract code.

---

## 5. System Limitations & Boundaries

To keep the development focus sharp and within the scope of proving core ZK-circuit and Solidity integration skills, the following boundaries were established:

### Individual Proof Verification Only
In a production-scale system handling millions of users, verifying each user's inclusion proof individually on-chain can result in high aggregate gas costs. A standard optimization is to batch or group multiple proofs together before submitting them to the EVM.
- **Reason for Exclusion**: Such advanced batch-proving systems significantly increase proving times, compilation overhead, and circuit complexity. For the purpose of validating inclusion and range-check mechanics, individual proof verification is highly effective and sufficient to demonstrate the protocol's core cryptographic feasibility without introducing unnecessary structural overhead.

### Single-Operator Root Commitment
In the current contract, the committed Merkle root is managed solely by the contract owner via the `updateRoot` function. This requires trusting the owner to publish the correct liabilities root representing the actual state of user accounts.
- **Reason for Exclusion**: Building a decentralized root-commitment protocol (such as utilizing decentralized multi-signature consensus, decentralized oracles, or verifying on-chain signatures from multiple independent auditing firms) is a network-level governance problem. Keeping the update model restricted to a single owner provides a clean and simple anchor for proof validation while keeping the focus on ZK-circuit correctness.
