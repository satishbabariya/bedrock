/// Errors thrown by `Bytes`, `BytesMut`, and `BytesReader` operations.
public enum BytesError: Error, Equatable, Sendable {
    /// A non-advancing access referenced an offset/length outside the buffer.
    case outOfBounds(offset: Int, length: Int, bufferCount: Int)
    /// A reader could not satisfy a read because the cursor reached the end.
    case shortRead(needed: Int, available: Int)
    /// An API received a negative `length` parameter.
    case invalidLength(Int)
}
