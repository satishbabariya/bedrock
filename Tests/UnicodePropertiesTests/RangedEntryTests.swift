import Testing
import UnicodeProperties

@Suite
struct RangedEntryTests {

    private func cat(_ cp: UInt32) -> UnicodeProperties.GeneralCategory {
        UnicodeProperties.generalCategory(of: Unicode.Scalar(cp)!)
    }

    @Test
    func cjkIdeographRange() {
        #expect(cat(0x4E00) == .otherLetter)
        #expect(cat(0x5000) == .otherLetter)
        #expect(cat(0x9FFF) == .otherLetter)
    }

    @Test
    func hangulSyllableRange() {
        #expect(cat(0xAC00) == .otherLetter)
        #expect(cat(0xD55C) == .otherLetter)
        #expect(cat(0xD7A3) == .otherLetter)
    }

    @Test
    func tangutIdeographRange() {
        #expect(cat(0x17000) == .otherLetter)
        #expect(cat(0x187F7) == .otherLetter)
    }

    @Test
    func plane15PrivateUseRange() {
        #expect(cat(0xF0000) == .privateUse)
        #expect(cat(0xFFFFD) == .privateUse)
    }

    @Test
    func plane16PrivateUseRange() {
        #expect(cat(0x100000) == .privateUse)
        #expect(cat(0x10FFFD) == .privateUse)
    }
}
