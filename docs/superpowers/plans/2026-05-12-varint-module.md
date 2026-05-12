# Varint Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a stdlib-only `Varint` module with LEB128 unsigned (`UInt32`/`UInt64`) and ZigZag-LEB128 signed (`Int32`/`Int64`) varint encode/decode, integrated with the existing `Bytes` module.

**Architecture:** A namespaced `public enum Varint` exposing per-width encode/decode entry points. Encoders write into `BytesMut`; decoders read from `BytesReader` or one-shot `Bytes`. Signed variants ZigZag-wrap then delegate to unsigned. Decoders bound at per-width byte caps (5 for u32, 10 for u64) to prevent varint bombs. Bytes/Reader extension methods provide the ergonomic API surface.

**Tech Stack:** Swift 6 (toolchain ≥ 6.0), SwiftPM, Swift Testing. Depends only on `Bytes`. No third-party dependencies, no Foundation.

**Source spec:** `docs/superpowers/specs/2026-05-12-varint-design.md`.

**Working directory:** `/Users/satishbabariya/Desktop/Bedrock`. Run all `swift` commands from there.

---

## Task 1: Package scaffolding

**Files:**
- Modify: `Package.swift`
- Create: `Sources/Varint/Varint.swift` (placeholder)
- Create: `Tests/VarintTests/SmokeTest.swift`

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
    ]
)
```

- [ ] **Step 2: Create placeholder source file**

Create `Sources/Varint/Varint.swift`:

```swift
// Varint — implemented in Task 2+.
@usableFromInline internal let _varintModuleLoaded = true
```

- [ ] **Step 3: Create the smoke test**

Create `Tests/VarintTests/SmokeTest.swift`:

```swift
import Testing
@testable import Varint

@Test func varintModuleLoads() {
    #expect(_varintModuleLoaded == true)
}
```

- [ ] **Step 4: Verify build + tests**

Run: `swift test`
Expected: all prior tests pass + 1 new smoke test. The total count is whatever the prior count was + 1.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/Varint Tests/VarintTests
git commit -m "Varint: scaffold module and smoke test"
```

---

## Task 2: VarintError + Varint namespace + bounds constants

**Files:**
- Create: `Sources/Varint/VarintError.swift`
- Modify: `Sources/Varint/Varint.swift` (replace placeholder with namespace + bounds)
- Create: `Tests/VarintTests/VarintErrorTests.swift`
- Modify: `Tests/VarintTests/SmokeTest.swift` (replace stale placeholder reference)

- [ ] **Step 1: Write the failing tests**

Create `Tests/VarintTests/VarintErrorTests.swift`:

```swift
import Testing
@testable import Varint

@Test func varintErrorEquality() {
    #expect(VarintError.truncated == VarintError.truncated)
    #expect(VarintError.overflow == VarintError.overflow)
    #expect(VarintError.truncated != VarintError.overflow)
}

@Test func boundsConstants() {
    #expect(Varint.maxBytes32 == 5)
    #expect(Varint.maxBytes64 == 10)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter VarintErrorTests`
Expected: compile errors — `VarintError` and `Varint.maxBytes*` not defined.

- [ ] **Step 3: Implement VarintError**

Create `Sources/Varint/VarintError.swift`:

```swift
/// Errors raised by varint decoding.
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

- [ ] **Step 4: Implement the Varint namespace + bounds**

Replace `Sources/Varint/Varint.swift` with:

```swift
import Bytes

/// LEB128 + ZigZag-LEB128 varint codec namespace.
public enum Varint {
    /// Maximum encoded byte count for a `UInt32` (or `Int32` via ZigZag).
    public static let maxBytes32 = 5

    /// Maximum encoded byte count for a `UInt64` (or `Int64` via ZigZag).
    public static let maxBytes64 = 10
}
```

- [ ] **Step 5: Update the smoke test**

Replace `Tests/VarintTests/SmokeTest.swift` with:

```swift
import Testing
@testable import Varint

