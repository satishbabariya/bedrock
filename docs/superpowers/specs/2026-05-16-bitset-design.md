# Bedrock `BitSet` Module — Design Spec

**Date:** 2026-05-16
**Layer:** 1 (Primitives, Bytes, Encodings) — *growable bit-array data structure*
**Status:** Approved, ready for implementation plan

---

## 1. Scope & Non-Goals

### In scope

- A `BitSet` value type — a growable set of non-negative `Int` indices stored as packed 64-bit words.
- `SetAlgebra` conformance for free `subtract`, `isSubset(of:)`, `isSuperset(of:)`, `isDisjoint(with:)`, and strict variants.
- Per-bit ops: `contains`, `insert`, `remove`, `update(with:)`, `toggle`.
- Bulk: `count` (popcount), `isEmpty`, `first`, `last`.
- Set ops: `union`, `intersection`, `subtracting`, `symmetricDifference` plus in-place forms; convenience operators `|`/`&`/`-`/`^` and `|=`/`&=`/`-=`/`^=`.
- `Sequence` conformance yielding the indices of set bits in ascending order.
- Conformances: `Sendable`, `Hashable`, `Equatable`, `ExpressibleByArrayLiteral`, `CustomStringConvertible` (e.g., `"BitSet{1, 3, 7}"`).
- **`Bytes` interop**: `init(bytes: Bytes)` and `var bytes: Bytes` using **little-endian bit packing** (byte 0 bit 0 = `BitSet` index 0, byte 0 bit 7 = index 7, byte 1 bit 0 = index 8, …). Trailing zero bytes trimmed on emit.
- Stdlib-only; depends only on `Bytes` from Layer 1.

### Explicitly out of scope (separate designs later)

- **`FixedBitSet`** (fixed-capacity stack-friendly variant) — YAGNI; add later as `BitSet64`/`BitSet256` if a hot path needs it.
- **Roaring bitmaps** (compressed sparse bitsets) — separate Layer 1 design, T2.
- **Bloom filters / Cuckoo filters / HyperLogLog** — Layer 3 (Collections & Data Structures).
- **`OptionSet` interop** — Swift's `OptionSet` is for typed flag enums ≤ 64 bits with its own ergonomics; no conversion provided.
- **Negative indices** — `insert(-1)` / `contains(-1)` / `toggle(-1)` trap (precondition). `remove(-1)` returns `nil` (matching `Set.remove`).
- **Async iteration** — Layer 11.
- **Range-based ops** (`insert(_: Range<Int>)`) — easy follow-up if a real consumer asks.

---

## 2. Module Layout

```
Bedrock/
└── Sources/
    └── BitSet/
        ├── BitSet.swift             # public struct BitSet + storage + init
        ├── BitSetMembership.swift   # contains/insert/remove/toggle/update
        ├── BitSetSetAlgebra.swift   # SetAlgebra conformance + operators
        ├── BitSetSequence.swift     # Sequence conformance, first/last/count
        ├── BitSetBytes.swift        # init(bytes:) / var bytes / CustomStringConvertible
        └── Internal/
            └── Word.swift           # bit-to-word arithmetic helpers
└── Tests/
    └── BitSetTests/
        ├── BitSetMembershipTests.swift
        ├── BitSetSetAlgebraTests.swift
        ├── BitSetSequenceTests.swift
        ├── BitSetBytesTests.swift
        └── BitSetConformanceTests.swift
```

`Package.swift` gains one library product `BitSet`, one source target depending only on `Bytes`, and one test target.

Six source files, five test files. ~50–120 LOC each.

---

## 3. Public API

### 3.1 `BitSet` core

```swift
// Sources/BitSet/BitSet.swift

import Bytes

/// A growable set of non-negative `Int` bit positions, stored as packed
/// 64-bit words. Behaves like `Set<Int>` but with O(1) per-bit operations
/// and word-parallel set algebra.
public struct BitSet: Sendable, Hashable {

    /// 64-bit words, little-endian bit packing within each word
    /// (word[0] bit 0 = position 0; word[0] bit 63 = position 63;
    /// word[1] bit 0 = position 64; …).
    @usableFromInline internal var storage: [UInt64]

    @usableFromInline
    internal init(storage: [UInt64]) {
        self.storage = storage
    }

    /// An empty BitSet. No allocation.
    public init() { self.storage = [] }

    /// Construct from any sequence of non-negative bit positions.
    /// Negative positions trap (precondition).
    public init<S: Sequence>(_ bits: S) where S.Element == Int

    /// Pre-allocate storage to hold positions up to (but not including)
    /// `minimumCapacity`. Allocations of size < this never grow.
    public init(minimumCapacity: Int)

    /// Number of bit positions in the set (popcount across all words).
    public var count: Int { get }

    /// `true` if no bits are set.
    public var isEmpty: Bool { get }

    /// The lowest set bit, or nil if empty.
    public var first: Int? { get }

    /// The highest set bit, or nil if empty.
    public var last: Int? { get }
}
```

