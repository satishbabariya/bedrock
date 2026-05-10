import Testing
@testable import Base64

@Test func base64EnumsExist() {
    let _: [Base64.Variant] = [.standard, .urlSafe]
    let _: [Base64.DecodeMode] = [.strict, .lenient, .constantTime]
    let _: [Base64.LineWrap] = [.none, .mime76]
    #expect(true)
}

@Test func base64ErrorEquality() {
    #expect(Base64Error.invalidCharacter(offset: 1, byte: 0x21)
            == Base64Error.invalidCharacter(offset: 1, byte: 0x21))
    #expect(Base64Error.invalidLength(7) == Base64Error.invalidLength(7))
    #expect(Base64Error.invalidPadding(offset: 5) == Base64Error.invalidPadding(offset: 5))
    #expect(Base64Error.constantTimeRejected == Base64Error.constantTimeRejected)
    #expect(Base64Error.invalidLength(7) != Base64Error.invalidLength(8))
}
