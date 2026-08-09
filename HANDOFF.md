# DUFS Production V1.0 — Handoff

## Current state

- Goal: maintainable DUFS Production V1.0 fork and Docker deployment.
- Completed phase: Phase 4 — Security Configuration.
- Current phase: stopped after Phase 4 at the user's direction.
- Source repository: `/home/ldzcyh/aiDev/workspaces/dufs`.
- Production deployment path: `/home/ldzcyh/dockerApps/dufs` (skeleton created;
  no DUFS production service has been started).
- Branch: `custom/v1`.
- Phase 3 entry HEAD: `ff60df962a49a1909915908a6fb69ba9c62e82d7`
  (`docs: record upstream baseline validation`).
- Phase 2 commit: `ff60df962a49a1909915908a6fb69ba9c62e82d7`.
- Current upstream baseline commit: `fe7fd564f80dfbac361c8e0589c3845638149d38`.
- Current port candidate: `5000/tcp` (available during discovery).

## Established facts

- `origin` is `git@github.com:ldzcyh309-prog/dufs.git`.
- `upstream` is `https://github.com/sigoden/dufs.git`.
- `origin/main` currently matches `upstream/main` at `fe7fd56`.
- `custom/v1` is based on that baseline; at Phase 3 entry it is two
  documentation commits ahead: `bef120a7c6ca0c46ace99a42db8604ee40f328b2`
  (Phase 1) and `ff60df962a49a1909915908a6fb69ba9c62e82d7` (Phase 2 HEAD).
- Host GitHub CLI and SSH authentication are valid; do not run `gh auth login`
  or `ssh-keygen`.
- Rust/Cargo/rustfmt/clippy are installed through user-level rustup stable.
- Do not modify any unrelated Docker project or perform Docker global cleanup.

## Phase 2 result

- Rust stable was installed with user-level rustup default profile; details are
  recorded in `docs/TESTING.md`.
- `cargo fmt --check`, `cargo clippy`, and `cargo build --release` passed.
- `cargo test` has two expected upstream IPv6-test incompatibilities because
  the xhydebian/Mihomo/household-lab production policy intentionally disables
  IPv6 and cannot bind `::1` (`os error 99`). This is not a DUFS regression,
  host fault, or production issue; no upstream Rust code was changed.
- The release binary (`dufs 0.46.0`) passed host HTTP, health, and static-file
  smoke tests on 127.0.0.1:5000.
- Official Dockerfile baseline image:
  `dufs:0.46.0-upstream-baseline-local`
  (`sha256:f10c5de536011d70da11eecaacf89b8a3eb6b2bc5e0bffd479d8745722287b41`).
  Its temporary container smoke test passed.

## Next step

When authorized, start Phase 5 — Custom UI V1. Do not begin it
automatically.

## Phase 3 result

- Runtime-only production skeleton created at
  `/home/ldzcyh/dockerApps/dufs`; it is not part of this Git repository.
- Compose project is explicitly `dufs`, parameterized through `.env`, and
  defaults to `127.0.0.1:5000` host publishing with container IPv4
  `0.0.0.0:5000`.
- No account/password or broad permission was configured: `allow-all` and all
  mutation/search/archive/hash permissions are false pending Phase 4.
- `.env` is mode 0600 and currently refers only to the local Phase 2 baseline
  image for static Compose validation, not a future production image.
- `docker compose config`, script syntax validation, and read-only doctor
  passed. No DUFS production container was started and no other Docker project
  was changed.

## Phase 4 result

- Production network baseline is intentional IPv4-only: container
  `0.0.0.0:5000`, safe host publish `127.0.0.1:5000`, and IPv6 disabled by
  xhydebian/Mihomo/household-lab network policy. The Phase 2 `::1` failures
  are expected upstream IPv6-test incompatibilities, not production issues.
- One runtime-only SHA-512 Basic `admin` rule is required through `.env`; no
  real password or hash is committed. The current placeholder blocks start
  until the user supplies a final admin hash.
- `allow-all` and symlink traversal remain false; upload, delete, search,
  archive, and hash are globally enabled and constrained by admin `/:rw`.
- Temporary loopback-only tests passed for authentication, upload/download,
  search, archive, hash, delete, hidden search, symlink blocking, health, and
  log secret hygiene. No production container was started.
