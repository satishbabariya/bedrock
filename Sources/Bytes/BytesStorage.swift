/// Internal heap-allocated byte buffer. Refcounted by Swift class ARC
/// (atomic by language guarantee). Never escapes the module.
///
/// Mutation of `pointer`/`capacity` is permitted only by `BytesMut` after
/// verifying `isKnownUniquelyReferenced`; that invariant is what makes
/// `@unchecked Sendable` safe here.
@usableFromInline
internal final class BytesStorage: @unchecked Sendable {
    @usableFromInline var pointer: UnsafeMutableRawPointer
    @usableFromInline var capacity: Int

    /// A shared zero-capacity singleton used to back empty `Bytes`/`BytesMut`
    /// without observable allocation. The 1-byte sentinel allocation exists
    /// only so `pointer` is non-nil for `withUnsafeBytes` callers; it is
    /// never read or written.
    @usableFromInline
    static let empty: BytesStorage = BytesStorage(capacity: 0)

    @usableFromInline
    init(capacity: Int) {
        precondition(capacity >= 0, "BytesStorage capacity must be non-negative")
        self.capacity = capacity
        // Always allocate at least 1 byte so `pointer` is non-nil even for
        // zero-capacity storage; the sentinel byte is never read or written.
        self.pointer = UnsafeMutableRawPointer.allocate(
            byteCount: Swift.max(capacity, 1), alignment: 8)
    }

    deinit {
        pointer.deallocate()
    }
}
