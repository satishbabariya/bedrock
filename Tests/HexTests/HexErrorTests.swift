import Testing
@testable import Hex

@Test func hexCaseEnum() {
    let cases: [Hex.Case] = [.lower, .upper]
    #expect(cases.count == 2)
}

@Test func hexErrorEquality() {
    #expect(HexError.oddLength(3) == HexError.oddLength(3))
    #expect(HexError.oddLength(3) != HexError.oddLength(5))
    #expect(HexError.invalidCharacter(offset: 2, byte: 0x40)
            == HexError.invalidCharacter(offset: 2, byte: 0x40))
    #expect(HexError.invalidCharacter(offset: 2, byte: 0x40)
            != HexError.invalidCharacter(offset: 3, byte: 0x40))
}
