extension UnicodeProperties {

    /// East Asian Width property (UAX #11). Used by terminal layout
    /// and CJK-aware string-width computation. Returns `.neutral` for
    /// codepoints not present in `EastAsianWidth.txt` (the documented
    /// default).
    public enum EastAsianWidth: UInt8, Sendable, Hashable, CaseIterable {
        case narrow      = 0   // Na
        case wide        = 1   // W
        case halfwidth   = 2   // H
        case fullwidth   = 3   // F
        case ambiguous   = 4   // A
        case neutral     = 5   // N (default)
    }
}
