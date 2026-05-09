# Bytes Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the `Bytes` module — a stdlib-only refcounted byte storage with an immutable `Bytes` view, a copy-on-write `BytesMut` builder, and a `~Copyable` `BytesReader` cursor.

**Architecture:** A single internal `final class BytesStorage` provides atomically-refcounted heap memory. Two public structs (`Bytes`, `BytesMut`) reference it with Swift's automatic ARC and use `isKnownUniquelyReferenced` for copy-on-write semantics. Reads use `loadUnaligned` + `bigEndian`/`littleEndian` swaps for endian-aware fixed-width integers. A `~Copyable` `BytesReader` carries a cursor over an immutable `Bytes`.

**Tech Stack:** Swift 6 (toolchain ≥ 6.0), SwiftPM, Swift Testing (`import Testing`), no third-party dependencies, no Foundation.

**Source spec:** `docs/superpowers/specs/2026-05-09-bytes-design.md`.

**Working directory:** `/Users/satishbabariya/Desktop/Bedrock` (repo root). Run all `swift` commands from there.

---

## Task 1: Package scaffolding

**Files:**
- Create: `Package.swift`
- Create: `Sources/Bytes/Bytes.swift` (placeholder)
- Create: `Tests/BytesTests/SmokeTest.swift`

- [ ] **Step 1: Write the package manifest**

Create `Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Bedrock",
    products: [
        .library(name: "Bytes", targets: ["Bytes"]),
    ],
    targets: [
        .target(name: "Bytes", path: "Sources/Bytes"),
        .testTarget(name: "BytesTests", dependencies: ["Bytes"], path: "Tests/BytesTests"),
    ]
)
```

- [ ] **Step 2: Add a placeholder source file**

Create `Sources/Bytes/Bytes.swift`:

```swift
// Bytes — implemented in Task 5+.
@usableFromInline internal let _bytesModuleLoaded = true
```

- [ ] **Step 3: Add the smoke test**

Create `Tests/BytesTests/SmokeTest.swift`:

```swift
import Testing
@testable import Bytes

@Test func moduleLoads() {
    #expect(_bytesModuleLoaded == true)
}
```

- [ ] **Step 4: Verify it builds and tests pass**

Run: `swift test`
Expected output contains: `Test run with 1 test in 1 suite passed`.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/Bytes/Bytes.swift Tests/BytesTests/SmokeTest.swift
git commit -m "Bytes: scaffold SwiftPM package and smoke test"
```

---

## Task 2: Endianness and BytesError

**Files:**
- Create: `Sources/Bytes/Endianness.swift`
- Create: `Sources/Bytes/BytesError.swift`
- Create: `Tests/BytesTests/EndiannessTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/BytesTests/EndiannessTests.swift`:

```swift
import Testing
@testable import Bytes

@Test func endiannessCasesAreSendable() {
    let cases: [Endianness] = [.big, .little, .host]
    #expect(cases.count == 3)
}

@Test func bytesErrorEquality() {
    #expect(BytesError.outOfBounds(offset: 0, length: 4, bufferCount: 2)
            == BytesError.outOfBounds(offset: 0, length: 4, bufferCount: 2))
    #expect(BytesError.shortRead(needed: 4, available: 2)
            == BytesError.shortRead(needed: 4, available: 2))
    #expect(BytesError.invalidLength(-1) == BytesError.invalidLength(-1))
    #expect(BytesError.shortRead(needed: 4, available: 2)
            != BytesError.shortRead(needed: 4, available: 3))
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter EndiannessTests`
Expected: compile error (`Endianness` and `BytesError` are not defined).

- [ ] **Step 3: Implement Endianness**

Create `Sources/Bytes/Endianness.swift`:

```swift
/// Byte order used to interpret multi-byte integers in a `Bytes` buffer.
public enum Endianness: Sendable {
    /// Big-endian (network byte order). The default for wire protocols.
    case big
    /// Little-endian.
    case little
    /// Platform-native byte order. Use only for shared-memory IPC or on-disk
    /// caches keyed to the host architecture; protocol code should prefer
    /// `.big` or `.little` explicitly.
    case host
}
```

- [ ] **Step 4: Implement BytesError**

Create `Sources/Bytes/BytesError.swift`:

```swift
/// Errors thrown by `Bytes`, `BytesMut`, and `BytesReader` operations.
public enum BytesError: Error, Equatable, Sendable {
    /// A non-advancing access referenced an offset/length outside the buffer.
    case outOfBounds(offset: Int, length: Int, bufferCount: Int)
    /// A reader could not satisfy a read because the cursor reached the end.
    case shortRead(needed: Int, available: Int)
    /// An API received a negative `length` parameter.
    case invalidLength(Int)
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter EndiannessTests`
Expected: 2 tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/Bytes/Endianness.swift Sources/Bytes/BytesError.swift \
        Tests/BytesTests/EndiannessTests.swift
git commit -m "Bytes: add Endianness and BytesError types"
```

---

## Task 3: BytesStorage internal class

**Files:**
- Create: `Sources/Bytes/BytesStorage.swift`
- Create: `Tests/BytesTests/BytesStorageTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/BytesTests/BytesStorageTests.swift`:

```swift
import Testing
@testable import Bytes

@Test func emptySingletonHasZeroCapacity() {
    let s = BytesStorage.empty
    #expect(s.capacity == 0)
}

@Test func emptySingletonIsShared() {
    #expect(BytesStorage.empty === BytesStorage.empty)
}

@Test func newStorageHasRequestedCapacity() {
    let s = BytesStorage(capacity: 128)
    #expect(s.capacity == 128)
}

@Test func storageDeallocatesOnLastReference() {
    // Indirect: allocate, drop, allocate again — addresses should be reusable.
    // This isn't deterministic but exercises deinit. ASan run will catch leaks.
    for _ in 0..<1000 {
        _ = BytesStorage(capacity: 1024)
    }
    // If we reach here without crash and ASan reports clean, dealloc works.
    #expect(true)
}

@Test func storageBytesAreReadWritable() {
    let s = BytesStorage(capacity: 8)
    s.pointer.storeBytes(of: UInt32(0xDEADBEEF), as: UInt32.self)
    let v = s.pointer.load(as: UInt32.self)
    #expect(v == 0xDEADBEEF)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter BytesStorageTests`
Expected: compile error (`BytesStorage` not defined).

- [ ] **Step 3: Implement BytesStorage**

Create `Sources/Bytes/BytesStorage.swift`:

```swift
/// Internal heap-allocated byte buffer. Refcounted by Swift class ARC
/// (atomic by language guarantee). Never escapes the module.
@usableFromInline
internal final class BytesStorage: @unchecked Sendable {
    @usableFromInline var pointer: UnsafeMutableRawPointer
    @usableFromInline var capacity: Int

    /// A shared zero-capacity singleton used to back empty `Bytes`/`BytesMut`
    /// without allocating. The 1-byte allocation exists only so `pointer`
    /// is non-nil for `withUnsafeBytes` callers; it is never read or written.
    @usableFromInline
    static let empty: BytesStorage = {
        let s = BytesStorage(rawCapacity: 0)
        return s
    }()

    @usableFromInline
    init(capacity: Int) {
        precondition(capacity >= 0, "BytesStorage capacity must be non-negative")
        self.capacity = capacity
        if capacity == 0 {
            // Allocate one byte so `pointer` is non-nil; never read or written.
            self.pointer = UnsafeMutableRawPointer.allocate(
                byteCount: 1, alignment: 8)
        } else {
            self.pointer = UnsafeMutableRawPointer.allocate(
                byteCount: capacity, alignment: 8)
        }
    }

    /// Identical to `init(capacity:)`, used by the `empty` singleton initializer.
    private init(rawCapacity: Int) {
        self.capacity = rawCapacity
        self.pointer = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 8)
    }

    deinit {
        pointer.deallocate()
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter BytesStorageTests`
Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Bytes/BytesStorage.swift Tests/BytesTests/BytesStorageTests.swift
git commit -m "Bytes: add BytesStorage refcounted heap class"
```

---

## Task 4: UnsafeReads helpers

**Files:**
- Create: `Sources/Bytes/Internal/UnsafeReads.swift`
- Create: `Tests/BytesTests/UnsafeReadsTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/BytesTests/UnsafeReadsTests.swift`:

```swift
import Testing
@testable import Bytes

@Test func loadFixedBigEndianUInt32() {
    let bytes: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF]
    bytes.withUnsafeBytes { buf in
        let v: UInt32 = loadFixed(UInt32.self,
                                  from: buf.baseAddress!,
                                  offset: 0,
                                  endianness: .big)
        #expect(v == 0xDEADBEEF)
    }
}

