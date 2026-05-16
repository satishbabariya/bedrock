# Bedrock `PercentEncoding` Module — Design Spec

**Date:** 2026-05-16
**Layer:** 1 (Primitives, Bytes, Encodings) — *RFC 3986 / x-www-form-urlencoded byte codec*
**Status:** Approved, ready for implementation plan

---

## 1. Scope & Non-Goals

### In scope

- A `PercentEncoding` namespaced enum with **named encoding sets** for the common RFC 3986 / WHATWG URL contexts.
- **Sets**: `.unreserved` (RFC 3986 §2.3), `.pathSegment`, `.query`, `.fragment`, `.userinfo`, `.component` (only unreserved unencoded — paranoid), `.form` (`application/x-www-form-urlencoded`: space → `+`).
- **Encode** `String` or `Bytes` input → `String` output, plus stream-into-`BytesMut` overloads for I/O paths.
- **Decode** with strict error handling — throws `.malformedEscape(offset:)` on truncated `%`/`%X<eof>` or non-hex digits. Two variants: `decode` (treats `+` as literal `+`) and `decodeForm` (decodes `+` to ASCII space).
- **Decoder returns `Bytes`** — caller validates UTF-8 if expected. URL fields aren't guaranteed text.
- **Extensions** on `String` and `Bytes` (`s.percentEncoded(.query)`, `try Bytes(percentDecoding: s)`).
- Stdlib-only, depends only on `Bytes` from Layer 1.

### Explicitly out of scope (separate designs later)

- **`application/x-www-form-urlencoded` parser/serializer** — the `key=value&key=value` structural layer. This module ships only the byte-level form codec (`+` ↔ space + percent rules); higher-level dict/array handling is form-encoding's own design.
- **URL parser (RFC 3986 + WHATWG)** — Layer 1, T3, separate spec; depends on Layer 2 Unicode tables for IDNA.
- **IRI / IDNA / Punycode** — Layer 2.
- **`multipart/form-data`** — Layer 18 HTTP.

---

## 2. Module Layout

```
Bedrock/
└── Sources/
    └── PercentEncoding/
        ├── PercentEncoding.swift           # public enum namespace + Set enum
        ├── PercentEncodingError.swift      # public enum PercentEncodingError
        ├── PercentEncodingEncode.swift     # encode + into-BytesMut
        ├── PercentEncodingDecode.swift     # decode + decodeForm + into-BytesMut
        ├── PercentEncodingExtensions.swift # String/Bytes extensions
        └── Internal/
            └── Tables.swift                # 256-entry safe-byte tables per Set
└── Tests/
    └── PercentEncodingTests/
        ├── PercentEncodingEncodeTests.swift
        ├── PercentEncodingDecodeTests.swift
        ├── PercentEncodingFormTests.swift
        ├── PercentEncodingErrorTests.swift
        └── PercentEncodingRoundTripTests.swift
```

`Package.swift` gains one library product `PercentEncoding`, one source target depending only on `Bytes`, and one test target.

Six source files (one per concern), five test files. Average 60–120 LOC each. Only depends on `Bytes` from Layer 1.

---

## 3. Public API

### 3.1 `PercentEncoding` namespace + `Set`

