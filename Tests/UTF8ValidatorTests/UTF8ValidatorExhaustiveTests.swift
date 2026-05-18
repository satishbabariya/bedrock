import Testing
import UTF8Validator
import Bytes

@Suite
struct UTF8ValidatorExhaustiveTests {

    /// Independent hand-rolled UTF-8 encoder used as oracle.
    /// Does NOT depend on Swift's `Unicode.UTF8.encode`.
    private func encode(_ cp: UInt32) -> [UInt8] {
        precondition(cp <= 0x10FFFF)
        if cp < 0x80 {
            return [UInt8(cp)]
        } else if cp < 0x800 {
            return [
                UInt8(0xC0 | (cp >> 6)),
                UInt8(0x80 | (cp & 0x3F)),
            ]
        } else if cp < 0x10000 {
            return [
                UInt8(0xE0 | (cp >> 12)),
                UInt8(0x80 | ((cp >> 6) & 0x3F)),
                UInt8(0x80 | (cp & 0x3F)),
            ]
        } else {
            return [
                UInt8(0xF0 | (cp >> 18)),
                UInt8(0x80 | ((cp >> 12) & 0x3F)),
                UInt8(0x80 | ((cp >> 6) & 0x3F)),
                UInt8(0x80 | (cp & 0x3F)),
            ]
        }
    }

    @Test
    func everyValidCodePointRoundTrips() {
        for cp: UInt32 in 0x0000 ... 0x10FFFF {
            if cp >= 0xD800 && cp <= 0xDFFF { continue }  // skip surrogates
            let bytes = Bytes(encode(cp))
            let r = UTF8Validator.validate(bytes)
            if r != .valid {
                Issue.record("U+\(String(cp, radix: 16, uppercase: true)) encoded to \(Array(bytes)) was rejected with \(r)")
                return  // stop at first failure
            }
            if !UTF8Validator.isValid(bytes) {
                Issue.record("isValid==false for U+\(String(cp, radix: 16, uppercase: true))")
                return
            }
        }
    }

    @Test
    func everySurrogateEncodingIsRejected() {
        for cp: UInt32 in 0xD800 ... 0xDFFF {
            let bytes = Bytes(encode(cp))
            let r = UTF8Validator.validate(bytes)
            if r == .valid {
                Issue.record("U+\(String(cp, radix: 16, uppercase: true)) (surrogate) was accepted")
                return
            }
        }
    }
}
