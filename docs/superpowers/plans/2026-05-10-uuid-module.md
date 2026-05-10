# UUID Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a stdlib-only `UUID` module with universal parse/format/inspect for all RFC 4122/9562 versions and generation for v4/v7/v8 (the versions buildable today).

**Architecture:** A 128-bit value-type UUID backed by `SIMD16<UInt8>`. Six source files split by concern (type/conformances, version+variant, error, parse, format, generate) plus an isolated libc-bridging wall-clock shim. `Comparable` is byte-wise so v7s sort by timestamp. RNG generators accept `inout some RandomNumberGenerator`; default uses `SystemRandomNumberGenerator`.

**Tech Stack:** Swift 6 (toolchain ≥ 6.0), SwiftPM, Swift Testing. No third-party dependencies, no Foundation. One libc shim (`clock_gettime` / `GetSystemTimePreciseAsFileTime`) under `#if canImport(...)`.

**Source spec:** `docs/superpowers/specs/2026-05-10-uuid-design.md`.

**Working directory:** `/Users/satishbabariya/Desktop/Bedrock`. Run all `swift` commands from there.

---

## Task 1: Package scaffolding

**Files:**
- Modify: `Package.swift`
- Create: `Sources/UUID/UUID.swift` (placeholder)
- Create: `Tests/UUIDTests/SmokeTest.swift`

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
    ]
)
```

- [ ] **Step 2: Create placeholder source file**

Create `Sources/UUID/UUID.swift`:

```swift
// UUID — implemented in Task 2+.
@usableFromInline internal let _uuidModuleLoaded = true
```

- [ ] **Step 3: Create the smoke test**

Create `Tests/UUIDTests/SmokeTest.swift`:

```swift
import Testing
@testable import UUID

@Test func uuidModuleLoads() {
    #expect(_uuidModuleLoaded == true)
}
```

- [ ] **Step 4: Verify build + tests**

Run: `swift test`
Expected: all 152 prior tests pass + 1 new smoke test = 153 total.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/UUID Tests/UUIDTests
git commit -m "UUID: scaffold module and smoke test"
```

---

## Task 2: UUIDError + Version + Variant enums

**Files:**
- Create: `Sources/UUID/UUIDError.swift`
- Create: `Sources/UUID/UUIDVersion.swift`
- Modify: `Sources/UUID/UUID.swift` (replace placeholder with empty namespace stub)
- Create: `Tests/UUIDTests/UUIDErrorTests.swift`
- Modify: `Tests/UUIDTests/SmokeTest.swift` (replace stale placeholder reference)

- [ ] **Step 1: Write the failing tests**

Create `Tests/UUIDTests/UUIDErrorTests.swift`:

```swift
import Testing
@testable import UUID

@Test func uuidErrorEquality() {
    #expect(UUIDError.invalidFormat == UUIDError.invalidFormat)
    #expect(UUIDError.invalidByteCount(15) == UUIDError.invalidByteCount(15))
    #expect(UUIDError.invalidByteCount(15) != UUIDError.invalidByteCount(17))
    #expect(UUIDError.invalidHexCharacter(offset: 5, byte: 0x40)
            == UUIDError.invalidHexCharacter(offset: 5, byte: 0x40))
    #expect(UUIDError.invalidHexCharacter(offset: 5, byte: 0x40)
            != UUIDError.invalidHexCharacter(offset: 6, byte: 0x40))
}

@Test func versionEnumCases() {
    let all = UUID.Version.allCases
    #expect(all.count == 8)
    #expect(UUID.Version.v1.rawValue == 1)
    #expect(UUID.Version.v8.rawValue == 8)
}

@Test func variantEnumCases() {
    let cases: [UUID.Variant] = [.ncs, .rfc4122, .microsoft, .future]
    #expect(cases.count == 4)
    #expect(UUID.Variant.rfc4122 == .rfc4122)
    #expect(UUID.Variant.rfc4122 != .future)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter UUIDErrorTests`
Expected: compile errors — `UUIDError`, `UUID.Version`, `UUID.Variant` not defined.

- [ ] **Step 3: Implement UUIDError**

Create `Sources/UUID/UUIDError.swift`:

```swift
/// Errors raised by UUID parsing and byte construction.
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

- [ ] **Step 4: Implement the UUID namespace + nested enums**

Replace `Sources/UUID/UUID.swift` with:

```swift
import Bytes

/// A 128-bit universally unique identifier.
///
/// Storage is 16 bytes in network (big-endian) byte order. This file
/// holds the namespace shell; conformances and methods are added in
/// subsequent tasks.
public struct UUID {
    @usableFromInline let storage: SIMD16<UInt8>

    @usableFromInline
    init(storage: SIMD16<UInt8>) {
        self.storage = storage
    }
}
```

Create `Sources/UUID/UUIDVersion.swift`:

```swift
extension UUID {
    /// RFC 4122 / 9562 version (`.v1`...`.v8`).
    public enum Version: Int, Sendable, CaseIterable {
        case v1 = 1, v2 = 2, v3 = 3, v4 = 4, v5 = 5, v6 = 6, v7 = 7, v8 = 8
    }

