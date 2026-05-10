import Testing
import Bytes
@testable import Base64

private let rfcVectors: [(String, String)] = [
    ("",       ""),
    ("f",      "Zg=="),
    ("fo",     "Zm8="),
    ("foo",    "Zm9v"),
    ("foob",   "Zm9vYg=="),
    ("fooba",  "Zm9vYmE="),
    ("foobar", "Zm9vYmFy"),
]

@Test func decodeStrictRFCVectors() throws {
    for (expected, encoded) in rfcVectors {
        let decoded = try Base64.decode(encoded)
        #expect(Array(decoded) == Array(expected.utf8))
    }
}

@Test func decodeUrlSafeAlphabet() throws {
    // "-_-_" url-safe = 0xFB 0xFF 0xBF (the inverse of the encode test)
    let decoded = try Base64.decode("-_-_")
    #expect(Array(decoded) == [0xFB, 0xFF, 0xBF])
}

@Test func decodePaddedAndUnpaddedEquivalent() throws {
    let padded = try Base64.decode("Zg==")
    let unpadded = try Base64.decode("Zg")
    #expect(padded == unpadded)
    #expect(Array(padded) == [0x66])
}

@Test func decodeMixingStandardAndUrlSafeThrows() {
    // First char is 'A' (alphanum) → no variant lock-in yet.
    // Then '+' locks standard. Then '-' violates → throws at offset of '-'.
    #expect(throws: Base64Error.self) {
        _ = try Base64.decode("A+B-")
    }
}

@Test func decodeStrictRejectsWhitespace() {
    #expect(throws: Base64Error.invalidCharacter(offset: 2, byte: 0x20)) {
        _ = try Base64.decode("Zg ==")  // space at offset 2
    }
}

@Test func decodeInvalidCharacterThrows() {
    #expect(throws: Base64Error.invalidCharacter(offset: 1, byte: 0x21)) {
        _ = try Base64.decode("Z!g=")  // '!' = 0x21 at offset 1
    }
}

@Test func decodeInvalidLengthThrows() {
    // 1 char, no padding — single sextet has no whole byte to emit.
    #expect(throws: Base64Error.invalidLength(1)) {
        _ = try Base64.decode("Z")
    }
}

@Test func decodeInvalidPaddingMidStream() {
    #expect(throws: Base64Error.self) {
        _ = try Base64.decode("Z=g=")  // '=' at offset 1 (mid-stream)
    }
}

@Test func decodeFromBytesOverload() throws {
    let input = Bytes(Array("Zm9v".utf8))
    #expect(Array(try Base64.decode(input)) == Array("foo".utf8))
}

@Test func decodeIntoBytesMutReturnsByteCount() throws {
    var out = BytesMut()
    out.putUInt8(0xAA)
    let n = try Base64.decode("Zm9v", into: &out)
    #expect(n == 3)
    let frozen = out.freeze()
    #expect(Array(frozen) == [0xAA, 0x66, 0x6F, 0x6F])
}

@Test func decodeLenientSkipsWhitespace() throws {
    let result = try Base64.decode("Zm9v\nYmFy", mode: .lenient)
    #expect(Array(result) == Array("foobar".utf8))
}

@Test func decodeLenientAcceptsSpacesAndTabs() throws {
    let result = try Base64.decode("Zm 9v\tYmFy", mode: .lenient)
    #expect(Array(result) == Array("foobar".utf8))
}

@Test func decodeLenientRejectsNonWhitespaceInvalid() {
    #expect(throws: Base64Error.invalidCharacter(offset: 1, byte: 0x21)) {
        _ = try Base64.decode("Z!9v", mode: .lenient)
    }
}

@Test func base64DecodeTableMatchesGroundTruth() {
    func expected(for byte: UInt8) -> UInt8 {
        switch byte {
        case 0x41...0x5A: return byte - 0x41           // A-Z -> 0...25
        case 0x61...0x7A: return byte - 0x61 + 26      // a-z -> 26...51
        case 0x30...0x39: return byte - 0x30 + 52      // 0-9 -> 52...61
        case 0x2B:        return 62                    // '+'
        case 0x2F:        return 63                    // '/'
        case 0x2D:        return 62                    // '-' (url-safe)
        case 0x5F:        return 63                    // '_' (url-safe)
        case 0x3D:        return 0xFD                  // '=' padding sentinel
        case 0x09, 0x0A, 0x0D, 0x20: return 0xFE       // whitespace sentinel
        default:          return 0xFF                  // invalid
        }
    }
    for i in 0..<256 {
        let b = UInt8(i)
        #expect(base64DecodeTable[i] == expected(for: b),
                "table mismatch at byte 0x\(String(b, radix: 16))")
    }
}

@Test func decodeAlphanumericOnlyDoesNotLockVariant() throws {
    // "Zm9v" is alphanumeric -- no +/-_ to trigger variant lock-in.
    // Should succeed under both default (.strict) and .lenient.
    let viaStrict = try Base64.decode("Zm9v", mode: .strict)
    let viaLenient = try Base64.decode("Zm9v", mode: .lenient)
    #expect(Array(viaStrict) == Array("foo".utf8))
    #expect(Array(viaLenient) == Array("foo".utf8))
}
