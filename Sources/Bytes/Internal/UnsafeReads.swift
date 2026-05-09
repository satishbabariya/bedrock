@inlinable
internal func loadFixed<T: FixedWidthInteger>(
    _ type: T.Type,
    from base: UnsafeRawPointer,
    offset: Int,
    endianness: Endianness
) -> T {
    let raw = base.loadUnaligned(fromByteOffset: offset, as: T.self)
    switch endianness {
    case .big:    return T(bigEndian: raw)
    case .little: return T(littleEndian: raw)
    case .host:   return raw
    }
}

@inlinable
internal func storeFixed<T: FixedWidthInteger>(
    _ value: T,
    to base: UnsafeMutableRawPointer,
    offset: Int,
    endianness: Endianness
) {
    let raw: T
    switch endianness {
    case .big:    raw = value.bigEndian
    case .little: raw = value.littleEndian
    case .host:   raw = value
    }
    // copyMemory is alignment-agnostic on both source and destination,
    // making this the canonical Swift idiom for unaligned writes.
    withUnsafeBytes(of: raw) { src in
        base.advanced(by: offset)
            .copyMemory(from: src.baseAddress!, byteCount: src.count)
    }
}
