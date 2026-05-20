import Testing
import UnicodeProperties

@Suite
struct CanonicalCombiningClassTests {

    private func ccc(_ scalar: Unicode.Scalar) -> UInt8 {
        UnicodeProperties.canonicalCombiningClass(of: scalar)
    }

    @Test
    func asciiHasZeroCCC() {
        #expect(ccc("A") == 0)
        #expect(ccc("5") == 0)
        #expect(ccc(" ") == 0)
    }

    @Test
    func combiningGraveIsAbove() {
        #expect(ccc("\u{0300}") == 230)
    }

    @Test
    func combiningAcuteIsAbove() {
        #expect(ccc("\u{0301}") == 230)
    }

    @Test
    func combiningTildeIsAbove() {
        #expect(ccc("\u{0303}") == 230)
    }

    @Test
    func combiningCedillaIsAttachedBelow() {
        #expect(ccc("\u{0327}") == 202)
    }

    @Test
    func hiraganaVoicingMark() {
        #expect(ccc(Unicode.Scalar(0x3099)!) == 8)
    }

    @Test
    func hebrewShevaIsTen() {
        #expect(ccc(Unicode.Scalar(0x05B0)!) == 10)
    }

    @Test
    func arabicShaddaIs33() {
        #expect(ccc(Unicode.Scalar(0x0651)!) == 33)
    }
}
