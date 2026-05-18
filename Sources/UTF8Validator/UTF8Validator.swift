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

    /// Fast yes/no validation. Equivalent to `validate(_:) == .valid`
    /// but allowed to skip offset bookkeeping.
    public static func isValid(_ bytes: Bytes) -> Bool {
        UTF8ValidatorDFA.isValid(bytes)
    }

    /// Validate `bytes` as strict UTF-8 per RFC 3629. Rejects overlongs,
    /// surrogates (U+D800–U+DFFF), and code points > U+10FFFF.
    public static func validate(_ bytes: Bytes) -> ValidationResult {
        UTF8ValidatorDFA.validate(bytes)
    }
}
