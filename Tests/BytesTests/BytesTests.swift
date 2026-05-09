import Testing
@testable import Bytes

@Test func emptyBytesHasZeroCount() {
    let b = Bytes()
    #expect(b.count == 0)
    #expect(b.isEmpty == true)
}

@Test func bytesEmptyConstantSharesStorage() {
    let a = Bytes.empty
    let b = Bytes.empty
    #expect(a.count == 0 && b.count == 0)
}

@Test func bytesFromArray() {
    let b = Bytes([0xDE, 0xAD, 0xBE, 0xEF])
    #expect(b.count == 4)
    #expect(b[0] == 0xDE)
    #expect(b[3] == 0xEF)
}

@Test func bytesArrayLiteral() {
    let b: Bytes = [0x01, 0x02, 0x03]
    #expect(b.count == 3)
    #expect(Array(b) == [0x01, 0x02, 0x03])
}

@Test func bytesIteration() {
    let b = Bytes([0x10, 0x20, 0x30])
    var sum = 0
    for byte in b { sum += Int(byte) }
    #expect(sum == 0x60)
}

@Test func bytesFirstAndLast() {
    let b = Bytes([0xAA, 0xBB, 0xCC])
    #expect(b.first == 0xAA)
    #expect(b.last == 0xCC)
}

@Test func bytesContains() {
    let b = Bytes([0x01, 0x02, 0x03])
    #expect(b.contains(0x02))
    #expect(!b.contains(0x99))
}