```swift
// Sources/PercentEncoding/PercentEncoding.swift

import Bytes

public enum PercentEncoding {

    /// Encoding-set rules per RFC 3986 / WHATWG URL component contexts.
    public enum Set: Sendable {
        /// RFC 3986 §2.3: A–Z a–z 0–9 - _ . ~ left unencoded.
        case unreserved
        /// Path segment: unreserved + sub-delims + `:` + `@`. Encodes `/`.
        case pathSegment
        /// Query: unreserved + sub-delims (minus `&` and `=`) + `:@/?`.
        case query
        /// Fragment: same as query plus `?`.
        case fragment
        /// Userinfo (`user:pass`): unreserved + sub-delims + `:`.
        case userinfo
        /// Strict component: only unreserved bytes unencoded.
        case component
        /// `application/x-www-form-urlencoded`: encodes per `.component`,
        /// but maps ASCII space (0x20) to `+` instead of `%20`.
        case form
    }

    // ─── Encode ───────────────────────────────────────────────────────────

    /// Percent-encode `string` (UTF-8 bytes) using `set`. Returns the
    /// encoded ASCII string.
    public static func encode(_ string: String, as set: Set) -> String

    /// Percent-encode arbitrary bytes using `set`. Returns the encoded
    /// ASCII string.
    public static func encode(_ bytes: Bytes, as set: Set) -> String

    /// Stream-encode UTF-8 bytes of `string` into `out`.
    public static func encode(_ string: String, as set: Set, into out: inout BytesMut)

    /// Stream-encode `bytes` into `out`.
    public static func encode(_ bytes: Bytes, as set: Set, into out: inout BytesMut)

    // ─── Decode ───────────────────────────────────────────────────────────

    /// Decode a percent-encoded string. `+` is treated as a literal `+`
    /// (use `decodeForm` for x-www-form-urlencoded inputs).
    /// Throws `.malformedEscape(offset:)` on truncated or non-hex `%XX`.
    public static func decode(_ string: String) throws -> Bytes

    /// Decode percent-encoded ASCII bytes.
    public static func decode(_ bytes: Bytes) throws -> Bytes

    /// Stream-decode into `out`. Returns the byte count appended.
    @discardableResult
    public static func decode(_ string: String, into out: inout BytesMut) throws -> Int

    /// Decode `application/x-www-form-urlencoded`: same as `decode` but
    /// maps `+` to ASCII space (0x20).
    public static func decodeForm(_ string: String) throws -> Bytes

    /// Stream-decode form into `out`.
    @discardableResult
    public static func decodeForm(_ string: String, into out: inout BytesMut) throws -> Int
}
```

### 3.2 Errors

```swift
// Sources/PercentEncoding/PercentEncodingError.swift

public enum PercentEncodingError: Error, Equatable, Sendable {
    /// A `%` was found without two valid hex digits after it — either
    /// truncated (`%X<eof>` or `%<eof>`) or a non-hex character followed.
    /// The offset is the position of the `%` in the input UTF-8 byte array.
    case malformedEscape(offset: Int)
}
```

### 3.3 Extensions

```swift
// Sources/PercentEncoding/PercentEncodingExtensions.swift

import Bytes

extension String {
    public func percentEncoded(_ set: PercentEncoding.Set) -> String {
        PercentEncoding.encode(self, as: set)
    }
}

extension Bytes {
    public func percentEncoded(_ set: PercentEncoding.Set) -> String {
        PercentEncoding.encode(self, as: set)
    }

    public init(percentDecoding string: String) throws {
        self = try PercentEncoding.decode(string)
    }

    public init(percentDecodingForm string: String) throws {
        self = try PercentEncoding.decodeForm(string)
    }
}
```

### 3.4 Notes on choices

- **Encoder takes `String` or `Bytes`**, returns `String` (percent-encoded output is always ASCII). The `String` overload internally UTF-8-encodes.
- **Decoder returns `Bytes`**, not `String`, because URL fields aren't guaranteed UTF-8 — caller validates if expected.
- **`.form` is the only set with non-byte-table behavior** — it also remaps space → `+` on encode. Encoded inside the set table via a `spaceAsPlus: Bool` flag in the internal `SetTable` struct.
- **`decode` vs `decodeForm`** are separate operations rather than a flag, mirroring Rust's `percent_encoding::percent_decode` vs `form_urlencoded::parse` split.

---

## 4. Algorithms

### 4.1 Safe-byte tables

Each `Set` resolves to a 256-entry `[Bool]` (safe = leave unencoded) plus a `spaceAsPlus: Bool` flag. Tables are computed once at module load by code (auditable, easy to review):

