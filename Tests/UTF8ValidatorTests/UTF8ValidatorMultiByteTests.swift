import Testing
import UTF8Validator
import Bytes

@Suite
struct UTF8ValidatorMultiByteTests {

    private func b(_ xs: [UInt8]) -> Bytes { Bytes(xs) }

    @Test
    func twoByteLowerBound() {
        // U+0080 = C2 80
        #expect(UTF8Validator.validate(b([0xC2, 0x80])) == .valid)
    }

    @Test
    func twoByteCopyright() {
        // U+00A9 © = C2 A9
        #expect(UTF8Validator.validate(b([0xC2, 0xA9])) == .valid)
    }

    @Test
    func twoByteUpperBound() {
        // U+07FF = DF BF
        #expect(UTF8Validator.validate(b([0xDF, 0xBF])) == .valid)
    }

    @Test
    func threeByteLowerBound() {
        // U+0800 = E0 A0 80
        #expect(UTF8Validator.validate(b([0xE0, 0xA0, 0x80])) == .valid)
    }

    @Test
    func threeByteEuro() {
        // U+20AC € = E2 82 AC
        #expect(UTF8Validator.validate(b([0xE2, 0x82, 0xAC])) == .valid)
    }

    @Test
    func threeByteReplacementChar() {
        // U+FFFD = EF BF BD
        #expect(UTF8Validator.validate(b([0xEF, 0xBF, 0xBD])) == .valid)
    }

    @Test
    func threeByteUpperBound() {
        // U+FFFF = EF BF BF
        #expect(UTF8Validator.validate(b([0xEF, 0xBF, 0xBF])) == .valid)
    }

    @Test
    func threeByteJustBeforeSurrogates() {
        // U+D7FF = ED 9F BF
        #expect(UTF8Validator.validate(b([0xED, 0x9F, 0xBF])) == .valid)
    }

    @Test
    func threeByteJustAfterSurrogates() {
        // U+E000 = EE 80 80
        #expect(UTF8Validator.validate(b([0xEE, 0x80, 0x80])) == .valid)
    }

    @Test
    func fourByteLowerBound() {
        // U+10000 = F0 90 80 80
        #expect(UTF8Validator.validate(b([0xF0, 0x90, 0x80, 0x80])) == .valid)
    }

    @Test
    func fourByteGrinningFace() {
        // U+1F600 😀 = F0 9F 98 80
        #expect(UTF8Validator.validate(b([0xF0, 0x9F, 0x98, 0x80])) == .valid)
    }

    @Test
    func fourByteUpperBound() {
        // U+10FFFF = F4 8F BF BF
        #expect(UTF8Validator.validate(b([0xF4, 0x8F, 0xBF, 0xBF])) == .valid)
    }

    @Test
    func interleaved() {
        let mixed: [UInt8] = [
            0x41,
            0xC2, 0xA9,
            0xE2, 0x82, 0xAC,
            0xF0, 0x9F, 0x98, 0x80,
        ]
        #expect(UTF8Validator.validate(b(mixed)) == .valid)
    }
}
