# Bedrock `UUID` Module — Design Spec

**Date:** 2026-05-10
**Layer:** 1 (Primitives, Bytes, Encodings) — *UUID type and v4/v7/v8 generation*
**Status:** Approved, ready for implementation plan

---

## 1. Scope & Non-Goals

### In scope

- A 128-bit `UUID` value type, stdlib-only.
- **Parse** any version: canonical, brace-wrapped, `urn:uuid:`-prefixed, and 32-char hyphenless. Case-insensitive hex.
- **Format** to multiple shapes: canonical lowercase (default `description`), canonical uppercase, hyphenless, brace-wrapped, URN.
- **Inspect**: `version: Version?` (`.v1`...`.v8`, `nil` for non-RFC-4122 layout) and `variant: Variant` (`.ncs`, `.rfc4122`, `.microsoft`, `.future`).
- **Generate today**: `v4()` (random), `v7()` (Unix-ms timestamp + random), `v8(bytes:)` (custom 122-bit payload). Each has a `using: inout some RandomNumberGenerator` overload; default uses `SystemRandomNumberGenerator`.
- **Wall-clock** access via a tiny libc-bridging shim (`clock_gettime`/`GetSystemTimePreciseAsFileTime`) so `v7()` is callable today without waiting for Layer 5 Time.
- **Conformances**: `Sendable`, `Hashable`, `Equatable`, `Comparable` (big-endian byte order — sorts v7s by timestamp), `CustomStringConvertible`, `LosslessStringConvertible`.
- **Constants**: `UUID.nil` and `UUID.max`.
- **`Bytes` interop**: `init(bytes: Bytes) throws`, `init<S: Sequence>(bytes: S) throws where S.Element == UInt8`, `var bytes: Bytes`.

### Explicitly out of scope (each its own follow-up patch)

- `v1()` / `v6()` generation — wait for Layer 8 MAC enumeration. Parsing/inspecting v1/v6 already works.
- `v3(namespace:name:)` / `v5(namespace:name:)` — wait for Layer 12 MD5/SHA-1. Parsing/inspecting v3/v5 already works.
- Monotonic v7 (per-millisecond counter) — RFC 9562 §6.2 optional hardening.
- `Codable` conformance — Layer 14 owns serialization.
- Foundation `UUID` interop.
- ULID — v7 is the standard replacement.

---

## 2. Module Layout

```
Bedrock/
└── Sources/
    └── UUID/
        ├── UUID.swift              # public struct UUID, conformances, constants
        ├── UUIDVersion.swift       # public enum Version + Variant
        ├── UUIDError.swift         # public enum UUIDError
        ├── UUIDParse.swift         # parsing (canonical/braces/URN/hyphenless)
        ├── UUIDFormat.swift        # formatting + Format enum + description
        ├── UUIDGenerate.swift      # v4 / v7 / v8 generators
        └── Internal/
            └── WallClock.swift     # libc shim: unixWallClockMilliseconds()
└── Tests/
    └── UUIDTests/
        ├── UUIDParseTests.swift
        ├── UUIDFormatTests.swift
        ├── UUIDInspectTests.swift
        ├── UUIDGenerateTests.swift
        ├── UUIDOrderingTests.swift
        └── UUIDConstantsTests.swift
```

`Package.swift` gains one library product `UUID`, one source target depending only on `Bytes`, and one test target.

Six source files (one per concern), six test files. Average file size 100–150 lines; the largest (`UUIDFormat.swift`) is around 200.

The `Internal/WallClock.swift` file is the only OS-dependent code in the module — `#if canImport(...)` shims for Darwin / Glibc / Musl / WinSDK. The rest of the module is pure logic.

---

## 3. Public API

### 3.1 `UUID` core

