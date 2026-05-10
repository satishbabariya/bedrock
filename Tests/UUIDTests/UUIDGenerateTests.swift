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
