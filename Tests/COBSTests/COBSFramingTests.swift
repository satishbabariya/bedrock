import Testing
import COBS
import Bytes

@Suite
struct COBSFramingTests {

    private func b(_ xs: [UInt8]) -> Bytes { Bytes(xs) }

    @Test
    func terminatorEncodeAppendsZero() {
        let out = COBS.encoded(b([0x11, 0x22]), framing: .terminator)
        #expect(Array(out).last == 0x00)
    }

    @Test
    func terminatorDecodeStripsZero() throws {
        let out = try COBS.decoded(b([0x03, 0x11, 0x22, 0x00]), framing: .terminator)
        #expect(Array(out) == [0x11, 0x22])
    }

    @Test
    func terminatorDecodeMissingFinalZero() {
        // Last byte 0x33 != 0x00.
        #expect(throws: COBSError.missingTerminator) {
            _ = try COBS.decoded(b([0x03, 0x11, 0x22, 0x33]), framing: .terminator)
        }
    }

    @Test
    func terminatorDecodeEmptyInputMissingTerminator() {
        #expect(throws: COBSError.missingTerminator) {
            _ = try COBS.decoded(b([]), framing: .terminator)
        }
    }

    @Test
    func terminatorDecodeMidStreamZeroIsUnexpected() {
        // [01 00 01 00] under .terminator framing:
        // After stripping trailing 0x00, payload = [01 00 01].
        // i=0 code=1 blockEnd=1 no body. code<0xFF, i==1<3, emit 0x00 separator. i=1.
        // i=1 code=0x00 — code byte itself is zero -> unexpectedTerminator(offset: 1).
        #expect {
            try COBS.decoded(b([0x01, 0x00, 0x01, 0x00]), framing: .terminator)
        } throws: { error in
            guard let e = error as? COBSError,
                  case .unexpectedTerminator(let off) = e else { return false }
            return off == 1
        }
    }

    @Test
    func emptyRoundTripFramed() throws {
        let enc = COBS.encoded(b([]), framing: .terminator)
        #expect(Array(enc) == [0x01, 0x00])
        let dec = try COBS.decoded(enc, framing: .terminator)
        #expect(Array(dec) == [])
    }

    @Test
    func framedRoundTripWithEmbeddedZeros() throws {
        let input = b([0x00, 0x11, 0x00, 0x22, 0x33, 0x00])
        let enc = COBS.encoded(input, framing: .terminator)
        #expect(Array(enc).last == 0x00)
        let dec = try COBS.decoded(enc, framing: .terminator)
        #expect(Array(dec) == Array(input))
    }
}
