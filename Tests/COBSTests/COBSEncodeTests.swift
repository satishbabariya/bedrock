import Testing
import COBS
import Bytes

@Suite
struct COBSEncodeTests {

    private func b(_ xs: [UInt8]) -> Bytes { Bytes(xs) }

    @Test
    func emptyEncodesToSingleCodeByte() {
        let out = COBS.encoded(b([]))
        #expect(Array(out) == [0x01])
    }

    @Test
    func singleZeroEncodes() {
        let out = COBS.encoded(b([0x00]))
        #expect(Array(out) == [0x01, 0x01])
    }

    @Test
    func twoZerosEncode() {
        let out = COBS.encoded(b([0x00, 0x00]))
        #expect(Array(out) == [0x01, 0x01, 0x01])
    }

    @Test
    func singleNonZeroEncodes() {
        let out = COBS.encoded(b([0x42]))
        #expect(Array(out) == [0x02, 0x42])
    }

    @Test
    func paperExampleEncodes() {
        // [11 22 00 33] -> [03 11 22 02 33]
        let out = COBS.encoded(b([0x11, 0x22, 0x00, 0x33]))
        #expect(Array(out) == [0x03, 0x11, 0x22, 0x02, 0x33])
    }

    @Test
    func longerMixedEncodes() {
        // [00 11 00 00 22 33] -> [01 02 11 01 03 22 33]
        let out = COBS.encoded(b([0x00, 0x11, 0x00, 0x00, 0x22, 0x33]))
        #expect(Array(out) == [0x01, 0x02, 0x11, 0x01, 0x03, 0x22, 0x33])
    }

    @Test
    func twoHundredFiftyFourNonZeroHitsBlockMax() {
        // 254 non-zero bytes -> [FF, 01..01, 01] = 256 bytes total.
        let input = Bytes(Array(repeating: UInt8(0x01), count: 254))
        let out = Array(COBS.encoded(input))
        #expect(out.count == 256)
        #expect(out.first == 0xFF)
        #expect(Array(out[1..<255]) == Array(repeating: UInt8(0x01), count: 254))
        #expect(out.last == 0x01)
    }

    @Test
    func twoHundredFiftyFiveNonZeroSplitsBlocks() {
        // 255 non-zero bytes -> [FF, 01..01(254), 02, 01] = 257 bytes total.
        let input = Bytes(Array(repeating: UInt8(0x01), count: 255))
        let out = Array(COBS.encoded(input))
        #expect(out.count == 257)
        #expect(out[0] == 0xFF)
        #expect(out[255] == 0x02)
        #expect(out[256] == 0x01)
    }

    @Test
    func twoHundredFiftyFourZeros() {
        // 254 zeros -> 255 bytes of 0x01.
        let input = Bytes(Array(repeating: UInt8(0x00), count: 254))
        let out = Array(COBS.encoded(input))
        #expect(out == Array(repeating: UInt8(0x01), count: 255))
    }

    @Test
    func terminatorFramingAppendsZero() {
        let out = COBS.encoded(b([0x11, 0x22]), framing: .terminator)
        #expect(Array(out) == [0x03, 0x11, 0x22, 0x00])
    }

    @Test
    func terminatorFramingOnEmpty() {
        let out = COBS.encoded(b([]), framing: .terminator)
        #expect(Array(out) == [0x01, 0x00])
    }

    @Test
    func encodeAppendsToExistingBytesMut() {
        var dst = BytesMut()
        dst.putUInt8(0xAA)
        dst.putUInt8(0xBB)
        let n = COBS.encode(b([0x11, 0x22]), into: &dst)
        let arr = Array(dst.snapshot())
        #expect(Array(arr.prefix(2)) == [0xAA, 0xBB])
        #expect(Array(arr.suffix(arr.count - 2)) == [0x03, 0x11, 0x22])
        #expect(n == 3)
    }

    @Test
    func encodeReturnsAppendedCountWithTerminator() {
        var dst = BytesMut()
        let n = COBS.encode(b([]), into: &dst, framing: .terminator)
        #expect(n == 2)
        #expect(Array(dst.snapshot()) == [0x01, 0x00])
    }
}
