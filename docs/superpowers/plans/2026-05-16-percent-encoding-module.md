# PercentEncoding Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a stdlib-only `PercentEncoding` module with RFC 3986 / WHATWG-aware named encoding sets and an x-www-form-urlencoded decoder, integrated with the existing `Bytes` module.

**Architecture:** A namespaced `public enum PercentEncoding` with a nested `Set` enum dispatching to internal 256-entry safe-byte lookup tables. Encoders write into `BytesMut` and produce `String`; decoders read `String`/`Bytes` and produce `Bytes`. Two decode entry points: `decode` (literal `+`) and `decodeForm` (decodes `+` to space). `String`/`Bytes` extension methods provide the ergonomic API surface.

**Tech Stack:** Swift 6 (toolchain ≥ 6.0), SwiftPM, Swift Testing. Depends only on `Bytes`. No third-party dependencies, no Foundation.

**Source spec:** `docs/superpowers/specs/2026-05-16-percent-encoding-design.md`.

**Working directory:** `/Users/satishbabariya/Desktop/Bedrock`. Run all `swift` commands from there.

---

## Task 1: Package scaffolding

**Files:**
- Modify: `Package.swift`
- Create: `Sources/PercentEncoding/PercentEncoding.swift` (placeholder)
- Create: `Tests/PercentEncodingTests/SmokeTest.swift`

- [ ] **Step 1: Update Package.swift**

Replace `Package.swift` with:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Bedrock",
    products: [
        .library(name: "Bytes", targets: ["Bytes"]),
        .library(name: "Hex", targets: ["Hex"]),
        .library(name: "Base64", targets: ["Base64"]),
        .library(name: "UUID", targets: ["UUID"]),
        .library(name: "Varint", targets: ["Varint"]),
        .library(name: "PercentEncoding", targets: ["PercentEncoding"]),
    ],
    targets: [
        .target(name: "Bytes", path: "Sources/Bytes"),
        .testTarget(name: "BytesTests", dependencies: ["Bytes"], path: "Tests/BytesTests"),

        .target(name: "Hex", dependencies: ["Bytes"], path: "Sources/Hex"),
        .testTarget(name: "HexTests", dependencies: ["Hex", "Bytes"], path: "Tests/HexTests"),

        .target(name: "Base64", dependencies: ["Bytes"], path: "Sources/Base64"),
        .testTarget(name: "Base64Tests", dependencies: ["Base64", "Bytes"], path: "Tests/Base64Tests"),

        .target(name: "UUID", dependencies: ["Bytes"], path: "Sources/UUID"),
        .testTarget(name: "UUIDTests", dependencies: ["UUID", "Bytes"], path: "Tests/UUIDTests"),

        .target(name: "Varint", dependencies: ["Bytes"], path: "Sources/Varint"),
        .testTarget(name: "VarintTests", dependencies: ["Varint", "Bytes"], path: "Tests/VarintTests"),

        .target(name: "PercentEncoding", dependencies: ["Bytes"], path: "Sources/PercentEncoding"),
        .testTarget(name: "PercentEncodingTests", dependencies: ["PercentEncoding", "Bytes"], path: "Tests/PercentEncodingTests"),
    ]
)
```

- [ ] **Step 2: Create placeholder source file**

Create `Sources/PercentEncoding/PercentEncoding.swift`:

```swift
// PercentEncoding — implemented in Task 2+.
@usableFromInline internal let _percentEncodingModuleLoaded = true
```

- [ ] **Step 3: Create the smoke test**

Create `Tests/PercentEncodingTests/SmokeTest.swift`:

```swift
import Testing
@testable import PercentEncoding

@Test func percentEncodingModuleLoads() {
    #expect(_percentEncodingModuleLoaded == true)
}
```

- [ ] **Step 4: Verify build + tests**

Run: `swift test`
Expected: all prior tests pass + 1 new smoke test.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/PercentEncoding Tests/PercentEncodingTests
git commit -m "PercentEncoding: scaffold module and smoke test"
```

---

## Task 2: PercentEncodingError + namespace + Set enum

**Files:**
- Create: `Sources/PercentEncoding/PercentEncodingError.swift`
- Modify: `Sources/PercentEncoding/PercentEncoding.swift` (replace placeholder with namespace + Set)
- Create: `Tests/PercentEncodingTests/PercentEncodingErrorTests.swift`
- Modify: `Tests/PercentEncodingTests/SmokeTest.swift` (replace stale placeholder reference)

