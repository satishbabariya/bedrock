import Testing
import UTF8Validator
import Bytes

@Suite
struct UTF8ValidatorExtensionsTests {

    private func b(_ xs: [UInt8]) -> Bytes { Bytes(xs) }

    @Test
    func isValidUTF8MatchesNamespaceCall() {
        let valid = b([0x41, 0xC2, 0xA9])
        let invalid = b([0xC0, 0x80])
        #expect(valid.isValidUTF8 == UTF8Validator.isValid(valid))
        #expect(invalid.isValidUTF8 == UTF8Validator.isValid(invalid))
        #expect(valid.isValidUTF8)
        #expect(invalid.isValidUTF8 == false)
    }

    @Test
    func validateUTF8MatchesNamespaceCall() {
        let valid = b([0x41])
        let invalid = b([0x41, 0xFF])
        #expect(valid.validateUTF8() == UTF8Validator.validate(valid))
        #expect(invalid.validateUTF8() == UTF8Validator.validate(invalid))
        #expect(invalid.validateUTF8() == .invalid(offset: 1))
    }

    @Test
    func extensionsOnEmpty() {
        let empty = b([])
        #expect(empty.isValidUTF8)
        #expect(empty.validateUTF8() == .valid)
    }
}
