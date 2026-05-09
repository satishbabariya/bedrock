# Layer 27 — WebAssembly Tooling

| Field | Value |
|---|---|
| **Phase** | 13 — Compiler / Language Tooling |
| **Effort** | included in Phase 13 (6–12 person-months total) |
| **Depends on** | [Layer 26](layer-26-compiler-infra.md), [Layer 11](layer-11-async-runtime.md) (WASI host I/O) |
| **Dependents** | downstream tooling |

## Libraries

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| WASM parser | `wasmparser` | T2 | |
| WASM encoder | `wasm-encoder` | T2 | |
| WASM printer | `wasmprinter` | T2 | |
| WAT parser | `wast`, `wat` | T2 | |
| WIT parser | `wit-parser` | T2 | |
| Component Model | `wit-component`, `wit-bindgen-core`, `wit-bindgen` | T3 | |
| WASM runtime | `wasmtime`, `wasmer`, `wasmi`, `wasmedge`, `wasm3-rs` | ❌ | Bridge wasmtime C API. |
| WASM compiler | `cranelift-codegen`, `winch-codegen`, `wasmtime-cranelift`, `wasmtime-internal-*` | T4 | |
| WASI | `wasmtime-wasi`, `wasmtime-wasi-io`, `wasmtime-wasi-http`, `wiggle` | T3 | |
| WIT bindgen language outputs | `wit-bindgen-rust`, `wit-bindgen-c`, `wit-bindgen-go` | T3 | Add Swift target. |
| WASM transformer | `walrus`, `wasm-opt`, `binaryen` | ❌ | Bridge binaryen. |
| WASM math intrinsics | `wasmtime-internal-math` | T1 | |
| WASM debugging | `wasmtime-internal-jit-debug` | T3 | |
| Stack switching | `wasmtime-internal-fiber` | T4 | |

---

[← Index](../README.md) · [Dependency graph](../DEPENDENCIES.md)
