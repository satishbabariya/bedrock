public struct BuiltTrie<Value: FixedWidthInteger & Sendable>: Sendable {
    public let stage1: [UInt16]
    public let stage2: [Value]

    public init(stage1: [UInt16], stage2: [Value]) {
        self.stage1 = stage1
        self.stage2 = stage2
    }

    public func lookup(_ codepoint: UInt32) -> Value {
        let block = Int(stage1[Int(codepoint >> 8)])
        return stage2[(block << 8) | Int(codepoint & 0xFF)]
    }
}

public enum TwoStageTrieBuilder {

    /// Build a compacted two-stage trie from an uncompacted array of
    /// 0x110000 entries (one per codepoint).
    public static func build<Value: FixedWidthInteger & Sendable>(
        _ uncompacted: [Value]
    ) -> BuiltTrie<Value> {
        precondition(uncompacted.count == 0x110000)

        let blockCount = 0x110000 / 256
        var stage1 = [UInt16](repeating: 0, count: blockCount)
        var stage2: [Value] = []
        var blockIndex: [[Value]: UInt16] = [:]

        for b in 0..<blockCount {
            let block = Array(uncompacted[(b * 256)..<((b + 1) * 256)])
            if let existing = blockIndex[block] {
                stage1[b] = existing
            } else {
                let idx = UInt16(stage2.count / 256)
                stage2.append(contentsOf: block)
                blockIndex[block] = idx
                stage1[b] = idx
            }
        }
        return BuiltTrie(stage1: stage1, stage2: stage2)
    }
}
