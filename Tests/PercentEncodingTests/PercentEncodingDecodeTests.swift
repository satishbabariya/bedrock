import Testing
import Bytes
@testable import PercentEncoding

@Test func decodeEmpty() throws {
    #expect(Array(try PercentEncoding.decode("")) == [])
}

@Test func decodeLiteralPassthrough() throws {
    // All-unreserved input passes through unchanged.
    let s = "abc-_.~"
    let out = try PercentEncoding.decode(s)
    #expect(Array(out) == Array(s.utf8))
}

@Test func decodePercentEscapes() throws {
    let out = try PercentEncoding.decode("a%20b%2Fc")
    #expect(out == Bytes([0x61, 0x20, 0x62, 0x2F, 0x63]))
}

@Test func decodeAcceptsLowercaseHex() throws {
    // RFC 3986: producers SHOULD emit uppercase; consumers MUST accept either.
    let out = try PercentEncoding.decode("%2f")
    #expect(out == Bytes([0x2F]))
}

@Test func decodePlusIsLiteral() throws {
    // decode (non-form) treats '+' as literal byte 0x2B.
    let out = try PercentEncoding.decode("a+b")
    #expect(out == Bytes([0x61, 0x2B, 0x62]))
}

@Test func decodeDelimitersAreLiteral() throws {
    let out = try PercentEncoding.decode("a&b=c")
    #expect(out == Bytes(Array("a&b=c".utf8)))
}

@Test func decodeRoundTripsRFCExample() throws {
    let encoded = PercentEncoding.encode("Hello World!", as: .component)
    let decoded = try PercentEncoding.decode(encoded)
    #expect(decoded == Bytes(Array("Hello World!".utf8)))
}

@Test func decodeNonAsciiBytesPassThrough() throws {
    // Bytes >= 0x80 (from a String's UTF-8) decode unchanged.
    let s = "é"  // UTF-8: 0xC3 0xA9
    let out = try PercentEncoding.decode(s)
    #expect(Array(out) == [0xC3, 0xA9])
}

@Test func decodeFromBytesMatchesFromString() throws {
    let s = "a%20b"
    let viaString = try PercentEncoding.decode(s)
    let viaBytes  = try PercentEncoding.decode(Bytes(Array(s.utf8)))
    #expect(viaString == viaBytes)
}

@Test func decodeIntoBytesMutReturnsByteCount() throws {
    var out = BytesMut()
    out.putUInt8(0xAA)
    let n = try PercentEncoding.decode("a%20b", into: &out)
    #expect(n == 3)
    let frozen = out.freeze()
    #expect(Array(frozen) == [0xAA, 0x61, 0x20, 0x62])
}
