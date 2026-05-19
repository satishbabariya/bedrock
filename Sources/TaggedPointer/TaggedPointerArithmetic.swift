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
}
