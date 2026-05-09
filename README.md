# Bedrock

**Swift Systems Ecosystem Blueprint** — a comprehensive ecosystem architecture and implementation roadmap for transforming Swift 6 into a complete general-purpose systems programming platform from a minimal starting point (language + compiler + core stdlib only).

> No Foundation. No Dispatch. No SwiftNIO. No Swift Crypto. No Swift Collections. No Apple platform assumptions. No third-party packages.

The blueprint catalogs ~600+ libraries, primitives, and tools across 28 layers, each mapped to its Rust ecosystem equivalent, with portability tiers, build effort, and a layered dependency graph.

---

## Layout

| Path | Contents |
|---|---|
| [`layers/`](layers/) | One file per layer. Each contains a verdict table, dependencies, dependents, and effort. |
| [`DEPENDENCIES.md`](DEPENDENCIES.md) | Mermaid graph of inter-layer dependencies (renders inline on GitHub). |
| [`dependencies.dot`](dependencies.dot) · [`dependencies.svg`](dependencies.svg) | Graphviz source + rendered SVG. Regenerate with `dot -Tsvg dependencies.dot -o dependencies.svg`. |
| [`archive/bare-swift6-ecosystem.md`](archive/bare-swift6-ecosystem.md) | Original single-file blueprint. |

---

## Effort Tiers

- **T1 — Trivial** (hours to days): pure logic, single-file, no FFI, no platform syscalls
- **T2 — Straightforward** (days to weeks): well-specified protocols/formats, modest scope
- **T3 — Substantial** (weeks to months): large API surface, intricate state, performance-critical
- **T4 — Hard** (months to years): deeply tied to OS internals, async runtime, or wraps complex C
- **❌ Bridge C** — port doesn't make sense; use the C library through Swift's C interop

---

## Layer Index

### Phase 1 — Foundations (3–6 person-months)
- [Layer 0 — Language Stdlib Gaps](layers/layer-00-stdlib-gaps.md)
- [Layer 1 — Primitives, Bytes, Encodings](layers/layer-01-primitives.md)
- [Layer 2 — Text & Unicode](layers/layer-02-text-unicode.md)
- [Layer 3 — Collections & Data Structures](layers/layer-03-collections.md)
- [Layer 4 — Numeric & Math](layers/layer-04-numeric-math.md)
- [Layer 5 — Time, Date, Calendars](layers/layer-05-time-date.md)
- [Layer 6 — Random Numbers](layers/layer-06-random.md)
- [Layer 7 — Hashing (Non-crypto)](layers/layer-07-hashing.md)

### Phase 2 — OS Layer (3–5 person-months)
- [Layer 8 — Filesystem & OS](layers/layer-08-filesystem-os.md)
- [Layer 9 — Process, Signals, IPC](layers/layer-09-process-ipc.md)
- [Layer 10 — Concurrency Primitives](layers/layer-10-concurrency.md)

### Phase 3 — Async Reactor (4–8 person-months) — *single biggest gating item*
- [Layer 11 — Async Runtime & I/O](layers/layer-11-async-runtime.md)

### Phase 4 — Crypto + TLS (2–4 person-months; +6–12 if pure-Swift)
- [Layer 12 — Cryptography](layers/layer-12-cryptography.md)
- [Layer 13 — TLS & PKI](layers/layer-13-tls-pki.md)

### Phase 5 — Serialization (6–10 person-months)
- [Layer 14 — Serialization Framework](layers/layer-14-serialization-framework.md)
- [Layer 15 — Data Formats](layers/layer-15-data-formats.md)
- [Layer 16 — Compression](layers/layer-16-compression.md)

### Phase 6 — Networking (6–10 person-months)
- [Layer 17 — Networking Protocols](layers/layer-17-networking-protocols.md)
- [Layer 18 — HTTP Stack](layers/layer-18-http-stack.md)

### Phase 7 — Web Frameworks (3–5 person-months)
- [Layer 19 — Web Frameworks](layers/layer-19-web-frameworks.md)

### Phase 8 — Databases (8–14 person-months)
- [Layer 20 — Databases & Storage](layers/layer-20-databases-storage.md)

### Phase 9 — Observability (3–5 person-months)
- [Layer 21 — Observability](layers/layer-21-observability.md)

### Phase 10 — Configuration & CLI (3–6 person-months)
- [Layer 22 — Configuration & Secrets](layers/layer-22-config-secrets.md)
- [Layer 23 — CLI & Terminal](layers/layer-23-cli-terminal.md)

### Phase 11 — Macros & Codegen (1–3 person-months)
- [Layer 24 — Macros & Code Generation](layers/layer-24-macros-codegen.md)

### Phase 12 — Testing & Tooling (2–4 person-months)
- [Layer 25 — Testing, Fuzzing, Benchmarking](layers/layer-25-testing.md)

### Phase 13 — Compiler / Language Tooling (6–12 person-months)
- [Layer 26 — Compiler Infrastructure](layers/layer-26-compiler-infra.md)
- [Layer 27 — WebAssembly Tooling](layers/layer-27-wasm-tooling.md)

