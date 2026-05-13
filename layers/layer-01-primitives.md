# Layer 1 — Primitives, Bytes, Encodings

| Field | Value |
|---|---|
| **Phase** | 1 — Foundations |
| **Effort** | included in Phase 1 (3–6 person-months total) |
| **Depends on** | [Layer 0](layer-00-stdlib-gaps.md) |
| **Dependents** | [Layer 2](layer-02-text-unicode.md), [Layer 3](layer-03-collections.md), [Layer 5](layer-05-time-date.md), [Layer 7](layer-07-hashing.md), [Layer 8](layer-08-filesystem-os.md), [Layer 11](layer-11-async-runtime.md), [Layer 12](layer-12-cryptography.md), [Layer 14](layer-14-serialization-framework.md), [Layer 15](layer-15-data-formats.md), [Layer 16](layer-16-compression.md), [Layer 17](layer-17-networking-protocols.md), [Layer 18](layer-18-http-stack.md), [Layer 20](layer-20-databases-storage.md), [Layer 21](layer-21-observability.md), [Layer 22](layer-22-config-secrets.md), [Layer 23](layer-23-cli-terminal.md) |

> **Status:** shipping modules:
> - `Sources/Bytes/` — core bytes ([design](../docs/superpowers/specs/2026-05-09-bytes-design.md), [plan](../docs/superpowers/plans/2026-05-09-bytes-module.md))
> - `Sources/Hex/` — hex codec ([design](../docs/superpowers/specs/2026-05-10-hex-base64-design.md), [plan](../docs/superpowers/plans/2026-05-10-hex-base64-modules.md))
> - `Sources/Base64/` — base64 codec, including constant-time decode ([same design + plan](../docs/superpowers/specs/2026-05-10-hex-base64-design.md))
> - `Sources/UUID/` — UUID type with v4/v7/v8 generation; v1/v3/v5/v6 parse/inspect work, generation deferred to follow-up patches when Layer 8 (MAC) and Layer 12 (MD5/SHA-1) ship ([design](../docs/superpowers/specs/2026-05-10-uuid-design.md), [plan](../docs/superpowers/plans/2026-05-10-uuid-module.md))
> - `Sources/Varint/` — LEB128 unsigned + ZigZag-LEB128 signed for UInt32/UInt64/Int32/Int64 ([design](../docs/superpowers/specs/2026-05-12-varint-design.md), [plan](../docs/superpowers/plans/2026-05-12-varint-module.md))
>
> Remaining categories (BitSet, percent encoding, SIMD UTF-8, COBS, URL/IDNA) pending their own designs.

The absolute foundation. Without these, no I/O, no protocols, nothing.

## Libraries

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

[← Index](../README.md) · [Dependency graph](../DEPENDENCIES.md)