```swift
// Sources/UUID/UUID.swift

import Bytes

/// A 128-bit universally unique identifier.
///
/// Storage is 16 bytes in network (big-endian) byte order, exposed as
/// `bytes`. Use `description` for canonical lowercase string form.
public struct UUID: Sendable, Hashable, Comparable {

    /// 16 raw bytes in network byte order.
    @usableFromInline let storage: SIMD16<UInt8>

    @usableFromInline
    init(storage: SIMD16<UInt8>) {
        self.storage = storage
    }

    // ─── Constants ────────────────────────────────────────────────────────

    /// All-zero UUID: `00000000-0000-0000-0000-000000000000`.
    public static let `nil` = UUID(storage: SIMD16<UInt8>(repeating: 0))

    /// All-ones UUID: `ffffffff-ffff-ffff-ffff-ffffffffffff`.
    public static let max = UUID(storage: SIMD16<UInt8>(repeating: 0xFF))

    // ─── Bytes interop ────────────────────────────────────────────────────

    /// Construct from exactly 16 bytes in network order.
    public init(bytes: Bytes) throws

    /// Construct from any 16-element UInt8 sequence.
    public init<S: Sequence>(bytes: S) throws where S.Element == UInt8

    /// 16 bytes in network byte order.
    public var bytes: Bytes { get }

    // ─── Inspection ───────────────────────────────────────────────────────

    /// RFC 4122 / 9562 version (`.v1`...`.v8`). `nil` when the variant
    /// isn't `.rfc4122` (the version field has no defined meaning then).
    public var version: Version? { get }

    /// Layout variant per RFC 4122 §4.1.1.
    public var variant: Variant { get }

    // ─── Comparable ──────────────────────────────────────────────────────

    /// Lexicographic byte-wise comparison. Sorts v7 UUIDs in timestamp order.
    public static func < (lhs: UUID, rhs: UUID) -> Bool
}
```

### 3.2 `Version` and `Variant`

```swift
// Sources/UUID/UUIDVersion.swift

extension UUID {
    public enum Version: Int, Sendable, CaseIterable {
        case v1 = 1, v2 = 2, v3 = 3, v4 = 4, v5 = 5, v6 = 6, v7 = 7, v8 = 8
    }

    public enum Variant: Sendable, Equatable {
        case ncs            // 0xx — Apollo NCS legacy
        case rfc4122        // 10x — RFC 4122 / 9562 (the modern standard)
        case microsoft      // 110 — Microsoft GUIDs
        case future         // 111 — reserved
    }
}
```

### 3.3 Format

```swift
// Sources/UUID/UUIDFormat.swift

extension UUID: CustomStringConvertible, LosslessStringConvertible {

    /// Canonical lowercase: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`.
    public var description: String { get }

    /// Lossless init: accepts canonical lowercase only — for round-trip
    /// from `description`. Use `init(_:)` for permissive parsing.
    public init?(_ description: String)

    /// Output format options.
    public enum Format: Sendable {
        case canonicalLower    // 550e8400-e29b-41d4-a716-446655440000
        case canonicalUpper    // 550E8400-E29B-41D4-A716-446655440000
        case hyphenless        // 550e8400e29b41d4a716446655440000
        case braced            // {550e8400-e29b-41d4-a716-446655440000}
        case urn               // urn:uuid:550e8400-e29b-41d4-a716-446655440000
    }

    public func formatted(_ format: Format) -> String
}
```

### 3.4 Parse

```swift
// Sources/UUID/UUIDParse.swift

extension UUID {
    /// Permissive parse: accepts canonical, braces, urn:uuid: prefix,
    /// and 32-char hyphenless. Hex case-insensitive. Throws on any
    /// other shape.
    public init(_ string: String) throws
}
```

### 3.5 Generate

```swift
// Sources/UUID/UUIDGenerate.swift

extension UUID {
    /// Random v4 UUID using `SystemRandomNumberGenerator`.
    public static func v4() -> UUID

    /// Random v4 UUID using a caller-provided RNG.
    public static func v4<R: RandomNumberGenerator>(using rng: inout R) -> UUID

    /// Time-sortable v7 UUID: 48-bit Unix milliseconds + 74 random bits
    /// (RFC 9562 §5.7). Uses the wall-clock shim and `SystemRandomNumberGenerator`.
    public static func v7() -> UUID

    /// v7 with caller-provided clock and RNG.
    public static func v7<R: RandomNumberGenerator>(
        unixMillisecondsSince1970: Int64,
        using rng: inout R
    ) -> UUID

