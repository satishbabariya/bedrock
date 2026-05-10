# Hex + Base64 Modules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship two stdlib-only codec modules — `Hex` (encode/decode, case-insensitive) and `Base64` (standard + url-safe, optional padding, MIME line-wrap, strict/lenient/constant-time decode) — both consuming `Bytes`/`BytesMut` from the prior module.

**Architecture:** Each codec is a `public enum` namespace (`Hex`, `Base64`) plus a per-codec error type, table-driven encode/decode, and thin `Bytes`/`String` extensions. Tables are computed in code so values are auditable. Encode is total (never throws); decode throws structured `HexError` / `Base64Error` with offset and byte information. Constant-time Base64 decode uses branch-free byte classification adapted from `base64ct`.

**Tech Stack:** Swift 6 (toolchain ≥ 6.0), SwiftPM, Swift Testing. No third-party dependencies, no Foundation.

**Source spec:** `docs/superpowers/specs/2026-05-10-hex-base64-design.md`.

**Working directory:** `/Users/satishbabariya/Desktop/Bedrock` (repo root). Run all `swift` commands from there.

---

## Task 1: Package scaffolding for Hex + Base64

**Files:**
- Modify: `Package.swift`
- Create: `Sources/Hex/Hex.swift` (placeholder)
- Create: `Sources/Base64/Base64.swift` (placeholder)
- Create: `Tests/HexTests/SmokeTest.swift`
- Create: `Tests/Base64Tests/SmokeTest.swift`

- [ ] **Step 1: Update Package.swift**

Replace the contents of `Package.swift` with:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Bedrock",
    products: [
        .library(name: "Bytes", targets: ["Bytes"]),
        .library(name: "Hex", targets: ["Hex"]),
        .library(name: "Base64", targets: ["Base64"]),
    ],
    targets: [
        .target(name: "Bytes", path: "Sources/Bytes"),
        .testTarget(name: "BytesTests", dependencies: ["Bytes"], path: "Tests/BytesTests"),

        .target(name: "Hex", dependencies: ["Bytes"], path: "Sources/Hex"),
        .testTarget(name: "HexTests", dependencies: ["Hex", "Bytes"], path: "Tests/HexTests"),

        .target(name: "Base64", dependencies: ["Bytes"], path: "Sources/Base64"),
        .testTarget(name: "Base64Tests", dependencies: ["Base64", "Bytes"], path: "Tests/Base64Tests"),
    ]
)
```

- [ ] **Step 2: Create placeholder source files**

Create `Sources/Hex/Hex.swift`:

```swift
// Hex — implemented in Task 2+.
@usableFromInline internal let _hexModuleLoaded = true
```

Create `Sources/Base64/Base64.swift`:

```swift
// Base64 — implemented in Task 6+.
@usableFromInline internal let _base64ModuleLoaded = true
```

- [ ] **Step 3: Create the smoke tests**

Create `Tests/HexTests/SmokeTest.swift`:

```swift
import Testing
@testable import Hex

@Test func hexModuleLoads() {
    #expect(_hexModuleLoaded == true)
}
```

Create `Tests/Base64Tests/SmokeTest.swift`:

```swift
import Testing
@testable import Base64

@Test func base64ModuleLoads() {
    #expect(_base64ModuleLoaded == true)
}
```

- [ ] **Step 4: Verify build + tests**

Run: `swift test`
Expected: all 89 prior `Bytes` tests still pass, plus 2 new smoke tests = 91 total.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/Hex Sources/Base64 Tests/HexTests Tests/Base64Tests
git commit -m "Hex+Base64: scaffold modules and smoke tests"
```

---

## Task 2: HexError + Hex namespace + Case enum

**Files:**
- Create: `Sources/Hex/HexError.swift`
- Modify: `Sources/Hex/Hex.swift` (replace placeholder with namespace stub + Case enum)
- Create: `Tests/HexTests/HexErrorTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/HexTests/HexErrorTests.swift`:

```swift
import Testing
@testable import Hex

@Test func hexCaseEnum() {
    let cases: [Hex.Case] = [.lower, .upper]
    #expect(cases.count == 2)
}

@Test func hexErrorEquality() {
    #expect(HexError.oddLength(3) == HexError.oddLength(3))
    #expect(HexError.oddLength(3) != HexError.oddLength(5))
    #expect(HexError.invalidCharacter(offset: 2, byte: 0x40)
            == HexError.invalidCharacter(offset: 2, byte: 0x40))
    #expect(HexError.invalidCharacter(offset: 2, byte: 0x40)
            != HexError.invalidCharacter(offset: 3, byte: 0x40))
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter HexErrorTests`
Expected: compile errors (`Hex.Case`, `HexError` not defined).

- [ ] **Step 3: Implement HexError**

Create `Sources/Hex/HexError.swift`:

```swift
/// Errors thrown by `Hex.decode`.
public enum HexError: Error, Equatable, Sendable {
    /// Input length must be even (one hex digit per nibble, two per byte).
    case oddLength(Int)
    /// Non-hex character at the given byte offset in the input.
    case invalidCharacter(offset: Int, byte: UInt8)
}
```

- [ ] **Step 4: Implement the Hex namespace + Case enum**

Replace the contents of `Sources/Hex/Hex.swift` with:

```swift
import Bytes

/// Hex (base-16) codec namespace.
public enum Hex {
    /// Encoding case for hex output.
    public enum Case: Sendable {
        case lower    // "deadbeef"
        case upper    // "DEADBEEF"
    }
}
```

- [ ] **Step 5: Update the smoke test**

The smoke test now references a deleted symbol. Replace `Tests/HexTests/SmokeTest.swift` with a trivial existence check on the new namespace:

```swift
import Testing
@testable import Hex

@Test func hexNamespaceExists() {
    let _: Hex.Case = .lower
    #expect(true)
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `swift test --filter HexTests`
Expected: 3 tests pass (1 smoke + 2 error tests).

- [ ] **Step 7: Commit**

```bash
git add Sources/Hex Tests/HexTests
git commit -m "Hex: add namespace, Case enum, and HexError"
```

---

## Task 3: Hex encode + tables

**Files:**
- Create: `Sources/Hex/Internal/Tables.swift`
- Modify: `Sources/Hex/Hex.swift` (append encode methods)
- Create: `Tests/HexTests/HexEncodeTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/HexTests/HexEncodeTests.swift`:

```swift
import Testing
import Bytes
@testable import Hex

@Test func encodeEmpty() {
    #expect(Hex.encode(Bytes()) == "")
    #expect(Hex.encode(Bytes(), case: .upper) == "")
}

@Test func encodeKnownVectorsLower() {
    #expect(Hex.encode(Bytes([0xDE, 0xAD, 0xBE, 0xEF])) == "deadbeef")
    #expect(Hex.encode(Bytes([0x00, 0x0F, 0xF0, 0xFF])) == "000ff0ff")
}

@Test func encodeKnownVectorsUpper() {
    #expect(Hex.encode(Bytes([0xDE, 0xAD, 0xBE, 0xEF]), case: .upper) == "DEADBEEF")
    #expect(Hex.encode(Bytes([0x00, 0x0F, 0xF0, 0xFF]), case: .upper) == "000FF0FF")
}

@Test func encodeAllByteValues() {
    var bytes: [UInt8] = []
    for i in 0..<256 { bytes.append(UInt8(i)) }
    let lower = Hex.encode(Bytes(bytes))
    let upper = Hex.encode(Bytes(bytes), case: .upper)
    #expect(lower.count == 512)
    #expect(upper.count == 512)
    #expect(lower.lowercased() == lower)
    #expect(upper.uppercased() == upper)
    // Spot check first and last bytes
    #expect(lower.hasPrefix("00"))
    #expect(lower.hasSuffix("ff"))
}

