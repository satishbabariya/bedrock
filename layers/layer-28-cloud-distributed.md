# Layer 28 — Cloud, Distributed, Specialized

| Field | Value |
|---|---|
| **Phase** | 14 — Specialized & Cloud |
| **Effort** | 4–10 person-months for core; graphics/ML/GUI are each multi-year |
| **Depends on** | [Layer 18](layer-18-http-stack.md), [Layer 20](layer-20-databases-storage.md), [Layer 21](layer-21-observability.md), [Layer 14](layer-14-serialization-framework.md), [Layer 11](layer-11-async-runtime.md) |
| **Dependents** | top of stack — application-layer concerns |

## Libraries

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| AWS SigV4 | `aws-sigv4`, `reqsign` | T2 | |
| GCP service-account auth | `yup-oauth2`, `gcp_auth` | T2 | |
| Azure auth | `azure_identity`, `azure_core` | T2 | |
| Kubernetes client | `kube`, `kube-client`, `kube-core`, `kube-derive`, `kube-runtime`, `k8s-openapi` | T3 | |
| Helm | `helm-client` | T3 | |
| Docker / OCI | `bollard`, `docker-api`, `oci-spec`, `oci-distribution` | T2 | |
| Containers (rootless) | `youki`, `runc-rs` | T4 | |
| OpenTelemetry collectors | (see [Layer 21](layer-21-observability.md)) | | |
| Distributed tracing | (see [Layer 21](layer-21-observability.md)) | | |
| Workflow engines | `temporalio-sdk-core`, `temporalio-sdk` | ❌ | FFI wrap. |
| Dapr | `dapr-rs` | T2 | |
| Service mesh sidecar | `linkerd2-proxy` | T4 | |
| Consensus (Raft) | `raft-rs`, `openraft`, `async-raft` | T4 | |
| Consensus (Paxos) | `paxos-rs` | T4 | |
| CRDTs | `automerge`, `yrs`, `diamond-types`, `loro`, `crdts` | T4 | |
| Vector clocks | `vclock` | T1 | |
| Event sourcing | `cqrs-es`, `eventstore` | T3 | |
| Saga pattern | `saga-pattern` | T2 | |
| Distributed locks | `distributed-lock`, `redlock` | T2 | |
| Leader election | `raft-rs`, `etcd-client` (lease) | T3 | |
| Service registry | `consul-rs`, `eureka-client` | T2 | |
| Job scheduling | `tokio-cron-scheduler`, `cron`, `clokwerk`, `delay_timer`, `apalis` | T2 | |
| Background workers | `apalis`, `sidekiq.rs`, `faktory`, `faktory-rs` | T2 | |
| Workflow / DAG | `dagrs`, `petgraph` | T2 | |
| Erlang/OTP-style supervisors | `bastion`, `riker` | T4 | |
| Actor framework | `actix`, `xtra`, `kameo`, `riker`, `bastion`, `coerce` | T3 | Swift actors are native. |
| Streaming / event processing | `arrow-flight`, `materialize`, `vector` | T4 | |
| Search / IR | `tantivy`, `meilisearch`, `quickwit` | T4 | |
| ML inference | `candle-core`, `tract`, `burn`, `dfdx`, `tch`, `ort`, `llama-cpp-2` | T4 | Often bridge C/C++. |
| Vector search | `qdrant-client`, `usearch`, `hora`, `instant-distance` | T3 | |
| Tokenizers (NLP) | `tokenizers`, `tiktoken-rs` | T2 | |
| Embeddings | `fastembed-rs`, `embed-anything` | T3 | |
| Crypto wallets | `coins-bip32`, `bip39`, `bdk`, `bitcoin` | T3 | |
| Blockchain | `ethers-rs`, `web3`, `solana-sdk`, `substrate` | T4 | |
| 2D graphics | `tiny-skia`, `cairo-rs`, `raqote`, `vello` | T3 | |
| 3D graphics | `wgpu`, `glow`, `gfx-rs`, `vulkano`, `bevy` | T4 | Bridge Vulkan/Metal. |
| Game engine | `bevy`, `macroquad`, `ggez`, `piston` | T4 | |
| Physics | `rapier`, `parry`, `nphysics` | T4 | |
| GUI | `egui`, `iced`, `dioxus`, `tauri`, `slint`, `xilem`, `gtk-rs`, `relm4`, `floem`, `fltk-rs` | T4 | |
| Notifications | `notify-rust` | T2 | |
| Hardware (USB) | `rusb`, `nusb`, `libusb` | ❌ | Bridge libusb. |
| Hardware (I2C/SPI/GPIO) | `embedded-hal`, `linux-embedded-hal`, `rppal` | T2 | |
| Robotics (ROS) | `r2r`, `ros2-rs`, `safe_drive` | T3 | |
| Bioinformatics | `bio`, `noodles`, `rust-htslib` | T4 | |
| Image processing | `image`, `imageproc`, `kornia-rs` | T3 | |
| Computer vision | `opencv`, `kornia-rs` | ❌ | Bridge OpenCV. |
| OCR | `leptess`, `tesseract` | ❌ | Bridge Tesseract. |
| Speech | `whisper-rs`, `vosk-rs` | ❌ | Bridge. |
| TTS | `tts`, `coqui-tts` | ❌ | Bridge. |
| Audio synthesis | `cpal`, `rodio`, `kira`, `fundsp`, `dasp` | T3 | |
| MIDI | `midir`, `midly` | T2 | |
| Game networking | `naia`, `quinn`, `webrtc-rs` | T3 | |

---

[← Index](../README.md) · [Dependency graph](../DEPENDENCIES.md)
