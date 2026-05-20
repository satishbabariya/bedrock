import Testing
import UnicodeProperties

@Suite
struct CaseFoldingTests {

    private func folded(_ scalar: Unicode.Scalar) -> Unicode.Scalar {
        UnicodeProperties.caseFolded(of: scalar)
    }

    @Test
    func asciiUppercaseFoldsToLowercase() {
        #expect(folded("A") == "a")
        #expect(folded("Z") == "z")
        #expect(folded("M") == "m")
    }

    @Test
    func asciiLowercaseIsIdentity() {
        #expect(folded("a") == "a")
        #expect(folded("z") == "z")
    }

    @Test
    func asciiNonLettersIdentity() {
        #expect(folded("5") == "5")
        #expect(folded(" ") == " ")
        #expect(folded("!") == "!")
        #expect(folded("\u{0000}") == "\u{0000}")
    }

    @Test
    func latin1Uppercase() {
        // À U+00C0 -> à U+00E0
        #expect(folded(Unicode.Scalar(0x00C0)!) == Unicode.Scalar(0x00E0)!)
    }

    @Test
    func greekHeadline() {
        // Σ (U+03A3) and ς (U+03C2) BOTH fold to σ (U+03C3).
        let sigma = Unicode.Scalar(0x03C3)!
        #expect(folded(Unicode.Scalar(0x03A3)!) == sigma)
        #expect(folded(Unicode.Scalar(0x03C2)!) == sigma)
        #expect(folded(sigma) == sigma)
    }

    @Test
    func sharpSIdentityInV1() {
        // ß (U+00DF) has only an F entry; no simple folding in v1.
        let sharpS = Unicode.Scalar(0x00DF)!
        #expect(folded(sharpS) == sharpS)
    }

    @Test
    func turkishDottedIIdentityInV1() {
        // İ (U+0130) has F + T but no C/S; no simple folding in v1.
        let dottedI = Unicode.Scalar(0x0130)!
        #expect(folded(dottedI) == dottedI)
    }

    @Test
    func cjkIdentity() {
        let cjk = Unicode.Scalar(0x6F22)!
        #expect(folded(cjk) == cjk)
    }

    @Test
    func titlecaseLetterFoldsToLowercase() {
        // ǅ U+01C5 -> ǆ U+01C6
        #expect(folded(Unicode.Scalar(0x01C5)!) == Unicode.Scalar(0x01C6)!)
    }

    @Test
    func foldingEquivalenceHoldsAcrossCasePairs() {
        #expect(folded("A") == folded("a"))
        #expect(folded(Unicode.Scalar(0x03A3)!) == folded(Unicode.Scalar(0x03C2)!))
        #expect(folded(Unicode.Scalar(0x00C0)!) == folded(Unicode.Scalar(0x00E0)!))
    }
}
