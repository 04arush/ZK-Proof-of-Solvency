import { Barretenberg, UltraHonkBackend } from "@aztec/bb.js";
import { readFileSync, writeFileSync } from "fs";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const circuit = JSON.parse(readFileSync(
    resolve(__dirname, "../../circuits/inclusion_proof/target/inclusion_proof.json"),
    "utf-8"
));

const api = await Barretenberg.new();
const backend = new UltraHonkBackend(circuit.bytecode, api);
const vk = await backend.getVerificationKey({
    verifierTarget: 'evm'
});
const solidity = await backend.getSolidityVerifier(
    vk,
    { verifierTarget: 'evm' }
);

writeFileSync(
    resolve(__dirname, "../../contracts/src/UltraHonkVerifier.sol"),
    solidity
);

console.log("UltraHonkVerifier.sol written!");
await api.destroy();