    /// Custom v8 UUID. The provided 16 bytes are stored verbatim except
    /// for the version field (byte 6 high nibble = 8) and variant field
    /// (byte 8 high two bits = 10) per RFC 9562 §5.8 — the application
    /// owns the remaining 122 bits.
    public static func v8(bytes: Bytes) throws -> UUID
}
```

### 3.6 Errors

```swift
// Sources/UUID/UUIDError.swift

public enum UUIDError: Error, Equatable, Sendable {
    /// Input string didn't match any accepted shape (length, hyphens,
    /// or recognized wrapping).
    case invalidFormat
    /// Input had the right shape but contained a non-hex character at
    /// the given UTF-8 byte offset (after URN prefix and brace stripping).
    case invalidHexCharacter(offset: Int, byte: UInt8)
    /// Byte input had the wrong length (UUIDs are exactly 16 bytes).
    case invalidByteCount(Int)
}
```

---

## 4. Storage & Internals

### 4.1 Storage type

`SIMD16<UInt8>` from the standard library — exactly 16 bytes inline, value semantics, stdlib-synthesized `Hashable`/`Equatable`/`Sendable`, indexable by `Int`. Avoids the awkwardness of a `(UInt64, UInt64)` tuple (byte-swap required for `bytes`) and the heap allocation of `[UInt8]`.

### 4.2 Wall-clock shim

`Sources/UUID/Internal/WallClock.swift`:

```swift
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WinSDK)
import WinSDK
#endif

/// Milliseconds since the Unix epoch (1970-01-01 UTC).
/// Internal — only used by v7 generation.
@usableFromInline
internal func unixWallClockMilliseconds() -> Int64 {
    #if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
    var ts = timespec()
    _ = clock_gettime(CLOCK_REALTIME, &ts)
    return Int64(ts.tv_sec) * 1000 + Int64(ts.tv_nsec) / 1_000_000
    #elseif canImport(WinSDK)
    var ft = FILETIME()
    GetSystemTimePreciseAsFileTime(&ft)
    let intervals = (UInt64(ft.dwHighDateTime) << 32) | UInt64(ft.dwLowDateTime)
    let unixEpoch100ns: UInt64 = 116444736000000000
    return Int64((intervals &- unixEpoch100ns) / 10_000)
    #else
    fatalError("No platform clock available for unixWallClockMilliseconds()")
    #endif
}
```

This is the only OS-dependent code in the module. Layer 8's blueprint explicitly endorses libc bridging for POSIX functionality, so this fits the project's stated approach.

---

## 5. Generation Algorithms

### 5.1 v4 (random)

Per RFC 4122 §4.4 / RFC 9562 §5.4:

1. Fill all 16 bytes with random data from the RNG (two `UInt64`s).
2. Stamp version: `byte 6 = (byte 6 & 0x0F) | 0x40` — high nibble = `0100`.
3. Stamp variant: `byte 8 = (byte 8 & 0x3F) | 0x80` — top two bits = `10`.

```swift
public static func v4<R: RandomNumberGenerator>(using rng: inout R) -> UUID {
    var s = SIMD16<UInt8>()
    let lo = rng.next() as UInt64
    let hi = rng.next() as UInt64
    withUnsafeMutableBytes(of: &s) { dst in
        dst.storeBytes(of: lo, toByteOffset: 0, as: UInt64.self)
        dst.storeBytes(of: hi, toByteOffset: 8, as: UInt64.self)
    }
    s[6] = (s[6] & 0x0F) | 0x40
    s[8] = (s[8] & 0x3F) | 0x80
    return UUID(storage: s)
}

