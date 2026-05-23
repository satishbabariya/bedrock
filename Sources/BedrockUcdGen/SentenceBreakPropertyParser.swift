public struct SentenceBreakPropertyEntry: Equatable, Sendable {
    public let first: UInt32
    public let last: UInt32
    public let value: String   // "CR", "LF", "Sep", "Extend", "Format",
                                // "Sp", "Lower", "Upper", "OLetter",
                                // "Numeric", "ATerm", "STerm", "SContinue", "Close"

    public init(first: UInt32, last: UInt32, value: String) {
        self.first = first
        self.last  = last
        self.value = value
    }
}

public enum SentenceBreakPropertyParseError: Error, Equatable {
    case truncatedLine(lineNumber: Int)
    case invalidCodepoint(lineNumber: Int, raw: String)
    case invalidRange(lineNumber: Int, raw: String)
    case emptyPropertyValue(lineNumber: Int)
}

public enum SentenceBreakPropertyParser {

    public static func parse(_ text: String) throws -> [SentenceBreakPropertyEntry] {
        var entries: [SentenceBreakPropertyEntry] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        for (i, lineSub) in lines.enumerated() {
            let lineNumber = i + 1
            var line = String(lineSub)
            if let hashIdx = line.firstIndex(of: "#") {
                line = String(line[..<hashIdx])
            }
            let trimmed = line.sbpTrimmed()
            if trimmed.isEmpty { continue }

            let fields = trimmed.split(separator: ";", omittingEmptySubsequences: false)
            if fields.count < 2 {
                throw SentenceBreakPropertyParseError.truncatedLine(lineNumber: lineNumber)
            }
            let rangeField = String(fields[0]).sbpTrimmed()
            let valueField = String(fields[1]).sbpTrimmed()

            if valueField.isEmpty {
                throw SentenceBreakPropertyParseError.emptyPropertyValue(lineNumber: lineNumber)
            }

            let first: UInt32
            let last: UInt32
            if let dotRange = rangeField.sbpRange(of: "..") {
                let firstStr = String(rangeField[..<dotRange.lowerBound]).sbpTrimmed()
                let lastStr  = String(rangeField[dotRange.upperBound...]).sbpTrimmed()
                guard !firstStr.isEmpty, !lastStr.isEmpty,
                      let f = UInt32(firstStr, radix: 16),
                      let l = UInt32(lastStr,  radix: 16) else {
                    throw SentenceBreakPropertyParseError.invalidRange(lineNumber: lineNumber,
                                                                       raw: rangeField)
                }
                first = f
                last  = l
            } else {
                guard let cp = UInt32(rangeField, radix: 16) else {
                    throw SentenceBreakPropertyParseError.invalidCodepoint(lineNumber: lineNumber,
                                                                           raw: rangeField)
                }
                first = cp
                last  = cp
            }

            entries.append(SentenceBreakPropertyEntry(first: first, last: last, value: valueField))
        }
        return entries
    }
}

public enum SentenceBreakCode {
    /// Map UCD Sentence_Break value to UInt8 raw value matching
    /// UnicodeProperties.SentenceBreak.
    public static func rawValue(for value: String) throws -> UInt8 {
        switch value {
        case "Other":     return 0
        case "CR":        return 1
        case "LF":        return 2
        case "Sep":       return 3
        case "Extend":    return 4
        case "Format":    return 5
        case "Sp":        return 6
        case "Lower":     return 7
        case "Upper":     return 8
        case "OLetter":   return 9
        case "Numeric":   return 10
        case "ATerm":     return 11
        case "STerm":     return 12
        case "SContinue": return 13
        case "Close":     return 14
        default:
            throw SentenceBreakPropertyParseError.invalidCodepoint(lineNumber: -1, raw: value)
        }
    }
}

public extension Array where Element == SentenceBreakPropertyEntry {
    /// Returns a 0x110000-element array of UInt8 raw values (0–14).
    /// Default fill is 0 (Other) per the UCD `@missing` directive.
    func expandSentenceBreak() throws -> [UInt8] {
        var out = [UInt8](repeating: 0, count: 0x110000)
        for entry in self {
            let value = try SentenceBreakCode.rawValue(for: entry.value)
            for cp in entry.first...entry.last {
                out[Int(cp)] = value
            }
        }
        return out
    }
}

private extension String {
    func sbpTrimmed() -> String {
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
    func sbpRange(of needle: String) -> Range<String.Index>? {
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
