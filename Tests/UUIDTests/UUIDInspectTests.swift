import Testing
import Bytes
@testable import UUID

/// Build a UUID with a specific byte 6 (version) and byte 8 (variant)
/// using the bytes-init. The other bytes are zero.
private func make(version v: UInt8, variant b8: UInt8) throws -> UUID {
    var raw = [UInt8](repeating: 0, count: 16)
    raw[6] = v
    raw[8] = b8
    return try UUID(bytes: raw)
}

@Test func nilUUIDVariantIsNCS() {
    #expect(UUID.nil.variant == .ncs)
    #expect(UUID.nil.version == nil)   // version meaningful only for rfc4122
}

@Test func maxUUIDVariantIsFuture() {
    #expect(UUID.max.variant == .future)
    #expect(UUID.max.version == nil)
}

@Test func variantNCSDetected() throws {
    // Top bit 0 → NCS. Use 0x00, 0x40 (covers 0xx range).
    let a = try make(version: 0x00, variant: 0x00)  // 000xxxxx
    let b = try make(version: 0x00, variant: 0x40)  // 010xxxxx
    #expect(a.variant == .ncs)
    #expect(b.variant == .ncs)
}

@Test func variantRFC4122Detected() throws {
    // Top two bits 10 → RFC 4122. Test 0x80 (100xxxxx) and 0xA0 (101xxxxx).
    let a = try make(version: 0x40, variant: 0x80)
    let b = try make(version: 0x40, variant: 0xA0)
    #expect(a.variant == .rfc4122)
    #expect(b.variant == .rfc4122)
}

@Test func variantMicrosoftDetected() throws {
    // Top three bits 110 → Microsoft. 0xC0 = 11000000.
    let u = try make(version: 0x40, variant: 0xC0)
    #expect(u.variant == .microsoft)
}

@Test func variantFutureDetected() throws {
    // Top three bits 111 → future. 0xE0 = 11100000.
    let u = try make(version: 0x40, variant: 0xE0)
    #expect(u.variant == .future)
}

@Test func versionV1ThroughV8Detected() throws {
    for v in 1...8 {
        let u = try make(version: UInt8(v << 4), variant: 0x80)
        #expect(u.version == UUID.Version(rawValue: v))
    }
}

@Test func versionNilForNonRFC4122() throws {
    // Version field would be 4 (0x40) but variant is NCS (0x00).
    let u = try make(version: 0x40, variant: 0x00)
    #expect(u.version == nil)
}

@Test func versionRawValuesMatchWireBits() {
    // Sanity: rawValue 1 → wire bits 0001, etc.
    #expect(UUID.Version.v1.rawValue == 1)
    #expect(UUID.Version.v4.rawValue == 4)
    #expect(UUID.Version.v7.rawValue == 7)
    #expect(UUID.Version.v8.rawValue == 8)
}
