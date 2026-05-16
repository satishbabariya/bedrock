import Testing
import Bytes
@testable import BitSet

@Test func bitZeroBytes() {
    let s: BitSet = [0]
    #expect(Array(s.bytes) == [0x01])
}

@Test func bitSevenBytes() {
    let s: BitSet = [7]
    #expect(Array(s.bytes) == [0x80])
}

@Test func bitEightBytes() {
    let s: BitSet = [8]
    #expect(Array(s.bytes) == [0x00, 0x01])
}

@Test func emptyBytes() {
    let s = BitSet()
    #expect(Array(s.bytes) == [])
}

@Test func multipleBitsInOneByte() {
    let s: BitSet = [0, 1]
    let bytes = Array(s.bytes)
    #expect(bytes == [0x03])
    #expect(bytes.count == 1)
}

@Test func trailingZeroBytesTrimmedOnEmit() {
    var s = BitSet([0, 1])
    s.insert(1000)
    s.remove(1000)
    // Storage has many words, but only bits 0 and 1 are set.
    let bytes = Array(s.bytes)
    #expect(bytes == [0x03])
}

@Test func roundTripBytePositions() throws {
    for bit in 0..<201 {
        let original: BitSet = [bit]
        let decoded = BitSet(bytes: original.bytes)
        #expect(decoded == original, "round-trip failed for bit \(bit)")
    }
}

@Test func decodeAcceptsTrailingZeroBytes() {
    let s = BitSet(bytes: Bytes([0x00, 0x00, 0x00]))
    #expect(s.isEmpty)
}

@Test func roundTripDeterministicBuffer() throws {
    // Build a BitSet from a known byte buffer; encode; verify identical bytes.
    var state: UInt64 = 0xABCD_EF01_2345_6789
    func next() -> UInt8 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return UInt8((state >> 56) & 0xFF)
    }
    var raw: [UInt8] = []
    raw.reserveCapacity(256)
    for _ in 0..<256 { raw.append(next()) }
    // Ensure the last byte is non-zero so no trim occurs on round-trip.
    raw[raw.count - 1] |= 0x01
    let original = Bytes(raw)
    let s = BitSet(bytes: original)
    #expect(s.bytes == original)
}
