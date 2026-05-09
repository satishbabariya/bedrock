import Testing
@testable import Bytes

@Test func readerInitialState() {
    let r = BytesReader(Bytes([0x01, 0x02, 0x03]))
    #expect(r.remaining == 3)
    #expect(r.consumed == 0)
    #expect(r.isExhausted == false)
}

@Test func readerEmptyIsExhausted() {
    let r = BytesReader(Bytes())
    #expect(r.remaining == 0)
    #expect(r.consumed == 0)
    #expect(r.isExhausted == true)
}

@Test func readerRemainingBytes() {
    let r = BytesReader(Bytes([0x01, 0x02, 0x03]))
    let tail = r.remainingBytes()
    #expect(Array(tail) == [0x01, 0x02, 0x03])
}

@Test func readerReadUInt8Advances() {
    var r = BytesReader(Bytes([0xAA, 0xBB, 0xCC]))
    #expect(r.readUInt8() == 0xAA)
    #expect(r.consumed == 1)
    #expect(r.remaining == 2)
    #expect(r.readUInt8() == 0xBB)
    #expect(r.readUInt8() == 0xCC)
    #expect(r.readUInt8() == nil)            // exhausted
    #expect(r.consumed == 3)                 // did NOT advance on failure
}

@Test func readerReadUInt32() {
    var r = BytesReader(Bytes([0xDE, 0xAD, 0xBE, 0xEF, 0x42]))
    #expect(r.readUInt32(endianness: .big) == 0xDEADBEEF)
    #expect(r.remaining == 1)
    #expect(r.readUInt32(endianness: .big) == nil)  // not enough left
    #expect(r.remaining == 1)                       // unchanged on failure
}

@Test func readerReadUInt16AndUInt64() {
    var r = BytesReader(Bytes([0xDE, 0xAD,
                               0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]))
    #expect(r.readUInt16(endianness: .big) == 0xDEAD)
    #expect(r.readUInt64(endianness: .big) == 0x0102030405060708)
}

@Test func readerReadSigned() {
    var r = BytesReader(Bytes([0xFF, 0xFF, 0xFE]))
    #expect(r.readInt8() == -1)
    #expect(r.readInt16(endianness: .big) == -2)
}

@Test func readerReadBytesZeroCopy() {
    let original = Bytes([0x01, 0x02, 0x03, 0x04, 0x05])
    var r = BytesReader(original)
    let head = r.readBytes(length: 3)
    #expect(head != nil)
    #expect(Array(head!) == [0x01, 0x02, 0x03])
    let originalAddr = original.withUnsafeBytes { $0.baseAddress! }
    let headAddr = head!.withUnsafeBytes { $0.baseAddress! }
    #expect(headAddr == originalAddr)
}

@Test func readerReadBytesShortReadReturnsNil() {
    var r = BytesReader(Bytes([0x01, 0x02]))
    #expect(r.readBytes(length: 5) == nil)
    #expect(r.consumed == 0)                 // did not advance
}

@Test func readerReadBytesNegativeLengthReturnsNil() {
    var r = BytesReader(Bytes([0x01, 0x02]))
    #expect(r.readBytes(length: -1) == nil)
    #expect(r.consumed == 0)
}
