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
