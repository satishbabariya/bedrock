# Layer 12 — Cryptography

| Field | Value |
|---|---|
| **Phase** | 4 — Crypto + TLS |
| **Effort** | included in Phase 4 (2–4 person-months total, +6–12 if pure-Swift) |
| **Depends on** | [Layer 1](layer-01-primitives.md), [Layer 4](layer-04-numeric-math.md) (bigint), [Layer 6](layer-06-random.md) (entropy) |
| **Dependents** | [Layer 13](layer-13-tls-pki.md), [Layer 17](layer-17-networking-protocols.md), [Layer 19](layer-19-web-frameworks.md) (auth) |

Production rule: bridge BoringSSL or libsodium. Pure-Swift crypto without audited libraries is dangerous. Listed for completeness.

## Libraries

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| Crypto provider | `ring`, `aws-lc-rs`, `aws-lc-sys`, `openssl`, `boring`, `boring-sys`, `mbedtls` | ❌ | Bridge BoringSSL. |
| SHA-2 family | `sha2` | T1 | |
| SHA-3 / Keccak | `tiny-keccak`, `sha3`, `keccak` | T2 | |
| SHA-1 (legacy) | `sha1`, `sha1_smol` | T1 | |
| MD5 (legacy) | `md-5`, `md5` | T1 | |
| BLAKE2 / BLAKE3 | `blake2`, `blake3` | T2 | BLAKE3 has SIMD. |
| RIPEMD | `ripemd` | T1 | |
| HMAC | `hmac` | T1 | |
| HKDF | `hkdf` | T1 | |
| Hash trait | `digest`, `block-buffer`, `crypto-common`, `generic-array`, `hybrid-array` | T1 | |
| AES | `aes`, `aes-soft`, `aes-gcm`, `aes-gcm-siv`, `aes-siv` | T2 | |
| ChaCha20 / Poly1305 | `chacha20`, `chacha20poly1305`, `poly1305` | T2 | |
| AEAD trait | `aead` | T1 | |
| Salsa20 | `salsa20` | T1 | |
| KDF / Argon2 / scrypt / bcrypt / PBKDF2 | `argon2`, `scrypt`, `bcrypt`, `pbkdf2`, `password-hash` | T2 | |
| RSA | `rsa` | T3 | BigInt + side-channels. |
| ECDSA | `ecdsa`, `k256`, `p256`, `p384`, `p521` | T3 | |
| EdDSA | `ed25519`, `ed25519-dalek`, `ed25519-compact` | T3 | |
| Curve25519 | `curve25519-dalek`, `x25519-dalek` | T4 | Constant-time arithmetic. |
| Elliptic curve trait | `elliptic-curve`, `group`, `ff`, `primeorder` | T2 | |
| Constant-time bigint | `crypto-bigint`, `num-bigint-dig` | T3 | |
| Signature trait | `signature` | T1 | |
| Deterministic ECDSA | `rfc6979` | T1 | |
| Constant-time helpers | `subtle`, `constant_time_eq`, `cmov` | T2 | |
| Memory zeroization | `zeroize`, `zeroize_derive`, `secrecy` | T2 | Hard with ARC. |
| Secret management | `secrecy`, `redact` | T1 | |
| CPU feature detect | `cpufeatures` | T1 | |
| Universal hash | `universal-hash` | T1 | |
| Cipher trait | `cipher`, `inout` | T1 | |
| Streaming cipher | `stream-cipher`, `chacha20` | T1 | |
| Threshold / MPC | `frost-core`, `vsss-rs`, `verifiable-secret-sharing` | T4 | |
| Homomorphic encryption | `concrete`, `tfhe` | ❌ | Bridge. |
| Post-quantum | `pqcrypto`, `kyber`, `dilithium`, `sphincs+` | T4 | |
| Zero-knowledge | `arkworks`, `bellman`, `bulletproofs`, `halo2` | T4 | |
| Random | (see [Layer 6](layer-06-random.md)) | | |

---

[← Index](../README.md) · [Dependency graph](../DEPENDENCIES.md)
