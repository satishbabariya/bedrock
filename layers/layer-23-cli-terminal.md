# Layer 23 — CLI & Terminal

| Field | Value |
|---|---|
| **Phase** | 10 — Configuration & CLI |
| **Effort** | included in Phase 10 (3–6 person-months total) |
| **Depends on** | [Layer 24](layer-24-macros-codegen.md) (clap-style derive), [Layer 8](layer-08-filesystem-os.md), [Layer 9](layer-09-process-ipc.md), [Layer 1](layer-01-primitives.md) |
| **Dependents** | downstream tooling |

## Libraries

| Need | Rust crate(s) | Tier | Notes |
|---|---|---|---|
| Argument parsing | `clap`, `clap_builder`, `clap_derive`, `clap_lex`, `argh`, `gumdrop`, `pico-args`, `bpaf`, `lexopt`, `xflags` | T2 | |
| Subcommands | `clap`, `argh` | T2 | |
| Shell completions | `clap_complete`, `clap_mangen`, `clap_complete_fig` | T2 | |
| Manpage generation | `clap_mangen` | T1 | |
| Terminal colors | `termcolor`, `colored`, `nu-ansi-term`, `ansi_term`, `owo-colors`, `yansi`, `console` | T1 | |
| ANSI parsing | `anstyle`, `anstyle-parse`, `anstyle-query`, `anstream`, `colorchoice`, `is_terminal_polyfill`, `utf8parse`, `vte`, `strip-ansi-escapes` | T1 | |
| Terminal control | `crossterm`, `termion`, `console`, `terminal_size` | T2 | |
| Progress bars | `indicatif`, `pbr`, `progress` | T2 | |
| Spinners | `spinners`, `indicatif`, `cli-spinners` | T1 | |
| TUI framework | `ratatui`, `tui-rs`, `cursive`, `iocraft`, `dialoguer` | T3 | |
| Prompts | `dialoguer`, `inquire`, `requestty` | T2 | |
| Tables | `comfy-table`, `cli-table`, `prettytable`, `tabled` | T1 | |
| Diff display | `similar`, `dissimilar`, `difference`, `diffy` | T2 | |
| Hex dump | `hexyl`, `pretty-hex` | T1 | |
| Editor integration | `tui-input`, `rustyline`, `reedline`, `linefeed` | T3 | |
| Shell parsing | `shellwords`, `shlex`, `shell-words` | T1 | |
| Shell escape | `shell-escape` | T1 | |
| Cmd builder | `which`, `command-group`, `duct` | T1 | |
| Environment | `env_logger`, `envy` | T1 | |
| Help / docs | `clap`, `bpaf` | T2 | |
| Multi-progress | `indicatif::MultiProgress` | T2 | |
| Pager | `minus`, `less-rs`, `pager` | T2 | |
| Notifier (desktop) | `notify-rust`, `winrt-notification` | T2 | |
| Tree printing | `termtree`, `ptree` | T1 | |
| Self-update | `self_update`, `cargo-update` | T2 | |
| Config dirs | (see [Layer 8](layer-08-filesystem-os.md)) | | |
| ASCII art | `figlet-rs`, `colored` | T1 | |

---

[← Index](../README.md) · [Dependency graph](../DEPENDENCIES.md)