### 3.2 Membership

```swift
// Sources/BitSet/BitSetMembership.swift

extension BitSet {

    /// Returns `true` if `bit` is set. Returns `false` for positions past
    /// the highest allocated word. Traps on negative `bit`.
    public func contains(_ bit: Int) -> Bool

    /// Sets `bit`, growing storage as needed. Traps on negative `bit`.
    /// Returns `(inserted: false, memberAfterInsert: bit)` if `bit` was
    /// already present, else `(inserted: true, memberAfterInsert: bit)`.
    @discardableResult
    public mutating func insert(_ bit: Int) -> (inserted: Bool, memberAfterInsert: Int)

    /// Clears `bit`. Returns the removed position or nil if it wasn't set.
    /// Negative positions return nil without trapping (matches `Set.remove`).
    @discardableResult
    public mutating func remove(_ bit: Int) -> Int?

    /// `SetAlgebra` ceremony: insert and return nil if already present,
    /// otherwise return the inserted value.
    @discardableResult
    public mutating func update(with bit: Int) -> Int?

    /// Flip the state of `bit`. Traps on negative `bit`.
    public mutating func toggle(_ bit: Int)
}
```

### 3.3 SetAlgebra + operators + array literal

```swift
// Sources/BitSet/BitSetSetAlgebra.swift

extension BitSet: SetAlgebra {
    public typealias Element = Int
    public typealias ArrayLiteralElement = Int

    /// Sets the receiver to the union of itself and `other`.
    public mutating func formUnion(_ other: BitSet)

    /// Sets the receiver to the intersection of itself and `other`.
    public mutating func formIntersection(_ other: BitSet)

    /// Sets the receiver to bits in either input but not both.
    public mutating func formSymmetricDifference(_ other: BitSet)

    // `union`, `intersection`, `symmetricDifference`, `subtracting`,
    // `subtract`, `isSubset(of:)`, `isStrictSubset(of:)`, `isSuperset(of:)`,
    // `isStrictSuperset(of:)`, `isDisjoint(with:)` come from SetAlgebra defaults.
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

### 3.4 Sequence

```swift
// Sources/BitSet/BitSetSequence.swift

extension BitSet: Sequence {
    public typealias Element = Int

    public struct Iterator: IteratorProtocol {
        public typealias Element = Int
        public mutating func next() -> Int?
    }

    public func makeIterator() -> Iterator
}
```

### 3.5 Bytes interop + description

```swift
// Sources/BitSet/BitSetBytes.swift

extension BitSet {

    /// Construct from packed bytes (little-endian bit ordering).
    /// Trailing zero bytes are accepted but redundant.
    public init(bytes: Bytes)

    /// Emit packed bytes. Trailing zero bytes are trimmed.
    /// An empty BitSet returns `Bytes()`.
    public var bytes: Bytes { get }
}

extension BitSet: CustomStringConvertible {
    /// `"BitSet{1, 3, 7}"` (ascending order).
    public var description: String { get }
}
```

### 3.6 Notes on choices

- **`SetAlgebra` conformance** gives us `subtracting`, `subtract`, `isSubset(of:)`, `isSuperset(of:)`, `isDisjoint(with:)`, and the strict variants from protocol defaults. We implement only the six required methods plus `update(with:)`.
- **`insert(_:)` returns a tuple** because `SetAlgebra` demands it. `@discardableResult` lets `s.insert(7)` stay ergonomic.
- **No `Collection` conformance.** Bit positions are sparse integer indices, not a contiguous range. `Sequence` is sufficient.
- **`contains(_:)` returns `false`** for positions past allocated storage — no allocation, no trap.
- **Negative-bit policy is asymmetric** by `SetAlgebra` convention: `insert(-1)` traps (programmer error), `contains(-1)` traps (programmer error), `toggle(-1)` traps, but `remove(-1)` returns nil (matches `Set.remove` on missing elements).
- **`bytes` trims trailing zero bytes** so the encoding is canonical. `init(bytes:)` accepts non-trimmed input.

---

## 4. Internals

### 4.1 Word layout & arithmetic

```swift
// Sources/BitSet/Internal/Word.swift

@usableFromInline internal let bitsPerWord = 64

