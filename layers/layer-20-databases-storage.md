# Layer 20 — Databases & Storage

| Field | Value |
|---|---|
| **Phase** | 8 — Databases |
| **Effort** | 8–14 person-months |
| **Depends on** | [Layer 11](layer-11-async-runtime.md), [Layer 17](layer-17-networking-protocols.md), [Layer 14](layer-14-serialization-framework.md), [Layer 18](layer-18-http-stack.md) (REST drivers), [Layer 16](layer-16-compression.md) |
| **Dependents** | [Layer 28](layer-28-cloud-distributed.md) (cloud datastores) |

## Libraries

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| SQL framework / ORM | `sqlx`, `diesel`, `sea-orm`, `rbatis`, `welds`, `ormx`, `sqlite3-builder` | T3 | |
| SQL query builder | `sea-query`, `sql-builder`, `quaint` | T2 | |
| SQLx adapters | `sqlx-core`, `sqlx-mysql`, `sqlx-postgres`, `sqlx-sqlite`, `sqlx-macros` | T3 | |
| Postgres protocol | `postgres-protocol`, `postgres-types` | T3 | |
| Postgres client | `tokio-postgres`, `postgres`, `postgres-native-tls` | T3 | |
| Postgres logical replication | `postgres-replication` | T2 | Pgoutput parser. |
| Postgres extensions | `pgrx`, `pgx`, `pg_escape` | T4 | |
| MySQL protocol | `mysql_async`, `mysql_common`, `mysql` | T3 | |
| MariaDB | (uses `mysql_async`) | T3 | |
| SQLite | `rusqlite`, `sqlite`, `libsqlite3-sys`, `sqlite-loadable`, `tokio-rusqlite` | ❌ | Bridge SQLite. |
| DuckDB | `duckdb`, `libduckdb-sys` | ❌ | Bridge libduckdb. |
| MS SQL Server | `tiberius`, `tds` | T3 | |
| Oracle | `oracle` | ❌ | Bridge OCI. |
| ClickHouse | `clickhouse`, `klickhouse`, `clickhouse-rs` | T2 | |
| Cassandra / ScyllaDB | `cdrs-tokio`, `scylla`, `cassandra-cpp` | T3 | |
| MongoDB | `mongodb`, `mongo-rust-driver` | T3 | |
| Redis | (see [Layer 17](layer-17-networking-protocols.md)) | | |
| Memcached | (see [Layer 17](layer-17-networking-protocols.md)) | | |
| etcd | `etcd-client`, `etcd-rs` | T2 | |
| Consul | `consul-rs` | T2 | |
| InfluxDB | `influxdb`, `influxdb2` | T2 | |
| TimescaleDB | (uses Postgres client) | | |
| QuestDB | `questdb-rs` | T2 | |
| TiKV | `tikv-client` | T3 | |
| FoundationDB | `foundationdb`, `foundationdb-sys` | ❌ | Bridge. |
| Neo4j | `neo4rs` | T2 | |
| ArangoDB | `aragog`, `arangors` | T2 | |
| RocksDB | `rocksdb`, `librocksdb-sys`, `rust-rocksdb` | ❌ | Bridge. |
| sled | `sled` | T4 | Pure-Rust embedded KV. |
| LMDB | `lmdb`, `heed`, `lmdb-rkv` | ❌ | Bridge. |
| ReDB | `redb` | T3 | Pure-Rust embedded KV. |
| Fjall | `fjall` | T3 | LSM-tree. |
| Connection pool (sync) | `r2d2`, `r2d2_postgres`, `r2d2_mysql`, `r2d2_sqlite`, `r2d2_redis`, `scheduled-thread-pool` | T2 | |
| Connection pool (async) | `bb8`, `deadpool`, `mobc` | T2 | |
| Migrations | `refinery`, `barrel`, `dbmigrate`, `sqlx-cli` | T2 | |
| Object storage abstraction | `opendal`, `object_store`, `rust-s3`, `aws-sdk-s3`, `azure_storage`, `google-cloud-storage` | T3 | |
| AWS SDK | `aws-sdk-*` (~300 service crates), `aws-config`, `aws-credential-types`, `aws-runtime`, `aws-smithy-*` | T3 | Codegen target. |
| GCP SDK | `google-cloud-*`, `tonic` (gRPC services) | T3 | |
| Azure SDK | `azure_*` | T3 | |
| Iceberg | `iceberg`, `iceberg-catalog-rest` | T4 | |
| Delta Lake | `deltalake` | T4 | |
| Hudi | `hudi-rs` | T4 | |
| Apache Avro | (see [Layer 15](layer-15-data-formats.md)) | | |
| BigQuery | `gcp-bigquery-client` | T2 | |
| ElasticSearch | `elasticsearch`, `elastic` | T2 | |
| OpenSearch | `opensearch` | T2 | |
| Time series (TDB) | `whisper-rs`, `seriesdb` | T3 | |
| Vector DB | `qdrant-client`, `milvus-sdk-rust`, `weaviate-community-client`, `pinecone-rs` | T2 | |
| Embedded full-text search | `tantivy`, `meilisearch-sdk`, `sonic-rs`, `bleve`-style | T4 | |
| Postgres in pure Rust | `pg-extend`, `gluesql` | T4 | |
| Spanner | `spanner-rs`, `google-cloud-spanner` | T2 | |
| DynamoDB | `aws-sdk-dynamodb`, `serde_dynamo` | T2 | |

---

[← Index](../README.md) · [Dependency graph](../DEPENDENCIES.md)
