public struct WordBreakPropertyEntry: Equatable, Sendable {
    public let first: UInt32
    public let last: UInt32
    public let value: String   // "CR", "LF", "Newline", "Extend", "ZWJ",
                                // "Regional_Indicator", "Format", "Katakana",
                                // "Hebrew_Letter", "ALetter", "Single_Quote",
                                // "Double_Quote", "MidNumLet", "MidLetter",
                                // "MidNum", "Numeric", "ExtendNumLet", "WSegSpace"

    public init(first: UInt32, last: UInt32, value: String) {
        self.first = first
        self.last  = last
        self.value = value
    }
}

public enum WordBreakPropertyParseError: Error, Equatable {
    case truncatedLine(lineNumber: Int)
    case invalidCodepoint(lineNumber: Int, raw: String)
    case invalidRange(lineNumber: Int, raw: String)
    case emptyPropertyValue(lineNumber: Int)
}

public enum WordBreakPropertyParser {

    public static func parse(_ text: String) throws -> [WordBreakPropertyEntry] {
        var entries: [WordBreakPropertyEntry] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        for (i, lineSub) in lines.enumerated() {
            let lineNumber = i + 1
            var line = String(lineSub)
            if let hashIdx = line.firstIndex(of: "#") {
                line = String(line[..<hashIdx])
            }
            let trimmed = line.wbpTrimmed()
            if trimmed.isEmpty { continue }

            let fields = trimmed.split(separator: ";", omittingEmptySubsequences: false)
            if fields.count < 2 {
                throw WordBreakPropertyParseError.truncatedLine(lineNumber: lineNumber)
            }
            let rangeField = String(fields[0]).wbpTrimmed()
            let valueField = String(fields[1]).wbpTrimmed()

            if valueField.isEmpty {
                throw WordBreakPropertyParseError.emptyPropertyValue(lineNumber: lineNumber)
            }

            let first: UInt32
            let last: UInt32
            if let dotRange = rangeField.wbpRange(of: "..") {
                let firstStr = String(rangeField[..<dotRange.lowerBound]).wbpTrimmed()
                let lastStr  = String(rangeField[dotRange.upperBound...]).wbpTrimmed()
                guard !firstStr.isEmpty, !lastStr.isEmpty,
                      let f = UInt32(firstStr, radix: 16),
                      let l = UInt32(lastStr,  radix: 16) else {
                    throw WordBreakPropertyParseError.invalidRange(lineNumber: lineNumber,
                                                                   raw: rangeField)
                }
                first = f
                last  = l
            } else {
                guard let cp = UInt32(rangeField, radix: 16) else {
                    throw WordBreakPropertyParseError.invalidCodepoint(lineNumber: lineNumber,
                                                                       raw: rangeField)
                }
                first = cp
                last  = cp
            }

            entries.append(WordBreakPropertyEntry(first: first, last: last, value: valueField))
        }
        return entries
    }
}

public enum WordBreakCode {
    /// Map UCD Word_Break value to UInt8 raw value matching
    /// UnicodeProperties.WordBreak.
    public static func rawValue(for value: String) throws -> UInt8 {
        switch value {
        case "Other":              return 0
        case "CR":                 return 1
        case "LF":                 return 2
        case "Newline":            return 3
        case "Extend":             return 4
        case "ZWJ":                return 5
        case "Regional_Indicator": return 6
        case "Format":             return 7
        case "Katakana":           return 8
        case "Hebrew_Letter":      return 9
        case "ALetter":            return 10
        case "Single_Quote":       return 11
        case "Double_Quote":       return 12
        case "MidNumLet":          return 13
        case "MidLetter":          return 14
        case "MidNum":             return 15
        case "Numeric":            return 16
        case "ExtendNumLet":       return 17
        case "WSegSpace":          return 18
        default:
            throw WordBreakPropertyParseError.invalidCodepoint(lineNumber: -1, raw: value)
        }
    }
}

public extension Array where Element == WordBreakPropertyEntry {
    /// Returns a 0x110000-element array of UInt8 raw values (0–18).
    /// Default fill is 0 (Other) per the UCD `@missing` directive.
    func expandWordBreak() throws -> [UInt8] {
        var out = [UInt8](repeating: 0, count: 0x110000)
        for entry in self {
            let value = try WordBreakCode.rawValue(for: entry.value)
            for cp in entry.first...entry.last {
                out[Int(cp)] = value
            }
        }
        return out
    }
}

private extension String {
    func wbpTrimmed() -> String {
        var startIdx = self.startIndex
        while startIdx < self.endIndex,
              [" ", "\t", "\r"].contains(self[startIdx]) {
            startIdx = self.index(after: startIdx)
        }
        var endIdx = self.endIndex
        while endIdx > startIdx {
            let prev = self.index(before: endIdx)
            if ![" ", "\t", "\r"].contains(self[prev]) { break }
            endIdx = prev
        }
        return String(self[startIdx..<endIdx])
    }

    /// Returns the range of the first occurrence of `needle` in `self`,
    /// using only stdlib Character comparisons (no Foundation).
    func wbpRange(of needle: String) -> Range<String.Index>? {
        guard !needle.isEmpty else { return startIndex..<startIndex }
        var i = startIndex
        let needleFirst = needle[needle.startIndex]
        while i < endIndex {
            if self[i] == needleFirst {
                var si = i
                var ni = needle.startIndex
                while ni < needle.endIndex, si < endIndex, self[si] == needle[ni] {
                    si = index(after: si)
                    ni = needle.index(after: ni)
                }
                if ni == needle.endIndex { return i..<si }
            }
            i = index(after: i)
        }
        return nil
    }
}
