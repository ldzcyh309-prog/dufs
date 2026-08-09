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
| `cargo test` | Expected IPv6 test incompatibility: 2 failures in `tests/bind.rs`; remaining executed tests passed |
| `cargo clippy` | Pass with 3 warnings, no compilation error |
| `cargo build --release` | Pass |

`cargo test` failed only in `bind_ipv4_ipv6::case_1` and
`bind_ipv4_ipv6::case_3`. The test process could not bind `::1` and reported
`Cannot assign requested address (os error 99)`; the second failure timed out
waiting for the same IPv6 listener. The xhydebian host, Mihomo transparent
proxy, and household/lab network intentionally use an IPv4-only policy, so
these upstream IPv6-specific tests are expected to be incompatible with this
production environment. This is not a DUFS regression, host-network fault, or
production issue. IPv6 must not be enabled and upstream tests must not be
modified merely to make this result green.

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

## Phase 4 — Security configuration validation

Phase 4 used the production security configuration with a temporary SHA-512
crypt password and `--auth-method basic`, but supplied the temporary auth rule
only to a process bound to `127.0.0.1`. No production Compose service was
started and all temporary credentials, data, and logs were removed afterward.

| Check | Result |
| --- | --- |
| Unauthenticated request | HTTP 401 |
| Invalid credentials | HTTP 401 |
| Valid temporary admin read | HTTP 200 |
| Upload | HTTP 201 |
| Download/read | HTTP 200 |
| Search | HTTP 200 and expected result |
| Archive | HTTP 200, `application/zip` |
| Hash | HTTP 200 and SHA-256 matched |
| Delete test file | HTTP 204; subsequent read HTTP 404 |
| Symlink outside root | HTTP 404 |
| Hidden `.git` search | HTTP 200 search response with no `.git` entry |
| Health | HTTP 200, `{"status":"OK"}` |
| Log secret check | Pass: no Authorization header or temporary password |

The hidden-name test confirms DUFS's intended listing/search behavior; hidden
names are not treated as a substitute for access control.
