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
