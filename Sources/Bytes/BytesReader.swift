/// A noncopyable cursor over an immutable `Bytes`. Reads advance the cursor;
/// noncopyable semantics prevent accidental cursor forks across consumers.
public struct BytesReader: ~Copyable {
    @usableFromInline let bytes: Bytes
    @usableFromInline var cursor: Int

    public init(_ bytes: Bytes) {
        self.bytes = bytes
        self.cursor = 0
    }

    public var remaining: Int { bytes.count - cursor }
    public var consumed: Int { cursor }
    public var isExhausted: Bool { cursor >= bytes.count }

    /// Returns the unread tail without advancing.
    public func remainingBytes() -> Bytes {
        bytes[cursor..<bytes.count]
    }
}
