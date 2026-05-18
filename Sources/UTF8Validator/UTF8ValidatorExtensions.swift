import Bytes

extension Bytes {

    /// `true` iff the bytes are well-formed strict UTF-8.
    public var isValidUTF8: Bool {
        UTF8Validator.isValid(self)
    }

    /// Validate as strict UTF-8; on failure the result carries the
    /// offset of the first byte of the malformed sequence.
    public func validateUTF8() -> UTF8Validator.ValidationResult {
        UTF8Validator.validate(self)
    }
}
