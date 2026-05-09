# Layer 26 — Compiler Infrastructure

| Field | Value |
|---|---|
| **Phase** | 13 — Compiler / Language Tooling |
| **Effort** | included in Phase 13 (6–12 person-months total) |
| **Depends on** | [Layer 24](layer-24-macros-codegen.md), [Layer 1](layer-01-primitives.md), [Layer 3](layer-03-collections.md) |
| **Dependents** | [Layer 27](layer-27-wasm-tooling.md) |

## Libraries

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| Lexer generators | `logos`, `rusty_lex` | T2 | |
| Parser combinators | `winnow`, `nom`, `combine`, `chumsky`, `parsell` | T2 | |
| Parser generators | `pest`, `pest_derive`, `pest_meta`, `pest_generator`, `pest_ascii_tree`, `lalrpop`, `tree-sitter-cli` | T3 | |
| PEG | `pest`, `peg` | T3 | |
| Tree-sitter | `tree-sitter`, `tree-sitter-loader` | ❌ | Bridge C library. |
| Codegen helpers | `cranelift-srcgen`, `quote` | T2 | |
| LLVM bindings | `inkwell`, `llvm-sys`, `llvm-ir` | ❌ | Bridge LLVM. |
| Cranelift | `cranelift-codegen`, `cranelift-frontend`, `cranelift-isle`, `cranelift-entity`, `cranelift-bforest`, `cranelift-bitset`, `cranelift-control`, `cranelift-native`, `cranelift-assembler-x64`, `regalloc2` | T4 | |
| Symbolic execution | `klee-rs` | T4 | |
| Type checking helpers | `ena` (union-find), `petgraph` | T2 | |
| Diagnostics rendering | `codespan`, `codespan-reporting`, `ariadne`, `miette` | T2 | High value. |
| String interning | (see [Layer 24](layer-24-macros-codegen.md)) | | |
| Symbol demangling | `rustc-demangle`, `cpp_demangle`, `symbolic-demangle` | T2 | |
| Object file reading | `object`, `goblin` | T3 | ELF/Mach-O/PE. |
| DWARF | `gimli`, `addr2line` | T3 | |
| Linker bits | `mold-rs` (n/a), `ld-rs` | T4 | |
| Code generators | `tonic-build`, `prost-build`, `protobuf-build` | T2 | |
| Pretty printing | `prettyplease`, `pretty`, `pretty-hex` | T1 | |
| AST manipulation | `syn`, `quote` | ❌ | SwiftSyntax. |
| Optimization passes | `petgraph`, custom | T3 | |
| Type-level numerics | `typenum`, `generic-array` | T3 | |
| Macro expansion | `cargo-expand` | ❌ | Tooling. |
| Build system | `cargo`, `xtask`-style | ❌ | SwiftPM. |
| Crate version semver | `semver` | T1 | |

---

[← Index](../README.md) · [Dependency graph](../DEPENDENCIES.md)