```swift
// Sources/PercentEncoding/Internal/Tables.swift

internal struct SetTable {
    let safe: [Bool]
    let spaceAsPlus: Bool
}

@inline(__always)
private func isUnreserved(_ b: UInt8) -> Bool {
    switch b {
    case 0x41...0x5A, 0x61...0x7A, 0x30...0x39: return true   // A-Z a-z 0-9
    case 0x2D, 0x2E, 0x5F, 0x7E:                return true   // - . _ ~
    default:                                    return false
    }
}

@inline(__always)
private func isSubDelim(_ b: UInt8) -> Bool {
    switch b {
    case 0x21, 0x24, 0x26, 0x27, 0x28, 0x29,                 // ! $ & ' ( )
         0x2A, 0x2B, 0x2C, 0x3B, 0x3D:                       // * + , ; =
        return true
    default: return false
    }
}

internal let unreservedTable = SetTable(
    safe: (0..<256).map { isUnreserved(UInt8($0)) },
    spaceAsPlus: false
)

internal let pathSegmentTable = SetTable(
    safe: (0..<256).map { b in
        let u = UInt8(b)
        return isUnreserved(u) || isSubDelim(u) || u == 0x3A || u == 0x40
        //                                          ':'        '@'
    },
    spaceAsPlus: false
)

internal let queryTable = SetTable(
    safe: (0..<256).map { b in
        let u = UInt8(b)
        // sub-delims minus '&' (0x26) and '=' (0x3D) so they remain
        // meaningful inside a value.
        let subDelimForQuery: Bool = {
            switch u {
            case 0x21, 0x24, 0x27, 0x28, 0x29,
                 0x2A, 0x2B, 0x2C, 0x3B:
                return true
            default: return false
            }
        }()
        return isUnreserved(u) || subDelimForQuery
            || u == 0x3A || u == 0x40 || u == 0x2F || u == 0x3F
        //     ':'           '@'         '/'         '?'
    },
    spaceAsPlus: false
)

internal let fragmentTable = SetTable(
    safe: (0..<256).map { b in
        let u = UInt8(b)
        return isUnreserved(u) || isSubDelim(u)
            || u == 0x3A || u == 0x40 || u == 0x2F || u == 0x3F
    },
    spaceAsPlus: false
)

internal let userinfoTable = SetTable(
    safe: (0..<256).map { b in
        let u = UInt8(b)
        return isUnreserved(u) || isSubDelim(u) || u == 0x3A
    },
    spaceAsPlus: false
)

internal let componentTable = SetTable(
    safe: (0..<256).map { isUnreserved(UInt8($0)) },
    spaceAsPlus: false
)

internal let formTable = SetTable(
    safe: (0..<256).map { isUnreserved(UInt8($0)) },
    spaceAsPlus: true
)

/// Uppercase hex alphabet for encoding (RFC 3986 §2.1 SHOULD).
internal let hexUpper: [UInt8] = Array("0123456789ABCDEF".utf8)

@inline(__always)
internal func setTable(for set: PercentEncoding.Set) -> SetTable {
    switch set {
    case .unreserved:  return unreservedTable
    case .pathSegment: return pathSegmentTable
    case .query:       return queryTable
    case .fragment:    return fragmentTable
    case .userinfo:    return userinfoTable
    case .component:   return componentTable
    case .form:        return formTable
    }
}

/// Local nibble decoder — duplicated from Hex by design (peer Layer 1 module).
@inline(__always)
internal func decodeNibble(_ b: UInt8) -> UInt8 {
    switch b {
    case 0x30...0x39: return b - 0x30           // '0'-'9'
    case 0x41...0x46: return b - 0x41 + 10      // 'A'-'F'
    case 0x61...0x66: return b - 0x61 + 10      // 'a'-'f'
    default:          return 0xFF
    }
}
```

