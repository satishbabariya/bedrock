import Testing
@testable import UUID

@Test func uuidNamespaceExists() {
    let _: UUID.Version = .v4
    let _: UUID.Variant = .rfc4122
    #expect(true)
}
