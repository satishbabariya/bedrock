import Testing
import UTF8Validator
import Bytes

@Suite
struct UTF8ValidatorRejectionTests {

    private func b(_ xs: [UInt8]) -> Bytes { Bytes(xs) }

    private func reject(_ xs: [UInt8], _ msg: String) {
        let r = UTF8Validator.validate(b(xs))
        if case .valid = r {
            Issue.record("expected rejection for \(msg) — got .valid")
        }
        #expect(UTF8Validator.isValid(b(xs)) == false,
                "expected isValid==false for \(msg)")
    }

    // Overlongs
    @Test func overlongNullTwoByte() { reject([0xC0, 0x80], "U+0000 as 2-byte") }
    @Test func overlongNullThreeByte() { reject([0xE0, 0x80, 0x80], "U+0000 as 3-byte") }
    @Test func overlongNullFourByte() { reject([0xF0, 0x80, 0x80, 0x80], "U+0000 as 4-byte") }
    @Test func overlongDeleteTwoByte() { reject([0xC1, 0xBF], "U+007F as 2-byte") }
    @Test func overlong07FFThreeByte() { reject([0xE0, 0x9F, 0xBF], "U+07FF as 3-byte") }
    @Test func overlongFFFFFourByte() { reject([0xF0, 0x8F, 0xBF, 0xBF], "U+FFFF as 4-byte") }

    // Surrogates
    @Test func surrogateLowerBound() { reject([0xED, 0xA0, 0x80], "U+D800") }
    @Test func surrogateMidpoint() { reject([0xED, 0xAA, 0xAA], "U+DAAA") }
    @Test func surrogateUpperBound() { reject([0xED, 0xBF, 0xBF], "U+DFFF") }

    // Out of range
    @Test func outOfRangeJustAboveMax() { reject([0xF4, 0x90, 0x80, 0x80], "U+110000") }
    @Test func fiveByteSequence() { reject([0xF8, 0x87, 0xBF, 0xBF, 0xBF], "5-byte form") }
    @Test func sixByteSequence() { reject([0xFC, 0x84, 0x80, 0x80, 0x80, 0x80], "6-byte form") }

    // Invalid lead bytes
    @Test func invalidLeadC0() { reject([0xC0], "0xC0 alone") }
    @Test func invalidLeadC1() { reject([0xC1], "0xC1 alone") }

    @Test
    func invalidLeadsF5ThroughFF() {
        for byte: UInt8 in 0xF5 ... 0xFF {
            reject([byte], "\(String(byte, radix: 16)) alone")
        }
    }

    @Test
    func strayContinuations() {
        for byte: UInt8 in 0x80 ... 0xBF {
            reject([byte], "stray cont \(String(byte, radix: 16))")
        }
    }

    // Truncated
    @Test func truncatedTwoByteLead() { reject([0xC2], "C2 without cont") }
    @Test func truncatedThreeByteAfterLead() { reject([0xE2], "E2 alone") }
    @Test func truncatedThreeByteAfterOneCont() { reject([0xE2, 0x82], "E2 82 (1 of 2 conts)") }
    @Test func truncatedFourByteAfterLead() { reject([0xF0], "F0 alone") }
    @Test func truncatedFourByteAfterTwoConts() { reject([0xF0, 0x9F, 0x98], "F0 9F 98 (2 of 3 conts)") }

    // Mid-sequence garbage
    @Test
    func validPrefixBadByteValidSuffix() {
        let xs: [UInt8] = [
            0x41,
            0xE2, 0x82, 0xAC,
            0xC0,
            0x42,
        ]
        let r = UTF8Validator.validate(b(xs))
        if case .valid = r {
            Issue.record("expected rejection")
        }
    }
}
