public struct EastAsianWidthEntry: Equatable, Sendable {
    public let first: UInt32
    public let last: UInt32
    public let value: String   // "A", "F", "H", "N", "Na", "W"

    public init(first: UInt32, last: UInt32, value: String) {
        self.first = first
        self.last  = last
        self.value = value
    }
}

public enum EastAsianWidthParseError: Error, Equatable {
    case truncatedLine(lineNumber: Int)
    case invalidCodepoint(lineNumber: Int, raw: String)
    case invalidRange(lineNumber: Int, raw: String)
    case emptyPropertyValue(lineNumber: Int)
}

public enum EastAsianWidthParser {

    public static func parse(_ text: String) throws -> [EastAsianWidthEntry] {
        var entries: [EastAsianWidthEntry] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        for (i, lineSub) in lines.enumerated() {
            let lineNumber = i + 1
            var line = String(lineSub)
            if let hashIdx = line.firstIndex(of: "#") {
                line = String(line[..<hashIdx])
            }
            let trimmed = line.eawTrimmed()
            if trimmed.isEmpty { continue }

            let fields = trimmed.split(separator: ";", omittingEmptySubsequences: false)
            if fields.count < 2 {
                throw EastAsianWidthParseError.truncatedLine(lineNumber: lineNumber)
            }
            let rangeField = String(fields[0]).eawTrimmed()
            let valueField = String(fields[1]).eawTrimmed()

            if valueField.isEmpty {
                throw EastAsianWidthParseError.emptyPropertyValue(lineNumber: lineNumber)
            }

            let first: UInt32
            let last: UInt32
            if let dotRange = rangeField.eawRange(of: "..") {
                let firstStr = String(rangeField[..<dotRange.lowerBound]).eawTrimmed()
                let lastStr  = String(rangeField[dotRange.upperBound...]).eawTrimmed()
                guard !firstStr.isEmpty, !lastStr.isEmpty,
                      let f = UInt32(firstStr, radix: 16),
                      let l = UInt32(lastStr,  radix: 16) else {
                    throw EastAsianWidthParseError.invalidRange(lineNumber: lineNumber,
                                                                raw: rangeField)
                }
                first = f
                last  = l
            } else {
                guard let cp = UInt32(rangeField, radix: 16) else {
                    throw EastAsianWidthParseError.invalidCodepoint(lineNumber: lineNumber,
                                                                    raw: rangeField)
                }
                first = cp
                last  = cp
            }

            entries.append(EastAsianWidthEntry(first: first, last: last, value: valueField))
        }
        return entries
    }
}

public enum EastAsianWidthCode {
    /// Map UCD EAW code to UInt8 raw value matching UnicodeProperties.EastAsianWidth.
    public static func rawValue(for code: String) throws -> UInt8 {
        switch code {
        case "Na": return 0
        case "W":  return 1
        case "H":  return 2
        case "F":  return 3
        case "A":  return 4
        case "N":  return 5
        default:
            throw EastAsianWidthParseError.invalidCodepoint(lineNumber: -1, raw: code)
        }
    }
}

public extension Array where Element == EastAsianWidthEntry {
    /// Returns a 0x110000-element array of UInt8 raw values (0–5).
    /// Default fill is 5 (N = Neutral) per the UCD file header.
    func expandEastAsianWidth() throws -> [UInt8] {
        var out = [UInt8](repeating: 5, count: 0x110000)
        for entry in self {
            let value = try EastAsianWidthCode.rawValue(for: entry.value)
            for cp in entry.first...entry.last {
                out[Int(cp)] = value
            }
        }
        return out
    }
}

private extension String {
    func eawTrimmed() -> String {
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
    func eawRange(of needle: String) -> Range<String.Index>? {
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
