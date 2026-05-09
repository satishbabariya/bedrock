# Layer 4 — Numeric & Math

| Field | Value |
|---|---|
| **Phase** | 1 — Foundations |
| **Effort** | included in Phase 1 (3–6 person-months total) |
| **Depends on** | [Layer 0](layer-00-stdlib-gaps.md) |
| **Dependents** | [Layer 12](layer-12-cryptography.md) (bigint for RSA / EC) |

## Libraries

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| Bigint / bignum | `num-bigint`, `num-bigint-dig`, `crypto-bigint`, `ibig`, `dashu`, `malachite` | T3 | |
| Rationals | `num-rational`, `fraction` | T2 | |
| Complex | `num-complex` | T1 | |
| Arbitrary-precision decimal | `bigdecimal`, `rug`, `decimal-rs` | T3 | |
| Fixed-precision decimal | `rust_decimal`, `fixed`, `fpdec` | T2 | |
| Half-precision floats | `half` | T1 | Swift has `Float16`. |
| BFloat16 | `bf16` | T1 | |
| GMP/MPFR bindings | `rug`, `gmp-mpfr-sys` | ❌ | Bridge libgmp. |
| Statistics | `statrs`, `statistical`, `average`, `criterion-stats` | T2 | |
| Linear algebra | `nalgebra`, `ndarray`, `ndarray-linalg`, `cgmath`, `glam`, `ultraviolet`, `simba`, `vek` | T3 | Each is a full project. |
| BLAS / LAPACK | `blas`, `lapack`, `openblas-src`, `intel-mkl-src` | ❌ | Bridge native. |
| Random / probability | `rand_distr`, `probability` | T2 | |
| Polynomial / numerical | `roots`, `argmin`, `optimize` | T2 | |
| Number theory | `primes`, `prime_factorization`, `is-prime` | T1 | |
| Floating-point comparison | `float-cmp`, `approx`, `assert_float_eq` | T1 | |
| Saturating / checked arithmetic | `saturating`, `num-traits` | T1 | Swift has `&+`, `addingReportingOverflow`. |
| Quaternions | `quaternion` | T1 | |
| FFT | `rustfft`, `realfft` | T3 | |
| GIS / geo | `geo`, `geo-types`, `proj`, `geographiclib` | T3 | |

---

[← Index](../README.md) · [Dependency graph](../DEPENDENCIES.md)
