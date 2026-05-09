# Layer 8 — Filesystem & OS

| Field | Value |
|---|---|
| **Phase** | 2 — OS Layer |
| **Effort** | included in Phase 2 (3–5 person-months total) |
| **Depends on** | [Layer 1](layer-01-primitives.md) |
| **Dependents** | [Layer 9](layer-09-process-ipc.md), [Layer 11](layer-11-async-runtime.md), [Layer 22](layer-22-config-secrets.md), [Layer 23](layer-23-cli-terminal.md) |

## Libraries

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| POSIX wrapper | `nix`, `rustix`, `libc`, `linux-raw-sys` | ❌ | Bridge libc / direct syscalls. |
| Windows API | `windows`, `windows-sys`, `winapi` | ❌ | Bridge Win32. |
| File descriptor types | `io-lifetimes`, `io-extras` | T1 | Swift has `FileDescriptor` (System). |
| Errno wrapping | `errno`, `nix::errno` | T1 | swift-system has `Errno`. |
| Path utilities | `pathdiff`, `path-clean`, `path-absolutize`, `dunce`, `relative-path`, `camino`, `typed-path` | T1 | |
| Standard directories | `dirs`, `directories`, `directories-next`, `dirs-next`, `etcetera`, `home`, `shellexpand` | T1 | |
| Recursive walk | `walkdir`, `jwalk`, `ignore` | T1 | |
| Glob matching | `glob`, `globset`, `globwalk` | T2 | |
| Tempfiles | `tempfile`, `mktemp`, `tempdir` | T1 | |
| File locking | `fs2`, `fd-lock`, `file-lock` | T1 | |
| Memory-mapped files | `memmap`, `memmap2`, `fmmap` | T2 | |
| Symlinks | `symlink` | T1 | |
| Extended attributes | `xattr` | T1 | Bridge `getxattr`/`setxattr`. |
| File times | `filetime` | T1 | |
| Atomic file write | `atomicwrites`, `tempfile-fast` | T1 | |
| Filesystem watching | `notify`, `notify-debouncer-mini`, `hotwatch`, `watchexec` | T3 | inotify/FSEvents/ReadDirectoryChangesW. |
| Same-file detection | `same-file` | T1 | |
| Capability-based fs | `cap-std`, `cap-primitives`, `cap-fs-ext`, `cap-net-ext`, `cap-rand`, `cap-time-ext` | T3 | |
| Memfd | `memfd` | T1 | Linux-only. |
| Set times safely | `fs-set-times` | T1 | |
| Recursive copy | `fs_extra`, `copy_dir` | T1 | |
| Trash / recycle bin | `trash` | T2 | |
| User info / passwd | `users`, `pwd`, `whoami`, `uname` | T1 | |
| Hostname | `hostname`, `gethostname` | T1 | |
| /proc parsing | `procfs`, `rustix-linux-procfs` | T1 | Linux-only. |

---

[← Index](../README.md) · [Dependency graph](../DEPENDENCIES.md)
