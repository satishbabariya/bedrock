import Testing
import UnicodeProperties

@Suite
struct SimpleCaseMappingTests {

    @Test
    func asciiBidirectionalPairs() {
        #expect(UnicodeProperties.simpleLowercase(of: "A") == "a")
        #expect(UnicodeProperties.simpleLowercase(of: "Z") == "z")
        #expect(UnicodeProperties.simpleUppercase(of: "a") == "A")
        #expect(UnicodeProperties.simpleUppercase(of: "z") == "Z")
    }

    @Test
    func asciiTitlecaseOfLowercaseIsUppercase() {
        #expect(UnicodeProperties.simpleTitlecase(of: "a") == "A")
    }

    @Test
    func asciiIdentities() {
        #expect(UnicodeProperties.simpleUppercase(of: "A") == "A")
        #expect(UnicodeProperties.simpleLowercase(of: "a") == "a")
    }

    @Test
    func asciiNonLettersIdentity() {
        #expect(UnicodeProperties.simpleUppercase(of: "5") == "5")
        #expect(UnicodeProperties.simpleLowercase(of: " ") == " ")
        #expect(UnicodeProperties.simpleTitlecase(of: "!") == "!")
    }

    @Test
    func titlecaseLetterU01C5() {
        let titlecase = Unicode.Scalar(0x01C5)!
        #expect(UnicodeProperties.simpleUppercase(of: titlecase) == Unicode.Scalar(0x01C4)!)
        #expect(UnicodeProperties.simpleLowercase(of: titlecase) == Unicode.Scalar(0x01C6)!)
        #expect(UnicodeProperties.simpleTitlecase(of: titlecase) == titlecase)
    }

    @Test
    func latin1Supplement() {
        #expect(UnicodeProperties.simpleLowercase(of: Unicode.Scalar(0x00C0)!) == Unicode.Scalar(0x00E0)!)
        #expect(UnicodeProperties.simpleUppercase(of: Unicode.Scalar(0x00E0)!) == Unicode.Scalar(0x00C0)!)
    }

    @Test
    func greekCapitalSigma() {
        #expect(UnicodeProperties.simpleLowercase(of: Unicode.Scalar(0x03A3)!) == Unicode.Scalar(0x03C3)!)
    }

    @Test
    func cjkIdentity() {
        let cjk = Unicode.Scalar(0x6F22)!
        #expect(UnicodeProperties.simpleUppercase(of: cjk) == cjk)
        #expect(UnicodeProperties.simpleLowercase(of: cjk) == cjk)
        #expect(UnicodeProperties.simpleTitlecase(of: cjk) == cjk)
    }

    @Test
    func sharpSStaysIdentityInV1() {
        // U+00DF has no single-codepoint uppercase (would need SpecialCasing.txt)
        let sharpS = Unicode.Scalar(0x00DF)!
        #expect(UnicodeProperties.simpleUppercase(of: sharpS) == sharpS)
    }
}
