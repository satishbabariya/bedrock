import Testing
import UnicodeProperties

@Suite
struct SentenceBreakTests {

    private func sb(_ scalar: Unicode.Scalar) -> UnicodeProperties.SentenceBreak {
        UnicodeProperties.sentenceBreak(of: scalar)
    }

    @Test
    func crIsCR() {
        // U+000D CARRIAGE RETURN
        #expect(sb(Unicode.Scalar(0x000D)!) == .cr)
    }

    @Test
    func lfIsLF() {
        // U+000A LINE FEED
        #expect(sb(Unicode.Scalar(0x000A)!) == .lf)
    }

    @Test
    func nextLineIsSep() {
        // U+0085 NEXT LINE — only Sep codepoint in low BMP
        #expect(sb(Unicode.Scalar(0x0085)!) == .sep)
    }

    @Test
    func combiningGraveIsExtend() {
        // U+0300 COMBINING GRAVE ACCENT — first of Extend range 0300..036F
        #expect(sb(Unicode.Scalar(0x0300)!) == .extend)
    }

    @Test
    func softHyphenIsFormat() {
        // U+00AD SOFT HYPHEN — single-codepoint Format entry
        #expect(sb(Unicode.Scalar(0x00AD)!) == .format)
    }

    @Test
    func spaceIsSp() {
        // U+0020 SPACE
        #expect(sb(Unicode.Scalar(0x0020)!) == .sp)
    }

    @Test
    func latinSmallAIsLower() {
        // U+0061 LATIN SMALL LETTER A — first of Lower range 0061..007A
        #expect(sb("a") == .lower)
    }

    @Test
    func latinCapitalAIsUpper() {
        // U+0041 LATIN CAPITAL LETTER A — first of Upper range 0041..005A
        #expect(sb("A") == .upper)
    }

    @Test
    func latinLetterTwoWithStrokeIsOLetter() {
        // U+01BB LATIN LETTER TWO WITH STROKE — single-codepoint OLetter entry
        #expect(sb(Unicode.Scalar(0x01BB)!) == .oLetter)
    }

    @Test
    func digitZeroIsNumeric() {
        // U+0030 DIGIT ZERO — first of Numeric range 0030..0039
        #expect(sb("0") == .numeric)
    }

    @Test
    func fullStopIsATerm() {
        // U+002E FULL STOP — single-codepoint ATerm entry
        #expect(sb(".") == .aTerm)
    }

    @Test
    func questionMarkIsSTerm() {
        // U+003F QUESTION MARK — single-codepoint STerm entry
        #expect(sb("?") == .sTerm)
    }

    @Test
    func commaIsSContinue() {
        // U+002C COMMA — single-codepoint SContinue entry
        #expect(sb(",") == .sContinue)
    }

    @Test
    func rightParenIsClose() {
        // U+0029 RIGHT PARENTHESIS — single-codepoint Close entry
        #expect(sb(Unicode.Scalar(0x0029)!) == .close)
    }

    @Test
    func emojiIsOther() {
        // U+1F600 GRINNING FACE — not listed in SentenceBreakProperty.txt
        #expect(sb(Unicode.Scalar(0x1F600)!) == .other)
    }

    @Test
    func enumHasFifteenCases() {
        #expect(UnicodeProperties.SentenceBreak.allCases.count == 15)
    }

    @Test
    func rawValuesAreInRange() {
        for sb in UnicodeProperties.SentenceBreak.allCases {
            #expect(sb.rawValue <= 14)
        }
    }
}
