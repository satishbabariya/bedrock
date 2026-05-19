/// Two-stage trie for U+0000..U+10FFFF property lookups.
///
/// `stage1[codepoint >> 8]` gives a block index into stage2.
/// `stage2[(blockIndex << 8) | (codepoint & 0xFF)]` gives the value.
///
/// Duplicate 256-entry blocks in stage2 are deduplicated at codegen
/// time so identical blocks (e.g., large unassigned runs) share storage.
@usableFromInline
internal struct TwoStageTrie<Value: FixedWidthInteger>: Sendable where Value: Sendable {
    @usableFromInline let stage1: [UInt16]
    @usableFromInline let stage2: [Value]

    @inlinable
    init(stage1: [UInt16], stage2: [Value]) {
        self.stage1 = stage1
        self.stage2 = stage2
    }

    @inlinable
    func lookup(_ codepoint: UInt32) -> Value {
        let block = Int(stage1[Int(codepoint >> 8)])
        return stage2[(block << 8) | Int(codepoint & 0xFF)]
    }
}
