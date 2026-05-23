extension UnicodeProperties {

    /// Word_Break property (UAX #29). Used by word-segmentation
    /// algorithms to find word boundaries. Returns `.other` for
    /// codepoints not explicitly listed in `WordBreakProperty.txt`
    /// (the UCD default per @missing).
    public enum WordBreak: UInt8, Sendable, Hashable, CaseIterable {
        case other             = 0   // XX (default — not in UCD file)
        case cr                = 1   // CR
        case lf                = 2   // LF
        case newline           = 3   // Newline
        case extend            = 4   // Extend
        case zwj               = 5   // ZWJ
        case regionalIndicator = 6   // Regional_Indicator
        case format            = 7   // Format
        case katakana          = 8   // Katakana
        case hebrewLetter      = 9   // Hebrew_Letter
        case aLetter           = 10  // ALetter
        case singleQuote       = 11  // Single_Quote
        case doubleQuote       = 12  // Double_Quote
        case midNumLet         = 13  // MidNumLet
        case midLetter         = 14  // MidLetter
        case midNum            = 15  // MidNum
        case numeric           = 16  // Numeric
        case extendNumLet      = 17  // ExtendNumLet
        case wSegSpace         = 18  // WSegSpace
    }
}
