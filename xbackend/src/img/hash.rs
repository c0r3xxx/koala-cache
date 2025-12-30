pub fn compute_hash(body: &[u8]) -> String {
    let hash = blake3::hash(body);
    hash.to_hex().to_string()
}