@inline(__always)
@usableFromInline
internal func wordIndex(_ bit: Int) -> Int { bit / bitsPerWord }

@inline(__always)
@usableFromInline
internal func bitOffset(_ bit: Int) -> Int { bit % bitsPerWord }

@inline(__always)
@usableFromInline
internal func bitMask(_ bit: Int) -> UInt64 { UInt64(1) << bitOffset(bit) }
```

### 4.2 Storage canonicalization

Two `BitSet` values with the same set of bits but different trailing zero words must compare equal and hash equally. The implementation keeps storage non-canonical (any number of trailing zero words allowed) but **all observable operations canonicalize on read**:

- `count` iterates all words and sums `nonzeroBitCount` (trailing zero words contribute 0 — no special-casing needed).
- `last` skips trailing zero words.
- `Hashable`: hash by iterating the prefix up through the last non-zero word.
- `Equatable`: compare word-by-word up to `max(lhs.lastNonZeroIndex, rhs.lastNonZeroIndex)`; words past either's storage are implicit zeros.

A small helper `lastNonZeroWordIndex() -> Int` returns the highest word index with a non-zero value (or -1 if all zero) for use by `hash(into:)` and `==`.

We **don't** mutate `storage` to trim on every operation — that would defeat the no-allocation default of `insert` in steady state.

### 4.3 Growth

```swift
@usableFromInline
internal mutating func ensureWord(_ wordIdx: Int) {
    if wordIdx >= storage.count {
        storage.append(contentsOf:
            Array(repeating: 0, count: wordIdx + 1 - storage.count))
    }
}
```

`insert(_:)` calls this with the bit's word index. No doubling — bit positions are dense within their word, so we allocate exactly what's requested.

### 4.4 Iterator algorithm

```swift
public struct Iterator: IteratorProtocol {
    @usableFromInline internal let words: [UInt64]
    @usableFromInline internal var wordIdx: Int = 0
    @usableFromInline internal var current: UInt64 = 0
    @usableFromInline internal var loaded: Bool = false

    @inlinable
    public mutating func next() -> Int? {
        // Load the next non-zero word if needed.
        while !loaded || current == 0 {
            if wordIdx >= words.count { return nil }
            current = words[wordIdx]
            wordIdx += 1
            loaded = true
            // If current is 0, the loop continues to the next word.
        }
        let tz = current.trailingZeroBitCount
        current &= current &- 1           // clear lowest set bit
        return (wordIdx - 1) * bitsPerWord + tz
    }
}
```

Empty words skip in O(1). Within a word, each `next()` costs one `trailingZeroBitCount` + one `&` + one `&-`.

### 4.5 Set operation algorithms

All four set operations work word-parallel:

- **`formUnion`**: extend `self.storage` to `max(self.storage.count, other.storage.count)`, then `for i in 0..<other.storage.count { storage[i] |= other.storage[i] }`.
- **`formIntersection`**: truncate `self.storage` to `min(self.storage.count, other.storage.count)` (trailing words become implicit zero), then `for i in 0..<storage.count { storage[i] &= other.storage[i] }`.
- **`formSymmetricDifference`**: extend like union, then `for i in 0..<other.storage.count { storage[i] ^= other.storage[i] }`.
- **`subtract`**: for shared range `storage[i] &= ~other.storage[i]`; tail (in `self` only) is preserved.

All are O(n) in word count. No allocations beyond what `extend` requires.

### 4.6 Bytes interop

Bit `i` maps to byte `i / 8`, bit `i % 8` (LSB-first within a byte):

- `BitSet([0])` → `[0x01]`
- `BitSet([7])` → `[0x80]`
- `BitSet([8])` → `[0x00, 0x01]`

```swift
public init(bytes: Bytes) {
    var words: [UInt64] = []
    let wordCount = (bytes.count + 7) / 8
    words.reserveCapacity(wordCount)
    bytes.withUnsafeBytes { src in
        var i = 0
        while i < src.count {
            var w: UInt64 = 0
            let remaining = src.count - i
            let take = min(8, remaining)
            for j in 0..<take {
                w |= UInt64(src[i + j]) << (j * 8)
            }
            words.append(w)
            i += 8
        }
    }
    self.storage = words
}

