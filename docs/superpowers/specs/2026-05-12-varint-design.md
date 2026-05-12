# Bedrock `Varint` Module — Design Spec

**Date:** 2026-05-12
**Layer:** 1 (Primitives, Bytes, Encodings) — *LEB128 + ZigZag varint codec*
**Status:** Approved, ready for implementation plan

---

## 1. Scope & Non-Goals

### In scope

- **LEB128 unsigned varint** for `UInt32` and `UInt64`.
- **ZigZag-LEB128 signed varint** for `Int32` and `Int64` (Protobuf `sint32`/`sint64`).
- **Encode** into a `BytesMut` (streaming) or as a one-shot `Bytes` value. Returns the byte count of the encoded output.
- **Decode** from a `BytesReader` (cursor-advancing) or one-shot from `Bytes` (returns value + consumed length).
- **Bounds**: u32 ≤ 5 bytes; u64 ≤ 10 bytes. Exceeding → `.overflow`. Truncated input (continuation bit still set when bytes run out) → `.truncated`.
- **Extensions** on `BytesMut`, `BytesReader` for ergonomic call sites (`buf.putVarint(150 as UInt32)`, `try reader.readVarintUInt32()`).
- Lenient decoder: non-canonical encodings (e.g., `0x80 0x00` for 0) are accepted as long as they fit within the per-width byte cap.

### Explicitly out of scope (separate designs later)

- **SQLite varint** — different format (1–9 bytes, big-endian).
- **VLQ** (MIDI, JSON source maps) — close cousin but distinct convention.
- **Protobuf wire format** — Layer 14 owns wire-level serialization.
- **DWARF-specific parsing** (tags, attributes) — future debug-info module.
- **Async streaming decode** — Layer 11 reactor.
- **`.strict` (canonical-only) mode** — not pursuing; Protobuf practice is lenient.

---

## 2. Module Layout

```
Bedrock/
└── Sources/
    └── Varint/
        ├── Varint.swift              # public enum Varint namespace
        ├── VarintError.swift         # public enum VarintError
        ├── VarintLEB128.swift        # unsigned encode/decode (UInt32, UInt64)
        ├── VarintZigZag.swift        # signed encode/decode (Int32, Int64)
        └── VarintExtensions.swift    # BytesMut/BytesReader convenience
└── Tests/
    └── VarintTests/
        ├── VarintLEB128Tests.swift
        ├── VarintZigZagTests.swift
        ├── VarintErrorTests.swift
        └── VarintExtensionsTests.swift
```

`Package.swift` gains one library product `Varint`, one source target depending only on `Bytes`, and one test target.

Five source files (one per concern), four test files. ~50–100 LOC each. Only depends on `Bytes` from Layer 1.

---

## 3. Public API

### 3.1 `Varint` namespace

