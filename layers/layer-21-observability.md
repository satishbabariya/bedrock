# Layer 21 — Observability

| Field | Value |
|---|---|
| **Phase** | 9 — Observability |
| **Effort** | 3–5 person-months |
| **Depends on** | [Layer 11](layer-11-async-runtime.md), [Layer 14](layer-14-serialization-framework.md), [Layer 1](layer-01-primitives.md), [Layer 7](layer-07-hashing.md) |
| **Dependents** | [Layer 28](layer-28-cloud-distributed.md) |

## Libraries

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| Logging façade | `log`, `slog` | T1 | |
| Logging implementation | `env_logger`, `pretty_env_logger`, `simplelog`, `flexi_logger`, `fern`, `log4rs`, `colog` | T2 | |
| Structured tracing | `tracing`, `tracing-attributes`, `tracing-core`, `tracing-log`, `tracing-serde`, `tracing-subscriber`, `tracing-futures`, `tracing-error`, `tracing-mutex`, `tracing-actix-web`, `tracing-appender` | T3 | |
| OpenTelemetry | `opentelemetry`, `opentelemetry_sdk`, `opentelemetry-otlp`, `opentelemetry-proto`, `opentelemetry-jaeger`, `opentelemetry-zipkin`, `opentelemetry-prometheus`, `opentelemetry-stdout`, `tracing-opentelemetry` | T3 | |
| Metrics façade | `metrics`, `metrics-util` | T1 | |
| Prometheus | `prometheus`, `metrics-exporter-prometheus`, `prometheus-client`, `actix-web-prom`, `axum-prometheus` | T2 | |
| Statsd | `cadence`, `metrics-exporter-statsd`, `dogstatsd` | T1 | |
| Quantile sketches | `sketches-ddsketch`, `tdigest`, `quantiles`, `hdrhistogram` | T1 | |
| Sentry | `sentry`, `sentry-core`, `sentry-types`, `sentry-backtrace`, `sentry-contexts`, `sentry-debug-images`, `sentry-panic`, `sentry-tracing`, `sentry-actix`, `sentry-tower` | T2 | |
| Backtrace | `backtrace`, `color-backtrace`, `human-panic` | T2 | Bridge libunwind. |
| Symbolication | `addr2line`, `gimli`, `findshlibs`, `symbolic-debuginfo` | T3 | |
| DWARF | `gimli`, `gimli-mock` | T3 | |
| Debug ID | `debugid` | T1 | |
| Profiling | `pprof`, `puffin`, `superluminal-perf`, `tracy-client`, `tracing-tracy`, `coz` | T3 | |
| Crash reporting | `minidump-writer`, `breakpad-handler`, `crash-handler` | T4 | |
| Continuous profiling | `pyroscope` | T2 | |
| Rate-limited logging | `log-derive`, `tracing-rate-limited` | T1 | |
| Console / tokio inspector | `console-subscriber`, `tokio-console` | T3 | |
| Status page / health | `health` | T1 | |
| eBPF | `aya`, `redbpf`, `libbpf-rs` | T4 | Linux-specific. |
| Audit logging | `audit-tip` | T1 | |

---

[← Index](../README.md) · [Dependency graph](../DEPENDENCIES.md)
