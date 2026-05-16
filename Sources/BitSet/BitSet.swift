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
