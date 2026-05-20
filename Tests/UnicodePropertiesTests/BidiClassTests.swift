import Testing
import UnicodeProperties

@Suite
struct BidiClassTests {

    private func cls(_ scalar: Unicode.Scalar) -> UnicodeProperties.BidiClass {
        UnicodeProperties.bidiClass(of: scalar)
    }

    @Test
    func ascii() {
        #expect(cls("A") == .leftToRight)
        #expect(cls("5") == .europeanNumber)
        #expect(cls(" ") == .whiteSpace)
        #expect(cls("$") == .europeanTerminator)
        #expect(cls(",") == .commonSeparator)
    }

    @Test
    func hebrewIsRightToLeft() {
        #expect(cls("\u{05D0}") == .rightToLeft)
    }

    @Test
    func arabicIsArabicLetter() {
        #expect(cls("\u{0627}") == .arabicLetter)
    }

    @Test
    func combiningMarkIsNSM() {
        #expect(cls("\u{0301}") == .nonspacingMark)
    }

    @Test
    func paragraphSeparator() {
        #expect(cls(Unicode.Scalar(0x2029)!) == .paragraphSeparator)
    }

    @Test
    func explicitFormattingCharacters() {
        #expect(cls(Unicode.Scalar(0x202A)!) == .leftToRightEmbedding)
        #expect(cls(Unicode.Scalar(0x202B)!) == .rightToLeftEmbedding)
        #expect(cls(Unicode.Scalar(0x202C)!) == .popDirectionalFormat)
        #expect(cls(Unicode.Scalar(0x202D)!) == .leftToRightOverride)
        #expect(cls(Unicode.Scalar(0x202E)!) == .rightToLeftOverride)
        #expect(cls(Unicode.Scalar(0x2066)!) == .leftToRightIsolate)
        #expect(cls(Unicode.Scalar(0x2067)!) == .rightToLeftIsolate)
        #expect(cls(Unicode.Scalar(0x2068)!) == .firstStrongIsolate)
        #expect(cls(Unicode.Scalar(0x2069)!) == .popDirectionalIsolate)
    }
}
