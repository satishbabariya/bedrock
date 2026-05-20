public struct CaseFoldingEntry: Equatable, Sendable {
    public enum Status: Character, Sendable {
        case common  = "C"
        case full    = "F"
        case simple  = "S"
        case turkic  = "T"
    }

    public let codepoint: UInt32
    public let status: Status
    public let mapping: [UInt32]

    public init(codepoint: UInt32, status: Status, mapping: [UInt32]) {
        self.codepoint = codepoint
        self.status = status
        self.mapping = mapping
    }
}

public enum CaseFoldingParseError: Error, Equatable {
    case truncatedLine(lineNumber: Int)
    case invalidCodepoint(lineNumber: Int, raw: String)
    case invalidStatus(lineNumber: Int, raw: String)
    case emptyMapping(lineNumber: Int)
}

public enum CaseFoldingParser {

    public static func parse(_ text: String) throws -> [CaseFoldingEntry] {
        var entries: [CaseFoldingEntry] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        for (i, lineSub) in lines.enumerated() {
            let lineNumber = i + 1
            var line = String(lineSub)
            if let hashIdx = line.firstIndex(of: "#") {
                line = String(line[..<hashIdx])
            }
            let trimmed = line.cfTrimmed()
            if trimmed.isEmpty { continue }

            let fields = trimmed.split(separator: ";", omittingEmptySubsequences: false)
            if fields.count < 3 {
                throw CaseFoldingParseError.truncatedLine(lineNumber: lineNumber)
            }
            let codepointField = String(fields[0]).cfTrimmed()
            let statusField    = String(fields[1]).cfTrimmed()
            let mappingField   = String(fields[2]).cfTrimmed()

            guard let codepoint = UInt32(codepointField, radix: 16) else {
                throw CaseFoldingParseError.invalidCodepoint(lineNumber: lineNumber,
                                                              raw: codepointField)
            }
            guard statusField.count == 1,
                  let statusChar = statusField.first,
                  let status = CaseFoldingEntry.Status(rawValue: statusChar) else {
                throw CaseFoldingParseError.invalidStatus(lineNumber: lineNumber,
                                                          raw: statusField)
            }
            if mappingField.isEmpty {
                throw CaseFoldingParseError.emptyMapping(lineNumber: lineNumber)
            }
            var mapping: [UInt32] = []
            for token in mappingField.split(separator: " ", omittingEmptySubsequences: true) {
                guard let cp = UInt32(token, radix: 16) else {
                    throw CaseFoldingParseError.invalidCodepoint(lineNumber: lineNumber,
                                                                  raw: String(token))
                }
                mapping.append(cp)
            }
            if mapping.isEmpty {
                throw CaseFoldingParseError.emptyMapping(lineNumber: lineNumber)
            }
            entries.append(CaseFoldingEntry(codepoint: codepoint,
                                             status: status,
                                             mapping: mapping))
        }
        return entries
    }
}

private extension String {
    func cfTrimmed() -> String {
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
}
