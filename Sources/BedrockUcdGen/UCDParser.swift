public struct UCDEntry: Equatable, Sendable {
    public let first: UInt32
    public let last: UInt32
    public let category: String
    public let canonicalCombiningClass: UInt8
    public let bidiClass: String

    public init(first: UInt32,
                last: UInt32,
                category: String,
                canonicalCombiningClass: UInt8 = 0,
                bidiClass: String = "L") {
        self.first = first
        self.last = last
        self.category = category
        self.canonicalCombiningClass = canonicalCombiningClass
        self.bidiClass = bidiClass
    }
}

public enum UCDParseError: Error, Equatable {
    case truncatedLine(lineNumber: Int)
    case invalidCodepoint(lineNumber: Int, raw: String)
    case unmatchedRangeMarker(lineNumber: Int)
}

public enum UCDParser {

    public static func parse(_ text: String) throws -> [UCDEntry] {
        var entries: [UCDEntry] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var i = 0
        while i < lines.count {
            let lineNumber = i + 1
            let raw = String(lines[i].stdlibTrimmed())
            if raw.isEmpty {
                i += 1
                continue
            }

            let fields = raw.split(separator: ";", omittingEmptySubsequences: false)
            // UCD lines have 15 fields (UAX #44 §4.2.1).
            if fields.count < 15 {
                throw UCDParseError.truncatedLine(lineNumber: lineNumber)
            }
            guard let codepoint = UInt32(fields[0], radix: 16) else {
                throw UCDParseError.invalidCodepoint(lineNumber: lineNumber,
                                                     raw: String(fields[0]))
            }
            let name = String(fields[1])
            let category = String(fields[2])
            guard let ccc = UInt8(fields[3]) else {
                throw UCDParseError.invalidCodepoint(lineNumber: lineNumber,
                                                      raw: String(fields[3]))
            }
            let bidi = String(fields[4])

            if name.hasSuffix(", First>") {
                guard i + 1 < lines.count else {
                    throw UCDParseError.unmatchedRangeMarker(lineNumber: lineNumber)
                }
                let nextRaw = String(lines[i + 1].stdlibTrimmed())
                let nextFields = nextRaw.split(separator: ";",
                                                omittingEmptySubsequences: false)
                guard nextFields.count >= 15,
                      nextFields[1].hasSuffix(", Last>") else {
                    throw UCDParseError.unmatchedRangeMarker(lineNumber: lineNumber)
                }
                guard let lastCodepoint = UInt32(nextFields[0], radix: 16) else {
                    throw UCDParseError.invalidCodepoint(lineNumber: lineNumber + 1,
                                                          raw: String(nextFields[0]))
                }
                entries.append(UCDEntry(first: codepoint,
                                         last: lastCodepoint,
                                         category: category,
                                         canonicalCombiningClass: ccc,
                                         bidiClass: bidi))
                i += 2
            } else {
                entries.append(UCDEntry(first: codepoint,
                                         last: codepoint,
                                         category: category,
                                         canonicalCombiningClass: ccc,
                                         bidiClass: bidi))
                i += 1
            }
        }
        return entries
    }
}

public enum GeneralCategoryCode {
    /// Map UCD category abbreviation to the UnicodeProperties.GeneralCategory raw value.
    public static func rawValue(for abbreviation: String) throws -> UInt8 {
        switch abbreviation {
        case "Lu": return 0
        case "Ll": return 1
        case "Lt": return 2
        case "Lm": return 3
        case "Lo": return 4
        case "Mn": return 5
        case "Mc": return 6
        case "Me": return 7
        case "Nd": return 8
        case "Nl": return 9
        case "No": return 10
        case "Pc": return 11
        case "Pd": return 12
        case "Ps": return 13
        case "Pe": return 14
        case "Pi": return 15
        case "Pf": return 16
        case "Po": return 17
        case "Sm": return 18
        case "Sc": return 19
        case "Sk": return 20
        case "So": return 21
        case "Zs": return 22
        case "Zl": return 23
        case "Zp": return 24
        case "Cc": return 25
        case "Cf": return 26
        case "Cs": return 27
        case "Co": return 28
        case "Cn": return 29
        default:
            throw UCDParseError.invalidCodepoint(lineNumber: -1, raw: abbreviation)
        }
    }
}

public extension Array where Element == UCDEntry {
    /// Expand a list of UCDEntries into a 0x110000-element uncompacted
    /// array of general-category raw values. Codepoints absent from
    /// the input default to .unassigned (raw 29).
    func expandToUncompacted() throws -> [UInt8] {
        var out = [UInt8](repeating: 29, count: 0x110000)
        for entry in self {
            let value = try GeneralCategoryCode.rawValue(for: entry.category)
            for cp in entry.first...entry.last {
                out[Int(cp)] = value
            }
        }
        return out
    }
}

private extension Substring {
    func stdlibTrimmed() -> Substring {
        var s = self.drop(while: { $0 == " " || $0 == "\t" || $0 == "\r" })
        while let last = s.last, last == " " || last == "\t" || last == "\r" {
            s = s.dropLast()
        }
        return s
    }
}
