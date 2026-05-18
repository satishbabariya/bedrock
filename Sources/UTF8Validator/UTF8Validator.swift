import Bytes

/// Strict UTF-8 byte-sequence validator (RFC 3629).
public enum UTF8Validator {

    /// Outcome of validating a byte sequence as UTF-8.
    public enum ValidationResult: Equatable, Hashable, Sendable {
        case valid

        /// Validation failed; `offset` is the byte index where the first
        /// malformed sequence began (WHATWG convention).
        case invalid(offset: Int)
    }
}