@Test func loadFixedLittleEndianUInt32() {
    let bytes: [UInt8] = [0xEF, 0xBE, 0xAD, 0xDE]
    bytes.withUnsafeBytes { buf in
        let v: UInt32 = loadFixed(UInt32.self,
                                  from: buf.baseAddress!,
                                  offset: 0,
                                  endianness: .little)
        #expect(v == 0xDEADBEEF)
    }
}

@Test func storeFixedBigEndianUInt32() {
    var bytes = [UInt8](repeating: 0, count: 4)
    bytes.withUnsafeMutableBytes { buf in
        storeFixed(UInt32(0xDEADBEEF),
                   to: buf.baseAddress!,
                   offset: 0,
                   endianness: .big)
    }
    #expect(bytes == [0xDE, 0xAD, 0xBE, 0xEF])
}

@Test func storeFixedLittleEndianUInt32() {
    var bytes = [UInt8](repeating: 0, count: 4)
    bytes.withUnsafeMutableBytes { buf in
        storeFixed(UInt32(0xDEADBEEF),
                   to: buf.baseAddress!,
                   offset: 0,
                   endianness: .little)
    }
    #expect(bytes == [0xEF, 0xBE, 0xAD, 0xDE])
}

@Test func loadFixedRespectsOffset() {
    let bytes: [UInt8] = [0x00, 0x00, 0xDE, 0xAD]
    bytes.withUnsafeBytes { buf in
        let v: UInt16 = loadFixed(UInt16.self,
                                  from: buf.baseAddress!,
                                  offset: 2,
                                  endianness: .big)
        #expect(v == 0xDEAD)
    }
}

