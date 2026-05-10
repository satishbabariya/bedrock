import Testing
import Bytes
@testable import UUID

/// Deterministic RNG for repeatable tests.
struct DeterministicRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

@Test func v4HasVersion4AndRfc4122Variant() {
    let u = UUID.v4()
    #expect(u.version == .v4)
    #expect(u.variant == .rfc4122)
}

@Test func v4WithDeterministicRNGIsRepeatable() {
    var rngA = DeterministicRNG(seed: 42)
    var rngB = DeterministicRNG(seed: 42)
    let a = UUID.v4(using: &rngA)
    let b = UUID.v4(using: &rngB)
    #expect(a == b)
}

@Test func v4DifferentSeedsProduceDifferentUUIDs() {
    var rngA = DeterministicRNG(seed: 42)
    var rngB = DeterministicRNG(seed: 43)
    let a = UUID.v4(using: &rngA)
    let b = UUID.v4(using: &rngB)
    #expect(a != b)
}

@Test func v41000UniqueSmoke() {
    var seen: Set<UUID> = []
    for _ in 0..<1000 { seen.insert(UUID.v4()) }
    #expect(seen.count == 1000)
}

@Test func v7HasVersion7AndRfc4122Variant() {
    let u = UUID.v7()
    #expect(u.version == .v7)
    #expect(u.variant == .rfc4122)
}

@Test func v7TimestampIsInFirst6Bytes() {
    let ms: Int64 = 0x0000_0192_4F1B_7E3A  // arbitrary 48-bit timestamp
    var rng = DeterministicRNG(seed: 7)
    let u = UUID.v7(unixMillisecondsSince1970: ms, using: &rng)
    let bytes = Array(u.bytes)
    let recovered: Int64 =
        (Int64(bytes[0]) << 40) |
        (Int64(bytes[1]) << 32) |
        (Int64(bytes[2]) << 24) |
        (Int64(bytes[3]) << 16) |
        (Int64(bytes[4]) <<  8) |
         Int64(bytes[5])
    #expect(recovered == ms)
}

@Test func v7VersionAndVariantStamped() {
    var rng = DeterministicRNG(seed: 13)
    let u = UUID.v7(unixMillisecondsSince1970: 0, using: &rng)
    let bytes = Array(u.bytes)
    #expect((bytes[6] >> 4) == 0x7)         // version 7
    #expect((bytes[8] >> 6) == 0b10)        // variant 10
}

@Test func v7NoArgUsesCurrentWallClock() {
    let before = unixWallClockMilliseconds()
    let u = UUID.v7()
    let after = unixWallClockMilliseconds()
    let bytes = Array(u.bytes)
    let ms: Int64 =
        (Int64(bytes[0]) << 40) |
        (Int64(bytes[1]) << 32) |
        (Int64(bytes[2]) << 24) |
        (Int64(bytes[3]) << 16) |
        (Int64(bytes[4]) <<  8) |
         Int64(bytes[5])
    // Allow 1s of slack on either side for slow CI.
    #expect(ms >= before - 1000)
    #expect(ms <= after + 1000)
}

@Test func v7sInIncreasingMsSortInOrder() {
    var rng = DeterministicRNG(seed: 99)
    let a = UUID.v7(unixMillisecondsSince1970: 1_000_000, using: &rng)
    let b = UUID.v7(unixMillisecondsSince1970: 2_000_000, using: &rng)
    let c = UUID.v7(unixMillisecondsSince1970: 3_000_000, using: &rng)
    #expect(a < b)
    #expect(b < c)
    #expect(a < c)
}

@Test func v8HasVersion8AndRfc4122Variant() throws {
    let raw = [UInt8](repeating: 0xAA, count: 16)
    let u = try UUID.v8(bytes: Bytes(raw))
    #expect(u.version == .v8)
    #expect(u.variant == .rfc4122)
}

@Test func v8PreservesCallerBytesExceptVersionAndVariant() throws {
    let raw = [UInt8](repeating: 0xAA, count: 16)
    let u = try UUID.v8(bytes: Bytes(raw))
    let out = Array(u.bytes)
    // Bytes 0-5, 7, 9-15 unchanged.
    for i in [0, 1, 2, 3, 4, 5, 7, 9, 10, 11, 12, 13, 14, 15] {
        #expect(out[i] == 0xAA, "byte \(i) should be 0xAA, got \(out[i])")
    }
    // Byte 6: low nibble preserved (0xA), high nibble = 8.
    #expect(out[6] == 0x8A)
    // Byte 8: low 6 bits preserved (0b101010 = 0x2A), top two bits = 0b10.
    #expect(out[8] == 0xAA)  // 0b10101010 — high two bits already were 10
}

@Test func v8VersionStampOverwritesHighNibbleOfByte6() throws {
    var raw = [UInt8](repeating: 0, count: 16)
    raw[6] = 0xFF  // expect high nibble to become 8, low nibble to stay F
    let u = try UUID.v8(bytes: Bytes(raw))
    let out = Array(u.bytes)
    #expect(out[6] == 0x8F)
}

@Test func v8VariantStampOverwritesTopTwoBitsOfByte8() throws {
    var raw = [UInt8](repeating: 0, count: 16)
    raw[8] = 0xFF  // expect top two bits to become 10, low 6 bits stay 1
    let u = try UUID.v8(bytes: Bytes(raw))
    let out = Array(u.bytes)
    // 0xFF & 0x3F = 0x3F; 0x3F | 0x80 = 0xBF
    #expect(out[8] == 0xBF)
}

@Test func v8WrongLengthThrows() {
    let short = Bytes([UInt8](repeating: 0, count: 15))
    #expect(throws: UUIDError.invalidByteCount(15)) {
        _ = try UUID.v8(bytes: short)
    }
    let long = Bytes([UInt8](repeating: 0, count: 17))
    #expect(throws: UUIDError.invalidByteCount(17)) {
        _ = try UUID.v8(bytes: long)
    }
}
