# Decisions

## D-001: Intentional IPv4-only V1 runtime baseline

The household/lab network, xhydebian host, and Mihomo transparent proxy
intentionally disable IPv6. DUFS Production V1 therefore uses container IPv4
`0.0.0.0:5000` and loopback host publishing `127.0.0.1:5000` only. The Phase 2
upstream tests that require `::1` are expected to be incompatible with this
policy; they are neither a DUFS regression nor a host fault. Do not enable
IPv6 or modify upstream tests merely to change this result.

## D-002: No service start in Phase 3

Phase 3 creates an inspectable production skeleton without starting a service.
Access control has no real credentials yet and is deferred to Phase 4. The
Phase 2 baseline image reference exists only to validate Compose interpolation;
the final custom production image is deferred to Phase 6.

## D-003: SHA-512 Basic admin authentication with least privilege

V1 has one `admin` account with `/:rw`, supplied only through runtime `.env`
as a SHA-512 crypt hash. DUFS uses Basic authentication for hashed passwords.
Global permissions enable upload, delete, search, archive, and hash, but keep
`allow-all` and symlink traversal false. Account and global permissions both
apply, so neither alone grants an operation. No anonymous or guest rule is
created.

## D-004: UI V1 uses the official complete-assets override

DUFS documents `--assets <directory>` as the supported way to override its
built-in UI. Phase 5 therefore tracks a complete copy of upstream `assets/` at
the baseline commit in `custom/assets/`, then makes the smallest possible
HTML/CSS/JavaScript changes there. Compose supplies it as read-only `/assets`.

This preserves the server-generated `__INDEX_DATA__` and
`__ASSETS_PREFIX__` placeholders and the upstream interaction JavaScript. It
does not alter Rust Core, HTTP access control, WebDAV methods, or the file API.
The cost is that upstream asset changes require a deliberate file-by-file
comparison; this is acceptable for V1 and is documented in Architecture.

## D-005：Phase 6 维持 scratch runtime 与 baked assets fallback

Phase 6 使用独立的 `Dockerfile.custom`，不修改官方 `Dockerfile`。它基于
官方 amd64 Rust musl 多阶段构建，最终保持 scratch runtime。镜像内的
`/assets/` 来自 `custom/assets/`，保证没有外部挂载时仍可提供验证过的 UI；
生产运行时的只读 `/assets` bind mount 则拥有覆盖优先级。config、`.env`、
secret、data、logs 和 backup 不得进入镜像。

## D-006：项目新增内容使用中文

从 Phase 6 起，项目新增或实际修改的代码注释、运维脚本说明和项目文档正文
统一使用中文。上游原始源码及其英文注释保持原样，避免无关 upstream diff。
技术标识、协议名、配置键、API 路径、Docker 标签键与命令保留其官方英文形式。
