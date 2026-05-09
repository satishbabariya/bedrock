# Layer 25 — Testing, Fuzzing, Benchmarking

| Field | Value |
|---|---|
| **Phase** | 12 — Testing & Tooling |
| **Effort** | 2–4 person-months |
| **Depends on** | [Layer 24](layer-24-macros-codegen.md), [Layer 14](layer-14-serialization-framework.md) (snapshot codecs), [Layer 1](layer-01-primitives.md) |
| **Dependents** | downstream development workflows |

## Libraries

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| Unit testing | (Rust stdlib `#[test]`) | T1 | Swift Testing framework. |
| Property testing | `proptest`, `quickcheck`, `arbitrary`, `arbtest` | T2 | |
| Snapshot testing | `insta`, `expect-test`, `goldentests` | T2 | |
| Mocking | `mockall`, `mockito`, `faux`, `mockiato` | T3 | Hard without runtime reflection. |
| HTTP mocking | (see [Layer 18](layer-18-http-stack.md)) | | |
| Test helpers | `pretty_assertions`, `assert2`, `assert_matches`, `assert_cmd`, `assert_fs` | T1 | |
| Test data | `fake`, `faker_rand` | T2 | |
| Integration testing | `testcontainers`, `dockertest` | T2 | |
| Benchmarking | `criterion`, `divan`, `iai`, `bencher`, `easybench` | T3 | |
| Fuzzing | `cargo-fuzz`, `afl`, `honggfuzz`, `arbitrary` | ❌ | Tooling, not lib. |
| Coverage | `tarpaulin`, `grcov`, `llvm-cov` | ❌ | Tooling. |
| Test predicates | `predicates`, `predicates-core`, `predicates-tree` | T1 | |
| Approval testing | `insta`, `expect-test` | T2 | |
| Concurrency testing | `loom`, `shuttle` | T4 | Permutation testing. |
| Doctest | (Rust stdlib) | T2 | |
| Conformance | `conformist`, `compliance-test` | T2 | |

---

[← Index](../README.md) · [Dependency graph](../DEPENDENCIES.md)
