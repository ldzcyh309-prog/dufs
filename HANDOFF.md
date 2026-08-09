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
- Phase 5 — Custom UI V1: complete.
- Phase 6 — Custom Image: complete.
- 当前停点：Phase 6 已完成，等待审核；不得启动正式 production service。
- 下一阶段：仅在明确授权后进入 Phase 7 — Production Compose Deployment。

## Git state

- Development repository: `/home/ldzcyh/aiDev/workspaces/dufs`.
- Branch: `custom/v1`.
- Phase 5 entry HEAD: `712dcb718347f1f83c09a2a0e941d595361326b6`
  (`docs: finalize phase4 handoff`).
- Upstream baseline tag: `v0.1.0-upstream-baseline`.
- Upstream baseline commit:
  `fe7fd564f80dfbac361c8e0589c3845638149d38`.
- `origin`: `git@github.com:ldzcyh309-prog/dufs.git`.
- `upstream`: `https://github.com/sigoden/dufs.git`.
- `origin/main` matches `upstream/main` at the baseline commit; do not develop
  on `main`.
- `custom/v1` now contains the Phase 5 official-assets UI override and
  supporting deployment/documentation changes. Rust Core remains unchanged.

## Phase 6 镜像状态

- Dockerfile：`/home/ldzcyh/aiDev/workspaces/dufs/Dockerfile.custom`；官方
  `Dockerfile` 未修改。
- 上游版本：`0.46.0`，来自 `Cargo.toml`；镜像构建修订为 Custom UI V1 提交
  `153a36fee65515f9f2493c92b9578db12605aeb8`。
- 不可变风格本地 tag：`dufs:0.46.0-custom-v1-153a36f`；便利 alias：
  `dufs:0.46.0-custom-v1`。不会推送任何外部 registry。
- 镜像 ID：`sha256:a9245966724483d5097530acbbff6f14ea5b77a4a2da0ccf93e06dd274c4431d`；
  `linux/amd64`、scratch runtime、ENTRYPOINT `[/bin/dufs]`。
- 最终镜像包含 `/bin/dufs` 和 `/assets/`。`/assets/` 从
  `custom/assets/` 烘焙，运行时
  `/home/ldzcyh/dockerApps/dufs/assets:/assets:ro` 可覆盖它。
- OCI labels 已验证：title、version、revision、source、description。
- 运行时 `.env` 的 `DUFS_IMAGE` 已更新为不可变风格 tag；管理员 sentinel
  未修改，`.env` 仍为 0600。
- 两组临时 IPv4 loopback 测试均通过：无外置挂载的 baked UI 与 runtime
  assets override；认证、health、浏览、上传/下载、WebDAV PROPFIND、favicon
  和 symlink blocking 均无回归。临时容器、凭据与数据已清除。
- 正式 production container 仍未启动；不要自动进入 Phase 7。

## 项目语言规范

从 Phase 6 起，本项目新增或实际修改的自定义代码注释、运维脚本说明和项目
文档正文统一使用中文。上游原始源码及其英文注释保持原样，避免制造无关的
upstream diff。技术标识、协议名、配置键、API 路径、Docker 标签键和命令
保持官方英文名称。

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

## Phase 5 UI state

- Official source assets: repository `assets/` at the pinned baseline.
- Custom assets: `/home/ldzcyh/aiDev/workspaces/dufs/custom/assets`.
- Runtime assets: `/home/ldzcyh/dockerApps/dufs/assets`, mounted read-only.
- Compose and its sanitized example pass `--assets /assets`.
- UI V1 uses native HTML/CSS/JavaScript only: Chinese primary UI text, a
  `DUFS 文件空间` title, a custom SVG favicon, and responsive phone layout.
- At 390×844 and 430×932, long names ellipsize and controls wrap inside the
  actions column; no horizontal page overflow was observed.
- Temporary IPv4-loopback testing passed browse, authentication, upload,
  download, search, MKCOL, delete, archive, SHA-256 hash, WebDAV PROPFIND,
  health, favicon delivery, JavaScript syntax, and Compose static rendering.
- No formal production container was started; final admin secret remains the
  runtime sentinel.

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

## 下一会话清单：审核后再决定是否进入 Phase 7

1. Read the two control documents in
   `/home/ldzcyh/aiDev/workspaces/dufs-project` and this `HANDOFF.md`.
2. In the source repository, run read-only `git status`, `git branch -vv`,
   `git log --oneline --decorate -8`, and `git remote -v`; confirm `custom/v1`
   is clean and `main` remains the upstream baseline.
3. 阅读 `docs/IMAGE_BUILD.md`、`docs/ARCHITECTURE.md`、`docs/DEPLOYMENT.md`、
   `docs/SECURITY.md`、`docs/TESTING.md` 与 `docs/DECISIONS.md`。
4. 复核 `docker image inspect dufs:0.46.0-custom-v1-153a36f`、runtime
   `.env` 的镜像引用和 `docker compose config`；不得修改管理员 sentinel。
5. 保持 IPv4-only 策略，不启动 production Compose。Phase 6 已关闭，等待
   审核；未经明确授权不得进入 Phase 7。
