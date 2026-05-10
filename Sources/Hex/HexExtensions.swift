import Bytes

extension Bytes {
    /// Hex-encode this buffer. Default case is lowercase.
    public func hexEncoded(case: Hex.Case = .lower) -> String {
        Hex.encode(self, case: `case`)
    }
}

extension String {
    /// Construct a String containing the hex encoding of `bytes`.
    public init(hexEncoding bytes: Bytes, case: Hex.Case = .lower) {
        self = Hex.encode(bytes, case: `case`)
    }
}

extension Bytes {
    /// Decode a hex string into bytes. Case-insensitive.
    public init(hexDecoding s: String) throws {
        self = try Hex.decode(s)
    }
}
