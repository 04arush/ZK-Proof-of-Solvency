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
    let expected: Field = 9326983004124375216551096032771341412132084386804905225430866942582012914771;
    let computed = hash_2([1, 100]);
    assert(computed == expected, "Poseidon output does not match TypeScript hash. Bug: Hash mismatch");
}

#[test(should_fail_with = "Root hash does not match")]
fn test_tampered_balance_fails() {
    main(
        999,
        111,
        [7084943248676488125621343905198874488660816445407727855697413019739432601422, 20005602404344041849787639084770724552013063169321901524192746524806189726681],
        [50, 150],
        [false, false],
        18257237824409374571232224204969554156633458997522455585510909277740193481569,
        300
    );
}

#[test(should_fail_with = "Root sum does not match")]
fn test_wrong_root_sum_fails() {
    main(
        100,
        111,
        [7084943248676488125621343905198874488660816445407727855697413019739432601422, 20005602404344041849787639084770724552013063169321901524192746524806189726681],
        [50, 150],
        [false, false],
        18257237824409374571232224204969554156633458997522455585510909277740193481569,
        999
    );
}