# Zero-Knowledge Proof of Solvency (ZK-PoS)

A zero-knowledge proof-of-solvency protocol that allows an asset custodian to prove liabilities coverage and non-negative user balances without disclosing individual account data.

## What This Proves

This system provides a mathematical guarantee of liability solvency and honest individual inclusion. It cryptographically proves that a specific user's balance is correctly included as a leaf in a Merkle Sum Tree, that the tree's root sum matches the custodian's publicly declared aggregate liability, and that every balance represented in the tree is non-negative (within the `[0, 2^64)` range). Ensuring non-negativity prevents the operator from hiding reserve deficits by injecting fake negative-balance accounts to artificially decrease the declared liabilities, all while preserving user privacy by keeping secrets and individual balances fully off-chain.

## Prerequisites

To build and run this project, the following tool versions are required:

- **Nargo**: `1.0.0-beta.26` (Noir package manager/compiler)
- **Barretenberg (bb)**: `0.87.0` (Barretenberg proving backend CLI, with `@aztec/bb.js@5.0.0` library)
- **Foundry**: `1.7.1` (Solidity compilation and testing framework)
- **Node.js**: `v20.20.2` (TypeScript script execution environment)

## Setup & Installation

Follow these steps in order to set up a working local environment:

1. **Clone the repository and install Node.js dependencies**:
   ```bash
   cd scripts
   npm install
   ```

2. **Compile the Noir ZK circuit**:
   ```bash
   cd ../circuits/inclusion_proof
   nargo compile
   ```

3. **Compile the smart contracts**:
   ```bash
   cd ../../contracts
   forge build
   ```

## Usage

This protocol features a complete pipeline from tree construction to on-chain verification.

### 1. Build the Merkle Sum Tree
To verify off-chain calculations and ensure that the Poseidon hashing implementation in TypeScript matches the circuit implementation, run the sanity tests and the demo builder:
```bash
cd scripts
npm test
npx tsx src/demo.ts
```

### 2. Run Circuit Tests
Run unit tests for the Noir circuit to verify correctness of the inclusion and range proof logic under normal and adversarial conditions:
```bash
cd circuits/inclusion_proof
nargo test
```

### 3. Generate Solidity Verifier
Generate the Solidity verifier contract (`UltraHonkVerifier.sol`) from the compiled circuit's verification key:
```bash
cd scripts
npx tsx src/genVerifier.ts
```

### 4. Run the Proving Pipeline
Execute the off-chain pipeline to generate witness data, construct the UltraHonk proof, verify it locally, and export the output payload (`proof.json`):
```bash
cd scripts
npx tsx src/prove.ts
```

### 5. Run the Solidity Test Suite
Verify the smart contracts and the generated ZK verifier using Forge. The test suite loads the generated `proof.json` directly from the filesystem:
```bash
cd contracts
forge test -vv
```

### 6. Local Contract Deployment
To deploy the verifier and solvency contract to a local network (e.g., Anvil):
```bash
cd contracts
forge script script/Deploy.s.sol --rpc-url <rpc_url> --broadcast
```

## Project Structure

- `circuits/inclusion_proof/`: The Noir ZK-circuit codebase validating Merkle path inclusion and balance range checks.
- `contracts/`: Solidity smart contracts containing the generated verifier, the solvency registry, and the Forge test suite.
- `scripts/`: TypeScript/Node.js utilities for off-chain Merkle Sum Tree generation, witness formulation, and proving execution.

## Testing & Coverage

The Solidity test suite maintains **100% line, function, and branch coverage** on the core custom contract (`ProofOfSolvency.sol`).

The following files are excluded from coverage analysis:
- `contracts/src/UltraHonkVerifier.sol`: Machine-generated cryptographic verifier code produced automatically by Barretenberg, whose correctness is mathematically guaranteed by the backend compiler.
- `contracts/script/Deploy.s.sol`: Local deployment script executed transiently off-chain to instantiate contracts, containing no persistent on-chain logic or state-modifying edge cases.

To run the coverage suite and view the detailed report:
```bash
cd contracts
forge coverage
```

## Architecture & Design Decisions

This system utilizes a Merkle Sum Tree to securely bind user identities and balances inside hierarchical Poseidon hashes, which are verified using a Noir arithmetic circuit. The proving pipeline compiles these constraints into an UltraHonk proof, allowing gas-efficient, on-chain validation via smart contracts that match the committed liability roots. For a deep dive into the cryptographic layout, the range-proof mechanism, and detailed engineering choices, see [ARCHITECTURE.md](./ARCHITECTURE.md).

## Security & Scope Note

This repository represents an educational practice project designed to demonstrate ZK-circuit construction and Solidity smart contract integration. It has not been audited by a professional security firm, is not intended for production environments, and should not be used to manage real financial funds.

## Credits

- **Summa (PSE)**: Designed with inspiration from the open-source proof-of-solvency reference implementation by the Privacy & Scaling Explorations team at the Ethereum Foundation.
- **Noir & Barretenberg**: Engineered using the Aztec's Noir domain-specific language and Aztec's Barretenberg proving system.

## License

This project is licensed under the terms of the MIT License. See `LICENSE.md` for details.