- [ ] **Step 1: Write the failing tests**

Create `Tests/PercentEncodingTests/PercentEncodingErrorTests.swift`:

```swift
import Testing
@testable import PercentEncoding

@Test func errorEquality() {
    #expect(PercentEncodingError.malformedEscape(offset: 0)
            == PercentEncodingError.malformedEscape(offset: 0))
    #expect(PercentEncodingError.malformedEscape(offset: 0)
            != PercentEncodingError.malformedEscape(offset: 3))
}

@Test func setEnumCases() {
    let cases: [PercentEncoding.Set] = [
        .unreserved, .pathSegment, .query, .fragment,
        .userinfo, .component, .form,
    ]
    #expect(cases.count == 7)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter PercentEncodingErrorTests`
Expected: compile errors — types not defined.

- [ ] **Step 3: Implement PercentEncodingError**

Create `Sources/PercentEncoding/PercentEncodingError.swift`:

```swift
/// Errors raised by percent-encoded input decoding.
public enum PercentEncodingError: Error, Equatable, Sendable {
    /// A `%` was found without two valid hex digits after it — either
    /// truncated (`%X<eof>` or `%<eof>`) or a non-hex character followed.
    /// The offset is the position of the `%` in the input UTF-8 byte array.
    case malformedEscape(offset: Int)
}
```

- [ ] **Step 4: Implement the PercentEncoding namespace + Set**

Replace `Sources/PercentEncoding/PercentEncoding.swift` with:

```swift
import Bytes

/// RFC 3986 / x-www-form-urlencoded percent-encoding codec namespace.
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
}
```

- [ ] **Step 5: Update the smoke test**

Replace `Tests/PercentEncodingTests/SmokeTest.swift` with:

```swift
import Testing
@testable import PercentEncoding

@Test func percentEncodingNamespaceExists() {
    let _: PercentEncoding.Set = .unreserved
    #expect(true)
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `swift test --filter PercentEncodingTests`
Expected: 3 tests pass (1 smoke + 2 error/set).

- [ ] **Step 7: Commit**

```bash
git add Sources/PercentEncoding Tests/PercentEncodingTests
git commit -m "PercentEncoding: add namespace, Set enum, and PercentEncodingError"
```

---

## Task 3: Internal tables (safe-byte + nibble decode)

**Files:**
- Create: `Sources/PercentEncoding/Internal/Tables.swift`
- (No standalone tests — tables are exercised by Task 4 encode tests)

- [ ] **Step 1: Implement the tables**

Create `Sources/PercentEncoding/Internal/Tables.swift`:

```swift
/// Per-set encoding rules: safe-byte bitmap (256 entries) + space-as-plus flag.
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

/// Uppercase hex alphabet (RFC 3986 §2.1 SHOULD).
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

- [ ] **Step 2: Verify it builds**

Run: `swift build`
Expected: build succeeds with no warnings.

- [ ] **Step 3: Commit**

```bash
git add Sources/PercentEncoding/Internal/Tables.swift
git commit -m "PercentEncoding: add per-set safe-byte tables and nibble decoder"
```

---

## Task 4: Encode (all four overloads + tests)

**Files:**
- Create: `Sources/PercentEncoding/PercentEncodingEncode.swift`
- Create: `Tests/PercentEncodingTests/PercentEncodingEncodeTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/PercentEncodingTests/PercentEncodingEncodeTests.swift`:

