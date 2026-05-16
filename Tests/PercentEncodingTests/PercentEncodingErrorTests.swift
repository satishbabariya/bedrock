import Testing
@testable import PercentEncoding

@Test func errorEquality() {
    #expect(PercentEncodingError.malformedEscape(offset: 0)
            == PercentEncodingError.malformedEscape(offset: 0))
    #expect(PercentEncodingError.malformedEscape(offset: 0)
            != PercentEncodingError.malformedEscape(offset: 3))
}

@Test func setEnumCases() {
    let cases: [PercentEncoding.Set] = [
        .unreserved, .pathSegment, .query, .fragment,
        .userinfo, .component, .form,
    ]
    #expect(cases.count == 7)
}

@Test func decodeBareEscapeThrows() {
    #expect(throws: PercentEncodingError.malformedEscape(offset: 0)) {
        _ = try PercentEncoding.decode("%")
    }
}

@Test func decodeNonHexHighNibbleThrows() {
    #expect(throws: PercentEncodingError.malformedEscape(offset: 0)) {
        _ = try PercentEncoding.decode("%G0")
    }
}

@Test func decodeNonHexLowNibbleThrows() {
    #expect(throws: PercentEncodingError.malformedEscape(offset: 0)) {
        _ = try PercentEncoding.decode("%2G")
    }
}

@Test func decodeTruncatedEscapeAtEndThrows() {
    #expect(throws: PercentEncodingError.malformedEscape(offset: 3)) {
        _ = try PercentEncoding.decode("abc%")
    }
}

@Test func decodeOneHexDigitThenEOFThrows() {
    #expect(throws: PercentEncodingError.malformedEscape(offset: 3)) {
        _ = try PercentEncoding.decode("abc%2")
    }
}

@Test func decodeFormBareEscapeThrows() {
    // Verify decodeForm shares the error path with decode.
    #expect(throws: PercentEncodingError.malformedEscape(offset: 0)) {
        _ = try PercentEncoding.decodeForm("%")
    }
}
