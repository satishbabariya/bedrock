# Layer 9 — Process, Signals, IPC

| Field | Value |
|---|---|
| **Phase** | 2 — OS Layer |
| **Effort** | included in Phase 2 (3–5 person-months total) |
| **Depends on** | [Layer 8](layer-08-filesystem-os.md), [Layer 10](layer-10-concurrency.md) |
| **Dependents** | [Layer 23](layer-23-cli-terminal.md) (subprocess invocation) |

## Libraries

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| Process spawn / wait | `subprocess`, `duct`, `cmd_lib`, `command-group`, `os_pipe` | T2 | |
| Process info | `sysinfo`, `procfs`, `psutil`, `heim` | T2 | |
| Signal handling | `signal-hook`, `signal-hook-registry`, `signal-hook-tokio` | T2 | |
| Process groups | `process-control`, `command-group` | T2 | |
| Daemonization | `daemonize`, `daemon` | T2 | |
| Resource limits | `rlimit`, `rusage` | T1 | |
| Shared memory | `shared_memory`, `raw_sync`, `shmem-ipc` | T3 | |
| Pipes | `os_pipe`, `interprocess`, `nix::unistd::pipe` | T2 | |
| Unix domain sockets | `tokio::net::UnixStream`, `interprocess`, `nix` | T2 | |
| D-Bus | `zbus`, `dbus`, `dbus-rs` | T3 | Linux desktop only. |
| Mach IPC | `mach`, `mach2` | ❌ | Bridge Mach. |
| Pseudo-terminal (PTY) | `portable-pty`, `pty`, `pty-process` | T2 | |
| Spawn isolated | `nsjail-rs`, `extrasafe` | T3 | Linux namespaces. |

---

[← Index](../README.md) · [Dependency graph](../DEPENDENCIES.md)
