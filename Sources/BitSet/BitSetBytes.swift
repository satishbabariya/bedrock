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
