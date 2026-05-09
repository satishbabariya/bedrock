# Layer 17 — Networking Protocols

| Field | Value |
|---|---|
| **Phase** | 6 — Networking |
| **Effort** | included in Phase 6 (6–10 person-months total) |
| **Depends on** | [Layer 11](layer-11-async-runtime.md), [Layer 13](layer-13-tls-pki.md), [Layer 1](layer-01-primitives.md) |
| **Dependents** | [Layer 18](layer-18-http-stack.md), [Layer 20](layer-20-databases-storage.md), [Layer 28](layer-28-cloud-distributed.md) |

## Libraries

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| Sockets | `socket2`, `mio` | T2 | |
| IP types | `ipnet`, `ipnetwork`, `cidr`, `ip_network` | T1 | |
| Network interface enumeration | `if-addrs`, `pnet`, `pcap` | T2 | |
| MAC address | `mac_address`, `eui48` | T1 | |
| DNS protocol | `hickory-proto`, `trust-dns-proto`, `domain` | T3 | |
| DNS resolver | `hickory-resolver`, `trust-dns-resolver`, `dns-lookup`, `async-resolver` | T3 | |
| resolv.conf | `resolv-conf` | T1 | |
| mDNS | `mdns-sd`, `astro-dnssd`, `searchlight` | T2 | |
| DHCP | `dhcp4r`, `dhcparse` | T2 | |
| FTP | `ftp`, `suppaftp`, `async-ftp` | T2 | |
| SSH client | `ssh2`, `russh`, `thrussh`, `osshkeys` | ❌/T4 | Bridge libssh2. |
| SSH key formats | `ssh-key`, `osshkeys` | T2 | |
| SFTP | `russh-sftp`, `ssh2` | T3 | |
| SMTP | `lettre`, `mail-send`, `samotop` | T2 | |
| IMAP | `imap`, `async-imap` | T3 | |
| POP3 | `pop3`, `async-pop` | T2 | |
| MIME / email parsing | `mail-parser`, `mailparse`, `email-encoding` | T2 | |
| WebSockets | `tokio-tungstenite`, `tungstenite`, `async-tungstenite`, `fastwebsockets`, `ws` | T2 | |
| TCP/UDP framing | `tokio-util` (codec) | T2 | |
| MQTT | `rumqttc`, `paho-mqtt`, `mqtt-protocol` | T2 | |
| AMQP / RabbitMQ | `lapin`, `amiquip` | T3 | |
| Kafka | `rdkafka`, `kafka-rust`, `rust-rdkafka`, `samsa` | ❌/T3 | Bridge librdkafka. |
| NATS | `async-nats`, `nats` | T2 | |
| Redis protocol | `redis`, `redis-protocol`, `fred`, `bb8-redis`, `deadpool-redis` | T2 | |
| Memcached | `memcache`, `async-memcached` | T2 | |
| ZeroMQ | `zmq`, `async-zmq` | ❌ | Bridge libzmq. |
| MsgPack-RPC | `rmp-rpc` | T2 | |
| JSON-RPC | `jsonrpsee`, `jsonrpc-core`, `jsonrpc-v2` | T2 | |
| OSC | `rosc` | T1 | |
| Modbus | `tokio-modbus`, `rmodbus` | T2 | |
| BLE / Bluetooth | `btleplug`, `bluer`, `bluest` | T3 | |
| Serial port | `serialport`, `tokio-serial`, `mio-serial` | T2 | |
| CoAP | `coap`, `coap-lite` | T2 | |
| RTP / RTCP | `webrtc-rtp`, `rtp-rs` | T3 | |
| STUN/TURN/ICE | `stun-rs`, `webrtc-rs` | T3 | |
| WebRTC | `webrtc-rs`, `str0m` | T4 | |
| QUIC | `quinn`, `quiche`, `s2n-quic`, `neqo` | T4 | |
| HTTP/3 | `h3`, `s2n-quic-h3`, `quiche` | T4 | |
| Network namespaces | `netns-rs`, `rtnetlink` | T3 | Linux. |
| Packet manipulation | `pnet`, `etherparse`, `pdu` | T3 | |
| Tun/Tap | `tun`, `tun-tap`, `wintun` | T3 | |
| Wireguard | `boringtun`, `wireguard-rs` | T4 | |
| Tor | `arti`, `tor-client` | T4 | |
| BitTorrent | `lava_torrent`, `librqbit` | T4 | |
| QUIC framing | `quinn-proto`, `quiche` | T3 | |
| TLS-PSK | `rustls` (via custom config) | T2 | |

---

[← Index](../README.md) · [Dependency graph](../DEPENDENCIES.md)
