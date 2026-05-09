# Layer 3 — Collections & Data Structures

| Field | Value |
|---|---|
| **Phase** | 1 — Foundations |
| **Effort** | included in Phase 1 (3–6 person-months total) |
| **Depends on** | [Layer 0](layer-00-stdlib-gaps.md), [Layer 1](layer-01-primitives.md), [Layer 7](layer-07-hashing.md) |
| **Dependents** | broad — used across most upper layers |

Swift's stdlib has `Array`, `Dictionary`, `Set`. swift-collections adds `Deque`, `OrderedSet`, `OrderedDictionary`. Bare Swift needs all of this and more.

## Libraries

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| SwissTable hashmap | `hashbrown` | T3 | Or use Swift `Dictionary`. |
| Order-preserving hashmap | `indexmap`, `linked-hash-map`, `linked_hash_set` | T2 | swift-collections has `OrderedDictionary`. |
| BTree map/set | (Rust stdlib) | T2 | Swift stdlib lacks; swift-collections has `TreeDictionary`. |
| Multimap | `multimap`, `multi_index_map`, `ordered-multimap` | T1 | |
| Bidirectional map | `bimap`, `bimap-rs` | T1 | |
| Concurrent hashmap | `dashmap`, `chashmap`, `flurry`, `scc` | T3 | Subtle correctness; Swift actors usually suffice. |
| LRU cache | `lru`, `clru`, `lru-cache` | T1 | |
| TinyLFU / W-TinyLFU cache | `moka`, `mini-moka` | T3 | High value over plain LRU. |
| ARC cache | `caches` | T2 | |
| Inline-storage vector | `smallvec`, `tinyvec`, `arrayvec`, `staticvec` | T2 | Swift lacks a great equivalent. |
| Bounded deque | `arraydeque`, `circular-buffer` | T1 | |
| Generational arena | `slab`, `slotmap`, `id-arena`, `generational-arena`, `thunderdome` | T1 | Compiler bread-and-butter. |
| Bump allocator | `bumpalo`, `typed-arena` | T1 | |
| Concurrent slab | `sharded-slab` | T3 | |
| Linked list (intrusive) | `intrusive-collections` | T3 | Swift has classes for this. |
| Doubly-linked list | `dlv-list`, `linked-list` | T1 | |
| Priority queue | `priority-queue`, `keyed_priority_queue`, `binary-heap-plus`, `min-max-heap` | T1 | |
| Skip list | `skiplist`, `crossbeam-skiplist` | T2 | |
| Trie | `radix_trie`, `qp-trie`, `patricia_tree`, `art-tree`, `fst` | T2 | |
| Roaring bitmap | `roaring`, `croaring` | T2 | Compressed bitsets. |
| Bloom filter | `bloomfilter`, `bloom`, `growable-bloom-filter` | T1 | |
| Cuckoo filter | `cuckoofilter` | T2 | |
| HyperLogLog | `hyperloglog`, `hyperloglogplus`, `streaming_algorithms` | T2 | |
| Count-min sketch | `count_min_sketch` | T1 | |
| Disjoint-set / union-find | `disjoint-sets`, `union-find` | T1 | |
| Graph | `petgraph`, `daggy`, `dot`, `graphlib` | T2 | |
| Interval tree | `intervaltree`, `rust_lapper` | T2 | |
| R-tree / spatial index | `rstar`, `spade`, `kdtree` | T3 | |
| Persistent / immutable | `im`, `rpds`, `archery` | T3 | |
| Vec of options (compact) | `dense-vec` | T1 | |
| Append-only growable | `boxcar`, `growable-bloom-filter` | T2 | |
| Range/interval set | `iset`, `range-collections`, `rangemap` | T2 | |

---

[← Index](../README.md) · [Dependency graph](../DEPENDENCIES.md)
