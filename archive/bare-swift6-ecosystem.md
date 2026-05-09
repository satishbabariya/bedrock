# Bare Swift 6 Ecosystem — Complete Library Requirements

**Goal:** Catalogue every library category Swift 6 needs to become a viable language for systems programming, backend services, data engineering, and general development — assuming Swift has *only* the language and core stdlib. No Foundation, no Dispatch, no swift-nio, no swift-crypto, no swift-collections, no third-party packages.

**Source material:** The full Rust ecosystem on crates.io. Categories below cover the most-depended-upon crates as well as specialized libraries needed for compilers, databases, networking, distributed systems, observability, cryptography, and developer tooling.

**Scope:** Comprehensive. ~600+ crates organized into 28 layers with portability tiers and a build order. Every layer ends with a verdict table.

---

## Table of Contents

1. [Effort Tiers](#effort-tiers)
2. [Layer 0 — Language Stdlib Gaps](#layer-0--language-stdlib-gaps)
3. [Layer 1 — Primitives, Bytes, Encodings](#layer-1--primitives-bytes-encodings)
4. [Layer 2 — Text & Unicode](#layer-2--text--unicode)
5. [Layer 3 — Collections & Data Structures](#layer-3--collections--data-structures)
6. [Layer 4 — Numeric & Math](#layer-4--numeric--math)
7. [Layer 5 — Time, Date, Calendars](#layer-5--time-date-calendars)
8. [Layer 6 — Random Numbers](#layer-6--random-numbers)
9. [Layer 7 — Hashing (Non-crypto)](#layer-7--hashing-non-crypto)
10. [Layer 8 — Filesystem & OS](#layer-8--filesystem--os)
11. [Layer 9 — Process, Signals, IPC](#layer-9--process-signals-ipc)
12. [Layer 10 — Concurrency Primitives](#layer-10--concurrency-primitives)
13. [Layer 11 — Async Runtime & I/O](#layer-11--async-runtime--io)
14. [Layer 12 — Cryptography](#layer-12--cryptography)
15. [Layer 13 — TLS & PKI](#layer-13--tls--pki)
16. [Layer 14 — Serialization Framework](#layer-14--serialization-framework)
17. [Layer 15 — Data Formats](#layer-15--data-formats)
18. [Layer 16 — Compression](#layer-16--compression)
19. [Layer 17 — Networking Protocols](#layer-17--networking-protocols)
20. [Layer 18 — HTTP Stack](#layer-18--http-stack)
21. [Layer 19 — Web Frameworks](#layer-19--web-frameworks)
22. [Layer 20 — Databases & Storage](#layer-20--databases--storage)
23. [Layer 21 — Observability](#layer-21--observability)
24. [Layer 22 — Configuration & Secrets](#layer-22--configuration--secrets)
25. [Layer 23 — CLI & Terminal](#layer-23--cli--terminal)
26. [Layer 24 — Macros & Code Generation](#layer-24--macros--code-generation)
27. [Layer 25 — Testing, Fuzzing, Benchmarking](#layer-25--testing-fuzzing-benchmarking)
28. [Layer 26 — Compiler Infrastructure](#layer-26--compiler-infrastructure)
29. [Layer 27 — WebAssembly Tooling](#layer-27--webassembly-tooling)
30. [Layer 28 — Cloud, Distributed, Specialized](#layer-28--cloud-distributed-specialized)
31. [Recommended Build Order](#recommended-build-order)
32. [Total Effort Estimate](#total-effort-estimate)

---

## Effort Tiers

- **T1 — Trivial** (hours to days): pure logic, single-file, no FFI, no platform syscalls
- **T2 — Straightforward** (days to weeks): well-specified protocols/formats, modest scope
- **T3 — Substantial** (weeks to months): large API surface, intricate state, performance-critical
- **T4 — Hard** (months to years): deeply tied to OS internals, async runtime, or wraps complex C
- **❌ Bridge C** — port doesn't make sense; use the C library through Swift's C interop

---

## Layer 0 — Language Stdlib Gaps

Things Swift's stdlib already partially handles but where Rust crates fill gaps. These need either stdlib evolution or polyfill libraries.

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

## Layer 1 — Primitives, Bytes, Encodings

The absolute foundation. Without these, no I/O, no protocols, nothing.

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| Refcounted byte buffer | `bytes`, `bytestring` | T2 | `ByteBuffer` is the cornerstone of all I/O. |
| Endian-safe integer reads | `byteorder`, `endian-num` | T1 | Wraps `loadUnaligned` + byte-swap. |
| LEB128 / varint codec | `leb128`, `leb128fmt`, `integer-encoding`, `varint` | T1 | Few hundred LOC. |
| ZigZag encoding | `integer-encoding` | T1 | |
| Hex codec | `hex`, `base16ct` | T1 | Trivial. |
| Base64 | `base64`, `base64ct`, `base64-simd`, `data-encoding` | T1 | Constant-time variant for crypto. |
| Base32 / Base58 / Base85 | `base32`, `bs58`, `ascii85`, `data-encoding` | T1 | |
| Percent encoding | `percent-encoding` | T1 | RFC 3986. |
| Form encoding | `form_urlencoded`, `serde_urlencoded` | T1 | |
| URL/URI parser | `url`, `iri-string`, `fluent-uri` | T3 | WHATWG/RFC 3986 + IDNA. |
| IDNA / Punycode | `idna`, `idna_adapter`, `unicode-normalization` | T2 | Spec-driven. |
| UUID | `uuid`, `ulid` | T1 | v4/v7/ULID all simple. |
| Bit manipulation | `bit-set`, `bitvec`, `fixedbitset`, `bitflags` | T1 | Swift `OptionSet` covers some. |
| SIMD UTF-8 validation | `simdutf8`, `simdutf` | T2 | Substantially faster than per-scalar. |
| Cobs / consistent overhead byte stuffing | `cobs` | T1 | |
| Tagged pointers | `tagptr` | T2 | |
| Zero-copy views | `zerocopy`, `bytemuck`, `safe-transmute`, `plain` | T2 | Swift has `withUnsafeBytes` + `loadUnaligned`. |

---

## Layer 2 — Text & Unicode

Swift's `String` is Unicode-correct, but its underlying tables come from the OS's ICU. Without Foundation/ICU, you must ship the tables yourself.

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| Unicode normalization (NFC/NFD/NFKC/NFKD) | `unicode-normalization`, `icu_normalizer`, `icu_normalizer_data` | T3 | Tables. |
| Grapheme/word/sentence segmentation (UAX #29) | `unicode-segmentation`, `icu_segmenter` | T3 | Tables. |
| Bidirectional algorithm (UAX #9) | `unicode-bidi` | T3 | |
| East Asian width | `unicode-width` | T2 | |
| Identifier classification (UAX #31) | `unicode-ident`, `unicode-xid` | T1 | |
| General properties | `unicode-properties`, `icu_properties`, `icu_properties_data` | T3 | Tables. |
| Casefolding / case mapping | `caseless`, `unicode_categories`, `icu_casemap` | T2 | |
| Script detection | `whatlang`, `lingua` | T2 | |
| Locale tags / BCP 47 | `language-tags`, `icu_locale_core`, `oxilangtag` | T2 | |
| ICU4X (modular Unicode) | `icu`, `icu_collections`, `icu_provider`, `icu_collator`, `icu_calendar`, `icu_decimal`, `icu_datetime`, `icu_list`, `icu_plurals`, `icu_relativetime`, `tinystr`, `litemap`, `potential_utf`, `utf8_iter`, `writeable`, `yoke`, `zerofrom`, `zerotrie`, `zerovec` | T4 | Massive but modular. Port what you need. |
| Stringprep (RFC 3454) | `stringprep` | T1 | |
| Case-insensitive ASCII | `unicase`, `caseless` | T1 | |
| Confusables / IDN security | `unicode-security`, `confusable_detector` | T2 | |
| String similarity | `strsim`, `triple_accel`, `edit-distance` | T1 | |
| Fuzzy matching | `fuzzy-matcher`, `nucleo`, `fuzzy_search` | T2 | |
| Character set detection | `chardet`, `chardetng`, `encoding_rs` | T3 | |
| Legacy text encodings | `encoding_rs`, `encoding`, `iconv` | T3 | gb18030, Shift-JIS, EUC-KR, etc. Or bridge ICU. |

---

## Layer 3 — Collections & Data Structures

Swift's stdlib has `Array`, `Dictionary`, `Set`. swift-collections adds `Deque`, `OrderedSet`, `OrderedDictionary`. Bare Swift needs all of this and more.

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| SwissTable hashmap | `hashbrown` | T3 | Or use Swift `Dictionary`. |
| Order-preserving hashmap | `indexmap`, `linked-hash-map`, `linked_hash_set` | T2 | swift-collections has `OrderedDictionary`. |
| BTree map/set | (Rust stdlib) | T2 | Swift stdlib lacks; swift-collections has `TreeDictionary`. |
| Multimap | `multimap`, `multi_index_map`, `ordered-multimap` | T1 | |
| Bidirectional map | `bimap`, `bimap-rs` | T1 | |
| Concurrent hashmap | `dashmap`, `chashmap`, `flurry`, `scc` | T3 | Subtle correctness; Swift actors usually suffice. |
| LRU cache | `lru`, `clru`, `lru-cache` | T1 | |
| TinyLFU / W-TinyLFU cache | `moka`, `mini-moka` | T3 | High value over plain LRU. |
| ARC cache | `caches` | T2 | |
| Inline-storage vector | `smallvec`, `tinyvec`, `arrayvec`, `staticvec` | T2 | Swift lacks a great equivalent. |
| Bounded deque | `arraydeque`, `circular-buffer` | T1 | |
| Generational arena | `slab`, `slotmap`, `id-arena`, `generational-arena`, `thunderdome` | T1 | Compiler bread-and-butter. |
| Bump allocator | `bumpalo`, `typed-arena` | T1 | |
| Concurrent slab | `sharded-slab` | T3 | |
| Linked list (intrusive) | `intrusive-collections` | T3 | Swift has classes for this. |
| Doubly-linked list | `dlv-list`, `linked-list` | T1 | |
| Priority queue | `priority-queue`, `keyed_priority_queue`, `binary-heap-plus`, `min-max-heap` | T1 | |
| Skip list | `skiplist`, `crossbeam-skiplist` | T2 | |
| Trie | `radix_trie`, `qp-trie`, `patricia_tree`, `art-tree`, `fst` | T2 | |
| Roaring bitmap | `roaring`, `croaring` | T2 | Compressed bitsets. |
| Bloom filter | `bloomfilter`, `bloom`, `growable-bloom-filter` | T1 | |
| Cuckoo filter | `cuckoofilter` | T2 | |
| HyperLogLog | `hyperloglog`, `hyperloglogplus`, `streaming_algorithms` | T2 | |
| Count-min sketch | `count_min_sketch` | T1 | |
| Disjoint-set / union-find | `disjoint-sets`, `union-find` | T1 | |
| Graph | `petgraph`, `daggy`, `dot`, `graphlib` | T2 | |
| Interval tree | `intervaltree`, `rust_lapper` | T2 | |
| R-tree / spatial index | `rstar`, `spade`, `kdtree` | T3 | |
| Persistent / immutable | `im`, `rpds`, `archery` | T3 | |
| Vec of options (compact) | `dense-vec` | T1 | |
| Append-only growable | `boxcar`, `growable-bloom-filter` | T2 | |
| Range/interval set | `iset`, `range-collections`, `rangemap` | T2 | |

---

## Layer 4 — Numeric & Math

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| Bigint / bignum | `num-bigint`, `num-bigint-dig`, `crypto-bigint`, `ibig`, `dashu`, `malachite` | T3 | |
| Rationals | `num-rational`, `fraction` | T2 | |
| Complex | `num-complex` | T1 | |
| Arbitrary-precision decimal | `bigdecimal`, `rug`, `decimal-rs` | T3 | |
| Fixed-precision decimal | `rust_decimal`, `fixed`, `fpdec` | T2 | |
| Half-precision floats | `half` | T1 | Swift has `Float16`. |
| BFloat16 | `bf16` | T1 | |
| GMP/MPFR bindings | `rug`, `gmp-mpfr-sys` | ❌ | Bridge libgmp. |
| Statistics | `statrs`, `statistical`, `average`, `criterion-stats` | T2 | |
| Linear algebra | `nalgebra`, `ndarray`, `ndarray-linalg`, `cgmath`, `glam`, `ultraviolet`, `simba`, `vek` | T3 | Each is a full project. |
| BLAS / LAPACK | `blas`, `lapack`, `openblas-src`, `intel-mkl-src` | ❌ | Bridge native. |
| Random / probability | `rand_distr`, `probability` | T2 | |
| Polynomial / numerical | `roots`, `argmin`, `optimize` | T2 | |
| Number theory | `primes`, `prime_factorization`, `is-prime` | T1 | |
| Floating-point comparison | `float-cmp`, `approx`, `assert_float_eq` | T1 | |
| Saturating / checked arithmetic | `saturating`, `num-traits` | T1 | Swift has `&+`, `addingReportingOverflow`. |
| Quaternions | `quaternion` | T1 | |
| FFT | `rustfft`, `realfft` | T3 | |
| GIS / geo | `geo`, `geo-types`, `proj`, `geographiclib` | T3 | |

---

## Layer 5 — Time, Date, Calendars

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| Wall clock + duration | `chrono`, `time`, `jiff` | T3 | `jiff` is the modern best-designed option. |
| Monotonic clock | `instant`, `web-time`, `quanta`, `coarsetime` | T1 | Swift `ContinuousClock` exists. |
| TZ database | `chrono-tz`, `tzdb`, `tz-rs`, `iana-time-zone` | T3 | Need to ship/embed tzdata. |
| Cron expression | `cron`, `croner`, `cron_clock`, `saffron` | T2 | |
| Time intervals | `time-fmt`, `humantime`, `humantime-serde`, `parse_duration` | T1 | |
| Calendar arithmetic | `chronoutil`, `icu_calendar` | T2 | |
| Date format parsing | `dateparser`, `dtparse` | T2 | |
| ISO 8601 / RFC 3339 | `time` formats, `chrono` formats | T1 | |

---

## Layer 6 — Random Numbers

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| RNG framework | `rand`, `rand_core` | T2 | |
| OS entropy | `getrandom` | T1 | Bridge `getrandom` / `SecRandomCopyBytes`. |
| ChaCha PRNG | `rand_chacha` | T2 | |
| Xoshiro / Xorshift | `rand_xoshiro`, `rand_xorshift` | T1 | |
| PCG | `rand_pcg` | T1 | |
| Fast non-crypto | `fastrand`, `nanorand`, `oorandom`, `wyrand` | T1 | |
| Distributions | `rand_distr`, `statrs` | T2 | |
| Sampling / shuffling | `rand`, `rand_seeder` | T1 | |
| Hardware RNG | `rdrand` | T2 | |

---

## Layer 7 — Hashing (Non-crypto)

Distinct from cryptographic hashing — these are for hashmaps, partitioning, fingerprints.

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| SipHash | `siphasher` | T1 | Swift's default already. |
| FxHash | `fxhash`, `rustc-hash`, `fxhash-shootout` | T1 | |
| AHash | `ahash` | T1 | |
| FoldHash | `foldhash` | T1 | |
| xxHash | `twox-hash`, `xxhash-rust` | T1 | |
| MetroHash | `metrohash` | T1 | |
| Murmur3 | `murmur3`, `mur3`, `fasthash` | T1 | |
| SeaHash | `seahash` | T1 | |
| HighwayHash | `highway` | T2 | |
| CityHash / FarmHash | `cityhasher`, `farmhash` | T2 | |
| CRC | `crc`, `crc-catalog`, `crc32fast`, `crc32c`, `crc-any` | T1 | |
| Adler-32 | `adler`, `adler2`, `simd-adler32` | T1 | |
| Fletcher | `fletcher` | T1 | |

---

## Layer 8 — Filesystem & OS

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

## Layer 9 — Process, Signals, IPC

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

## Layer 10 — Concurrency Primitives

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

## Layer 11 — Async Runtime & I/O

The big one. Without swift-nio, you must build the reactor yourself.

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

## Layer 12 — Cryptography

Production rule: bridge BoringSSL or libsodium. Pure-Swift crypto without audited libraries is dangerous. Listed for completeness.

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| Crypto provider | `ring`, `aws-lc-rs`, `aws-lc-sys`, `openssl`, `boring`, `boring-sys`, `mbedtls` | ❌ | Bridge BoringSSL. |
| SHA-2 family | `sha2` | T1 | |
| SHA-3 / Keccak | `tiny-keccak`, `sha3`, `keccak` | T2 | |
| SHA-1 (legacy) | `sha1`, `sha1_smol` | T1 | |
| MD5 (legacy) | `md-5`, `md5` | T1 | |
| BLAKE2 / BLAKE3 | `blake2`, `blake3` | T2 | BLAKE3 has SIMD. |
| RIPEMD | `ripemd` | T1 | |
| HMAC | `hmac` | T1 | |
| HKDF | `hkdf` | T1 | |
| Hash trait | `digest`, `block-buffer`, `crypto-common`, `generic-array`, `hybrid-array` | T1 | |
| AES | `aes`, `aes-soft`, `aes-gcm`, `aes-gcm-siv`, `aes-siv` | T2 | |
| ChaCha20 / Poly1305 | `chacha20`, `chacha20poly1305`, `poly1305` | T2 | |
| AEAD trait | `aead` | T1 | |
| Salsa20 | `salsa20` | T1 | |
| KDF / Argon2 / scrypt / bcrypt / PBKDF2 | `argon2`, `scrypt`, `bcrypt`, `pbkdf2`, `password-hash` | T2 | |
| RSA | `rsa` | T3 | BigInt + side-channels. |
| ECDSA | `ecdsa`, `k256`, `p256`, `p384`, `p521` | T3 | |
| EdDSA | `ed25519`, `ed25519-dalek`, `ed25519-compact` | T3 | |
| Curve25519 | `curve25519-dalek`, `x25519-dalek` | T4 | Constant-time arithmetic. |
| Elliptic curve trait | `elliptic-curve`, `group`, `ff`, `primeorder` | T2 | |
| Constant-time bigint | `crypto-bigint`, `num-bigint-dig` | T3 | |
| Signature trait | `signature` | T1 | |
| Deterministic ECDSA | `rfc6979` | T1 | |
| Constant-time helpers | `subtle`, `constant_time_eq`, `cmov` | T2 | |
| Memory zeroization | `zeroize`, `zeroize_derive`, `secrecy` | T2 | Hard with ARC. |
| Secret management | `secrecy`, `redact` | T1 | |
| CPU feature detect | `cpufeatures` | T1 | |
| Universal hash | `universal-hash` | T1 | |
| Cipher trait | `cipher`, `inout` | T1 | |
| Streaming cipher | `stream-cipher`, `chacha20` | T1 | |
| Threshold / MPC | `frost-core`, `vsss-rs`, `verifiable-secret-sharing` | T4 | |
| Homomorphic encryption | `concrete`, `tfhe` | ❌ | Bridge. |
| Post-quantum | `pqcrypto`, `kyber`, `dilithium`, `sphincs+` | T4 | |
| Zero-knowledge | `arkworks`, `bellman`, `bulletproofs`, `halo2` | T4 | |
| Random | (see Layer 6) | | |

---

## Layer 13 — TLS & PKI

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| TLS implementation | `rustls`, `native-tls`, `openssl`, `boring`, `s2n-tls`, `mbedtls` | T4 | Bridge BoringSSL. |
| TLS-over-async | `tokio-rustls`, `tokio-native-tls`, `async-tls`, `async-native-tls` | T1 | |
| Cert validation | `rustls-webpki`, `webpki` | T4 | Bridge a vetted impl. |
| Cert types | `rustls-pki-types` | T1 | |
| OS trust store | `rustls-native-certs`, `native-tls`, `system-configuration` | T2 | |
| PEM parsing | `pem`, `pem-rfc7468`, `rustls-pemfile` | T1 | |
| Mozilla root CA bundle | `webpki-roots`, `webpki-root-certs` | T1 | Just data. |
| ASN.1 / DER | `der`, `der_derive`, `asn1`, `asn1-rs`, `picky-asn1`, `rasn`, `simple_asn1` | T3 | |
| X.509 cert | `x509-cert`, `x509-parser`, `picky` | T3 | |
| PKCS encodings | `pkcs1`, `pkcs5`, `pkcs7`, `pkcs8`, `pkcs10`, `pkcs12`, `cms` | T2 | |
| SEC1 | `sec1` | T1 | |
| SPKI | `spki` | T1 | |
| OID | `const-oid`, `oid-registry` | T1 | |
| OCSP | `ocsp`, `rasn-ocsp` | T2 | |
| Certificate Transparency | `ct-log-parser` | T2 | |
| Certificate generation | `rcgen` | T2 | |
| ACME / Let's Encrypt | `acme-lib`, `acme-micro`, `instant-acme` | T2 | |
| QUIC | `quinn`, `quiche`, `s2n-quic`, `neqo` | T4 | |
| Noise protocol | `snow` | T2 | |

---

## Layer 14 — Serialization Framework

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| Generic serialization | `serde`, `serde_core`, `serde_derive`, `miniserde`, `nanoserde`, `gros`, `deser-hjson` | T3 | Reframe on Swift macros. |
| Serde adapters | `serde_with`, `serde_with_macros`, `serde_repr`, `serde_bytes` | T2 | |
| Path-aware errors | `serde_path_to_error` | T1 | |
| Span-preserving | `serde_spanned` | T1 | |
| Trait-object serialization | `erased-serde`, `typetag`, `typetag-impl` | T2 | |
| Serde test helpers | `serde_test` | T1 | |
| Validation | `validator`, `garde`, `validify` | T2 | |
| JSON Schema generation | `schemars`, `schemars_derive`, `okapi`, `schemafy` | T2 | |
| OpenAPI generation | `utoipa`, `utoipa-gen`, `aide`, `okapi`, `paperclip`, `apistos` | T3 | High value with Swift macros. |
| OpenAPI client codegen | `progenitor`, `openapi-generator` | T3 | |
| Reflection | `reflect`, `bevy_reflect` | T3 | Swift Mirror is limited. |

---

## Layer 15 — Data Formats

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| JSON | `serde_json`, `simd-json`, `sonic-rs`, `json`, `tinyjson`, `jzon` | T2 | |
| JSON Patch (RFC 6902) | `json-patch` | T1 | |
| JSON Pointer (RFC 6901) | `jsonptr`, `serde_json_path` | T1 | |
| JSONPath | `jsonpath-rust`, `jsonpath_lib`, `jsonpath-plus`, `jsonpath` | T2 | |
| JSON5 | `json5`, `serde_json5` | T2 | |
| YAML 1.1 | `serde_yaml` (deprecated), `yaml-rust` | T2 | |
| YAML 1.2 | `yaml-rust2`, `serde_yml`, `serde_yaml_ng`, `saphyr` | T2 | |
| TOML | `toml`, `toml_edit`, `basic-toml` | T2 | |
| TOML internals | `toml_datetime`, `toml_parser`, `toml_write`, `toml_writer`, `winnow-toml` | T1 | |
| RON | `ron`, `serde_ron` | T1 | |
| HJSON | `deser-hjson`, `serde-hjson` | T1 | |
| INI | `rust-ini`, `ini`, `configparser`, `tini` | T1 | |
| XML | `quick-xml`, `xml-rs`, `roxmltree`, `xmltree`, `serde-xml-rs`, `yaserde`, `xot` | T2 | |
| HTML parser | `html5ever`, `scraper`, `select`, `kuchiki`, `tl`, `html_parser` | T3 | |
| CommonMark / Markdown | `pulldown-cmark`, `markdown`, `comrak`, `cmark-gfm`, `mdast-rs` | T3 | |
| reStructuredText | `restruct` | T2 | |
| AsciiDoc | `asciidoc-rs` | T3 | |
| LaTeX | `texrender`, `latex2mathml` | T3 | |
| MessagePack | `rmp`, `rmp-serde`, `messagepack-rs` | T2 | |
| CBOR | `ciborium`, `serde_cbor`, `minicbor`, `cbor4ii` | T2 | |
| BSON | `bson`, `bson2` | T2 | |
| Bincode | `bincode`, `bincode-derive` | T2 | |
| Postcard | `postcard`, `postcard-rpc` | T1 | |
| Borsh | `borsh`, `borsh-derive` | T2 | |
| Pot | `pot` | T2 | |
| Speedy | `speedy`, `speedy-derive` | T2 | |
| rkyv (zero-copy) | `rkyv`, `rkyv_derive`, `rend`, `bytecheck`, `ptr_meta` | T4 | Layout-tricky. |
| Cap'n Proto | `capnp`, `capnp-rpc` | T3 | |
| FlatBuffers | `flatbuffers`, `planus` | T3 | |
| Protobuf | `prost`, `prost-derive`, `prost-build`, `prost-types`, `pbjson`, `quick-protobuf`, `protobuf`, `rust-protobuf` | T3 | |
| Avro | `apache-avro`, `avro-rs`, `avrow` | T2 | |
| Parquet | `parquet`, `parquet2` | T4 | Major. |
| Arrow | `arrow`, `arrow2`, `arrow-array`, `arrow-buffer`, `arrow-schema`, `arrow-cast`, `arrow-data`, `arrow-arith`, `arrow-csv`, `arrow-ipc`, `arrow-json`, `arrow-ord`, `arrow-row`, `arrow-select`, `arrow-string` | T4 | |
| ORC | `orc-rust`, `datafusion-orc` | T4 | |
| Thrift | `thrift` | T3 | |
| ASN.1 BER/DER | (see Layer 13) | | |
| CSV | `csv`, `csv-core`, `csv-async` | T2 | |
| TSV / DSV | `csv` | T1 | |
| Excel (xlsx) | `calamine`, `umya-spreadsheet`, `rust_xlsxwriter`, `xlsx-write` | T3 | |
| ODS / Open Document | `calamine` | T2 | |
| PDF | `lopdf`, `printpdf`, `pdf-extract`, `genpdf`, `pdfium-render` | T3 | |
| EPUB | `epub`, `epub-builder` | T2 | |
| PostScript | `printpdf` | T2 | |
| SVG | `svg`, `usvg`, `resvg`, `svgtypes`, `roxmltree` | T3 | |
| Image (PNG/JPEG/etc) | `image`, `imagequant`, `kornia-rs`, `oxipng`, `mozjpeg`, `webp`, `avif`, `imageproc` | T3 | |
| Color | `palette`, `color-art`, `csscolorparser` | T2 | |
| Audio formats | `symphonia`, `hound`, `claxon`, `lewton`, `mp3`, `minimp3`, `ogg` | T3 | |
| Video formats | `ffmpeg-next`, `gstreamer-rs` | ❌ | Bridge ffmpeg. |
| Geographic | `geojson`, `gpx`, `kml`, `shapefile`, `osm-pbf` | T2 | |
| RDF / Semantic Web | `oxrdf`, `oxigraph`, `sophia` | T3 | |
| GraphQL | `async-graphql`, `juniper`, `cynic` | T3 | |
| gRPC reflection | `tonic-reflection` | T2 | |
| 3D / mesh | `gltf`, `obj`, `ply-rs`, `fbx` | T3 | |
| Crypto formats | `pem`, `pkcs8`, `ssh-key`, `osshkeys` | T2 | |

---

## Layer 16 — Compression

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| Deflate / gzip / zlib | `flate2`, `miniz_oxide`, `zlib-rs`, `libdeflate-rs`, `libz-sys` | ❌/T3 | Bridge zlib for prod; pure port for fun. |
| Zopfli (slow optimal Deflate) | `zopfli` | T2 | |
| Brotli | `brotli`, `brotli-decompressor`, `brotlic` | T3 | |
| zstd | `zstd`, `zstd-safe`, `zstd-sys`, `ruzstd` | ❌/T4 | Bridge libzstd. `ruzstd` is pure-Rust. |
| LZ4 | `lz4`, `lz4_flex`, `lz4-sys` | T2 | |
| Snappy | `snap`, `snappy` | T1 | |
| LZMA / xz | `xz2`, `lzma-rs`, `lzma-sys` | ❌ | Bridge liblzma. |
| BZip2 | `bzip2`, `bzip2-rs` | ❌/T3 | |
| LZO | `minilzo-rs` | T2 | |
| LZW | `lzw`, `weezl` | T1 | |
| Tar archive | `tar` | T1 | |
| ZIP archive | `zip`, `async_zip`, `rc-zip` | T2 | |
| 7z | `sevenz-rust`, `lzma-rs` | T3 | |
| RAR | `unrar` | ❌ | Bridge. |
| Compression abstraction | `async-compression`, `compression-codecs`, `compression-core` | T1 | |
| Streaming Deflate | `inflate`, `deflate` | T2 | |

---

## Layer 17 — Networking Protocols

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| Sockets | `socket2`, `mio` | T2 | |
| IP types | `ipnet`, `ipnetwork`, `cidr`, `ip_network` | T1 | |
| Network interface enumeration | `if-addrs`, `pnet`, `pcap` | T2 | |
| MAC address | `mac_address`, `eui48` | T1 | |
| DNS protocol | `hickory-proto`, `trust-dns-proto`, `domain` | T3 | |
| DNS resolver | `hickory-resolver`, `trust-dns-resolver`, `dns-lookup`, `async-resolver` | T3 | |
| resolv.conf | `resolv-conf` | T1 | |
| mDNS | `mdns-sd`, `astro-dnssd`, `searchlight` | T2 | |
| DHCP | `dhcp4r`, `dhcparse` | T2 | |
| FTP | `ftp`, `suppaftp`, `async-ftp` | T2 | |
| SSH client | `ssh2`, `russh`, `thrussh`, `osshkeys` | ❌/T4 | Bridge libssh2. |
| SSH key formats | `ssh-key`, `osshkeys` | T2 | |
| SFTP | `russh-sftp`, `ssh2` | T3 | |
| SMTP | `lettre`, `mail-send`, `samotop` | T2 | |
| IMAP | `imap`, `async-imap` | T3 | |
| POP3 | `pop3`, `async-pop` | T2 | |
| MIME / email parsing | `mail-parser`, `mailparse`, `email-encoding` | T2 | |
| WebSockets | `tokio-tungstenite`, `tungstenite`, `async-tungstenite`, `fastwebsockets`, `ws` | T2 | |
| TCP/UDP framing | `tokio-util` (codec) | T2 | |
| MQTT | `rumqttc`, `paho-mqtt`, `mqtt-protocol` | T2 | |
| AMQP / RabbitMQ | `lapin`, `amiquip` | T3 | |
| Kafka | `rdkafka`, `kafka-rust`, `rust-rdkafka`, `samsa` | ❌/T3 | Bridge librdkafka. |
| NATS | `async-nats`, `nats` | T2 | |
| Redis protocol | `redis`, `redis-protocol`, `fred`, `bb8-redis`, `deadpool-redis` | T2 | |
| Memcached | `memcache`, `async-memcached` | T2 | |
| ZeroMQ | `zmq`, `async-zmq` | ❌ | Bridge libzmq. |
| MsgPack-RPC | `rmp-rpc` | T2 | |
| JSON-RPC | `jsonrpsee`, `jsonrpc-core`, `jsonrpc-v2` | T2 | |
| OSC | `rosc` | T1 | |
| Modbus | `tokio-modbus`, `rmodbus` | T2 | |
| BLE / Bluetooth | `btleplug`, `bluer`, `bluest` | T3 | |
| Serial port | `serialport`, `tokio-serial`, `mio-serial` | T2 | |
| CoAP | `coap`, `coap-lite` | T2 | |
| RTP / RTCP | `webrtc-rtp`, `rtp-rs` | T3 | |
| STUN/TURN/ICE | `stun-rs`, `webrtc-rs` | T3 | |
| WebRTC | `webrtc-rs`, `str0m` | T4 | |
| QUIC | `quinn`, `quiche`, `s2n-quic`, `neqo` | T4 | |
| HTTP/3 | `h3`, `s2n-quic-h3`, `quiche` | T4 | |
| Network namespaces | `netns-rs`, `rtnetlink` | T3 | Linux. |
| Packet manipulation | `pnet`, `etherparse`, `pdu` | T3 | |
| Tun/Tap | `tun`, `tun-tap`, `wintun` | T3 | |
| Wireguard | `boringtun`, `wireguard-rs` | T4 | |
| Tor | `arti`, `tor-client` | T4 | |
| BitTorrent | `lava_torrent`, `librqbit` | T4 | |
| QUIC framing | `quinn-proto`, `quiche` | T3 | |
| TLS-PSK | `rustls` (via custom config) | T2 | |

---

## Layer 18 — HTTP Stack

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| HTTP types | `http`, `http-body`, `http-body-util` | T1 | |
| HTTP/1 parser | `httparse` | T2 | |
| HTTP date | `httpdate` | T1 | |
| HTTP/1+2 server/client | `hyper`, `hyper-util` | T3 | |
| HTTP/2 | `h2`, `nghttp2` | T3 | HPACK + state machine. |
| HTTP/3 | `h3`, `quiche` | T4 | |
| TLS-on-HTTP | `hyper-tls`, `hyper-rustls`, `hyper-openssl` | T1 | |
| Proxy support | `hyper-http-proxy`, `hyper-proxy` | T2 | |
| HTTP timeouts | `hyper-timeout` | T1 | |
| HTTP middleware | `tower`, `tower-http`, `tower-layer`, `tower-service` | T2 | |
| URL router | `matchit`, `route-recognizer`, `path-tree`, `pathmatcher` | T2 | |
| Strongly-typed headers | `headers`, `headers-core`, `accept-language` | T2 | |
| MIME types | `mime`, `mime_guess`, `infer` | T1 | |
| Content negotiation | `accept-language`, `mediatype` | T1 | |
| HTTP client high-level | `reqwest`, `ureq`, `isahc`, `surf`, `awc`, `attohttpc`, `minreq` | T3 | |
| HTTP signatures | `http-signature-normalization`, `httpsig` | T2 | |
| Cookies | `cookie`, `cookie_store` | T2 | |
| HTTP caching | `http-cache`, `http-cache-semantics` | T2 | |
| HTTP mocking | `wiremock`, `mockito`, `httpmock` | T2 | |
| Server-Sent Events | `sse-codec`, `eventsource-stream`, `actix-web-lab` | T1 | |
| Multipart | `multer`, `multipart-rs`, `actix-multipart` | T2 | |
| Form parsing | `serde_urlencoded`, `multer` | T1 | |
| Rate limiting | `governor`, `tower-governor` | T1 | |
| OpenAPI | (see Layer 14) | | |
| HTTP signing (AWS SigV4) | `aws-sigv4`, `reqsign`, `aws-sign-v4` | T2 | |
| GraphQL HTTP | `async-graphql-actix-web`, `juniper_actix` | T2 | |
| Webhook framework | `octocrab`, `webhook` | T2 | |

---

## Layer 19 — Web Frameworks

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| Tower-style | `axum`, `axum-core`, `axum-extra` | T3 | |
| Actor-style | `actix-web`, `actix-http`, `actix-server`, `actix-rt`, `actix-codec`, `actix-router`, `actix-service`, `actix-utils`, `actix-web-codegen`, `actix-macros`, `actix-multipart`, `actix-files`, `actix-cors`, `actix-session`, `actix-identity`, `actix-web-httpauth` | T3 | |
| Rocket | `rocket`, `rocket_codegen`, `rocket_contrib` | T3 | |
| Warp | `warp` | T2 | |
| Tide | `tide` | T2 | |
| Poem | `poem`, `poem-openapi` | T2 | |
| Salvo | `salvo` | T2 | |
| Loco | `loco-rs` | T3 | |
| Pavex | `pavex` | T3 | |
| Volga | `volga` | T2 | |
| ntex | `ntex` | T3 | |
| Trillium | `trillium` | T2 | |
| Async-graphql | `async-graphql` | T3 | |
| Templating | `tera`, `askama`, `handlebars`, `minijinja`, `liquid`, `ramhorns`, `maud`, `markup`, `sailfish`, `yarte` | T3 | |
| Static asset embed | `rust-embed`, `include_dir` | T1 | |
| Form handling | `serde_urlencoded`, `multer` | T1 | |
| Auth (JWT) | `jsonwebtoken`, `josekit`, `jwt-simple`, `biscuit` | T2 | |
| Auth (OAuth) | `oauth2`, `yup-oauth2`, `openidconnect`, `azure_identity` | T2 | |
| Auth (Sessions) | `actix-session`, `tower-sessions`, `axum-login` | T2 | |
| WebAuthn | `webauthn-rs` | T3 | |
| Captcha | `captcha-rs`, `mcaptcha` | T2 | |

---

## Layer 20 — Databases & Storage

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| SQL framework / ORM | `sqlx`, `diesel`, `sea-orm`, `rbatis`, `welds`, `ormx`, `sqlite3-builder` | T3 | |
| SQL query builder | `sea-query`, `sql-builder`, `quaint` | T2 | |
| SQLx adapters | `sqlx-core`, `sqlx-mysql`, `sqlx-postgres`, `sqlx-sqlite`, `sqlx-macros` | T3 | |
| Postgres protocol | `postgres-protocol`, `postgres-types` | T3 | |
| Postgres client | `tokio-postgres`, `postgres`, `postgres-native-tls` | T3 | |
| Postgres logical replication | `postgres-replication` | T2 | Pgoutput parser. |
| Postgres extensions | `pgrx`, `pgx`, `pg_escape` | T4 | |
| MySQL protocol | `mysql_async`, `mysql_common`, `mysql` | T3 | |
| MariaDB | (uses `mysql_async`) | T3 | |
| SQLite | `rusqlite`, `sqlite`, `libsqlite3-sys`, `sqlite-loadable`, `tokio-rusqlite` | ❌ | Bridge SQLite. |
| DuckDB | `duckdb`, `libduckdb-sys` | ❌ | Bridge libduckdb. |
| MS SQL Server | `tiberius`, `tds` | T3 | |
| Oracle | `oracle` | ❌ | Bridge OCI. |
| ClickHouse | `clickhouse`, `klickhouse`, `clickhouse-rs` | T2 | |
| Cassandra / ScyllaDB | `cdrs-tokio`, `scylla`, `cassandra-cpp` | T3 | |
| MongoDB | `mongodb`, `mongo-rust-driver` | T3 | |
| Redis | (see Layer 17) | | |
| Memcached | (see Layer 17) | | |
| etcd | `etcd-client`, `etcd-rs` | T2 | |
| Consul | `consul-rs` | T2 | |
| InfluxDB | `influxdb`, `influxdb2` | T2 | |
| TimescaleDB | (uses Postgres client) | | |
| QuestDB | `questdb-rs` | T2 | |
| TiKV | `tikv-client` | T3 | |
| FoundationDB | `foundationdb`, `foundationdb-sys` | ❌ | Bridge. |
| Neo4j | `neo4rs` | T2 | |
| ArangoDB | `aragog`, `arangors` | T2 | |
| RocksDB | `rocksdb`, `librocksdb-sys`, `rust-rocksdb` | ❌ | Bridge. |
| sled | `sled` | T4 | Pure-Rust embedded KV. |
| LMDB | `lmdb`, `heed`, `lmdb-rkv` | ❌ | Bridge. |
| ReDB | `redb` | T3 | Pure-Rust embedded KV. |
| Fjall | `fjall` | T3 | LSM-tree. |
| Connection pool (sync) | `r2d2`, `r2d2_postgres`, `r2d2_mysql`, `r2d2_sqlite`, `r2d2_redis`, `scheduled-thread-pool` | T2 | |
| Connection pool (async) | `bb8`, `deadpool`, `mobc` | T2 | |
| Migrations | `refinery`, `barrel`, `dbmigrate`, `sqlx-cli` | T2 | |
| Object storage abstraction | `opendal`, `object_store`, `rust-s3`, `aws-sdk-s3`, `azure_storage`, `google-cloud-storage` | T3 | |
| AWS SDK | `aws-sdk-*` (~300 service crates), `aws-config`, `aws-credential-types`, `aws-runtime`, `aws-smithy-*` | T3 | Codegen target. |
| GCP SDK | `google-cloud-*`, `tonic` (gRPC services) | T3 | |
| Azure SDK | `azure_*` | T3 | |
| Iceberg | `iceberg`, `iceberg-catalog-rest` | T4 | |
| Delta Lake | `deltalake` | T4 | |
| Hudi | `hudi-rs` | T4 | |
| Apache Avro | (see Layer 15) | | |
| BigQuery | `gcp-bigquery-client` | T2 | |
| ElasticSearch | `elasticsearch`, `elastic` | T2 | |
| OpenSearch | `opensearch` | T2 | |
| Time series (TDB) | `whisper-rs`, `seriesdb` | T3 | |
| Vector DB | `qdrant-client`, `milvus-sdk-rust`, `weaviate-community-client`, `pinecone-rs` | T2 | |
| Embedded full-text search | `tantivy`, `meilisearch-sdk`, `sonic-rs`, `bleve`-style | T4 | |
| Postgres in pure Rust | `pg-extend`, `gluesql` | T4 | |
| Spanner | `spanner-rs`, `google-cloud-spanner` | T2 | |
| DynamoDB | `aws-sdk-dynamodb`, `serde_dynamo` | T2 | |

---

## Layer 21 — Observability

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| Logging façade | `log`, `slog` | T1 | |
| Logging implementation | `env_logger`, `pretty_env_logger`, `simplelog`, `flexi_logger`, `fern`, `log4rs`, `colog` | T2 | |
| Structured tracing | `tracing`, `tracing-attributes`, `tracing-core`, `tracing-log`, `tracing-serde`, `tracing-subscriber`, `tracing-futures`, `tracing-error`, `tracing-mutex`, `tracing-actix-web`, `tracing-appender` | T3 | |
| OpenTelemetry | `opentelemetry`, `opentelemetry_sdk`, `opentelemetry-otlp`, `opentelemetry-proto`, `opentelemetry-jaeger`, `opentelemetry-zipkin`, `opentelemetry-prometheus`, `opentelemetry-stdout`, `tracing-opentelemetry` | T3 | |
| Metrics façade | `metrics`, `metrics-util` | T1 | |
| Prometheus | `prometheus`, `metrics-exporter-prometheus`, `prometheus-client`, `actix-web-prom`, `axum-prometheus` | T2 | |
| Statsd | `cadence`, `metrics-exporter-statsd`, `dogstatsd` | T1 | |
| Quantile sketches | `sketches-ddsketch`, `tdigest`, `quantiles`, `hdrhistogram` | T1 | |
| Sentry | `sentry`, `sentry-core`, `sentry-types`, `sentry-backtrace`, `sentry-contexts`, `sentry-debug-images`, `sentry-panic`, `sentry-tracing`, `sentry-actix`, `sentry-tower` | T2 | |
| Backtrace | `backtrace`, `color-backtrace`, `human-panic` | T2 | Bridge libunwind. |
| Symbolication | `addr2line`, `gimli`, `findshlibs`, `symbolic-debuginfo` | T3 | |
| DWARF | `gimli`, `gimli-mock` | T3 | |
| Debug ID | `debugid` | T1 | |
| Profiling | `pprof`, `puffin`, `superluminal-perf`, `tracy-client`, `tracing-tracy`, `coz` | T3 | |
| Crash reporting | `minidump-writer`, `breakpad-handler`, `crash-handler` | T4 | |
| Continuous profiling | `pyroscope` | T2 | |
| Rate-limited logging | `log-derive`, `tracing-rate-limited` | T1 | |
| Console / tokio inspector | `console-subscriber`, `tokio-console` | T3 | |
| Status page / health | `health` | T1 | |
| eBPF | `aya`, `redbpf`, `libbpf-rs` | T4 | Linux-specific. |
| Audit logging | `audit-tip` | T1 | |

---

## Layer 22 — Configuration & Secrets

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| Layered config | `config`, `figment`, `confy`, `confique`, `twelf` | T2 | |
| Env vars | `dotenvy`, `dotenv`, `envy`, `envconfig` | T1 | |
| .env file | `dotenvy`, `dotenv` | T1 | |
| CLI from struct | (see Layer 23 — `clap`) | | |
| Secrets handling | `secrecy`, `redact`, `vaultrs`, `rustify` | T2 | |
| HashiCorp Vault | `vaultrs`, `hashicorp_vault` | T2 | |
| AWS Secrets Manager | `aws-sdk-secretsmanager` | T2 | |
| Feature flags | `configcat`, `unleash-client-rust`, `featureprobe`, `flagd` | T2 | |
| Service discovery | `consul-rs`, `etcd-client` | T2 | |

---

## Layer 23 — CLI & Terminal

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| Argument parsing | `clap`, `clap_builder`, `clap_derive`, `clap_lex`, `argh`, `gumdrop`, `pico-args`, `bpaf`, `lexopt`, `xflags` | T2 | |
| Subcommands | `clap`, `argh` | T2 | |
| Shell completions | `clap_complete`, `clap_mangen`, `clap_complete_fig` | T2 | |
| Manpage generation | `clap_mangen` | T1 | |
| Terminal colors | `termcolor`, `colored`, `nu-ansi-term`, `ansi_term`, `owo-colors`, `yansi`, `console` | T1 | |
| ANSI parsing | `anstyle`, `anstyle-parse`, `anstyle-query`, `anstream`, `colorchoice`, `is_terminal_polyfill`, `utf8parse`, `vte`, `strip-ansi-escapes` | T1 | |
| Terminal control | `crossterm`, `termion`, `console`, `terminal_size` | T2 | |
| Progress bars | `indicatif`, `pbr`, `progress` | T2 | |
| Spinners | `spinners`, `indicatif`, `cli-spinners` | T1 | |
| TUI framework | `ratatui`, `tui-rs`, `cursive`, `iocraft`, `dialoguer` | T3 | |
| Prompts | `dialoguer`, `inquire`, `requestty` | T2 | |
| Tables | `comfy-table`, `cli-table`, `prettytable`, `tabled` | T1 | |
| Diff display | `similar`, `dissimilar`, `difference`, `diffy` | T2 | |
| Hex dump | `hexyl`, `pretty-hex` | T1 | |
| Editor integration | `tui-input`, `rustyline`, `reedline`, `linefeed` | T3 | |
| Shell parsing | `shellwords`, `shlex`, `shell-words` | T1 | |
| Shell escape | `shell-escape` | T1 | |
| Cmd builder | `which`, `command-group`, `duct` | T1 | |
| Environment | `env_logger`, `envy` | T1 | |
| Help / docs | `clap`, `bpaf` | T2 | |
| Multi-progress | `indicatif::MultiProgress` | T2 | |
| Pager | `minus`, `less-rs`, `pager` | T2 | |
| Notifier (desktop) | `notify-rust`, `winrt-notification` | T2 | |
| Tree printing | `termtree`, `ptree` | T1 | |
| Self-update | `self_update`, `cargo-update` | T2 | |
| Config dirs | (see Layer 8) | | |
| ASCII art | `figlet-rs`, `colored` | T1 | |

---

## Layer 24 — Macros & Code Generation

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

## Layer 25 — Testing, Fuzzing, Benchmarking

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| Unit testing | (Rust stdlib `#[test]`) | T1 | Swift Testing framework. |
| Property testing | `proptest`, `quickcheck`, `arbitrary`, `arbtest` | T2 | |
| Snapshot testing | `insta`, `expect-test`, `goldentests` | T2 | |
| Mocking | `mockall`, `mockito`, `faux`, `mockiato` | T3 | Hard without runtime reflection. |
| HTTP mocking | (see Layer 18) | | |
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

## Layer 26 — Compiler Infrastructure

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
| String interning | (see Layer 24) | | |
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

## Layer 27 — WebAssembly Tooling

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

## Layer 28 — Cloud, Distributed, Specialized

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| AWS SigV4 | `aws-sigv4`, `reqsign` | T2 | |
| GCP service-account auth | `yup-oauth2`, `gcp_auth` | T2 | |
| Azure auth | `azure_identity`, `azure_core` | T2 | |
| Kubernetes client | `kube`, `kube-client`, `kube-core`, `kube-derive`, `kube-runtime`, `k8s-openapi` | T3 | |
| Helm | `helm-client` | T3 | |
| Docker / OCI | `bollard`, `docker-api`, `oci-spec`, `oci-distribution` | T2 | |
| Containers (rootless) | `youki`, `runc-rs` | T4 | |
| OpenTelemetry collectors | (see Layer 21) | | |
| Distributed tracing | (see Layer 21) | | |
| Workflow engines | `temporalio-sdk-core`, `temporalio-sdk` | ❌ | FFI wrap. |
| Dapr | `dapr-rs` | T2 | |
| Service mesh sidecar | `linkerd2-proxy` | T4 | |
| Consensus (Raft) | `raft-rs`, `openraft`, `async-raft` | T4 | |
| Consensus (Paxos) | `paxos-rs` | T4 | |
| CRDTs | `automerge`, `yrs`, `diamond-types`, `loro`, `crdts` | T4 | |
| Vector clocks | `vclock` | T1 | |
| Event sourcing | `cqrs-es`, `eventstore` | T3 | |
| Saga pattern | `saga-pattern` | T2 | |
| Distributed locks | `distributed-lock`, `redlock` | T2 | |
| Leader election | `raft-rs`, `etcd-client` (lease) | T3 | |
| Service registry | `consul-rs`, `eureka-client` | T2 | |
| Job scheduling | `tokio-cron-scheduler`, `cron`, `clokwerk`, `delay_timer`, `apalis` | T2 | |
| Background workers | `apalis`, `sidekiq.rs`, `faktory`, `faktory-rs` | T2 | |
| Workflow / DAG | `dagrs`, `petgraph` | T2 | |
| Erlang/OTP-style supervisors | `bastion`, `riker` | T4 | |
| Actor framework | `actix`, `xtra`, `kameo`, `riker`, `bastion`, `coerce` | T3 | Swift actors are native. |
| Streaming / event processing | `arrow-flight`, `materialize`, `vector` | T4 | |
| Search / IR | `tantivy`, `meilisearch`, `quickwit` | T4 | |
| ML inference | `candle-core`, `tract`, `burn`, `dfdx`, `tch`, `ort`, `llama-cpp-2` | T4 | Often bridge C/C++. |
| Vector search | `qdrant-client`, `usearch`, `hora`, `instant-distance` | T3 | |
| Tokenizers (NLP) | `tokenizers`, `tiktoken-rs` | T2 | |
| Embeddings | `fastembed-rs`, `embed-anything` | T3 | |
| Crypto wallets | `coins-bip32`, `bip39`, `bdk`, `bitcoin` | T3 | |
| Blockchain | `ethers-rs`, `web3`, `solana-sdk`, `substrate` | T4 | |
| 2D graphics | `tiny-skia`, `cairo-rs`, `raqote`, `vello` | T3 | |
| 3D graphics | `wgpu`, `glow`, `gfx-rs`, `vulkano`, `bevy` | T4 | Bridge Vulkan/Metal. |
| Game engine | `bevy`, `macroquad`, `ggez`, `piston` | T4 | |
| Physics | `rapier`, `parry`, `nphysics` | T4 | |
| GUI | `egui`, `iced`, `dioxus`, `tauri`, `slint`, `xilem`, `gtk-rs`, `relm4`, `floem`, `fltk-rs` | T4 | |
| Notifications | `notify-rust` | T2 | |
| Hardware (USB) | `rusb`, `nusb`, `libusb` | ❌ | Bridge libusb. |
| Hardware (I2C/SPI/GPIO) | `embedded-hal`, `linux-embedded-hal`, `rppal` | T2 | |
| Robotics (ROS) | `r2r`, `ros2-rs`, `safe_drive` | T3 | |
| Bioinformatics | `bio`, `noodles`, `rust-htslib` | T4 | |
| Image processing | `image`, `imageproc`, `kornia-rs` | T3 | |
| Computer vision | `opencv`, `kornia-rs` | ❌ | Bridge OpenCV. |
| OCR | `leptess`, `tesseract` | ❌ | Bridge Tesseract. |
| Speech | `whisper-rs`, `vosk-rs` | ❌ | Bridge. |
| TTS | `tts`, `coqui-tts` | ❌ | Bridge. |
| Audio synthesis | `cpal`, `rodio`, `kira`, `fundsp`, `dasp` | T3 | |
| MIDI | `midir`, `midly` | T2 | |
| Game networking | `naia`, `quinn`, `webrtc-rs` | T3 | |

---

## Recommended Build Order

A pragmatic build sequence for filling Swift's ecosystem gaps. Each phase blocks the next.

### Phase 1 — Foundations (Layers 0–7)
**Goal:** primitives, encodings, collections, time, RNG, hashing.
- Bytes/ByteBuffer, byteorder, varints, hex/base64
- URL parser + IDNA (after Unicode tables)
- UUID
- Unicode data tables (normalization, segmentation, properties)
- Collections: SmallVec, ArrayVec, IndexMap, ordered/concurrent maps, slab/slotmap, arenas, LRU, TinyLFU
- Petgraph, fixedbitset, roaring, bloom
- Bigint, decimals, FFT
- chrono/time/jiff equivalent + tzdata
- RNG framework + ChaCha + xoshiro + getrandom bridge
- Non-crypto hashers (SipHash, FxHash, AHash, xxHash, CRC)

**Effort:** 3–6 person-months.

### Phase 2 — OS Layer (Layers 8–10)
**Goal:** filesystem, processes, signals, sync primitives.
- POSIX bridge (libc) + Windows bridge (Win32)
- Path utilities, standard dirs, walkdir, glob
- Tempfiles, mmap, file locking, xattr
- Filesystem watching (inotify/FSEvents/RDC)
- Process spawn/wait, signals, pipes
- Mutex/RwLock implementations
- Channels (sync + async), ring buffers
- Atomic Arc swap, RCU primitives
- Rate limiting, backoff

**Effort:** 3–5 person-months.

### Phase 3 — Async Reactor (Layer 11)
**Goal:** epoll/kqueue/IOCP/io_uring reactor + async runtime.
- mio-equivalent reactor
- Future combinators (most are Swift-native)
- Async I/O, codecs, timers
- Async fs, async DNS

**Effort:** 4–8 person-months. Single biggest gating item.

### Phase 4 — Crypto + TLS (Layers 12–13)
**Goal:** bridge BoringSSL/libsodium, port spec-driven primitives, ASN.1/DER/X.509.
- Bridge BoringSSL or libsodium for production crypto
- ASN.1/DER, PKCS encodings, X.509 cert parsing
- PEM encoding, OID registry
- Mozilla CA bundle
- TLS-on-async wrappers
- ACME client (optional)

**Effort:** 2–4 person-months (assuming you bridge for crypto; otherwise add 6–12 months).

### Phase 5 — Serialization (Layers 14–16)
**Goal:** serde-equivalent on Swift macros + every common format.
- Serde-equivalent macro framework
- JSON (streaming + DOM), JSON Patch, JSONPath
- TOML (with edit-preserving variant)
- YAML 1.2
- XML, HTML parser
- CommonMark
- CBOR, MessagePack, Bincode, Postcard, Borsh
- Protobuf (with Swift macro codegen)
- FlatBuffers, Cap'n Proto
- CSV
- JSON Schema, OpenAPI
- Compression: bridge zstd/zlib, port Snappy/LZ4

**Effort:** 6–10 person-months.

### Phase 6 — Networking (Layers 17–18)
**Goal:** every common wire protocol + complete HTTP stack.
- Sockets, IP types, network interfaces
- DNS (protocol + resolver)
- HTTP types, HTTP/1 parser, HTTP/2 (HPACK + state)
- HTTP client + server
- Tower-style middleware
- WebSockets
- TLS-on-HTTP integration
- AWS SigV4, GCP signing
- HTTP cache, cookies, multipart, SSE
- MQTT, AMQP, Redis protocol, NATS
- SMTP/IMAP/POP3, MIME

**Effort:** 6–10 person-months.

### Phase 7 — Web Frameworks (Layer 19)
**Goal:** at least one production web framework.
- Tower-style framework (Axum-equivalent recommended over Actix)
- Templating (one engine: Tera/Askama/Handlebars)
- Auth: JWT, OAuth2, sessions
- Static asset embed
- WebAuthn (optional)

**Effort:** 3–5 person-months.

### Phase 8 — Databases (Layer 20)
**Goal:** Postgres, MySQL, SQLite, Redis at minimum.
- Bridge SQLite, DuckDB
- Postgres wire protocol + client
- Postgres logical replication
- MySQL wire protocol + client
- Connection pooling (sync + async)
- Migrations
- SQL query builder + macro-based compile-time SQL (sqlx-equivalent)
- Object storage abstraction (OpenDAL-equivalent)
- AWS/GCP/Azure SDKs (codegen-driven)
- Redis client, MongoDB, Elasticsearch

**Effort:** 8–14 person-months.

### Phase 9 — Observability (Layer 21)
**Goal:** logging, tracing, metrics, error reporting.
- log + tracing equivalents
- OpenTelemetry SDK
- Prometheus exporter
- DDSketch, t-digest, HDR histogram
- Sentry SDK
- Backtrace + symbolication (bridge libunwind)
- pprof-style profiling (bridge libunwind)

**Effort:** 3–5 person-months.

### Phase 10 — Configuration & CLI (Layers 22–23)
**Goal:** layered config + production CLI tooling.
- Layered config (env + file + defaults)
- Secrets management
- Vault client
- Feature-flag clients
- CLI argument parser (clap-equivalent on Swift macros)
- Terminal control (crossterm-equivalent)
- TUI framework (Ratatui-equivalent — large)
- Progress bars, prompts, tables
- Pager, diff display

**Effort:** 3–6 person-months.

### Phase 11 — Macros & Codegen (Layer 24)
**Goal:** ergonomic derive ecosystem on Swift macros.
- Derive macros for Display/Error/Builder/Enum helpers
- File embedding macros
- Compile-time perfect hashing (PHF)
- String interning
- Diagnostics rendering (codespan/miette equivalent)

**Effort:** 1–3 person-months.

### Phase 12 — Testing & Tooling (Layer 25)
**Goal:** complete test toolkit.
- Property testing (proptest/quickcheck-equivalent)
- Snapshot testing (insta-equivalent)
- Mocking framework
- Benchmarking (criterion-equivalent)
- Integration testing with containers

**Effort:** 2–4 person-months.

### Phase 13 — Compiler / Language Tooling (Layers 26–27)
**Goal:** support your Swift-syntax compiler work.
- Lexer generator (logos-equivalent)
- Parser combinators (winnow) + parser generator (pest)
- Diagnostics rendering
- String interning, perfect hashing
- Object-file readers (ELF/Mach-O/PE)
- DWARF + symbolication
- WASM tooling: wasmparser, wast, wasmprinter, wit-parser
- Cranelift-ISLE port (instruction selection)

**Effort:** 6–12 person-months.

### Phase 14 — Specialized & Cloud (Layer 28)
**Goal:** Kubernetes, workflows, distributed primitives.
- Kubernetes client + runtime (operator pattern)
- Docker/OCI client
- Temporal SDK (FFI wrap)
- Job scheduling, background workers
- CRDTs (optional)
- ML inference (mostly bridge)
- 2D/3D graphics, GUI (large; defer)

**Effort:** 4–10 person-months for core; graphics/ML/GUI are each multi-year.

---

## Total Effort Estimate

**Pragmatic baseline (bridge C aggressively for crypto, TLS, SQLite, DuckDB, zstd, libunwind, libpq optional, ICU optional):**

| Phase | Months |
|---|---|
| 1. Foundations | 3–6 |
| 2. OS layer | 3–5 |
| 3. Async reactor | 4–8 |
| 4. Crypto + TLS | 2–4 |
| 5. Serialization | 6–10 |
| 6. Networking | 6–10 |
| 7. Web frameworks | 3–5 |
| 8. Databases | 8–14 |
| 9. Observability | 3–5 |
| 10. Config + CLI | 3–6 |
| 11. Macros | 1–3 |
| 12. Testing | 2–4 |
| 13. Compiler tooling | 6–12 |
| 14. Specialized | 4–10 |
| **Total** | **54–102 person-months** |

**Pure-Swift (no C bridges except OS syscalls):** add 12–24 months for pure-Swift crypto, TLS, ICU, Unicode tables, compression. Total: ~70–125 person-months.

For comparison: the Rust ecosystem on crates.io represents roughly 15+ years of cumulative community work across ~150,000 crates; the swift-server / Apple-backed Swift ecosystem (swift-nio + Vapor + adjacent) represents ~7+ years of focused effort. Your bare-Swift port is essentially recapitulating that history, ideally with the benefit of hindsight.

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

## Final Notes

This document is a map, not a roadmap. The right strategy isn't "port everything"; it's:

1. **Bridge C aggressively** at the OS, crypto, TLS, SQLite, and codec layers. These are the most-vetted, most-performance-critical pieces of software in the world; recreating them in Swift is a poor use of effort.
2. **Port pure-logic Rust crates** (parsers, data structures, algorithms, format codecs) where the value is the algorithm, not the Rust-specific machinery.
3. **Reframe macro-driven crates** (serde, sqlx, clap, tracing) on Swift macros + SwiftSyntax. The runtime traits are easy; the derive system is the work.
4. **Build the async reactor once**, carefully. It blocks every networking protocol downstream.
5. **Defer specialized layers** (ML, GUI, graphics, blockchain, embedded) until the foundations are solid.

A realistic aim: 12–18 months of focused work by a team of 3–5 to get bare Swift to "viable backend language" parity (Phases 1–9). Beyond that is decades of community work, which is what Foundation and the swift-server ecosystem represent today.
