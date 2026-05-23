import Testing
import UnicodeProperties

@Suite
struct GraphemeClusterBreakTests {

    private func gcb(_ scalar: Unicode.Scalar) -> UnicodeProperties.GraphemeClusterBreak {
        UnicodeProperties.graphemeClusterBreak(of: scalar)
    }

    @Test
    func crIsCR() {
        // U+000D CARRIAGE RETURN
        #expect(gcb(Unicode.Scalar(0x000D)!) == .cr)
    }

    @Test
    func lfIsLF() {
        // U+000A LINE FEED
        #expect(gcb(Unicode.Scalar(0x000A)!) == .lf)
    }

    @Test
    func nullIsControl() {
        // U+0000 NULL — in Control range 0000..0009
        #expect(gcb(Unicode.Scalar(0x0000)!) == .control)
    }

    @Test
    func tabIsControl() {
        // U+0009 CHARACTER TABULATION — in Control range 0000..0009
        #expect(gcb(Unicode.Scalar(0x0009)!) == .control)
    }

    @Test
    func combiningAcuteIsExtend() {
        // U+0301 COMBINING ACUTE ACCENT
        #expect(gcb(Unicode.Scalar(0x0301)!) == .extend)
    }

    @Test
    func zwjIsZWJ() {
        // U+200D ZERO WIDTH JOINER
        #expect(gcb(Unicode.Scalar(0x200D)!) == .zwj)
    }

    @Test
    func regionalIndicatorAIsRegionalIndicator() {
        // U+1F1E6 REGIONAL INDICATOR SYMBOL LETTER A
        #expect(gcb(Unicode.Scalar(0x1F1E6)!) == .regionalIndicator)
    }

    @Test
    func arabicNumberSignIsPrepend() {
        // U+0600 ARABIC NUMBER SIGN — first entry in the file
        #expect(gcb(Unicode.Scalar(0x0600)!) == .prepend)
    }

    @Test
    func devanagariVowelSignAAIsSpacingMark() {
        // U+093E DEVANAGARI VOWEL SIGN AA — in SpacingMark range 093E..0940
        #expect(gcb(Unicode.Scalar(0x093E)!) == .spacingMark)
    }

    @Test
    func hangulLeadKiyeokIsL() {
        // U+1100 HANGUL CHOSEONG KIYEOK — in L range 1100..115F
        #expect(gcb(Unicode.Scalar(0x1100)!) == .l)
    }

    @Test
    func hangulVowelFillerIsV() {
        // U+1160 HANGUL JUNGSEONG FILLER — in V range 1160..11A7
        #expect(gcb(Unicode.Scalar(0x1160)!) == .v)
    }

    @Test
    func hangulTrailingKiyeokIsT() {
        // U+11A8 HANGUL JONGSEONG KIYEOK — in T range 11A8..11FF
        #expect(gcb(Unicode.Scalar(0x11A8)!) == .t)
    }

    @Test
    func hangulSyllableGAIsLV() {
        // U+AC00 HANGUL SYLLABLE GA (precomposed, no trailing jamo)
        #expect(gcb(Unicode.Scalar(0xAC00)!) == .lv)
    }

    @Test
    func hangulSyllableGAGIsLVT() {
        // U+AC01 HANGUL SYLLABLE GAG (precomposed, with trailing jamo)
        #expect(gcb(Unicode.Scalar(0xAC01)!) == .lvt)
    }

    @Test
    func asciiLetterIsOther() {
        // U+0041 A — not listed in GraphemeBreakProperty.txt
        #expect(gcb("A") == .other)
    }

    @Test
    func enumHasFourteenCases() {
        #expect(UnicodeProperties.GraphemeClusterBreak.allCases.count == 14)
    }

    @Test
    func rawValuesAreInRange() {
        for gcb in UnicodeProperties.GraphemeClusterBreak.allCases {
            #expect(gcb.rawValue <= 13)
        }
    }
}
