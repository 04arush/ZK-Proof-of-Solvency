import { hashLeaf, hashNode } from "./src/poseidon.js";

function assert(condition: boolean, msg: string) {
    if (!condition) throw new Error(`FAIL: ${msg}`);
    console.log(`PASS: ${msg}`);
}

// deterministic
const h1 = hashLeaf(1n, 100n);
const h2 = hashLeaf(1n, 100n);
assert(h1 === h2, "same inputs -> same hash");

// different inputs -> different hash
const h3 = hashLeaf(1n, 101n);
assert(h1 !== h3, "different balance -> different hash");

// node hash changes when sum changes
const n1 = hashNode(h1, 100n, h3, 101n);
const n2 = hashNode(h1, 999n, h3, 101n);
assert(n1 !== n2, "swapping sum breaks node hash");

console.log("\nSample leaf hash (1n, 100n):", h1.toString());