# Layer 13 — TLS & PKI

| Field | Value |
|---|---|
| **Phase** | 4 — Crypto + TLS |
| **Effort** | included in Phase 4 (2–4 person-months total) |
| **Depends on** | [Layer 12](layer-12-cryptography.md), [Layer 11](layer-11-async-runtime.md), [Layer 14](layer-14-serialization-framework.md) (ASN.1/DER) |
| **Dependents** | [Layer 17](layer-17-networking-protocols.md), [Layer 18](layer-18-http-stack.md) |

## Libraries

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| TLS implementation | `rustls`, `native-tls`, `openssl`, `boring`, `s2n-tls`, `mbedtls` | T4 | Bridge BoringSSL. |
| TLS-over-async | `tokio-rustls`, `tokio-native-tls`, `async-tls`, `async-native-tls` | T1 | |
| Cert validation | `rustls-webpki`, `webpki` | T4 | Bridge a vetted impl. |
| Cert types | `rustls-pki-types` | T1 | |
| OS trust store | `rustls-native-certs`, `native-tls`, `system-configuration` | T2 | |
| PEM parsing | `pem`, `pem-rfc7468`, `rustls-pemfile` | T1 | |
| Mozilla root CA bundle | `webpki-roots`, `webpki-root-certs` | T1 | Just data. |
| ASN.1 / DER | `der`, `der_derive`, `asn1`, `asn1-rs`, `picky-asn1`, `rasn`, `simple_asn1` | T3 | |
| X.509 cert | `x509-cert`, `x509-parser`, `picky` | T3 | |
| PKCS encodings | `pkcs1`, `pkcs5`, `pkcs7`, `pkcs8`, `pkcs10`, `pkcs12`, `cms` | T2 | |
| SEC1 | `sec1` | T1 | |
| SPKI | `spki` | T1 | |
| OID | `const-oid`, `oid-registry` | T1 | |
| OCSP | `ocsp`, `rasn-ocsp` | T2 | |
| Certificate Transparency | `ct-log-parser` | T2 | |
| Certificate generation | `rcgen` | T2 | |
| ACME / Let's Encrypt | `acme-lib`, `acme-micro`, `instant-acme` | T2 | |
| QUIC | `quinn`, `quiche`, `s2n-quic`, `neqo` | T4 | |
| Noise protocol | `snow` | T2 | |

---

[← Index](../README.md) · [Dependency graph](../DEPENDENCIES.md)
