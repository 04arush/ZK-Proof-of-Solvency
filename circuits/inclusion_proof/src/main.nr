use poseidon::poseidon::bn254::{hash_2, hash_4};

global DEPTH: u32 = 2;

fn main(
    balance: u64,
    secret: Field,
    path_hashes: [Field; DEPTH],
    path_sums: [Field; DEPTH],
    path_indices: [bool; DEPTH],
    root_hash: pub Field,
    root_sum: pub Field
) {
    // Constraint 1: recompute the leaf
    let leaf_hash = hash_2([secret, balance as Field]);

    // Constraint 2: walk up the Merkle tree
    let mut current_hash = leaf_hash;
    let mut current_sum = balance as Field;

    for i in 0..DEPTH {
        let sibling_hash = path_hashes[i];
        let sibling_sum = path_sums[i];

        let is_right = path_indices[i] as Field;

        let left_hash = (1 - is_right) * current_hash + is_right * sibling_hash;
        let left_sum = (1 - is_right) * current_sum + is_right * sibling_sum;
        let right_hash = (1 - is_right) * sibling_hash + is_right * current_hash;
        let right_sum = (1 - is_right) * sibling_sum + is_right * current_sum;

        current_hash = hash_4([left_hash, left_sum, right_hash, right_sum]);
        current_sum = left_sum + right_sum;
    }

    // Constraint 3: computed root must match the public input
    assert(current_hash == root_hash, "Root hash does not match");
    assert(current_sum == root_sum, "Root sum does not match");
}

#[test]
fn test_leaf_hash_matches_ts() {
    // hashLeaf(1n, 100n) from poseidon.test.ts printed:
    // 9326983004124375216551096032771341412132084386804905225430866942582012914771
    let expected: Field = 9326983004124375216551096032771341412132084386804905225430866942582012914771;
    let computed = hash_2([1, 100]);
    assert(computed == expected, "Poseidon output does not match TypeScript hash. Bug: Hash mismatch");
}
