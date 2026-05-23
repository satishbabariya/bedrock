import Testing
import UnicodeProperties

@Suite
struct EastAsianWidthTests {

    private func eaw(_ scalar: Unicode.Scalar) -> UnicodeProperties.EastAsianWidth {
        UnicodeProperties.eastAsianWidth(of: scalar)
    }

    @Test
    func asciiLetterIsNarrow() {
        // U+0041 A → Na (Narrow)
        #expect(eaw("A") == .narrow)
    }

    @Test
    func asciiDigitIsNarrow() {
        // U+0035 5 → Na (Narrow)
        #expect(eaw("5") == .narrow)
    }

    @Test
    func asciiSpaceIsNarrow() {
        // U+0020 SPACE → Na (Narrow)
        #expect(eaw(" ") == .narrow)
    }

    @Test
    func controlCharacterIsNeutral() {
        // U+0000 NULL → N (Neutral)
        #expect(eaw(Unicode.Scalar(0x0000)!) == .neutral)
    }

    @Test
    func fullwidthDigitIsFullwidth() {
        // U+FF10 FULLWIDTH DIGIT ZERO → F (Fullwidth)
        #expect(eaw(Unicode.Scalar(0xFF10)!) == .fullwidth)
    }

    @Test
    func halfwidthKatakanaIsHalfwidth() {
        // U+FF71 HALFWIDTH KATAKANA LETTER A → H (Halfwidth)
        #expect(eaw(Unicode.Scalar(0xFF71)!) == .halfwidth)
    }

    @Test
    func wideCJKIsWide() {
        // U+6F22 漢 → W (Wide)
        #expect(eaw(Unicode.Scalar(0x6F22)!) == .wide)
    }

    @Test
    func ideographicSpaceIsFullwidth() {
        // U+3000 IDEOGRAPHIC SPACE → F (Fullwidth)
        #expect(eaw(Unicode.Scalar(0x3000)!) == .fullwidth)
    }

    @Test
    func greekCapitalAlphaIsAmbiguous() {
        // U+0391 Α GREEK CAPITAL LETTER ALPHA → A (Ambiguous)
        #expect(eaw(Unicode.Scalar(0x0391)!) == .ambiguous)
    }

    @Test
    func privateUseAreaIsAmbiguous() {
        // U+E000 is in the PUA A (Ambiguous) range per UCD.
        #expect(eaw(Unicode.Scalar(0xE000)!) == .ambiguous)
    }

    @Test
    func enumHasSixCases() {
        #expect(UnicodeProperties.EastAsianWidth.allCases.count == 6)
    }

    @Test
    func rawValuesAreInRange() {
        for width in UnicodeProperties.EastAsianWidth.allCases {
            #expect(width.rawValue <= 5)
        }
    }
}