```swift
import Testing
import Bytes
@testable import PercentEncoding

@Test func encodeEmptyForEverySet() {
    let sets: [PercentEncoding.Set] = [
        .unreserved, .pathSegment, .query, .fragment,
        .userinfo, .component, .form,
    ]
    for set in sets {
        #expect(PercentEncoding.encode("", as: set) == "")
    }
}

@Test func encodeUnreservedRFCExample() {
    // 'Hello' all unreserved; space and '!' are not.
    #expect(PercentEncoding.encode("Hello World!", as: .unreserved)
            == "Hello%20World%21")
}

@Test func encodeFragmentAllowsExclamation() {
    // '!' is a sub-delim, allowed in fragment.
    #expect(PercentEncoding.encode("Hello World!", as: .fragment)
            == "Hello%20World!")
}

@Test func encodeComponentEncodesExclamation() {
    // .component is the strict set — only unreserved unencoded.
    #expect(PercentEncoding.encode("Hello World!", as: .component)
            == "Hello%20World%21")
}

@Test func encodeSlashInPathSegmentIsEncoded() {
    #expect(PercentEncoding.encode("a/b", as: .pathSegment) == "a%2Fb")
}

@Test func encodeSlashInQueryIsLiteral() {
    #expect(PercentEncoding.encode("a/b", as: .query) == "a/b")
}

@Test func encodeAmpersandAndEqualsInQueryEncoded() {
    // Query set removes '&' and '=' from sub-delims so they encode.
    #expect(PercentEncoding.encode("a=1&b=2", as: .query) == "a%3D1%26b%3D2")
}

@Test func encodeColonInUserinfoIsLiteral() {
    #expect(PercentEncoding.encode("user:pass", as: .userinfo) == "user:pass")
}

@Test func encodeBytesAbove127AlwaysEncoded() {
    // Non-ASCII bytes always get percent-encoded for every set.
    let bytes = Bytes([0xC3, 0xA9])  // "é" in UTF-8
    #expect(PercentEncoding.encode(bytes, as: .fragment) == "%C3%A9")
}

@Test func encodeBytesAndStringOverloadsMatch() {
    let s = "Hello World!"
    let b = Bytes(Array(s.utf8))
    for set in [PercentEncoding.Set.unreserved, .pathSegment, .query, .fragment, .component] {
        #expect(PercentEncoding.encode(s, as: set) == PercentEncoding.encode(b, as: set))
    }
}

@Test func encodeUsesUppercaseHex() {
    // RFC 3986 §2.1: "uppercase hexadecimal digits should be used".
    let s = PercentEncoding.encode("ÿ", as: .component)
    #expect(s == "%C3%BF")
    #expect(s == s.uppercased())
}

@Test func encodeIntoBytesMutAppends() {
    var buf = BytesMut()
    buf.putUInt8(0xAA)
    PercentEncoding.encode("a b", as: .component, into: &buf)
    let frozen = buf.freeze()
    // 0xAA + "a%20b" = [0xAA, 0x61, 0x25, 0x32, 0x30, 0x62]
    #expect(Array(frozen) == [0xAA, 0x61, 0x25, 0x32, 0x30, 0x62])
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter PercentEncodingEncodeTests`
Expected: compile errors — `PercentEncoding.encode` not defined.

- [ ] **Step 3: Implement encode**

Create `Sources/PercentEncoding/PercentEncodingEncode.swift`:

```swift
import Bytes

extension PercentEncoding {

    /// Percent-encode `bytes` into `out` using `set`. Bytes that are "safe"
    /// per the set pass through; bytes that are unsafe become `%XX`
    /// (uppercase hex). `.form` additionally maps space (0x20) to `+`.
    public static func encode(_ bytes: Bytes, as set: Set, into out: inout BytesMut) {
        let t = setTable(for: set)
        out.reserveCapacity(out.count + bytes.count)
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

    /// Percent-encode `bytes` using `set`. Returns the encoded ASCII string.
    public static func encode(_ bytes: Bytes, as set: Set) -> String {
        var buf = BytesMut(capacity: bytes.count)
        encode(bytes, as: set, into: &buf)
        return String(decoding: buf.freeze(), as: UTF8.self)
    }

    /// Percent-encode the UTF-8 bytes of `string` using `set`.
    public static func encode(_ string: String, as set: Set) -> String {
        let arr = Array(string.utf8)
        return encode(Bytes(arr), as: set)
    }

    /// Stream-encode the UTF-8 bytes of `string` into `out`.
    public static func encode(_ string: String, as set: Set, into out: inout BytesMut) {
        let arr = Array(string.utf8)
        encode(Bytes(arr), as: set, into: &out)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter PercentEncodingEncodeTests`
