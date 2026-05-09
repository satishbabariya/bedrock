# Layer 15 — Data Formats

| Field | Value |
|---|---|
| **Phase** | 5 — Serialization |
| **Effort** | included in Phase 5 (6–10 person-months total) |
| **Depends on** | [Layer 14](layer-14-serialization-framework.md), [Layer 1](layer-01-primitives.md), [Layer 2](layer-02-text-unicode.md) |
| **Dependents** | [Layer 18](layer-18-http-stack.md), [Layer 20](layer-20-databases-storage.md), [Layer 28](layer-28-cloud-distributed.md) |

## Libraries

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| JSON | `serde_json`, `simd-json`, `sonic-rs`, `json`, `tinyjson`, `jzon` | T2 | |
| JSON Patch (RFC 6902) | `json-patch` | T1 | |
| JSON Pointer (RFC 6901) | `jsonptr`, `serde_json_path` | T1 | |
| JSONPath | `jsonpath-rust`, `jsonpath_lib`, `jsonpath-plus`, `jsonpath` | T2 | |
| JSON5 | `json5`, `serde_json5` | T2 | |
| YAML 1.1 | `serde_yaml` (deprecated), `yaml-rust` | T2 | |
| YAML 1.2 | `yaml-rust2`, `serde_yml`, `serde_yaml_ng`, `saphyr` | T2 | |
| TOML | `toml`, `toml_edit`, `basic-toml` | T2 | |
| TOML internals | `toml_datetime`, `toml_parser`, `toml_write`, `toml_writer`, `winnow-toml` | T1 | |
| RON | `ron`, `serde_ron` | T1 | |
| HJSON | `deser-hjson`, `serde-hjson` | T1 | |
| INI | `rust-ini`, `ini`, `configparser`, `tini` | T1 | |
| XML | `quick-xml`, `xml-rs`, `roxmltree`, `xmltree`, `serde-xml-rs`, `yaserde`, `xot` | T2 | |
| HTML parser | `html5ever`, `scraper`, `select`, `kuchiki`, `tl`, `html_parser` | T3 | |
| CommonMark / Markdown | `pulldown-cmark`, `markdown`, `comrak`, `cmark-gfm`, `mdast-rs` | T3 | |
| reStructuredText | `restruct` | T2 | |
| AsciiDoc | `asciidoc-rs` | T3 | |
| LaTeX | `texrender`, `latex2mathml` | T3 | |
| MessagePack | `rmp`, `rmp-serde`, `messagepack-rs` | T2 | |
| CBOR | `ciborium`, `serde_cbor`, `minicbor`, `cbor4ii` | T2 | |
| BSON | `bson`, `bson2` | T2 | |
| Bincode | `bincode`, `bincode-derive` | T2 | |
| Postcard | `postcard`, `postcard-rpc` | T1 | |
| Borsh | `borsh`, `borsh-derive` | T2 | |
| Pot | `pot` | T2 | |
| Speedy | `speedy`, `speedy-derive` | T2 | |
| rkyv (zero-copy) | `rkyv`, `rkyv_derive`, `rend`, `bytecheck`, `ptr_meta` | T4 | Layout-tricky. |
| Cap'n Proto | `capnp`, `capnp-rpc` | T3 | |
| FlatBuffers | `flatbuffers`, `planus` | T3 | |
| Protobuf | `prost`, `prost-derive`, `prost-build`, `prost-types`, `pbjson`, `quick-protobuf`, `protobuf`, `rust-protobuf` | T3 | |
| Avro | `apache-avro`, `avro-rs`, `avrow` | T2 | |
| Parquet | `parquet`, `parquet2` | T4 | Major. |
| Arrow | `arrow`, `arrow2`, `arrow-array`, `arrow-buffer`, `arrow-schema`, `arrow-cast`, `arrow-data`, `arrow-arith`, `arrow-csv`, `arrow-ipc`, `arrow-json`, `arrow-ord`, `arrow-row`, `arrow-select`, `arrow-string` | T4 | |
| ORC | `orc-rust`, `datafusion-orc` | T4 | |
| Thrift | `thrift` | T3 | |
| ASN.1 BER/DER | (see [Layer 13](layer-13-tls-pki.md)) | | |
| CSV | `csv`, `csv-core`, `csv-async` | T2 | |
| TSV / DSV | `csv` | T1 | |
| Excel (xlsx) | `calamine`, `umya-spreadsheet`, `rust_xlsxwriter`, `xlsx-write` | T3 | |
| ODS / Open Document | `calamine` | T2 | |
| PDF | `lopdf`, `printpdf`, `pdf-extract`, `genpdf`, `pdfium-render` | T3 | |
| EPUB | `epub`, `epub-builder` | T2 | |
| PostScript | `printpdf` | T2 | |
| SVG | `svg`, `usvg`, `resvg`, `svgtypes`, `roxmltree` | T3 | |
| Image (PNG/JPEG/etc) | `image`, `imagequant`, `kornia-rs`, `oxipng`, `mozjpeg`, `webp`, `avif`, `imageproc` | T3 | |
| Color | `palette`, `color-art`, `csscolorparser` | T2 | |
| Audio formats | `symphonia`, `hound`, `claxon`, `lewton`, `mp3`, `minimp3`, `ogg` | T3 | |
| Video formats | `ffmpeg-next`, `gstreamer-rs` | ❌ | Bridge ffmpeg. |
| Geographic | `geojson`, `gpx`, `kml`, `shapefile`, `osm-pbf` | T2 | |
| RDF / Semantic Web | `oxrdf`, `oxigraph`, `sophia` | T3 | |
| GraphQL | `async-graphql`, `juniper`, `cynic` | T3 | |
| gRPC reflection | `tonic-reflection` | T2 | |
| 3D / mesh | `gltf`, `obj`, `ply-rs`, `fbx` | T3 | |
| Crypto formats | `pem`, `pkcs8`, `ssh-key`, `osshkeys` | T2 | |

---

[← Index](../README.md) · [Dependency graph](../DEPENDENCIES.md)