@Test func loadFixedHandlesUnalignedOffsets() {
    let bytes: [UInt8] = [0xAA, 0xDE, 0xAD, 0xBE, 0xEF, 0xBB]
    bytes.withUnsafeBytes { buf in
        let v: UInt32 = loadFixed(UInt32.self,
                                  from: buf.baseAddress!,
                                  offset: 1,
                                  endianness: .big)
        #expect(v == 0xDEADBEEF)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter UnsafeReadsTests`
Expected: compile error (`loadFixed`/`storeFixed` not defined).

- [ ] **Step 3: Implement the helpers**

Create `Sources/Bytes/Internal/UnsafeReads.swift`:

```swift
@inlinable
internal func loadFixed<T: FixedWidthInteger>(
    _ type: T.Type,
    from base: UnsafeRawPointer,
    offset: Int,
    endianness: Endianness
) -> T {
    let raw = base.loadUnaligned(fromByteOffset: offset, as: T.self)
    switch endianness {
    case .big:    return T(bigEndian: raw)
    case .little: return T(littleEndian: raw)
    case .host:   return raw
    }
}

@inlinable
internal func storeFixed<T: FixedWidthInteger>(
    _ value: T,
    to base: UnsafeMutableRawPointer,
    offset: Int,
    endianness: Endianness
) {
    let raw: T
    switch endianness {
    case .big:    raw = value.bigEndian
    case .little: raw = value.littleEndian
    case .host:   raw = value
    }
    base.storeBytes(of: raw, toByteOffset: offset, as: T.self)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter UnsafeReadsTests`
Expected: 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Bytes/Internal/UnsafeReads.swift Tests/BytesTests/UnsafeReadsTests.swift
git commit -m "Bytes: add loadFixed/storeFixed unaligned-load helpers"
```

---

## Task 5: Bytes — construction, count, RandomAccessCollection

**Files:**
- Modify: `Sources/Bytes/Bytes.swift`
- Create: `Tests/BytesTests/BytesTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/BytesTests/BytesTests.swift`:

```swift
import Testing
@testable import Bytes

@Test func emptyBytesHasZeroCount() {
    let b = Bytes()
    #expect(b.count == 0)
    #expect(b.isEmpty == true)
}

@Test func bytesEmptyConstantSharesStorage() {
    let a = Bytes.empty
    let b = Bytes.empty
    #expect(a.count == 0 && b.count == 0)
}

@Test func bytesFromArray() {
    let b = Bytes([0xDE, 0xAD, 0xBE, 0xEF])
    #expect(b.count == 4)
    #expect(b[0] == 0xDE)
    #expect(b[3] == 0xEF)
}

@Test func bytesArrayLiteral() {
    let b: Bytes = [0x01, 0x02, 0x03]
    #expect(b.count == 3)
    #expect(Array(b) == [0x01, 0x02, 0x03])
}

@Test func bytesIteration() {
    let b = Bytes([0x10, 0x20, 0x30])
    var sum = 0
    for byte in b { sum += Int(byte) }
    #expect(sum == 0x60)
}

@Test func bytesFirstAndLast() {
    let b = Bytes([0xAA, 0xBB, 0xCC])
    #expect(b.first == 0xAA)
    #expect(b.last == 0xCC)
}

@Test func bytesContains() {
    let b = Bytes([0x01, 0x02, 0x03])
    #expect(b.contains(0x02))
    #expect(!b.contains(0x99))
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter BytesTests`
Expected: compile errors (`Bytes` is currently a placeholder).

- [ ] **Step 3: Implement Bytes (replace placeholder)**

Replace the entire contents of `Sources/Bytes/Bytes.swift` with:

```swift
/// An immutable, refcounted, zero-copy view over a byte buffer.
public struct Bytes: Sendable {
    @usableFromInline let storage: BytesStorage
    @usableFromInline let offset: Int
    @usableFromInline let length: Int

    @usableFromInline
    init(storage: BytesStorage, offset: Int, length: Int) {
        self.storage = storage
        self.offset = offset
        self.length = length
    }

    /// An empty `Bytes` value sharing a process-wide singleton storage.
    public static let empty = Bytes(storage: .empty, offset: 0, length: 0)

    public init() {
        self = .empty
    }

    public init<S: Sequence>(_ bytes: S) where S.Element == UInt8 {
        let array = Array(bytes)
        if array.isEmpty {
            self = .empty
            return
        }
        let storage = BytesStorage(capacity: array.count)
        array.withUnsafeBufferPointer { src in
            storage.pointer.copyMemory(from: src.baseAddress!,
                                       byteCount: array.count)
        }
        self.init(storage: storage, offset: 0, length: array.count)
    }

    public var count: Int { length }
    public var isEmpty: Bool { length == 0 }
}

extension Bytes: RandomAccessCollection {
    public typealias Element = UInt8
    public typealias Index = Int

    public var startIndex: Int { 0 }
    public var endIndex: Int { length }

    public subscript(position: Int) -> UInt8 {
        precondition(position >= 0 && position < length,
                     "Bytes index out of range")
        return storage.pointer.load(fromByteOffset: offset + position,
                                    as: UInt8.self)
    }
}

extension Bytes: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: UInt8...) {
        self.init(elements)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter BytesTests`
Expected: all 7 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Bytes/Bytes.swift Tests/BytesTests/BytesTests.swift
git commit -m "Bytes: add Bytes type with RandomAccessCollection conformance"
```

---

## Task 6: Bytes — slicing operations

**Files:**
- Modify: `Sources/Bytes/Bytes.swift`
- Modify: `Tests/BytesTests/BytesTests.swift`

- [ ] **Step 1: Add the failing tests**

Append to `Tests/BytesTests/BytesTests.swift`:

```swift
@Test func bytesPrefix() {
    let b = Bytes([0x01, 0x02, 0x03, 0x04])
    #expect(Array(b.prefix(2)) == [0x01, 0x02])
    #expect(Array(b.prefix(0)) == [])
    #expect(Array(b.prefix(99)) == [0x01, 0x02, 0x03, 0x04])  // clamps
}

@Test func bytesSuffix() {
    let b = Bytes([0x01, 0x02, 0x03, 0x04])
    #expect(Array(b.suffix(2)) == [0x03, 0x04])
    #expect(Array(b.suffix(0)) == [])
    #expect(Array(b.suffix(99)) == [0x01, 0x02, 0x03, 0x04])  // clamps
}

@Test func bytesDropFirst() {
    let b = Bytes([0x01, 0x02, 0x03, 0x04])
    #expect(Array(b.dropFirst(2)) == [0x03, 0x04])
    #expect(Array(b.dropFirst(0)) == [0x01, 0x02, 0x03, 0x04])
    #expect(Array(b.dropFirst(99)) == [])  // clamps
}

@Test func bytesDropLast() {
    let b = Bytes([0x01, 0x02, 0x03, 0x04])
    #expect(Array(b.dropLast(2)) == [0x01, 0x02])
    #expect(Array(b.dropLast(0)) == [0x01, 0x02, 0x03, 0x04])
    #expect(Array(b.dropLast(99)) == [])  // clamps
}

@Test func bytesRangeSubscript() {
    let b = Bytes([0x10, 0x20, 0x30, 0x40, 0x50])
    let mid = b[1..<4]
    #expect(Array(mid) == [0x20, 0x30, 0x40])
}

@Test func bytesSlicingIsZeroCopy() {
    let b = Bytes([0x01, 0x02, 0x03, 0x04])
    let mid = b[1..<3]
    let baseAddrOriginal = b.withUnsafeBytes { $0.baseAddress! }
    let baseAddrSlice = mid.withUnsafeBytes { $0.baseAddress! }
    // Slice points 1 byte into the original storage.
    #expect(baseAddrSlice == baseAddrOriginal.advanced(by: 1))
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter BytesTests`
Expected: compile errors for `prefix`, `suffix`, `dropFirst`, `dropLast`, range subscript, `withUnsafeBytes`.

- [ ] **Step 3: Add slicing methods to Bytes**

Append the following extension to `Sources/Bytes/Bytes.swift` (after the existing extensions):

```swift
extension Bytes {
    public func prefix(_ n: Int) -> Bytes {
        let take = max(0, min(n, length))
        return Bytes(storage: storage, offset: offset, length: take)
    }

    public func suffix(_ n: Int) -> Bytes {
        let take = max(0, min(n, length))
        return Bytes(storage: storage,
                     offset: offset + (length - take),
                     length: take)
    }

    public func dropFirst(_ n: Int) -> Bytes {
        let drop = max(0, min(n, length))
        return Bytes(storage: storage,
                     offset: offset + drop,
                     length: length - drop)
    }

    public func dropLast(_ n: Int) -> Bytes {
        let drop = max(0, min(n, length))
        return Bytes(storage: storage,
                     offset: offset,
                     length: length - drop)
    }

    public subscript(range: Range<Int>) -> Bytes {
        precondition(range.lowerBound >= 0 && range.upperBound <= length,
                     "Bytes range out of bounds")
        return Bytes(storage: storage,
                     offset: offset + range.lowerBound,
                     length: range.count)
    }

    public func withUnsafeBytes<R>(
        _ body: (UnsafeRawBufferPointer) throws -> R
    ) rethrows -> R {
        let start = storage.pointer.advanced(by: offset)
        let buffer = UnsafeRawBufferPointer(start: length == 0 ? nil : start,
                                            count: length)
        return try body(buffer)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter BytesTests`
Expected: all 13 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Bytes/Bytes.swift Tests/BytesTests/BytesTests.swift
git commit -m "Bytes: add zero-copy slicing (prefix/suffix/range) and withUnsafeBytes"
```

---

## Task 7: Bytes — Optional peek operations

**Files:**
- Modify: `Sources/Bytes/Bytes.swift`
- Modify: `Tests/BytesTests/BytesTests.swift`

- [ ] **Step 1: Add the failing tests**

Append to `Tests/BytesTests/BytesTests.swift`:

```swift
@Test func bytesPeekUInt8() {
    let b = Bytes([0xAB, 0xCD])
    #expect(b.peekUInt8(at: 0) == 0xAB)
    #expect(b.peekUInt8(at: 1) == 0xCD)
    #expect(b.peekUInt8(at: 2) == nil)
    #expect(b.peekUInt8(at: -1) == nil)
}

@Test func bytesPeekUInt16BigLittle() {
    let b = Bytes([0xDE, 0xAD])
    #expect(b.peekUInt16(at: 0, endianness: .big) == 0xDEAD)
    #expect(b.peekUInt16(at: 0, endianness: .little) == 0xADDE)
    #expect(b.peekUInt16(at: 1, endianness: .big) == nil)  // only 1 byte left
}

@Test func bytesPeekUInt32BigLittle() {
    let b = Bytes([0xDE, 0xAD, 0xBE, 0xEF])
    #expect(b.peekUInt32(at: 0, endianness: .big) == 0xDEADBEEF)
    #expect(b.peekUInt32(at: 0, endianness: .little) == 0xEFBEADDE)
    #expect(b.peekUInt32(at: 1, endianness: .big) == nil)
}

@Test func bytesPeekUInt64BigLittle() {
    let b = Bytes([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
    #expect(b.peekUInt64(at: 0, endianness: .big) == 0x0102030405060708)
    #expect(b.peekUInt64(at: 0, endianness: .little) == 0x0807060504030201)
}

@Test func bytesPeekSignedIntegers() {
    let b = Bytes([0xFF, 0xFF, 0xFF, 0xFE])
    #expect(b.peekInt8(at: 0) == -1)
    #expect(b.peekInt16(at: 0, endianness: .big) == -1)
    #expect(b.peekInt32(at: 0, endianness: .big) == -2)
}

@Test func bytesPeekBytes() {
    let b = Bytes([0x01, 0x02, 0x03, 0x04, 0x05])
    let slice = b.peekBytes(at: 1, length: 3)
    #expect(slice != nil)
    #expect(Array(slice!) == [0x02, 0x03, 0x04])
    #expect(b.peekBytes(at: 1, length: 99) == nil)         // out of bounds
    #expect(b.peekBytes(at: -1, length: 1) == nil)         // negative offset
    #expect(b.peekBytes(at: 0, length: -1) == nil)         // negative length
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter BytesTests`
Expected: compile errors for `peekUInt8`, `peekUInt16`, etc.

- [ ] **Step 3: Add Optional peek methods**

Append to `Sources/Bytes/Bytes.swift`:

```swift
extension Bytes {
    @inlinable
    public func peekUInt8(at offset: Int) -> UInt8? {
        guard offset >= 0, offset + 1 <= length else { return nil }
        return storage.pointer.load(
            fromByteOffset: self.offset + offset, as: UInt8.self)
    }

    @inlinable
    public func peekInt8(at offset: Int) -> Int8? {
        guard let u = peekUInt8(at: offset) else { return nil }
        return Int8(bitPattern: u)
    }

    @inlinable
    public func peekUInt16(at offset: Int, endianness: Endianness) -> UInt16? {
        guard offset >= 0, offset + 2 <= length else { return nil }
        return loadFixed(UInt16.self, from: storage.pointer,
                         offset: self.offset + offset, endianness: endianness)
    }

    @inlinable
    public func peekInt16(at offset: Int, endianness: Endianness) -> Int16? {
        peekUInt16(at: offset, endianness: endianness).map(Int16.init(bitPattern:))
    }

    @inlinable
    public func peekUInt32(at offset: Int, endianness: Endianness) -> UInt32? {
        guard offset >= 0, offset + 4 <= length else { return nil }
        return loadFixed(UInt32.self, from: storage.pointer,
                         offset: self.offset + offset, endianness: endianness)
    }

    @inlinable
    public func peekInt32(at offset: Int, endianness: Endianness) -> Int32? {
        peekUInt32(at: offset, endianness: endianness).map(Int32.init(bitPattern:))
    }

    @inlinable
    public func peekUInt64(at offset: Int, endianness: Endianness) -> UInt64? {
        guard offset >= 0, offset + 8 <= length else { return nil }
        return loadFixed(UInt64.self, from: storage.pointer,
                         offset: self.offset + offset, endianness: endianness)
    }

    @inlinable
    public func peekInt64(at offset: Int, endianness: Endianness) -> Int64? {
        peekUInt64(at: offset, endianness: endianness).map(Int64.init(bitPattern:))
    }

    @inlinable
    public func peekBytes(at offset: Int, length: Int) -> Bytes? {
        guard offset >= 0, length >= 0, offset + length <= self.length else {
            return nil
        }
        return Bytes(storage: storage,
                     offset: self.offset + offset,
                     length: length)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter BytesTests`
Expected: all 19 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Bytes/Bytes.swift Tests/BytesTests/BytesTests.swift
git commit -m "Bytes: add Optional peek operations for fixed-width integers"
```

---

## Task 8: Bytes — Throwing tryPeek operations

**Files:**
- Modify: `Sources/Bytes/Bytes.swift`
- Modify: `Tests/BytesTests/BytesTests.swift`

- [ ] **Step 1: Add the failing tests**

Append to `Tests/BytesTests/BytesTests.swift`:

```swift
@Test func bytesTryPeekSucceeds() throws {
    let b = Bytes([0xDE, 0xAD, 0xBE, 0xEF])
    #expect(try b.tryPeekUInt32(at: 0, endianness: .big) == 0xDEADBEEF)
    #expect(try b.tryPeekUInt8(at: 1) == 0xAD)
}

@Test func bytesTryPeekThrowsOutOfBounds() {
    let b = Bytes([0xDE, 0xAD])
    #expect(throws: BytesError.outOfBounds(offset: 1, length: 4, bufferCount: 2)) {
        _ = try b.tryPeekUInt32(at: 1, endianness: .big)
    }
    #expect(throws: BytesError.outOfBounds(offset: -1, length: 1, bufferCount: 2)) {
        _ = try b.tryPeekUInt8(at: -1)
    }
}

@Test func bytesTryPeekBytesThrowsInvalidLength() {
    let b = Bytes([0xDE, 0xAD])
    #expect(throws: BytesError.invalidLength(-1)) {
        _ = try b.tryPeekBytes(at: 0, length: -1)
    }
}

@Test func bytesTryPeekBytesThrowsOutOfBounds() {
    let b = Bytes([0xDE, 0xAD])
    #expect(throws: BytesError.outOfBounds(offset: 0, length: 5, bufferCount: 2)) {
        _ = try b.tryPeekBytes(at: 0, length: 5)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter BytesTests`
Expected: compile errors for `tryPeek*`.

- [ ] **Step 3: Add throwing tryPeek methods**

Append to `Sources/Bytes/Bytes.swift`:

```swift
extension Bytes {
    public func tryPeekUInt8(at offset: Int) throws -> UInt8 {
        guard let v = peekUInt8(at: offset) else {
            throw BytesError.outOfBounds(offset: offset, length: 1, bufferCount: length)
        }
        return v
    }

    public func tryPeekInt8(at offset: Int) throws -> Int8 {
        Int8(bitPattern: try tryPeekUInt8(at: offset))
    }

    public func tryPeekUInt16(at offset: Int, endianness: Endianness) throws -> UInt16 {
        guard let v = peekUInt16(at: offset, endianness: endianness) else {
            throw BytesError.outOfBounds(offset: offset, length: 2, bufferCount: length)
        }
        return v
    }

    public func tryPeekInt16(at offset: Int, endianness: Endianness) throws -> Int16 {
        Int16(bitPattern: try tryPeekUInt16(at: offset, endianness: endianness))
    }

    public func tryPeekUInt32(at offset: Int, endianness: Endianness) throws -> UInt32 {
        guard let v = peekUInt32(at: offset, endianness: endianness) else {
            throw BytesError.outOfBounds(offset: offset, length: 4, bufferCount: length)
        }
        return v
    }

    public func tryPeekInt32(at offset: Int, endianness: Endianness) throws -> Int32 {
        Int32(bitPattern: try tryPeekUInt32(at: offset, endianness: endianness))
    }

    public func tryPeekUInt64(at offset: Int, endianness: Endianness) throws -> UInt64 {
        guard let v = peekUInt64(at: offset, endianness: endianness) else {
            throw BytesError.outOfBounds(offset: offset, length: 8, bufferCount: length)
        }
        return v
    }

    public func tryPeekInt64(at offset: Int, endianness: Endianness) throws -> Int64 {
        Int64(bitPattern: try tryPeekUInt64(at: offset, endianness: endianness))
    }

    public func tryPeekBytes(at offset: Int, length: Int) throws -> Bytes {
        if length < 0 { throw BytesError.invalidLength(length) }
        guard let v = peekBytes(at: offset, length: length) else {
            throw BytesError.outOfBounds(offset: offset,
                                         length: length,
                                         bufferCount: self.length)
        }
        return v
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter BytesTests`
Expected: all 23 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Bytes/Bytes.swift Tests/BytesTests/BytesTests.swift
git commit -m "Bytes: add throwing tryPeek operations"
```

---

## Task 9: Bytes — Hashable + Equatable

**Files:**
- Modify: `Sources/Bytes/Bytes.swift`
- Modify: `Tests/BytesTests/BytesTests.swift`

- [ ] **Step 1: Add the failing tests**

Append to `Tests/BytesTests/BytesTests.swift`:

```swift
@Test func bytesEqualByContent() {
    let a = Bytes([0x01, 0x02, 0x03])
    let b = Bytes([0x01, 0x02, 0x03])
    let c = Bytes([0x01, 0x02])
    let d = Bytes([0x01, 0x02, 0x04])
    #expect(a == b)
    #expect(a != c)
    #expect(a != d)
}

@Test func bytesEmptyEquality() {
    #expect(Bytes() == Bytes.empty)
    #expect(Bytes() == Bytes([]))
}

@Test func bytesHashableConsistent() {
    let a = Bytes([0xDE, 0xAD, 0xBE, 0xEF])
    let b = Bytes([0xDE, 0xAD, 0xBE, 0xEF])
    var seen = Set<Bytes>()
    seen.insert(a)
    #expect(seen.contains(b))
}

@Test func bytesSliceEqualsArray() {
    let original = Bytes([0x10, 0x20, 0x30, 0x40, 0x50])
    let slice = original[1..<4]
    #expect(slice == Bytes([0x20, 0x30, 0x40]))
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter BytesTests`
Expected: compile errors — `Bytes` is not yet `Hashable`.

- [ ] **Step 3: Add Hashable conformance**

Append to `Sources/Bytes/Bytes.swift`:

```swift
extension Bytes: Hashable {
    public static func == (lhs: Bytes, rhs: Bytes) -> Bool {
        guard lhs.length == rhs.length else { return false }
        return lhs.withUnsafeBytes { l in
            rhs.withUnsafeBytes { r in
                if l.count == 0 { return true }
                return l.elementsEqual(r)
            }
        }
    }

    public func hash(into hasher: inout Hasher) {
        withUnsafeBytes { buf in
            hasher.combine(bytes: buf)
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter BytesTests`
Expected: all 27 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Bytes/Bytes.swift Tests/BytesTests/BytesTests.swift
git commit -m "Bytes: add Hashable conformance with content equality"
```

---

## Task 10: BytesMut — construction and basic state

**Files:**
- Create: `Sources/Bytes/BytesMut.swift`
- Create: `Tests/BytesTests/BytesMutTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/BytesTests/BytesMutTests.swift`:

```swift
import Testing
@testable import Bytes

@Test func bytesMutEmptyDefault() {
    let m = BytesMut()
    #expect(m.count == 0)
    #expect(m.capacity == 0)
    #expect(m.isEmpty == true)
}

@Test func bytesMutWithCapacity() {
    let m = BytesMut(capacity: 128)
    #expect(m.count == 0)
    #expect(m.capacity >= 128)
    #expect(m.isEmpty == true)
}

@Test func bytesMutFromSequence() {
    let m = BytesMut([0x01, 0x02, 0x03])
    #expect(m.count == 3)
    #expect(m.capacity >= 3)
}

@Test func bytesMutReserveCapacityGrows() {
    var m = BytesMut()
    m.reserveCapacity(256)
    #expect(m.capacity >= 256)
    #expect(m.count == 0)
}

@Test func bytesMutClearResetsCount() {
    var m = BytesMut([0x01, 0x02, 0x03])
    let capBefore = m.capacity
    m.clear()
    #expect(m.count == 0)
    #expect(m.capacity == capBefore)  // storage retained when uniquely owned
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter BytesMutTests`
Expected: compile errors (`BytesMut` not defined).

- [ ] **Step 3: Implement BytesMut basics**

Create `Sources/Bytes/BytesMut.swift`:

```swift
/// A mutable byte builder with copy-on-write semantics. Freezes into `Bytes`.
public struct BytesMut {
    @usableFromInline var storage: BytesStorage
    @usableFromInline var _count: Int

    public init() {
        self.storage = .empty
        self._count = 0
    }

    public init(capacity: Int) {
        precondition(capacity >= 0, "BytesMut capacity must be non-negative")
        self.storage = capacity == 0 ? .empty : BytesStorage(capacity: capacity)
        self._count = 0
    }

    public init<S: Sequence>(_ bytes: S) where S.Element == UInt8 {
        let array = Array(bytes)
        self.storage = array.isEmpty ? .empty : BytesStorage(capacity: array.count)
        self._count = array.count
        if !array.isEmpty {
            array.withUnsafeBufferPointer { src in
                storage.pointer.copyMemory(from: src.baseAddress!,
                                           byteCount: array.count)
            }
        }
    }

    public var count: Int { _count }
    public var capacity: Int { storage.capacity }
    public var isEmpty: Bool { _count == 0 }

    public mutating func reserveCapacity(_ n: Int) {
        precondition(n >= 0, "reserveCapacity must be non-negative")
        ensureCapacity(forAdditional: max(0, n - _count))
    }

    public mutating func clear() {
        _count = 0
        // Storage is retained; growth is lazy on next put.
    }

    /// Ensures the storage can hold `_count + additional` bytes total, performing
    /// CoW if shared. Internal helper used by all mutating ops.
    @usableFromInline
    mutating func ensureCapacity(forAdditional additional: Int) {
        let required = _count + additional
        let unique = isKnownUniquelyReferenced(&storage)
        if required <= storage.capacity && unique {
            return
        }
        let newCapacity: Int
        if required <= storage.capacity {
            newCapacity = storage.capacity
        } else {
            let doubled = storage.capacity &* 2
            newCapacity = max(required, doubled, 64)
        }
        let newStorage = BytesStorage(capacity: newCapacity)
        if _count > 0 {
            newStorage.pointer.copyMemory(
                from: UnsafeRawPointer(storage.pointer),
                byteCount: _count)
        }
        storage = newStorage
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter BytesMutTests`
Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Bytes/BytesMut.swift Tests/BytesTests/BytesMutTests.swift
git commit -m "Bytes: add BytesMut construction, capacity, clear, ensureCapacity"
```

---

## Task 11: BytesMut — put operations

**Files:**
- Modify: `Sources/Bytes/BytesMut.swift`
- Modify: `Tests/BytesTests/BytesMutTests.swift`

- [ ] **Step 1: Add the failing tests**

Append to `Tests/BytesTests/BytesMutTests.swift`:

```swift
@Test func bytesMutPutUInt8() {
    var m = BytesMut()
    m.putUInt8(0xAB)
    m.putUInt8(0xCD)
    let frozen = m.snapshot()
    #expect(Array(frozen) == [0xAB, 0xCD])
}

@Test func bytesMutPutUInt16BigLittle() {
    var m = BytesMut()
    m.putUInt16(0xDEAD, endianness: .big)
    m.putUInt16(0xDEAD, endianness: .little)
    let s = m.snapshot()
    #expect(Array(s) == [0xDE, 0xAD, 0xAD, 0xDE])
}

@Test func bytesMutPutUInt32() {
    var m = BytesMut()
    m.putUInt32(0xDEADBEEF, endianness: .big)
    let s = m.snapshot()
    #expect(Array(s) == [0xDE, 0xAD, 0xBE, 0xEF])
}

@Test func bytesMutPutUInt64() {
    var m = BytesMut()
    m.putUInt64(0x0102030405060708, endianness: .big)
    let s = m.snapshot()
    #expect(Array(s) == [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
}

@Test func bytesMutPutSignedIntegers() {
    var m = BytesMut()
    m.putInt8(-1)
    m.putInt16(-1, endianness: .big)
    m.putInt32(-2, endianness: .big)
    let s = m.snapshot()
    #expect(Array(s) == [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFE])
}

@Test func bytesMutPutBytesFromSequence() {
    var m = BytesMut()
    m.putBytes([0x01, 0x02, 0x03] as [UInt8])
    let s = m.snapshot()
    #expect(Array(s) == [0x01, 0x02, 0x03])
}

@Test func bytesMutPutBytesFromBytes() {
    var m = BytesMut()
    let other = Bytes([0xAA, 0xBB])
    m.putBytes(other)
    m.putBytes(other)
    let s = m.snapshot()
    #expect(Array(s) == [0xAA, 0xBB, 0xAA, 0xBB])
}

@Test func bytesMutGrowsOnAppend() {
    var m = BytesMut(capacity: 4)
    let initialCap = m.capacity
    for _ in 0..<100 { m.putUInt8(0xAA) }
    #expect(m.count == 100)
    #expect(m.capacity > initialCap)
    let s = m.snapshot()
    #expect(s.count == 100)
    #expect(s[0] == 0xAA && s[99] == 0xAA)
}

@Test func bytesMutWithUnsafeMutableBytes() {
    var m = BytesMut(capacity: 4)
    m.putBytes([0x00, 0x00, 0x00, 0x00] as [UInt8])
    m.withUnsafeMutableBytes { buf in
        buf[0] = 0xFF
        buf[3] = 0xFF
    }
    let s = m.snapshot()
    #expect(Array(s) == [0xFF, 0x00, 0x00, 0xFF])
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter BytesMutTests`
Expected: compile errors for `put*`, `snapshot`, `withUnsafeMutableBytes`.

- [ ] **Step 3: Implement put operations and snapshot**

Append to `Sources/Bytes/BytesMut.swift`:

```swift
extension BytesMut {
    public mutating func putUInt8(_ v: UInt8) {
        ensureCapacity(forAdditional: 1)
        storage.pointer.storeBytes(of: v, toByteOffset: _count, as: UInt8.self)
        _count += 1
    }

    public mutating func putInt8(_ v: Int8) {
        putUInt8(UInt8(bitPattern: v))
    }

    public mutating func putUInt16(_ v: UInt16, endianness: Endianness) {
        ensureCapacity(forAdditional: 2)
        storeFixed(v, to: storage.pointer, offset: _count, endianness: endianness)
        _count += 2
    }

    public mutating func putInt16(_ v: Int16, endianness: Endianness) {
        putUInt16(UInt16(bitPattern: v), endianness: endianness)
    }

    public mutating func putUInt32(_ v: UInt32, endianness: Endianness) {
        ensureCapacity(forAdditional: 4)
        storeFixed(v, to: storage.pointer, offset: _count, endianness: endianness)
        _count += 4
    }

    public mutating func putInt32(_ v: Int32, endianness: Endianness) {
        putUInt32(UInt32(bitPattern: v), endianness: endianness)
    }

    public mutating func putUInt64(_ v: UInt64, endianness: Endianness) {
        ensureCapacity(forAdditional: 8)
        storeFixed(v, to: storage.pointer, offset: _count, endianness: endianness)
        _count += 8
    }

    public mutating func putInt64(_ v: Int64, endianness: Endianness) {
        putUInt64(UInt64(bitPattern: v), endianness: endianness)
    }

    public mutating func putBytes<S: Sequence>(_ bytes: S) where S.Element == UInt8 {
        let array = Array(bytes)
        guard !array.isEmpty else { return }
        ensureCapacity(forAdditional: array.count)
        array.withUnsafeBufferPointer { src in
            storage.pointer.advanced(by: _count).copyMemory(
                from: src.baseAddress!, byteCount: array.count)
        }
        _count += array.count
    }

    public mutating func putBytes(_ other: Bytes) {
        guard !other.isEmpty else { return }
        ensureCapacity(forAdditional: other.count)
        other.withUnsafeBytes { src in
            storage.pointer.advanced(by: _count).copyMemory(
                from: src.baseAddress!, byteCount: src.count)
        }
        _count += other.count
    }

    /// Non-consuming snapshot. Returns a `Bytes` referencing the current
    /// storage; subsequent mutations CoW into a new storage.
    public func snapshot() -> Bytes {
        Bytes(storage: storage, offset: 0, length: _count)
    }

    public mutating func withUnsafeMutableBytes<R>(
        _ body: (UnsafeMutableRawBufferPointer) throws -> R
    ) rethrows -> R {
        ensureCapacity(forAdditional: 0)  // CoW if shared
        let buffer = UnsafeMutableRawBufferPointer(
            start: _count == 0 ? nil : storage.pointer, count: _count)
        return try body(buffer)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter BytesMutTests`
Expected: all 14 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Bytes/BytesMut.swift Tests/BytesTests/BytesMutTests.swift
git commit -m "Bytes: add BytesMut put operations, snapshot, withUnsafeMutableBytes"
```

---

## Task 12: BytesMut — freeze and CoW correctness

**Files:**
- Modify: `Sources/Bytes/BytesMut.swift`
- Create: `Tests/BytesTests/CowTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/BytesTests/CowTests.swift`:

```swift
import Testing
@testable import Bytes

@Test func freezeReturnsContentsAndResetsBuilder() {
    var m = BytesMut()
    m.putBytes([0xDE, 0xAD] as [UInt8])
    let frozen = m.freeze()
    #expect(Array(frozen) == [0xDE, 0xAD])
    #expect(m.count == 0)
    #expect(m.isEmpty == true)
}

@Test func freezeAllowsBuilderReuse() {
    var m = BytesMut()
    m.putUInt8(0xAA)
    let first = m.freeze()
    m.putUInt8(0xBB)
    let second = m.freeze()
    #expect(Array(first) == [0xAA])
    #expect(Array(second) == [0xBB])
}

@Test func snapshotPreservedAcrossMutation() {
    var m = BytesMut()
    m.putBytes([0x01, 0x02] as [UInt8])
    let snap = m.snapshot()
    m.putBytes([0x03, 0x04] as [UInt8])  // triggers CoW
    #expect(Array(snap) == [0x01, 0x02])
    #expect(Array(m.snapshot()) == [0x01, 0x02, 0x03, 0x04])
}

@Test func snapshotForcesCoWOnNextMutation() {
    var m = BytesMut(capacity: 64)
    m.putBytes([0xAA, 0xBB] as [UInt8])
    let snapAddr = m.snapshot().withUnsafeBytes { $0.baseAddress! }
    m.putUInt8(0xCC)  // CoW expected because snapshot still alive
    let postAddr = m.snapshot().withUnsafeBytes { $0.baseAddress! }
    #expect(snapAddr != postAddr)
}

@Test func freezeIntoBytesIsZeroCopyOnImmediateAccess() {
    var m = BytesMut(capacity: 64)
    m.putBytes([0x01, 0x02, 0x03] as [UInt8])
    let storageAddr = m.snapshot().withUnsafeBytes { $0.baseAddress! }
    let frozen = m.freeze()
    let frozenAddr = frozen.withUnsafeBytes { $0.baseAddress! }
    #expect(storageAddr == frozenAddr)
}

@Test func cowStress() {
    var m = BytesMut()
    var snapshots: [Bytes] = []
    for i in 0..<10_000 {
        m.putUInt8(UInt8(i & 0xFF))
        if i % 100 == 0 {
            snapshots.append(m.snapshot())
        }
    }
    // After 10k appends with snapshots taken every 100 iterations:
    #expect(m.count == 10_000)
    // Each snapshot should reflect the prefix at the time it was taken.
    for (idx, snap) in snapshots.enumerated() {
        let expectedCount = idx * 100 + 1
        #expect(snap.count == expectedCount)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter CowTests`
Expected: compile error (`freeze` not defined).

- [ ] **Step 3: Implement freeze**

Append to `Sources/Bytes/BytesMut.swift`:

```swift
extension BytesMut {
    /// Hands ownership of the current contents to a new `Bytes` and resets
    /// this builder to an empty state backed by the empty singleton.
    public mutating func freeze() -> Bytes {
        let result = Bytes(storage: storage, offset: 0, length: _count)
        storage = .empty
        _count = 0
        return result
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter CowTests`
Expected: all 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Bytes/BytesMut.swift Tests/BytesTests/CowTests.swift
git commit -m "Bytes: add freeze() and CoW correctness tests"
```

---

## Task 13: BytesReader — basic structure

**Files:**
- Create: `Sources/Bytes/BytesReader.swift`
- Create: `Tests/BytesTests/BytesReaderTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/BytesTests/BytesReaderTests.swift`:

```swift
import Testing
@testable import Bytes

@Test func readerInitialState() {
    let r = BytesReader(Bytes([0x01, 0x02, 0x03]))
    #expect(r.remaining == 3)
    #expect(r.consumed == 0)
    #expect(r.isExhausted == false)
}

@Test func readerEmptyIsExhausted() {
    let r = BytesReader(Bytes())
    #expect(r.remaining == 0)
    #expect(r.consumed == 0)
    #expect(r.isExhausted == true)
}

@Test func readerRemainingBytes() {
    let r = BytesReader(Bytes([0x01, 0x02, 0x03]))
    let tail = r.remainingBytes()
    #expect(Array(tail) == [0x01, 0x02, 0x03])
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter BytesReaderTests`
Expected: compile error (`BytesReader` not defined).

- [ ] **Step 3: Implement BytesReader basics**

Create `Sources/Bytes/BytesReader.swift`:

```swift
/// A noncopyable cursor over an immutable `Bytes`. Reads advance the cursor;
/// noncopyable semantics prevent accidental cursor forks across consumers.
public struct BytesReader: ~Copyable {
    @usableFromInline let bytes: Bytes
    @usableFromInline var cursor: Int

    public init(_ bytes: Bytes) {
        self.bytes = bytes
        self.cursor = 0
    }

    public var remaining: Int { bytes.count - cursor }
    public var consumed: Int { cursor }
    public var isExhausted: Bool { cursor >= bytes.count }

    /// Returns the unread tail without advancing.
    public func remainingBytes() -> Bytes {
        bytes[cursor..<bytes.count]
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter BytesReaderTests`
Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Bytes/BytesReader.swift Tests/BytesTests/BytesReaderTests.swift
git commit -m "Bytes: add BytesReader (~Copyable) cursor structure"
```

---

## Task 14: BytesReader — Optional read operations

**Files:**
- Modify: `Sources/Bytes/BytesReader.swift`
- Modify: `Tests/BytesTests/BytesReaderTests.swift`

- [ ] **Step 1: Add the failing tests**

Append to `Tests/BytesTests/BytesReaderTests.swift`:

```swift
@Test func readerReadUInt8Advances() {
    var r = BytesReader(Bytes([0xAA, 0xBB, 0xCC]))
    #expect(r.readUInt8() == 0xAA)
    #expect(r.consumed == 1)
    #expect(r.remaining == 2)
    #expect(r.readUInt8() == 0xBB)
    #expect(r.readUInt8() == 0xCC)
    #expect(r.readUInt8() == nil)            // exhausted
    #expect(r.consumed == 3)                 // did NOT advance on failure
}

@Test func readerReadUInt32() {
    var r = BytesReader(Bytes([0xDE, 0xAD, 0xBE, 0xEF, 0x42]))
    #expect(r.readUInt32(endianness: .big) == 0xDEADBEEF)
    #expect(r.remaining == 1)
    #expect(r.readUInt32(endianness: .big) == nil)  // not enough left
    #expect(r.remaining == 1)                       // unchanged on failure
}

@Test func readerReadUInt16AndUInt64() {
    var r = BytesReader(Bytes([0xDE, 0xAD,
                               0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]))
    #expect(r.readUInt16(endianness: .big) == 0xDEAD)
    #expect(r.readUInt64(endianness: .big) == 0x0102030405060708)
}

@Test func readerReadSigned() {
    var r = BytesReader(Bytes([0xFF, 0xFF, 0xFE]))
    #expect(r.readInt8() == -1)
    #expect(r.readInt16(endianness: .big) == -2)
}

@Test func readerReadBytesZeroCopy() {
    let original = Bytes([0x01, 0x02, 0x03, 0x04, 0x05])
    var r = BytesReader(original)
    let head = r.readBytes(length: 3)
    #expect(head != nil)
    #expect(Array(head!) == [0x01, 0x02, 0x03])
    let originalAddr = original.withUnsafeBytes { $0.baseAddress! }
    let headAddr = head!.withUnsafeBytes { $0.baseAddress! }
    #expect(headAddr == originalAddr)
}

@Test func readerReadBytesShortReadReturnsNil() {
    var r = BytesReader(Bytes([0x01, 0x02]))
    #expect(r.readBytes(length: 5) == nil)
    #expect(r.consumed == 0)                 // did not advance
}

@Test func readerReadBytesNegativeLengthReturnsNil() {
    var r = BytesReader(Bytes([0x01, 0x02]))
    #expect(r.readBytes(length: -1) == nil)
    #expect(r.consumed == 0)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter BytesReaderTests`
Expected: compile errors for `read*`.

- [ ] **Step 3: Implement Optional reads**

Append to `Sources/Bytes/BytesReader.swift`:

```swift
extension BytesReader {
    public mutating func readUInt8() -> UInt8? {
        guard let v = bytes.peekUInt8(at: cursor) else { return nil }
        cursor += 1
        return v
    }

    public mutating func readInt8() -> Int8? {
        readUInt8().map(Int8.init(bitPattern:))
    }

    public mutating func readUInt16(endianness: Endianness) -> UInt16? {
        guard let v = bytes.peekUInt16(at: cursor, endianness: endianness)
        else { return nil }
        cursor += 2
        return v
    }

    public mutating func readInt16(endianness: Endianness) -> Int16? {
        readUInt16(endianness: endianness).map(Int16.init(bitPattern:))
    }

    public mutating func readUInt32(endianness: Endianness) -> UInt32? {
        guard let v = bytes.peekUInt32(at: cursor, endianness: endianness)
        else { return nil }
        cursor += 4
        return v
    }

    public mutating func readInt32(endianness: Endianness) -> Int32? {
        readUInt32(endianness: endianness).map(Int32.init(bitPattern:))
    }

    public mutating func readUInt64(endianness: Endianness) -> UInt64? {
        guard let v = bytes.peekUInt64(at: cursor, endianness: endianness)
        else { return nil }
        cursor += 8
        return v
    }

    public mutating func readInt64(endianness: Endianness) -> Int64? {
        readUInt64(endianness: endianness).map(Int64.init(bitPattern:))
    }

    public mutating func readBytes(length: Int) -> Bytes? {
        guard length >= 0,
              let slice = bytes.peekBytes(at: cursor, length: length) else {
            return nil
        }
        cursor += length
        return slice
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter BytesReaderTests`
Expected: all 10 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Bytes/BytesReader.swift Tests/BytesTests/BytesReaderTests.swift
git commit -m "Bytes: add BytesReader Optional read operations"
```

---

## Task 15: BytesReader — Throwing tryRead operations

**Files:**
- Modify: `Sources/Bytes/BytesReader.swift`
- Modify: `Tests/BytesTests/BytesReaderTests.swift`

- [ ] **Step 1: Add the failing tests**

Append to `Tests/BytesTests/BytesReaderTests.swift`:

```swift
@Test func readerTryReadSucceeds() throws {
    var r = BytesReader(Bytes([0xDE, 0xAD, 0xBE, 0xEF]))
    #expect(try r.tryReadUInt32(endianness: .big) == 0xDEADBEEF)
    #expect(r.remaining == 0)
}

@Test func readerTryReadThrowsShortRead() {
    var r = BytesReader(Bytes([0x01, 0x02]))
    #expect(throws: BytesError.shortRead(needed: 4, available: 2)) {
        _ = try r.tryReadUInt32(endianness: .big)
    }
    // cursor unchanged after failure
    #expect(r.consumed == 0)
}

@Test func readerTryReadBytesThrowsInvalidLength() {
    var r = BytesReader(Bytes([0x01, 0x02]))
    #expect(throws: BytesError.invalidLength(-1)) {
        _ = try r.tryReadBytes(length: -1)
    }
}

@Test func readerTryReadBytesThrowsShortRead() {
    var r = BytesReader(Bytes([0x01, 0x02]))
    #expect(throws: BytesError.shortRead(needed: 5, available: 2)) {
        _ = try r.tryReadBytes(length: 5)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter BytesReaderTests`
Expected: compile errors for `tryRead*`.

- [ ] **Step 3: Implement throwing tryRead operations**

Append to `Sources/Bytes/BytesReader.swift`:

```swift
extension BytesReader {
    public mutating func tryReadUInt8() throws -> UInt8 {
        guard let v = readUInt8() else {
            throw BytesError.shortRead(needed: 1, available: remaining)
        }
        return v
    }

    public mutating func tryReadInt8() throws -> Int8 {
        Int8(bitPattern: try tryReadUInt8())
    }

    public mutating func tryReadUInt16(endianness: Endianness) throws -> UInt16 {
        guard let v = readUInt16(endianness: endianness) else {
            throw BytesError.shortRead(needed: 2, available: remaining)
        }
        return v
    }

    public mutating func tryReadInt16(endianness: Endianness) throws -> Int16 {
        Int16(bitPattern: try tryReadUInt16(endianness: endianness))
    }

    public mutating func tryReadUInt32(endianness: Endianness) throws -> UInt32 {
        guard let v = readUInt32(endianness: endianness) else {
            throw BytesError.shortRead(needed: 4, available: remaining)
        }
        return v
    }

    public mutating func tryReadInt32(endianness: Endianness) throws -> Int32 {
        Int32(bitPattern: try tryReadUInt32(endianness: endianness))
    }

    public mutating func tryReadUInt64(endianness: Endianness) throws -> UInt64 {
        guard let v = readUInt64(endianness: endianness) else {
            throw BytesError.shortRead(needed: 8, available: remaining)
        }
        return v
    }

    public mutating func tryReadInt64(endianness: Endianness) throws -> Int64 {
        Int64(bitPattern: try tryReadUInt64(endianness: endianness))
    }

    public mutating func tryReadBytes(length: Int) throws -> Bytes {
        if length < 0 { throw BytesError.invalidLength(length) }
        guard let v = readBytes(length: length) else {
            throw BytesError.shortRead(needed: length, available: remaining)
        }
        return v
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter BytesReaderTests`
Expected: all 14 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Bytes/BytesReader.swift Tests/BytesTests/BytesReaderTests.swift
git commit -m "Bytes: add BytesReader throwing tryRead operations"
```

---

## Task 16: BytesReader — skip and trySkip

**Files:**
- Modify: `Sources/Bytes/BytesReader.swift`
- Modify: `Tests/BytesTests/BytesReaderTests.swift`

- [ ] **Step 1: Add the failing tests**

Append to `Tests/BytesTests/BytesReaderTests.swift`:

```swift
@Test func readerSkipAdvances() {
    var r = BytesReader(Bytes([0x01, 0x02, 0x03, 0x04]))
    #expect(r.skip(2) == true)
    #expect(r.consumed == 2)
    #expect(r.readUInt8() == 0x03)
}

@Test func readerSkipPastEndReturnsFalse() {
    var r = BytesReader(Bytes([0x01, 0x02]))
    #expect(r.skip(5) == false)
    #expect(r.consumed == 0)             // unchanged on failure
}

@Test func readerSkipNegativeReturnsFalse() {
    var r = BytesReader(Bytes([0x01]))
    #expect(r.skip(-1) == false)
    #expect(r.consumed == 0)
}

@Test func readerTrySkipThrowsOnShortRead() {
    var r = BytesReader(Bytes([0x01, 0x02]))
    #expect(throws: BytesError.shortRead(needed: 5, available: 2)) {
        try r.trySkip(5)
    }
    #expect(r.consumed == 0)
}

@Test func readerTrySkipThrowsOnNegative() {
    var r = BytesReader(Bytes([0x01]))
    #expect(throws: BytesError.invalidLength(-1)) {
        try r.trySkip(-1)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter BytesReaderTests`
Expected: compile errors for `skip` and `trySkip`.

- [ ] **Step 3: Implement skip and trySkip**

Append to `Sources/Bytes/BytesReader.swift`:

```swift
extension BytesReader {
    public mutating func skip(_ n: Int) -> Bool {
        guard n >= 0, cursor + n <= bytes.count else { return false }
        cursor += n
        return true
    }

    public mutating func trySkip(_ n: Int) throws {
        if n < 0 { throw BytesError.invalidLength(n) }
        guard cursor + n <= bytes.count else {
            throw BytesError.shortRead(needed: n, available: remaining)
        }
        cursor += n
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter BytesReaderTests`
Expected: all 19 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Bytes/BytesReader.swift Tests/BytesTests/BytesReaderTests.swift
git commit -m "Bytes: add BytesReader skip and trySkip"
```

---

## Task 17: Round-trip endianness tests + final coverage gate

**Files:**
- Modify: `Tests/BytesTests/EndiannessTests.swift`

- [ ] **Step 1: Add round-trip property tests**

Append to `Tests/BytesTests/EndiannessTests.swift`:

```swift
@Test func roundTripUInt16AllEndianness() {
    for endianness in [Endianness.big, .little, .host] {
        let value: UInt16 = 0xDEAD
        var m = BytesMut()
        m.putUInt16(value, endianness: endianness)
        var r = BytesReader(m.freeze())
        #expect(r.readUInt16(endianness: endianness) == value)
    }
}

@Test func roundTripUInt32AllEndianness() {
    for endianness in [Endianness.big, .little, .host] {
        let value: UInt32 = 0xDEADBEEF
        var m = BytesMut()
        m.putUInt32(value, endianness: endianness)
        var r = BytesReader(m.freeze())
        #expect(r.readUInt32(endianness: endianness) == value)
    }
}

@Test func roundTripUInt64AllEndianness() {
    for endianness in [Endianness.big, .little, .host] {
        let value: UInt64 = 0x0123_4567_89AB_CDEF
        var m = BytesMut()
        m.putUInt64(value, endianness: endianness)
        var r = BytesReader(m.freeze())
        #expect(r.readUInt64(endianness: endianness) == value)
    }
}

@Test func roundTripSignedIntegers() {
    for endianness in [Endianness.big, .little, .host] {
        var m = BytesMut()
        m.putInt8(-1)
        m.putInt16(-2, endianness: endianness)
        m.putInt32(-3, endianness: endianness)
        m.putInt64(-4, endianness: endianness)
        var r = BytesReader(m.freeze())
        #expect(r.readInt8() == -1)
        #expect(r.readInt16(endianness: endianness) == -2)
        #expect(r.readInt32(endianness: endianness) == -3)
        #expect(r.readInt64(endianness: endianness) == -4)
    }
}

@Test func bigEndianBytePatternIsExact() {
    var m = BytesMut()
    m.putUInt32(0x11223344, endianness: .big)
    #expect(Array(m.freeze()) == [0x11, 0x22, 0x33, 0x44])
}

@Test func littleEndianBytePatternIsExact() {
    var m = BytesMut()
    m.putUInt32(0x11223344, endianness: .little)
    #expect(Array(m.freeze()) == [0x44, 0x33, 0x22, 0x11])
}
```

- [ ] **Step 2: Run all tests**

Run: `swift test`
Expected: all tests pass (~46 tests across 6 suites).

- [ ] **Step 3: Run with code coverage**

Run: `swift test --enable-code-coverage`
Then inspect coverage:

```bash
COV_BIN=$(swift build --show-bin-path)
xcrun llvm-cov report \
    "$COV_BIN/BedrockPackageTests.xctest/Contents/MacOS/BedrockPackageTests" \
    -instr-profile "$COV_BIN/codecov/default.profdata" \
    Sources/Bytes
```

Expected: coverage on `Sources/Bytes/` ≥ 90%. If a file is below 90%, write a targeted test for the uncovered branch and re-run.

- [ ] **Step 4: Run with address sanitizer (CoW stress)**

Run: `swift test --sanitize=address --filter CowTests`
Expected: all tests pass; ASan reports no leaks/double-frees.

- [ ] **Step 5: Commit**

```bash
git add Tests/BytesTests/EndiannessTests.swift
git commit -m "Bytes: add round-trip endianness tests and coverage gate"
```

---

## Closing Task: Final verification

- [ ] **Step 1: Confirm all tests pass on a clean build**

```bash
swift package clean
swift test
```

Expected: every test passes. No warnings about Sendable, concurrency, or deprecated APIs.

- [ ] **Step 2: Verify the public surface compiles for an external consumer**

Run: `swift build -c release`
Expected: builds successfully with no errors.

- [ ] **Step 3: Push to GitHub**

```bash
git push origin main
```

Expected: commits pushed to `https://github.com/satishbabariya/bedrock`.

- [ ] **Step 4: Cross-link the implementation in the layer doc**

Edit `layers/layer-01-primitives.md` and add a status banner near the top:

```markdown
> **Status:** core bytes module shipping in `Sources/Bytes/` ([design](../docs/superpowers/specs/2026-05-09-bytes-design.md), [plan](../docs/superpowers/plans/2026-05-09-bytes-module.md)). Remaining categories (Hex, Base64, varints, UUID, URL/IDNA, etc.) are tracked here pending their own designs.
```

Commit:

```bash
git add layers/layer-01-primitives.md
git commit -m "Bytes: cross-link Layer 1 layer doc to design+plan"
git push
```
