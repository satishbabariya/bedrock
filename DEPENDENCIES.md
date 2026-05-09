# Bedrock Dependency Graph

Inter-layer dependencies. Edges point **from a layer to its prerequisites** (i.e. `A → B` means *A depends on B*).

A static SVG render of the same graph lives at [`dependencies.svg`](dependencies.svg); regenerate with:

```
dot -Tsvg dependencies.dot -o dependencies.svg
```

---

## Mermaid (renders inline on GitHub)

```mermaid
graph TD
    classDef p1 fill:#e8f4ff,stroke:#1f6feb,color:#0a2540
    classDef p2 fill:#e8fff0,stroke:#1a7f37,color:#0a2540
    classDef p3 fill:#fff4d6,stroke:#bf8700,color:#0a2540
    classDef p4 fill:#fde2e2,stroke:#cf222e,color:#0a2540
    classDef p5 fill:#f3e8ff,stroke:#8250df,color:#0a2540
    classDef p6 fill:#e2f5ff,stroke:#0969da,color:#0a2540
    classDef p7 fill:#ffe2f0,stroke:#bf3989,color:#0a2540
    classDef p8 fill:#e8e8ff,stroke:#5a5aff,color:#0a2540
    classDef p9 fill:#ffead5,stroke:#a5670a,color:#0a2540
    classDef p10 fill:#d6ffe2,stroke:#0a7f3f,color:#0a2540
    classDef p11 fill:#ffd6d6,stroke:#a5310a,color:#0a2540
    classDef p12 fill:#d6efff,stroke:#0a4ea5,color:#0a2540
    classDef p13 fill:#f0d6ff,stroke:#5a0aa5,color:#0a2540
    classDef p14 fill:#ffe8b3,stroke:#7a5a0a,color:#0a2540

    L00["Layer 0<br/>Stdlib Gaps"]:::p1
    L01["Layer 1<br/>Primitives"]:::p1
    L02["Layer 2<br/>Text & Unicode"]:::p1
    L03["Layer 3<br/>Collections"]:::p1
    L04["Layer 4<br/>Numeric & Math"]:::p1
    L05["Layer 5<br/>Time & Date"]:::p1
    L06["Layer 6<br/>Random"]:::p1
    L07["Layer 7<br/>Hashing"]:::p1

    L08["Layer 8<br/>Filesystem & OS"]:::p2
    L09["Layer 9<br/>Process & IPC"]:::p2
    L10["Layer 10<br/>Concurrency"]:::p2

    L11["Layer 11<br/>Async Runtime"]:::p3

    L12["Layer 12<br/>Cryptography"]:::p4
    L13["Layer 13<br/>TLS & PKI"]:::p4

    L14["Layer 14<br/>Serialization"]:::p5
    L15["Layer 15<br/>Data Formats"]:::p5
    L16["Layer 16<br/>Compression"]:::p5

    L17["Layer 17<br/>Networking"]:::p6
    L18["Layer 18<br/>HTTP Stack"]:::p6

    L19["Layer 19<br/>Web Frameworks"]:::p7

    L20["Layer 20<br/>Databases"]:::p8

    L21["Layer 21<br/>Observability"]:::p9

    L22["Layer 22<br/>Config & Secrets"]:::p10
    L23["Layer 23<br/>CLI & Terminal"]:::p10

    L24["Layer 24<br/>Macros & Codegen"]:::p11

    L25["Layer 25<br/>Testing"]:::p12

    L26["Layer 26<br/>Compiler Infra"]:::p13
    L27["Layer 27<br/>WASM Tooling"]:::p13

    L28["Layer 28<br/>Cloud & Distributed"]:::p14

    L01 --> L00
    L02 --> L01
    L03 --> L00
    L03 --> L01
    L03 --> L07
    L04 --> L00
    L05 --> L01
    L05 --> L02
    L06 --> L00
    L07 --> L01

    L08 --> L01
    L09 --> L08
    L09 --> L10
    L10 --> L00

    L11 --> L01
    L11 --> L08
    L11 --> L10

    L12 --> L01
    L12 --> L04
    L12 --> L06
    L13 --> L12
    L13 --> L11
    L13 --> L14

    L14 --> L01
    L14 --> L24
    L15 --> L14
    L15 --> L01
    L15 --> L02
    L16 --> L01

    L17 --> L11
    L17 --> L13
    L17 --> L01
    L18 --> L17
    L18 --> L14
    L18 --> L16
    L18 --> L05
    L18 --> L01

    L19 --> L18
    L19 --> L24
    L19 --> L14
    L19 --> L12

    L20 --> L11
    L20 --> L17
    L20 --> L14
    L20 --> L18
    L20 --> L16

    L21 --> L11
    L21 --> L14
    L21 --> L01
    L21 --> L07

    L22 --> L14
    L22 --> L08
    L22 --> L01

    L23 --> L24
    L23 --> L08
    L23 --> L09
    L23 --> L01

    L24 --> L01

    L25 --> L24
    L25 --> L14
    L25 --> L01

    L26 --> L24
    L26 --> L01
    L26 --> L03

    L27 --> L26
    L27 --> L11

    L28 --> L18
    L28 --> L20
    L28 --> L21
    L28 --> L14
    L28 --> L11
```

---

## Edge Inventory

Each row: a layer and the prerequisites it builds upon.

| Layer | Depends on |
|---|---|
| Layer 0 | — |
| Layer 1 | L0 |
| Layer 2 | L1 |
| Layer 3 | L0, L1, L7 |
| Layer 4 | L0 |
| Layer 5 | L1, L2 |
| Layer 6 | L0 |
| Layer 7 | L1 |
| Layer 8 | L1 |
| Layer 9 | L8, L10 |
| Layer 10 | L0 |
| Layer 11 | L1, L8, L10 |
| Layer 12 | L1, L4, L6 |
| Layer 13 | L11, L12, L14 |
| Layer 14 | L1, L24 |
| Layer 15 | L1, L2, L14 |
| Layer 16 | L1 |
| Layer 17 | L1, L11, L13 |
| Layer 18 | L1, L5, L14, L16, L17 |
| Layer 19 | L12, L14, L18, L24 |
| Layer 20 | L11, L14, L16, L17, L18 |
| Layer 21 | L1, L7, L11, L14 |
| Layer 22 | L1, L8, L14 |
| Layer 23 | L1, L8, L9, L24 |
| Layer 24 | L1 |
| Layer 25 | L1, L14, L24 |
| Layer 26 | L1, L3, L24 |
| Layer 27 | L11, L26 |
| Layer 28 | L11, L14, L18, L20, L21 |

---

## Critical Path

The longest dependency chain in the graph (each link blocks the next):

`L0 → L1 → L8 → L11 → L13 → L17 → L18 → L20 → L28`

Translation: stdlib gaps → primitives → filesystem/OS → async reactor → TLS → networking protocols → HTTP → databases → cloud. **Layer 11 (Async Runtime) is the single biggest gating item** — every networking protocol and every database client downstream is blocked on it.

Other notable chains:

- `L0 → L1 → L24 → L14 → L19` — primitives → macros → serialization → web frameworks
- `L0 → L1 → L24 → L26 → L27` — primitives → macros → compiler infra → WASM