public static func v4() -> UUID {
    var rng = SystemRandomNumberGenerator()
    return v4(using: &rng)
}
```

### 5.2 v7 (Unix-ms timestamp + random)

Per RFC 9562 §5.7:

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                          unix_ts_ms                           |  bytes 0-3
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|          unix_ts_ms           |  ver  |       rand_a          |  bytes 4-7
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|var|                        rand_b                             |  bytes 8-11
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                            rand_b                             |  bytes 12-15
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

- Bytes 0–5: 48-bit unsigned big-endian Unix-ms timestamp.
- Byte 6 high nibble: version `0111` = 7.
- Byte 6 low nibble + byte 7: 12 random bits (`rand_a`).
- Byte 8 high two bits: variant `10`.
- Byte 8 low 6 bits + bytes 9–15: 62 random bits (`rand_b`).

```swift
public static func v7<R: RandomNumberGenerator>(
    unixMillisecondsSince1970: Int64,
    using rng: inout R
) -> UUID {
    let ms = UInt64(bitPattern: Int64(unixMillisecondsSince1970)) & 0x0000_FFFF_FFFF_FFFF
    var s = SIMD16<UInt8>()
    s[0] = UInt8((ms >> 40) & 0xFF)
    s[1] = UInt8((ms >> 32) & 0xFF)
    s[2] = UInt8((ms >> 24) & 0xFF)
    s[3] = UInt8((ms >> 16) & 0xFF)
    s[4] = UInt8((ms >>  8) & 0xFF)
    s[5] = UInt8(ms & 0xFF)
    let r0: UInt64 = rng.next()
    let r1: UInt64 = rng.next()
    s[6]  = UInt8((r0 >> 56) & 0xFF)
    s[7]  = UInt8((r0 >> 48) & 0xFF)
    s[8]  = UInt8((r0 >> 40) & 0xFF)
    s[9]  = UInt8((r0 >> 32) & 0xFF)
    s[10] = UInt8((r0 >> 24) & 0xFF)
    s[11] = UInt8((r0 >> 16) & 0xFF)
    s[12] = UInt8((r1 >> 56) & 0xFF)
    s[13] = UInt8((r1 >> 48) & 0xFF)
    s[14] = UInt8((r1 >> 40) & 0xFF)
    s[15] = UInt8((r1 >> 32) & 0xFF)
    s[6] = (s[6] & 0x0F) | 0x70
    s[8] = (s[8] & 0x3F) | 0x80
    return UUID(storage: s)
}

public static func v7() -> UUID {
    var rng = SystemRandomNumberGenerator()
    return v7(unixMillisecondsSince1970: unixWallClockMilliseconds(), using: &rng)
}
```

**No monotonicity guard.** RFC 9562 §6.2 lists per-millisecond monotonicity as optional hardening; deferred. Two v7s generated in the same millisecond may compare in either order.

### 5.3 v8 (custom)

```swift
public static func v8(bytes: Bytes) throws -> UUID {
    guard bytes.count == 16 else {
        throw UUIDError.invalidByteCount(bytes.count)
    }
    var s = SIMD16<UInt8>()
    bytes.withUnsafeBytes { src in
        for i in 0..<16 { s[i] = src[i] }
    }
    s[6] = (s[6] & 0x0F) | 0x80
    s[8] = (s[8] & 0x3F) | 0x80
    return UUID(storage: s)
}
```

---

## 6. Parse & Format

### 6.1 Permissive parse

Strip wrappers, then dispatch to the canonical or hyphenless inner parser:

```swift
public init(_ string: String) throws {
    var s = string

    // Strip URN prefix (case-insensitive).
    if s.lowercased().hasPrefix("urn:uuid:") {
        s = String(s.dropFirst("urn:uuid:".count))
    }
    // Strip braces.
    if s.hasPrefix("{"), s.hasSuffix("}") {
        s = String(s.dropFirst().dropLast())
    }

    let utf8 = Array(s.utf8)
    let bytes: SIMD16<UInt8>
    switch utf8.count {
    case 36: bytes = try Self.parseCanonical(utf8)
    case 32: bytes = try Self.parseHyphenless(utf8)
    default: throw UUIDError.invalidFormat
    }
    self.init(storage: bytes)
}

