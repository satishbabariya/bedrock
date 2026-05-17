import Testing
import COBS
import Bytes

@Suite
struct COBSDecodeTests {

    private func b(_ xs: [UInt8]) -> Bytes { Bytes(xs) }

    @Test
    func decodeSingleCodeByteYieldsEmpty() throws {
        let out = try COBS.decoded(b([0x01]))
        #expect(Array(out) == [])
    }

    @Test
    func decodeSingleZero() throws {
        let out = try COBS.decoded(b([0x01, 0x01]))
        #expect(Array(out) == [0x00])
    }

    @Test
    func decodeTwoZeros() throws {
        let out = try COBS.decoded(b([0x01, 0x01, 0x01]))
        #expect(Array(out) == [0x00, 0x00])
    }

    @Test
    func decodeSingleNonZero() throws {
        let out = try COBS.decoded(b([0x02, 0x42]))
        #expect(Array(out) == [0x42])
    }

    @Test
    func decodePaperExample() throws {
        let out = try COBS.decoded(b([0x03, 0x11, 0x22, 0x02, 0x33]))
        #expect(Array(out) == [0x11, 0x22, 0x00, 0x33])
    }

    @Test
    func decodeLongerMixed() throws {
        let out = try COBS.decoded(b([0x01, 0x02, 0x11, 0x01, 0x03, 0x22, 0x33]))
        #expect(Array(out) == [0x00, 0x11, 0x00, 0x00, 0x22, 0x33])
    }

    @Test
    func decodeBlockMaxBoundary() throws {
        var encoded: [UInt8] = [0xFF]
        encoded.append(contentsOf: Array(repeating: UInt8(0x01), count: 254))
        encoded.append(0x01)
        let out = try COBS.decoded(b(encoded))
        #expect(Array(out) == Array(repeating: UInt8(0x01), count: 254))
    }

    @Test
    func decodeJustOverBlockMax() throws {
        var encoded: [UInt8] = [0xFF]
        encoded.append(contentsOf: Array(repeating: UInt8(0x01), count: 254))
        encoded.append(0x02)
        encoded.append(0x01)
        let out = try COBS.decoded(b(encoded))
        #expect(Array(out) == Array(repeating: UInt8(0x01), count: 255))
    }

    @Test
    func emptyInputIsTruncated() {
        #expect(throws: COBSError.truncated) {
            _ = try COBS.decoded(b([]))
        }
    }

    @Test
    func codeByteOverrunsInputIsTruncated() {
        #expect(throws: COBSError.truncated) {
            _ = try COBS.decoded(b([0x05, 0x11, 0x22, 0x33]))
        }
    }

    @Test
    func zeroInBodyIsInvalidZeroByte() {
        #expect {
            try COBS.decoded(b([0x00]))
        } throws: { error in
            guard let e = error as? COBSError,
                  case .invalidZeroByte(let off) = e else { return false }
            return off == 0
        }
    }

    @Test
    func zeroInsideBlockIsInvalidZeroByte() {
        #expect {
            try COBS.decoded(b([0x03, 0x11, 0x00, 0x33]))
        } throws: { error in
            guard let e = error as? COBSError,
                  case .invalidZeroByte(let off) = e else { return false }
            return off == 2
        }
    }

    @Test
    func decodeAppendsToExistingBytesMut() throws {
        var dst = BytesMut()
        dst.putUInt8(0xAA)
        let n = try COBS.decode(b([0x03, 0x11, 0x22]), into: &dst)
        #expect(n == 2)
        #expect(Array(dst.snapshot()) == [0xAA, 0x11, 0x22])
    }

    @Test
    func decodeReturnsZeroForEmptyEncoding() throws {
        var dst = BytesMut()
        let n = try COBS.decode(b([0x01]), into: &dst)
        #expect(n == 0)
        #expect(dst.snapshot().count == 0)
    }
}
