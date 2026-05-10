import Testing
@testable import UUID

@Test func uuidNamespaceExists() {
    let _: UUID.Version = .v4
    let _: UUID.Variant = .rfc4122
    #expect(true)
}

@Test func wallClockReturnsRecentTimestamp() {
    let ms = unixWallClockMilliseconds()
    // Sanity: should be a recent timestamp (after Jan 1, 2020 UTC).
    let jan2020Ms: Int64 = 1577836800000
    #expect(ms > jan2020Ms)
}
