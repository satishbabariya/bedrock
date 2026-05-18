import Testing
import UTF8Validator
import Bytes

@Suite
struct UTF8ValidatorASCIITests {

    private func b(_ xs: [UInt8]) -> Bytes { Bytes(xs) }

    @Test
    func everyASCIIByteIsValid() {
        for byte: UInt8 in 0x00 ... 0x7F {
            #expect(UTF8Validator.validate(b([byte])) == .valid,
                    "expected ASCII byte \(byte) to be valid")
            #expect(UTF8Validator.isValid(b([byte])),
                    "expected isValid for ASCII byte \(byte)")
        }
    }

    @Test
    func longASCIIStringIsValid() {
        let kib = Array(repeating: UInt8(0x41), count: 1024)
        #expect(UTF8Validator.validate(b(kib)) == .valid)
        #expect(UTF8Validator.isValid(b(kib)))
    }

    @Test
    func mixedASCIIRoundTrips() {
        let helloWorld: [UInt8] = [
            0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x2C, 0x20,
            0x57, 0x6F, 0x72, 0x6C, 0x64, 0x21,
        ]
        #expect(UTF8Validator.validate(b(helloWorld)) == .valid)
    }
}
