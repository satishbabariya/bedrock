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
