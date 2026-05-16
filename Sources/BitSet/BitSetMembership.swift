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