    /// Layout variant per RFC 4122 §4.1.1.
    public enum Variant: Sendable, Equatable {
        case ncs            // 0xx — Apollo NCS legacy
        case rfc4122        // 10x — RFC 4122 / 9562 (modern standard)
        case microsoft      // 110 — Microsoft GUIDs
        case future         // 111 — reserved
    }
}
```

- [ ] **Step 5: Update the smoke test**

Replace `Tests/UUIDTests/SmokeTest.swift` with:

```swift
import Testing
@testable import UUID

@Test func uuidNamespaceExists() {
    let _: UUID.Version = .v4
    let _: UUID.Variant = .rfc4122
    #expect(true)
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `swift test --filter UUIDTests`
Expected: 4 tests pass (1 smoke + 3 error/version/variant).

- [ ] **Step 7: Commit**

```bash
git add Sources/UUID Tests/UUIDTests
git commit -m "UUID: add namespace, Version/Variant enums, and UUIDError"
```

---

## Task 3: UUID core — constants, Sendable, Hashable, Bytes interop

**Files:**
- Modify: `Sources/UUID/UUID.swift` (add conformances + constants + bytes interop)
- Create: `Tests/UUIDTests/UUIDConstantsTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/UUIDTests/UUIDConstantsTests.swift`:

```swift
import Testing
import Bytes
@testable import UUID

@Test func nilUUIDAllZero() {
    let n = UUID.nil
    #expect(Array(n.bytes) == [UInt8](repeating: 0, count: 16))
}

@Test func maxUUIDAllOnes() {
    let m = UUID.max
    #expect(Array(m.bytes) == [UInt8](repeating: 0xFF, count: 16))
}

@Test func uuidEquatable() {
    #expect(UUID.nil == UUID.nil)
    #expect(UUID.nil != UUID.max)
}

@Test func uuidHashable() {
    var seen: Set<UUID> = []
    seen.insert(.nil)
    seen.insert(.max)
    #expect(seen.contains(.nil))
    #expect(seen.contains(.max))
    #expect(seen.count == 2)
}

@Test func initFromBytesSucceeds() throws {
    let raw: [UInt8] = (0..<16).map { UInt8($0) }
    let u = try UUID(bytes: Bytes(raw))
    #expect(Array(u.bytes) == raw)
}

@Test func initFromSequenceSucceeds() throws {
    let raw: [UInt8] = (0..<16).map { UInt8($0) }
    let u = try UUID(bytes: raw)
    #expect(Array(u.bytes) == raw)
}

@Test func initFromBytesWrongLengthThrows() {
    let short = Bytes([UInt8](repeating: 0, count: 15))
    #expect(throws: UUIDError.invalidByteCount(15)) {
        _ = try UUID(bytes: short)
    }
    let long = Bytes([UInt8](repeating: 0, count: 17))
    #expect(throws: UUIDError.invalidByteCount(17)) {
        _ = try UUID(bytes: long)
    }
}

@Test func initFromSequenceWrongLengthThrows() {
    let short: [UInt8] = [0, 1, 2]
    #expect(throws: UUIDError.invalidByteCount(3)) {
        _ = try UUID(bytes: short)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter UUIDConstantsTests`
Expected: compile errors — `UUID.nil`, `UUID.max`, `init(bytes:)`, `bytes`, `Hashable` not yet implemented.

- [ ] **Step 3: Add conformances, constants, and Bytes interop**

Replace `Sources/UUID/UUID.swift` with:

```swift
import Bytes

/// A 128-bit universally unique identifier.
///
/// Storage is 16 bytes in network (big-endian) byte order, exposed as
/// `bytes`. Use `description` for canonical lowercase string form.
public struct UUID: Sendable, Hashable {
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
    public init(bytes: Bytes) throws {
        guard bytes.count == 16 else {
            throw UUIDError.invalidByteCount(bytes.count)
        }
        var s = SIMD16<UInt8>()
        bytes.withUnsafeBytes { src in
            for i in 0..<16 { s[i] = src[i] }
        }
        self.storage = s
    }

    /// Construct from any 16-element UInt8 sequence.
    public init<S: Sequence>(bytes: S) throws where S.Element == UInt8 {
        let arr = Array(bytes)
        guard arr.count == 16 else {
            throw UUIDError.invalidByteCount(arr.count)
        }
        var s = SIMD16<UInt8>()
        for i in 0..<16 { s[i] = arr[i] }
        self.storage = s
    }

    /// 16 bytes in network byte order.
    public var bytes: Bytes {
        var arr: [UInt8] = []
        arr.reserveCapacity(16)
        for i in 0..<16 { arr.append(storage[i]) }
        return Bytes(arr)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter UUIDConstantsTests`
Expected: all 8 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/UUID/UUID.swift Tests/UUIDTests/UUIDConstantsTests.swift
git commit -m "UUID: add nil/max constants, Hashable, and Bytes interop"
```

---

## Task 4: Inspection (version + variant) + Comparable

**Files:**
- Modify: `Sources/UUID/UUID.swift` (add Comparable conformance)
- Create: `Sources/UUID/UUIDInspect.swift`
- Create: `Tests/UUIDTests/UUIDInspectTests.swift`
- Create: `Tests/UUIDTests/UUIDOrderingTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/UUIDTests/UUIDInspectTests.swift`:

```swift
import Testing
import Bytes
@testable import UUID

/// Build a UUID with a specific byte 6 (version) and byte 8 (variant)
/// using the bytes-init. The other bytes are zero.
private func make(version v: UInt8, variant b8: UInt8) throws -> UUID {
    var raw = [UInt8](repeating: 0, count: 16)
    raw[6] = v
    raw[8] = b8
    return try UUID(bytes: raw)
}

@Test func nilUUIDVariantIsNCS() {
    #expect(UUID.nil.variant == .ncs)
    #expect(UUID.nil.version == nil)   // version meaningful only for rfc4122
}

@Test func maxUUIDVariantIsFuture() {
    #expect(UUID.max.variant == .future)
    #expect(UUID.max.version == nil)
}

@Test func variantNCSDetected() throws {
    // Top bit 0 → NCS. Use 0x00, 0x40 (covers 0xx range).
    let a = try make(version: 0x00, variant: 0x00)  // 000xxxxx
    let b = try make(version: 0x00, variant: 0x40)  // 010xxxxx
    #expect(a.variant == .ncs)
    #expect(b.variant == .ncs)
}

@Test func variantRFC4122Detected() throws {
    // Top two bits 10 → RFC 4122. Test 0x80 (100xxxxx) and 0xA0 (101xxxxx).
    let a = try make(version: 0x40, variant: 0x80)
    let b = try make(version: 0x40, variant: 0xA0)
    #expect(a.variant == .rfc4122)
    #expect(b.variant == .rfc4122)
}

@Test func variantMicrosoftDetected() throws {
    // Top three bits 110 → Microsoft. 0xC0 = 11000000.
    let u = try make(version: 0x40, variant: 0xC0)
    #expect(u.variant == .microsoft)
}

@Test func variantFutureDetected() throws {
    // Top three bits 111 → future. 0xE0 = 11100000.
    let u = try make(version: 0x40, variant: 0xE0)
    #expect(u.variant == .future)
}

@Test func versionV1ThroughV8Detected() throws {
    for v in 1...8 {
        let u = try make(version: UInt8(v << 4), variant: 0x80)
        #expect(u.version == UUID.Version(rawValue: v))
    }
}

@Test func versionNilForNonRFC4122() throws {
    // Version field would be 4 (0x40) but variant is NCS (0x00).
    let u = try make(version: 0x40, variant: 0x00)
    #expect(u.version == nil)
}

@Test func versionRawValuesMatchWireBits() {
    // Sanity: rawValue 1 → wire bits 0001, etc.
    #expect(UUID.Version.v1.rawValue == 1)
    #expect(UUID.Version.v4.rawValue == 4)
    #expect(UUID.Version.v7.rawValue == 7)
    #expect(UUID.Version.v8.rawValue == 8)
}
```

Create `Tests/UUIDTests/UUIDOrderingTests.swift`:

```swift
import Testing
import Bytes
@testable import UUID

@Test func nilSortsBeforeAnything() throws {
    let u = try UUID(bytes: [UInt8](repeating: 1, count: 16))
    #expect(UUID.nil < u)
    #expect(!(u < UUID.nil))
}

@Test func maxSortsAfterAnything() throws {
    let u = try UUID(bytes: [UInt8](repeating: 1, count: 16))
    #expect(u < UUID.max)
    #expect(!(UUID.max < u))
}

@Test func equalUUIDsAreNotLess() {
    #expect(!(UUID.nil < UUID.nil))
    #expect(!(UUID.max < UUID.max))
}

@Test func lexicographicOrder() throws {
    var a = [UInt8](repeating: 0, count: 16); a[0] = 0x01
    var b = [UInt8](repeating: 0, count: 16); b[0] = 0x02
    let ua = try UUID(bytes: a)
    let ub = try UUID(bytes: b)
    #expect(ua < ub)
}

@Test func lateBytesBreakTiesAfterEarlyEqual() throws {
    var a = [UInt8](repeating: 0xAA, count: 16)
    var b = [UInt8](repeating: 0xAA, count: 16)
    a[15] = 0x01
    b[15] = 0x02
    let ua = try UUID(bytes: a)
    let ub = try UUID(bytes: b)
    #expect(ua < ub)
}

@Test func equalHashesAreEqual() {
    #expect(UUID.nil.hashValue == UUID.nil.hashValue)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter UUIDInspectTests`
Run: `swift test --filter UUIDOrderingTests`
Expected: compile errors — `version`, `variant`, `Comparable` not yet implemented.

- [ ] **Step 3: Add Comparable to UUID.swift**

In `Sources/UUID/UUID.swift`, change the type declaration line from:

```swift
public struct UUID: Sendable, Hashable {
```

to:

```swift
public struct UUID: Sendable, Hashable, Comparable {
```

Then append this extension at the end of the file (after the closing `}` of the struct):

```swift
extension UUID {
    /// Lexicographic byte-wise comparison. Sorts v7 UUIDs in timestamp order.
    public static func < (lhs: UUID, rhs: UUID) -> Bool {
        for i in 0..<16 {
            if lhs.storage[i] != rhs.storage[i] {
                return lhs.storage[i] < rhs.storage[i]
            }
        }
        return false
    }
}
```

- [ ] **Step 4: Implement inspection**

Create `Sources/UUID/UUIDInspect.swift`:

```swift
extension UUID {
    /// RFC 4122 / 9562 version (`.v1`...`.v8`). `nil` when the variant
    /// isn't `.rfc4122` (the version field has no defined meaning then).
    public var version: Version? {
        guard variant == .rfc4122 else { return nil }
        let v = (storage[6] >> 4) & 0x0F
        return Version(rawValue: Int(v))
    }

    /// Layout variant per RFC 4122 §4.1.1.
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

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter UUIDTests`
Expected: all UUID tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/UUID Tests/UUIDTests/UUIDInspectTests.swift Tests/UUIDTests/UUIDOrderingTests.swift
git commit -m "UUID: add version/variant inspection and Comparable byte-wise ordering"
```

---

## Task 5: Format + LosslessStringConvertible

**Files:**
- Create: `Sources/UUID/UUIDFormat.swift`
- Create: `Tests/UUIDTests/UUIDFormatTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/UUIDTests/UUIDFormatTests.swift`:

```swift
import Testing
import Bytes
@testable import UUID

@Test func descriptionIsCanonicalLowercase() throws {
    let raw: [UInt8] = [
        0x55, 0x0e, 0x84, 0x00, 0xe2, 0x9b, 0x41, 0xd4,
        0xa7, 0x16, 0x44, 0x66, 0x55, 0x44, 0x00, 0x00,
    ]
    let u = try UUID(bytes: raw)
    #expect(u.description == "550e8400-e29b-41d4-a716-446655440000")
    #expect(u.description.count == 36)
}

@Test func nilDescription() {
    #expect(UUID.nil.description == "00000000-0000-0000-0000-000000000000")
}

@Test func formattedCanonicalUpper() throws {
    let raw: [UInt8] = [
        0x55, 0x0e, 0x84, 0x00, 0xe2, 0x9b, 0x41, 0xd4,
        0xa7, 0x16, 0x44, 0x66, 0x55, 0x44, 0x00, 0x00,
    ]
    let u = try UUID(bytes: raw)
    #expect(u.formatted(.canonicalUpper) == "550E8400-E29B-41D4-A716-446655440000")
}

@Test func formattedHyphenless() throws {
    let raw: [UInt8] = [
        0x55, 0x0e, 0x84, 0x00, 0xe2, 0x9b, 0x41, 0xd4,
        0xa7, 0x16, 0x44, 0x66, 0x55, 0x44, 0x00, 0x00,
    ]
    let u = try UUID(bytes: raw)
    let s = u.formatted(.hyphenless)
    #expect(s == "550e8400e29b41d4a716446655440000")
    #expect(s.count == 32)
    #expect(!s.contains("-"))
}

@Test func formattedBraced() throws {
    let u = UUID.nil
    let s = u.formatted(.braced)
    #expect(s == "{00000000-0000-0000-0000-000000000000}")
    #expect(s.hasPrefix("{"))
    #expect(s.hasSuffix("}"))
}

@Test func formattedURN() throws {
    let u = UUID.nil
    let s = u.formatted(.urn)
    #expect(s == "urn:uuid:00000000-0000-0000-0000-000000000000")
    #expect(s.hasPrefix("urn:uuid:"))
}

@Test func losslessInitAcceptsCanonicalLowercase() {
    let s = "550e8400-e29b-41d4-a716-446655440000"
    let u = UUID(s)
    #expect(u != nil)
    #expect(u?.description == s)
}

@Test func losslessInitRejectsUppercase() {
    let s = "550E8400-E29B-41D4-A716-446655440000"
    #expect(UUID(s) == nil)
}

@Test func losslessInitRejectsBracesAndURN() {
    #expect(UUID("{550e8400-e29b-41d4-a716-446655440000}") == nil)
    #expect(UUID("urn:uuid:550e8400-e29b-41d4-a716-446655440000") == nil)
    #expect(UUID("550e8400e29b41d4a716446655440000") == nil)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter UUIDFormatTests`
Expected: compile errors — `description`, `formatted`, `init?(_:)` not defined; `Format` enum missing.

- [ ] **Step 3: Implement Format**

Create `Sources/UUID/UUIDFormat.swift`:

```swift
extension UUID: CustomStringConvertible, LosslessStringConvertible {

    /// Canonical lowercase: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`.
    public var description: String { formatted(.canonicalLower) }

    /// Lossless init: accepts canonical lowercase only — for round-trip
    /// from `description`. Use `init(_:)` for permissive parsing.
    public init?(_ description: String) {
        guard description.utf8.count == 36 else { return nil }
        let utf8 = Array(description.utf8)
        // Reject uppercase hex so description.init?(_:) round-trips.
        for b in utf8 where (0x41...0x46).contains(b) { return nil }
        // Validate hyphens at the four canonical positions.
        guard utf8[8] == 0x2D && utf8[13] == 0x2D
           && utf8[18] == 0x2D && utf8[23] == 0x2D
        else { return nil }
        var s = SIMD16<UInt8>()
        var byteIdx = 0
        var i = 0
        while i < 36 {
            if utf8[i] == 0x2D { i += 1; continue }
            let hi = Self.decodeNibble(utf8[i])
            let lo = Self.decodeNibble(utf8[i + 1])
            if hi == 0xFF || lo == 0xFF { return nil }
            s[byteIdx] = (hi << 4) | lo
            byteIdx += 1
            i += 2
        }
        self.init(storage: s)
    }

    /// Output format options.
    public enum Format: Sendable {
        case canonicalLower    // 550e8400-e29b-41d4-a716-446655440000
        case canonicalUpper    // 550E8400-E29B-41D4-A716-446655440000
        case hyphenless        // 550e8400e29b41d4a716446655440000
        case braced            // {550e8400-e29b-41d4-a716-446655440000}
        case urn               // urn:uuid:550e8400-e29b-41d4-a716-446655440000
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

    /// Internal nibble decoder shared with the permissive parser. Returns
    /// 0xFF for non-hex input. Duplicated in spirit from the Hex module —
    /// see spec §6.1 for the rationale (no peer Layer 1 imports).
    @inline(__always)
    static func decodeNibble(_ b: UInt8) -> UInt8 {
        switch b {
        case 0x30...0x39: return b - 0x30
        case 0x41...0x46: return b - 0x41 + 10
        case 0x61...0x66: return b - 0x61 + 10
        default:          return 0xFF
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter UUIDFormatTests`
Expected: all 9 format tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/UUID/UUIDFormat.swift Tests/UUIDTests/UUIDFormatTests.swift
git commit -m "UUID: add Format enum, formatted(), description, lossless init"
```

---

## Task 6: Permissive parse

**Files:**
- Create: `Sources/UUID/UUIDParse.swift`
- Create: `Tests/UUIDTests/UUIDParseTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/UUIDTests/UUIDParseTests.swift`:

```swift
import Testing
import Bytes
@testable import UUID

@Test func parseCanonicalLowercase() throws {
    let u = try UUID("550e8400-e29b-41d4-a716-446655440000")
    #expect(u.description == "550e8400-e29b-41d4-a716-446655440000")
}

@Test func parseCanonicalUppercase() throws {
    let u = try UUID("550E8400-E29B-41D4-A716-446655440000")
    #expect(u.description == "550e8400-e29b-41d4-a716-446655440000")
}

@Test func parseCanonicalMixedCase() throws {
    let u = try UUID("550e8400-E29B-41d4-a716-446655440000")
    #expect(u.description == "550e8400-e29b-41d4-a716-446655440000")
}

@Test func parseBraced() throws {
    let u = try UUID("{550e8400-e29b-41d4-a716-446655440000}")
    #expect(u.description == "550e8400-e29b-41d4-a716-446655440000")
}

@Test func parseURN() throws {
    let u = try UUID("urn:uuid:550e8400-e29b-41d4-a716-446655440000")
    #expect(u.description == "550e8400-e29b-41d4-a716-446655440000")
}

@Test func parseURNCaseInsensitivePrefix() throws {
    let u = try UUID("URN:UUID:550e8400-e29b-41d4-a716-446655440000")
    #expect(u.description == "550e8400-e29b-41d4-a716-446655440000")
}

@Test func parseHyphenless() throws {
    let u = try UUID("550e8400e29b41d4a716446655440000")
    #expect(u.description == "550e8400-e29b-41d4-a716-446655440000")
}

@Test func parseWrongLengthThrows() {
    #expect(throws: UUIDError.invalidFormat) {
        _ = try UUID("550e8400-e29b-41d4-a716-44665544000")  // 35 chars
    }
    #expect(throws: UUIDError.invalidFormat) {
        _ = try UUID("550e8400-e29b-41d4-a716-4466554400000") // 37 chars
    }
}

@Test func parseMissingHyphenThrows() {
    // Replace one hyphen with a hex digit to keep length 36.
    #expect(throws: UUIDError.invalidFormat) {
        _ = try UUID("550e8400xe29b-41d4-a716-446655440000")
    }
}

@Test func parseInvalidHexCharacterThrows() {
    // '@' = 0x40 at offset 0.
    #expect(throws: UUIDError.invalidHexCharacter(offset: 0, byte: 0x40)) {
        _ = try UUID("@50e8400-e29b-41d4-a716-446655440000")
    }
}

@Test func parseInvalidHexInHyphenless() {
    // 'g' = 0x67 at offset 0.
    #expect(throws: UUIDError.invalidHexCharacter(offset: 0, byte: 0x67)) {
        _ = try UUID("g50e8400e29b41d4a716446655440000")
    }
}

@Test func parseRoundTripsThroughBytes() throws {
    let original = "550e8400-e29b-41d4-a716-446655440000"
    let u = try UUID(original)
    let backFromBytes = try UUID(bytes: u.bytes)
    #expect(backFromBytes.description == original)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter UUIDParseTests`
Expected: compile errors — `init(_:) throws` not defined.

- [ ] **Step 3: Implement parsing**

Create `Sources/UUID/UUIDParse.swift`:

```swift
extension UUID {

    /// Permissive parse: accepts canonical, braces, urn:uuid: prefix,
    /// and 32-char hyphenless. Hex case-insensitive. Throws on any
    /// other shape.
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
            let hi = Self.decodeNibble(utf8[i])
            let lo = Self.decodeNibble(utf8[i + 1])
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
            let hi = Self.decodeNibble(utf8[i])
            let lo = Self.decodeNibble(utf8[i + 1])
            if hi == 0xFF { throw UUIDError.invalidHexCharacter(offset: i, byte: utf8[i]) }
            if lo == 0xFF { throw UUIDError.invalidHexCharacter(offset: i + 1, byte: utf8[i + 1]) }
            out[byteIdx] = (hi << 4) | lo
            byteIdx += 1
            i += 2
        }
        return out
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter UUIDParseTests`
Expected: all 12 parse tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/UUID/UUIDParse.swift Tests/UUIDTests/UUIDParseTests.swift
git commit -m "UUID: add permissive parser (canonical/braces/URN/hyphenless)"
```

---

## Task 7: WallClock shim

**Files:**
- Create: `Sources/UUID/Internal/WallClock.swift`
- (No tests — internal utility tested indirectly via v7 in Task 9)

- [ ] **Step 1: Implement the shim**

Create `Sources/UUID/Internal/WallClock.swift`:

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

- [ ] **Step 2: Verify it builds**

Run: `swift build`
Expected: build succeeds; no warnings.

- [ ] **Step 3: Quick smoke test from the test target**

Append to `Tests/UUIDTests/SmokeTest.swift`:

```swift
@Test func wallClockReturnsRecentTimestamp() {
    let ms = unixWallClockMilliseconds()
    // Sanity: should be a recent timestamp (after Jan 1, 2020 UTC).
    let jan2020Ms: Int64 = 1577836800000
    #expect(ms > jan2020Ms)
}
```

- [ ] **Step 4: Run tests**

Run: `swift test --filter UUIDTests`
Expected: all tests pass including the new smoke test.

- [ ] **Step 5: Commit**

```bash
git add Sources/UUID/Internal/WallClock.swift Tests/UUIDTests/SmokeTest.swift
git commit -m "UUID: add wall-clock shim (clock_gettime / GetSystemTimePreciseAsFileTime)"
```

---

## Task 8: v4 generator

**Files:**
- Create: `Sources/UUID/UUIDGenerate.swift`
- Create: `Tests/UUIDTests/UUIDGenerateTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/UUIDTests/UUIDGenerateTests.swift`:

```swift
import Testing
import Bytes
@testable import UUID

/// Deterministic RNG for repeatable tests.
struct DeterministicRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

@Test func v4HasVersion4AndRfc4122Variant() {
    let u = UUID.v4()
    #expect(u.version == .v4)
    #expect(u.variant == .rfc4122)
}

@Test func v4WithDeterministicRNGIsRepeatable() {
    var rngA = DeterministicRNG(seed: 42)
    var rngB = DeterministicRNG(seed: 42)
    let a = UUID.v4(using: &rngA)
    let b = UUID.v4(using: &rngB)
    #expect(a == b)
}

@Test func v4DifferentSeedsProduceDifferentUUIDs() {
    var rngA = DeterministicRNG(seed: 42)
    var rngB = DeterministicRNG(seed: 43)
    let a = UUID.v4(using: &rngA)
    let b = UUID.v4(using: &rngB)
    #expect(a != b)
}

@Test func v41000UniqueSmoke() {
    var seen: Set<UUID> = []
    for _ in 0..<1000 { seen.insert(UUID.v4()) }
    #expect(seen.count == 1000)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter UUIDGenerateTests`
Expected: compile errors — `UUID.v4` not defined.

- [ ] **Step 3: Implement v4**

Create `Sources/UUID/UUIDGenerate.swift`:

```swift
import Bytes

extension UUID {

    /// Random v4 UUID using `SystemRandomNumberGenerator`.
    public static func v4() -> UUID {
        var rng = SystemRandomNumberGenerator()
        return v4(using: &rng)
    }

    /// Random v4 UUID using a caller-provided RNG.
    public static func v4<R: RandomNumberGenerator>(using rng: inout R) -> UUID {
        var s = SIMD16<UInt8>()
        let lo: UInt64 = rng.next()
        let hi: UInt64 = rng.next()
        withUnsafeMutableBytes(of: &s) { dst in
            dst.storeBytes(of: lo, toByteOffset: 0, as: UInt64.self)
            dst.storeBytes(of: hi, toByteOffset: 8, as: UInt64.self)
        }
        s[6] = (s[6] & 0x0F) | 0x40    // version 4 = 0100xxxx
        s[8] = (s[8] & 0x3F) | 0x80    // variant 10x
        return UUID(storage: s)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter UUIDGenerateTests`
Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/UUID/UUIDGenerate.swift Tests/UUIDTests/UUIDGenerateTests.swift
git commit -m "UUID: add v4 generator (system + injectable RNG)"
```

---

## Task 9: v7 generator

**Files:**
- Modify: `Sources/UUID/UUIDGenerate.swift` (append v7)
- Modify: `Tests/UUIDTests/UUIDGenerateTests.swift` (append v7 tests)

- [ ] **Step 1: Append the failing tests**

Append to `Tests/UUIDTests/UUIDGenerateTests.swift`:

```swift
@Test func v7HasVersion7AndRfc4122Variant() {
    let u = UUID.v7()
    #expect(u.version == .v7)
    #expect(u.variant == .rfc4122)
}

@Test func v7TimestampIsInFirst6Bytes() {
    let ms: Int64 = 0x0000_0192_4F1B_7E3A  // arbitrary 48-bit timestamp
    var rng = DeterministicRNG(seed: 7)
    let u = UUID.v7(unixMillisecondsSince1970: ms, using: &rng)
    let bytes = Array(u.bytes)
    let recovered: Int64 =
        (Int64(bytes[0]) << 40) |
        (Int64(bytes[1]) << 32) |
        (Int64(bytes[2]) << 24) |
        (Int64(bytes[3]) << 16) |
        (Int64(bytes[4]) <<  8) |
         Int64(bytes[5])
    #expect(recovered == ms)
}

@Test func v7VersionAndVariantStamped() {
    var rng = DeterministicRNG(seed: 13)
    let u = UUID.v7(unixMillisecondsSince1970: 0, using: &rng)
    let bytes = Array(u.bytes)
    #expect((bytes[6] >> 4) == 0x7)         // version 7
    #expect((bytes[8] >> 6) == 0b10)        // variant 10
}

@Test func v7NoArgUsesCurrentWallClock() {
    let before = unixWallClockMilliseconds()
    let u = UUID.v7()
    let after = unixWallClockMilliseconds()
    let bytes = Array(u.bytes)
    let ms: Int64 =
        (Int64(bytes[0]) << 40) |
        (Int64(bytes[1]) << 32) |
        (Int64(bytes[2]) << 24) |
        (Int64(bytes[3]) << 16) |
        (Int64(bytes[4]) <<  8) |
         Int64(bytes[5])
    // Allow 1s of slack on either side for slow CI.
    #expect(ms >= before - 1000)
    #expect(ms <= after + 1000)
}

@Test func v7sInIncreasingMsSortInOrder() {
    var rng = DeterministicRNG(seed: 99)
    let a = UUID.v7(unixMillisecondsSince1970: 1_000_000, using: &rng)
    let b = UUID.v7(unixMillisecondsSince1970: 2_000_000, using: &rng)
    let c = UUID.v7(unixMillisecondsSince1970: 3_000_000, using: &rng)
    #expect(a < b)
    #expect(b < c)
    #expect(a < c)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter UUIDGenerateTests`
Expected: compile errors — `UUID.v7` not defined.

- [ ] **Step 3: Append v7 to UUIDGenerate.swift**

Append to `Sources/UUID/UUIDGenerate.swift`:

```swift
extension UUID {

    /// Time-sortable v7 UUID: 48-bit Unix milliseconds + 74 random bits
    /// (RFC 9562 §5.7). Uses the wall-clock shim and `SystemRandomNumberGenerator`.
    public static func v7() -> UUID {
        var rng = SystemRandomNumberGenerator()
        return v7(unixMillisecondsSince1970: unixWallClockMilliseconds(), using: &rng)
    }

    /// v7 with caller-provided clock and RNG.
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
        s[6] = (s[6] & 0x0F) | 0x70    // version 7 = 0111xxxx
        s[8] = (s[8] & 0x3F) | 0x80    // variant 10x
        return UUID(storage: s)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter UUIDGenerateTests`
Expected: 9 tests pass (4 v4 + 5 v7).

- [ ] **Step 5: Commit**

```bash
git add Sources/UUID/UUIDGenerate.swift Tests/UUIDTests/UUIDGenerateTests.swift
git commit -m "UUID: add v7 generator (Unix ms + random tail per RFC 9562)"
```

---

## Task 10: v8 generator

**Files:**
- Modify: `Sources/UUID/UUIDGenerate.swift` (append v8)
- Modify: `Tests/UUIDTests/UUIDGenerateTests.swift` (append v8 tests)

- [ ] **Step 1: Append the failing tests**

Append to `Tests/UUIDTests/UUIDGenerateTests.swift`:

```swift
@Test func v8HasVersion8AndRfc4122Variant() throws {
    let raw = [UInt8](repeating: 0xAA, count: 16)
    let u = try UUID.v8(bytes: Bytes(raw))
    #expect(u.version == .v8)
    #expect(u.variant == .rfc4122)
}

@Test func v8PreservesCallerBytesExceptVersionAndVariant() throws {
    let raw = [UInt8](repeating: 0xAA, count: 16)
    let u = try UUID.v8(bytes: Bytes(raw))
    let out = Array(u.bytes)
    // Bytes 0-5, 7, 9-15 unchanged.
    for i in [0, 1, 2, 3, 4, 5, 7, 9, 10, 11, 12, 13, 14, 15] {
        #expect(out[i] == 0xAA, "byte \(i) should be 0xAA, got \(out[i])")
    }
    // Byte 6: low nibble preserved (0xA), high nibble = 8.
    #expect(out[6] == 0x8A)
    // Byte 8: low 6 bits preserved (0b101010 = 0x2A), top two bits = 0b10.
    #expect(out[8] == 0xAA)  // 0b10101010 — high two bits already were 10
}

@Test func v8VersionStampOverwritesHighNibbleOfByte6() throws {
    var raw = [UInt8](repeating: 0, count: 16)
    raw[6] = 0xFF  // expect high nibble to become 8, low nibble to stay F
    let u = try UUID.v8(bytes: Bytes(raw))
    let out = Array(u.bytes)
    #expect(out[6] == 0x8F)
}

@Test func v8VariantStampOverwritesTopTwoBitsOfByte8() throws {
    var raw = [UInt8](repeating: 0, count: 16)
    raw[8] = 0xFF  // expect top two bits to become 10, low 6 bits stay 1
    let u = try UUID.v8(bytes: Bytes(raw))
    let out = Array(u.bytes)
    // 0xFF & 0x3F = 0x3F; 0x3F | 0x80 = 0xBF
    #expect(out[8] == 0xBF)
}

@Test func v8WrongLengthThrows() {
    let short = Bytes([UInt8](repeating: 0, count: 15))
    #expect(throws: UUIDError.invalidByteCount(15)) {
        _ = try UUID.v8(bytes: short)
    }
    let long = Bytes([UInt8](repeating: 0, count: 17))
    #expect(throws: UUIDError.invalidByteCount(17)) {
        _ = try UUID.v8(bytes: long)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter UUIDGenerateTests`
Expected: compile errors — `UUID.v8` not defined.

- [ ] **Step 3: Append v8 to UUIDGenerate.swift**

Append to `Sources/UUID/UUIDGenerate.swift`:

```swift
extension UUID {

    /// Custom v8 UUID. The provided 16 bytes are stored verbatim except
    /// for the version field (byte 6 high nibble = 8) and variant field
    /// (byte 8 high two bits = 10) per RFC 9562 §5.8 — the application
    /// owns the remaining 122 bits.
    public static func v8(bytes: Bytes) throws -> UUID {
        guard bytes.count == 16 else {
            throw UUIDError.invalidByteCount(bytes.count)
        }
        var s = SIMD16<UInt8>()
        bytes.withUnsafeBytes { src in
            for i in 0..<16 { s[i] = src[i] }
        }
        s[6] = (s[6] & 0x0F) | 0x80    // version 8 = 1000xxxx
        s[8] = (s[8] & 0x3F) | 0x80    // variant 10x
        return UUID(storage: s)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter UUIDGenerateTests`
Expected: 14 tests pass (4 v4 + 5 v7 + 5 v8).

- [ ] **Step 5: Commit**

```bash
git add Sources/UUID/UUIDGenerate.swift Tests/UUIDTests/UUIDGenerateTests.swift
git commit -m "UUID: add v8 generator (custom payload with version/variant stamp)"
```

---

## Task 11: Final verification + cross-link Layer 1 doc + push

**Files:**
- Modify: `layers/layer-01-primitives.md` (update status banner)

- [ ] **Step 1: Run the full suite on a clean build**

```bash
swift package clean
swift test
```

Expected: every test passes. Total ≈ 200 tests.

- [ ] **Step 2: Check coverage**

```bash
swift test --enable-code-coverage
COV_BIN=$(swift build --show-bin-path)
xcrun llvm-cov report \
    "$COV_BIN/BedrockPackageTests.xctest/Contents/MacOS/BedrockPackageTests" \
    -instr-profile "$COV_BIN/codecov/default.profdata" \
    Sources/UUID
```

Expected: coverage on `Sources/UUID/` ≥ 90%. **Report the table.** If a file is below 90%, identify the gap and add a single targeted test.

- [ ] **Step 3: Verify release build**

Run: `swift build -c release`
Expected: build succeeds with no errors or new warnings.

- [ ] **Step 4: Update the Layer 1 status banner**

Open `layers/layer-01-primitives.md`. Find the existing status banner (it currently lists Bytes, Hex, Base64). Replace the `Status:` block with:

```markdown
> **Status:** shipping modules:
> - `Sources/Bytes/` — core bytes ([design](../docs/superpowers/specs/2026-05-09-bytes-design.md), [plan](../docs/superpowers/plans/2026-05-09-bytes-module.md))
> - `Sources/Hex/` — hex codec ([design](../docs/superpowers/specs/2026-05-10-hex-base64-design.md), [plan](../docs/superpowers/plans/2026-05-10-hex-base64-modules.md))
> - `Sources/Base64/` — base64 codec, including constant-time decode ([same design + plan](../docs/superpowers/specs/2026-05-10-hex-base64-design.md))
> - `Sources/UUID/` — UUID type with v4/v7/v8 generation; v1/v3/v5/v6 parse/inspect work, generation deferred to follow-up patches when Layer 8 (MAC) and Layer 12 (MD5/SHA-1) ship ([design](../docs/superpowers/specs/2026-05-10-uuid-design.md), [plan](../docs/superpowers/plans/2026-05-10-uuid-module.md))
>
> Remaining categories (varints, BitSet, percent encoding, SIMD UTF-8, COBS, URL/IDNA) pending their own designs.
```

- [ ] **Step 5: Commit and push**

```bash
git add layers/layer-01-primitives.md
git commit -m "UUID: cross-link Layer 1 doc to UUID module design+plan"
git push origin main
```

Expected: push succeeds; ~12 commits added since the spec.
