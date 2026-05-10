import Bytes

/// A 128-bit universally unique identifier.
///
/// Storage is 16 bytes in network (big-endian) byte order, exposed as
/// `bytes`. Use `description` for canonical lowercase string form.
public struct UUID: Sendable, Hashable {
    @usableFromInline let storage: SIMD16<UInt8>

    @usableFromInline
    init(storage: SIMD16<UInt8>) {
        self.storage = storage
    }

    // ─── Constants ────────────────────────────────────────────────────────

    /// All-zero UUID: `00000000-0000-0000-0000-000000000000`.
    public static let `nil` = UUID(storage: SIMD16<UInt8>(repeating: 0))

    /// All-ones UUID: `ffffffff-ffff-ffff-ffff-ffffffffffff`.
    public static let max = UUID(storage: SIMD16<UInt8>(repeating: 0xFF))

    // ─── Bytes interop ────────────────────────────────────────────────────

    /// Construct from exactly 16 bytes in network order.
    public init(bytes: Bytes) throws {
        guard bytes.count == 16 else {
            throw UUIDError.invalidByteCount(bytes.count)
        }
        var s = SIMD16<UInt8>()
        bytes.withUnsafeBytes { src in
            for i in 0..<16 { s[i] = src[i] }
        }
        self.storage = s
    }

    /// Construct from any 16-element UInt8 sequence.
    public init<S: Sequence>(bytes: S) throws where S.Element == UInt8 {
        let arr = Array(bytes)
        guard arr.count == 16 else {
            throw UUIDError.invalidByteCount(arr.count)
        }
        var s = SIMD16<UInt8>()
        for i in 0..<16 { s[i] = arr[i] }
        self.storage = s
    }

    /// 16 bytes in network byte order.
    public var bytes: Bytes {
        var arr: [UInt8] = []
        arr.reserveCapacity(16)
        for i in 0..<16 { arr.append(storage[i]) }
        return Bytes(arr)
    }
}
