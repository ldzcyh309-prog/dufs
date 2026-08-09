# DUFS Production V1.0 — Handoff

## Project goal

Maintain an upstream-synchronizable DUFS Fork and a separate, safe Docker
production deployment for the household/lab environment. Build in
`~/aiDev/workspaces`; run only in `~/dockerApps`.

## Completed phases and stop point

- Phase 0 — Discovery: complete.
- Phase 1 — GitHub Fork + Baseline: complete.
- Phase 2 — Upstream Baseline Build Validation: complete.
- Phase 3 — Production Skeleton: complete.
- Phase 4 — Security Configuration: complete.
- Current stop point: Phase 4 is complete. Do not start a production service.
- Next stage: Phase 5 — Custom UI V1.
- Phase 5 must not automatically enter Phase 6 — Custom Image.

## Git state

- Development repository: `/home/ldzcyh/aiDev/workspaces/dufs`.
- Branch: `custom/v1`.
- Session-closeout input HEAD and Phase 4 commit:
  `7abfe59a101c46eae484224efa6cc3a7d1dd5935`
  (`docs: define production security baseline`).
- Upstream baseline tag: `v0.1.0-upstream-baseline`.
- Upstream baseline commit:
  `fe7fd564f80dfbac361c8e0589c3845638149d38`.
- `origin`: `git@github.com:ldzcyh309-prog/dufs.git`.
- `upstream`: `https://github.com/sigoden/dufs.git`.
- `origin/main` matches `upstream/main` at the baseline commit; do not develop
  on `main`.
- `custom/v1` contains only project documentation and sanitized deployment
  templates so far; no DUFS Rust Core or UI behavior has been customized.

After this closeout document is committed, use `git rev-parse HEAD` and
`git status` as the authoritative current handoff state.

## Three-layer directory architecture

| Location | Responsibility |
| --- | --- |
| `/home/ldzcyh/aiDev/workspaces/dufs-project` | Project design and Codex execution-control documents |
| `/home/ldzcyh/aiDev/workspaces/dufs` | Fork, builds, tests, sanitized templates, documentation, and Git history |
| `/home/ldzcyh/dockerApps/dufs` | Runtime Compose, `.env`, config, assets, data, logs, backups, and scripts |

Never commit or copy runtime `.env`, real secrets, user data, logs, or backups
into the source repository.

## Toolchain and baseline validation

- Rust stable is installed through user-level rustup, including `rustc`,
  `cargo`, `rustfmt`, and `clippy`.
- `cargo fmt --check`: pass.
- `cargo clippy`: pass with three non-blocking upstream warnings.
- `cargo build --release`: pass; baseline binary is `dufs 0.46.0`.
- `cargo test`: upstream IPv6-only tests
  `bind_ipv4_ipv6::case_1` and `case_3` cannot bind `::1`.
- Host and official-Docker baseline smoke tests passed for homepage, health,
  and static-file serving. The retained local baseline image is
  `dufs:0.46.0-upstream-baseline-local`.

## Network policy

- DUFS Production V1.0 is intentionally IPv4 only.
- The household/lab network, xhydebian, and Mihomo transparent proxy disable
  IPv6 by production policy.
- Container bind: `0.0.0.0:5000`.
- Safe host publish: `127.0.0.1:5000`.
- Candidate port: `5000/tcp`; it was free at session closeout.
- The Phase 2 `::1` result is an expected upstream test incompatibility under
  the intentional IPv4-only environment. It is not a DUFS regression, a host
  network fault, or a production issue.
- Do not enable IPv6 or modify upstream tests to make those tests pass.

## Production skeleton and security state

- Runtime path: `/home/ldzcyh/dockerApps/dufs`.
- Compose project name: `dufs`.
- No formal DUFS production container has been started.
- The current local image setting is the Phase 2 baseline image for static
  Compose validation only; it is not the future Phase 6 production image.
- `.env` is `ldzcyh:ldzcyh`, mode 0600.
- `config/config.yaml` is `ldzcyh:ldzcyh`, mode 0640.
- `allow-all: false`.
- Global permissions: upload, delete, search, archive, and hash are true;
  symlink is false.
- Access-control design: one `admin` role with `/:rw`; no anonymous rule and
  no guest user.
- SHA-512 crypt password hashes are required and use DUFS Basic auth.
- The final administrator secret is intentionally not set. Runtime `.env`
  contains a safe sentinel, never a real password/hash.
- `doctor.sh` and `start.sh` reject a formal start until the final runtime-only
  admin hash replaces that sentinel.
- No real secret has been committed to Git.
- No production tag exists.

Phase 4 temporary loopback-only testing passed authentication, invalid-auth,
read/upload/download/search/archive/hash/delete, hidden-name search, symlink
blocking, health, and log-secret hygiene. Temporary data and credentials were
removed.

## Required prohibitions

- Do not modify Mihomo, its transparent proxy settings, or IPv4/IPv6 policy.
- Do not enable IPv6 for DUFS.
- Do not modify any other `/home/ldzcyh/dockerApps/*` project.
- Do not run `docker system prune`, `docker volume prune`, or `docker network
  prune`.
- Do not reconfigure GitHub CLI, SSH keys, or SSH configuration: GitHub CLI and
  SSH authentication have been verified working.
- Do not use `-A` or `--allow-all`.
- Do not set a final administrator password/hash without explicit user input.
- Do not create a production image, start production DUFS, or create a
  production tag before the corresponding later phases.

## Next-session checklist: Phase 5 — Custom UI V1

1. Read the two control documents in
   `/home/ldzcyh/aiDev/workspaces/dufs-project` and this `HANDOFF.md`.
2. In the source repository, run read-only `git status`, `git branch -vv`,
   `git log --oneline --decorate -8`, and `git remote -v`; confirm `custom/v1`
   is clean and `main` remains the upstream baseline.
3. Read `docs/ARCHITECTURE.md`, `docs/DEPLOYMENT.md`, `docs/SECURITY.md`,
   `docs/TESTING.md`, and `docs/DECISIONS.md` before changing assets.
4. Inspect upstream DUFS assets override support and existing UI assets. Prefer
   external assets, preserve DUFS core interactions and WebDAV compatibility,
   and do not modify Rust unless the documented Phase 10 conditions are met.
5. Keep the IPv4-only policy and do not start production Compose. Complete
   Phase 5 testing and documentation, commit its single-purpose changes, then
   stop for review; do not proceed automatically to Phase 6.
