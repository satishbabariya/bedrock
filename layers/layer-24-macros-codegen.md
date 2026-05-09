# Layer 24 — Macros & Code Generation

| Field | Value |
|---|---|
| **Phase** | 11 — Macros & Codegen |
| **Effort** | 1–3 person-months |
| **Depends on** | [Layer 1](layer-01-primitives.md); built atop SwiftSyntax (assumed available with the compiler) |
| **Dependents** | [Layer 14](layer-14-serialization-framework.md), [Layer 19](layer-19-web-frameworks.md), [Layer 23](layer-23-cli-terminal.md), [Layer 25](layer-25-testing.md), [Layer 26](layer-26-compiler-infra.md) |

## Libraries

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| Token tree | `proc-macro2`, `quote`, `syn`, `prettyplease`, `synstructure` | ❌ | Use SwiftSyntax. |
| Attribute parsing | `darling`, `darling_core`, `darling_macro`, `attribute-derive`, `deluxe` | T2 | Reframe on Swift macros. |
| Derive macros | `derive_builder`, `derive_more`, `derive-new`, `derive-where`, `educe`, `derivative`, `typed-builder`, `bon`, `getset` | T2 | |
| Display / Error derive | `displaydoc`, `parse-display`, `thiserror`, `anyhow`, `snafu`, `eyre` | T1 | |
| Enum helpers | `strum`, `strum_macros`, `enum-iterator`, `enum-iterator-derive`, `enum-as-inner`, `enum_dispatch`, `enum-ordinalize`, `enumset` | T1 | |
| Macro repetition | `seq-macro`, `paste`, `concat-idents` | T1 | |
| Compile-time asserts | `static_assertions`, `const_format` | T1 | |
| Compile-time string formatting | `const_format`, `phf` | T1 | |
| Inventory / plugin registry | `inventory`, `linkme` | T4 | Linker-section tricks. |
| Build-time codegen | `build.rs`, `codegen`, `cargo-emit` | T1 | SwiftPM build tools. |
| File embedding | `include_dir`, `rust-embed`, `rust-embed-impl`, `rust-embed-utils` | T2 | |
| Procmacro errors | `proc-macro-error`, `proc-macro-error2`, `proc-macro2-diagnostics` | T1 | Swift macro diagnostics. |
| Find macro crate | `proc-macro-crate` | ❌ | |
| String interning | `string-interner`, `lasso`, `internment`, `ustr` | T2 | |
| Phf maps | `phf`, `phf_codegen`, `phf_macros`, `phf_shared`, `phf_generator` | T2 | Compile-time perfect hashing. |

---

[← Index](../README.md) · [Dependency graph](../DEPENDENCIES.md)