@Test func varintNamespaceExists() {
    #expect(Varint.maxBytes32 == 5)
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `swift test --filter VarintTests`
Expected: 3 tests pass (1 smoke + 2 error/bounds).

- [ ] **Step 7: Commit**

```bash
git add Sources/Varint Tests/VarintTests
git commit -m "Varint: add namespace, bounds constants, and VarintError"
```

---

## Task 3: LEB128 unsigned encode (UInt32 + UInt64)

**Files:**
- Create: `Sources/Varint/VarintLEB128.swift`
- Create: `Tests/VarintTests/VarintLEB128Tests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/VarintTests/VarintLEB128Tests.swift`:

```swift
import Testing
import Bytes
@testable import Varint

@Test func encodeUInt64Zero() {
    var buf = BytesMut()
    let n = Varint.encode(UInt64(0), into: &buf)
    #expect(n == 1)
    #expect(Array(buf.freeze()) == [0x00])
}

@Test func encodeUInt64SmallValues() {
    var buf = BytesMut()
    Varint.encode(UInt64(1), into: &buf)
    Varint.encode(UInt64(127), into: &buf)
    Varint.encode(UInt64(128), into: &buf)
    Varint.encode(UInt64(150), into: &buf)
    #expect(Array(buf.freeze()) == [0x01, 0x7F, 0x80, 0x01, 0x96, 0x01])
}

@Test func encodeUInt64TwoByteBoundary() {
    var buf = BytesMut()
    Varint.encode(UInt64(16383), into: &buf)
    Varint.encode(UInt64(16384), into: &buf)
    #expect(Array(buf.freeze()) == [0xFF, 0x7F, 0x80, 0x80, 0x01])
}

@Test func encodeUInt32Max() {
    var buf = BytesMut()
    let n = Varint.encode(UInt32.max, into: &buf)
    #expect(n == 5)
    #expect(Array(buf.freeze()) == [0xFF, 0xFF, 0xFF, 0xFF, 0x0F])
}

@Test func encodeUInt64Max() {
    var buf = BytesMut()
    let n = Varint.encode(UInt64.max, into: &buf)
    #expect(n == 10)
    #expect(Array(buf.freeze()) == [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01])
}

@Test func encodeUInt32MatchesUInt64ForSmallValues() {
    var bufA = BytesMut()
    var bufB = BytesMut()
    Varint.encode(UInt32(150), into: &bufA)
    Varint.encode(UInt64(150), into: &bufB)
    #expect(Array(bufA.freeze()) == Array(bufB.freeze()))
}

@Test func encodeAppendsToExistingBuffer() {
    var buf = BytesMut()
    buf.putUInt8(0xAA)
    Varint.encode(UInt64(150), into: &buf)
    #expect(Array(buf.freeze()) == [0xAA, 0x96, 0x01])
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter VarintLEB128Tests`
Expected: compile errors — `Varint.encode` not defined.

- [ ] **Step 3: Implement encode**

Create `Sources/Varint/VarintLEB128.swift`:

```swift
import Bytes

extension Varint {

    /// Encode an unsigned 64-bit LEB128 varint into `out`. Returns the byte
    /// count appended (1–10).
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

    /// Encode an unsigned 32-bit LEB128 varint into `out`. Returns 1–5.
    @discardableResult
    public static func encode(_ value: UInt32, into out: inout BytesMut) -> Int {
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
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter VarintLEB128Tests`
Expected: 7 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Varint/VarintLEB128.swift Tests/VarintTests/VarintLEB128Tests.swift
git commit -m "Varint: add LEB128 unsigned encode for UInt32 and UInt64"
```

---

## Task 4: LEB128 unsigned decode (UInt32 + UInt64) + error tests

**Files:**
- Modify: `Sources/Varint/VarintLEB128.swift` (append decode methods)
- Modify: `Tests/VarintTests/VarintLEB128Tests.swift` (append decode tests)
- Create: `Tests/VarintTests/VarintErrorTests.swift` already has 2 tests; we'll append more

- [ ] **Step 1: Write the failing tests**

Append to `Tests/VarintTests/VarintLEB128Tests.swift`:

```swift
@Test func decodeUInt64KnownVectors() throws {
    var r = BytesReader(Bytes([0x00, 0x01, 0x7F, 0x80, 0x01, 0x96, 0x01]))
    #expect(try Varint.decodeUInt64(from: &r) == 0)
    #expect(try Varint.decodeUInt64(from: &r) == 1)
    #expect(try Varint.decodeUInt64(from: &r) == 127)
    #expect(try Varint.decodeUInt64(from: &r) == 128)
    #expect(try Varint.decodeUInt64(from: &r) == 150)
    #expect(r.isExhausted)
}

@Test func decodeUInt32KnownVectors() throws {
    var r = BytesReader(Bytes([0xFF, 0xFF, 0xFF, 0xFF, 0x0F]))
    #expect(try Varint.decodeUInt32(from: &r) == UInt32.max)
    #expect(r.isExhausted)
}

@Test func decodeUInt64MaxValue() throws {
    var r = BytesReader(Bytes([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01]))
    #expect(try Varint.decodeUInt64(from: &r) == UInt64.max)
    #expect(r.isExhausted)
}

@Test func roundTripUInt64Powers() throws {
    let values: [UInt64] = [
        0, 1, 127, 128, 16383, 16384,
        UInt64(1) << 32, UInt64(UInt32.max), UInt64.max - 1, UInt64.max,
    ]
    for v in values {
        var buf = BytesMut()
        Varint.encode(v, into: &buf)
        var r = BytesReader(buf.freeze())
        let decoded = try Varint.decodeUInt64(from: &r)
        #expect(decoded == v, "round-trip failed for \(v)")
    }
}

@Test func roundTripUInt32Boundaries() throws {
    let values: [UInt32] = [0, 1, 127, 128, 16383, 16384, UInt32.max - 1, UInt32.max]
    for v in values {
        var buf = BytesMut()
        Varint.encode(v, into: &buf)
        var r = BytesReader(buf.freeze())
        let decoded = try Varint.decodeUInt32(from: &r)
        #expect(decoded == v, "round-trip failed for \(v)")
    }
}

@Test func encodeReturnCountMatchesDecodeConsumed() throws {
    var buf = BytesMut()
    let written = Varint.encode(UInt64(0x1_2345_6789), into: &buf)
    var r = BytesReader(buf.freeze())
    _ = try Varint.decodeUInt64(from: &r)
    #expect(r.consumed == written)
}
```

Append to `Tests/VarintTests/VarintErrorTests.swift`:

```swift
import Bytes

@Test func decodeEmptyInputThrowsTruncated() {
    var r = BytesReader(Bytes())
    #expect(throws: VarintError.truncated) {
        _ = try Varint.decodeUInt64(from: &r)
    }
}

