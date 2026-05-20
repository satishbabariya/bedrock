import Testing
@testable import BedrockUcdGen

@Suite
struct CodeEmitterTests {

    @Test
    func headerContainsExpectedTokens() {
        let trie = BuiltTrie<UInt8>(
            stage1: [0, 0, 0, 0],
            stage2: [1, 2, 3]
        )
        let src = CodeEmitter.emit(trie, unicodeVersion: "16.0.0", globalName: "generalCategoryTable", valueTypeName: "UInt8")
        #expect(src.contains("GENERATED"))
        #expect(src.contains("16.0.0"))
        #expect(src.contains("@usableFromInline"))
        #expect(src.contains("internal let generalCategoryTable"))
        #expect(src.contains("TwoStageTrie<UInt8>"))
    }

    @Test
    func includesStage1AndStage2Arrays() {
        let trie = BuiltTrie<UInt8>(
            stage1: [0, 0],
            stage2: [42]
        )
        let src = CodeEmitter.emit(trie, unicodeVersion: "16.0.0", globalName: "generalCategoryTable", valueTypeName: "UInt8")
        #expect(src.contains("stage1:"))
        #expect(src.contains("stage2:"))
        #expect(src.contains("42"))
    }

    @Test
    func emitsValidSwift() {
        let trie = BuiltTrie(
            stage1: Array(repeating: UInt16(0), count: 16),
            stage2: Array(repeating: UInt8(0), count: 256)
        )
        let src = CodeEmitter.emit(trie, unicodeVersion: "16.0.0", globalName: "generalCategoryTable", valueTypeName: "UInt8")
        #expect(src.filter({ $0 == "[" }).count == src.filter({ $0 == "]" }).count)
        #expect(src.filter({ $0 == "(" }).count == src.filter({ $0 == ")" }).count)
    }

    @Test
    func usesProvidedGlobalName() {
        let trie = BuiltTrie<UInt8>(
            stage1: [0, 0],
            stage2: [1]
        )
        let src = CodeEmitter.emit(trie, unicodeVersion: "16.0.0", globalName: "myCustomTable", valueTypeName: "UInt8")
        #expect(src.contains("internal let myCustomTable"))
        #expect(src.contains("internal let generalCategoryTable") == false)
    }

    @Test
    func usesProvidedValueTypeName() {
        var uncompacted = [UInt32](repeating: 0, count: 0x110000)
        uncompacted[0x0041] = 0x0061
        let trie = TwoStageTrieBuilder.build(uncompacted)
        let src = CodeEmitter.emit(trie,
                                    unicodeVersion: "16.0.0",
                                    globalName: "uint32Table",
                                    valueTypeName: "UInt32")
        #expect(src.contains("TwoStageTrie<UInt32>"))
        #expect(src.contains("TwoStageTrie<UInt8>") == false)
    }
}
