public struct UCDEntry: Equatable, Sendable {
    public let first: UInt32
    public let last: UInt32
    public let category: String
    public let canonicalCombiningClass: UInt8
    public let bidiClass: String
    public let simpleUppercase: UInt32
    public let simpleLowercase: UInt32
    public let simpleTitlecase: UInt32

    public init(first: UInt32,
                last: UInt32,
                category: String,
                canonicalCombiningClass: UInt8 = 0,
                bidiClass: String = "L",
                simpleUppercase: UInt32 = 0,
                simpleLowercase: UInt32 = 0,
                simpleTitlecase: UInt32 = 0) {
        self.first = first
        self.last = last
        self.category = category
        self.canonicalCombiningClass = canonicalCombiningClass
        self.bidiClass = bidiClass
        self.simpleUppercase = simpleUppercase
        self.simpleLowercase = simpleLowercase
        self.simpleTitlecase = simpleTitlecase
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
            let upper = fields[12].isEmpty ? 0 : (UInt32(fields[12], radix: 16) ?? 0)
            let lower = fields[13].isEmpty ? 0 : (UInt32(fields[13], radix: 16) ?? 0)
            let title = fields[14].isEmpty ? 0 : (UInt32(fields[14], radix: 16) ?? 0)

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
                                         bidiClass: bidi,
                                         simpleUppercase: upper,
                                         simpleLowercase: lower,
                                         simpleTitlecase: title))
                i += 2
            } else {
                entries.append(UCDEntry(first: codepoint,
                                         last: codepoint,
                                         category: category,
                                         canonicalCombiningClass: ccc,
                                         bidiClass: bidi,
                                         simpleUppercase: upper,
                                         simpleLowercase: lower,
                                         simpleTitlecase: title))
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

public enum BidiClassCode {
    /// Map UCD bidi-class abbreviation to the UnicodeProperties.BidiClass raw value.
    public static func rawValue(for abbreviation: String) throws -> UInt8 {
        switch abbreviation {
        case "L":   return 0
        case "R":   return 1
        case "AL":  return 2
        case "EN":  return 3
        case "ES":  return 4
        case "ET":  return 5
        case "AN":  return 6
        case "CS":  return 7
        case "NSM": return 8
        case "BN":  return 9
        case "B":   return 10
        case "S":   return 11
        case "WS":  return 12
        case "ON":  return 13
        case "LRE": return 14
        case "LRO": return 15
        case "RLE": return 16
        case "RLO": return 17
        case "PDF": return 18
        case "LRI": return 19
        case "RLI": return 20
        case "FSI": return 21
        case "PDI": return 22
        default:
            throw UCDParseError.invalidCodepoint(lineNumber: -1, raw: abbreviation)
        }
    }
}

public extension Array where Element == UCDEntry {
    /// Expand a list of UCDEntries into a 0x110000-element uncompacted
    /// array of general-category raw values. Codepoints absent from
    /// the input default to .unassigned (raw 29).
    func expandGeneralCategory() throws -> [UInt8] {
        var out = [UInt8](repeating: 29, count: 0x110000)
        for entry in self {
            let value = try GeneralCategoryCode.rawValue(for: entry.category)
            for cp in entry.first...entry.last {
                out[Int(cp)] = value
            }
        }
        return out
    }

    /// Expand to a 0x110000-element uncompacted array of bidi-class raw
    /// values. Codepoints absent from the input default to L (raw 0).
    func expandBidiClass() throws -> [UInt8] {
        var out = [UInt8](repeating: 0, count: 0x110000)
        for entry in self {
            let value = try BidiClassCode.rawValue(for: entry.bidiClass)
            for cp in entry.first...entry.last {
                out[Int(cp)] = value
            }
        }
        return out
    }

    /// Expand to a 0x110000-element uncompacted array of canonical
    /// combining class values. Codepoints absent from the input
    /// default to 0 (Not Reordered).
    func expandCanonicalCombiningClass() -> [UInt8] {
        var out = [UInt8](repeating: 0, count: 0x110000)
        for entry in self {
            let value = entry.canonicalCombiningClass
            if value == 0 { continue }
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
