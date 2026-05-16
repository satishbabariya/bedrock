# BitSet Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a stdlib-only `BitSet` module — a growable set of non-negative `Int` bit positions stored as packed 64-bit words, conforming to `SetAlgebra`, with `Bytes` interop.

**Architecture:** `public struct BitSet` backed by `[UInt64]`. Word-parallel set operations via bitwise ops on whole words. `Sequence` conformance via a custom iterator using `trailingZeroBitCount`. Canonical `==`/`hash(into:)` ignore trailing zero words. Little-endian byte packing for `Bytes` interop.

**Tech Stack:** Swift 6 (toolchain ≥ 6.0), SwiftPM, Swift Testing. Depends only on `Bytes`. No third-party dependencies, no Foundation.

**Source spec:** `docs/superpowers/specs/2026-05-16-bitset-design.md`.

**Working directory:** `/Users/satishbabariya/Desktop/Bedrock`. Run all `swift` commands from there.

---

## Task 1: Package scaffolding

**Files:**
- Modify: `Package.swift`
- Create: `Sources/BitSet/BitSet.swift` (placeholder)
- Create: `Tests/BitSetTests/SmokeTest.swift`

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
        .library(name: "BitSet", targets: ["BitSet"]),
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

        .target(name: "BitSet", dependencies: ["Bytes"], path: "Sources/BitSet"),
        .testTarget(name: "BitSetTests", dependencies: ["BitSet", "Bytes"], path: "Tests/BitSetTests"),
    ]
)
```

- [ ] **Step 2: Create placeholder source file**

Create `Sources/BitSet/BitSet.swift`:

```swift
// BitSet — implemented in Task 2+.
@usableFromInline internal let _bitSetModuleLoaded = true
```

- [ ] **Step 3: Create the smoke test**

Create `Tests/BitSetTests/SmokeTest.swift`:

```swift
import Testing
@testable import BitSet

@Test func bitSetModuleLoads() {
    #expect(_bitSetModuleLoaded == true)
}
```

- [ ] **Step 4: Verify build + tests**

Run: `swift test`
Expected: all prior tests pass + 1 new smoke test.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/BitSet Tests/BitSetTests
git commit -m "BitSet: scaffold module and smoke test"
```

---

## Task 2: BitSet core (struct + Word helpers + basic state)

**Files:**
- Create: `Sources/BitSet/Internal/Word.swift`
- Modify: `Sources/BitSet/BitSet.swift` (replace placeholder)
- Create: `Tests/BitSetTests/BitSetMembershipTests.swift` (basic empty-state tests)
- Modify: `Tests/BitSetTests/SmokeTest.swift` (replace stale reference)

- [ ] **Step 1: Write the failing tests**

Create `Tests/BitSetTests/BitSetMembershipTests.swift`:

```swift
import Testing
import Bytes
@testable import BitSet

@Test func emptyBitSetState() {
    let s = BitSet()
    #expect(s.count == 0)
    #expect(s.isEmpty == true)
}

@Test func initFromSequence() {
    let s = BitSet([1, 3, 5])
    #expect(s.count == 3)
    #expect(s.isEmpty == false)
}

@Test func initFromEmptySequence() {
    let s = BitSet([Int]())
    #expect(s.count == 0)
    #expect(s.isEmpty == true)
}

@Test func initWithMinimumCapacity() {
    let s = BitSet(minimumCapacity: 1000)
    #expect(s.count == 0)
    #expect(s.isEmpty == true)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter BitSetMembershipTests`
Expected: compile errors — `BitSet` not defined.

- [ ] **Step 3: Implement the Word helpers**

Create `Sources/BitSet/Internal/Word.swift`:

```swift
/// Number of bits per backing word.
@usableFromInline internal let bitsPerWord = 64

/// Word index containing `bit`.
@inline(__always)
@usableFromInline
internal func wordIndex(_ bit: Int) -> Int { bit / bitsPerWord }

/// Bit position within its word (0...63).
@inline(__always)
@usableFromInline
internal func bitOffset(_ bit: Int) -> Int { bit % bitsPerWord }

/// Mask isolating `bit`'s position within its word.
@inline(__always)
@usableFromInline
internal func bitMask(_ bit: Int) -> UInt64 { UInt64(1) << bitOffset(bit) }
```

