import Testing
import UnicodeProperties

@Suite
struct ExhaustiveTests {

    @Test
    func everyCodepointLookupCompletesAndReturnsValidValue() {
        for cp: UInt32 in 0 ..< 0x110000 {
            guard let scalar = Unicode.Scalar(cp) else { continue }
            let c = UnicodeProperties.generalCategory(of: scalar)
            #expect(c.rawValue <= 29,
                    "out-of-range raw value at U+\(String(cp, radix: 16))")
            let b = UnicodeProperties.bidiClass(of: scalar)
            #expect(b.rawValue <= 22,
                    "out-of-range bidi-class raw value at U+\(String(cp, radix: 16))")
            _ = UnicodeProperties.canonicalCombiningClass(of: scalar)
            _ = UnicodeProperties.simpleUppercase(of: scalar)
            _ = UnicodeProperties.simpleLowercase(of: scalar)
            _ = UnicodeProperties.simpleTitlecase(of: scalar)
            _ = UnicodeProperties.caseFolded(of: scalar)
            _ = UnicodeProperties.isXIDStart(scalar)
            _ = UnicodeProperties.isXIDContinue(scalar)
            _ = UnicodeProperties.isIDStart(scalar)
            _ = UnicodeProperties.isIDContinue(scalar)
            _ = UnicodeProperties.isMath(scalar)
            _ = UnicodeProperties.isAlphabetic(scalar)
            _ = UnicodeProperties.isCased(scalar)
            _ = UnicodeProperties.isLowercase(scalar)
            _ = UnicodeProperties.isUppercase(scalar)
            _ = UnicodeProperties.fullCaseFolded(of: scalar)
            let eaw = UnicodeProperties.eastAsianWidth(of: scalar)
            #expect(eaw.rawValue <= 5,
                    "out-of-range EAW raw value at U+\(String(cp, radix: 16))")
            let bbt = UnicodeProperties.bidiBracketType(of: scalar)
            #expect(bbt.rawValue <= 2,
                    "out-of-range BidiBracketType raw value at U+\(String(cp, radix: 16))")
            _ = UnicodeProperties.pairedBracket(of: scalar)
            let gcb = UnicodeProperties.graphemeClusterBreak(of: scalar)
            #expect(gcb.rawValue <= 13,
                    "out-of-range GCB raw value at U+\(String(cp, radix: 16))")
            let sb = UnicodeProperties.sentenceBreak(of: scalar)
            #expect(sb.rawValue <= 14,
                    "out-of-range SB raw value at U+\(String(cp, radix: 16))")
        }
    }
}