Expected: all 12 encode tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/PercentEncoding/PercentEncodingEncode.swift Tests/PercentEncodingTests/PercentEncodingEncodeTests.swift
git commit -m "PercentEncoding: add encode (all sets, Bytes/String/BytesMut overloads)"
```

---

## Task 5: Decode + decodeForm + error tests

**Files:**
- Create: `Sources/PercentEncoding/PercentEncodingDecode.swift`
- Create: `Tests/PercentEncodingTests/PercentEncodingDecodeTests.swift`
- Modify: `Tests/PercentEncodingTests/PercentEncodingErrorTests.swift` (append decode-error tests)

- [ ] **Step 1: Write the failing tests**

Create `Tests/PercentEncodingTests/PercentEncodingDecodeTests.swift`:

```swift
import Testing
import Bytes
@testable import PercentEncoding

@Test func decodeEmpty() throws {
    #expect(Array(try PercentEncoding.decode("")) == [])
}

@Test func decodeLiteralPassthrough() throws {
    // All-unreserved input passes through unchanged.
    let s = "abc-_.~"
    let out = try PercentEncoding.decode(s)
    #expect(Array(out) == Array(s.utf8))
}

@Test func decodePercentEscapes() throws {
    let out = try PercentEncoding.decode("a%20b%2Fc")
    #expect(out == Bytes([0x61, 0x20, 0x62, 0x2F, 0x63]))
}

@Test func decodeAcceptsLowercaseHex() throws {
    // RFC 3986: producers SHOULD emit uppercase; consumers MUST accept either.
    let out = try PercentEncoding.decode("%2f")
    #expect(out == Bytes([0x2F]))
}

@Test func decodePlusIsLiteral() throws {
    // decode (non-form) treats '+' as literal byte 0x2B.
    let out = try PercentEncoding.decode("a+b")
    #expect(out == Bytes([0x61, 0x2B, 0x62]))
}

@Test func decodeDelimitersAreLiteral() throws {
    let out = try PercentEncoding.decode("a&b=c")
    #expect(out == Bytes(Array("a&b=c".utf8)))
}

@Test func decodeRoundTripsRFCExample() throws {
    let encoded = PercentEncoding.encode("Hello World!", as: .component)
    let decoded = try PercentEncoding.decode(encoded)
    #expect(decoded == Bytes(Array("Hello World!".utf8)))
}

@Test func decodeNonAsciiBytesPassThrough() throws {
    // Bytes ≥ 0x80 (from a String's UTF-8) decode unchanged.
    let s = "é"  // UTF-8: 0xC3 0xA9
    let out = try PercentEncoding.decode(s)
    #expect(Array(out) == [0xC3, 0xA9])
}

@Test func decodeFromBytesMatchesFromString() throws {
    let s = "a%20b"
    let viaString = try PercentEncoding.decode(s)
    let viaBytes  = try PercentEncoding.decode(Bytes(Array(s.utf8)))
    #expect(viaString == viaBytes)
}

@Test func decodeIntoBytesMutReturnsByteCount() throws {
    var out = BytesMut()
    out.putUInt8(0xAA)
    let n = try PercentEncoding.decode("a%20b", into: &out)
    #expect(n == 3)
    let frozen = out.freeze()
    #expect(Array(frozen) == [0xAA, 0x61, 0x20, 0x62])
}
```

Append to `Tests/PercentEncodingTests/PercentEncodingErrorTests.swift`:

```swift
@Test func decodeBareEscapeThrows() {
    #expect(throws: PercentEncodingError.malformedEscape(offset: 0)) {
        _ = try PercentEncoding.decode("%")
    }
}

@Test func decodeNonHexHighNibbleThrows() {
    #expect(throws: PercentEncodingError.malformedEscape(offset: 0)) {
        _ = try PercentEncoding.decode("%G0")
    }
}

@Test func decodeNonHexLowNibbleThrows() {
    #expect(throws: PercentEncodingError.malformedEscape(offset: 0)) {
        _ = try PercentEncoding.decode("%2G")
    }
}

@Test func decodeTruncatedEscapeAtEndThrows() {
    #expect(throws: PercentEncodingError.malformedEscape(offset: 3)) {
        _ = try PercentEncoding.decode("abc%")
    }
}

