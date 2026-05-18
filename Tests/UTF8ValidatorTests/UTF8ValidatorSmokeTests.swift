import Testing
import UTF8Validator
import Bytes

@Suite
struct UTF8ValidatorSmokeTests {

    private func b(_ xs: [UInt8]) -> Bytes { Bytes(xs) }

    @Test
    func emptyIsValid() {
        #expect(UTF8Validator.validate(b([])) == .valid)
        #expect(UTF8Validator.isValid(b([])))
    }

    @Test
    func singleASCIIByteIsValid() {
        #expect(UTF8Validator.validate(b([0x41])) == .valid)
        #expect(UTF8Validator.isValid(b([0x41])))
    }

    @Test
    func standaloneContinuationIsInvalid() {
        let r = UTF8Validator.validate(b([0x80]))
        #expect(r == .invalid(offset: 0))
        #expect(UTF8Validator.isValid(b([0x80])) == false)
    }

    @Test
    func wellFormedTwoByteSequenceIsValid() {
        // U+00A9 © = C2 A9
        #expect(UTF8Validator.validate(b([0xC2, 0xA9])) == .valid)
    }

    @Test
    func truncatedLeadByteIsInvalidAtSequenceStart() {
        // C2 alone (lead 2-byte, no cont)
        #expect(UTF8Validator.validate(b([0xC2])) == .invalid(offset: 0))
    }
}
