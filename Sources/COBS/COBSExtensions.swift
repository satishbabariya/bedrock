import Bytes

extension Bytes {

    /// COBS-encode these bytes.
    public func cobsEncoded(framing: COBS.Framing = .none) -> Bytes {
        COBS.encoded(self, framing: framing)
    }

    /// Initialize from a COBS-encoded source. Throws `COBSError` on malformed input.
    public init(cobsDecoding source: Bytes,
                framing: COBS.Framing = .none) throws {
        self = try COBS.decoded(source, framing: framing)
    }
}
