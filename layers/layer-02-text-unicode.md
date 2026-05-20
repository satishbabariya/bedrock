# Layer 2 — Text & Unicode

| Field | Value |
|---|---|
| **Phase** | 1 — Foundations |
| **Effort** | included in Phase 1 (3–6 person-months total) |
| **Depends on** | [Layer 1](layer-01-primitives.md) |
| **Dependents** | [Layer 5](layer-05-time-date.md), [Layer 15](layer-15-data-formats.md) |

Swift's `String` is Unicode-correct, but its underlying tables come from the OS's ICU. Without Foundation/ICU, you must ship the tables yourself.

> **Status:** shipping modules:
> - `Sources/UnicodeProperties/` — UCD-derived lookup against a two-stage trie. Properties available: general category (UAX #44), bidi class (UAX #9), canonical combining class, simple case mappings (uppercase/lowercase/titlecase). Codegen tool `bedrock-ucd-gen` emits one table per property ([2.1 design](../docs/superpowers/specs/2026-05-19-unicode-properties-design.md) · [2.1 plan](../docs/superpowers/plans/2026-05-19-unicode-properties-module.md) · [2.2 design](../docs/superpowers/specs/2026-05-20-bidi-class-and-ccc-design.md) · [2.2 plan](../docs/superpowers/plans/2026-05-20-bidi-class-and-ccc-module.md) · [2.3 design](../docs/superpowers/specs/2026-05-20-simple-case-mapping-design.md) · [2.3 plan](../docs/superpowers/plans/2026-05-20-simple-case-mapping-module.md)). Unicode 16.0.0.
>
> Subsequent sub-projects (Layer 2.4–2.8): normalization (NFC/NFD/NFKC/NFKD), segmentation (UAX #29), full case mapping (`SpecialCasing.txt`) + case folding (`CaseFolding.txt`), identifier classification (UAX #31), bidi algorithm (UAX #9), ASCII helpers.

## Libraries

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| Unicode normalization (NFC/NFD/NFKC/NFKD) | `unicode-normalization`, `icu_normalizer`, `icu_normalizer_data` | T3 | Tables. |
| Grapheme/word/sentence segmentation (UAX #29) | `unicode-segmentation`, `icu_segmenter` | T3 | Tables. |
| Bidirectional algorithm (UAX #9) | `unicode-bidi` | T3 | |
| East Asian width | `unicode-width` | T2 | |
| Identifier classification (UAX #31) | `unicode-ident`, `unicode-xid` | T1 | |
| General properties | `unicode-properties`, `icu_properties`, `icu_properties_data` | T3 | Tables. |
| Casefolding / case mapping | `caseless`, `unicode_categories`, `icu_casemap` | T2 | |
| Script detection | `whatlang`, `lingua` | T2 | |
| Locale tags / BCP 47 | `language-tags`, `icu_locale_core`, `oxilangtag` | T2 | |
| ICU4X (modular Unicode) | `icu`, `icu_collections`, `icu_provider`, `icu_collator`, `icu_calendar`, `icu_decimal`, `icu_datetime`, `icu_list`, `icu_plurals`, `icu_relativetime`, `tinystr`, `litemap`, `potential_utf`, `utf8_iter`, `writeable`, `yoke`, `zerofrom`, `zerotrie`, `zerovec` | T4 | Massive but modular. Port what you need. |
| Stringprep (RFC 3454) | `stringprep` | T1 | |
| Case-insensitive ASCII | `unicase`, `caseless` | T1 | |
| Confusables / IDN security | `unicode-security`, `confusable_detector` | T2 | |
| String similarity | `strsim`, `triple_accel`, `edit-distance` | T1 | |
| Fuzzy matching | `fuzzy-matcher`, `nucleo`, `fuzzy_search` | T2 | |
| Character set detection | `chardet`, `chardetng`, `encoding_rs` | T3 | |
| Legacy text encodings | `encoding_rs`, `encoding`, `iconv` | T3 | gb18030, Shift-JIS, EUC-KR, etc. Or bridge ICU. |

---

[← Index](../README.md) · [Dependency graph](../DEPENDENCIES.md)
