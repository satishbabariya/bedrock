import Testing
import Bytes
@testable import PercentEncoding

@Test func encodeEmptyForEverySet() {
    let sets: [PercentEncoding.Set] = [
        .unreserved, .pathSegment, .query, .fragment,
        .userinfo, .component, .form,
    ]
    for set in sets {
        #expect(PercentEncoding.encode("", as: set) == "")
    }
}

@Test func encodeUnreservedRFCExample() {
    // 'Hello' all unreserved; space and '!' are not.
    #expect(PercentEncoding.encode("Hello World!", as: .unreserved)
            == "Hello%20World%21")
}

@Test func encodeFragmentAllowsExclamation() {
    // '!' is a sub-delim, allowed in fragment.
    #expect(PercentEncoding.encode("Hello World!", as: .fragment)
            == "Hello%20World!")
}

@Test func encodeComponentEncodesExclamation() {
    // .component is the strict set — only unreserved unencoded.
    #expect(PercentEncoding.encode("Hello World!", as: .component)
            == "Hello%20World%21")
}

@Test func encodeSlashInPathSegmentIsEncoded() {
    #expect(PercentEncoding.encode("a/b", as: .pathSegment) == "a%2Fb")
}

@Test func encodeSlashInQueryIsLiteral() {
    #expect(PercentEncoding.encode("a/b", as: .query) == "a/b")
}

@Test func encodeAmpersandAndEqualsInQueryEncoded() {
    // Query set removes '&' and '=' from sub-delims so they encode.
    #expect(PercentEncoding.encode("a=1&b=2", as: .query) == "a%3D1%26b%3D2")
}

@Test func encodeColonInUserinfoIsLiteral() {
    #expect(PercentEncoding.encode("user:pass", as: .userinfo) == "user:pass")
}

@Test func encodeBytesAbove127AlwaysEncoded() {
    // Non-ASCII bytes always get percent-encoded for every set.
    let bytes = Bytes([0xC3, 0xA9])  // "é" in UTF-8
    #expect(PercentEncoding.encode(bytes, as: .fragment) == "%C3%A9")
}

@Test func encodeBytesAndStringOverloadsMatch() {
    let s = "Hello World!"
    let b = Bytes(Array(s.utf8))
    for set in [PercentEncoding.Set.unreserved, .pathSegment, .query, .fragment, .component] {
        #expect(PercentEncoding.encode(s, as: set) == PercentEncoding.encode(b, as: set))
    }
}

@Test func encodeUsesUppercaseHex() {
    // RFC 3986 §2.1: "uppercase hexadecimal digits should be used".
    let s = PercentEncoding.encode("ÿ", as: .component)
    #expect(s == "%C3%BF")
    #expect(s == s.uppercased())
}

@Test func encodeIntoBytesMutAppends() {
    var buf = BytesMut()
    buf.putUInt8(0xAA)
    PercentEncoding.encode("a b", as: .component, into: &buf)
    let frozen = buf.freeze()
    // 0xAA + "a%20b" = [0xAA, 0x61, 0x25, 0x32, 0x30, 0x62]
    #expect(Array(frozen) == [0xAA, 0x61, 0x25, 0x32, 0x30, 0x62])
}