RFC 3986 §2.1: "uppercase hexadecimal digits should be used for consistency." We emit uppercase but decode case-insensitively.

### 4.2 Encode

```swift
public static func encode(_ bytes: Bytes, as set: Set, into out: inout BytesMut) {
    let t = setTable(for: set)
    out.reserveCapacity(out.count + bytes.count)   // best case; grows if needed
    bytes.withUnsafeBytes { src in
        for b in src {
            if b == 0x20 && t.spaceAsPlus {
                out.putUInt8(0x2B)        // '+'
            } else if t.safe[Int(b)] {
                out.putUInt8(b)
            } else {
                out.putUInt8(0x25)        // '%'
                out.putUInt8(hexUpper[Int(b >> 4)])
                out.putUInt8(hexUpper[Int(b & 0x0F)])
            }
        }
    }
}

public static func encode(_ bytes: Bytes, as set: Set) -> String {
    var buf = BytesMut(capacity: bytes.count)
    encode(bytes, as: set, into: &buf)
    return String(decoding: buf.freeze(), as: UTF8.self)
}

public static func encode(_ string: String, as set: Set) -> String {
    let arr = Array(string.utf8)
    return encode(Bytes(arr), as: set)
}

public static func encode(_ string: String, as set: Set, into out: inout BytesMut) {
    let arr = Array(string.utf8)
    encode(Bytes(arr), as: set, into: &out)
}
```

### 4.3 Decode

```swift
private static func decodeBytes(
    _ src: [UInt8],
    plusToSpace: Bool,
    into out: inout BytesMut
) throws {
    var i = 0
    while i < src.count {
        let b = src[i]
        if b == 0x25 {                          // '%'
            guard i + 2 < src.count else {
                throw PercentEncodingError.malformedEscape(offset: i)
            }
            let hi = decodeNibble(src[i + 1])
            let lo = decodeNibble(src[i + 2])
            if hi == 0xFF || lo == 0xFF {
                throw PercentEncodingError.malformedEscape(offset: i)
            }
            out.putUInt8((hi << 4) | lo)
            i += 3
        } else if b == 0x2B && plusToSpace {    // '+'
            out.putUInt8(0x20)
            i += 1
        } else {
            out.putUInt8(b)
            i += 1
        }
    }
}

public static func decode(_ string: String) throws -> Bytes {
    var out = BytesMut(capacity: string.utf8.count)
    try decodeBytes(Array(string.utf8), plusToSpace: false, into: &out)
    return out.freeze()
}

public static func decode(_ bytes: Bytes) throws -> Bytes {
    var arr: [UInt8] = []
    arr.reserveCapacity(bytes.count)
    bytes.withUnsafeBytes { src in
        arr.append(contentsOf: src)
    }
    var out = BytesMut(capacity: arr.count)
    try decodeBytes(arr, plusToSpace: false, into: &out)
    return out.freeze()
}

@discardableResult
public static func decode(_ string: String, into out: inout BytesMut) throws -> Int {
    let before = out.count
    try decodeBytes(Array(string.utf8), plusToSpace: false, into: &out)
    return out.count - before
}

public static func decodeForm(_ string: String) throws -> Bytes {
    var out = BytesMut(capacity: string.utf8.count)
    try decodeBytes(Array(string.utf8), plusToSpace: true, into: &out)
    return out.freeze()
}

@discardableResult
public static func decodeForm(_ string: String, into out: inout BytesMut) throws -> Int {
    let before = out.count
    try decodeBytes(Array(string.utf8), plusToSpace: true, into: &out)
    return out.count - before
}
```

**Bounds check semantics:** `i + 2 < src.count` (strictly less) ensures both `src[i+1]` and `src[i+2]` are in range. A `%` at the last or second-to-last position throws `.malformedEscape(offset: i)`.

### 4.4 Failure-mode specifics

