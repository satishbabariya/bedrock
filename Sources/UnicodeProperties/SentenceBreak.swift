extension UnicodeProperties {

    /// Sentence_Break property (UAX #29). Used by sentence-
    /// segmentation algorithms to find sentence boundaries.
    /// Returns `.other` for codepoints not explicitly listed in
    /// `SentenceBreakProperty.txt` (the UCD default per @missing).
    public enum SentenceBreak: UInt8, Sendable, Hashable, CaseIterable {
        case other     = 0    // XX (default — not in UCD file)
        case cr        = 1    // CR
        case lf        = 2    // LF
        case sep       = 3    // Sep
        case extend    = 4    // Extend
        case format    = 5    // Format
        case sp        = 6    // Sp
        case lower     = 7    // Lower
        case upper     = 8    // Upper
        case oLetter   = 9    // OLetter
        case numeric   = 10   // Numeric
        case aTerm     = 11   // ATerm
        case sTerm     = 12   // STerm
        case sContinue = 13   // SContinue
        case close     = 14   // Close
    }
}
