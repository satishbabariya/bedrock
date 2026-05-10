import Bytes

/// A 128-bit universally unique identifier.
///
/// Storage is 16 bytes in network (big-endian) byte order. This file
/// holds the namespace shell; conformances and methods are added in
/// subsequent tasks.
public struct UUID {
    @usableFromInline let storage: SIMD16<UInt8>

    @usableFromInline
    init(storage: SIMD16<UInt8>) {
        self.storage = storage
    }
}
