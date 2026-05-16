import Testing
@testable import PercentEncoding

@Test func percentEncodingNamespaceExists() {
    let _: PercentEncoding.Set = .unreserved
    #expect(true)
}
