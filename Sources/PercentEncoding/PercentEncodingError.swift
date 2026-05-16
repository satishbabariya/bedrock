/// Errors raised by percent-encoded input decoding.
public enum PercentEncodingError: Error, Equatable, Sendable {
    /// A `%` was found without two valid hex digits after it — either
    /// truncated (`%X<eof>` or `%<eof>`) or a non-hex character followed.
    /// The offset is the position of the `%` in the input UTF-8 byte array.
    case malformedEscape(offset: Int)
}