@Test func decodeOneHexDigitThenEOFThrows() {
    #expect(throws: PercentEncodingError.malformedEscape(offset: 3)) {
        _ = try PercentEncoding.decode("abc%2")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter PercentEncodingTests`
Expected: compile errors — `PercentEncoding.decode` and `decodeForm` not defined.

- [ ] **Step 3: Implement decode + decodeForm**

Create `Sources/PercentEncoding/PercentEncodingDecode.swift`:

```swift
import Bytes

extension PercentEncoding {

    /// Shared internal byte-level decoder. Appends decoded bytes into `out`.
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
            } else if b == 0x2B && plusToSpace {    // '+' in form mode
                out.putUInt8(0x20)
                i += 1
            } else {
                out.putUInt8(b)
                i += 1
            }
        }
    }

    /// Decode a percent-encoded string. `+` is treated as a literal `+`.
    /// Throws `.malformedEscape(offset:)` on truncated or non-hex `%XX`.
    public static func decode(_ string: String) throws -> Bytes {
        var out = BytesMut(capacity: string.utf8.count)
        try decodeBytes(Array(string.utf8), plusToSpace: false, into: &out)
        return out.freeze()
    }

    /// Decode percent-encoded ASCII bytes.
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

    /// Stream-decode `string` into `out`. Returns the byte count appended.
    @discardableResult
    public static func decode(_ string: String, into out: inout BytesMut) throws -> Int {
        let before = out.count
        try decodeBytes(Array(string.utf8), plusToSpace: false, into: &out)
        return out.count - before
    }

    /// Decode `application/x-www-form-urlencoded`: same as `decode` but
    /// maps `+` to ASCII space (0x20).
    public static func decodeForm(_ string: String) throws -> Bytes {
        var out = BytesMut(capacity: string.utf8.count)
        try decodeBytes(Array(string.utf8), plusToSpace: true, into: &out)
        return out.freeze()
    }

    /// Stream-decode form into `out`. Returns the byte count appended.
    @discardableResult
    public static func decodeForm(_ string: String, into out: inout BytesMut) throws -> Int {
        let before = out.count
        try decodeBytes(Array(string.utf8), plusToSpace: true, into: &out)
        return out.count - before
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter PercentEncodingTests`
Expected: all PercentEncoding tests pass (encode + decode + error).

- [ ] **Step 5: Commit**

```bash
git add Sources/PercentEncoding/PercentEncodingDecode.swift Tests/PercentEncodingTests/PercentEncodingDecodeTests.swift Tests/PercentEncodingTests/PercentEncodingErrorTests.swift
git commit -m "PercentEncoding: add decode/decodeForm with structured error reporting"
```

---

## Task 6: Form-specific encode/decode tests

**Files:**
- Create: `Tests/PercentEncodingTests/PercentEncodingFormTests.swift`

The `.form` set behavior is already implemented (the `spaceAsPlus` flag in `formTable`); this task just adds focused tests.

- [ ] **Step 1: Write the tests**

Create `Tests/PercentEncodingTests/PercentEncodingFormTests.swift`:

```swift
import Testing
import Bytes
@testable import PercentEncoding

@Test func formEncodeSpaceBecomesPlus() {
    #expect(PercentEncoding.encode("hello world", as: .form) == "hello+world")
}

@Test func formEncodeLiteralPlusIsPercentEncoded() {
    // Crucial: a literal '+' in input must become %2B so it survives the
    // +/space conversion on decode.
    #expect(PercentEncoding.encode("a+b", as: .form) == "a%2Bb")
}

@Test func decodeFormPlusBecomesSpace() throws {
    let out = try PercentEncoding.decodeForm("a+b")
    #expect(out == Bytes([0x61, 0x20, 0x62]))   // "a b"
}

@Test func decodeFormPercentEncodedPlusBecomesLiteralPlus() throws {
    let out = try PercentEncoding.decodeForm("a%2Bb")
    #expect(out == Bytes([0x61, 0x2B, 0x62]))   // "a+b"
}

@Test func roundTripFormEncodeDecodeForm() throws {
    let original = "hello world+foo"
    let encoded = PercentEncoding.encode(original, as: .form)
    let decoded = try PercentEncoding.decodeForm(encoded)
    #expect(Array(decoded) == Array(original.utf8))
}

@Test func decodeFormIntoBytesMutReturnsCount() throws {
    var out = BytesMut()
    out.putUInt8(0xAA)
    let n = try PercentEncoding.decodeForm("a+b", into: &out)
    #expect(n == 3)
    let frozen = out.freeze()
    #expect(Array(frozen) == [0xAA, 0x61, 0x20, 0x62])
}
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `swift test --filter PercentEncodingFormTests`
Expected: 6 tests pass (form behavior already implemented in Tasks 3 + 5).

- [ ] **Step 3: Commit**

```bash
git add Tests/PercentEncodingTests/PercentEncodingFormTests.swift
git commit -m "PercentEncoding: tests for x-www-form-urlencoded space+ behavior"
```

---

## Task 7: Extensions on Bytes and String

**Files:**
- Create: `Sources/PercentEncoding/PercentEncodingExtensions.swift`
- Create: `Tests/PercentEncodingTests/PercentEncodingExtensionsTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/PercentEncodingTests/PercentEncodingExtensionsTests.swift`:

```swift
import Testing
import Bytes
@testable import PercentEncoding

@Test func stringPercentEncodedMatchesNamespaceForm() {
    let s = "Hello World!"
    #expect(s.percentEncoded(.fragment)
            == PercentEncoding.encode(s, as: .fragment))
}

@Test func bytesPercentEncodedMatchesNamespaceForm() {
    let b = Bytes(Array("Hello World!".utf8))
    #expect(b.percentEncoded(.component)
            == PercentEncoding.encode(b, as: .component))
}

@Test func bytesPercentDecodingMatchesNamespaceForm() throws {
    let s = "a%20b"
    let via = try Bytes(percentDecoding: s)
    let direct = try PercentEncoding.decode(s)
    #expect(via == direct)
}

@Test func bytesPercentDecodingFormMatchesNamespaceForm() throws {
    let s = "hello+world"
    let via = try Bytes(percentDecodingForm: s)
    let direct = try PercentEncoding.decodeForm(s)
    #expect(via == direct)
}

@Test func extensionDecodeThrowsOnMalformed() {
    #expect(throws: PercentEncodingError.malformedEscape(offset: 0)) {
        _ = try Bytes(percentDecoding: "%")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter PercentEncodingExtensionsTests`
Expected: compile errors — extension methods not defined.

- [ ] **Step 3: Implement the extensions**

Create `Sources/PercentEncoding/PercentEncodingExtensions.swift`:

```swift
import Bytes

extension String {
    /// Percent-encode this String's UTF-8 bytes using `set`.
    public func percentEncoded(_ set: PercentEncoding.Set) -> String {
        PercentEncoding.encode(self, as: set)
    }
}

extension Bytes {
    /// Percent-encode this byte buffer using `set`.
    public func percentEncoded(_ set: PercentEncoding.Set) -> String {
        PercentEncoding.encode(self, as: set)
    }

    /// Decode a percent-encoded string. `+` is treated as literal.
    public init(percentDecoding string: String) throws {
        self = try PercentEncoding.decode(string)
    }

    /// Decode an `application/x-www-form-urlencoded` string. `+` decodes
    /// to ASCII space.
    public init(percentDecodingForm string: String) throws {
        self = try PercentEncoding.decodeForm(string)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter PercentEncodingExtensionsTests`
Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/PercentEncoding/PercentEncodingExtensions.swift Tests/PercentEncodingTests/PercentEncodingExtensionsTests.swift
git commit -m "PercentEncoding: add String/Bytes percent-encoding extensions"
```

---

## Task 8: Round-trip tests + final verification + Layer 1 cross-link + push

**Files:**
- Create: `Tests/PercentEncodingTests/PercentEncodingRoundTripTests.swift`
- Modify: `layers/layer-01-primitives.md`

- [ ] **Step 1: Write the round-trip tests**

Create `Tests/PercentEncodingTests/PercentEncodingRoundTripTests.swift`:

```swift
import Testing
import Bytes
@testable import PercentEncoding

@Test func roundTripEveryByteThroughComponent() throws {
    let raw: [UInt8] = (0..<256).map { UInt8($0) }
    let original = Bytes(raw)
    let encoded = PercentEncoding.encode(original, as: .component)
    let decoded = try PercentEncoding.decode(encoded)
    #expect(decoded == original)
}

@Test func roundTripEveryByteThroughForm() throws {
    let raw: [UInt8] = (0..<256).map { UInt8($0) }
    let original = Bytes(raw)
    let encoded = PercentEncoding.encode(original, as: .form)
    let decoded = try PercentEncoding.decodeForm(encoded)
    #expect(decoded == original)
}

@Test func roundTripDeterministicRandom() throws {
    var state: UInt64 = 0xC0FFEE_FACE_F00D
    func next() -> UInt8 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return UInt8((state >> 56) & 0xFF)
    }
    var arr: [UInt8] = []
    arr.reserveCapacity(4096)
    for _ in 0..<4096 { arr.append(next()) }
    let original = Bytes(arr)
    let encoded = PercentEncoding.encode(original, as: .component)
    let decoded = try PercentEncoding.decode(encoded)
    #expect(decoded == original)
}

