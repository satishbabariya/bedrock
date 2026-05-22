import Testing
import UnicodeProperties

@Suite
struct FullCaseFoldingTests {

    private func folded(_ scalar: Unicode.Scalar) -> [Unicode.Scalar] {
        UnicodeProperties.fullCaseFolded(of: scalar)
    }

    @Test
    func asciiUppercaseFoldsToLowercase() {
        #expect(folded("A") == ["a"])
        #expect(folded("Z") == ["z"])
    }

    @Test
    func asciiLowercaseIsIdentity() {
        #expect(folded("a") == ["a"])
        #expect(folded("z") == ["z"])
    }

    @Test
    func asciiNonLettersIdentity() {
        #expect(folded("5") == ["5"])
        #expect(folded(" ") == [" "])
        #expect(folded("!") == ["!"])
    }

    @Test
    func latin1Uppercase() {
        #expect(folded(Unicode.Scalar(0x00C0)!) == [Unicode.Scalar(0x00E0)!])
    }

    @Test
    func sharpSExpandsToTwoEsses() {
        let result = folded(Unicode.Scalar(0x00DF)!)
        #expect(result == [Unicode.Scalar(0x0073)!, Unicode.Scalar(0x0073)!])
    }

    @Test
    func turkishDottedI() {
        let result = folded(Unicode.Scalar(0x0130)!)
        #expect(result == [Unicode.Scalar(0x0069)!, Unicode.Scalar(0x0307)!])
    }

    @Test
    func ffiLigatureExpandsToThree() {
        let result = folded(Unicode.Scalar(0xFB03)!)
        #expect(result == [Unicode.Scalar(0x0066)!,
                            Unicode.Scalar(0x0066)!,
                            Unicode.Scalar(0x0069)!])
    }

    @Test
    func greekIotaWithDialytikaAndTonos() {
        let result = folded(Unicode.Scalar(0x0390)!)
        #expect(result == [Unicode.Scalar(0x03B9)!,
                            Unicode.Scalar(0x0308)!,
                            Unicode.Scalar(0x0301)!])
    }

    @Test
    func greekSigmaCluster() {
        let sigma = Unicode.Scalar(0x03C3)!
        #expect(folded(Unicode.Scalar(0x03A3)!) == [sigma])
        #expect(folded(Unicode.Scalar(0x03C2)!) == [sigma])
        #expect(folded(sigma) == [sigma])
    }

    @Test
    func cjkIdentity() {
        let cjk = Unicode.Scalar(0x6F22)!
        #expect(folded(cjk) == [cjk])
    }

    @Test
    func titlecaseLetterFoldsLikeSimple() {
        #expect(folded(Unicode.Scalar(0x01C5)!) == [Unicode.Scalar(0x01C6)!])
    }

    @Test
    func resultIsAlwaysNonEmpty() {
        for cp: UInt32 in [0x0000, 0x0041, 0x00DF, 0xFB03, 0x6F22, 0x10000] {
            let scalar = Unicode.Scalar(cp)!
            let result = folded(scalar)
            #expect(result.isEmpty == false,
                    "fullCaseFolded should never return empty (cp U+\(String(cp, radix: 16)))")
        }
    }
}
