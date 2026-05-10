import Testing
import Bytes
@testable import Hex

@Test func decodeEmpty() throws {
    #expect(try Array(Hex.decode("")) == [])
}

@Test func decodeKnownVectors() throws {
    #expect(try Array(Hex.decode("deadbeef")) == [0xDE, 0xAD, 0xBE, 0xEF])
    #expect(try Array(Hex.decode("000FF0ff")) == [0x00, 0x0F, 0xF0, 0xFF])
}

@Test func decodeCaseInsensitive() throws {
    let a = try Hex.decode("DEADBEEF")
    let b = try Hex.decode("deadbeef")
    let c = try Hex.decode("DeAdBeEf")
    #expect(a == b)
    #expect(b == c)
}

@Test func decodeOddLengthThrows() {
    #expect(throws: HexError.oddLength(3)) { _ = try Hex.decode("abc") }
    #expect(throws: HexError.oddLength(1)) { _ = try Hex.decode("a") }
}

@Test func decodeInvalidCharacterThrows() {
    #expect(throws: HexError.invalidCharacter(offset: 2, byte: 0x40)) {
        _ = try Hex.decode("de@dbeef")  // '@' = 0x40 at offset 2
    }
    #expect(throws: HexError.invalidCharacter(offset: 0, byte: 0x67)) {
        _ = try Hex.decode("g0")        // 'g' = 0x67 at offset 0
    }
}

@Test func decodeFromBytesOverload() throws {
    let input = Bytes([0x64, 0x65, 0x61, 0x64])  // "dead" in ASCII
    #expect(try Array(Hex.decode(input)) == [0xDE, 0xAD])
}

@Test func decodeIntoBytesMutReturnsByteCount() throws {
    var out = BytesMut()
    out.putUInt8(0xAA)  // pre-existing content
    let n = try Hex.decode("deadbeef", into: &out)
    #expect(n == 4)
    let frozen = out.freeze()
    #expect(Array(frozen) == [0xAA, 0xDE, 0xAD, 0xBE, 0xEF])
}

@Test func decodeTableMatchesGroundTruth() {
    func expectedNibble(for byte: UInt8) -> UInt8 {
        switch byte {
        case 0x30...0x39: return byte - 0x30
        case 0x41...0x46: return byte - 0x41 + 10
        case 0x61...0x66: return byte - 0x61 + 10
        default:          return 0xFF
        }
    }
    for i in 0..<256 {
        let b = UInt8(i)
        #expect(hexDecodeTable[i] == expectedNibble(for: b),
                "table mismatch at byte 0x\(String(b, radix: 16))")
    }
}