```swift
// Sources/Varint/Varint.swift

import Bytes

/// LEB128 + ZigZag-LEB128 varint codec namespace.
public enum Varint {

    // ─── Bounds ───────────────────────────────────────────────────────────

    /// Maximum encoded byte count for a `UInt32` (or `Int32` via ZigZag).
    public static let maxBytes32 = 5

    /// Maximum encoded byte count for a `UInt64` (or `Int64` via ZigZag).
    public static let maxBytes64 = 10

    // ─── Encode into a BytesMut (streaming) ──────────────────────────────

    /// Encode an unsigned 32-bit LEB128 varint into `out`. Returns the byte
    /// count appended (1–5).
    @discardableResult
    public static func encode(_ value: UInt32, into out: inout BytesMut) -> Int

    /// Encode an unsigned 64-bit LEB128 varint into `out`. Returns 1–10.
    @discardableResult
    public static func encode(_ value: UInt64, into out: inout BytesMut) -> Int

    /// Encode a signed 32-bit ZigZag-LEB128 varint into `out`. Returns 1–5.
    @discardableResult
    public static func encode(_ value: Int32, into out: inout BytesMut) -> Int

    /// Encode a signed 64-bit ZigZag-LEB128 varint into `out`. Returns 1–10.
    @discardableResult
    public static func encode(_ value: Int64, into out: inout BytesMut) -> Int

    // ─── Encode to a fresh Bytes value (one-shot) ────────────────────────

    public static func encoded(_ value: UInt32) -> Bytes
    public static func encoded(_ value: UInt64) -> Bytes
    public static func encoded(_ value: Int32)  -> Bytes
    public static func encoded(_ value: Int64)  -> Bytes

    // ─── Decode advancing a BytesReader ──────────────────────────────────

    /// Decode an unsigned 32-bit LEB128 varint. Throws `.truncated` if input
    /// ends mid-varint, `.overflow` if the encoded form exceeds 5 bytes or
    /// the decoded value exceeds `UInt32.max`.
    public static func decodeUInt32(from reader: inout BytesReader) throws -> UInt32

    /// Decode an unsigned 64-bit LEB128 varint. Bounded at 10 bytes.
    public static func decodeUInt64(from reader: inout BytesReader) throws -> UInt64

    /// Decode a signed 32-bit ZigZag-LEB128 varint.
    public static func decodeInt32(from reader: inout BytesReader) throws -> Int32

    /// Decode a signed 64-bit ZigZag-LEB128 varint.
    public static func decodeInt64(from reader: inout BytesReader) throws -> Int64

    // ─── Decode one-shot from Bytes ──────────────────────────────────────

    /// Decode from `bytes` starting at offset 0. Returns the decoded value
    /// and the number of bytes consumed.
    public static func decodeUInt32(from bytes: Bytes) throws -> (value: UInt32, consumed: Int)
    public static func decodeUInt64(from bytes: Bytes) throws -> (value: UInt64, consumed: Int)
    public static func decodeInt32 (from bytes: Bytes) throws -> (value: Int32,  consumed: Int)
    public static func decodeInt64 (from bytes: Bytes) throws -> (value: Int64,  consumed: Int)
}
```

### 3.2 Errors

```swift
// Sources/Varint/VarintError.swift

public enum VarintError: Error, Equatable, Sendable {
    /// Input ran out before the varint completed (last byte had the
    /// continuation bit set).
    case truncated
    /// The varint exceeded its maximum byte count for the target width
    /// (5 bytes for 32-bit, 10 bytes for 64-bit), OR the decoded value
    /// is too large to fit the target integer type.
    case overflow
}
```

### 3.3 Extensions

```swift
// Sources/Varint/VarintExtensions.swift

import Bytes

extension BytesMut {
    @discardableResult public mutating func putVarint(_ v: UInt32) -> Int { Varint.encode(v, into: &self) }
    @discardableResult public mutating func putVarint(_ v: UInt64) -> Int { Varint.encode(v, into: &self) }
    @discardableResult public mutating func putVarint(_ v: Int32)  -> Int { Varint.encode(v, into: &self) }
    @discardableResult public mutating func putVarint(_ v: Int64)  -> Int { Varint.encode(v, into: &self) }
}

extension BytesReader {
    public mutating func readVarintUInt32() throws -> UInt32 { try Varint.decodeUInt32(from: &self) }
    public mutating func readVarintUInt64() throws -> UInt64 { try Varint.decodeUInt64(from: &self) }
    public mutating func readVarintInt32()  throws -> Int32  { try Varint.decodeInt32(from: &self) }
    public mutating func readVarintInt64()  throws -> Int64  { try Varint.decodeInt64(from: &self) }
}
```

### 3.4 Notes on choices

- **Typed entry points per width.** `decodeUInt32` reads up to 5 bytes; `decodeUInt64` up to 10. Decoding into the narrower type from a wider-encoded value throws `.overflow`. This catches truncation bugs at the boundary.
- **`encoded(_:)` returns `Bytes`**, not a tuple — encode is total and the size is just `bytes.count`.
- **`decode...(from: Bytes)` returns `(value, consumed)`** — callers without a reader want both pieces.
- **No `.canonical` mode flag** — lenient is the only mode, matching Protobuf practice. Per-width byte caps make varint bombs impossible (max 10 bytes per decode).
- **Extension methods on `BytesReader` are `mutating throws`** — `BytesReader` is `~Copyable`; the cursor-mutation invariant is preserved.

---

## 4. Algorithms

### 4.1 LEB128 encode (unsigned)

Standard 7-bits-per-byte with continuation bit:

