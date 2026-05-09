import Testing
@testable import Bytes

@Test func endiannessCasesAreSendable() {
    let cases: [Endianness] = [.big, .little, .host]
    #expect(cases.count == 3)
}

@Test func bytesErrorEquality() {
    #expect(BytesError.outOfBounds(offset: 0, length: 4, bufferCount: 2)
            == BytesError.outOfBounds(offset: 0, length: 4, bufferCount: 2))
    #expect(BytesError.shortRead(needed: 4, available: 2)
            == BytesError.shortRead(needed: 4, available: 2))
    #expect(BytesError.invalidLength(-1) == BytesError.invalidLength(-1))
    #expect(BytesError.shortRead(needed: 4, available: 2)
            != BytesError.shortRead(needed: 4, available: 3))
}
