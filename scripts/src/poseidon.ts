import { poseidon2, poseidon4 } from "poseidon-lite";

export function hashLeaf(secret: bigint, balance: bigint): bigint {
    return poseidon2([secret, balance]);
}

export function hashNode(
    leftHash: bigint, leftSum: bigint,
    rightHash: bigint, rightSum: bigint
): bigint {
    return poseidon4([leftHash, leftSum, rightHash, rightSum]);
}