@Test func decodeContinuationBitOnLastByteThrowsTruncated() {
    var r = BytesReader(Bytes([0x80]))
    #expect(throws: VarintError.truncated) {
        _ = try Varint.decodeUInt64(from: &r)
    }
}

@Test func decodeUInt64TooManyBytesThrowsOverflow() {
    // 11 bytes all with continuation set — exceeds 10-byte cap.
    let raw: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01]
    var r = BytesReader(Bytes(raw))
    #expect(throws: VarintError.overflow) {
        _ = try Varint.decodeUInt64(from: &r)
    }
}

@Test func decodeUInt64FinalBytePayloadTooLargeThrowsOverflow() {
    // 10 bytes, but the 10th carries a payload > 1 (would push beyond 64 bits).
    let raw: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x02]
    var r = BytesReader(Bytes(raw))
    #expect(throws: VarintError.overflow) {
        _ = try Varint.decodeUInt64(from: &r)
    }
}

@Test func decodeUInt32TooManyBytesThrowsOverflow() {
    // 6 bytes all with continuation set — exceeds 5-byte cap.
    let raw: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01]
    var r = BytesReader(Bytes(raw))
    #expect(throws: VarintError.overflow) {
        _ = try Varint.decodeUInt32(from: &r)
    }
}

@Test func decodeUInt32FinalBytePayloadTooLargeThrowsOverflow() {
    // 5 bytes, 5th carries payload > 0x0F (would push beyond 32 bits).
    let raw: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF, 0x10]
    var r = BytesReader(Bytes(raw))
    #expect(throws: VarintError.overflow) {
        _ = try Varint.decodeUInt32(from: &r)
    }
}

