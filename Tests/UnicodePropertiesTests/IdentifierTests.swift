import Testing
import UnicodeProperties

@Suite
struct IdentifierTests {

    @Test
    func asciiLettersAreStart() {
        #expect(UnicodeProperties.isXIDStart("A"))
        #expect(UnicodeProperties.isXIDStart("Z"))
        #expect(UnicodeProperties.isXIDStart("a"))
        #expect(UnicodeProperties.isXIDStart("z"))
    }

    @Test
    func asciiDigitsAreContinueOnly() {
        #expect(UnicodeProperties.isXIDStart("0") == false)
        #expect(UnicodeProperties.isXIDStart("9") == false)
        #expect(UnicodeProperties.isXIDContinue("0"))
        #expect(UnicodeProperties.isXIDContinue("9"))
    }

    @Test
    func underscoreIsContinueOnly() {
        #expect(UnicodeProperties.isXIDStart("_") == false)
        #expect(UnicodeProperties.isXIDContinue("_"))
    }

    @Test
    func asciiSpaceAndPunctuationAreNeither() {
        #expect(UnicodeProperties.isXIDStart(" ") == false)
        #expect(UnicodeProperties.isXIDContinue(" ") == false)
        #expect(UnicodeProperties.isXIDStart("!") == false)
        #expect(UnicodeProperties.isXIDContinue("!") == false)
    }

    @Test
    func latin1Letters() {
        #expect(UnicodeProperties.isXIDStart(Unicode.Scalar(0x00C0)!))
        #expect(UnicodeProperties.isXIDContinue(Unicode.Scalar(0x00C0)!))
    }

    @Test
    func middleDotIsContinueOnly() {
        // · U+00B7 MIDDLE DOT — per UAX #31, in XID_Continue but not XID_Start.
        #expect(UnicodeProperties.isXIDStart(Unicode.Scalar(0x00B7)!) == false)
        #expect(UnicodeProperties.isXIDContinue(Unicode.Scalar(0x00B7)!))
    }

    @Test
    func combiningMarksAreContinueOnly() {
        #expect(UnicodeProperties.isXIDStart(Unicode.Scalar(0x0301)!) == false)
        #expect(UnicodeProperties.isXIDContinue(Unicode.Scalar(0x0301)!))
    }

    @Test
    func cjkIsBoth() {
        let cjk = Unicode.Scalar(0x6F22)!
        #expect(UnicodeProperties.isXIDStart(cjk))
        #expect(UnicodeProperties.isXIDContinue(cjk))
    }

    @Test
    func greekIsBoth() {
        #expect(UnicodeProperties.isXIDStart(Unicode.Scalar(0x03A3)!))
        #expect(UnicodeProperties.isXIDStart(Unicode.Scalar(0x03C2)!))
        #expect(UnicodeProperties.isXIDContinue(Unicode.Scalar(0x03A3)!))
    }

    @Test
    func privateUseAndFormatAreNeither() {
        #expect(UnicodeProperties.isXIDStart(Unicode.Scalar(0xE000)!) == false)
        #expect(UnicodeProperties.isXIDContinue(Unicode.Scalar(0xE000)!) == false)
        #expect(UnicodeProperties.isXIDStart(Unicode.Scalar(0x200B)!) == false)
        #expect(UnicodeProperties.isXIDContinue(Unicode.Scalar(0x200B)!) == false)
    }

    @Test
    func startImpliesContinueAcrossSample() {
        let samples: [UInt32] = [0x41, 0x5A, 0x61, 0x7A, 0xC0, 0x03A3,
                                  0x6F22, 0x4E00, 0x10000, 0x1F49,
                                  0x0531, 0x0561]
        for cp in samples {
            let s = Unicode.Scalar(cp)!
            if UnicodeProperties.isXIDStart(s) {
                #expect(UnicodeProperties.isXIDContinue(s),
                        "U+\(String(cp, radix: 16)) is XID_Start but not XID_Continue")
            }
        }
    }
}
