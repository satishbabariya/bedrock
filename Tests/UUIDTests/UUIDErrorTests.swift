import Testing
@testable import UUID

@Test func uuidErrorEquality() {
    #expect(UUIDError.invalidFormat == UUIDError.invalidFormat)
    #expect(UUIDError.invalidByteCount(15) == UUIDError.invalidByteCount(15))
    #expect(UUIDError.invalidByteCount(15) != UUIDError.invalidByteCount(17))
    #expect(UUIDError.invalidHexCharacter(offset: 5, byte: 0x40)
            == UUIDError.invalidHexCharacter(offset: 5, byte: 0x40))
    #expect(UUIDError.invalidHexCharacter(offset: 5, byte: 0x40)
            != UUIDError.invalidHexCharacter(offset: 6, byte: 0x40))
}

@Test func versionEnumCases() {
    let all = UUID.Version.allCases
    #expect(all.count == 8)
    #expect(UUID.Version.v1.rawValue == 1)
    #expect(UUID.Version.v8.rawValue == 8)
}

@Test func variantEnumCases() {
    let cases: [UUID.Variant] = [.ncs, .rfc4122, .microsoft, .future]
    #expect(cases.count == 4)
    #expect(UUID.Variant.rfc4122 == .rfc4122)
    #expect(UUID.Variant.rfc4122 != .future)
}
