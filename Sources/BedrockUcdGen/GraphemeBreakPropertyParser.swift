public struct GraphemeBreakPropertyEntry: Equatable, Sendable {
    public let first: UInt32
    public let last: UInt32
    public let value: String   // "CR", "LF", "Control", "Extend", "ZWJ",
                                // "Regional_Indicator", "Prepend", "SpacingMark",
                                // "L", "V", "T", "LV", "LVT"

    public init(first: UInt32, last: UInt32, value: String) {
        self.first = first
        self.last  = last
        self.value = value
    }
}

public enum GraphemeBreakPropertyParseError: Error, Equatable {
    case truncatedLine(lineNumber: Int)
    case invalidCodepoint(lineNumber: Int, raw: String)
    case invalidRange(lineNumber: Int, raw: String)
    case emptyPropertyValue(lineNumber: Int)
}

public enum GraphemeBreakPropertyParser {

    public static func parse(_ text: String) throws -> [GraphemeBreakPropertyEntry] {
        var entries: [GraphemeBreakPropertyEntry] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        for (i, lineSub) in lines.enumerated() {
            let lineNumber = i + 1
            var line = String(lineSub)
            if let hashIdx = line.firstIndex(of: "#") {
                line = String(line[..<hashIdx])
            }
            let trimmed = line.gbpTrimmed()
            if trimmed.isEmpty { continue }

            let fields = trimmed.split(separator: ";", omittingEmptySubsequences: false)
            if fields.count < 2 {
                throw GraphemeBreakPropertyParseError.truncatedLine(lineNumber: lineNumber)
            }
            let rangeField = String(fields[0]).gbpTrimmed()
            let valueField = String(fields[1]).gbpTrimmed()

            if valueField.isEmpty {
                throw GraphemeBreakPropertyParseError.emptyPropertyValue(lineNumber: lineNumber)
            }

            let first: UInt32
            let last: UInt32
            if let dotRange = rangeField.gbpRange(of: "..") {
                let firstStr = String(rangeField[..<dotRange.lowerBound]).gbpTrimmed()
                let lastStr  = String(rangeField[dotRange.upperBound...]).gbpTrimmed()
                guard !firstStr.isEmpty, !lastStr.isEmpty,
                      let f = UInt32(firstStr, radix: 16),
                      let l = UInt32(lastStr,  radix: 16) else {
                    throw GraphemeBreakPropertyParseError.invalidRange(lineNumber: lineNumber,
                                                                       raw: rangeField)
                }
                first = f
                last  = l
            } else {
                guard let cp = UInt32(rangeField, radix: 16) else {
                    throw GraphemeBreakPropertyParseError.invalidCodepoint(lineNumber: lineNumber,
                                                                           raw: rangeField)
                }
                first = cp
                last  = cp
            }

            entries.append(GraphemeBreakPropertyEntry(first: first, last: last, value: valueField))
        }
        return entries
    }
}

public enum GraphemeClusterBreakCode {
    /// Map UCD Grapheme_Cluster_Break value to UInt8 raw value matching
    /// UnicodeProperties.GraphemeClusterBreak.
    public static func rawValue(for value: String) throws -> UInt8 {
        switch value {
        case "Other":              return 0
        case "CR":                 return 1
        case "LF":                 return 2
        case "Control":            return 3
        case "Extend":             return 4
        case "ZWJ":                return 5
        case "Regional_Indicator": return 6
        case "Prepend":            return 7
        case "SpacingMark":        return 8
        case "L":                  return 9
        case "V":                  return 10
        case "T":                  return 11
        case "LV":                 return 12
        case "LVT":                return 13
        default:
            throw GraphemeBreakPropertyParseError.invalidCodepoint(lineNumber: -1, raw: value)
        }
    }
}

public extension Array where Element == GraphemeBreakPropertyEntry {
    /// Returns a 0x110000-element array of UInt8 raw values (0–13).
    /// Default fill is 0 (Other) per the UCD `@missing` directive.
    func expandGraphemeClusterBreak() throws -> [UInt8] {
        var out = [UInt8](repeating: 0, count: 0x110000)
        for entry in self {
            let value = try GraphemeClusterBreakCode.rawValue(for: entry.value)
            for cp in entry.first...entry.last {
                out[Int(cp)] = value
            }
        }
        return out
    }
}

private extension String {
    func gbpTrimmed() -> String {
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
    func gbpRange(of needle: String) -> Range<String.Index>? {
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
