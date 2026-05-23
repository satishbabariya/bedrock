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