@Test func roundTripEverySet() throws {
    // Mixed input that exercises both safe and unsafe bytes for every set.
    let original = Bytes(Array("Hello World!/?&=:@#".utf8))
    for set in [PercentEncoding.Set.unreserved, .pathSegment, .query, .fragment, .userinfo, .component] {
        let encoded = PercentEncoding.encode(original, as: set)
        let decoded = try PercentEncoding.decode(encoded)
        #expect(decoded == original, "round-trip failed for set: \(set)")
    }
    // .form needs decodeForm:
    let encodedForm = PercentEncoding.encode(original, as: .form)
    let decodedForm = try PercentEncoding.decodeForm(encodedForm)
    #expect(decodedForm == original, "round-trip failed for .form")
}
```

- [ ] **Step 2: Run the full suite on a clean build**

```bash
swift package clean
swift test
```

Expected: every test passes. Total ≈ 297 tests.

- [ ] **Step 3: Check coverage**

```bash
swift test --enable-code-coverage
COV_BIN=$(swift build --show-bin-path)
xcrun llvm-cov report \
    "$COV_BIN/BedrockPackageTests.xctest/Contents/MacOS/BedrockPackageTests" \
    -instr-profile "$COV_BIN/codecov/default.profdata" \
    Sources/PercentEncoding
