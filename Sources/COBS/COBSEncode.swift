import Bytes

extension COBS {

    /// Encode `input` into `out`. Returns number of bytes appended.
    @discardableResult
    public static func encode(_ input: Bytes,
                              into out: inout BytesMut,
                              framing: Framing = .none) -> Int {
        let encoded = _encode(input, framing: framing)
        let before = out.count
        out.putBytes(encoded)
        return out.count - before
    }

    /// Encode `input` and return a fresh `Bytes`.
    public static func encoded(_ input: Bytes,
                               framing: Framing = .none) -> Bytes {
        Bytes(_encode(input, framing: framing))
    }

    // MARK: - Internal

    private static func _encode(_ input: Bytes, framing: Framing) -> [UInt8] {
        var out: [UInt8] = []
        out.reserveCapacity(maxEncodedSize(forSourceCount: input.count,
                                           framing: framing))

        // Special case: empty input -> single code byte 0x01.
        if input.isEmpty {
            out.append(0x01)
            if framing == .terminator { out.append(0x00) }
            return out
        }

        var codePos = 0
        out.append(0x00)        // placeholder for first code byte
        var code: UInt8 = 1     // count of bytes in current block + 1

        input.withUnsafeBytes { src in
            for b in src {
                if b == 0x00 {
                    out[codePos] = code
                    codePos = out.count
                    out.append(0x00)
                    code = 1
                } else {
                    out.append(b)
                    code &+= 1
                    if code == 0xFF {
                        out[codePos] = code
                        codePos = out.count
                        out.append(0x00)
                        code = 1
                    }
                }
            }
        }
        out[codePos] = code

        if framing == .terminator { out.append(0x00) }
        return out
    }
}
