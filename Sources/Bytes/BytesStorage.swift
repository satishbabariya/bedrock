/// Internal heap-allocated byte buffer. Refcounted by Swift class ARC
/// (atomic by language guarantee). Never escapes the module.
@usableFromInline
internal final class BytesStorage: @unchecked Sendable {
    @usableFromInline var pointer: UnsafeMutableRawPointer
    @usableFromInline var capacity: Int

    /// A shared zero-capacity singleton used to back empty `Bytes`/`BytesMut`
    /// without allocating. The 1-byte allocation exists only so `pointer`
    /// is non-nil for `withUnsafeBytes` callers; it is never read or written.
    @usableFromInline
    static let empty: BytesStorage = {
        let s = BytesStorage(rawCapacity: 0)
        return s
    }()

    @usableFromInline
    init(capacity: Int) {
        precondition(capacity >= 0, "BytesStorage capacity must be non-negative")
        self.capacity = capacity
        if capacity == 0 {
            // Allocate one byte so `pointer` is non-nil; never read or written.
            self.pointer = UnsafeMutableRawPointer.allocate(
                byteCount: 1, alignment: 8)
        } else {
            self.pointer = UnsafeMutableRawPointer.allocate(
                byteCount: capacity, alignment: 8)
        }
    }

    /// Identical to `init(capacity:)`, used by the `empty` singleton initializer.
    private init(rawCapacity: Int) {
        self.capacity = rawCapacity
        self.pointer = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 8)
    }

    deinit {
        pointer.deallocate()
    }
}
