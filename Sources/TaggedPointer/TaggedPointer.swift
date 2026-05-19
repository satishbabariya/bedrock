/// A pointer with a small tag packed into its unused low alignment bits.
///
/// `UnsafeMutablePointer<Pointee>` is guaranteed to be aligned to
/// `MemoryLayout<Pointee>.alignment`, so the low `log2(alignment)` bits
/// are always zero in a well-formed pointer and can carry a small tag
/// at no storage cost.
///
/// For `Pointee` types with alignment 8 (e.g., `Int`, `Double`), 3 tag
/// bits are available — values 0..7. For alignment-1 types (`UInt8`),
/// 0 tag bits are available; only `tag: 0` is valid.
public struct TaggedPointer<Pointee>: Equatable, Hashable, @unchecked Sendable {

    @usableFromInline
    internal let raw: UInt

    /// Build from a pointer + tag.
    /// Traps if `tag > maxTag` or if `pointer`'s low `tagBits` are nonzero.
    @inlinable
    public init(pointer: UnsafeMutablePointer<Pointee>?, tag: UInt = 0) {
        precondition(tag <= Self.maxTag,
                     "tag exceeds maxTag for this Pointee alignment")
        let pointerBits: UInt
        if let p = pointer {
            pointerBits = UInt(bitPattern: p)
            precondition(pointerBits & Self.tagMask == 0,
                         "pointer is not aligned to MemoryLayout<Pointee>.alignment")
        } else {
            pointerBits = 0
        }
        self.raw = pointerBits | tag
    }

    /// Internal raw-storage init used by `withTag` / `withPointer`.
    @usableFromInline
    internal init(rawStorage: UInt) {
        self.raw = rawStorage
    }

    /// The (untagged) pointer. `nil` if the tagged pointer was
    /// constructed from a nil pointer.
    @inlinable
    public var pointer: UnsafeMutablePointer<Pointee>? {
        let ptrBits = raw & ~Self.tagMask
        if ptrBits == 0 { return nil }
        return UnsafeMutablePointer<Pointee>(bitPattern: ptrBits)
    }

    /// The tag value (`0...maxTag`).
    @inlinable
    public var tag: UInt {
        raw & Self.tagMask
    }
}
