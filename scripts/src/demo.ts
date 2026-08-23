import { buildTree, getProof } from "./merkleTree.js";

const users = [
  { secret: 111n, balance: 100n },
  { secret: 222n, balance:  50n },
  { secret: 333n, balance:  80n },
  { secret: 444n, balance:  70n },
];

const levels = buildTree(users);
const root = levels[levels.length - 1][0];
console.log("Root hash:", root.hash.toString());
console.log("Root sum (total reserves):", root.sum.toString()); // should be 300

const proof = getProof(levels, 0); // proof for user at index 0
console.log("\nProof for user 0:");
console.log("  leaf hash:", proof.leaf.hash.toString());
console.log("  path length:", proof.pathElements.length);
proof.pathElements.forEach((node, i) => {
  console.log(`  level ${i} sibling — hash: ${node.hash}, sum: ${node.sum}, direction: ${proof.pathIndices[i]}`);
});