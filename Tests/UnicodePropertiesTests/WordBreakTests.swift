import Testing
import UnicodeProperties

@Suite
struct WordBreakTests {

    private func wb(_ scalar: Unicode.Scalar) -> UnicodeProperties.WordBreak {
        UnicodeProperties.wordBreak(of: scalar)
    }

    @Test
    func crIsCR() {
        // U+000D CARRIAGE RETURN
        #expect(wb(Unicode.Scalar(0x000D)!) == .cr)
    }

    @Test
    func lfIsLF() {
        // U+000A LINE FEED
        #expect(wb(Unicode.Scalar(0x000A)!) == .lf)
    }

    @Test
    func verticalTabIsNewline() {
        // U+000B <control-000B> — in Newline range 000B..000C
        #expect(wb(Unicode.Scalar(0x000B)!) == .newline)
    }

    @Test
    func nelIsNewline() {
        // U+0085 NEXT LINE (NEL)
        #expect(wb(Unicode.Scalar(0x0085)!) == .newline)
    }

    @Test
    func combiningGraveIsExtend() {
        // U+0300 COMBINING GRAVE ACCENT — first of Extend range 0300..036F
        #expect(wb(Unicode.Scalar(0x0300)!) == .extend)
    }

    @Test
    func zwjIsZWJ() {
        // U+200D ZERO WIDTH JOINER
        #expect(wb(Unicode.Scalar(0x200D)!) == .zwj)
    }

    @Test
    func regionalIndicatorAIsRegionalIndicator() {
        // U+1F1E6 REGIONAL INDICATOR SYMBOL LETTER A
        #expect(wb(Unicode.Scalar(0x1F1E6)!) == .regionalIndicator)
    }

    @Test
    func softHyphenIsFormat() {
        // U+00AD SOFT HYPHEN — listed as Format
        #expect(wb(Unicode.Scalar(0x00AD)!) == .format)
    }

    @Test
    func katakanaHiraganaDoubleHyphenIsKatakana() {
        // U+30A0 KATAKANA-HIRAGANA DOUBLE HYPHEN
        #expect(wb(Unicode.Scalar(0x30A0)!) == .katakana)
    }

    @Test
    func hebrewAlefIsHebrewLetter() {
        // U+05D0 HEBREW LETTER ALEF — first of Hebrew_Letter range 05D0..05EA
        #expect(wb(Unicode.Scalar(0x05D0)!) == .hebrewLetter)
    }

    @Test
    func latinCapitalAIsALetter() {
        // U+0041 LATIN CAPITAL LETTER A — first of ALetter range 0041..005A
        #expect(wb("A") == .aLetter)
    }

    @Test
    func apostropheIsSingleQuote() {
        // U+0027 APOSTROPHE
        #expect(wb(Unicode.Scalar(0x0027)!) == .singleQuote)
    }

    @Test
    func quotationMarkIsDoubleQuote() {
        // U+0022 QUOTATION MARK
        #expect(wb(Unicode.Scalar(0x0022)!) == .doubleQuote)
    }

    @Test
    func fullStopIsMidNumLet() {
        // U+002E FULL STOP
        #expect(wb(Unicode.Scalar(0x002E)!) == .midNumLet)
    }

    @Test
    func colonIsMidLetter() {
        // U+003A COLON
        #expect(wb(Unicode.Scalar(0x003A)!) == .midLetter)
    }

    @Test
    func commaIsMidNum() {
        // U+002C COMMA
        #expect(wb(Unicode.Scalar(0x002C)!) == .midNum)
    }

    @Test
    func digitZeroIsNumeric() {
        // U+0030 DIGIT ZERO — first of Numeric range 0030..0039
        #expect(wb(Unicode.Scalar(0x0030)!) == .numeric)
    }

    @Test
    func lowLineIsExtendNumLet() {
        // U+005F LOW LINE (underscore)
        #expect(wb(Unicode.Scalar(0x005F)!) == .extendNumLet)
    }

    @Test
    func spaceIsWSegSpace() {
        // U+0020 SPACE
        #expect(wb(Unicode.Scalar(0x0020)!) == .wSegSpace)
    }

    @Test
    func cjkUnifiedIdeographIsOther() {
        // U+4E00 CJK UNIFIED IDEOGRAPH-4E00 — not in WordBreakProperty.txt
        #expect(wb(Unicode.Scalar(0x4E00)!) == .other)
    }

    @Test
    func enumHasNineteenCases() {
        #expect(UnicodeProperties.WordBreak.allCases.count == 19)
    }

    @Test
    func rawValuesAreInRange() {
        for wb in UnicodeProperties.WordBreak.allCases {
            #expect(wb.rawValue <= 18)
        }
    }
}
