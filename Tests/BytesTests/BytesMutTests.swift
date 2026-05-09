import Testing
@testable import Bytes

@Test func bytesMutEmptyDefault() {
    let m = BytesMut()
    #expect(m.count == 0)
    #expect(m.capacity == 0)
    #expect(m.isEmpty == true)
}

@Test func bytesMutWithCapacity() {
    let m = BytesMut(capacity: 128)
    #expect(m.count == 0)
    #expect(m.capacity >= 128)
    #expect(m.isEmpty == true)
}

@Test func bytesMutFromSequence() {
    let m = BytesMut([0x01, 0x02, 0x03])
    #expect(m.count == 3)
    #expect(m.capacity >= 3)
}

@Test func bytesMutReserveCapacityGrows() {
    var m = BytesMut()
    m.reserveCapacity(256)
    #expect(m.capacity >= 256)
    #expect(m.count == 0)
}

@Test func bytesMutClearResetsCount() {
    var m = BytesMut([0x01, 0x02, 0x03])
    let capBefore = m.capacity
    m.clear()
    #expect(m.count == 0)
    #expect(m.capacity == capBefore)  // storage retained when uniquely owned
}

@Test func bytesMutPutUInt8() {
    var m = BytesMut()
    m.putUInt8(0xAB)
    m.putUInt8(0xCD)
    let frozen = m.snapshot()
    #expect(Array(frozen) == [0xAB, 0xCD])
}

@Test func bytesMutPutUInt16BigLittle() {
    var m = BytesMut()
    m.putUInt16(0xDEAD, endianness: .big)
    m.putUInt16(0xDEAD, endianness: .little)
    let s = m.snapshot()
    #expect(Array(s) == [0xDE, 0xAD, 0xAD, 0xDE])
}

@Test func bytesMutPutUInt32() {
    var m = BytesMut()
    m.putUInt32(0xDEADBEEF, endianness: .big)
    let s = m.snapshot()
    #expect(Array(s) == [0xDE, 0xAD, 0xBE, 0xEF])
}

@Test func bytesMutPutUInt64() {
    var m = BytesMut()
    m.putUInt64(0x0102030405060708, endianness: .big)
    let s = m.snapshot()
    #expect(Array(s) == [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
}

@Test func bytesMutPutSignedIntegers() {
    var m = BytesMut()
    m.putInt8(-1)
    m.putInt16(-1, endianness: .big)
    m.putInt32(-2, endianness: .big)
    let s = m.snapshot()
    #expect(Array(s) == [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFE])
}

@Test func bytesMutPutBytesFromSequence() {
    var m = BytesMut()
    m.putBytes([0x01, 0x02, 0x03] as [UInt8])
    let s = m.snapshot()
    #expect(Array(s) == [0x01, 0x02, 0x03])
}

@Test func bytesMutPutBytesFromBytes() {
    var m = BytesMut()
    let other = Bytes([0xAA, 0xBB])
    m.putBytes(other)
    m.putBytes(other)
    let s = m.snapshot()
    #expect(Array(s) == [0xAA, 0xBB, 0xAA, 0xBB])
}

@Test func bytesMutGrowsOnAppend() {
    var m = BytesMut(capacity: 4)
    let initialCap = m.capacity
    for _ in 0..<100 { m.putUInt8(0xAA) }
    #expect(m.count == 100)
    #expect(m.capacity > initialCap)
    let s = m.snapshot()
    #expect(s.count == 100)
    #expect(s[0] == 0xAA && s[99] == 0xAA)
}

@Test func bytesMutWithUnsafeMutableBytes() {
    var m = BytesMut(capacity: 4)
    m.putBytes([0x00, 0x00, 0x00, 0x00] as [UInt8])
    m.withUnsafeMutableBytes { buf in
        buf[0] = 0xFF
        buf[3] = 0xFF
    }
    let s = m.snapshot()
    #expect(Array(s) == [0xFF, 0x00, 0x00, 0xFF])
}
