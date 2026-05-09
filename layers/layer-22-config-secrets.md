# Layer 22 — Configuration & Secrets

| Field | Value |
|---|---|
| **Phase** | 10 — Configuration & CLI |
| **Effort** | included in Phase 10 (3–6 person-months total) |
| **Depends on** | [Layer 14](layer-14-serialization-framework.md), [Layer 8](layer-08-filesystem-os.md), [Layer 1](layer-01-primitives.md) |
| **Dependents** | downstream applications |

## Libraries

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| Layered config | `config`, `figment`, `confy`, `confique`, `twelf` | T2 | |
| Env vars | `dotenvy`, `dotenv`, `envy`, `envconfig` | T1 | |
| .env file | `dotenvy`, `dotenv` | T1 | |
| CLI from struct | (see [Layer 23](layer-23-cli-terminal.md) — `clap`) | | |
| Secrets handling | `secrecy`, `redact`, `vaultrs`, `rustify` | T2 | |
| HashiCorp Vault | `vaultrs`, `hashicorp_vault` | T2 | |
| AWS Secrets Manager | `aws-sdk-secretsmanager` | T2 | |
| Feature flags | `configcat`, `unleash-client-rust`, `featureprobe`, `flagd` | T2 | |
| Service discovery | `consul-rs`, `etcd-client` | T2 | |

---

[← Index](../README.md) · [Dependency graph](../DEPENDENCIES.md)
