import Testing
import Bytes
@testable import UUID

@Test func descriptionIsCanonicalLowercase() throws {
    let raw: [UInt8] = [
        0x55, 0x0e, 0x84, 0x00, 0xe2, 0x9b, 0x41, 0xd4,
        0xa7, 0x16, 0x44, 0x66, 0x55, 0x44, 0x00, 0x00,
    ]
    let u = try UUID(bytes: raw)
    #expect(u.description == "550e8400-e29b-41d4-a716-446655440000")
    #expect(u.description.count == 36)
}

@Test func nilDescription() {
    #expect(UUID.nil.description == "00000000-0000-0000-0000-000000000000")
}

@Test func formattedCanonicalUpper() throws {
    let raw: [UInt8] = [
        0x55, 0x0e, 0x84, 0x00, 0xe2, 0x9b, 0x41, 0xd4,
        0xa7, 0x16, 0x44, 0x66, 0x55, 0x44, 0x00, 0x00,
    ]
    let u = try UUID(bytes: raw)
    #expect(u.formatted(.canonicalUpper) == "550E8400-E29B-41D4-A716-446655440000")
}

@Test func formattedHyphenless() throws {
    let raw: [UInt8] = [
        0x55, 0x0e, 0x84, 0x00, 0xe2, 0x9b, 0x41, 0xd4,
        0xa7, 0x16, 0x44, 0x66, 0x55, 0x44, 0x00, 0x00,
    ]
    let u = try UUID(bytes: raw)
    let s = u.formatted(.hyphenless)
    #expect(s == "550e8400e29b41d4a716446655440000")
    #expect(s.count == 32)
    #expect(!s.contains("-"))
}

@Test func formattedBraced() throws {
    let u = UUID.nil
    let s = u.formatted(.braced)
    #expect(s == "{00000000-0000-0000-0000-000000000000}")
    #expect(s.hasPrefix("{"))
    #expect(s.hasSuffix("}"))
}

@Test func formattedURN() throws {
    let u = UUID.nil
    let s = u.formatted(.urn)
    #expect(s == "urn:uuid:00000000-0000-0000-0000-000000000000")
    #expect(s.hasPrefix("urn:uuid:"))
}

@Test func losslessInitAcceptsCanonicalLowercase() {
    let s = "550e8400-e29b-41d4-a716-446655440000"
    let u = UUID(s)
    #expect(u != nil)
    #expect(u?.description == s)
}

@Test func losslessInitRejectsUppercase() {
    let s = "550E8400-E29B-41D4-A716-446655440000"
    #expect(UUID(s) == nil)
}

@Test func losslessInitRejectsBracesAndURN() {
    #expect(UUID("{550e8400-e29b-41d4-a716-446655440000}") == nil)
    #expect(UUID("urn:uuid:550e8400-e29b-41d4-a716-446655440000") == nil)
    #expect(UUID("550e8400e29b41d4a716446655440000") == nil)
}
