# Layer 19 — Web Frameworks

| Field | Value |
|---|---|
| **Phase** | 7 — Web Frameworks |
| **Effort** | 3–5 person-months |
| **Depends on** | [Layer 18](layer-18-http-stack.md), [Layer 24](layer-24-macros-codegen.md), [Layer 14](layer-14-serialization-framework.md), [Layer 12](layer-12-cryptography.md) (auth) |
| **Dependents** | downstream applications |

## Libraries

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| Tower-style | `axum`, `axum-core`, `axum-extra` | T3 | |
| Actor-style | `actix-web`, `actix-http`, `actix-server`, `actix-rt`, `actix-codec`, `actix-router`, `actix-service`, `actix-utils`, `actix-web-codegen`, `actix-macros`, `actix-multipart`, `actix-files`, `actix-cors`, `actix-session`, `actix-identity`, `actix-web-httpauth` | T3 | |
| Rocket | `rocket`, `rocket_codegen`, `rocket_contrib` | T3 | |
| Warp | `warp` | T2 | |
| Tide | `tide` | T2 | |
| Poem | `poem`, `poem-openapi` | T2 | |
| Salvo | `salvo` | T2 | |
| Loco | `loco-rs` | T3 | |
| Pavex | `pavex` | T3 | |
| Volga | `volga` | T2 | |
| ntex | `ntex` | T3 | |
| Trillium | `trillium` | T2 | |
| Async-graphql | `async-graphql` | T3 | |
| Templating | `tera`, `askama`, `handlebars`, `minijinja`, `liquid`, `ramhorns`, `maud`, `markup`, `sailfish`, `yarte` | T3 | |
| Static asset embed | `rust-embed`, `include_dir` | T1 | |
| Form handling | `serde_urlencoded`, `multer` | T1 | |
| Auth (JWT) | `jsonwebtoken`, `josekit`, `jwt-simple`, `biscuit` | T2 | |
| Auth (OAuth) | `oauth2`, `yup-oauth2`, `openidconnect`, `azure_identity` | T2 | |
| Auth (Sessions) | `actix-session`, `tower-sessions`, `axum-login` | T2 | |
| WebAuthn | `webauthn-rs` | T3 | |
| Captcha | `captcha-rs`, `mcaptcha` | T2 | |

---

[← Index](../README.md) · [Dependency graph](../DEPENDENCIES.md)
