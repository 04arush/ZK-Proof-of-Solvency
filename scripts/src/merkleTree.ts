import { hashLeaf, hashNode } from "./poseidon.js";

export type TreeNode = {
    hash: bigint;
    sum: bigint;
};

export type MerkleProof = {
    leaf: TreeNode;
    pathElements: TreeNode[];   // sibling at each level, bottom -> root
    pathIndices: number[]; // 0 = current node is left child, 1 = current node is right child
    root: TreeNode;
};

// Building the tree
export function buildTree(leaves: { 
    secret: bigint;
    balance: bigint 
}[]) {
    
    // Pad the leaves to the next power of 2
    const size = nextPowerOf2(leaves.length);
    const paddedLeaves = [...leaves];
    while (paddedLeaves.length < size) {
        paddedLeaves.push({ secret: 0n, balance: 0n });
    }

    // level 0 = leaves
    const levels: TreeNode[][] = [];
    levels[0] = paddedLeaves.map(({ secret, balance }) => ({
        hash: hashLeaf(secret, balance),
        sum: balance,
    }));

    // Build up level by level
    let current = levels[0];
    while (current.length > 1) {
        const next: TreeNode[] = [];
        for (let i = 0; i < current.length; i += 2) {
            const left = current[i];
            const right = current[i + 1];
            next.push({
                hash: hashNode(left.hash, left.sum, right.hash, right.sum),
                sum: left.sum + right.sum,
            });
        }
        levels.push(next);
        current = next;
    }

    return levels;  // levels[last] is [root]
}


function nextPowerOf2(n: number): number {
    let p = 1;
    while (p < n) p <<= 1;
    return p;
}

// Extraction a proof
export function getProof(
    levels: TreeNode[][],
    leafIndex: number
): MerkleProof {
    const pathElements: TreeNode[] = [];
    const pathIndices: number[] = [];

    let index = leafIndex;
    for (let level = 0; level < levels.length - 1; level++) {
        const isRight = index % 2;  // 1 if current node is right child
        const siblingIndex = isRight ? index - 1 : index + 1;
        pathElements.push(levels[level][siblingIndex]);
        pathIndices.push(isRight);
        index = Math.floor(index / 2);  // move up to the parent
    }

    const root = levels[levels.length - 1][0];
    
    return {
        leaf: levels[0][leafIndex],
        pathElements,
        pathIndices,
        root,
    };
}