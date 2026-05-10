import Testing
import Bytes
@testable import UUID

@Test func parseCanonicalLowercase() throws {
    let u = try UUID(parsing: "550e8400-e29b-41d4-a716-446655440000")
    #expect(u.description == "550e8400-e29b-41d4-a716-446655440000")
}

@Test func parseCanonicalUppercase() throws {
    let u = try UUID(parsing: "550E8400-E29B-41D4-A716-446655440000")
    #expect(u.description == "550e8400-e29b-41d4-a716-446655440000")
}

@Test func parseCanonicalMixedCase() throws {
    let u = try UUID(parsing: "550e8400-E29B-41d4-a716-446655440000")
    #expect(u.description == "550e8400-e29b-41d4-a716-446655440000")
}

@Test func parseBraced() throws {
    let u = try UUID(parsing: "{550e8400-e29b-41d4-a716-446655440000}")
    #expect(u.description == "550e8400-e29b-41d4-a716-446655440000")
}

@Test func parseURN() throws {
    let u = try UUID(parsing: "urn:uuid:550e8400-e29b-41d4-a716-446655440000")
    #expect(u.description == "550e8400-e29b-41d4-a716-446655440000")
}

@Test func parseURNCaseInsensitivePrefix() throws {
    let u = try UUID(parsing: "URN:UUID:550e8400-e29b-41d4-a716-446655440000")
    #expect(u.description == "550e8400-e29b-41d4-a716-446655440000")
}

@Test func parseHyphenless() throws {
    let u = try UUID(parsing: "550e8400e29b41d4a716446655440000")
    #expect(u.description == "550e8400-e29b-41d4-a716-446655440000")
}

@Test func parseWrongLengthThrows() {
    #expect(throws: UUIDError.invalidFormat) {
        _ = try UUID(parsing: "550e8400-e29b-41d4-a716-44665544000")  // 35 chars
    }
    #expect(throws: UUIDError.invalidFormat) {
        _ = try UUID(parsing: "550e8400-e29b-41d4-a716-4466554400000") // 37 chars
    }
}

@Test func parseMissingHyphenThrows() {
    // Replace one hyphen with a hex digit to keep length 36.
    #expect(throws: UUIDError.invalidFormat) {
        _ = try UUID(parsing: "550e8400xe29b-41d4-a716-446655440000")
    }
}

@Test func parseInvalidHexCharacterThrows() {
    // '@' = 0x40 at offset 0.
    #expect(throws: UUIDError.invalidHexCharacter(offset: 0, byte: 0x40)) {
        _ = try UUID(parsing: "@50e8400-e29b-41d4-a716-446655440000")
    }
}

@Test func parseInvalidHexInHyphenless() {
    // 'g' = 0x67 at offset 0.
    #expect(throws: UUIDError.invalidHexCharacter(offset: 0, byte: 0x67)) {
        _ = try UUID(parsing: "g50e8400e29b41d4a716446655440000")
    }
}

@Test func parseRoundTripsThroughBytes() throws {
    let original = "550e8400-e29b-41d4-a716-446655440000"
    let u = try UUID(parsing: original)
    let backFromBytes = try UUID(bytes: u.bytes)
    #expect(backFromBytes.description == original)
}
