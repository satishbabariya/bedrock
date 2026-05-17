import Bytes

extension COBS {

    /// Decode `input` into `out`. Returns number of bytes appended.
    /// Throws `COBSError` on malformed input.
    @discardableResult
    public static func decode(_ input: Bytes,
                              into out: inout BytesMut,
                              framing: Framing = .none) throws -> Int {
        let decoded = try _decode(input, framing: framing)
        let before = out.count
        out.putBytes(decoded)
        return out.count - before
    }

    /// Decode `input` and return a fresh `Bytes`.
    public static func decoded(_ input: Bytes,
                               framing: Framing = .none) throws -> Bytes {
        Bytes(try _decode(input, framing: framing))
    }

    // MARK: - Internal

    private static func _decode(_ input: Bytes, framing: Framing) throws -> [UInt8] {

        // Determine payload length (strip trailing 0x00 in framed mode).
        let payloadCount: Int
        if framing == .terminator {
            if input.isEmpty {
                throw COBSError.missingTerminator
            }
            var lastByte: UInt8 = 0
            input.withUnsafeBytes { src in
                lastByte = src[input.count - 1]
            }
            if lastByte != 0x00 {
                throw COBSError.missingTerminator
            }
            payloadCount = input.count - 1
        } else {
            payloadCount = input.count
        }

        if payloadCount == 0 {
            throw COBSError.truncated
        }

        var out: [UInt8] = []
        out.reserveCapacity(maxDecodedSize(forEncodedCount: input.count,
                                            framing: framing))

        // We do the algorithmic work inside withUnsafeBytes; if we hit a
        // structured error, we surface it through `caught` and throw after.
        var caught: COBSError? = nil

        input.withUnsafeBytes { src in
            var i = 0
            while i < payloadCount {
                let code = src[i]
                if code == 0x00 {
                    caught = framing == .terminator
                        ? .unexpectedTerminator(offset: i)
                        : .invalidZeroByte(offset: i)
                    return
                }
                i += 1
                let blockEnd = i + Int(code) - 1
                if blockEnd > payloadCount {
                    caught = .truncated
                    return
                }
                while i < blockEnd {
                    let bb = src[i]
                    if bb == 0x00 {
                        caught = framing == .terminator
                            ? .unexpectedTerminator(offset: i)
                            : .invalidZeroByte(offset: i)
                        return
                    }
                    out.append(bb)
                    i += 1
                }
                // Inter-block zero, unless block was maximal or at end.
                if code < 0xFF && i < payloadCount {
                    out.append(0x00)
                }
            }
        }

        if let err = caught { throw err }
        return out
    }
}