- [ ] **Step 4: Implement BitSet core**

Replace `Sources/BitSet/BitSet.swift` with:

```swift
import Bytes

/// A growable set of non-negative `Int` bit positions, stored as packed
/// 64-bit words. Behaves like `Set<Int>` but with O(1) per-bit operations
/// and word-parallel set algebra.
public struct BitSet: Sendable, Hashable {

    /// 64-bit words, little-endian bit packing within each word
    /// (word[0] bit 0 = position 0; word[0] bit 63 = position 63;
    /// word[1] bit 0 = position 64; ...).
    @usableFromInline internal var storage: [UInt64]

    @usableFromInline
    internal init(storage: [UInt64]) {
        self.storage = storage
    }

    /// An empty BitSet. No allocation.
    public init() { self.storage = [] }

    /// Construct from any sequence of non-negative bit positions.
    /// Negative positions trap (precondition).
    public init<S: Sequence>(_ bits: S) where S.Element == Int {
        self.storage = []
        for b in bits {
            precondition(b >= 0, "BitSet positions must be non-negative")
            let wIdx = wordIndex(b)
            if wIdx >= storage.count {
                storage.append(contentsOf:
                    Array(repeating: 0, count: wIdx + 1 - storage.count))
            }
            storage[wIdx] |= bitMask(b)
        }
    }

    /// Pre-allocate storage to hold positions up to (but not including)
    /// `minimumCapacity`. Allocations of size < this never grow.
    public init(minimumCapacity: Int) {
        precondition(minimumCapacity >= 0, "minimumCapacity must be non-negative")
        let wordCount = (minimumCapacity + bitsPerWord - 1) / bitsPerWord
        self.storage = Array(repeating: 0, count: wordCount)
    }

    /// Number of bit positions in the set (popcount across all words).
    public var count: Int {
        var total = 0
        for w in storage { total += w.nonzeroBitCount }
        return total
    }

    /// `true` if no bits are set.
    public var isEmpty: Bool {
        for w in storage where w != 0 { return false }
        return true
    }
}
```

- [ ] **Step 5: Update the smoke test**

Replace `Tests/BitSetTests/SmokeTest.swift` with:

```swift
import Testing
@testable import BitSet

@Test func bitSetNamespaceExists() {
    let _ = BitSet()
    #expect(true)
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `swift test --filter BitSetTests`
Expected: 5 tests pass (1 smoke + 4 from membership tests).

- [ ] **Step 7: Commit**

```bash
git add Sources/BitSet Tests/BitSetTests
git commit -m "BitSet: add core struct with storage, inits, count, isEmpty"
```

---

## Task 3: Membership (contains/insert/remove/toggle/update)

**Files:**
- Create: `Sources/BitSet/BitSetMembership.swift`
- Modify: `Tests/BitSetTests/BitSetMembershipTests.swift` (append tests)

- [ ] **Step 1: Append the failing tests**

Append to `Tests/BitSetTests/BitSetMembershipTests.swift`:

```swift
@Test func containsAndInsertSingleBit() {
    var s = BitSet()
    #expect(s.contains(7) == false)
    let result = s.insert(7)
    #expect(result.inserted == true)
    #expect(result.memberAfterInsert == 7)
    #expect(s.contains(7) == true)
    #expect(s.count == 1)
}

@Test func insertExistingReturnsFalse() {
    var s = BitSet([7])
    let result = s.insert(7)
    #expect(result.inserted == false)
    #expect(result.memberAfterInsert == 7)
    #expect(s.count == 1)
}

@Test func insertAcrossWordBoundary() {
    var s = BitSet()
    s.insert(7)
    s.insert(64)
    s.insert(128)
    #expect(s.count == 3)
    #expect(s.contains(7))
    #expect(s.contains(64))
    #expect(s.contains(128))
    #expect(s.contains(63) == false)
}

@Test func removeReturnsValueOrNil() {
    var s = BitSet([7])
    #expect(s.remove(7) == 7)
    #expect(s.remove(7) == nil)
    #expect(s.contains(7) == false)
}

@Test func toggleSetsAndClears() {
    var s = BitSet()
    s.toggle(3)
    #expect(s.contains(3))
    s.toggle(3)
    #expect(s.contains(3) == false)
}