```

Expected: coverage on `Sources/PercentEncoding/` ≥ 90%. **Report the table.** If a file is below 90%, identify the gap and add a single targeted test.

- [ ] **Step 4: Verify release build**

Run: `swift build -c release`
Expected: build succeeds with no errors or new warnings.

- [ ] **Step 5: Update the Layer 1 status banner**

Open `layers/layer-01-primitives.md`. Find the existing status banner (the multi-line `> **Status:**` block that lists Bytes/Hex/Base64/UUID/Varint). Replace it with:

```markdown
> **Status:** shipping modules:
> - `Sources/Bytes/` — core bytes ([design](../docs/superpowers/specs/2026-05-09-bytes-design.md), [plan](../docs/superpowers/plans/2026-05-09-bytes-module.md))
> - `Sources/Hex/` — hex codec ([design](../docs/superpowers/specs/2026-05-10-hex-base64-design.md), [plan](../docs/superpowers/plans/2026-05-10-hex-base64-modules.md))
> - `Sources/Base64/` — base64 codec, including constant-time decode ([same design + plan](../docs/superpowers/specs/2026-05-10-hex-base64-design.md))
> - `Sources/UUID/` — UUID type with v4/v7/v8 generation; v1/v3/v5/v6 parse/inspect work, generation deferred to follow-up patches when Layer 8 (MAC) and Layer 12 (MD5/SHA-1) ship ([design](../docs/superpowers/specs/2026-05-10-uuid-design.md), [plan](../docs/superpowers/plans/2026-05-10-uuid-module.md))
> - `Sources/Varint/` — LEB128 unsigned + ZigZag-LEB128 signed for UInt32/UInt64/Int32/Int64 ([design](../docs/superpowers/specs/2026-05-12-varint-design.md), [plan](../docs/superpowers/plans/2026-05-12-varint-module.md))
> - `Sources/PercentEncoding/` — RFC 3986 + x-www-form-urlencoded byte codec with per-component named sets ([design](../docs/superpowers/specs/2026-05-16-percent-encoding-design.md), [plan](../docs/superpowers/plans/2026-05-16-percent-encoding-module.md))
>
> Remaining categories (BitSet, SIMD UTF-8, COBS, URL/IDNA) pending their own designs.
```

- [ ] **Step 6: Commit and push**

```bash
git add Tests/PercentEncodingTests/PercentEncodingRoundTripTests.swift layers/layer-01-primitives.md
git commit -m "PercentEncoding: add round-trip tests and cross-link Layer 1 doc"
git push origin main
```

Expected: push succeeds.
