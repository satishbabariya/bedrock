import Testing
import UTF8Validator
import Bytes

@Suite
struct UTF8ValidatorOffsetTests {

    private func b(_ xs: [UInt8]) -> Bytes { Bytes(xs) }

    @Test
    func badByteAtStartOffsetZero() {
        #expect(UTF8Validator.validate(b([0xFF])) == .invalid(offset: 0))
    }

    @Test
    func badByteAfterASCIIPrefix() {
        #expect(UTF8Validator.validate(b([0x41, 0x42, 0x43, 0xFF]))
                == .invalid(offset: 3))
    }

    @Test
    func badContinuationOffsetEqualsLeadIndex() {
        // ASCII "A" then 3-byte lead E2 then bad cont C0
        #expect(UTF8Validator.validate(b([0x41, 0xE2, 0xC0]))
                == .invalid(offset: 1))
    }

    @Test
    func truncatedSequenceOffsetIsLeadIndex() {
        // ASCII "AB" then 3-byte lead E2 with no continuations
        #expect(UTF8Validator.validate(b([0x41, 0x42, 0xE2]))
                == .invalid(offset: 2))
    }

    @Test
    func truncatedFourByteOffsetIsLeadIndex() {
        // ASCII "A" then F0 9F (lead + 1 of 3 conts)
        #expect(UTF8Validator.validate(b([0x41, 0xF0, 0x9F]))
                == .invalid(offset: 1))
    }

    @Test
    func strayContinuationOffsetIsItsOwnIndex() {
        // ASCII "AB" then stray 0xBF
        #expect(UTF8Validator.validate(b([0x41, 0x42, 0xBF]))
                == .invalid(offset: 2))
    }

    @Test
    func surrogateOffsetIsLeadIndex() {
        // ASCII "X" then ED A0 80 (surrogate)
        #expect(UTF8Validator.validate(b([0x58, 0xED, 0xA0, 0x80]))
                == .invalid(offset: 1))
    }

    @Test
    func overlongOffsetIsLeadIndex() {
        // ASCII "X" then C0 80 (overlong null) - C0 is an invalid lead (cls 11)
        #expect(UTF8Validator.validate(b([0x58, 0xC0, 0x80]))
                == .invalid(offset: 1))
    }

    @Test
    func multipleValidSequencesThenBadByte() {
        // "A" + € + 😀 + 0xFF
        let xs: [UInt8] = [
            0x41,                       // A     (offset 0)
            0xE2, 0x82, 0xAC,           // €     (offsets 1..3)
            0xF0, 0x9F, 0x98, 0x80,     // 😀    (offsets 4..7)
            0xFF,                        // bad  (offset 8)
        ]
        #expect(UTF8Validator.validate(b(xs)) == .invalid(offset: 8))
    }
}
