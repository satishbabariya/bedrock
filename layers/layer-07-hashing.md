# Layer 7 — Hashing (Non-crypto)

| Field | Value |
|---|---|
| **Phase** | 1 — Foundations |
| **Effort** | included in Phase 1 (3–6 person-months total) |
| **Depends on** | [Layer 1](layer-01-primitives.md) |
| **Dependents** | [Layer 3](layer-03-collections.md), [Layer 21](layer-21-observability.md) |

Distinct from cryptographic hashing — these are for hashmaps, partitioning, fingerprints.

## Libraries

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| SipHash | `siphasher` | T1 | Swift's default already. |
| FxHash | `fxhash`, `rustc-hash`, `fxhash-shootout` | T1 | |
| AHash | `ahash` | T1 | |
| FoldHash | `foldhash` | T1 | |
| xxHash | `twox-hash`, `xxhash-rust` | T1 | |
| MetroHash | `metrohash` | T1 | |
| Murmur3 | `murmur3`, `mur3`, `fasthash` | T1 | |
| SeaHash | `seahash` | T1 | |
| HighwayHash | `highway` | T2 | |
| CityHash / FarmHash | `cityhasher`, `farmhash` | T2 | |
| CRC | `crc`, `crc-catalog`, `crc32fast`, `crc32c`, `crc-any` | T1 | |
| Adler-32 | `adler`, `adler2`, `simd-adler32` | T1 | |
| Fletcher | `fletcher` | T1 | |

---

[← Index](../README.md) · [Dependency graph](../DEPENDENCIES.md)
