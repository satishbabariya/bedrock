import Bytes

@usableFromInline
internal enum UTF8ValidatorDFA {

    @usableFromInline static let ACCEPT: UInt8 = 0
    @usableFromInline static let REJECT: UInt8 = 96

    // 256-entry byte-class table.
    @usableFromInline static let byteClass: [UInt8] = [
        // 0x00..0x7F — ASCII (class 0)
        0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,
        // 0x80..0x8F — continuation low-low (class 1)
        1, 1, 1, 1, 1, 1, 1, 1,  1, 1, 1, 1, 1, 1, 1, 1,
        // 0x90..0x9F — continuation low-high (class 2)
        2, 2, 2, 2, 2, 2, 2, 2,  2, 2, 2, 2, 2, 2, 2, 2,
        // 0xA0..0xBF — continuation high (class 3) — 32 entries
        3, 3, 3, 3, 3, 3, 3, 3,  3, 3, 3, 3, 3, 3, 3, 3,
        3, 3, 3, 3, 3, 3, 3, 3,  3, 3, 3, 3, 3, 3, 3, 3,
        // 0xC0..0xC1 — invalid (class 11)
        11, 11,
        // 0xC2..0xDF — lead 2-byte (class 4) — 30 entries
        4, 4, 4, 4, 4, 4, 4, 4,  4, 4, 4, 4, 4, 4,
        4, 4, 4, 4, 4, 4, 4, 4,  4, 4, 4, 4, 4, 4, 4, 4,
        // 0xE0 — lead 3-byte overlong-protected (class 5)
        5,
        // 0xE1..0xEC — lead 3-byte general (class 6) — 12 entries
        6, 6, 6, 6, 6, 6, 6, 6,  6, 6, 6, 6,
        // 0xED — lead 3-byte surrogate-protected (class 7)
        7,
        // 0xEE..0xEF — lead 3-byte general (class 6)
        6, 6,
        // 0xF0 — lead 4-byte overlong-protected (class 8)
        8,
        // 0xF1..0xF3 — lead 4-byte general (class 9)
        9, 9, 9,
        // 0xF4 — lead 4-byte range-protected (class 10)
        10,
        // 0xF5..0xFF — invalid (class 11) — 11 entries
        11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11,
    ]

    // Transition table. 9 states × 12 classes = 108 entries.
    // Index as transition[Int(state) + Int(class)].
    @usableFromInline static let transition: [UInt8] = [
        // s0  ACCEPT
        //  cls: 0    1   2   3   4   5   6   7   8   9  10  11
                 0,  96, 96, 96, 12, 36, 24, 48, 72, 60, 84, 96,
        // s12 — need 1 cont (any)
                96,   0,  0,  0, 96, 96, 96, 96, 96, 96, 96, 96,
        // s24 — need 2 conts (first any)
                96,  12, 12, 12, 96, 96, 96, 96, 96, 96, 96, 96,
        // s36 — E0: first cont must be A0..BF (cls 3)
                96,  96, 96, 12, 96, 96, 96, 96, 96, 96, 96, 96,
        // s48 — ED: first cont must be 80..9F (cls 1 or 2)
                96,  12, 12, 96, 96, 96, 96, 96, 96, 96, 96, 96,
        // s60 — F1..F3: need 3 conts (first any)
                96,  24, 24, 24, 96, 96, 96, 96, 96, 96, 96, 96,
        // s72 — F0: first cont must be 90..BF (cls 2 or 3)
                96,  96, 24, 24, 96, 96, 96, 96, 96, 96, 96, 96,
        // s84 — F4: first cont must be 80..8F (cls 1)
                96,  24, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96,
        // s96 REJECT (terminal)
                96,  96, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96,
    ]

    @usableFromInline
    static func validate(_ bytes: Bytes) -> UTF8Validator.ValidationResult {
        var state: UInt8 = ACCEPT
        var sequenceStart: Int = 0
        var rejectedAt: Int = -1
        let count = bytes.count

        bytes.withUnsafeBytes { src in
            var i = 0
            while i < count {
                let cls = byteClass[Int(src[i])]
                state = transition[Int(state) + Int(cls)]
                if state == REJECT {
                    rejectedAt = sequenceStart
                    return
                }
                if state == ACCEPT {
                    sequenceStart = i + 1
                }
                i += 1
            }
        }

        if rejectedAt >= 0 { return .invalid(offset: rejectedAt) }
        if state != ACCEPT { return .invalid(offset: sequenceStart) }
        return .valid
    }

    @usableFromInline
    static func isValid(_ bytes: Bytes) -> Bool {
        var state: UInt8 = ACCEPT
        let count = bytes.count
        var ok = true

        bytes.withUnsafeBytes { src in
            var i = 0
            while i < count {
                let cls = byteClass[Int(src[i])]
                state = transition[Int(state) + Int(cls)]
                if state == REJECT {
                    ok = false
                    return
                }
                i += 1
            }
        }

        return ok && state == ACCEPT
    }
}
