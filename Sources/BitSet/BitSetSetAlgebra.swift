extension BitSet: SetAlgebra {
    public typealias Element = Int
    public typealias ArrayLiteralElement = Int

    // MARK: - Non-mutating operations (required by SetAlgebra even though form* exists)

    /// Returns a new set with all bits from both `self` and `other`.
    public __consuming func union(_ other: __owned BitSet) -> BitSet {
        var result = self
        result.formUnion(other)
        return result
    }

    /// Returns a new set with only bits present in both `self` and `other`.
    public func intersection(_ other: BitSet) -> BitSet {
        var result = self
        result.formIntersection(other)
        return result
    }

    /// Returns a new set with bits in either `self` or `other`, but not both.
    public __consuming func symmetricDifference(_ other: __owned BitSet) -> BitSet {
        var result = self
        result.formSymmetricDifference(other)
        return result
    }

    // MARK: - Mutating operations

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
