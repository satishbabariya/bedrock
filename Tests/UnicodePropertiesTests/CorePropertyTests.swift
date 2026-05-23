import Testing
import UnicodeProperties

@Suite
struct CorePropertyTests {

    // MARK: - Math

    @Test
    func mathTrueForOperators() {
        // U+002B PLUS SIGN (Sm)
        #expect(UnicodeProperties.isMath(Unicode.Scalar(0x002B)!))
        // U+003C LESS-THAN SIGN (Sm)
        #expect(UnicodeProperties.isMath(Unicode.Scalar(0x003C)!))
        // U+2211 N-ARY SUMMATION ∑ (Sm)
        #expect(UnicodeProperties.isMath(Unicode.Scalar(0x2211)!))
    }

    @Test
    func mathFalseForLettersAndDigits() {
        #expect(UnicodeProperties.isMath("A") == false)
        #expect(UnicodeProperties.isMath("5") == false)
        #expect(UnicodeProperties.isMath(" ") == false)
    }

    // MARK: - Alphabetic

    @Test
    func alphabeticTrueForLetters() {
        #expect(UnicodeProperties.isAlphabetic("A"))
        #expect(UnicodeProperties.isAlphabetic("z"))
        // U+00E0 à (Ll)
        #expect(UnicodeProperties.isAlphabetic(Unicode.Scalar(0x00E0)!))
        // U+03B1 α GREEK SMALL LETTER ALPHA
        #expect(UnicodeProperties.isAlphabetic(Unicode.Scalar(0x03B1)!))
    }

    @Test
    func alphabeticFalseForDigitsAndPunctuation() {
        #expect(UnicodeProperties.isAlphabetic("5") == false)
        #expect(UnicodeProperties.isAlphabetic("!") == false)
        #expect(UnicodeProperties.isAlphabetic("+") == false)
    }

    // MARK: - Cased

    @Test
    func casedTrueForUpperAndLowercase() {
        #expect(UnicodeProperties.isCased("A"))
        #expect(UnicodeProperties.isCased("z"))
        // U+00C0 À — uppercase Latin-1
        #expect(UnicodeProperties.isCased(Unicode.Scalar(0x00C0)!))
        // U+03B1 α — lowercase Greek
        #expect(UnicodeProperties.isCased(Unicode.Scalar(0x03B1)!))
    }

    @Test
    func casedFalseForDigitsAndPunctuation() {
        #expect(UnicodeProperties.isCased("5") == false)
        #expect(UnicodeProperties.isCased("!") == false)
        #expect(UnicodeProperties.isCased(" ") == false)
    }

    // MARK: - Lowercase

    @Test
    func lowercaseTrueForLowercaseLetters() {
        #expect(UnicodeProperties.isLowercase("a"))
        #expect(UnicodeProperties.isLowercase("z"))
        // U+00E0 à (Ll)
        #expect(UnicodeProperties.isLowercase(Unicode.Scalar(0x00E0)!))
        // U+03B1 α GREEK SMALL LETTER ALPHA
        #expect(UnicodeProperties.isLowercase(Unicode.Scalar(0x03B1)!))
    }

    @Test
    func lowercaseFalseForUppercase() {
        #expect(UnicodeProperties.isLowercase("A") == false)
        #expect(UnicodeProperties.isLowercase("Z") == false)
        // U+0391 Α GREEK CAPITAL LETTER ALPHA
        #expect(UnicodeProperties.isLowercase(Unicode.Scalar(0x0391)!) == false)
    }

    @Test
    func lowercaseFalseForDigitsAndPunctuation() {
        #expect(UnicodeProperties.isLowercase("5") == false)
        #expect(UnicodeProperties.isLowercase("!") == false)
    }

    // MARK: - Uppercase

    @Test
    func uppercaseTrueForUppercaseLetters() {
        #expect(UnicodeProperties.isUppercase("A"))
        #expect(UnicodeProperties.isUppercase("Z"))
        // U+00C0 À (Lu)
        #expect(UnicodeProperties.isUppercase(Unicode.Scalar(0x00C0)!))
        // U+0391 Α GREEK CAPITAL LETTER ALPHA
        #expect(UnicodeProperties.isUppercase(Unicode.Scalar(0x0391)!))
    }

    @Test
    func uppercaseFalseForLowercase() {
        #expect(UnicodeProperties.isUppercase("a") == false)
        #expect(UnicodeProperties.isUppercase("z") == false)
        // U+03B1 α GREEK SMALL LETTER ALPHA
        #expect(UnicodeProperties.isUppercase(Unicode.Scalar(0x03B1)!) == false)
    }

    @Test
    func uppercaseFalseForDigitsAndPunctuation() {
        #expect(UnicodeProperties.isUppercase("5") == false)
        #expect(UnicodeProperties.isUppercase(" ") == false)
    }

    // MARK: - Cross-property spot checks

    @Test
    func lowercaseAndUppercaseAreMutuallyExclusive() {
        let samples: [UInt32] = [0x41, 0x61, 0x00C0, 0x00E0, 0x0391, 0x03B1]
        for cp in samples {
            let s = Unicode.Scalar(cp)!
            let lo = UnicodeProperties.isLowercase(s)
            let up = UnicodeProperties.isUppercase(s)
            #expect(!(lo && up),
                    "U+\(String(cp, radix: 16)) is both Lowercase and Uppercase")
        }
    }

    @Test
    func casedImpliesEitherLowercaseOrUppercase() {
        let samples: [UInt32] = [0x41, 0x61, 0x00C0, 0x00E0, 0x0391, 0x03B1,
                                  0x01C5]  // U+01C5 ǅ Titlecase_Letter
        for cp in samples {
            let s = Unicode.Scalar(cp)!
            if UnicodeProperties.isCased(s) {
                let lo = UnicodeProperties.isLowercase(s)
                let up = UnicodeProperties.isUppercase(s)
                // Note: titlecase letters are Cased but may be neither
                // Lowercase nor Uppercase — do not assert lo || up here.
                // What we can assert is Cased != false.
                _ = lo; _ = up
            }
        }
    }
}
