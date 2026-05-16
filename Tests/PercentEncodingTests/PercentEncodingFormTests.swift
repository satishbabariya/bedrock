import Testing
import Bytes
@testable import PercentEncoding

@Test func formEncodeSpaceBecomesPlus() {
    #expect(PercentEncoding.encode("hello world", as: .form) == "hello+world")
}

@Test func formEncodeLiteralPlusIsPercentEncoded() {
    // Crucial: a literal '+' in input must become %2B so it survives the
    // +/space conversion on decode.
    #expect(PercentEncoding.encode("a+b", as: .form) == "a%2Bb")
}

@Test func decodeFormPlusBecomesSpace() throws {
    let out = try PercentEncoding.decodeForm("a+b")
    #expect(out == Bytes([0x61, 0x20, 0x62]))   // "a b"
}

@Test func decodeFormPercentEncodedPlusBecomesLiteralPlus() throws {
    let out = try PercentEncoding.decodeForm("a%2Bb")
    #expect(out == Bytes([0x61, 0x2B, 0x62]))   // "a+b"
}

@Test func roundTripFormEncodeDecodeForm() throws {
    let original = "hello world+foo"
    let encoded = PercentEncoding.encode(original, as: .form)
    let decoded = try PercentEncoding.decodeForm(encoded)
    #expect(Array(decoded) == Array(original.utf8))
}

@Test func decodeFormIntoBytesMutReturnsCount() throws {
    var out = BytesMut()
    out.putUInt8(0xAA)
    let n = try PercentEncoding.decodeForm("a+b", into: &out)
    #expect(n == 3)
    let frozen = out.freeze()
    #expect(Array(frozen) == [0xAA, 0x61, 0x20, 0x62])
}
