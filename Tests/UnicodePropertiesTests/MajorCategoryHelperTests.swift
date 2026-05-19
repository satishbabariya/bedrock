import Testing
import UnicodeProperties

@Suite
struct MajorCategoryHelperTests {

    @Test
    func isLetter() {
        #expect(UnicodeProperties.isLetter("A"))
        #expect(UnicodeProperties.isLetter("z"))
        #expect(UnicodeProperties.isLetter("\u{6F22}"))
        #expect(UnicodeProperties.isLetter("5") == false)
        #expect(UnicodeProperties.isLetter("!") == false)
    }

    @Test
    func isNumber() {
        #expect(UnicodeProperties.isNumber("5"))
        #expect(UnicodeProperties.isNumber("\u{2163}"))
        #expect(UnicodeProperties.isNumber("A") == false)
    }

    @Test
    func isMark() {
        #expect(UnicodeProperties.isMark("\u{0301}"))
        #expect(UnicodeProperties.isMark("A") == false)
    }

    @Test
    func isPunctuation() {
        #expect(UnicodeProperties.isPunctuation("!"))
        #expect(UnicodeProperties.isPunctuation(","))
        #expect(UnicodeProperties.isPunctuation("("))
        #expect(UnicodeProperties.isPunctuation("A") == false)
    }

    @Test
    func isSymbol() {
        #expect(UnicodeProperties.isSymbol("\u{2211}"))
        #expect(UnicodeProperties.isSymbol("$"))
        #expect(UnicodeProperties.isSymbol("A") == false)
    }

    @Test
    func isSeparator() {
        #expect(UnicodeProperties.isSeparator(" "))
        #expect(UnicodeProperties.isSeparator("\n") == false)
    }

    @Test
    func isControl() {
        #expect(UnicodeProperties.isControl("\t"))
        #expect(UnicodeProperties.isControl("\n"))
        #expect(UnicodeProperties.isControl("A") == false)
    }
}
