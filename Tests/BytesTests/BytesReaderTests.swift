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
