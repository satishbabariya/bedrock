import Testing
import Bytes
@testable import Base64

// RFC 4648 §10 test vectors.
private let rfcVectors: [(String, String)] = [
    ("",       ""),
    ("f",      "Zg=="),
    ("fo",     "Zm8="),
    ("foo",    "Zm9v"),
    ("foob",   "Zm9vYg=="),
    ("fooba",  "Zm9vYmE="),
    ("foobar", "Zm9vYmFy"),
]

@Test func encodeStandardRFCVectors() {
    for (input, expected) in rfcVectors {
        let bytes = Bytes(Array(input.utf8))
        #expect(Base64.encode(bytes) == expected)
    }
}

@Test func encodeStandardEmptyProducesEmpty() {
    #expect(Base64.encode(Bytes()) == "")
}

@Test func encodeAllByteValues() {
    var arr: [UInt8] = []
    for i in 0..<256 { arr.append(UInt8(i)) }
    let s = Base64.encode(Bytes(arr))
    // 256 bytes → ceil(256/3)*4 = 86 quanta → 344 chars (with padding)
    #expect(s.count == 344)
    // No invalid characters
    let alphabet = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")
    #expect(s.allSatisfy { alphabet.contains($0) })
}

@Test func encodeSequenceOverloadMatchesBytesOverload() {
    let arr: [UInt8] = [0x00, 0xFF, 0x80]
    #expect(Base64.encode(arr) == Base64.encode(Bytes(arr)))
}

@Test func encodeIntoBytesMutAppends() {
    var buf = BytesMut()
    buf.putUInt8(0xAA)
    Base64.encode(Bytes(Array("foo".utf8)), into: &buf)
    let frozen = buf.freeze()
    // 0xAA + "Zm9v" (4 ASCII bytes)
    #expect(Array(frozen) == [0xAA, 0x5A, 0x6D, 0x39, 0x76])
}

@Test func encodeIntoBytesMutEmptyInputAppendsNothing() {
    var buf = BytesMut()
    buf.putUInt8(0xAA)
    Base64.encode(Bytes(), into: &buf)
    let frozen = buf.freeze()
    #expect(Array(frozen) == [0xAA])
}

@Test func encodeUrlSafeReplacesPlusAndSlash() {
    // Bytes that produce '+' (62) and '/' (63) in the standard encoding.
    // Three-byte input 0xFB 0xFF 0xBF =>
    //   bits 11111011 11111111 10111111
    //   sextets: 111110 111111 111110 111111 = 62 63 62 63
    //   standard: "+/+/"
    //   url-safe: "-_-_"
    let bytes = Bytes([0xFB, 0xFF, 0xBF])
    #expect(Base64.encode(bytes, variant: .standard) == "+/+/")
    #expect(Base64.encode(bytes, variant: .urlSafe) == "-_-_")
}

@Test func encodeUnpaddedStripsEquals() {
    let bytes = Bytes(Array("f".utf8))
    #expect(Base64.encode(bytes, padding: true)  == "Zg==")
    #expect(Base64.encode(bytes, padding: false) == "Zg")

    let bytes2 = Bytes(Array("fo".utf8))
    #expect(Base64.encode(bytes2, padding: true)  == "Zm8=")
    #expect(Base64.encode(bytes2, padding: false) == "Zm8")

    let bytes3 = Bytes(Array("foo".utf8))
    // Whole quanta — no padding either way.
    #expect(Base64.encode(bytes3, padding: true)  == "Zm9v")
    #expect(Base64.encode(bytes3, padding: false) == "Zm9v")
}

@Test func encodeMime76InsertsCRLFAtColumn76() {
    // 60 bytes input → 80 base64 chars (no padding because divisible by 3).
    // mime76 should insert CRLF after column 76, leaving 4 chars on the
    // next line.
    let bytes = Bytes([UInt8](repeating: 0x00, count: 60))
    let s = Base64.encode(bytes, lineWrap: .mime76)
    // 60 input bytes / 3 = 20 quanta → 80 ASCII chars + 1 CRLF (2 bytes) = 82 UTF-8 bytes total.
    // Note: Swift String.count treats \r\n as one grapheme cluster, so use .utf8.count.
    #expect(s.utf8.count == 82)
    // CRLF should appear at byte offsets 76 and 77.
    let utf8 = Array(s.utf8)
    #expect(utf8[76] == 0x0D)  // CR
    #expect(utf8[77] == 0x0A)  // LF
}

@Test func encodeMime76DoesNotSplitQuantum() {
    // Encode a buffer that produces exactly 76 base64 chars — the CRLF is
    // inserted after the 76th char, so the output is 76 data bytes + 2 CRLF
    // bytes = 78 UTF-8 bytes. Use .utf8 throughout to avoid Swift's
    // grapheme-cluster folding of \r\n into one Character.
    let bytes = Bytes([UInt8](repeating: 0x41, count: 57))  // 57/3 = 19 quanta = 76 chars
    let s = Base64.encode(bytes, lineWrap: .mime76)
    let utf8 = Array(s.utf8)
    #expect(utf8.count == 78)
    #expect(utf8[76] == 0x0D)  // CR
    #expect(utf8[77] == 0x0A)  // LF
}
