# DUFS Production V1.0 — Handoff

## Current state

- Goal: maintainable DUFS Production V1.0 fork and Docker deployment.
- Completed phase: Phase 2 — Upstream Baseline Build Validation.
- Current phase: stopped after Phase 2 at the user's direction.
- Source repository: `/home/ldzcyh/aiDev/workspaces/dufs`.
- Production deployment path: `/home/ldzcyh/dockerApps/dufs` (not yet created).
- Branch: `custom/v1`.
- Current upstream baseline commit: `fe7fd56`.
- Current port candidate: `5000/tcp` (available during discovery).

## Established facts

- `origin` is `git@github.com:ldzcyh309-prog/dufs.git`.
- `upstream` is `https://github.com/sigoden/dufs.git`.
- `origin/main` currently matches `upstream/main` at `fe7fd56`.
- `custom/v1` is based on that baseline and currently contains the project
  documentation commit `bef120a` on top of it.
- Host GitHub CLI and SSH authentication are valid; do not run `gh auth login`
  or `ssh-keygen`.
- Rust/Cargo/rustfmt/clippy are installed through user-level rustup stable.
- Do not modify any unrelated Docker project or perform Docker global cleanup.

## Phase 2 result

- Rust stable was installed with user-level rustup default profile; details are
  recorded in `docs/TESTING.md`.
- `cargo fmt --check`, `cargo clippy`, and `cargo build --release` passed.
- `cargo test` has two baseline IPv6 bind failures because this execution
  environment cannot bind `::1` (`os error 99`). No upstream Rust code was
  changed.
- The release binary (`dufs 0.46.0`) passed host HTTP, health, and static-file
  smoke tests on 127.0.0.1:5000.
- Official Dockerfile baseline image:
  `dufs:0.46.0-upstream-baseline-local`
  (`sha256:f10c5de536011d70da11eecaacf89b8a3eb6b2bc5e0bffd479d8745722287b41`).
  Its temporary container smoke test passed.

## Next step

When authorized, start Phase 3 — Production Skeleton. Do not begin it
automatically.
