import Testing
import COBS
import Bytes

@Suite
struct COBSRoundTripTests {

    /// Seeded linear-congruential generator (no Foundation dependency).
    private struct LCG {
        var state: UInt64
        mutating func next() -> UInt8 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return UInt8(truncatingIfNeeded: state >> 56)
        }
        mutating func bytes(_ n: Int) -> [UInt8] {
            var out: [UInt8] = []
            out.reserveCapacity(n)
            for _ in 0..<n { out.append(next()) }
            return out
        }
    }

    private func b(_ xs: [UInt8]) -> Bytes { Bytes(xs) }

    private func roundTrip(_ input: [UInt8], framing: COBS.Framing) throws {
        let enc = COBS.encoded(b(input), framing: framing)
        let dec = try COBS.decoded(enc, framing: framing)
        #expect(Array(dec) == input,
                "round-trip mismatch (framing: \(framing), n=\(input.count))")
    }

    @Test
    func corpusBodyOnly() throws {
        let corpus: [[UInt8]] = [
            [],
            [0x00],
            [0x01],
            [0xFF],
            [0x00, 0x00],
            [0x11, 0x22, 0x00, 0x33],
            Array(repeating: 0x00, count: 10),
            Array(repeating: 0xAA, count: 10),
            [0x00, 0x01, 0x02, 0x00, 0x03],
        ]
        for input in corpus {
            try roundTrip(input, framing: .none)
        }
    }

    @Test
    func corpusFramed() throws {
        let corpus: [[UInt8]] = [
            [],
            [0x00],
            [0x01],
            [0xFF],
            [0x00, 0x00],
            [0x11, 0x22, 0x00, 0x33],
            Array(repeating: 0x00, count: 10),
            Array(repeating: 0xAA, count: 10),
            [0x00, 0x01, 0x02, 0x00, 0x03],
        ]
        for input in corpus {
            try roundTrip(input, framing: .terminator)
        }
    }

    @Test
    func everySingleByteRoundTripsBodyOnly() throws {
        for byte in UInt8.min ... UInt8.max {
            try roundTrip([byte], framing: .none)
        }
    }

    @Test
    func everySingleByteRoundTripsFramed() throws {
        for byte in UInt8.min ... UInt8.max {
            try roundTrip([byte], framing: .terminator)
        }
    }

    @Test
    func blockBoundaryLengthsRoundTrip() throws {
        let lengths = [253, 254, 255, 256, 507, 508, 509, 510]
        for n in lengths {
            // All non-zero (worst-case for block-max boundary).
            try roundTrip(Array(repeating: UInt8(0x01), count: n), framing: .none)
            try roundTrip(Array(repeating: UInt8(0x01), count: n), framing: .terminator)
            // All zero (worst-case overhead).
            try roundTrip(Array(repeating: UInt8(0x00), count: n), framing: .none)
            try roundTrip(Array(repeating: UInt8(0x00), count: n), framing: .terminator)
        }
    }

    @Test
    func pseudoRandom1KiBRoundTrips() throws {
        var rng = LCG(state: 0xDEAD_BEEF_CAFE_F00D)
        let data = rng.bytes(1024)
        try roundTrip(data, framing: .none)
        try roundTrip(data, framing: .terminator)
    }

    @Test
    func pseudoRandom10KiBRoundTrips() throws {
        var rng = LCG(state: 0x0123_4567_89AB_CDEF)
        let data = rng.bytes(10 * 1024)
        try roundTrip(data, framing: .none)
        try roundTrip(data, framing: .terminator)
    }

    @Test
    func decodedSizeWithinMaxBound() throws {
        var rng = LCG(state: 0xAAAA_5555_BBBB_CCCC)
        let data = rng.bytes(2048)
        let enc = COBS.encoded(b(data))
        let dec = try COBS.decoded(enc)
        let bound = COBS.maxDecodedSize(forEncodedCount: enc.count)
        #expect(dec.count <= bound)
        #expect(dec.count == data.count)
    }
}
