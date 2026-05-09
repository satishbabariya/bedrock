# Layer 18 — HTTP Stack

| Field | Value |
|---|---|
| **Phase** | 6 — Networking |
| **Effort** | included in Phase 6 (6–10 person-months total) |
| **Depends on** | [Layer 17](layer-17-networking-protocols.md), [Layer 14](layer-14-serialization-framework.md), [Layer 16](layer-16-compression.md), [Layer 5](layer-05-time-date.md), [Layer 1](layer-01-primitives.md) |
| **Dependents** | [Layer 19](layer-19-web-frameworks.md), [Layer 20](layer-20-databases-storage.md) (REST drivers), [Layer 28](layer-28-cloud-distributed.md) (cloud SDKs) |

## Libraries

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| HTTP types | `http`, `http-body`, `http-body-util` | T1 | |
| HTTP/1 parser | `httparse` | T2 | |
| HTTP date | `httpdate` | T1 | |
| HTTP/1+2 server/client | `hyper`, `hyper-util` | T3 | |
| HTTP/2 | `h2`, `nghttp2` | T3 | HPACK + state machine. |
| HTTP/3 | `h3`, `quiche` | T4 | |
| TLS-on-HTTP | `hyper-tls`, `hyper-rustls`, `hyper-openssl` | T1 | |
| Proxy support | `hyper-http-proxy`, `hyper-proxy` | T2 | |
| HTTP timeouts | `hyper-timeout` | T1 | |
| HTTP middleware | `tower`, `tower-http`, `tower-layer`, `tower-service` | T2 | |
| URL router | `matchit`, `route-recognizer`, `path-tree`, `pathmatcher` | T2 | |
| Strongly-typed headers | `headers`, `headers-core`, `accept-language` | T2 | |
| MIME types | `mime`, `mime_guess`, `infer` | T1 | |
| Content negotiation | `accept-language`, `mediatype` | T1 | |
| HTTP client high-level | `reqwest`, `ureq`, `isahc`, `surf`, `awc`, `attohttpc`, `minreq` | T3 | |
| HTTP signatures | `http-signature-normalization`, `httpsig` | T2 | |
| Cookies | `cookie`, `cookie_store` | T2 | |
| HTTP caching | `http-cache`, `http-cache-semantics` | T2 | |
| HTTP mocking | `wiremock`, `mockito`, `httpmock` | T2 | |
| Server-Sent Events | `sse-codec`, `eventsource-stream`, `actix-web-lab` | T1 | |
| Multipart | `multer`, `multipart-rs`, `actix-multipart` | T2 | |
| Form parsing | `serde_urlencoded`, `multer` | T1 | |
| Rate limiting | `governor`, `tower-governor` | T1 | |
| OpenAPI | (see [Layer 14](layer-14-serialization-framework.md)) | | |
| HTTP signing (AWS SigV4) | `aws-sigv4`, `reqsign`, `aws-sign-v4` | T2 | |
| GraphQL HTTP | `async-graphql-actix-web`, `juniper_actix` | T2 | |
| Webhook framework | `octocrab`, `webhook` | T2 | |

---

[← Index](../README.md) · [Dependency graph](../DEPENDENCIES.md)
