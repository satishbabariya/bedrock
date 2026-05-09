# Layer 14 — Serialization Framework

| Field | Value |
|---|---|
| **Phase** | 5 — Serialization |
| **Effort** | included in Phase 5 (6–10 person-months total) |
| **Depends on** | [Layer 1](layer-01-primitives.md), [Layer 24](layer-24-macros-codegen.md) (derive macros) |
| **Dependents** | [Layer 13](layer-13-tls-pki.md), [Layer 15](layer-15-data-formats.md), [Layer 18](layer-18-http-stack.md), [Layer 19](layer-19-web-frameworks.md), [Layer 20](layer-20-databases-storage.md), [Layer 21](layer-21-observability.md), [Layer 22](layer-22-config-secrets.md), [Layer 25](layer-25-testing.md) |

## Libraries

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| Generic serialization | `serde`, `serde_core`, `serde_derive`, `miniserde`, `nanoserde`, `gros`, `deser-hjson` | T3 | Reframe on Swift macros. |
| Serde adapters | `serde_with`, `serde_with_macros`, `serde_repr`, `serde_bytes` | T2 | |
| Path-aware errors | `serde_path_to_error` | T1 | |
| Span-preserving | `serde_spanned` | T1 | |
| Trait-object serialization | `erased-serde`, `typetag`, `typetag-impl` | T2 | |
| Serde test helpers | `serde_test` | T1 | |
| Validation | `validator`, `garde`, `validify` | T2 | |
| JSON Schema generation | `schemars`, `schemars_derive`, `okapi`, `schemafy` | T2 | |
| OpenAPI generation | `utoipa`, `utoipa-gen`, `aide`, `okapi`, `paperclip`, `apistos` | T3 | High value with Swift macros. |
| OpenAPI client codegen | `progenitor`, `openapi-generator` | T3 | |
| Reflection | `reflect`, `bevy_reflect` | T3 | Swift Mirror is limited. |

---

[← Index](../README.md) · [Dependency graph](../DEPENDENCIES.md)