### Phase 14 — Specialized & Cloud (4–10 person-months core; multi-year for ML/GUI/graphics)
- [Layer 28 — Cloud, Distributed, Specialized](layers/layer-28-cloud-distributed.md)

---

## Total Effort

| Path | Estimate |
|---|---|
| Pragmatic baseline (bridge C aggressively) | **54–102 person-months** |
| Pure-Swift (no C bridges except OS syscalls) | **70–125 person-months** |
| Realistic team aim — Phases 1–9, "viable backend language" parity | 12–18 months for a team of 3–5 |

---

## Top 50 Highest-Leverage Ports

If you can only do 50 things, do these. Ranked by impact × portability:

1. `bytes` — refcounted byte buffer
2. mio-equivalent reactor — unlocks all networking
3. `http` types
4. `httparse`
5. hyper-equivalent (HTTP/1+2)
6. `winnow` — parser combinators
7. serde-equivalent on Swift macros
8. JSON (built on serde-equiv)
9. TLS bridging layer (BoringSSL/libsodium)
10. `url` + IDNA
11. Unicode tables (normalization + segmentation + properties)
12. jiff-equivalent — date/time
13. `uuid`
14. tracing-equivalent
15. metrics-equivalent + Prometheus exporter
16. tower-equivalent middleware
17. `matchit` router
18. axum-equivalent web framework
19. clap-equivalent CLI
20. `tokio-postgres` equivalent (Postgres)
21. `postgres-replication` (pgoutput parser)
22. SQLite bridge
23. sqlx-style compile-time SQL macros
24. `petgraph` — graphs
25. `indexmap` — order-preserving map
26. `smallvec` + `arrayvec`
27. slab/slotmap/id-arena
28. `aho-corasick`
29. `lexical-core` — fast number parsing
30. `pulldown-cmark` — Markdown
31. opentelemetry-equivalent
32. `sketches-ddsketch`
33. Sentry SDK
34. crossterm-equivalent
35. ratatui-equivalent (TUI)
36. `apache-avro`
37. Parquet reader (subset)
38. OpenDAL-equivalent
39. AWS SigV4 / `reqsign`
40. JWT / `jsonwebtoken`
41. OAuth2 / `yup-oauth2`
42. Kubernetes client + runtime
43. Tokio-tungstenite-equivalent (WebSockets)
44. Connection pooling (`r2d2`/`bb8`/`deadpool`)
45. `proptest`/`quickcheck`-equivalent
46. `insta`-equivalent (snapshot testing)
47. `criterion`-equivalent (benchmarking)
48. `tracing-tracy`/profiling integration
49. `wasmparser` + `wasmprinter` + `wast`
50. `cranelift-isle`

---

## What Should Always Stay Bridged C

Even in the most ambitious bare-Swift world, these don't make sense to port:

| Category | Reason |
|---|---|
| **OS syscalls** (libc, Win32, Mach) | The kernel ABI itself. |
| **TLS** (BoringSSL/OpenSSL) | Audited crypto + huge surface. |
| **Symmetric crypto primitives in production** | Constant-time guarantees outside vetted code are dangerous. |
| **zstd / zlib / libdeflate / brotli** | Mature, hand-tuned C; ports are slower. |
| **SQLite** | The C library *is* the spec. |
| **DuckDB** | C++ engine is the entire value. |
| **ICU / ICU4X full implementation** | Tables are massive and the C library is excellent. |
| **libgit2** | If you need git. |
| **wasmtime runtime / V8 / SpiderMonkey** | Bridge runtime C APIs. |
| **LLVM / MLIR** | If using for codegen. |
| **ffmpeg / libav** | Multimedia codecs. |
| **OpenCV / Tesseract / Whisper** | ML/CV C++ libraries. |
| **librdkafka, libzmq, libusb, libpq** (optional) | Battle-tested wire-protocol clients. |
| **jemalloc / mimalloc** | Allocator swap is fraught in Swift. |
| **libunwind / libbacktrace** | Stack unwinding ABI. |
| **tzdata** | Just ship the data file. |
| **CA root bundles** | Just ship the data file. |

---

## Strategy

This document is a map, not a roadmap. The right strategy isn't "port everything"; it's:

1. **Bridge C aggressively** at the OS, crypto, TLS, SQLite, and codec layers. These are the most-vetted, most-performance-critical pieces of software in the world; recreating them in Swift is a poor use of effort.
2. **Port pure-logic Rust crates** (parsers, data structures, algorithms, format codecs) where the value is the algorithm, not the Rust-specific machinery.
3. **Reframe macro-driven crates** (serde, sqlx, clap, tracing) on Swift macros + SwiftSyntax. The runtime traits are easy; the derive system is the work.
4. **Build the async reactor once**, carefully. It blocks every networking protocol downstream.
5. **Defer specialized layers** (ML, GUI, graphics, blockchain, embedded) until the foundations are solid.
