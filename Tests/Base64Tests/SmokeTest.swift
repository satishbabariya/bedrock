import Testing
@testable import Base64

@Test func base64NamespaceExists() {
    let _: Base64.Variant = .standard
    let _: Base64.DecodeMode = .strict
    let _: Base64.LineWrap = .none
    #expect(true)
}
