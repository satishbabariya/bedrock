# Layer 0 — Language Stdlib Gaps

| Field | Value |
|---|---|
| **Phase** | 1 — Foundations |
| **Effort** | included in Phase 1 (3–6 person-months total) |
| **Depends on** | — (foundational) |
| **Dependents** | [Layer 1](layer-01-primitives.md), [Layer 3](layer-03-collections.md), [Layer 4](layer-04-numeric-math.md), [Layer 6](layer-06-random.md), [Layer 10](layer-10-concurrency.md) |

Things Swift's stdlib already partially handles but where Rust crates fill gaps. These need either stdlib evolution or polyfill libraries.

## Libraries

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| Stable atomic types | (Rust stdlib) | T1 | Swift Atomics package now in stdlib evolution. |
| `Result`-style error chaining | `anyhow`, `thiserror`, `eyre`, `color-eyre`, `error-stack`, `snafu`, `failure` | T1 | Swift `throws` covers most; need ergonomic context-attaching API. |
| Lazy globals | `lazy_static`, `once_cell` | T1 | Swift `let` is already lazy-on-first-use. |
| Generic numeric traits | `num-traits`, `num` | T2 | Swift has `Numeric`, `BinaryInteger`, `FloatingPoint`. Gaps: `Bounded`, `Saturating`. |
| Owned/borrowed unification | `cow`, `beef`, `maybe-owned` | T1 | Swift CoW is built into value types. |
| `Pin` / self-referential types | `pin-project`, `pin-project-lite` | ❌ | Swift doesn't need these. |
| `Send`/`Sync` markers | (Rust stdlib) | T1 | Swift `Sendable` exists; some library wrappers (`sync_wrapper`, `fragile`) are Rust-specific. |
| Type-id / reflection | `typeid`, `as-any`, `downcast` | T1 | Swift `Any`/`as?` natively. |
| Const generics polyfills | `typenum`, `generic-array`, `hybrid-array` | T2 | Swift's generics differ; rarely needed. |
| Ordering-by-key | `partial_cmp`-style helpers | T1 | Swift has `min(by:)`, `Comparable`. |

---

[← Index](../README.md) · [Dependency graph](../DEPENDENCIES.md)
