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
