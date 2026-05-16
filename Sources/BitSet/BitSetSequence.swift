extension BitSet: Sequence {
    // Element = Int is already declared via SetAlgebra conformance.

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
