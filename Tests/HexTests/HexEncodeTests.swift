import Testing
import Bytes
@testable import Hex

@Test func encodeEmpty() {
    #expect(Hex.encode(Bytes()) == "")
    #expect(Hex.encode(Bytes(), case: .upper) == "")
}

@Test func encodeKnownVectorsLower() {
    #expect(Hex.encode(Bytes([0xDE, 0xAD, 0xBE, 0xEF])) == "deadbeef")
    #expect(Hex.encode(Bytes([0x00, 0x0F, 0xF0, 0xFF])) == "000ff0ff")
}

@Test func encodeKnownVectorsUpper() {
    #expect(Hex.encode(Bytes([0xDE, 0xAD, 0xBE, 0xEF]), case: .upper) == "DEADBEEF")
    #expect(Hex.encode(Bytes([0x00, 0x0F, 0xF0, 0xFF]), case: .upper) == "000FF0FF")
}

@Test func encodeAllByteValues() {
    var bytes: [UInt8] = []
    for i in 0..<256 { bytes.append(UInt8(i)) }
    let lower = Hex.encode(Bytes(bytes))
    let upper = Hex.encode(Bytes(bytes), case: .upper)
    #expect(lower.count == 512)
    #expect(upper.count == 512)
    #expect(lower.lowercased() == lower)
    #expect(upper.uppercased() == upper)
    // Spot check first and last bytes
    #expect(lower.hasPrefix("00"))
    #expect(lower.hasSuffix("ff"))
}

@Test func encodeSequenceOverloadMatchesBytesOverload() {
    let arr: [UInt8] = [0x12, 0x34, 0x56]
    #expect(Hex.encode(arr) == Hex.encode(Bytes(arr)))
    #expect(Hex.encode(arr, case: .upper) == Hex.encode(Bytes(arr), case: .upper))
}

@Test func encodeIntoBytesMutAppends() {
    var buf = BytesMut()
    buf.putBytes([0xAA, 0xBB] as [UInt8])  // pre-existing content
    Hex.encode(Bytes([0xDE, 0xAD]), into: &buf)
    let frozen = buf.freeze()
    // [0xAA, 0xBB] (raw) + "dead" (4 ASCII bytes)
    #expect(Array(frozen) == [0xAA, 0xBB, 0x64, 0x65, 0x61, 0x64])
}

@Test func encodeIntoBytesMutEmptyInputAppendsNothing() {
    var buf = BytesMut()
    buf.putUInt8(0xAA)
    Hex.encode(Bytes(), into: &buf)
    let frozen = buf.freeze()
    #expect(Array(frozen) == [0xAA])
}