public var bytes: Bytes {
    var lastNonZero = -1
    for (i, w) in storage.enumerated() where w != 0 { lastNonZero = i }
    if lastNonZero < 0 { return Bytes() }
    var out: [UInt8] = []
    out.reserveCapacity((lastNonZero + 1) * 8)
    for i in 0...lastNonZero {
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
```

### 4.7 description

```swift
public var description: String {
    let elements = self.map(String.init).joined(separator: ", ")
    return "BitSet{\(elements)}"
}
```

(`self.map` uses the iterator from §4.4.)

---

## 5. Error Model

**No errors.** The module throws nothing:

- `insert(_:)` / `toggle(_:)` / `contains(_:)` on negative indices **trap** (precondition — programmer error).
- `remove(_:)` on a negative or absent index returns `nil` (matches `Set.remove`).
- All bulk and set operations are total.
- `init(bytes:)` accepts any byte sequence (empty → empty BitSet; over-long with trailing zeros → trimmed).

There is no `BitSetError` type because there are no recoverable failures.

---

## 6. Testing Strategy

Five test files, all Swift Testing (`@Test` / `#expect`).

### 6.1 `BitSetMembershipTests` (~10 tests)
- Empty BitSet: `count == 0`, `isEmpty == true`, `contains(0) == false`, `first == nil`, `last == nil`.
- `insert(7)` then `contains(7) == true`; `insert(7)` again returns `(inserted: false, ...)`.
- `insert(64)` works across word boundary; `count` after `insert(7)` and `insert(64)` is `2`.
- `remove(7)` returns `7`; `remove(7)` again returns `nil`.
- `toggle(3)` sets then clears.
- `contains(1_000_000)` on empty BitSet returns false (no allocation).
- `remove(-1)` returns nil without trap.
- `first`/`last` correctly report lowest/highest set bit after a sequence of inserts.
- `update(with:)` returns nil on first insert, returns the value on re-insert.

### 6.2 `BitSetSetAlgebraTests` (~12 tests)
- `union`, `intersection`, `subtracting`, `symmetricDifference` on small literal sets vs hand-computed expected.
- Operators `|`, `&`, `-`, `^` produce identical results to method form.
- In-place `formUnion`, `formIntersection`, `formSymmetricDifference`, `subtract` mutate correctly.
- `isSubset(of:)`, `isSuperset(of:)`, `isDisjoint(with:)`, `isStrictSubset(of:)`, `isStrictSuperset(of:)`.
- Self-union is identity; self-intersection is identity; self-difference is empty; self-symmetric-difference is empty.
- `BitSet().union(BitSet([1,2,3]))` equals `BitSet([1,2,3])`.
- Mismatched-length operands: union with one operand 10× longer than the other still produces the right result without truncation.

### 6.3 `BitSetSequenceTests` (~6 tests)
- Iterating `[1, 3, 5]` yields `1, 3, 5` in ascending order.
- Iterating a BitSet spanning multiple words yields all positions in ascending order.
- Iterating an empty BitSet yields nothing.
- Iterating `BitSet([0, 63, 64, 127, 128])` correctly crosses every word boundary.
- `Array(s)` produces the right array.
- `s.map { $0 * 2 }` works.

### 6.4 `BitSetBytesTests` (~8 tests)
- `BitSet([0]).bytes == Bytes([0x01])`.
- `BitSet([7]).bytes == Bytes([0x80])`.
- `BitSet([8]).bytes == Bytes([0x00, 0x01])`.
- `BitSet().bytes == Bytes()`.
- Trailing-zero-byte trim: `BitSet([0, 1]).bytes` has length 1.
- Round-trip: encode then decode every byte position 0..200.
- `BitSet(bytes: Bytes([0x00, 0x00, 0x00]))` decodes to empty BitSet.
- Round-trip a 256-byte deterministic-random buffer.

### 6.5 `BitSetConformanceTests` (~6 tests)
- `BitSet([1, 2, 3]) == BitSet([1, 2, 3])`.
- `BitSet()` literal-init equals `[]`.
- Two BitSets with same set bits but different trailing zero words are equal.
- Same-bit BitSets hash equally (insert into a `Set<BitSet>`).
- `description` of `BitSet([3, 1, 7])` is `"BitSet{1, 3, 7}"`.
- `Sendable`: assignable to a `Sendable`-typed binding.

**Coverage gate:** ≥ 90% on `Sources/BitSet/`.

---

## 7. Deferrals

- **`FixedBitSet`** — fixed-capacity, stack-friendly variant. Add later if a hot path needs it.
- **Roaring bitmaps** — compressed sparse bitsets (separate Layer 1 design).
- **Bloom / Cuckoo / HyperLogLog** — probabilistic structures, Layer 3.
- **`OptionSet` interop** — `OptionSet` is for typed flag enums; no general-purpose conversion provided.
- **Range-based operations** (`insert(_: Range<Int>)`, `contains(_: Range<Int>)`) — easy follow-up if needed.
- **Word-aligned external storage views** (`init(words: [UInt64])` directly) — low value; add if a real consumer asks.