@Test func encodeSequenceOverloadMatchesBytesOverload() {
    let arr: [UInt8] = [0x12, 0x34, 0x56]
    #expect(Hex.encode(arr) == Hex.encode(Bytes(arr)))
    #expect(Hex.encode(arr, case: .upper) == Hex.encode(Bytes(arr), case: .upper))
}

@Test func encodeIntoBytesMutAppends() {
    var buf = BytesMut()
    buf.putBytes([0xAA, 0xBB] as [UInt8])  // pre-existing content
    Hex.encode(Bytes([0xDE, 0xAD]), into: &buf)
    let frozen = buf.freeze()
    // [0xAA, 0xBB] (raw) + "dead" (4 ASCII bytes)
    #expect(Array(frozen) == [0xAA, 0xBB, 0x64, 0x65, 0x61, 0x64])
}

@Test func encodeIntoBytesMutEmptyInputAppendsNothing() {
    var buf = BytesMut()
    buf.putUInt8(0xAA)
    Hex.encode(Bytes(), into: &buf)
    let frozen = buf.freeze()
    #expect(Array(frozen) == [0xAA])
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter HexEncodeTests`
Expected: compile errors for `Hex.encode`.

- [ ] **Step 3: Implement the encode tables**

Create `Sources/Hex/Internal/Tables.swift`:

```swift
/// Lowercase hex alphabet ("0"..."9", "a"..."f"). Indexed by 0...15.
@usableFromInline
internal let hexLowerAlphabet: [UInt8] = Array("0123456789abcdef".utf8)

/// Uppercase hex alphabet ("0"..."9", "A"..."F"). Indexed by 0...15.
@usableFromInline
internal let hexUpperAlphabet: [UInt8] = Array("0123456789ABCDEF".utf8)
```

- [ ] **Step 4: Implement Hex.encode**

Append to `Sources/Hex/Hex.swift`:

```swift
extension Hex {
    /// Hex-encode `bytes` to a String. Default case is lowercase.
    public static func encode(_ bytes: Bytes, case: Case = .lower) -> String {
        let alphabet = (`case` == .lower) ? hexLowerAlphabet : hexUpperAlphabet
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count * 2)
        bytes.withUnsafeBytes { src in
            for byte in src {
                out.append(alphabet[Int(byte >> 4)])
                out.append(alphabet[Int(byte & 0x0F)])
            }
        }
        return String(decoding: out, as: UTF8.self)
    }

    /// Sequence overload — useful for `[UInt8]`, `Array(...)`, etc.
    public static func encode<S: Sequence>(_ bytes: S, case: Case = .lower) -> String
    where S.Element == UInt8 {
        let alphabet = (`case` == .lower) ? hexLowerAlphabet : hexUpperAlphabet
        var out: [UInt8] = []
        out.reserveCapacity(bytes.underestimatedCount * 2)
        for byte in bytes {
            out.append(alphabet[Int(byte >> 4)])
            out.append(alphabet[Int(byte & 0x0F)])
        }
        return String(decoding: out, as: UTF8.self)
    }

    /// Stream-encode into a `BytesMut`. Appends 2 ASCII bytes per input byte.
    public static func encode(_ bytes: Bytes, into out: inout BytesMut, case: Case = .lower) {
        guard !bytes.isEmpty else { return }
        let alphabet = (`case` == .lower) ? hexLowerAlphabet : hexUpperAlphabet
        out.reserveCapacity(out.count + bytes.count * 2)
        bytes.withUnsafeBytes { src in
            for byte in src {
                out.putUInt8(alphabet[Int(byte >> 4)])
                out.putUInt8(alphabet[Int(byte & 0x0F)])
            }
        }
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter HexEncodeTests`
Expected: all 7 encode tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/Hex Tests/HexTests/HexEncodeTests.swift
git commit -m "Hex: add encode (lower/upper) with Bytes, Sequence, and BytesMut overloads"
```

---

## Task 4: Hex decode + table + table sanity

**Files:**
- Modify: `Sources/Hex/Internal/Tables.swift` (append decode table)
- Modify: `Sources/Hex/Hex.swift` (append decode methods)
- Create: `Tests/HexTests/HexDecodeTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/HexTests/HexDecodeTests.swift`:

```swift
import Testing
import Bytes
@testable import Hex

@Test func decodeEmpty() throws {
    #expect(try Array(Hex.decode("")) == [])
}

@Test func decodeKnownVectors() throws {
    #expect(try Array(Hex.decode("deadbeef")) == [0xDE, 0xAD, 0xBE, 0xEF])
    #expect(try Array(Hex.decode("000FF0ff")) == [0x00, 0x0F, 0xF0, 0xFF])
}

@Test func decodeCaseInsensitive() throws {
    let a = try Hex.decode("DEADBEEF")
    let b = try Hex.decode("deadbeef")
    let c = try Hex.decode("DeAdBeEf")
    #expect(a == b)
    #expect(b == c)
}

@Test func decodeOddLengthThrows() {
    #expect(throws: HexError.oddLength(3)) { _ = try Hex.decode("abc") }
    #expect(throws: HexError.oddLength(1)) { _ = try Hex.decode("a") }
}

@Test func decodeInvalidCharacterThrows() {
    #expect(throws: HexError.invalidCharacter(offset: 2, byte: 0x40)) {
        _ = try Hex.decode("de@dbeef")  // '@' = 0x40 at offset 2
    }
    #expect(throws: HexError.invalidCharacter(offset: 0, byte: 0x67)) {
        _ = try Hex.decode("g0")        // 'g' = 0x67 at offset 0
    }
}

@Test func decodeFromBytesOverload() throws {
    let input = Bytes([0x64, 0x65, 0x61, 0x64])  // "dead" in ASCII
    #expect(try Array(Hex.decode(input)) == [0xDE, 0xAD])
}

@Test func decodeIntoBytesMutReturnsByteCount() throws {
    var out = BytesMut()
    out.putUInt8(0xAA)  // pre-existing content
    let n = try Hex.decode("deadbeef", into: &out)
    #expect(n == 4)
    let frozen = out.freeze()
    #expect(Array(frozen) == [0xAA, 0xDE, 0xAD, 0xBE, 0xEF])
}

@Test func decodeTableMatchesGroundTruth() {
    func expectedNibble(for byte: UInt8) -> UInt8 {
        switch byte {
        case 0x30...0x39: return byte - 0x30
        case 0x41...0x46: return byte - 0x41 + 10
        case 0x61...0x66: return byte - 0x61 + 10
        default:          return 0xFF
        }
    }
    for i in 0..<256 {
        let b = UInt8(i)
        #expect(hexDecodeTable[i] == expectedNibble(for: b),
                "table mismatch at byte 0x\(String(b, radix: 16))")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter HexDecodeTests`
Expected: compile errors — `Hex.decode` and `hexDecodeTable` not defined.

- [ ] **Step 3: Append the decode table**

Append to `Sources/Hex/Internal/Tables.swift`:

```swift
/// 256-entry decode table mapping ASCII byte → nibble value (0...15)
/// or 0xFF for non-hex bytes.
@usableFromInline
internal let hexDecodeTable: [UInt8] = (0..<256).map { i in
    switch UInt8(i) {
    case 0x30...0x39: return UInt8(i - 0x30)        // '0'-'9'
    case 0x41...0x46: return UInt8(i - 0x41 + 10)   // 'A'-'F'
    case 0x61...0x66: return UInt8(i - 0x61 + 10)   // 'a'-'f'
    default:          return 0xFF
    }
}
```

- [ ] **Step 4: Implement Hex.decode**

Append to `Sources/Hex/Hex.swift`:

```swift
extension Hex {
    /// Decode a hex string. Case-insensitive. Throws on odd length or
    /// non-hex characters.
    public static func decode(_ s: String) throws -> Bytes {
        var utf8: [UInt8] = []
        utf8.reserveCapacity(s.utf8.count)
        utf8.append(contentsOf: s.utf8)
        return try decodeBytes(utf8)
    }

    /// Decode hex bytes (ASCII). Same semantics as the String overload.
    public static func decode(_ bytes: Bytes) throws -> Bytes {
        var arr: [UInt8] = []
        arr.reserveCapacity(bytes.count)
        bytes.withUnsafeBytes { src in
            arr.append(contentsOf: src)
        }
        return try decodeBytes(arr)
    }

    /// Stream-decode into a `BytesMut`. Returns the number of decoded bytes
    /// appended.
    @discardableResult
    public static func decode(_ s: String, into out: inout BytesMut) throws -> Int {
        let decoded = try decode(s)
        out.putBytes(decoded)
        return decoded.count
    }

    private static func decodeBytes(_ src: [UInt8]) throws -> Bytes {
        guard src.count.isMultiple(of: 2) else {
            throw HexError.oddLength(src.count)
        }
        var out = BytesMut(capacity: src.count / 2)
        var i = 0
        while i < src.count {
            let hi = hexDecodeTable[Int(src[i])]
            if hi == 0xFF {
                throw HexError.invalidCharacter(offset: i, byte: src[i])
            }
            let lo = hexDecodeTable[Int(src[i + 1])]
            if lo == 0xFF {
                throw HexError.invalidCharacter(offset: i + 1, byte: src[i + 1])
            }
            out.putUInt8((hi << 4) | lo)
            i += 2
        }
        return out.freeze()
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter HexDecodeTests`
Expected: all 8 decode tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/Hex Tests/HexTests/HexDecodeTests.swift
git commit -m "Hex: add decode with table-driven nibble lookup and structured errors"
```

---

## Task 5: Hex extensions + round-trip tests

**Files:**
- Create: `Sources/Hex/HexExtensions.swift`
- Create: `Tests/HexTests/HexRoundTripTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/HexTests/HexRoundTripTests.swift`:

```swift
import Testing
import Bytes
@testable import Hex

@Test func extensionEncodeOnBytes() {
    let b = Bytes([0xDE, 0xAD])
    #expect(b.hexEncoded() == "dead")
    #expect(b.hexEncoded(case: .upper) == "DEAD")
}

@Test func extensionStringHexEncoding() {
    let b = Bytes([0xCA, 0xFE])
    #expect(String(hexEncoding: b) == "cafe")
    #expect(String(hexEncoding: b, case: .upper) == "CAFE")
}

@Test func extensionBytesHexDecoding() throws {
    let b = try Bytes(hexDecoding: "deadbeef")
    #expect(Array(b) == [0xDE, 0xAD, 0xBE, 0xEF])
}

@Test func roundTripEveryByte() throws {
    var arr: [UInt8] = []
    for i in 0..<256 { arr.append(UInt8(i)) }
    let original = Bytes(arr)
    let lower = original.hexEncoded()
    let upper = original.hexEncoded(case: .upper)
    let backFromLower = try Bytes(hexDecoding: lower)
    let backFromUpper = try Bytes(hexDecoding: upper)
    #expect(original == backFromLower)
    #expect(original == backFromUpper)
}

@Test func roundTripDeterministicRandom() throws {
    // Linear congruential generator with fixed seed for repeatability.
    var state: UInt64 = 0xDEADBEEFCAFEBABE
    func next() -> UInt8 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return UInt8((state >> 56) & 0xFF)
    }
    var arr: [UInt8] = []
    arr.reserveCapacity(4096)
    for _ in 0..<4096 { arr.append(next()) }
    let original = Bytes(arr)
    let encoded = original.hexEncoded()
    let decoded = try Bytes(hexDecoding: encoded)
    #expect(original == decoded)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter HexRoundTripTests`
Expected: compile errors for `hexEncoded`, `String(hexEncoding:)`, `Bytes(hexDecoding:)`.

- [ ] **Step 3: Implement the extensions**

Create `Sources/Hex/HexExtensions.swift`:

```swift
import Bytes

extension Bytes {
    /// Hex-encode this buffer. Default case is lowercase.
    public func hexEncoded(case: Hex.Case = .lower) -> String {
        Hex.encode(self, case: `case`)
    }
}

extension String {
    /// Construct a String containing the hex encoding of `bytes`.
    public init(hexEncoding bytes: Bytes, case: Hex.Case = .lower) {
        self = Hex.encode(bytes, case: `case`)
    }
}

extension Bytes {
    /// Decode a hex string into bytes. Case-insensitive.
    public init(hexDecoding s: String) throws {
        self = try Hex.decode(s)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter HexRoundTripTests`
Expected: all 5 round-trip tests pass.

- [ ] **Step 5: Verify the full Hex module**

Run: `swift test --filter HexTests`
Expected: all Hex tests pass (smoke + error + encode + decode + round-trip).

- [ ] **Step 6: Commit**

```bash
git add Sources/Hex/HexExtensions.swift Tests/HexTests/HexRoundTripTests.swift
git commit -m "Hex: add Bytes/String extensions and round-trip tests"
```

---

## Task 6: Base64Error + namespace + variant/mode/wrap enums

**Files:**
- Create: `Sources/Base64/Base64Error.swift`
- Modify: `Sources/Base64/Base64.swift` (replace placeholder with namespace + enums)
- Create: `Tests/Base64Tests/Base64ErrorTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/Base64Tests/Base64ErrorTests.swift`:

```swift
import Testing
@testable import Base64

@Test func base64EnumsExist() {
    let _: [Base64.Variant] = [.standard, .urlSafe]
    let _: [Base64.DecodeMode] = [.strict, .lenient, .constantTime]
    let _: [Base64.LineWrap] = [.none, .mime76]
    #expect(true)
}

@Test func base64ErrorEquality() {
    #expect(Base64Error.invalidCharacter(offset: 1, byte: 0x21)
            == Base64Error.invalidCharacter(offset: 1, byte: 0x21))
    #expect(Base64Error.invalidLength(7) == Base64Error.invalidLength(7))
    #expect(Base64Error.invalidPadding(offset: 5) == Base64Error.invalidPadding(offset: 5))
    #expect(Base64Error.constantTimeRejected == Base64Error.constantTimeRejected)
    #expect(Base64Error.invalidLength(7) != Base64Error.invalidLength(8))
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter Base64ErrorTests`
Expected: compile errors for the missing types.

- [ ] **Step 3: Implement Base64Error**

Create `Sources/Base64/Base64Error.swift`:

```swift
/// Errors thrown by `Base64.decode`.
public enum Base64Error: Error, Equatable, Sendable {
    /// Input contains a character not in the active alphabet (and, in
    /// `.strict`/`.constantTime` modes, not whitespace).
    case invalidCharacter(offset: Int, byte: UInt8)
    /// Input length isn't a multiple of 4 (after whitespace stripping in
    /// `.lenient` mode), and unpadded input would be ambiguous.
    case invalidLength(Int)
    /// Padding was required by the input shape but missing or malformed
    /// (e.g. `=` mid-stream, or a single `=` in a position where two
    /// are required).
    case invalidPadding(offset: Int)
    /// A constant-time decode failed without revealing the failure offset
    /// (would leak timing). The whole input is rejected.
    case constantTimeRejected
}
```

- [ ] **Step 4: Implement the Base64 namespace + nested enums**

Replace `Sources/Base64/Base64.swift` with:

```swift
import Bytes

/// Base64 (RFC 4648) codec namespace.
public enum Base64 {
    /// Alphabet variant.
    public enum Variant: Sendable {
        case standard   // RFC 4648 §4: A–Z a–z 0–9 + /
        case urlSafe    // RFC 4648 §5: A–Z a–z 0–9 - _
    }

    /// Decoder behavior on whitespace, non-alphabet chars, and timing safety.
    public enum DecodeMode: Sendable {
        /// Reject any byte not in the alphabet (including whitespace) and
        /// validate padding strictly. Variable-time. Default.
        case strict
        /// Skip ASCII whitespace (space, tab, CR, LF). Reject other
        /// non-alphabet bytes. Variable-time.
        case lenient
        /// Branch-free decoder for crypto inputs (keys, JWT signatures,
        /// X.509 fields). Rejects whitespace; runtime independent of the
        /// invalid-character position. Slower than `.strict`.
        case constantTime
    }

    /// MIME-style line wrapping on encode (RFC 2045 §6.8 = 76 chars + CRLF).
    public enum LineWrap: Sendable {
        case none
        case mime76                 // 76 columns, CRLF separator
    }
}
```

- [ ] **Step 5: Update the smoke test**

Replace `Tests/Base64Tests/SmokeTest.swift` with:

```swift
import Testing
@testable import Base64

@Test func base64NamespaceExists() {
    let _: Base64.Variant = .standard
    let _: Base64.DecodeMode = .strict
    let _: Base64.LineWrap = .none
    #expect(true)
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `swift test --filter Base64Tests`
Expected: 3 tests pass (smoke + 2 error tests).

- [ ] **Step 7: Commit**

```bash
git add Sources/Base64 Tests/Base64Tests
git commit -m "Base64: add namespace, Variant/DecodeMode/LineWrap, and Base64Error"
```

---

## Task 7: Base64 encode (standard, padded, no wrap) + tables

**Files:**
- Create: `Sources/Base64/Internal/Tables.swift`
- Modify: `Sources/Base64/Base64.swift` (append encode methods)
- Create: `Tests/Base64Tests/Base64EncodeTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/Base64Tests/Base64EncodeTests.swift`:

```swift
import Testing
import Bytes
@testable import Base64

// RFC 4648 §10 test vectors.
private let rfcVectors: [(String, String)] = [
    ("",       ""),
    ("f",      "Zg=="),
    ("fo",     "Zm8="),
    ("foo",    "Zm9v"),
    ("foob",   "Zm9vYg=="),
    ("fooba",  "Zm9vYmE="),
    ("foobar", "Zm9vYmFy"),
]

@Test func encodeStandardRFCVectors() {
    for (input, expected) in rfcVectors {
        let bytes = Bytes(Array(input.utf8))
        #expect(Base64.encode(bytes) == expected)
    }
}

@Test func encodeStandardEmptyProducesEmpty() {
    #expect(Base64.encode(Bytes()) == "")
}

@Test func encodeAllByteValues() {
    var arr: [UInt8] = []
    for i in 0..<256 { arr.append(UInt8(i)) }
    let s = Base64.encode(Bytes(arr))
    // 256 bytes → ceil(256/3)*4 = 86 quanta → 344 chars (with padding)
    #expect(s.count == 344)
    // No invalid characters
    let alphabet = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")
    #expect(s.allSatisfy { alphabet.contains($0) })
}

@Test func encodeSequenceOverloadMatchesBytesOverload() {
    let arr: [UInt8] = [0x00, 0xFF, 0x80]
    #expect(Base64.encode(arr) == Base64.encode(Bytes(arr)))
}

@Test func encodeIntoBytesMutAppends() {
    var buf = BytesMut()
    buf.putUInt8(0xAA)
    Base64.encode(Bytes(Array("foo".utf8)), into: &buf)
    let frozen = buf.freeze()
    // 0xAA + "Zm9v" (4 ASCII bytes)
    #expect(Array(frozen) == [0xAA, 0x5A, 0x6D, 0x39, 0x76])
}

@Test func encodeIntoBytesMutEmptyInputAppendsNothing() {
    var buf = BytesMut()
    buf.putUInt8(0xAA)
    Base64.encode(Bytes(), into: &buf)
    let frozen = buf.freeze()
    #expect(Array(frozen) == [0xAA])
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter Base64EncodeTests`
Expected: compile errors for `Base64.encode`.

- [ ] **Step 3: Create the encode tables**

Create `Sources/Base64/Internal/Tables.swift`:

```swift
/// Standard Base64 alphabet (RFC 4648 §4). Indexed by 0...63.
@usableFromInline
internal let base64StandardAlphabet: [UInt8] = Array(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)

/// URL-safe Base64 alphabet (RFC 4648 §5). Indexed by 0...63.
@usableFromInline
internal let base64UrlSafeAlphabet: [UInt8] = Array(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".utf8)

/// ASCII '=' padding character.
@usableFromInline
internal let base64Pad: UInt8 = 0x3D
```

- [ ] **Step 4: Implement Base64.encode (basic form)**

Append to `Sources/Base64/Base64.swift`:

```swift
extension Base64 {
    /// Encode `bytes`. Default: standard alphabet, padded, no line wrap.
    public static func encode(
        _ bytes: Bytes,
        variant: Variant = .standard,
        padding: Bool = true,
        lineWrap: LineWrap = .none
    ) -> String {
        var out: [UInt8] = []
        encodeIntoArray(bytes, into: &out,
                        variant: variant, padding: padding, lineWrap: lineWrap)
        return String(decoding: out, as: UTF8.self)
    }

    /// Sequence overload — useful for `[UInt8]`, `Array(...)`, etc.
    public static func encode<S: Sequence>(
        _ bytes: S,
        variant: Variant = .standard,
        padding: Bool = true,
        lineWrap: LineWrap = .none
    ) -> String where S.Element == UInt8 {
        encode(Bytes(bytes), variant: variant, padding: padding, lineWrap: lineWrap)
    }

    /// Stream-encode into a `BytesMut`.
    public static func encode(
        _ bytes: Bytes,
        into out: inout BytesMut,
        variant: Variant = .standard,
        padding: Bool = true,
        lineWrap: LineWrap = .none
    ) {
        guard !bytes.isEmpty else { return }
        var arr: [UInt8] = []
        encodeIntoArray(bytes, into: &arr,
                        variant: variant, padding: padding, lineWrap: lineWrap)
        out.putBytes(arr)
    }

    /// Internal helper. Writes the encoded bytes into `out`.
    private static func encodeIntoArray(
        _ bytes: Bytes,
        into out: inout [UInt8],
        variant: Variant,
        padding: Bool,
        lineWrap: LineWrap
    ) {
        let alphabet = (variant == .standard)
            ? base64StandardAlphabet
            : base64UrlSafeAlphabet
        let estimated = 4 * ((bytes.count + 2) / 3)
        out.reserveCapacity(out.count + estimated)

        var lineCol = 0
        func emit(_ b: UInt8) {
            out.append(b)
            if case .mime76 = lineWrap {
                lineCol += 1
                if lineCol == 76 {
                    out.append(0x0D)  // CR
                    out.append(0x0A)  // LF
                    lineCol = 0
                }
            }
        }

        bytes.withUnsafeBytes { src in
            var i = 0
            while i + 3 <= src.count {
                let b0 = UInt32(src[i])
                let b1 = UInt32(src[i + 1])
                let b2 = UInt32(src[i + 2])
                let v = (b0 << 16) | (b1 << 8) | b2
                emit(alphabet[Int((v >> 18) & 0x3F)])
                emit(alphabet[Int((v >> 12) & 0x3F)])
                emit(alphabet[Int((v >>  6) & 0x3F)])
                emit(alphabet[Int(v & 0x3F)])
                i += 3
            }
            let rem = src.count - i
            if rem == 1 {
                let v = UInt32(src[i]) << 16
                emit(alphabet[Int((v >> 18) & 0x3F)])
                emit(alphabet[Int((v >> 12) & 0x3F)])
                if padding {
                    emit(base64Pad)
                    emit(base64Pad)
                }
            } else if rem == 2 {
                let v = (UInt32(src[i]) << 16) | (UInt32(src[i + 1]) << 8)
                emit(alphabet[Int((v >> 18) & 0x3F)])
                emit(alphabet[Int((v >> 12) & 0x3F)])
                emit(alphabet[Int((v >>  6) & 0x3F)])
                if padding {
                    emit(base64Pad)
                }
            }
        }
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter Base64EncodeTests`
Expected: all 6 encode tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/Base64 Tests/Base64Tests/Base64EncodeTests.swift
git commit -m "Base64: add encode (standard, padded) with overloads and RFC vectors"
```

---

## Task 8: Base64 encode options (urlSafe, padding off, mime76)

**Files:**
- Modify: `Tests/Base64Tests/Base64EncodeTests.swift` (append more tests)

- [ ] **Step 1: Append the failing tests**

Append to `Tests/Base64Tests/Base64EncodeTests.swift`:

```swift
@Test func encodeUrlSafeReplacesPlusAndSlash() {
    // Bytes that produce '+' (62) and '/' (63) in the standard encoding.
    // Three-byte input 0xFB 0xFF 0xBF =>
    //   bits 11111011 11111111 10111111
    //   sextets: 111110 111111 111110 111111 = 62 63 62 63
    //   standard: "+/+/"
    //   url-safe: "-_-_"
    let bytes = Bytes([0xFB, 0xFF, 0xBF])
    #expect(Base64.encode(bytes, variant: .standard) == "+/+/")
    #expect(Base64.encode(bytes, variant: .urlSafe) == "-_-_")
}

@Test func encodeUnpaddedStripsEquals() {
    let bytes = Bytes(Array("f".utf8))
    #expect(Base64.encode(bytes, padding: true)  == "Zg==")
    #expect(Base64.encode(bytes, padding: false) == "Zg")

    let bytes2 = Bytes(Array("fo".utf8))
    #expect(Base64.encode(bytes2, padding: true)  == "Zm8=")
    #expect(Base64.encode(bytes2, padding: false) == "Zm8")

    let bytes3 = Bytes(Array("foo".utf8))
    // Whole quanta — no padding either way.
    #expect(Base64.encode(bytes3, padding: true)  == "Zm9v")
    #expect(Base64.encode(bytes3, padding: false) == "Zm9v")
}

@Test func encodeMime76InsertsCRLFAtColumn76() {
    // 60 bytes input → 80 base64 chars (no padding because divisible by 3).
    // mime76 should insert CRLF after column 76, leaving 4 chars on the
    // next line.
    let bytes = Bytes([UInt8](repeating: 0x00, count: 60))
    let s = Base64.encode(bytes, lineWrap: .mime76)
    // 60 input bytes / 3 = 20 quanta → 80 ASCII chars + 1 CRLF = 82 chars total
    #expect(s.count == 82)
    // CRLF should appear at index 76 and 77
    let chars = Array(s)
    #expect(chars[76] == "\r")
    #expect(chars[77] == "\n")
}

@Test func encodeMime76DoesNotSplitQuantum() {
    // Encode a buffer that produces exactly 76 chars total — no CRLF should
    // appear because there's no 77th char.
    let bytes = Bytes([UInt8](repeating: 0x41, count: 57))  // 57/3 = 19 quanta = 76 chars
    let s = Base64.encode(bytes, lineWrap: .mime76)
    #expect(s.count == 76)
    #expect(!s.contains("\r"))
    #expect(!s.contains("\n"))
}
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `swift test --filter Base64EncodeTests`
Expected: all 10 encode tests pass (4 new + 6 existing — the encoder already supports these options from Task 7).

- [ ] **Step 3: Commit**

```bash
git add Tests/Base64Tests/Base64EncodeTests.swift
git commit -m "Base64: tests for urlSafe, padding=false, mime76 line wrap"
```

---

## Task 9: Base64 decode (.strict, both alphabets, padding optional)

**Files:**
- Modify: `Sources/Base64/Internal/Tables.swift` (append decode table)
- Modify: `Sources/Base64/Base64.swift` (append decode methods)
- Create: `Tests/Base64Tests/Base64DecodeTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/Base64Tests/Base64DecodeTests.swift`:

```swift
import Testing
import Bytes
@testable import Base64

private let rfcVectors: [(String, String)] = [
    ("",       ""),
    ("f",      "Zg=="),
    ("fo",     "Zm8="),
    ("foo",    "Zm9v"),
    ("foob",   "Zm9vYg=="),
    ("fooba",  "Zm9vYmE="),
    ("foobar", "Zm9vYmFy"),
]

@Test func decodeStrictRFCVectors() throws {
    for (expected, encoded) in rfcVectors {
        let decoded = try Base64.decode(encoded)
        #expect(Array(decoded) == Array(expected.utf8))
    }
}

@Test func decodeUrlSafeAlphabet() throws {
    // "-_-_" url-safe = 0xFB 0xFF 0xBF (the inverse of the encode test)
    let decoded = try Base64.decode("-_-_")
    #expect(Array(decoded) == [0xFB, 0xFF, 0xBF])
}

@Test func decodePaddedAndUnpaddedEquivalent() throws {
    let padded = try Base64.decode("Zg==")
    let unpadded = try Base64.decode("Zg")
    #expect(padded == unpadded)
    #expect(Array(padded) == [0x66])
}

@Test func decodeMixingStandardAndUrlSafeThrows() {
    // First char is 'A' (alphanum) → no variant lock-in yet.
    // Then '+' locks standard. Then '-' violates → throws at offset of '-'.
    #expect(throws: Base64Error.self) {
        _ = try Base64.decode("A+B-")
    }
}

@Test func decodeStrictRejectsWhitespace() {
    #expect(throws: Base64Error.invalidCharacter(offset: 2, byte: 0x20)) {
        _ = try Base64.decode("Zg ==")  // space at offset 2
    }
}

@Test func decodeInvalidCharacterThrows() {
    #expect(throws: Base64Error.invalidCharacter(offset: 1, byte: 0x21)) {
        _ = try Base64.decode("Z!g=")  // '!' = 0x21 at offset 1
    }
}

@Test func decodeInvalidLengthThrows() {
    // 3 chars, no padding — ambiguous.
    #expect(throws: Base64Error.invalidLength(3)) {
        _ = try Base64.decode("Zg=")
    }
}

@Test func decodeInvalidPaddingMidStream() {
    #expect(throws: Base64Error.self) {
        _ = try Base64.decode("Z=g=")  // '=' at offset 1 (mid-stream)
    }
}

@Test func decodeFromBytesOverload() throws {
    let input = Bytes(Array("Zm9v".utf8))
    #expect(Array(try Base64.decode(input)) == Array("foo".utf8))
}

@Test func decodeIntoBytesMutReturnsByteCount() throws {
    var out = BytesMut()
    out.putUInt8(0xAA)
    let n = try Base64.decode("Zm9v", into: &out)
    #expect(n == 3)
    let frozen = out.freeze()
    #expect(Array(frozen) == [0xAA, 0x66, 0x6F, 0x6F])
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter Base64DecodeTests`
Expected: compile errors for `Base64.decode`.

- [ ] **Step 3: Append the decode table**

Append to `Sources/Base64/Internal/Tables.swift`:

```swift
/// Sentinel values in the decode table.
@usableFromInline internal let base64Whitespace: UInt8 = 0xFE
@usableFromInline internal let base64PadSentinel: UInt8 = 0xFD
@usableFromInline internal let base64Invalid: UInt8 = 0xFF

/// 256-entry decode table mapping ASCII byte → 6-bit value (0...63),
/// `base64Whitespace`, `base64PadSentinel`, or `base64Invalid`.
/// Both standard and url-safe alphabet characters resolve to their value;
/// the auto-detect pass below validates that they don't appear in the
/// same input.
@usableFromInline
internal let base64DecodeTable: [UInt8] = (0..<256).map { i in
    let b = UInt8(i)
    switch b {
    case 0x41...0x5A: return b - 0x41           // A-Z → 0...25
    case 0x61...0x7A: return b - 0x61 + 26      // a-z → 26...51
    case 0x30...0x39: return b - 0x30 + 52      // 0-9 → 52...61
    case 0x2B:        return 62                 // '+'
    case 0x2F:        return 63                 // '/'
    case 0x2D:        return 62                 // '-' (url-safe)
    case 0x5F:        return 63                 // '_' (url-safe)
    case 0x3D:        return base64PadSentinel  // '='
    case 0x09, 0x0A, 0x0D, 0x20: return base64Whitespace
    default:          return base64Invalid
    }
}
```

- [ ] **Step 4: Implement Base64.decode (.strict, .lenient)**

Append to `Sources/Base64/Base64.swift`:

```swift
extension Base64 {
    /// Decode a Base64 string. Auto-detects variant; mixing throws.
    /// Padding is optional on input regardless of the encoder's choice.
    public static func decode(
        _ s: String,
        mode: DecodeMode = .strict
    ) throws -> Bytes {
        var arr: [UInt8] = []
        arr.reserveCapacity(s.utf8.count)
        arr.append(contentsOf: s.utf8)
        return try decodeBytes(arr, mode: mode)
    }

    /// Decode Base64 bytes (ASCII). Same semantics as the String overload.
    public static func decode(
        _ bytes: Bytes,
        mode: DecodeMode = .strict
    ) throws -> Bytes {
        var arr: [UInt8] = []
        arr.reserveCapacity(bytes.count)
        bytes.withUnsafeBytes { src in
            arr.append(contentsOf: src)
        }
        return try decodeBytes(arr, mode: mode)
    }

    /// Stream-decode into a `BytesMut`. Returns the number of decoded bytes.
    @discardableResult
    public static func decode(
        _ s: String,
        into out: inout BytesMut,
        mode: DecodeMode = .strict
    ) throws -> Int {
        let decoded = try decode(s, mode: mode)
        out.putBytes(decoded)
        return decoded.count
    }

    private static func decodeBytes(_ src: [UInt8], mode: DecodeMode) throws -> Bytes {
        if case .constantTime = mode {
            return try decodeConstantTime(src)
        }
        return try decodeVariableTime(src, mode: mode)
    }

    /// Variable-time decoder shared by `.strict` and `.lenient`.
    /// Tracks the variant once the first `+/-_` appears; mixing throws.
    private static func decodeVariableTime(_ src: [UInt8], mode: DecodeMode) throws -> Bytes {
        var out = BytesMut(capacity: (src.count / 4) * 3)
        var quantum: UInt32 = 0
        var sextetsInQuantum = 0
        var paddingsSeen = 0
        var seenStandardChar = false
        var seenUrlSafeChar = false

        for offset in 0..<src.count {
            let b = src[offset]
            let v = base64DecodeTable[Int(b)]

            // Handle whitespace
            if v == base64Whitespace {
                if mode == .lenient { continue }
                throw Base64Error.invalidCharacter(offset: offset, byte: b)
            }

            // Lock variant when seeing alphabet-distinguishing chars.
            switch b {
            case 0x2B, 0x2F:
                if seenUrlSafeChar {
                    throw Base64Error.invalidCharacter(offset: offset, byte: b)
                }
                seenStandardChar = true
            case 0x2D, 0x5F:
                if seenStandardChar {
                    throw Base64Error.invalidCharacter(offset: offset, byte: b)
                }
                seenUrlSafeChar = true
            default:
                break
            }

            // Handle padding
            if v == base64PadSentinel {
                if sextetsInQuantum < 2 {
                    throw Base64Error.invalidPadding(offset: offset)
                }
                paddingsSeen += 1
                if paddingsSeen > 2 {
                    throw Base64Error.invalidPadding(offset: offset)
                }
                continue
            }

            if v == base64Invalid {
                throw Base64Error.invalidCharacter(offset: offset, byte: b)
            }

            // Padding mid-stream → invalid
            if paddingsSeen > 0 {
                throw Base64Error.invalidCharacter(offset: offset, byte: b)
            }

            // Append sextet
            quantum = (quantum << 6) | UInt32(v)
            sextetsInQuantum += 1

            if sextetsInQuantum == 4 {
                out.putUInt8(UInt8((quantum >> 16) & 0xFF))
                out.putUInt8(UInt8((quantum >>  8) & 0xFF))
                out.putUInt8(UInt8(quantum & 0xFF))
                quantum = 0
                sextetsInQuantum = 0
                paddingsSeen = 0
            }
        }

        // Tail handling: if we ended mid-quantum, padding was either implied
        // (unpadded input) or already accounted for.
        switch sextetsInQuantum {
        case 0:
            break
        case 1:
            // Single sextet at the end is never valid (no whole bytes).
            throw Base64Error.invalidLength(src.count)
        case 2:
            // Two sextets → 1 output byte.
            quantum <<= 12
            out.putUInt8(UInt8((quantum >> 16) & 0xFF))
        case 3:
            // Three sextets → 2 output bytes.
            quantum <<= 6
            out.putUInt8(UInt8((quantum >> 16) & 0xFF))
            out.putUInt8(UInt8((quantum >>  8) & 0xFF))
        default:
            break
        }

        return out.freeze()
    }

    /// Constant-time decoder. Implemented in Task 11.
    private static func decodeConstantTime(_ src: [UInt8]) throws -> Bytes {
        // Stub for now; Task 11 fills this in.
        throw Base64Error.constantTimeRejected
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter Base64DecodeTests`
Expected: all 10 decode tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/Base64 Tests/Base64Tests/Base64DecodeTests.swift
git commit -m "Base64: add strict decode with auto-variant, padding-optional, error cases"
```

---

## Task 10: Base64 decode .lenient mode

**Files:**
- Modify: `Tests/Base64Tests/Base64DecodeTests.swift` (append .lenient tests)

- [ ] **Step 1: Append the failing tests**

Append to `Tests/Base64Tests/Base64DecodeTests.swift`:

```swift
@Test func decodeLenientSkipsWhitespace() throws {
    let result = try Base64.decode("Zm9v\nYmFy", mode: .lenient)
    #expect(Array(result) == Array("foobar".utf8))
}

@Test func decodeLenientAcceptsSpacesAndTabs() throws {
    let result = try Base64.decode("Zm 9v\tYmFy", mode: .lenient)
    #expect(Array(result) == Array("foobar".utf8))
}

@Test func decodeLenientRejectsNonWhitespaceInvalid() {
    #expect(throws: Base64Error.invalidCharacter(offset: 1, byte: 0x21)) {
        _ = try Base64.decode("Z!9v", mode: .lenient)
    }
}
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `swift test --filter Base64DecodeTests`
Expected: all 13 decode tests pass (the `.lenient` path is already implemented in Task 9).

- [ ] **Step 3: Commit**

```bash
git add Tests/Base64Tests/Base64DecodeTests.swift
git commit -m "Base64: tests for lenient decode (whitespace skipping)"
```

---

## Task 11: Base64 decode .constantTime mode

**Files:**
- Create: `Sources/Base64/Internal/ConstantTime.swift`
- Modify: `Sources/Base64/Base64.swift` (replace decodeConstantTime stub)
- Create: `Tests/Base64Tests/Base64ConstantTimeTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/Base64Tests/Base64ConstantTimeTests.swift`:

```swift
import Testing
import Bytes
@testable import Base64

@Test func constantTimeDecodesValidInput() throws {
    let result = try Base64.decode("Zm9vYmFy", mode: .constantTime)
    #expect(Array(result) == Array("foobar".utf8))
}

@Test func constantTimeAcceptsBothAlphabets() throws {
    let standard = try Base64.decode("+/+/", mode: .constantTime)
    let urlSafe  = try Base64.decode("-_-_", mode: .constantTime)
    #expect(Array(standard) == [0xFB, 0xFF, 0xBF])
    #expect(Array(urlSafe)  == [0xFB, 0xFF, 0xBF])
}

@Test func constantTimeRejectsWhitespace() {
    // .lenient would accept "Zm9v\nYmFy"; .constantTime rejects.
    #expect(throws: Base64Error.constantTimeRejected) {
        _ = try Base64.decode("Zm9v\nYmFy", mode: .constantTime)
    }
}

@Test func constantTimeRejectsInvalidCharacterWithoutOffset() {
    #expect(throws: Base64Error.constantTimeRejected) {
        _ = try Base64.decode("Z!9v", mode: .constantTime)
    }
}

@Test func constantTimeHandlesPadded() throws {
    let result = try Base64.decode("Zg==", mode: .constantTime)
    #expect(Array(result) == [0x66])
}

@Test func constantTimeSmokeTimingInvariance() {
    // Smoke test: a fully valid input and one with a single invalid byte
    // at the midpoint should not be wildly different in wall-clock time.
    // This is NOT a real timing-attack defense — see Layer 25 for that.
    let validBytes = [UInt8](repeating: 0x41, count: 1000)  // all 'A'
    let valid = String(decoding: validBytes, as: UTF8.self)
    var invalidBytes = validBytes
    invalidBytes[500] = 0x21  // '!' invalid in middle
    let invalid = String(decoding: invalidBytes, as: UTF8.self)

    let start1 = ContinuousClock().now
    _ = try? Base64.decode(valid, mode: .constantTime)
    let dt1 = ContinuousClock().now - start1

    let start2 = ContinuousClock().now
    _ = try? Base64.decode(invalid, mode: .constantTime)
    let dt2 = ContinuousClock().now - start2

    // Allow a wide ratio because this is a smoke test, not a real
    // statistical analysis. We just want to catch a 100x divergence
    // that would indicate the decoder bailed out early on the invalid
    // input.
    let nanos1 = dt1.components.attoseconds / 1_000_000_000
    let nanos2 = dt2.components.attoseconds / 1_000_000_000
    let ratio = max(nanos1, nanos2) / max(min(nanos1, nanos2), 1)
    #expect(ratio < 10, "Timing ratio \(ratio) suggests early-exit on invalid input")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter Base64ConstantTimeTests`
Expected: tests fail because the stub throws `constantTimeRejected` for everything.

- [ ] **Step 3: Implement the constant-time decoder**

Create `Sources/Base64/Internal/ConstantTime.swift`:

```swift
import Bytes

/// Branch-free Base64 decoder. Accepts both standard and url-safe alphabets.
/// Rejects whitespace and any non-alphabet byte. Runtime is a function of
/// input length only — never of which byte was invalid.
///
/// Algorithm: classify each byte into a 6-bit value or "invalid" using
/// arithmetic comparisons (no data-dependent branches). Accumulate a
/// running invalid-mask across the whole input. After processing all
/// bytes, a single check on the mask determines whether to throw.
@usableFromInline
internal func base64DecodeConstantTime(_ src: [UInt8]) throws -> Bytes {
    // Strip up to 2 trailing '=' bytes for padding handling. The strip
    // count itself is data-dependent on the very last bytes, but those
    // bytes are public (length is public). We treat padding handling as
    // public information.
    var len = src.count
    var paddingCount = 0
    if len >= 1, src[len - 1] == 0x3D {
        paddingCount += 1
        len -= 1
    }
    if len >= 1, src[len - 1] == 0x3D {
        paddingCount += 1
        len -= 1
    }

    var invalidMask: UInt32 = 0
    var quantum: UInt32 = 0
    var sextets = 0
    var out = BytesMut(capacity: (len / 4) * 3 + 3)

    for i in 0..<len {
        let b = UInt32(src[i])
        let value = classifyByte(b, invalidMask: &invalidMask)

        quantum = (quantum << 6) | value
        sextets += 1

        if sextets == 4 {
            out.putUInt8(UInt8((quantum >> 16) & 0xFF))
            out.putUInt8(UInt8((quantum >>  8) & 0xFF))
            out.putUInt8(UInt8(quantum & 0xFF))
            quantum = 0
            sextets = 0
        }
    }

    // Tail
    switch sextets {
    case 0: break
    case 1:
        // Invalid quantum length — but we still emit nothing and mark invalid.
        invalidMask |= 1
    case 2:
        quantum <<= 12
        out.putUInt8(UInt8((quantum >> 16) & 0xFF))
    case 3:
        quantum <<= 6
        out.putUInt8(UInt8((quantum >> 16) & 0xFF))
        out.putUInt8(UInt8((quantum >>  8) & 0xFF))
    default: break
    }

    if invalidMask != 0 {
        // The output BytesMut is dropped on throw; ARC reclaims storage.
        // True secure-zeroize requires libsodium-style memset_s, which
        // doesn't land until Layer 12 crypto.
        throw Base64Error.constantTimeRejected
    }

    return out.freeze()
}

/// Classify an ASCII byte into a 6-bit value. Updates `invalidMask`
/// (OR-merging) when the byte is outside both alphabets. All ops are
/// branch-free arithmetic on UInt32.
@inline(__always)
private func classifyByte(_ b: UInt32, invalidMask: inout UInt32) -> UInt32 {
    // Range checks return 0xFFFFFFFF if in range, 0 otherwise.
    let isUpper  = inRange(b, lo: 0x41, hi: 0x5A)   // A-Z → 0-25
    let isLower  = inRange(b, lo: 0x61, hi: 0x7A)   // a-z → 26-51
    let isDigit  = inRange(b, lo: 0x30, hi: 0x39)   // 0-9 → 52-61
    let isPlus   = eq(b, 0x2B)                       // '+' → 62
    let isSlash  = eq(b, 0x2F)                       // '/' → 63
    let isMinus  = eq(b, 0x2D)                       // '-' → 62 (url-safe)
    let isUnder  = eq(b, 0x5F)                       // '_' → 63 (url-safe)

    let valUpper = (b - 0x41) & isUpper
    let valLower = ((b - 0x61) + 26) & isLower
    let valDigit = ((b - 0x30) + 52) & isDigit
    let valPlus  = 62 & isPlus
    let valSlash = 63 & isSlash
    let valMinus = 62 & isMinus
    let valUnder = 63 & isUnder

    let value = valUpper | valLower | valDigit | valPlus | valSlash | valMinus | valUnder

    // OR all the "is-valid" masks; if none matched, the result is 0,
    // meaning the byte was not in any alphabet.
    let validMask = isUpper | isLower | isDigit | isPlus | isSlash | isMinus | isUnder
    invalidMask |= ~validMask

    return value
}

/// Returns 0xFFFFFFFF if `b` is in [lo, hi], else 0. Branch-free.
@inline(__always)
private func inRange(_ b: UInt32, lo: UInt32, hi: UInt32) -> UInt32 {
    // (b >= lo) & (b <= hi)
    let geLo = ge(b, lo)
    let leHi = ge(hi, b)
    return geLo & leHi
}

/// Returns 0xFFFFFFFF if a >= b, else 0. Branch-free.
@inline(__always)
private func ge(_ a: UInt32, _ b: UInt32) -> UInt32 {
    // Equivalent to (a >= b) ? 0xFFFFFFFF : 0 without branches.
    // Trick: ((b - a - 1) >> 31) is 1 if a >= b, else 0; widen.
    let diff = b &- a &- 1
    let bit = (diff >> 31) & 1
    return UInt32(0) &- bit
}

/// Returns 0xFFFFFFFF if a == b, else 0. Branch-free.
@inline(__always)
private func eq(_ a: UInt32, _ b: UInt32) -> UInt32 {
    let x = a ^ b
    // nz = 1 if x != 0 (a != b), else 0
    let nz = (x | (UInt32(0) &- x)) >> 31
    // Want: nz==0 → 0xFFFFFFFF, nz==1 → 0
    // 1 &- nz: nz==0 → 1, nz==1 → 0
    // 0 &- (1 &- nz): nz==0 → 0xFFFFFFFF (wrap), nz==1 → 0
    return UInt32(0) &- (1 &- nz)
}
```

Now replace the stub `decodeConstantTime` in `Sources/Base64/Base64.swift`. Find this method:

```swift
private static func decodeConstantTime(_ src: [UInt8]) throws -> Bytes {
    // Stub for now; Task 11 fills this in.
    throw Base64Error.constantTimeRejected
}
```

Replace it with:

```swift
private static func decodeConstantTime(_ src: [UInt8]) throws -> Bytes {
    try base64DecodeConstantTime(src)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter Base64ConstantTimeTests`
Expected: all 6 constant-time tests pass.

- [ ] **Step 5: Verify the full Base64 module still works**

Run: `swift test --filter Base64Tests`
Expected: all Base64 tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/Base64 Tests/Base64Tests/Base64ConstantTimeTests.swift
git commit -m "Base64: add constant-time decoder (branch-free byte classification)"
```

---

## Task 12: Base64 extensions + round-trip + final coverage gate

**Files:**
- Create: `Sources/Base64/Base64Extensions.swift`
- Create: `Tests/Base64Tests/Base64RoundTripTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/Base64Tests/Base64RoundTripTests.swift`:

```swift
import Testing
import Bytes
@testable import Base64

@Test func extensionEncodeOnBytes() {
    let b = Bytes(Array("foo".utf8))
    #expect(b.base64Encoded() == "Zm9v")
    #expect(b.base64Encoded(variant: .urlSafe) == "Zm9v")
    #expect(b.base64Encoded(padding: false) == "Zm9v")
}

@Test func extensionStringBase64Encoding() {
    let b = Bytes(Array("foo".utf8))
    #expect(String(base64Encoding: b) == "Zm9v")
}

@Test func extensionBytesBase64Decoding() throws {
    let b = try Bytes(base64Decoding: "Zm9v")
    #expect(Array(b) == Array("foo".utf8))
}

@Test func roundTripEveryLengthThrough256() throws {
    // For each length 0...256, encode and decode under each variant +
    // padding setting, asserting the round-trip is identity.
    for length in 0...256 {
        let arr = (0..<length).map { UInt8($0 & 0xFF) }
        let original = Bytes(arr)
        for variant in [Base64.Variant.standard, .urlSafe] {
            for padding in [true, false] {
                let encoded = Base64.encode(original, variant: variant, padding: padding)
                let decoded = try Base64.decode(encoded)
                #expect(original == decoded,
                        "round-trip failed: length=\(length) variant=\(variant) padding=\(padding)")
            }
        }
    }
}

@Test func roundTripDeterministicRandom() throws {
    var state: UInt64 = 0x0123456789ABCDEF
    func next() -> UInt8 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return UInt8((state >> 56) & 0xFF)
    }
    var arr: [UInt8] = []
    arr.reserveCapacity(4096)
    for _ in 0..<4096 { arr.append(next()) }
    let original = Bytes(arr)

    for variant in [Base64.Variant.standard, .urlSafe] {
        for padding in [true, false] {
            let encoded = Base64.encode(original, variant: variant, padding: padding)
            let decoded = try Base64.decode(encoded)
            #expect(original == decoded)
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter Base64RoundTripTests`
Expected: compile errors for `base64Encoded`, `String(base64Encoding:)`, `Bytes(base64Decoding:)`.

- [ ] **Step 3: Implement the extensions**

Create `Sources/Base64/Base64Extensions.swift`:

```swift
import Bytes

extension Bytes {
    /// Base64-encode this buffer.
    public func base64Encoded(
        variant: Base64.Variant = .standard,
        padding: Bool = true,
        lineWrap: Base64.LineWrap = .none
    ) -> String {
        Base64.encode(self, variant: variant, padding: padding, lineWrap: lineWrap)
    }
}

extension String {
    /// Construct a String containing the Base64 encoding of `bytes`.
    public init(
        base64Encoding bytes: Bytes,
        variant: Base64.Variant = .standard,
        padding: Bool = true,
        lineWrap: Base64.LineWrap = .none
    ) {
        self = Base64.encode(bytes, variant: variant, padding: padding, lineWrap: lineWrap)
    }
}

extension Bytes {
    /// Decode a Base64 string into bytes.
    public init(
        base64Decoding s: String,
        mode: Base64.DecodeMode = .strict
    ) throws {
        self = try Base64.decode(s, mode: mode)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter Base64Tests`
Expected: all Base64 tests pass.

- [ ] **Step 5: Run the full suite and check coverage**

Run: `swift test --enable-code-coverage`

Then inspect coverage:

```bash
COV_BIN=$(swift build --show-bin-path)
xcrun llvm-cov report \
    "$COV_BIN/BedrockPackageTests.xctest/Contents/MacOS/BedrockPackageTests" \
    -instr-profile "$COV_BIN/codecov/default.profdata" \
    Sources/Hex Sources/Base64
```

Expected: coverage on `Sources/Hex/` and `Sources/Base64/` each ≥ 90%. **Report the table.** If a file is below 90%, identify the uncovered lines and add a single targeted test for the gap.

- [ ] **Step 6: Commit and push**

```bash
git add Sources/Base64/Base64Extensions.swift Tests/Base64Tests/Base64RoundTripTests.swift
git commit -m "Base64: add Bytes/String extensions, round-trip tests, coverage gate"
git push origin main
```

---

## Task 13: Cross-link Layer 1 doc

**Files:**
- Modify: `layers/layer-01-primitives.md`

- [ ] **Step 1: Update the status banner**

Open `layers/layer-01-primitives.md`. The existing banner reads:

```markdown
> **Status:** core bytes module shipping in `Sources/Bytes/` ([design](../docs/superpowers/specs/2026-05-09-bytes-design.md), [plan](../docs/superpowers/plans/2026-05-09-bytes-module.md)). Remaining categories (Hex, Base64, varints, UUID, URL/IDNA, etc.) are tracked here pending their own designs.
```

Replace it with:

```markdown
> **Status:** shipping modules:
> - `Sources/Bytes/` — core bytes ([design](../docs/superpowers/specs/2026-05-09-bytes-design.md), [plan](../docs/superpowers/plans/2026-05-09-bytes-module.md))
> - `Sources/Hex/` — hex codec ([design](../docs/superpowers/specs/2026-05-10-hex-base64-design.md), [plan](../docs/superpowers/plans/2026-05-10-hex-base64-modules.md))
> - `Sources/Base64/` — base64 codec, including constant-time decode ([same design + plan](../docs/superpowers/specs/2026-05-10-hex-base64-design.md))
>
> Remaining categories (varints, UUID, BitSet, percent encoding, SIMD UTF-8, COBS, URL/IDNA) pending their own designs.
```

- [ ] **Step 2: Commit and push**

```bash
git add layers/layer-01-primitives.md
git commit -m "Hex+Base64: cross-link Layer 1 doc to new module designs"
git push origin main
```
