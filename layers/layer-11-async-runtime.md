# Layer 11 — Async Runtime & I/O

| Field | Value |
|---|---|
| **Phase** | 3 — Async Reactor |
| **Effort** | 4–8 person-months — single biggest gating item |
| **Depends on** | [Layer 1](layer-01-primitives.md), [Layer 8](layer-08-filesystem-os.md), [Layer 10](layer-10-concurrency.md) |
| **Dependents** | [Layer 13](layer-13-tls-pki.md), [Layer 17](layer-17-networking-protocols.md), [Layer 18](layer-18-http-stack.md), [Layer 20](layer-20-databases-storage.md), [Layer 21](layer-21-observability.md), [Layer 27](layer-27-wasm-tooling.md), [Layer 28](layer-28-cloud-distributed.md) |

The big one. Without swift-nio, you must build the reactor yourself.

## Libraries

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| OS event loop | `mio`, `polling`, `mio-extras` | T3 | epoll/kqueue/IOCP/io_uring abstraction. |
| io_uring | `io-uring`, `tokio-uring`, `glommio`, `monoio`, `rio` | T4 | Linux-specific. |
| Async runtime | `tokio`, `async-std`, `smol`, `async-executor`, `async-global-executor`, `bastion`, `embassy-executor` | T4 | Swift has `Task`/executors; reactor + scheduler is the work. |
| Future combinators | `futures`, `futures-util`, `futures-core`, `futures-channel`, `futures-executor`, `futures-io`, `futures-macro`, `futures-sink`, `futures-task`, `futures-timer`, `futures-intrusive`, `futures-retry` | T2 | Swift `AsyncSequence` covers most. |
| Async traits | `async-trait`, `async-recursion` | ❌ | Swift native. |
| Async streams | `tokio-stream`, `async-stream`, `futures-async-stream` | ❌ | Swift `AsyncSequence`. |
| Async I/O | `tokio::io`, `async-fs`, `async-net`, `async-process` | T3 | |
| Codec framing | `tokio-util` (codec), `asynchronous-codec` | T2 | |
| Async timers | `tokio::time`, `futures-timer`, `wasm-timer` | T2 | |
| Single-threaded async | `monoio`, `glommio`, `tokio_uring` | T4 | |
| Compatibility layer | `async-compat`, `tokio-util` (compat) | T2 | |
| Scoped async | `async-scoped`, `tokio-scoped` | T3 | |
| Cancellation | `tokio-util` (cancellation), `stop-token` | T1 | Swift has Task.cancel. |
| Async fs | `async-fs`, `tokio::fs` | T2 | |
| Async DNS | `trust-dns-resolver`, `hickory-resolver`, `async-std-resolver` | T3 | |
| Pin projection | `pin-project`, `pin-project-lite`, `pin-utils` | ❌ | Swift doesn't need. |
| Async lock | `async-lock`, `tokio::sync::Mutex` | T1 | |

---

[← Index](../README.md) · [Dependency graph](../DEPENDENCIES.md)