```swift
@discardableResult
public static func encode(_ value: UInt64, into out: inout BytesMut) -> Int {
    var v = value
    var count = 0
    while v >= 0x80 {
        out.putUInt8(UInt8(v & 0x7F) | 0x80)
        v >>= 7
        count += 1
    }
    out.putUInt8(UInt8(v))
    return count + 1
}
```

The `UInt32` overload runs an identical loop locally. Pre-widening to `UInt64` would change the return-count tracking; keeping it local is clearer and the duplication is ~10 lines.

### 4.2 ZigZag wrappers

ZigZag formula: `(n << 1) ^ (n >> (k-1))` where k is the bit width.

```swift
@inline(__always)
internal func zigzagEncode(_ n: Int32) -> UInt32 {
    UInt32(bitPattern: (n << 1) ^ (n >> 31))
}

@inline(__always)
internal func zigzagEncode(_ n: Int64) -> UInt64 {
    UInt64(bitPattern: (n << 1) ^ (n >> 63))
}

@inline(__always)
internal func zigzagDecode(_ u: UInt32) -> Int32 {
    Int32(bitPattern: (u >> 1)) ^ -Int32(bitPattern: u & 1)
}

@inline(__always)
internal func zigzagDecode(_ u: UInt64) -> Int64 {
    Int64(bitPattern: (u >> 1)) ^ -Int64(bitPattern: u & 1)
}
```

The bit-pattern conversions avoid signed-overflow traps at `Int32.min` / `Int64.min` (where `-Int64.min` would otherwise trap).

Signed encode/decode delegate to the unsigned forms after wrap/unwrap:

```swift
@discardableResult
public static func encode(_ value: Int64, into out: inout BytesMut) -> Int {
    encode(zigzagEncode(value), into: &out)
}

public static func decodeInt64(from reader: inout BytesReader) throws -> Int64 {
    zigzagDecode(try decodeUInt64(from: &reader))
}
```

### 4.3 LEB128 decode (unsigned)

```swift
public static func decodeUInt64(from reader: inout BytesReader) throws -> UInt64 {
    var result: UInt64 = 0
    var shift: UInt64 = 0
    var byteCount = 0
    while byteCount < maxBytes64 {
        guard let byte = reader.readUInt8() else { throw VarintError.truncated }
        byteCount += 1
        let payload = UInt64(byte & 0x7F)
        // Detect overflow on the final byte (the 10th can only carry 1 bit).
        if byteCount == maxBytes64 && payload > 1 {
            throw VarintError.overflow
        }
        result |= payload << shift
        if byte & 0x80 == 0 { return result }
        shift += 7
    }
    // Loop fell through — 10th byte had continuation bit set.
    throw VarintError.overflow
}
```

`decodeUInt32` runs an analogous loop bounded at 5 bytes, with the same final-byte payload check (the 5th byte can only carry 4 bits without overflowing UInt32):

```swift
public static func decodeUInt32(from reader: inout BytesReader) throws -> UInt32 {
    var result: UInt32 = 0
    var shift: UInt32 = 0
    var byteCount = 0
    while byteCount < maxBytes32 {
        guard let byte = reader.readUInt8() else { throw VarintError.truncated }
        byteCount += 1
        let payload = UInt32(byte & 0x7F)
        if byteCount == maxBytes32 && payload > 0x0F {
            throw VarintError.overflow
        }
        result |= payload << shift
        if byte & 0x80 == 0 { return result }
        shift += 7
    }
    throw VarintError.overflow
}
```

### 4.4 One-shot `Bytes` decoders

Wrap in a temporary `BytesReader` and report the cursor on success:

```swift
public static func decodeUInt64(from bytes: Bytes) throws -> (value: UInt64, consumed: Int) {
    var r = BytesReader(bytes)
    let v = try decodeUInt64(from: &r)
    return (v, r.consumed)
}
```

(`consumed` is already exposed on `BytesReader` from the Bytes module.)

### 4.5 Failure-mode specifics

