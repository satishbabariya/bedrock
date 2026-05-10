import Bytes

extension Bytes {
    /// Base64-encode this buffer.
    public func base64Encoded(
        variant: Base64.Variant = .standard,
        padding: Bool = true,
        lineWrap: Base64.LineWrap = .none
    ) -> String {
        Base64.encode(self, variant: variant, padding: padding, lineWrap: lineWrap)
    }
}

extension String {
    /// Construct a String containing the Base64 encoding of `bytes`.
    public init(
        base64Encoding bytes: Bytes,
        variant: Base64.Variant = .standard,
        padding: Bool = true,
        lineWrap: Base64.LineWrap = .none
    ) {
        self = Base64.encode(bytes, variant: variant, padding: padding, lineWrap: lineWrap)
    }
}

extension Bytes {
    /// Decode a Base64 string into bytes.
    public init(
        base64Decoding s: String,
        mode: Base64.DecodeMode = .strict
    ) throws {
        self = try Base64.decode(s, mode: mode)
    }
}
