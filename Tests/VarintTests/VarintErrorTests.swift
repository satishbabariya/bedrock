import Testing
@testable import Varint

@Test func varintErrorEquality() {
    #expect(VarintError.truncated == VarintError.truncated)
    #expect(VarintError.overflow == VarintError.overflow)
    #expect(VarintError.truncated != VarintError.overflow)
}

@Test func boundsConstants() {
    #expect(Varint.maxBytes32 == 5)
    #expect(Varint.maxBytes64 == 10)
}