- **Truncated `%`**: a `%` at offset *n* where *n+2 ≥ src.count* → `.malformedEscape(offset: n)`.
- **Non-hex digit after `%`**: either nibble is `0xFF` (sentinel) → `.malformedEscape(offset: n)`. Offset is the `%`, not the bad nibble, so callers can locate the start of the problem.
- The decoder is otherwise lenient: any byte that isn't `%` (or `+` in form mode) passes through verbatim. Bytes ≥ 0x80 inside `String` UTF-8 decode unchanged; this matches WHATWG percent-decode behavior.

---

## 5. Error Model

| Case | Triggered by |
|---|---|
| `.malformedEscape(offset: Int)` | `%` not followed by exactly two hex digits, or `%` at the input's tail with < 2 trailing bytes. Offset points at the `%`. |

`encode` is total — no throws.

---

## 6. Testing Strategy

Five test files, all Swift Testing (`@Test` / `#expect`).

### 6.1 `PercentEncodingEncodeTests` (~12 tests)
- RFC 3986 §2.4 example: `"Hello World!"` → `"Hello%20World!"` with `.fragment` (`!` is allowed); `"Hello%20World%21"` with `.component` (`!` is not).
- Empty input → empty output for every set.
- Each predefined set: a representative byte that's safe AND one that isn't.
- Reserved-character behavior: encoding `/` with `.pathSegment` produces `%2F`; encoding `/` with `.query` leaves it alone.
- Bytes ≥ 0x80 always get percent-encoded.
- `Bytes` and `String` input overloads produce identical results for the same UTF-8 content.
- Streaming `encode(_:as:into:)` appends to a pre-populated `BytesMut` without overwriting.

### 6.2 `PercentEncodingDecodeTests` (~10 tests)
- Round-trip vectors from the encode tests.
- Lowercase hex in `%XX` is accepted (`%2f` decodes to `/`).
- Bytes that look like delimiters (`+`, `&`, `=`) pass through verbatim under `decode` (form mode is separate).
- Mixed `%`-escapes and literal bytes interleave correctly.
- One-shot `decode(_: Bytes)` matches `decode(_: String)` for the same UTF-8.
- `decode(_:into:)` returns the correct byte count and appends.

### 6.3 `PercentEncodingFormTests` (~5 tests)
- `.form` encoder: `"hello world"` → `"hello+world"`.
- `.form` encoder: `"a+b"` → `"a%2Bb"` (literal `+` in input must be percent-encoded so it round-trips through `+`/space conversion).
- `decodeForm`: `"a+b"` → `"a b"`.
- `decodeForm`: `"a%2Bb"` → `"a+b"`.
- Round-trip through `.form` + `decodeForm` for `"hello world+foo"`.

### 6.4 `PercentEncodingErrorTests` (~5 tests)
- `decode("%")` → `malformedEscape(offset: 0)`.
- `decode("%G0")` → `malformedEscape(offset: 0)` (non-hex high nibble).
- `decode("%2G")` → `malformedEscape(offset: 0)` (non-hex low nibble).
- `decode("abc%")` → `malformedEscape(offset: 3)`.
- `decode("abc%2")` → `malformedEscape(offset: 3)` (one hex digit then EOF).

### 6.5 `PercentEncodingRoundTripTests` (~4 tests)
- Round-trip every byte 0x00…0xFF through `.component` set and `decode`.
- Round-trip a 4 KiB deterministic-random buffer through `.component`.
- Round-trip every byte through `.form` + `decodeForm`.
- Round-trip every set: encode an input that exercises both safe and unsafe bytes; decode back.

**Coverage gate:** ≥ 90% on `Sources/PercentEncoding/`.

---

## 7. Deferrals

- **`application/x-www-form-urlencoded` parser/serializer** — key-value structure (multi-value keys, ordering).
- **URL parser (RFC 3986 + WHATWG)** — depends on Layer 2 Unicode tables.
- **IRI / IDNA / Punycode** — Layer 2.
- **`multipart/form-data`** — Layer 18 HTTP.