@Test func containsBeyondStorageReturnsFalse() {
    let s = BitSet()
    // No allocation triggered; should just return false.
    #expect(s.contains(1_000_000) == false)
}

@Test func removeNegativeReturnsNil() {
    var s = BitSet([1, 2, 3])
    // Set.remove convention: nil for missing element, no trap on negative.
    #expect(s.remove(-1) == nil)
}

@Test func updateReturnsNilOnFirstInsert() {
    var s = BitSet()
    #expect(s.update(with: 5) == nil)
    #expect(s.update(with: 5) == 5)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter BitSetMembershipTests`
Expected: compile errors — `contains`/`insert`/`remove`/`toggle`/`update` not defined.

- [ ] **Step 3: Implement membership**

Create `Sources/BitSet/BitSetMembership.swift`:

```swift
extension BitSet {

    /// Returns `true` if `bit` is set. Returns `false` for positions past
    /// the highest allocated word. Traps on negative `bit`.
    public func contains(_ bit: Int) -> Bool {
        precondition(bit >= 0, "BitSet positions must be non-negative")
        let wIdx = wordIndex(bit)
        guard wIdx < storage.count else { return false }
        return (storage[wIdx] & bitMask(bit)) != 0
    }

    /// Sets `bit`, growing storage as needed. Traps on negative `bit`.
    /// Returns `(inserted: false, memberAfterInsert: bit)` if `bit` was
    /// already present, else `(inserted: true, memberAfterInsert: bit)`.
    @discardableResult
    public mutating func insert(_ bit: Int) -> (inserted: Bool, memberAfterInsert: Int) {
        precondition(bit >= 0, "BitSet positions must be non-negative")
        let wIdx = wordIndex(bit)
        if wIdx >= storage.count {
            storage.append(contentsOf:
                Array(repeating: 0, count: wIdx + 1 - storage.count))
        }
        let mask = bitMask(bit)
        let already = (storage[wIdx] & mask) != 0
        storage[wIdx] |= mask
        return (inserted: !already, memberAfterInsert: bit)
    }

    /// Clears `bit`. Returns the removed position or nil if it wasn't set.
    /// Negative positions return nil without trapping (matches `Set.remove`).
    @discardableResult
    public mutating func remove(_ bit: Int) -> Int? {
        guard bit >= 0 else { return nil }
        let wIdx = wordIndex(bit)
        guard wIdx < storage.count else { return nil }
        let mask = bitMask(bit)
        guard (storage[wIdx] & mask) != 0 else { return nil }
        storage[wIdx] &= ~mask
        return bit
    }

    /// `SetAlgebra` ceremony: insert and return nil if newly inserted,
    /// otherwise return the value that was already present.
    @discardableResult
    public mutating func update(with bit: Int) -> Int? {
        let result = insert(bit)
        return result.inserted ? nil : bit
    }

    /// Flip the state of `bit`. Traps on negative `bit`.
    public mutating func toggle(_ bit: Int) {
        precondition(bit >= 0, "BitSet positions must be non-negative")
        let wIdx = wordIndex(bit)
        if wIdx >= storage.count {
            storage.append(contentsOf:
                Array(repeating: 0, count: wIdx + 1 - storage.count))
        }
        storage[wIdx] ^= bitMask(bit)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter BitSetMembershipTests`
Expected: all 12 membership tests pass (4 prior + 8 new).

- [ ] **Step 5: Commit**

```bash
git add Sources/BitSet/BitSetMembership.swift Tests/BitSetTests/BitSetMembershipTests.swift
git commit -m "BitSet: add membership ops (contains/insert/remove/update/toggle)"
```

---

## Task 4: SetAlgebra + operators + ExpressibleByArrayLiteral

**Files:**
- Create: `Sources/BitSet/BitSetSetAlgebra.swift`
- Create: `Tests/BitSetTests/BitSetSetAlgebraTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/BitSetTests/BitSetSetAlgebraTests.swift`:

```swift
import Testing
@testable import BitSet

@Test func arrayLiteralInit() {
    let s: BitSet = [1, 3, 5]
    #expect(s.contains(1))
    #expect(s.contains(3))
    #expect(s.contains(5))
    #expect(s.count == 3)
}

@Test func unionMatchesHandComputed() {
    let a: BitSet = [1, 3, 5]
    let b: BitSet = [3, 5, 7]
    let u = a.union(b)
    #expect(u.count == 4)
    for bit in [1, 3, 5, 7] { #expect(u.contains(bit)) }
}

@Test func intersectionMatchesHandComputed() {
    let a: BitSet = [1, 3, 5]
    let b: BitSet = [3, 5, 7]
    let i = a.intersection(b)
    #expect(i.count == 2)
    for bit in [3, 5] { #expect(i.contains(bit)) }
    #expect(i.contains(1) == false)
    #expect(i.contains(7) == false)
}

@Test func subtractingMatchesHandComputed() {
    let a: BitSet = [1, 3, 5]
    let b: BitSet = [3, 5, 7]
    let d = a.subtracting(b)
    #expect(d.count == 1)
    #expect(d.contains(1))
}

@Test func symmetricDifferenceMatchesHandComputed() {
    let a: BitSet = [1, 3, 5]
    let b: BitSet = [3, 5, 7]
    let sd = a.symmetricDifference(b)
    #expect(sd.count == 2)
    #expect(sd.contains(1))
    #expect(sd.contains(7))
    #expect(sd.contains(3) == false)
    #expect(sd.contains(5) == false)
}

@Test func operatorsMatchMethodForm() {
    let a: BitSet = [1, 3, 5]
    let b: BitSet = [3, 5, 7]
    #expect(a | b == a.union(b))
    #expect(a & b == a.intersection(b))
    #expect(a - b == a.subtracting(b))
    #expect(a ^ b == a.symmetricDifference(b))
}

@Test func inPlaceFormsMutate() {
    var a: BitSet = [1, 3, 5]
    var b = a
    b.formUnion([7])
    a |= [7]
    #expect(a == b)
    #expect(a.contains(7))
}

@Test func subsetSupersetDisjoint() {
    let small: BitSet = [1, 3]
    let big: BitSet = [1, 3, 5, 7]
    let other: BitSet = [2, 4]
    #expect(small.isSubset(of: big))
    #expect(big.isSuperset(of: small))
    #expect(small.isStrictSubset(of: big))
    #expect(big.isStrictSuperset(of: small))
    #expect(small.isDisjoint(with: other))
    #expect(big.isDisjoint(with: other) == false)
}

@Test func selfOperationsAreIdentitiesOrEmpty() {
    let a: BitSet = [1, 3, 5]
    #expect(a.union(a) == a)
    #expect(a.intersection(a) == a)
    #expect(a.subtracting(a).isEmpty)
    #expect(a.symmetricDifference(a).isEmpty)
}

@Test func unionWithEmpty() {
    let a: BitSet = [1, 2, 3]
    let empty = BitSet()
    #expect(empty.union(a) == a)
    #expect(a.union(empty) == a)
}

@Test func mismatchedLengthOperands() {
    // One operand spans many words; the other is short.
    let big = BitSet((0..<200).map { $0 })
    let small: BitSet = [1, 100, 199]
    let u = big.union(small)
    #expect(u.count == 200)
    let i = big.intersection(small)
    #expect(i == small)
    let d = small.subtracting(big)
    #expect(d.isEmpty)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter BitSetSetAlgebraTests`
Expected: compile errors — SetAlgebra methods not implemented and ExpressibleByArrayLiteral not declared.

- [ ] **Step 3: Implement SetAlgebra + operators**

Create `Sources/BitSet/BitSetSetAlgebra.swift`:

```swift
extension BitSet: SetAlgebra {
    public typealias Element = Int
    public typealias ArrayLiteralElement = Int

    /// Sets the receiver to the union of itself and `other`.
    public mutating func formUnion(_ other: BitSet) {
        if other.storage.count > storage.count {
            storage.append(contentsOf:
                Array(repeating: 0, count: other.storage.count - storage.count))
        }
        for i in 0..<other.storage.count {
            storage[i] |= other.storage[i]
        }
    }

    /// Sets the receiver to the intersection of itself and `other`.
    public mutating func formIntersection(_ other: BitSet) {
        let common = Swift.min(storage.count, other.storage.count)
        // Truncate tail (any bits past `common` in self become implicit zero).
        if storage.count > common {
            storage.removeLast(storage.count - common)
        }
        for i in 0..<common {
            storage[i] &= other.storage[i]
        }
    }

    /// Sets the receiver to bits in either input but not both.
    public mutating func formSymmetricDifference(_ other: BitSet) {
        if other.storage.count > storage.count {
            storage.append(contentsOf:
                Array(repeating: 0, count: other.storage.count - storage.count))
        }
        for i in 0..<other.storage.count {
            storage[i] ^= other.storage[i]
        }
    }
}

extension BitSet: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Int...) { self.init(elements) }
}

// Convenience operators (not part of SetAlgebra).
extension BitSet {
    public static func | (lhs: BitSet, rhs: BitSet) -> BitSet { lhs.union(rhs) }
    public static func & (lhs: BitSet, rhs: BitSet) -> BitSet { lhs.intersection(rhs) }
    public static func - (lhs: BitSet, rhs: BitSet) -> BitSet { lhs.subtracting(rhs) }
    public static func ^ (lhs: BitSet, rhs: BitSet) -> BitSet { lhs.symmetricDifference(rhs) }

    public static func |= (lhs: inout BitSet, rhs: BitSet) { lhs.formUnion(rhs) }
    public static func &= (lhs: inout BitSet, rhs: BitSet) { lhs.formIntersection(rhs) }
    public static func -= (lhs: inout BitSet, rhs: BitSet) { lhs.subtract(rhs) }
    public static func ^= (lhs: inout BitSet, rhs: BitSet) { lhs.formSymmetricDifference(rhs) }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter BitSetSetAlgebraTests`
Expected: all 11 SetAlgebra tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/BitSet/BitSetSetAlgebra.swift Tests/BitSetTests/BitSetSetAlgebraTests.swift
git commit -m "BitSet: add SetAlgebra conformance, operators, and array literal init"
```

---

## Task 5: Sequence + Iterator + first/last

**Files:**
- Create: `Sources/BitSet/BitSetSequence.swift`
- Create: `Tests/BitSetTests/BitSetSequenceTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/BitSetTests/BitSetSequenceTests.swift`:

```swift
import Testing
@testable import BitSet

@Test func iteratesAscending() {
    let s: BitSet = [5, 1, 3]
    let arr = Array(s)
    #expect(arr == [1, 3, 5])
}

@Test func iteratesAcrossWordBoundaries() {
    let s: BitSet = [0, 63, 64, 127, 128]
    let arr = Array(s)
    #expect(arr == [0, 63, 64, 127, 128])
}

@Test func iteratesEmpty() {
    let s = BitSet()
    let arr = Array(s)
    #expect(arr == [])
}

@Test func iteratesLargeSet() {
    let positions = [0, 1, 2, 7, 64, 99, 128, 255, 500]
    let s = BitSet(positions)
    #expect(Array(s) == positions.sorted())
}

@Test func firstAndLast() {
    let s: BitSet = [10, 3, 100, 50]
    #expect(s.first == 3)
    #expect(s.last == 100)
}

@Test func firstAndLastEmpty() {
    let s = BitSet()
    #expect(s.first == nil)
    #expect(s.last == nil)
}

@Test func mapWorks() {
    let s: BitSet = [1, 2, 3]
    let doubled = s.map { $0 * 2 }
    #expect(doubled == [2, 4, 6])
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter BitSetSequenceTests`
Expected: compile errors — Sequence/first/last not defined.

- [ ] **Step 3: Implement Sequence + first + last**

Create `Sources/BitSet/BitSetSequence.swift`:

```swift
extension BitSet: Sequence {
    public typealias Element = Int

    public struct Iterator: IteratorProtocol {
        public typealias Element = Int

        @usableFromInline internal let words: [UInt64]
        @usableFromInline internal var wordIdx: Int = 0
        @usableFromInline internal var current: UInt64 = 0
        @usableFromInline internal var loaded: Bool = false

        @usableFromInline
        internal init(words: [UInt64]) {
            self.words = words
        }

        @inlinable
        public mutating func next() -> Int? {
            // Load the next non-zero word if needed.
            while !loaded || current == 0 {
                if wordIdx >= words.count { return nil }
                current = words[wordIdx]
                wordIdx += 1
                loaded = true
                // Loop continues if `current == 0` (skip empty words in O(1)).
            }
            let tz = current.trailingZeroBitCount
            current &= current &- 1           // clear lowest set bit
            return (wordIdx - 1) * bitsPerWord + tz
        }
    }

    public func makeIterator() -> Iterator {
        Iterator(words: storage)
    }
}

extension BitSet {

    /// The lowest set bit, or nil if empty.
    public var first: Int? {
        for (i, w) in storage.enumerated() where w != 0 {
            return i * bitsPerWord + w.trailingZeroBitCount
        }
        return nil
    }

    /// The highest set bit, or nil if empty.
    public var last: Int? {
        // Walk storage backwards for the last non-zero word.
        var i = storage.count - 1
        while i >= 0 {
            let w = storage[i]
            if w != 0 {
                // Position of highest set bit in word: 63 - leadingZeroBitCount.
                return i * bitsPerWord + (bitsPerWord - 1 - w.leadingZeroBitCount)
            }
            i -= 1
        }
        return nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter BitSetSequenceTests`
Expected: all 7 sequence tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/BitSet/BitSetSequence.swift Tests/BitSetTests/BitSetSequenceTests.swift
git commit -m "BitSet: add Sequence conformance with first/last"
```

---

## Task 6: Canonical Hashable / Equatable

**Files:**
- Modify: `Sources/BitSet/BitSet.swift` (append custom `==` and `hash(into:)`)
- Create: `Tests/BitSetTests/BitSetConformanceTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/BitSetTests/BitSetConformanceTests.swift`:

```swift
import Testing
@testable import BitSet

@Test func equalForSameBits() {
    let a: BitSet = [1, 2, 3]
    let b: BitSet = [1, 2, 3]
    #expect(a == b)
}

@Test func unequalForDifferentBits() {
    let a: BitSet = [1, 2, 3]
    let b: BitSet = [1, 2, 4]
    #expect(a != b)
}

@Test func equalDespiteTrailingZeroWords() {
    var a = BitSet([1, 2, 3])
    var b = BitSet([1, 2, 3])
    // Force `b` to have extra trailing zero words by inserting then removing
    // a bit in a high word.
    b.insert(1000)
    b.remove(1000)
    // Storage diverges (b has more trailing zero words), but logical sets match.
    #expect(a.storage.count != b.storage.count)
    #expect(a == b)
    // And hashing is consistent.
    var seen: Set<BitSet> = []
    seen.insert(a)
    #expect(seen.contains(b))
}

@Test func emptyBitSetsAllEqual() {
    let a = BitSet()
    let b = BitSet([Int]())
    var c = BitSet([5])
    c.remove(5)
    #expect(a == b)
    #expect(b == c)
}

@Test func sendableConformance() async {
    // Compile-time check: BitSet must be Sendable to cross actor boundaries.
    let s: BitSet = [1, 2, 3]
    let result = await withCheckedContinuation { (cont: CheckedContinuation<Int, Never>) in
        Task.detached {
            cont.resume(returning: s.count)
        }
    }
    #expect(result == 3)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter BitSetConformanceTests`
Expected: `equalDespiteTrailingZeroWords` fails — the synthesized `==` compares storage arrays element-wise, treating `[1]` and `[1, 0]` as unequal.

- [ ] **Step 3: Implement canonical == and hash(into:)**

Append to `Sources/BitSet/BitSet.swift`:

```swift
extension BitSet {

    /// Index of the highest word containing any set bits, or -1 if all zero.
    @usableFromInline
    internal func lastNonZeroWordIndex() -> Int {
        var i = storage.count - 1
        while i >= 0 {
            if storage[i] != 0 { return i }
            i -= 1
        }
        return -1
    }

    /// Canonical equality: ignores trailing zero words.
    public static func == (lhs: BitSet, rhs: BitSet) -> Bool {
        let lLast = lhs.lastNonZeroWordIndex()
        let rLast = rhs.lastNonZeroWordIndex()
        if lLast != rLast { return false }
        if lLast < 0 { return true }   // both empty
        for i in 0...lLast {
            if lhs.storage[i] != rhs.storage[i] { return false }
        }
        return true
    }

    /// Canonical hash: only words up through the last non-zero index contribute.
    public func hash(into hasher: inout Hasher) {
        let last = lastNonZeroWordIndex()
        if last < 0 { return }   // empty: contribute nothing
        for i in 0...last {
            hasher.combine(storage[i])
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter BitSetConformanceTests`
Expected: all 5 conformance tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/BitSet/BitSet.swift Tests/BitSetTests/BitSetConformanceTests.swift
git commit -m "BitSet: canonical == and hash(into:) ignore trailing zero words"
```

---

## Task 7: Bytes interop + description

**Files:**
- Create: `Sources/BitSet/BitSetBytes.swift`
- Create: `Tests/BitSetTests/BitSetBytesTests.swift`
- Modify: `Tests/BitSetTests/BitSetConformanceTests.swift` (append description test)

- [ ] **Step 1: Write the failing tests**

Create `Tests/BitSetTests/BitSetBytesTests.swift`:

```swift
import Testing
import Bytes
@testable import BitSet

@Test func bitZeroBytes() {
    let s: BitSet = [0]
    #expect(Array(s.bytes) == [0x01])
}

@Test func bitSevenBytes() {
    let s: BitSet = [7]
    #expect(Array(s.bytes) == [0x80])
}

@Test func bitEightBytes() {
    let s: BitSet = [8]
    #expect(Array(s.bytes) == [0x00, 0x01])
}

@Test func emptyBytes() {
    let s = BitSet()
    #expect(Array(s.bytes) == [])
}

@Test func multipleBitsInOneByte() {
    let s: BitSet = [0, 1]
    let bytes = Array(s.bytes)
    #expect(bytes == [0x03])
    #expect(bytes.count == 1)
}

@Test func trailingZeroBytesTrimmedOnEmit() {
    var s = BitSet([0, 1])
    s.insert(1000)
    s.remove(1000)
    // Storage has many words, but only bits 0 and 1 are set.
    let bytes = Array(s.bytes)
    #expect(bytes == [0x03])
}

@Test func roundTripBytePositions() throws {
    for bit in 0..<201 {
        let original: BitSet = [bit]
        let decoded = BitSet(bytes: original.bytes)
        #expect(decoded == original, "round-trip failed for bit \(bit)")
    }
}

@Test func decodeAcceptsTrailingZeroBytes() {
    let s = BitSet(bytes: Bytes([0x00, 0x00, 0x00]))
    #expect(s.isEmpty)
}

@Test func roundTripDeterministicBuffer() throws {
    // Build a BitSet from a known byte buffer; encode; verify identical bytes.
    var state: UInt64 = 0xABCD_EF01_2345_6789
    func next() -> UInt8 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return UInt8((state >> 56) & 0xFF)
    }
    var raw: [UInt8] = []
    raw.reserveCapacity(256)
    for _ in 0..<256 { raw.append(next()) }
    // Ensure the last byte is non-zero so no trim occurs on round-trip.
    raw[raw.count - 1] |= 0x01
    let original = Bytes(raw)
    let s = BitSet(bytes: original)
    #expect(s.bytes == original)
}
```

Append to `Tests/BitSetTests/BitSetConformanceTests.swift`:

```swift
@Test func descriptionFormat() {
    let s: BitSet = [3, 1, 7]
    #expect(s.description == "BitSet{1, 3, 7}")
}

@Test func descriptionEmpty() {
    let s = BitSet()
    #expect(s.description == "BitSet{}")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter BitSetTests`
Expected: compile errors — `bytes`, `init(bytes:)`, `description` not defined.

- [ ] **Step 3: Implement Bytes interop + description**

Create `Sources/BitSet/BitSetBytes.swift`:

```swift
import Bytes

extension BitSet {

    /// Construct from packed bytes (little-endian bit ordering).
    /// Trailing zero bytes are accepted but redundant.
    public init(bytes: Bytes) {
        var words: [UInt64] = []
        let wordCount = (bytes.count + 7) / 8
        words.reserveCapacity(wordCount)
        bytes.withUnsafeBytes { src in
            var i = 0
            while i < src.count {
                var w: UInt64 = 0
                let take = Swift.min(8, src.count - i)
                for j in 0..<take {
                    w |= UInt64(src[i + j]) << (j * 8)
                }
                words.append(w)
                i += 8
            }
        }
        self.storage = words
    }

    /// Emit packed bytes. Trailing zero bytes are trimmed.
    /// An empty BitSet returns `Bytes()`.
    public var bytes: Bytes {
        let lastWord = lastNonZeroWordIndex()
        if lastWord < 0 { return Bytes() }
        var out: [UInt8] = []
        out.reserveCapacity((lastWord + 1) * 8)
        for i in 0...lastWord {
            let w = storage[i]
            for j in 0..<8 {
                out.append(UInt8((w >> (j * 8)) & 0xFF))
            }
        }
        // Trim trailing zero bytes (final word's high bytes may be zero).
        while let tail = out.last, tail == 0 {
            out.removeLast()
        }
        return Bytes(out)
    }
}

extension BitSet: CustomStringConvertible {
    /// `"BitSet{1, 3, 7}"` (ascending order).
    public var description: String {
        let elements = self.map(String.init).joined(separator: ", ")
        return "BitSet{\(elements)}"
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter BitSetTests`
Expected: all BitSet tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/BitSet/BitSetBytes.swift Tests/BitSetTests/BitSetBytesTests.swift Tests/BitSetTests/BitSetConformanceTests.swift
git commit -m "BitSet: add Bytes interop and CustomStringConvertible"
```

---

## Task 8: Final verification + cross-link + push

**Files:**
- Modify: `layers/layer-01-primitives.md`

- [ ] **Step 1: Run the full suite on a clean build**

```bash
swift package clean
swift test
```

Expected: every test passes. Total ≈ 343 tests.

- [ ] **Step 2: Check coverage**

```bash
swift test --enable-code-coverage
COV_BIN=$(swift build --show-bin-path)
xcrun llvm-cov report \
    "$COV_BIN/BedrockPackageTests.xctest/Contents/MacOS/BedrockPackageTests" \
    -instr-profile "$COV_BIN/codecov/default.profdata" \
    Sources/BitSet
```

Expected: coverage on `Sources/BitSet/` ≥ 90%. **Report the table.** If a file is below 90%, identify the gap.

- [ ] **Step 3: Verify release build**

Run: `swift build -c release`
Expected: build succeeds with no errors or new warnings.

- [ ] **Step 4: Update the Layer 1 status banner**

Open `layers/layer-01-primitives.md`. Find the existing status banner (the multi-line `> **Status:**` block listing Bytes/Hex/Base64/UUID/Varint/PercentEncoding). Replace it with:

```markdown
> **Status:** shipping modules:
> - `Sources/Bytes/` — core bytes ([design](../docs/superpowers/specs/2026-05-09-bytes-design.md), [plan](../docs/superpowers/plans/2026-05-09-bytes-module.md))
> - `Sources/Hex/` — hex codec ([design](../docs/superpowers/specs/2026-05-10-hex-base64-design.md), [plan](../docs/superpowers/plans/2026-05-10-hex-base64-modules.md))
> - `Sources/Base64/` — base64 codec, including constant-time decode ([same design + plan](../docs/superpowers/specs/2026-05-10-hex-base64-design.md))
> - `Sources/UUID/` — UUID type with v4/v7/v8 generation; v1/v3/v5/v6 parse/inspect work, generation deferred to follow-up patches when Layer 8 (MAC) and Layer 12 (MD5/SHA-1) ship ([design](../docs/superpowers/specs/2026-05-10-uuid-design.md), [plan](../docs/superpowers/plans/2026-05-10-uuid-module.md))
> - `Sources/Varint/` — LEB128 unsigned + ZigZag-LEB128 signed for UInt32/UInt64/Int32/Int64 ([design](../docs/superpowers/specs/2026-05-12-varint-design.md), [plan](../docs/superpowers/plans/2026-05-12-varint-module.md))
> - `Sources/PercentEncoding/` — RFC 3986 + x-www-form-urlencoded byte codec with per-component named sets ([design](../docs/superpowers/specs/2026-05-16-percent-encoding-design.md), [plan](../docs/superpowers/plans/2026-05-16-percent-encoding-module.md))
> - `Sources/BitSet/` — growable bit-array with SetAlgebra conformance and Bytes interop ([design](../docs/superpowers/specs/2026-05-16-bitset-design.md), [plan](../docs/superpowers/plans/2026-05-16-bitset-module.md))
>
> Remaining categories (SIMD UTF-8, COBS, URL/IDNA) pending their own designs.
```

- [ ] **Step 5: Commit and push**

```bash
git add layers/layer-01-primitives.md
git commit -m "BitSet: cross-link Layer 1 doc to BitSet module design+plan"
git push origin main
```

Expected: push succeeds.
