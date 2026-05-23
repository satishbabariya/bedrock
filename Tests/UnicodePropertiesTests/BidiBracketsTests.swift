import Testing
import UnicodeProperties

@Suite
struct BidiBracketsTests {

    private func bbt(_ scalar: Unicode.Scalar) -> UnicodeProperties.BidiBracketType {
        UnicodeProperties.bidiBracketType(of: scalar)
    }

    private func pb(_ scalar: Unicode.Scalar) -> Unicode.Scalar? {
        UnicodeProperties.pairedBracket(of: scalar)
    }

    // --- bidiBracketType ---

    @Test
    func leftParenIsOpen() {
        #expect(bbt("(") == .open)
    }

    @Test
    func rightParenIsClose() {
        #expect(bbt(")") == .close)
    }

    @Test
    func asciiLetterIsNone() {
        #expect(bbt("A") == .none)
    }

    @Test
    func leftSquareBracketIsOpen() {
        #expect(bbt("[") == .open)
    }

    @Test
    func rightSquareBracketIsClose() {
        #expect(bbt("]") == .close)
    }

    @Test
    func leftCurlyBraceIsOpen() {
        #expect(bbt("{") == .open)
    }

    @Test
    func rightCurlyBraceIsClose() {
        #expect(bbt("}") == .close)
    }

    @Test
    func cjkLeftAngleBracketIsOpen() {
        // U+3008 LEFT ANGLE BRACKET → open
        #expect(bbt(Unicode.Scalar(0x3008)!) == .open)
    }

    @Test
    func cjkRightAngleBracketIsClose() {
        // U+3009 RIGHT ANGLE BRACKET → close
        #expect(bbt(Unicode.Scalar(0x3009)!) == .close)
    }

    // --- pairedBracket ---

    @Test
    func pairedOfLeftParenIsRightParen() {
        #expect(pb("(") == ")")
    }

    @Test
    func pairedOfRightParenIsLeftParen() {
        #expect(pb(")") == "(")
    }

    @Test
    func pairedOfAsciiLetterIsNil() {
        #expect(pb("A") == nil)
    }

    @Test
    func pairedOfSquareBrackets() {
        #expect(pb("[") == "]")
        #expect(pb("]") == "[")
    }

    @Test
    func pairedOfCurlyBraces() {
        #expect(pb("{") == "}")
        #expect(pb("}") == "{")
    }

    @Test
    func pairedOfCJKAngleBrackets() {
        // U+3008 ↔ U+3009
        #expect(pb(Unicode.Scalar(0x3008)!) == Unicode.Scalar(0x3009)!)
        #expect(pb(Unicode.Scalar(0x3009)!) == Unicode.Scalar(0x3008)!)
    }

    // --- enum sanity ---

    @Test
    func enumHasThreeCases() {
        #expect(UnicodeProperties.BidiBracketType.allCases.count == 3)
    }

    @Test
    func rawValuesAreInRange() {
        for t in UnicodeProperties.BidiBracketType.allCases {
            #expect(t.rawValue <= 2)
        }
    }
}
