extension TaggedPointer {

    /// Number of tag bits available, derived from `Pointee`'s alignment.
    @inlinable
    public static var tagBits: Int {
        MemoryLayout<Pointee>.alignment.trailingZeroBitCount
    }

    /// Mask of bits used for the tag (`(1 << tagBits) - 1`).
    @inlinable
    public static var tagMask: UInt {
        (1 << tagBits) - 1
    }

    /// Maximum representable tag value (same as `tagMask`).
    @inlinable
    public static var maxTag: UInt { tagMask }

    /// Derive a new tagged pointer with a different tag, same pointer.
    /// Traps if `newTag > maxTag`.
    @inlinable
    public func withTag(_ newTag: UInt) -> TaggedPointer<Pointee> {
        precondition(newTag <= Self.maxTag,
                     "tag exceeds maxTag for this Pointee alignment")
        let pointerBits = raw & ~Self.tagMask
        return TaggedPointer(rawStorage: pointerBits | newTag)
    }

    /// Derive a new tagged pointer with a different pointer, same tag.
    /// Traps if the new pointer's low `tagBits` are nonzero.
    @inlinable
    public func withPointer(_ newPointer: UnsafeMutablePointer<Pointee>?) -> TaggedPointer<Pointee> {
        TaggedPointer(pointer: newPointer, tag: tag)
    }
}
