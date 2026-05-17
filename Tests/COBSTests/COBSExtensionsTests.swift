import Testing
import COBS
import Bytes

@Suite
struct COBSExtensionsTests {

    private func b(_ xs: [UInt8]) -> Bytes { Bytes(xs) }

    @Test
    func cobsEncodedMatchesNamespaceCall() {
        let input = b([0x11, 0x22, 0x00, 0x33])
        let viaExt = input.cobsEncoded()
        let viaNS  = COBS.encoded(input)
        #expect(Array(viaExt) == Array(viaNS))
    }

    @Test
    func cobsEncodedTerminatorMatchesNamespace() {
        let input = b([0x00, 0xFF, 0x00])
        let viaExt = input.cobsEncoded(framing: .terminator)
        let viaNS  = COBS.encoded(input, framing: .terminator)
        #expect(Array(viaExt) == Array(viaNS))
    }

    @Test
    func bytesInitDecodingMatchesNamespace() throws {
        let encoded = b([0x03, 0x11, 0x22, 0x02, 0x33])
        let viaInit = try Bytes(cobsDecoding: encoded)
        let viaNS   = try COBS.decoded(encoded)
        #expect(Array(viaInit) == Array(viaNS))
    }

    @Test
    func bytesInitDecodingTerminatorMatchesNamespace() throws {
        let encoded = b([0x03, 0x11, 0x22, 0x00])
        let viaInit = try Bytes(cobsDecoding: encoded, framing: .terminator)
        let viaNS   = try COBS.decoded(encoded, framing: .terminator)
        #expect(Array(viaInit) == Array(viaNS))
    }

    @Test
    func roundTripThroughExtensions() throws {
        let input = b([0x00, 0x11, 0x22, 0x00, 0x33, 0xFF, 0x00])
        let enc = input.cobsEncoded(framing: .terminator)
        let dec = try Bytes(cobsDecoding: enc, framing: .terminator)
        #expect(Array(dec) == Array(input))
    }

    @Test
    func bytesInitDecodingPropagatesError() {
        #expect(throws: COBSError.truncated) {
            _ = try Bytes(cobsDecoding: b([]))
        }
    }
}
