# Layer 10 — Concurrency Primitives

| Field | Value |
|---|---|
| **Phase** | 2 — OS Layer |
| **Effort** | included in Phase 2 (3–5 person-months total) |
| **Depends on** | [Layer 0](layer-00-stdlib-gaps.md) (atomics) |
| **Dependents** | [Layer 9](layer-09-process-ipc.md), [Layer 11](layer-11-async-runtime.md) |

## Libraries

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| Atomic operations | `portable-atomic`, `atomic`, `crossbeam-utils` | T1 | Swift Atomics. |
| Mutex / RwLock | `parking_lot`, `parking_lot_core`, `spin`, `try-lock`, `tracing-mutex` | T2 | |
| Lock abstractions | `lock_api`, `lockfree`, `loom` | T1 | |
| Channels (sync) | `crossbeam-channel`, `flume`, `kanal` | T3 | |
| Channels (async) | `async-channel`, `kanal`, `flume`, `tokio::sync::mpsc` | T3 | |
| Bounded SPSC ring | `ringbuf`, `rtrb`, `spsc-bip-buffer` | T1 | |
| Work-stealing deque | `crossbeam-deque` | T3 | Chase-Lev. |
| Epoch-based GC | `crossbeam-epoch`, `seize`, `haphazard` | T3 | Memory reclamation. |
| Once / OnceCell | `once_cell`, `lazy_static` | T1 | |
| Thread-local storage | `thread_local`, `os_thread_local` | T1 | |
| Atomic Arc swap | `arc-swap`, `aarc` | T2 | |
| Read-copy-update (RCU) | `rcu_cell`, `crossbeam-utils` | T3 | |
| Notify primitives | `event-listener`, `event-listener-strategy`, `atomic-waker`, `parking`, `local-waker`, `want` | T1 | |
| Barriers / countdown | `tokio::sync::Barrier`, `crossbeam-utils::sync::Parker` | T1 | |
| Rate limiting | `governor`, `leaky-bucket`, `ratelimit_meter`, `ratelimit` | T1 | |
| Concurrent queue | `concurrent-queue`, `crossbeam-queue` | T2 | |
| Backoff / retry | `backoff`, `backon`, `again`, `tokio-retry`, `fure`, `fail` | T1 | |
| Semaphore | `tokio::sync::Semaphore`, `async-semaphore` | T1 | |
| Async broadcast | `async-broadcast`, `tokio::sync::broadcast`, `postage` | T2 | |

---

[← Index](../README.md) · [Dependency graph](../DEPENDENCIES.md)