@Test func decodeNonCanonicalEncodingIsAccepted() throws {
    // 0x80 0x00 = non-canonical encoding of 0 (canonical is [0x00]).
    // Lenient mode accepts this.
    var r = BytesReader(Bytes([0x80, 0x00]))
    #expect(try Varint.decodeUInt64(from: &r) == 0)
}

@Test func decodeTruncatedAdvancesCursorToFailurePoint() {
    // Input [0x80]: decoder reads byte 0 (cursor → 1), sees continuation,
    // tries to read byte 1, gets nil, throws .truncated. Cursor is at 1.
    var r = BytesReader(Bytes([0x80]))
    #expect(throws: VarintError.truncated) {
        _ = try Varint.decodeUInt64(from: &r)
    }
    #expect(r.consumed == 1)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter VarintTests`
Expected: compile errors — `Varint.decodeUInt32` and `Varint.decodeUInt64` not defined.

- [ ] **Step 3: Implement decode**

Append to `Sources/Varint/VarintLEB128.swift`:

```swift
extension Varint {

    /// Decode an unsigned 64-bit LEB128 varint. Throws `.truncated` if input
    /// ends mid-varint, `.overflow` if the encoded form exceeds 10 bytes or
    /// the final byte's payload would overflow `UInt64`.
    public static func decodeUInt64(from reader: inout BytesReader) throws -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        var byteCount = 0
        while byteCount < maxBytes64 {
            guard let byte = reader.readUInt8() else { throw VarintError.truncated }
            byteCount += 1
            let payload = UInt64(byte & 0x7F)
            if byteCount == maxBytes64 && payload > 1 {
                throw VarintError.overflow
            }
            result |= payload << shift
            if byte & 0x80 == 0 { return result }
            shift += 7
        }
        throw VarintError.overflow
    }

    /// Decode an unsigned 32-bit LEB128 varint. Bounded at 5 bytes; the
    /// 5th byte's payload must fit in 4 bits.
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
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter VarintTests`
Expected: all decode + error tests pass (Round-trip tests should also pass since encode lands the same bytes the decoder reads back).

- [ ] **Step 5: Commit**

```bash
git add Sources/Varint/VarintLEB128.swift Tests/VarintTests/VarintLEB128Tests.swift Tests/VarintTests/VarintErrorTests.swift
git commit -m "Varint: add LEB128 unsigned decode with truncated/overflow detection"
```

---

## Task 5: One-shot helpers (`encoded(_:)` and `decode(from: Bytes)`)

**Files:**
- Modify: `Sources/Varint/VarintLEB128.swift` (append one-shot helpers)
- Modify: `Tests/VarintTests/VarintLEB128Tests.swift` (append tests)

- [ ] **Step 1: Append the failing tests**

Append to `Tests/VarintTests/VarintLEB128Tests.swift`:

```swift
@Test func encodedUInt64ReturnsBytes() {
    #expect(Array(Varint.encoded(UInt64(0))) == [0x00])
    #expect(Array(Varint.encoded(UInt64(150))) == [0x96, 0x01])
    #expect(Array(Varint.encoded(UInt64.max)).count == 10)
}

@Test func encodedUInt32ReturnsBytes() {
    #expect(Array(Varint.encoded(UInt32(150))) == [0x96, 0x01])
    #expect(Array(Varint.encoded(UInt32.max)).count == 5)
}

@Test func decodeUInt64FromBytesReturnsValueAndConsumed() throws {
    // Encode three values back-to-back, then decode the first one.
    var buf = BytesMut()
    Varint.encode(UInt64(150), into: &buf)
    Varint.encode(UInt64(99), into: &buf)
    Varint.encode(UInt64(7), into: &buf)
    let frozen = buf.freeze()
    let (v, consumed) = try Varint.decodeUInt64(from: frozen)
    #expect(v == 150)
    #expect(consumed == 2)
}

@Test func decodeUInt32FromBytesReturnsValueAndConsumed() throws {
    let bytes = Varint.encoded(UInt32(16384))  // 3 bytes
    let (v, consumed) = try Varint.decodeUInt32(from: bytes)
    #expect(v == 16384)
    #expect(consumed == 3)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter VarintLEB128Tests`
