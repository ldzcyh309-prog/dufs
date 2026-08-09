# Architecture

DUFS Production V1.0 separates planning, building, and running.

| Location | Responsibility |
| --- | --- |
| `/home/ldzcyh/aiDev/workspaces/dufs-project` | Project design and execution control documents |
| `/home/ldzcyh/aiDev/workspaces/dufs` | Upstream Fork, custom branch, builds, tests, templates, and documentation |
| `/home/ldzcyh/dockerApps/dufs` | Runtime Compose files, local environment, data, logs, backups, and scripts |

The Git repository contains only sanitized deployment examples. The runtime
directory is deliberately outside that repository so that production `.env`,
secrets, data, logs, and backups cannot be committed accidentally.

DUFS uses an explicit Compose project name, `dufs`. The xhydebian host, Mihomo
transparent proxy, and household/lab network intentionally use IPv4 only:
DUFS listens on `0.0.0.0:5000` in the container while the host publishes
`127.0.0.1:5000`. IPv6 is disabled by production network policy. Any broader
exposure is deferred to later explicit deployment approval. Phase 4 adds a
runtime-only admin secret structure; no authentication secret is stored in the
source repository.

## Phase 5 UI override

Phase 5 adds `custom/assets/`, a complete, version-pinned copy of the official
`assets/` directory from baseline commit `fe7fd56`. This is DUFS's documented
`--assets` override mechanism: at runtime the Compose command passes
`--assets /assets`, and the separate runtime directory mounts its `/assets`
read-only. No Rust source, request routing, authentication, or WebDAV behavior
is changed.

The tracked copy deliberately keeps the same file names and plain HTML, CSS,
and JavaScript structure as upstream. Reviewers can compare it directly with
`git diff --no-index assets custom/assets`; later upstream updates should
repeat that comparison before selectively rebasing UI changes.

## Phase 6 镜像边界

`Dockerfile.custom` 使用 amd64 Rust musl builder 和 scratch runtime。最终层
仅保留 `/bin/dufs`、`/assets/` 与 OCI 元数据；Custom UI V1 作为镜像内
fallback，运行时 `/assets:ro` 挂载仍可覆盖它。runtime 配置、密钥、数据、
日志与备份不属于 build context 或最终镜像。
