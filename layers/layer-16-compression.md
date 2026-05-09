# Layer 16 — Compression

| Field | Value |
|---|---|
| **Phase** | 5 — Serialization |
| **Effort** | included in Phase 5 (6–10 person-months total) |
| **Depends on** | [Layer 1](layer-01-primitives.md) |
| **Dependents** | [Layer 18](layer-18-http-stack.md) (content-encoding), [Layer 20](layer-20-databases-storage.md) (block compression) |

## Libraries

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

[← Index](../README.md) · [Dependency graph](../DEPENDENCIES.md)