Expected: compile errors — `Varint.encoded` and `Varint.decode...(from: Bytes)` not defined.

- [ ] **Step 3: Implement one-shot helpers**

Append to `Sources/Varint/VarintLEB128.swift`:

```swift
extension Varint {

    /// One-shot encode: returns the varint bytes as a fresh `Bytes` value.
    public static func encoded(_ value: UInt64) -> Bytes {
        var b = BytesMut(capacity: maxBytes64)
        encode(value, into: &b)
        return b.freeze()
    }

    /// One-shot encode for UInt32. Result is 1–5 bytes.
    public static func encoded(_ value: UInt32) -> Bytes {
        var b = BytesMut(capacity: maxBytes32)
        encode(value, into: &b)
        return b.freeze()
    }

    /// One-shot decode: returns the value and the number of bytes consumed.
    public static func decodeUInt64(from bytes: Bytes) throws -> (value: UInt64, consumed: Int) {
        var r = BytesReader(bytes)
        let v = try decodeUInt64(from: &r)
        return (v, r.consumed)
    }

    /// One-shot decode for UInt32.
    public static func decodeUInt32(from bytes: Bytes) throws -> (value: UInt32, consumed: Int) {
        var r = BytesReader(bytes)
        let v = try decodeUInt32(from: &r)
        return (v, r.consumed)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter VarintLEB128Tests`
Expected: all VarintLEB128Tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Varint/VarintLEB128.swift Tests/VarintTests/VarintLEB128Tests.swift
git commit -m "Varint: add one-shot encoded(_:) and decode(from: Bytes) helpers"
```

---

## Task 6: ZigZag signed encode/decode (Int32 + Int64)

**Files:**
- Create: `Sources/Varint/VarintZigZag.swift`
- Create: `Tests/VarintTests/VarintZigZagTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/VarintTests/VarintZigZagTests.swift`:

```swift
import Testing
import Bytes
@testable import Varint

@Test func zigzagKnownVectors() {
    // ZigZag mapping: 0→0, -1→1, 1→2, -2→3, 2→4, ...
    // Encoded varint bytes for these are [0x00], [0x01], [0x02], [0x03], [0x04].
    #expect(Array(Varint.encoded(Int64(0))) == [0x00])
    #expect(Array(Varint.encoded(Int64(-1))) == [0x01])
    #expect(Array(Varint.encoded(Int64(1))) == [0x02])
    #expect(Array(Varint.encoded(Int64(-2))) == [0x03])
    #expect(Array(Varint.encoded(Int64(2))) == [0x04])
}

@Test func zigzagInt32KnownVectors() {
    #expect(Array(Varint.encoded(Int32(0))) == [0x00])
    #expect(Array(Varint.encoded(Int32(-1))) == [0x01])
    #expect(Array(Varint.encoded(Int32(1))) == [0x02])
}

@Test func roundTripInt64Boundaries() throws {
    let values: [Int64] = [0, -1, 1, -2, 2, Int64.min, Int64.max, -1000, 1000, Int64.min + 1, Int64.max - 1]
    for v in values {
        var buf = BytesMut()
        Varint.encode(v, into: &buf)
        var r = BytesReader(buf.freeze())
        let decoded = try Varint.decodeInt64(from: &r)
        #expect(decoded == v, "Int64 round-trip failed for \(v)")
    }
}