- **`.truncated`** — `BytesReader.readUInt8()` returns `nil` while the decoder still needs more bytes (i.e., the previous byte had the continuation bit set).
- **`.overflow` (byte cap)** — the encoded varint exceeds `maxBytes32` / `maxBytes64`, detected by the loop falling through after reading the full quota with continuation bits still set.
- **`.overflow` (final-byte payload too large)** — caught at the per-width final byte (5th for u32 → payload must be ≤ 0x0F; 10th for u64 → payload must be ≤ 0x01).
- **`.overflow` (narrowing)** — implicit when `decodeUInt32` rejects a value > `UInt32.max` via the byte-cap. Signed decoders inherit it via the unsigned delegate.

---

## 5. Error Model

| Case | Triggered by |
|---|---|
| `.truncated` | Input ran out mid-varint (last byte had continuation bit set; reader returned `nil`). |
| `.overflow` | Varint exceeded the per-width byte cap, OR the decoded value didn't fit the target integer width. |

`encode` and `encoded` are total — no throws.

---

## 6. Testing Strategy

Four test files, all Swift Testing (`@Test` / `#expect`).

### 6.1 `VarintLEB128Tests` (~14 tests)

Known vectors from Protobuf and DWARF specs:

| Value | Encoded |
|---|---|
| `0` | `[0x00]` |
| `1` | `[0x01]` |
| `127` | `[0x7F]` |
| `128` | `[0x80, 0x01]` |
| `150` | `[0x96, 0x01]` |
| `16383` | `[0xFF, 0x7F]` |
| `16384` | `[0x80, 0x80, 0x01]` |
| `UInt32.max` | 5-byte encoding `[0xFF, 0xFF, 0xFF, 0xFF, 0x0F]` |
| `UInt64.max` | 10-byte encoding `[0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01]` |

Plus:
- Streaming encode appends correctly to a pre-populated `BytesMut`.
- `encoded(_: UInt64)` round-trips through `decodeUInt64(from: Bytes)`.
- One-shot decode reports correct `consumed` count.
- Encode return value matches `consumed` on decode.

### 6.2 `VarintZigZagTests` (~10 tests)

Known ZigZag vectors:

| Signed value | Zigzag |
|---|---|
| `0` | `0` |
| `-1` | `1` |
| `1` | `2` |
| `-2` | `3` |
| `2` | `4` |

Plus:
- Round-trip every signed boundary: `Int32.min`, `Int32.max`, `Int64.min`, `Int64.max`, `0`, `-1`, `1`.
- Negative numbers produce the same encoded length as their ZigZag positive twin.
- `Int64.min` round-trips correctly — verifies the bit-pattern XOR avoids the `-Int64.min` trap.

### 6.3 `VarintErrorTests` (~8 tests)

- Empty input → `.truncated`.
- `[0x80]` (continuation bit set, no follow-up) → `.truncated`.
- 6-byte u32 with continuation bits set throughout → `.overflow`.
- 11-byte u64 input → `.overflow`.
- 10-byte u64 with payload > 1 in the final byte → `.overflow`.
- 5-byte u32 with payload > 0x0F in the final byte → `.overflow`.
- u64-encoded value exceeding `UInt32.max`, decoded into `UInt32` → `.overflow`.
- Lenient acceptance: `[0x80, 0x00]` decodes to `0` (non-canonical but valid within the byte cap).

### 6.4 `VarintExtensionsTests` (~6 tests)

- `buf.putVarint(150 as UInt32)` produces the same bytes as `Varint.encode(150, into: &buf)`.
- `try reader.readVarintUInt64()` returns the correct value and advances the cursor.
- Round-trip through extensions: encode → freeze → BytesReader → readVarint*.
- Partial-read semantics on `.truncated`: bytes successfully read before the failure remain consumed; only the failed `readUInt8()` (the nil one) does not advance. E.g., decoding `[0x80]` advances the cursor by 1 before throwing, not 0. No rollback.

**Coverage gate:** ≥ 90% on `Sources/Varint/`.

---

## 7. Deferrals

- **SQLite varint** — different format (1–9 bytes, big-endian).
- **VLQ** (MIDI, JSON source maps) — close cousin but separate convention.
- **Protobuf wire format** — Layer 14 owns wire-level serialization.
- **DWARF-specific parsing** — future debug-info module.
- **Async streaming decode** — Layer 11 reactor.
- **`.strict` (canonical-only) mode** — not pursuing; bounded lenient mode is sufficient.
