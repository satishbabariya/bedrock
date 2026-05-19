import Testing
@testable import UnicodeProperties

@Suite
struct TwoStageTrieTests {

    @Test
    func allZeroTrieReturnsZero() {
        let trie = TwoStageTrie<UInt8>(
            stage1: Array(repeating: UInt16(0), count: 4352),
            stage2: Array(repeating: UInt8(0), count: 256)
        )
        #expect(trie.lookup(0x0000) == 0)
        #expect(trie.lookup(0x0041) == 0)
        #expect(trie.lookup(0xFFFF) == 0)
        #expect(trie.lookup(0x10FFFF) == 0)
    }

    @Test
    func twoBlockTrieRoutesCorrectly() {
        var stage1 = Array(repeating: UInt16(0), count: 4352)
        stage1[1] = 1
        let stage2: [UInt8] =
            Array(repeating: UInt8(7),  count: 256) +
            Array(repeating: UInt8(42), count: 256)
        let trie = TwoStageTrie<UInt8>(stage1: stage1, stage2: stage2)
        #expect(trie.lookup(0x0000) == 7)
        #expect(trie.lookup(0x00FF) == 7)
        #expect(trie.lookup(0x0100) == 42)
        #expect(trie.lookup(0x01FF) == 42)
        #expect(trie.lookup(0x0200) == 7)
    }

    @Test
    func lookupAtMaxCodepointIsBoundsSafe() {
        let stage1 = Array(repeating: UInt16(0), count: 4352)
        let stage2 = Array(repeating: UInt8(99), count: 256)
        let trie = TwoStageTrie<UInt8>(stage1: stage1, stage2: stage2)
        #expect(trie.lookup(0x10FFFF) == 99)
    }
}
