# Layer 5 — Time, Date, Calendars

| Field | Value |
|---|---|
| **Phase** | 1 — Foundations |
| **Effort** | included in Phase 1 (3–6 person-months total) |
| **Depends on** | [Layer 1](layer-01-primitives.md), [Layer 2](layer-02-text-unicode.md) (locale/format) |
| **Dependents** | [Layer 18](layer-18-http-stack.md) (HTTP date), [Layer 28](layer-28-cloud-distributed.md) (scheduling) |

## Libraries

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| Wall clock + duration | `chrono`, `time`, `jiff` | T3 | `jiff` is the modern best-designed option. |
| Monotonic clock | `instant`, `web-time`, `quanta`, `coarsetime` | T1 | Swift `ContinuousClock` exists. |
| TZ database | `chrono-tz`, `tzdb`, `tz-rs`, `iana-time-zone` | T3 | Need to ship/embed tzdata. |
| Cron expression | `cron`, `croner`, `cron_clock`, `saffron` | T2 | |
| Time intervals | `time-fmt`, `humantime`, `humantime-serde`, `parse_duration` | T1 | |
| Calendar arithmetic | `chronoutil`, `icu_calendar` | T2 | |
| Date format parsing | `dateparser`, `dtparse` | T2 | |
| ISO 8601 / RFC 3339 | `time` formats, `chrono` formats | T1 | |

---

[← Index](../README.md) · [Dependency graph](../DEPENDENCIES.md)
