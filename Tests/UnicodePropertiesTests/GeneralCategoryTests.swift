import Testing
import UnicodeProperties

@Suite
struct GeneralCategoryTests {

    private func cat(_ scalar: Unicode.Scalar) -> UnicodeProperties.GeneralCategory {
        UnicodeProperties.generalCategory(of: scalar)
    }

    @Test
    func asciiUppercaseLetter() {
        #expect(cat("A") == .uppercaseLetter)
        #expect(cat("Z") == .uppercaseLetter)
    }

    @Test
    func asciiLowercaseLetter() {
        #expect(cat("a") == .lowercaseLetter)
        #expect(cat("z") == .lowercaseLetter)
    }

    @Test
    func asciiDigit() {
        #expect(cat("0") == .decimalNumber)
        #expect(cat("9") == .decimalNumber)
    }

    @Test
    func asciiPunctuation() {
        #expect(cat("!") == .otherPunctuation)
        #expect(cat(",") == .otherPunctuation)
    }

    @Test
    func asciiSpace() {
        #expect(cat(" ") == .spaceSeparator)
    }

    @Test
    func asciiControl() {
        #expect(cat("\u{0000}") == .control)
        #expect(cat("\u{0009}") == .control)
        #expect(cat("\u{007F}") == .control)
    }

    @Test
    func latin1Uppercase() {
        #expect(cat("\u{00C0}") == .uppercaseLetter)
    }

    @Test
    func titlecaseLetter() {
        #expect(cat("\u{01C5}") == .titlecaseLetter)
    }

    @Test
    func combiningMark() {
        #expect(cat("\u{0301}") == .nonspacingMark)
    }

    @Test
    func cjkIdeograph() {
        #expect(cat("\u{6F22}") == .otherLetter)
    }

    @Test
    func hangulSyllable() {
        #expect(cat("\u{D55C}") == .otherLetter)
    }

    @Test
    func mathematicalSymbol() {
        #expect(cat("\u{2211}") == .mathSymbol)
        #expect(cat("+") == .mathSymbol)
    }

    @Test
    func currencySymbol() {
        #expect(cat("$") == .currencySymbol)
        #expect(cat("\u{20AC}") == .currencySymbol)
    }

    @Test
    func emoji() {
        #expect(cat("\u{1F600}") == .otherSymbol)
    }

    @Test
    func privateUse() {
        #expect(cat(Unicode.Scalar(0xE000)!) == .privateUse)
    }

    @Test
    func formatChar() {
        #expect(cat(Unicode.Scalar(0x200B)!) == .format)
    }

    @Test
    func unicodeVersionConstant() {
        #expect(UnicodeProperties.unicodeVersion == "16.0.0")
    }
}