private static func parseCanonical(_ utf8: [UInt8]) throws -> SIMD16<UInt8> {
    guard utf8[8] == 0x2D && utf8[13] == 0x2D
       && utf8[18] == 0x2D && utf8[23] == 0x2D
    else { throw UUIDError.invalidFormat }
    var out = SIMD16<UInt8>()
    var byteIdx = 0
    var i = 0
    while i < 36 {
        if utf8[i] == 0x2D { i += 1; continue }
        let hi = decodeNibble(utf8[i])
        let lo = decodeNibble(utf8[i + 1])
        if hi == 0xFF { throw UUIDError.invalidHexCharacter(offset: i, byte: utf8[i]) }
        if lo == 0xFF { throw UUIDError.invalidHexCharacter(offset: i + 1, byte: utf8[i + 1]) }
        out[byteIdx] = (hi << 4) | lo
        byteIdx += 1
        i += 2
    }
    return out
}

private static func parseHyphenless(_ utf8: [UInt8]) throws -> SIMD16<UInt8> {
    var out = SIMD16<UInt8>()
    var byteIdx = 0
    var i = 0
    while i < 32 {
        let hi = decodeNibble(utf8[i])
        let lo = decodeNibble(utf8[i + 1])
        if hi == 0xFF { throw UUIDError.invalidHexCharacter(offset: i, byte: utf8[i]) }
        if lo == 0xFF { throw UUIDError.invalidHexCharacter(offset: i + 1, byte: utf8[i + 1]) }
        out[byteIdx] = (hi << 4) | lo
        byteIdx += 1
        i += 2
    }
    return out
}

@inline(__always)
private static func decodeNibble(_ b: UInt8) -> UInt8 {
    switch b {
    case 0x30...0x39: return b - 0x30
    case 0x41...0x46: return b - 0x41 + 10
    case 0x61...0x66: return b - 0x61 + 10
    default: return 0xFF
    }
}
```

The `decodeNibble` logic is a near-duplicate of the Hex module's. **We don't `import Hex`** — UUID is a Layer 1 primitive; cross-importing peer Layer 1 modules creates circular concerns. ~10 lines of duplication is the right call.

**Offset semantics in `invalidHexCharacter`:** the offset is the index into the post-strip UTF-8 byte array (i.e., into `utf8` after URN/brace stripping), not the original input string. Documented on the error case.

### 6.2 Format

```swift
public var description: String { formatted(.canonicalLower) }

public init?(_ description: String) {
    // Lossless: canonical lowercase with hyphens, exact length 36.
    guard description.utf8.count == 36 else { return nil }
    let utf8 = Array(description.utf8)
    // Reject uppercase so description.init?(_:) round-trips to itself.
    for b in utf8 where (0x41...0x46).contains(b) { return nil }
    do {
        let bytes = try Self.parseCanonical(utf8)
        self.init(storage: bytes)
    } catch { return nil }
}

public func formatted(_ format: Format) -> String {
    let alphabet: [UInt8] = (format == .canonicalUpper)
        ? Array("0123456789ABCDEF".utf8)
        : Array("0123456789abcdef".utf8)
    var out: [UInt8] = []
    out.reserveCapacity(45)  // longest: urn:uuid:... = 9 + 36 = 45
    if format == .urn {
        out.append(contentsOf: Array("urn:uuid:".utf8))
    }
    if format == .braced { out.append(0x7B) }
    let needsHyphens = (format != .hyphenless)
    for i in 0..<16 {
        let b = storage[i]
        out.append(alphabet[Int(b >> 4)])
        out.append(alphabet[Int(b & 0x0F)])
        if needsHyphens && (i == 3 || i == 5 || i == 7 || i == 9) {
            out.append(0x2D)
        }
    }
    if format == .braced { out.append(0x7D) }
    return String(decoding: out, as: UTF8.self)
}
```

### 6.3 Inspection

```swift
extension UUID {
    public var version: Version? {
        guard variant == .rfc4122 else { return nil }
        let v = (storage[6] >> 4) & 0x0F
        return Version(rawValue: Int(v))
    }

