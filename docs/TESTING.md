# Testing

## Phase 2 — Upstream Baseline Build Validation

Date: 2026-08-09 (Asia/Singapore)

The code under test is the upstream baseline `fe7fd56` (tag
`v0.1.0-upstream-baseline`). The `custom/v1` branch adds project
documentation only; no DUFS Rust source or product behavior was changed.

### Rust toolchain

Installed with the official user-level rustup installer using the default
profile. The active default toolchain is `stable-x86_64-unknown-linux-gnu`.

| Tool | Observed version |
| --- | --- |
| rustup | `1.29.0 (28d1352db 2026-03-05)` |
| rustc | `1.97.1 (8bab26f4f 2026-07-14)` |
| cargo | `1.97.1 (c980f4866 2026-06-30)` |
| rustfmt | `1.9.0-stable (8bab26f4f6 2026-07-14)` |
| clippy | `0.1.97 (8bab26f4f6 2026-07-14)` |

### Rust validation

| Command | Result |
| --- | --- |
| `cargo fmt --check` | Pass |
| `cargo test` | Baseline failure: 2 failures in `tests/bind.rs`; remaining executed tests passed |
| `cargo clippy` | Pass with 3 warnings, no compilation error |
| `cargo build --release` | Pass |

`cargo test` failed only in `bind_ipv4_ipv6::case_1` and
`bind_ipv4_ipv6::case_3`. The test process could not bind `::1` and reported
`Cannot assign requested address (os error 99)`; the second failure timed out
waiting for the same IPv6 listener. This is an execution-environment IPv6
availability issue observed against unmodified upstream, not a custom
regression. No upstream source was changed.

`cargo clippy` completed successfully and reported three
`clippy::useless_borrows_in_formatting` warnings in `src/args.rs` and
`src/server.rs`. They are warnings under the default policy, not compiler
errors; no source change was made to suppress them.

### Release binary

| Property | Result |
| --- | --- |
| Path | `target/release/dufs` |
| Mode | executable (`-rwxrwxr-x`) |
| Size | `6.2M` |
| Type | 64-bit x86-64 PIE ELF, dynamically linked, stripped |
| Version | `dufs 0.46.0` |
| Help | `dufs --help` completed successfully |

### Host runtime smoke test

The release binary was run from a freshly created `/tmp` test directory with
`--bind 127.0.0.1 --port 5000`. Before start, port 5000 was confirmed unused.

| Check | Result |
| --- | --- |
| `GET /` | HTTP 200 |
| `GET /__dufs__/health` | HTTP 200, `{"status":"OK"}` |
| `GET /baseline.txt` | HTTP 200 with expected test payload |

The process was stopped and its dedicated test directory and response files
were removed after the test.

### Official Dockerfile baseline

The repository's unmodified `Dockerfile` was built as:

```text
dufs:0.46.0-upstream-baseline-local
```

Image ID:

```text
sha256:f10c5de536011d70da11eecaacf89b8a3eb6b2bc5e0bffd479d8745722287b41
```

Docker emitted one non-fatal BuildKit warning about a constant
`FROM --platform=linux/amd64` flag. The image build succeeded.

A temporary `dufs-phase2-baseline-smoke` container ran with a read-only
temporary data mount and `127.0.0.1:5000:5000` mapping.

| Check | Result |
| --- | --- |
| Container start | Pass |
| Port mapping | `5000/tcp -> 127.0.0.1:5000` |
| `GET /__dufs__/health` | HTTP 200, `{"status":"OK"}` |
| `GET /` | HTTP 200 |
| `GET /baseline.txt` | HTTP 200 with expected test payload |

The temporary container was stopped and automatically removed. No Docker
system, volume, or network cleanup was performed; the tagged baseline image
is retained locally for traceability.
