public struct UCDEntry: Equatable, Sendable {
    public let first: UInt32
    public let last: UInt32
    public let category: String

    public init(first: UInt32, last: UInt32, category: String) {
        self.first = first
        self.last = last
        self.category = category
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
                                         category: category))
                i += 2
            } else {
                entries.append(UCDEntry(first: codepoint,
                                         last: codepoint,
                                         category: category))
                i += 1
            }
        }
        return entries
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