@Test func roundTripInt32Boundaries() throws {
    let values: [Int32] = [0, -1, 1, -2, 2, Int32.min, Int32.max, -1000, 1000, Int32.min + 1, Int32.max - 1]
    for v in values {
        var buf = BytesMut()
        Varint.encode(v, into: &buf)
        var r = BytesReader(buf.freeze())
        let decoded = try Varint.decodeInt32(from: &r)
        #expect(decoded == v, "Int32 round-trip failed for \(v)")
    }
}

@Test func zigzagInt64MinRoundTrips() throws {
    // The tricky case — naive negation would trap.
    let v = Int64.min
    var buf = BytesMut()
    Varint.encode(v, into: &buf)
    var r = BytesReader(buf.freeze())
    #expect(try Varint.decodeInt64(from: &r) == Int64.min)
}

@Test func zigzagInt32MinRoundTrips() throws {
    let v = Int32.min
    var buf = BytesMut()
    Varint.encode(v, into: &buf)
    var r = BytesReader(buf.freeze())
    #expect(try Varint.decodeInt32(from: &r) == Int32.min)
}

@Test func zigzagNegativeAndPositiveTwinSameLength() {
    // ZigZag pairs negative n and positive (n-1) into adjacent codes,
    // so their encoded lengths match.
    #expect(Array(Varint.encoded(Int64(-100))).count == Array(Varint.encoded(Int64(99))).count)
    #expect(Array(Varint.encoded(Int64(-1_000_000))).count == Array(Varint.encoded(Int64(999_999))).count)
}

@Test func decodedInt64FromBytesReturnsValueAndConsumed() throws {
    let bytes = Varint.encoded(Int64(-1000))
    let (v, consumed) = try Varint.decodeInt64(from: bytes)
    #expect(v == -1000)
    #expect(consumed == bytes.count)
}

