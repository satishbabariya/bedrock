import Testing
@testable import BedrockUcdGen

@Suite
struct TwoStageTrieBuilderTests {

    @Test
    func allZerosCompactsToOneUniqueBlock() {
        let uncompacted = Array(repeating: UInt8(0), count: 0x110000)
        let result = TwoStageTrieBuilder.build(uncompacted)
        #expect(result.stage1.count == 4352)
        #expect(result.stage2.count == 256)
        #expect(Array(Set(result.stage1)) == [0])
    }

    @Test
    func roundTripsExactly() {
        var uncompacted = Array(repeating: UInt8(29), count: 0x110000)
        uncompacted[0x0041] = 0
        uncompacted[0x0061] = 1
        uncompacted[0x4E00] = 4
        let result = TwoStageTrieBuilder.build(uncompacted)
        for cp in [UInt32(0x0041), 0x0061, 0x4E00, 0x10FFFF, 0xABCD] {
            let lookup = result.lookup(UInt32(cp))
            #expect(lookup == uncompacted[Int(cp)],
                    "mismatch at U+\(String(cp, radix: 16))")
        }
    }

    @Test
    func selfCheckCoversAllCodepoints() throws {
        var uncompacted = Array(repeating: UInt8(29), count: 0x110000)
        for cp in stride(from: 0, to: 0x110000, by: 257) {
            uncompacted[cp] = UInt8(cp % 30)
        }
        let result = TwoStageTrieBuilder.build(uncompacted)
        for cp in 0..<UInt32(0x110000) {
            #expect(result.lookup(cp) == uncompacted[Int(cp)])
        }
    }

    @Test
    func dedupSharesIdenticalBlocks() {
        var uncompacted = Array(repeating: UInt8(7), count: 0x110000)
        uncompacted[0x0500] = 99
        let result = TwoStageTrieBuilder.build(uncompacted)
        #expect(result.stage1[0] == result.stage1[1])
        #expect(result.stage1[0] == result.stage1[2])
        #expect(result.stage1[5] != result.stage1[0])
    }
}
