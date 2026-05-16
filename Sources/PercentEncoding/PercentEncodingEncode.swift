import Bytes

extension PercentEncoding {

    /// Percent-encode `bytes` into `out` using `set`. Bytes that are "safe"
    /// per the set pass through; bytes that are unsafe become `%XX`
    /// (uppercase hex). `.form` additionally maps space (0x20) to `+`.
    public static func encode(_ bytes: Bytes, as set: Set, into out: inout BytesMut) {
        let t = setTable(for: set)
        out.reserveCapacity(out.count + bytes.count)
        bytes.withUnsafeBytes { src in
            for b in src {
                if b == 0x20 && t.spaceAsPlus {
                    out.putUInt8(0x2B)        // '+'
                } else if t.safe[Int(b)] {
                    out.putUInt8(b)
                } else {
                    out.putUInt8(0x25)        // '%'
                    out.putUInt8(hexUpper[Int(b >> 4)])
                    out.putUInt8(hexUpper[Int(b & 0x0F)])
                }
            }
        }
    }

    /// Percent-encode `bytes` using `set`. Returns the encoded ASCII string.
    public static func encode(_ bytes: Bytes, as set: Set) -> String {
        var buf = BytesMut(capacity: bytes.count)
        encode(bytes, as: set, into: &buf)
        return String(decoding: buf.freeze(), as: UTF8.self)
    }

    /// Percent-encode the UTF-8 bytes of `string` using `set`.
    public static func encode(_ string: String, as set: Set) -> String {
        let arr = Array(string.utf8)
        return encode(Bytes(arr), as: set)
    }

    /// Stream-encode the UTF-8 bytes of `string` into `out`.
    public static func encode(_ string: String, as set: Set, into out: inout BytesMut) {
        let arr = Array(string.utf8)
        encode(Bytes(arr), as: set, into: &out)
    }
}