    public var variant: Variant {
        let bits = storage[8] >> 5  // top three bits
        switch bits {
        case 0b000, 0b001, 0b010, 0b011: return .ncs
        case 0b100, 0b101:                return .rfc4122
        case 0b110:                       return .microsoft
        case 0b111:                       return .future
        default:                          return .future  // unreachable
        }
    }
}
```

### 6.4 Comparable

```swift
public static func < (lhs: UUID, rhs: UUID) -> Bool {
    for i in 0..<16 {
        if lhs.storage[i] != rhs.storage[i] {
            return lhs.storage[i] < rhs.storage[i]
        }
    }
    return false
}
```

Big-endian byte-wise compare. Sorts v7s by timestamp because the timestamp occupies the first 6 bytes in big-endian.

---

## 7. Error Model

| Case | Triggered by |
|---|---|
| `invalidFormat` | Wrong length, missing hyphens at expected positions, unknown wrapping. |
| `invalidHexCharacter(offset:byte:)` | Right shape, non-hex byte. Offset is into the post-strip UTF-8 byte array. |
| `invalidByteCount(Int)` | `init(bytes:)` got the wrong count. |

`v4()` / `v7()` are total. Only `v8(bytes:)` and `init(bytes:)` throw, both for length validation.

---

## 8. Testing Strategy

Six test files, all Swift Testing.

### `UUIDParseTests` (~12 tests)
- RFC examples decode to the expected bytes.
- Canonical, braces, URN, hyphenless all accepted.
- Hex case-insensitive.
- `urn:uuid:` prefix is case-insensitive itself.
- Wrong length throws `invalidFormat`.
- Missing hyphens at expected positions throw `invalidFormat`.
- Non-hex character throws `invalidHexCharacter` with the right offset.
- `init?(_:)` accepts canonical lowercase only; rejects uppercase, braces, URN, hyphenless.

### `UUIDFormatTests` (~8 tests)
- `description` is canonical lowercase, 36 chars.
- Round-trip every `Format` case via `formatted()` → `init(_:)`.
- `.canonicalUpper` is uppercase.
- `.hyphenless` is 32 chars, no hyphens.
- `.braced` starts with `{` and ends with `}`.
- `.urn` starts with `"urn:uuid:"`.

### `UUIDInspectTests` (~10 tests)
- A constructed v4 UUID reports `version == .v4` and `variant == .rfc4122`.
- A constructed v7 UUID reports `version == .v7`.
- A constructed v8 UUID reports `version == .v8`.
- A nil UUID reports `version == nil` and `variant == .ncs`.
- A max UUID reports `version == nil` and `variant == .future`.
- All four variant cases are detectable by manipulating byte 8.
- `Version` raw values match the wire bits.

### `UUIDGenerateTests` (~12 tests)
- `v4()` returns version 4, variant rfc4122.
- `v4(using:)` with a deterministic RNG produces a deterministic byte sequence (excluding the version/variant bits).
- 1000 distinct `v4()`s have no duplicates (smoke).
- `v7(unixMillisecondsSince1970:using:)` puts the timestamp in bytes 0–5 in big-endian, version 7 in byte 6, variant 10x in byte 8.
- `v7()` produces a UUID whose decoded timestamp is within ±1 second of `unixWallClockMilliseconds()` at test time.
- `v8(bytes:)` preserves the caller's bytes except at the version/variant positions.
- `v8(bytes:)` throws `invalidByteCount(15)` for a 15-byte input.

### `UUIDOrderingTests` (~6 tests)
- `Comparable` matches byte-wise lexicographic order.
- `nil` < any other UUID; `max` > any other UUID.
- v7s generated in increasing-ms order sort in that order.
- `Hashable`: equal UUIDs hash equally.

### `UUIDConstantsTests` (~3 tests)
- `nil.bytes` is 16 zero bytes.
- `max.bytes` is 16 0xFF bytes.
- `nil.description == "00000000-0000-0000-0000-000000000000"`.

**Coverage gate:** ≥ 90% on `Sources/UUID/`.

---

## 9. Deferrals

- **`v1()` / `v6()` generation** — wait for Layer 8 MAC enumeration. Parsing/inspecting v1/v6 already works.
- **`v3(namespace:name:)` / `v5(namespace:name:)`** — wait for Layer 12 MD5/SHA-1.
- **Monotonic v7** (per-millisecond counter) — RFC 9562 §6.2 optional hardening.
- **`Codable` conformance** — Layer 14.
- **Foundation `UUID` interop** — only when Foundation lands on the user side.
- **ULID** — v7 is the standard replacement.
