# Layer 6 — Random Numbers

| Field | Value |
|---|---|
| **Phase** | 1 — Foundations |
| **Effort** | included in Phase 1 (3–6 person-months total) |
| **Depends on** | [Layer 0](layer-00-stdlib-gaps.md) |
| **Dependents** | [Layer 12](layer-12-cryptography.md) (entropy + nonces) |

## Libraries

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| RNG framework | `rand`, `rand_core` | T2 | |
| OS entropy | `getrandom` | T1 | Bridge `getrandom` / `SecRandomCopyBytes`. |
| ChaCha PRNG | `rand_chacha` | T2 | |
| Xoshiro / Xorshift | `rand_xoshiro`, `rand_xorshift` | T1 | |
| PCG | `rand_pcg` | T1 | |
| Fast non-crypto | `fastrand`, `nanorand`, `oorandom`, `wyrand` | T1 | |
| Distributions | `rand_distr`, `statrs` | T2 | |
| Sampling / shuffling | `rand`, `rand_seeder` | T1 | |
| Hardware RNG | `rdrand` | T2 | |

---

[← Index](../README.md) · [Dependency graph](../DEPENDENCIES.md)