@Test func decodedInt32FromBytesReturnsValueAndConsumed() throws {
    let bytes = Varint.encoded(Int32(-1000))
    let (v, consumed) = try Varint.decodeInt32(from: bytes)
    #expect(v == -1000)
    #expect(consumed == bytes.count)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter VarintZigZagTests`
Expected: compile errors — `Varint.encode(_: Int32/Int64, ...)` and `Varint.decodeInt32/64` not defined.

- [ ] **Step 3: Implement ZigZag wrappers and signed encode/decode**

Create `Sources/Varint/VarintZigZag.swift`:

```swift
import Bytes

extension Varint {

    // ─── ZigZag wrappers (internal) ──────────────────────────────────────

    @inline(__always)
    internal static func zigzagEncode(_ n: Int32) -> UInt32 {
        UInt32(bitPattern: (n << 1) ^ (n >> 31))
    }

    @inline(__always)
    internal static func zigzagEncode(_ n: Int64) -> UInt64 {
        UInt64(bitPattern: (n << 1) ^ (n >> 63))
    }

    @inline(__always)
    internal static func zigzagDecode(_ u: UInt32) -> Int32 {
        Int32(bitPattern: (u >> 1)) ^ -Int32(bitPattern: u & 1)
    }

    @inline(__always)
    internal static func zigzagDecode(_ u: UInt64) -> Int64 {
        Int64(bitPattern: (u >> 1)) ^ -Int64(bitPattern: u & 1)
    }

    // ─── Signed encode (delegates to unsigned) ──────────────────────────

    /// Encode a signed 32-bit ZigZag-LEB128 varint into `out`. Returns 1–5.
    @discardableResult
    public static func encode(_ value: Int32, into out: inout BytesMut) -> Int {
        encode(zigzagEncode(value), into: &out)
    }

    /// Encode a signed 64-bit ZigZag-LEB128 varint into `out`. Returns 1–10.
    @discardableResult
    public static func encode(_ value: Int64, into out: inout BytesMut) -> Int {
        encode(zigzagEncode(value), into: &out)
    }

    // ─── Signed one-shot encode ─────────────────────────────────────────

    public static func encoded(_ value: Int32) -> Bytes {
        var b = BytesMut(capacity: maxBytes32)
        encode(value, into: &b)
        return b.freeze()
    }

    public static func encoded(_ value: Int64) -> Bytes {
        var b = BytesMut(capacity: maxBytes64)
        encode(value, into: &b)
        return b.freeze()
    }

    // ─── Signed decode ──────────────────────────────────────────────────

    /// Decode a signed 32-bit ZigZag-LEB128 varint.
    public static func decodeInt32(from reader: inout BytesReader) throws -> Int32 {
        zigzagDecode(try decodeUInt32(from: &reader))
    }

    /// Decode a signed 64-bit ZigZag-LEB128 varint.
    public static func decodeInt64(from reader: inout BytesReader) throws -> Int64 {
        zigzagDecode(try decodeUInt64(from: &reader))
    }

    // ─── Signed one-shot decode ─────────────────────────────────────────

    public static func decodeInt32(from bytes: Bytes) throws -> (value: Int32, consumed: Int) {
        var r = BytesReader(bytes)
        let v = try decodeInt32(from: &r)
        return (v, r.consumed)
    }

    public static func decodeInt64(from bytes: Bytes) throws -> (value: Int64, consumed: Int) {
        var r = BytesReader(bytes)
        let v = try decodeInt64(from: &r)
        return (v, r.consumed)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter VarintZigZagTests`
Expected: all 9 ZigZag tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Varint/VarintZigZag.swift Tests/VarintTests/VarintZigZagTests.swift
git commit -m "Varint: add ZigZag-LEB128 signed encode/decode for Int32 and Int64"
```

---

## Task 7: Extensions on BytesMut + BytesReader

**Files:**
- Create: `Sources/Varint/VarintExtensions.swift`
- Create: `Tests/VarintTests/VarintExtensionsTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/VarintTests/VarintExtensionsTests.swift`:

```swift
import Testing
import Bytes
@testable import Varint

@Test func putVarintUInt32MatchesNamespaceForm() {
    var bufA = BytesMut()
    var bufB = BytesMut()
    bufA.putVarint(UInt32(150))
    Varint.encode(UInt32(150), into: &bufB)
    #expect(Array(bufA.freeze()) == Array(bufB.freeze()))
}

@Test func putVarintReturnsByteCount() {
    var buf = BytesMut()
    let n = buf.putVarint(UInt64(150))
    #expect(n == 2)
}

@Test func readVarintUInt64ReturnsValueAndAdvances() throws {
    var buf = BytesMut()
    Varint.encode(UInt64(150), into: &buf)
    Varint.encode(UInt64(99), into: &buf)
    var r = BytesReader(buf.freeze())
    #expect(try r.readVarintUInt64() == 150)
    #expect(r.consumed == 2)
    #expect(try r.readVarintUInt64() == 99)
}

@Test func roundTripThroughExtensions() throws {
    var buf = BytesMut()
    buf.putVarint(UInt32(16384))
    buf.putVarint(Int32(-1000))
    buf.putVarint(UInt64(UInt64.max))
    buf.putVarint(Int64(Int64.min))
    var r = BytesReader(buf.freeze())
    #expect(try r.readVarintUInt32() == 16384)
    #expect(try r.readVarintInt32() == -1000)
    #expect(try r.readVarintUInt64() == UInt64.max)
    #expect(try r.readVarintInt64() == Int64.min)
    #expect(r.isExhausted)
}

@Test func readVarintTruncatedAdvancesCursorToFailurePoint() {
    var r = BytesReader(Bytes([0x80]))
    #expect(throws: VarintError.truncated) {
        _ = try r.readVarintUInt64()
    }
    #expect(r.consumed == 1)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter VarintExtensionsTests`
Expected: compile errors — `putVarint` and `readVarintXxx` methods not defined.

- [ ] **Step 3: Implement extensions**

Create `Sources/Varint/VarintExtensions.swift`:

```swift
import Bytes

extension BytesMut {
    @discardableResult
    public mutating func putVarint(_ v: UInt32) -> Int { Varint.encode(v, into: &self) }

    @discardableResult
    public mutating func putVarint(_ v: UInt64) -> Int { Varint.encode(v, into: &self) }

    @discardableResult
    public mutating func putVarint(_ v: Int32) -> Int { Varint.encode(v, into: &self) }

    @discardableResult
    public mutating func putVarint(_ v: Int64) -> Int { Varint.encode(v, into: &self) }
}

extension BytesReader {
    public mutating func readVarintUInt32() throws -> UInt32 {
        try Varint.decodeUInt32(from: &self)
    }

    public mutating func readVarintUInt64() throws -> UInt64 {
        try Varint.decodeUInt64(from: &self)
    }

    public mutating func readVarintInt32() throws -> Int32 {
        try Varint.decodeInt32(from: &self)
    }

    public mutating func readVarintInt64() throws -> Int64 {
        try Varint.decodeInt64(from: &self)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter VarintExtensionsTests`
Expected: all 5 extension tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Varint/VarintExtensions.swift Tests/VarintTests/VarintExtensionsTests.swift
git commit -m "Varint: add BytesMut.putVarint and BytesReader.readVarint* extensions"
```

---

## Task 8: Final verification + Layer 1 cross-link + push

**Files:**
- Modify: `layers/layer-01-primitives.md`

- [ ] **Step 1: Run the full suite on a clean build**

```bash
swift package clean
swift test
```

Expected: every test passes. Total ≈ 260 tests.

- [ ] **Step 2: Check coverage**

```bash
swift test --enable-code-coverage
COV_BIN=$(swift build --show-bin-path)
xcrun llvm-cov report \
    "$COV_BIN/BedrockPackageTests.xctest/Contents/MacOS/BedrockPackageTests" \
    -instr-profile "$COV_BIN/codecov/default.profdata" \
    Sources/Varint
```

Expected: coverage on `Sources/Varint/` ≥ 90%. **Report the table.** If a file is below 90%, identify the gap and add a single targeted test.

- [ ] **Step 3: Verify release build**

Run: `swift build -c release`
Expected: build succeeds with no errors or new warnings.

- [ ] **Step 4: Update the Layer 1 status banner**

Open `layers/layer-01-primitives.md`. Find the existing status banner. Replace the `Status:` block with:

```markdown
> **Status:** shipping modules:
> - `Sources/Bytes/` — core bytes ([design](../docs/superpowers/specs/2026-05-09-bytes-design.md), [plan](../docs/superpowers/plans/2026-05-09-bytes-module.md))
> - `Sources/Hex/` — hex codec ([design](../docs/superpowers/specs/2026-05-10-hex-base64-design.md), [plan](../docs/superpowers/plans/2026-05-10-hex-base64-modules.md))
> - `Sources/Base64/` — base64 codec, including constant-time decode ([same design + plan](../docs/superpowers/specs/2026-05-10-hex-base64-design.md))
> - `Sources/UUID/` — UUID type with v4/v7/v8 generation; v1/v3/v5/v6 parse/inspect work, generation deferred to follow-up patches when Layer 8 (MAC) and Layer 12 (MD5/SHA-1) ship ([design](../docs/superpowers/specs/2026-05-10-uuid-design.md), [plan](../docs/superpowers/plans/2026-05-10-uuid-module.md))
> - `Sources/Varint/` — LEB128 unsigned + ZigZag-LEB128 signed for UInt32/UInt64/Int32/Int64 ([design](../docs/superpowers/specs/2026-05-12-varint-design.md), [plan](../docs/superpowers/plans/2026-05-12-varint-module.md))
>
> Remaining categories (BitSet, percent encoding, SIMD UTF-8, COBS, URL/IDNA) pending their own designs.
```

- [ ] **Step 5: Commit and push**

```bash
git add layers/layer-01-primitives.md
git commit -m "Varint: cross-link Layer 1 doc to Varint module design+plan"
git push origin main
```

Expected: push succeeds; ~9 commits added since the spec.
