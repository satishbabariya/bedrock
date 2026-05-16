# COBS Module Design

**Status:** Approved
**Layer:** 1 — Primitives
**Depends on:** `Bytes`
**Date:** 2026-05-17

## Purpose

Provide an in-process implementation of [Consistent Overhead Byte Stuffing](https://en.wikipedia.org/wiki/Consistent_Overhead_Byte_Stuffing) (COBS) — a byte-stream encoding that eliminates 0x00 bytes from arbitrary binary payloads, enabling reliable frame delimiting in protocols that use 0x00 as a frame boundary.

The codec is a Layer 1 primitive: stdlib-only, no Foundation, no async, no I/O. It operates on `Bytes` and writes into `BytesMut`, matching the established Layer 1 pattern (Base64, Hex, Varint, PercentEncoding).

## Scope

### In scope

- A `COBS` namespaced enum exposing static `encode`/`encoded`/`decode`/`decoded` functions.
- Standard COBS with delimiter byte **0x00**.
- A `Framing` enum parameter with two cases:
  - `.none` (default) — encode/decode the body only. Caller manages frame delimiters externally.
  - `.terminator` — encode appends a 0x00 terminator; decode requires and consumes one.
- Structured error type `COBSError` distinguishing the four failure modes.
- Convenience extensions on `Bytes` for ergonomic call sites.
- Size-hint helpers (`maxEncodedSize`, `maxDecodedSize`) so callers can pre-reserve capacity.

### Out of scope (separate specs when needed)

- **COBS/R (Reduced)** — variant that saves a byte when the last byte is `< code`. Niche; YAGNI for now.
- **Non-standard delimiter bytes** (e.g., COBS-with-0x01). The standard delimiter is 0x00.
- **Streaming `BytesReader`-based decode** — COBS is short-frame-oriented; a true streaming decoder is more complex and can be added later as a stateful `COBSDecoder` type.
- **Multi-frame splitter** (`splitFrames(_:on:) -> [Bytes]`) — caller's job to chunk an inbound byte stream on 0x00 if they want.
- **DoS / max-frame-size limits** — caller's responsibility. The algorithm itself is O(n) and bounded by input length.
- **Async / AsyncSequence variants** — Layer 1 is synchronous.
- **`@inlinable` on hot paths** — defer until profiling shows it matters, matching the Varint/Base64 stance.

## Module Layout

```
Sources/COBS/
├── COBS.swift               # namespace + Framing enum + size helpers
├── COBSError.swift          # error type
├── COBSEncode.swift         # encode + encoded
├── COBSDecode.swift         # decode + decoded
└── COBSExtensions.swift     # Bytes conveniences
```

```
Tests/COBSTests/
├── COBSEncodeTests.swift
├── COBSDecodeTests.swift
├── COBSFramingTests.swift
├── COBSRoundTripTests.swift
├── COBSErrorTests.swift
└── COBSExtensionsTests.swift
```

## Public API

```swift
import Bytes

public enum COBS {

    /// Frame-delimiter handling.
    public enum Framing: Sendable, Hashable {
        /// Body only. Caller manages frame delimiters (recommended for
        /// in-memory pipelines, custom framers, or when 0x00 isn't your
        /// delimiter).
        case none

        /// Append a 0x00 terminator on encode; require and consume one
        /// on decode. Use when you want the codec to handle delimiting.
        case terminator
    }

    // MARK: - Encode

    /// Encode `input` into `out`. Returns the number of bytes appended.
    @discardableResult
    public static func encode(_ input: Bytes,
                              into out: inout BytesMut,
                              framing: Framing = .none) -> Int

    /// Encode `input` and return a fresh `Bytes`.
    public static func encoded(_ input: Bytes,
                               framing: Framing = .none) -> Bytes

    // MARK: - Decode

    /// Decode `input` into `out`. Returns the number of bytes appended.
    /// Throws `COBSError` on malformed input.
    @discardableResult
    public static func decode(_ input: Bytes,
                              into out: inout BytesMut,
                              framing: Framing = .none) throws -> Int

    /// Decode `input` and return a fresh `Bytes`.
    public static func decoded(_ input: Bytes,
                               framing: Framing = .none) throws -> Bytes

    // MARK: - Size hints

    /// Worst-case encoded body size: `n + ⌈n/254⌉ + 1` (add 1 if framed).
    public static func maxEncodedSize(forSourceCount n: Int,
                                      framing: Framing = .none) -> Int

    /// Upper bound on decoded size: `max(0, n - 1)` body bytes
    /// (`max(0, n - 2)` if framed). Actual decoded size ≤ this.
    public static func maxDecodedSize(forEncodedCount n: Int,
                                      framing: Framing = .none) -> Int
}
```

### Error type

```swift
public enum COBSError: Error, Hashable, Sendable {
    /// A 0x00 byte appeared inside encoded payload at `offset`
    /// (only emitted in `.none` framing — 0x00 is invalid in body bytes).
    case invalidZeroByte(offset: Int)

    /// A code byte points past the end of input.
    case truncated

    /// `.terminator` framing but no trailing 0x00 found.
    case missingTerminator

    /// `.terminator` framing but a 0x00 appeared before the final
    /// terminator position (i.e., mid-stream).
    case unexpectedTerminator(offset: Int)
}
```

### Extensions

```swift
extension Bytes {
    public func cobsEncoded(framing: COBS.Framing = .none) -> Bytes

    public init(cobsDecoding source: Bytes,
                framing: COBS.Framing = .none) throws
}
```

No `String` extensions — COBS operates on bytes, not text.

## Algorithm

### Encode (single pass, O(n))

```
Output starts with a placeholder code byte at codePos = 0.
code = 1                            # count of bytes in current block + 1
for each byte b in input:
    if b == 0x00:
        out[codePos] = code         # finalize current block
        codePos = out.count         # start new block
        out.append(0x00)            # placeholder
        code = 1
    else:
        out.append(b)
        code += 1
        if code == 0xFF:            # block is full (254 non-zero bytes)
            out[codePos] = code
            codePos = out.count
            out.append(0x00)
            code = 1
out[codePos] = code                  # finalize last block
if framing == .terminator: out.append(0x00)
```

**Empty input special case:** Empty body encodes to `[0x01]` (single code byte indicating "1-byte block, zero content bytes"). With `.terminator`: `[0x01, 0x00]`.

### Decode (single pass, O(n))

```
if framing == .terminator:
    if input.isEmpty || input.last != 0x00: throw .missingTerminator
    payload = input.dropLast()           # strip terminator
else:
    payload = input

if payload.isEmpty: throw .truncated

i = 0
while i < payload.count:
    code = payload[i]
    if code == 0x00:
        throw framing == .terminator
            ? .unexpectedTerminator(offset: i)
            : .invalidZeroByte(offset: i)
    i += 1
    blockEnd = i + Int(code) - 1
    if blockEnd > payload.count: throw .truncated
    while i < blockEnd:
        b = payload[i]
        if b == 0x00:
            throw framing == .terminator
                ? .unexpectedTerminator(offset: i)
                : .invalidZeroByte(offset: i)
        out.append(b)
        i += 1
    # Emit inter-block zero unless block was maximal (0xFF) or at end
    if code < 0xFF && i < payload.count:
        out.append(0x00)
```

### Edge cases (verified by trace)

| Input | Encoded body | Decoded back |
|---|---|---|
| `[]` | `[01]` | `[]` |
| `[00]` | `[01 01]` | `[00]` |
| `[00 00]` | `[01 01 01]` | `[00 00]` |
| `[11 22 00 33]` | `[03 11 22 02 33]` | `[11 22 00 33]` |
| `[01]*254` (254 non-zero bytes) | `[FF 01..01 01]` (256B) | `[01]*254` |
| `[01]*255` | `[FF 01..01 02 01]` (257B) | `[01]*255` |
| `[00]*254` | `[01]*255` | `[00]*254` |

**The subtle case — maximal block boundary.** When the encoder hits 254 non-zero bytes in a row, it emits a code-byte of 0xFF and starts a *new* block without an implicit zero between them. The decoder mirrors this: after consuming a block whose code byte was 0xFF, it does NOT emit a separator zero. This is what the `code < 0xFF` guard in the decoder protects.

## Testing Strategy

Each test file targets ≥ 90% line coverage on its corresponding source file.

### `COBSEncodeTests.swift`
- Empty input → `[01]` (both framings).
- Single non-zero byte.
- Single zero byte.
- All-zeros inputs (lengths 1, 2, 254, 255).
- No-zero inputs (lengths 1, 253, 254, 255 — straddles the 0xFF boundary).
- Mixed paper example: `[11 22 00 33]` → `[03 11 22 02 33]`.
- 254-byte block-boundary case: input `[01]*254` produces output ending in `01`.
- `encode(_:into:)` appends to a non-empty `BytesMut` and returns correct count.
- `encoded(_:)` produces a `Bytes` matching `encode` output.

### `COBSDecodeTests.swift`
- Inverse of every encode case.
- Invalid zero byte in body mode → `.invalidZeroByte(offset:)`.
- Truncated: code byte says 5 but only 3 bytes follow → `.truncated`.
- Truncated: empty payload → `.truncated`.
- `decode(_:into:)` appends and returns correct count.
- `decoded(_:)` returns fresh `Bytes`.

### `COBSFramingTests.swift`
- `.terminator` encode appends 0x00.
- `.terminator` decode strips 0x00.
- `.terminator` decode missing final 0x00 → `.missingTerminator`.
- `.terminator` decode with 0x00 mid-stream → `.unexpectedTerminator(offset:)`.
- Empty input + `.terminator` → `[01 00]` → decodes back to `[]`.

### `COBSRoundTripTests.swift`
- Property-style: for a corpus of fixed inputs (empty, all zeros, no zeros, alternating, deterministic-pseudo-random), `decoded(encoded(x)) == x` under both framings.
- All 256 single-byte inputs round-trip under both framings.
- Boundary inputs (253, 254, 255, 256, 508, 509 bytes — straddles block boundaries) round-trip.
- Round-trip 1 KiB and 10 KiB pseudo-random sequences (seeded LCG; no Foundation).

### `COBSErrorTests.swift`
- Each error case is constructible.
- `Hashable` semantics correct (equal cases hash equal; distinct cases distinguishable).
- `Sendable` (compile-time check via cross-actor stub if needed).

### `COBSExtensionsTests.swift`
- `Bytes.cobsEncoded(framing:)` matches `COBS.encoded`.
- `Bytes(cobsDecoding:framing:)` matches `COBS.decoded`.
- Round-trip through extensions under both framings.

### Size helpers
- `maxEncodedSize` is a tight upper bound for inputs that hit the 0xFF boundary.
- `maxDecodedSize` is an upper bound; verified `decoded(x).count <= maxDecodedSize`.

## Non-Functional Requirements

- **Stdlib only.** No Foundation, no swift-system, no swift-atomics.
- **Sendable** — `COBS` is a static-only namespace; `Framing` and `COBSError` conform to `Sendable`.
- **Allocation-aware** — `encode(_:into:)` and `decode(_:into:)` allow callers to reuse a `BytesMut` and avoid intermediate allocations.
- **Bounds-safe** — every index read is preceded by a `count` check; the decoder validates `blockEnd <= payload.count` before reading block bodies.
- **O(n) time, O(n) auxiliary space** (output buffer only).

## Open Questions

None. All design questions resolved during brainstorming:
- Framing: dual-mode (`.none` default, `.terminator` opt-in).
- Errors: four cases distinguishing body / truncation / missing-terminator / unexpected-terminator.
- API shape: matches Base64/Varint/PercentEncoding (`encode`/`encoded`/`decode`/`decoded` quartet + Bytes extensions).
- Streaming decode deferred.
