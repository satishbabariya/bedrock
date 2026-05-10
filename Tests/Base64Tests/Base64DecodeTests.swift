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
