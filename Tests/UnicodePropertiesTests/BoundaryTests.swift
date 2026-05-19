import Testing
import UnicodeProperties

@Suite
struct BoundaryTests {

    private func cat(_ cp: UInt32) -> UnicodeProperties.GeneralCategory {
        UnicodeProperties.generalCategory(of: Unicode.Scalar(cp)!)
    }

    @Test
    func lastAsciiIsControl() {
        #expect(cat(0x007F) == .control)
    }

    @Test
    func firstLatin1SupplementIsControl() {
        #expect(cat(0x0080) == .control)
    }

    @Test
    func bmpPuaStartAndEnd() {
        #expect(cat(0xE000) == .privateUse)
        #expect(cat(0xF8FF) == .privateUse)
    }

    @Test
    func lastValidScalarIsPrivateUse() {
        #expect(cat(0x10FFFD) == .privateUse)
    }

    @Test
    func justBeforeCjkRangeIsNotLetter() {
        let c = cat(0x4DFF)
        #expect(c != .otherLetter)
    }

    @Test
    func cjkRangeFirstAndLast() {
        #expect(cat(0x4E00) == .otherLetter)
        #expect(cat(0x9FFF) == .otherLetter)
    }
}
