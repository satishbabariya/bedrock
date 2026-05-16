import Testing
import Bytes
@testable import PercentEncoding

@Test func stringPercentEncodedMatchesNamespaceForm() {
    let s = "Hello World!"
    #expect(s.percentEncoded(.fragment)
            == PercentEncoding.encode(s, as: .fragment))
}

@Test func bytesPercentEncodedMatchesNamespaceForm() {
    let b = Bytes(Array("Hello World!".utf8))
    #expect(b.percentEncoded(.component)
            == PercentEncoding.encode(b, as: .component))
}

@Test func bytesPercentDecodingMatchesNamespaceForm() throws {
    let s = "a%20b"
    let via = try Bytes(percentDecoding: s)
    let direct = try PercentEncoding.decode(s)
    #expect(via == direct)
}

@Test func bytesPercentDecodingFormMatchesNamespaceForm() throws {
    let s = "hello+world"
    let via = try Bytes(percentDecodingForm: s)
    let direct = try PercentEncoding.decodeForm(s)
    #expect(via == direct)
}

@Test func extensionDecodeThrowsOnMalformed() {
    #expect(throws: PercentEncodingError.malformedEscape(offset: 0)) {
        _ = try Bytes(percentDecoding: "%")
    }
}
