import Testing
import COBS

@Suite
struct COBSSizingTests {

    @Test
    func framingHasNoneAndTerminator() {
        let a: COBS.Framing = .none
        let b: COBS.Framing = .terminator
        #expect(a != b)
        #expect(a == .none)
        #expect(b == .terminator)
    }

    @Test
    func framingIsSendableAndHashable() {
        var s = Set<COBS.Framing>()
        s.insert(.none)
        s.insert(.none)
        s.insert(.terminator)
        #expect(s.count == 2)
    }

    @Test
    func maxEncodedSizeEmptyBodyOnly() {
        // Empty encodes to [0x01].
        #expect(COBS.maxEncodedSize(forSourceCount: 0) == 1)
    }

    @Test
    func maxEncodedSizeEmptyTerminator() {
        // Empty encodes to [0x01, 0x00].
        #expect(COBS.maxEncodedSize(forSourceCount: 0, framing: .terminator) == 2)
    }

    @Test
    func maxEncodedSizeBodyOnlySmall() {
        // n=1: 1 + ⌈1/254⌉(=1) + 1 = 3 (upper bound; actual is 2).
        #expect(COBS.maxEncodedSize(forSourceCount: 1) == 3)
        // n=253: 253 + ⌈253/254⌉(=1) + 1 = 255 (upper bound; actual is 254).
        #expect(COBS.maxEncodedSize(forSourceCount: 253) == 255)
    }

    @Test
    func maxEncodedSizeBoundaryAt254() {
        // n=254: 254 + ⌈254/254⌉(=1) + 1 = 256 (tight — actual is 256).
        #expect(COBS.maxEncodedSize(forSourceCount: 254) == 256)
    }

    @Test
    func maxEncodedSizeBoundaryAt255() {
        // n=255: 255 + ⌈255/254⌉(=2) + 1 = 258 (upper bound; actual is 257).
        #expect(COBS.maxEncodedSize(forSourceCount: 255) == 258)
    }

    @Test
    func maxEncodedSizeTerminatorAdds1() {
        let bodyOnly = COBS.maxEncodedSize(forSourceCount: 254)
        let framed   = COBS.maxEncodedSize(forSourceCount: 254, framing: .terminator)
        #expect(framed == bodyOnly + 1)
    }

    @Test
    func maxDecodedSizeBodyOnly() {
        #expect(COBS.maxDecodedSize(forEncodedCount: 0) == 0)
        #expect(COBS.maxDecodedSize(forEncodedCount: 1) == 0)
        #expect(COBS.maxDecodedSize(forEncodedCount: 5) == 4)
    }

    @Test
    func maxDecodedSizeTerminator() {
        #expect(COBS.maxDecodedSize(forEncodedCount: 0, framing: .terminator) == 0)
        #expect(COBS.maxDecodedSize(forEncodedCount: 1, framing: .terminator) == 0)
        #expect(COBS.maxDecodedSize(forEncodedCount: 2, framing: .terminator) == 0)
        #expect(COBS.maxDecodedSize(forEncodedCount: 5, framing: .terminator) == 3)
    }
}
