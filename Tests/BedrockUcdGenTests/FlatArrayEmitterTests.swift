import Testing
@testable import BedrockUcdGen

@Suite
struct FlatArrayEmitterTests {

    @Test
    func headerContainsExpectedTokens() {
        let src = FlatArrayEmitter.emit([0, 1, 2, 3],
                                          unicodeVersion: "16.0.0",
                                          globalName: "exampleTable")
        #expect(src.contains("GENERATED"))
        #expect(src.contains("16.0.0"))
        #expect(src.contains("@usableFromInline"))
        #expect(src.contains("internal let exampleTable: [UInt32]"))
    }

    @Test
    func emitsArrayContents() {
        let src = FlatArrayEmitter.emit([42, 100, 255],
                                          unicodeVersion: "16.0.0",
                                          globalName: "exampleTable")
        #expect(src.contains("42"))
        #expect(src.contains("100"))
        #expect(src.contains("255"))
    }

    @Test
    func emptyArrayProducesValidLiteral() {
        let src = FlatArrayEmitter.emit([],
                                          unicodeVersion: "16.0.0",
                                          globalName: "exampleTable")
        #expect(src.contains("internal let exampleTable: [UInt32]"))
        #expect(src.contains("["))
        #expect(src.contains("]"))
    }

    @Test
    func balancedBrackets() {
        let src = FlatArrayEmitter.emit(Array(repeating: UInt32(1), count: 32),
                                          unicodeVersion: "16.0.0",
                                          globalName: "exampleTable")
        #expect(src.filter({ $0 == "[" }).count == src.filter({ $0 == "]" }).count)
    }

    @Test
    func usesProvidedGlobalName() {
        let src = FlatArrayEmitter.emit([1, 2, 3],
                                          unicodeVersion: "16.0.0",
                                          globalName: "myCustomFlat")
        #expect(src.contains("internal let myCustomFlat: [UInt32]"))
    }
}
