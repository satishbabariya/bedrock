import Bytes

extension String {
    /// Percent-encode this String's UTF-8 bytes using `set`.
    public func percentEncoded(_ set: PercentEncoding.Set) -> String {
        PercentEncoding.encode(self, as: set)
    }
}

extension Bytes {
    /// Percent-encode this byte buffer using `set`.
    public func percentEncoded(_ set: PercentEncoding.Set) -> String {
        PercentEncoding.encode(self, as: set)
    }

    /// Decode a percent-encoded string. `+` is treated as literal.
    public init(percentDecoding string: String) throws {
        self = try PercentEncoding.decode(string)
    }

    /// Decode an `application/x-www-form-urlencoded` string. `+` decodes
    /// to ASCII space.
    public init(percentDecodingForm string: String) throws {
        self = try PercentEncoding.decodeForm(string)
    }
}
