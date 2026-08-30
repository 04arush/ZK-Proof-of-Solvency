import { Noir } from "@noir-lang/noir_js";
import { Barretenberg, UltraHonkBackend } from "@aztec/bb.js";
import { readFileSync, writeFileSync } from "fs";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

const circuitPath = resolve(__dirname, "../../circuits/inclusion_proof/target/inclusion_proof.json");
const circuit = JSON.parse(readFileSync(circuitPath, "utf-8"));

const witnessPath = resolve(__dirname, "../witness.json");
const inputs = JSON.parse(readFileSync(witnessPath, "utf-8"));

const api = await Barretenberg.new();
const backend = new UltraHonkBackend(circuit.bytecode, api);
const noir = new Noir(circuit);

// -- Witness ----------------------
console.log("Generating witness...");
const { witness } = await noir.execute(inputs);

// -- Proof ------------------------
console.log("Generating proof...");
const proof = await backend.generateProof(
    witness,
    { verifierTarget: 'evm'} 
);

// -- Verification (off-chain) -----
console.log("Verifying proof (off-chain)...");
const valid = await backend.verifyProof(
    proof,
    { verifierTarget: 'evm' }
);
console.log("Proof valid: ", valid);

// Save proof to disk for Foundry tests
writeFileSync(
    resolve(__dirname, "../proof.json"),
    JSON.stringify({
        proof: Array.from(proof.proof),
        publicInputs: proof.publicInputs
    })
);
console.log("Public inputs: ", proof.publicInputs);
console.log("Proof length (bytes): ", proof.proof.length);

await api.destroy();