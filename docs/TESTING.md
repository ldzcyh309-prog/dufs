# 测试记录

## Phase 2 — upstream baseline

baseline 为 `fe7fd56`（`v0.1.0-upstream-baseline`）。`cargo fmt --check`、
`cargo clippy`、`cargo build --release` 通过；clippy 有 3 个非阻断 upstream
warning。`cargo test` 仅 `tests/bind.rs` 的两个 IPv6 用例因无法 bind `::1`
失败，符合 IPv4-only 生产策略，未修改 upstream 测试。

release binary 为 `dufs 0.46.0`。宿主机与官方 Docker baseline smoke test
均通过首页、`/__dufs__/health` 与静态文件服务。baseline image
`dufs:0.46.0-upstream-baseline-local` 保留用于审计。

## Phase 4 — 安全配置

临时 loopback 测试通过未认证/错误认证 401、有效 admin 访问、上传、下载、
搜索、archive、hash、删除、hidden-name 搜索、symlink blocking、health 和
日志不含 Authorization/临时密码。测试数据与凭据已清除。

## Phase 5 — Custom UI V1

使用 release binary、`--assets ./custom/assets`、临时 `/tmp` 数据及
`127.0.0.1:5105` 验证。JavaScript 语法、中文 UI、title、SVG favicon、认证、
浏览、上传下载、搜索、MKCOL、删除、archive、SHA-256 hash、WebDAV PROPFIND
和 Compose 静态配置均通过。Chrome 在 390×844、430×932 确认无横向溢出，
长文件名省略且操作按钮不重叠。

## Phase 6 — 初始 custom image

初始 local candidate `dufs:0.46.0-custom-v1-153a36f` 功能测试通过，但其
revision 只指向 Phase 5 提交，不能完整代表 `Dockerfile.custom` 已提交状态。
它被保留用于审计，已由 Phase 6.1 supersede。

## Phase 6.1 — 可追踪镜像 closeout

从干净的已提交 `faca49a59b6cfdf4a9331451355fc10e32a6f8b3` 构建
`dufs:0.46.0-custom-v1-faca49a`，并将 alias
`dufs:0.46.0-custom-v1` 指向该镜像。inspect 验证为 `linux/amd64` scratch
runtime，ENTRYPOINT 为 `["/bin/dufs"]`，OCI revision 精确为 `faca49a…`，
版本为 `0.46.0-custom-v1-faca49a`。export 验证 `/bin/dufs` 与完整 `/assets/`。

| 检查 | 结果 |
| --- | --- |
| `dufs --version` | 通过，`dufs 0.46.0` |
| baked UI，无外置 assets | 中文 UI、`DUFS 文件空间`、favicon、首页、health 通过 |
| 认证 | 未认证 401、错误凭据 401、临时有效 admin 200 |
| 文件功能 | 上传 201、下载 200 且内容一致 |
| WebDAV | `PROPFIND Depth: 1` 为 207 |
| symlink | 指向 `/etc/passwd` 返回 404 |
| runtime `/assets:ro` override | UI、title、favicon、health、认证、浏览通过 |
| 清理 | 临时容器、SHA-512 凭据与 `/tmp` 数据已删除 |

runtime `.env` 已改为 `dufs:0.46.0-custom-v1-faca49a`；secret 不在本文记录，
权限保持 0600。`docker compose config` 通过，production Compose 已运行。

## Phase 7 non-root UID/GID

生产 container 必须通过 `DUFS_UID`/`DUFS_GID` 以宿主机 `ldzcyh` numeric identity
运行。重建后需检查 `Config.User`、health、loopback bind、只读 assets/config，
并由 DUFS 创建专用测试文件后用宿主机 `stat` 确认 owner/group 与 `ldzcyh` 一致。

## Phase 7 最终验收

| 检查 | 结果 |
| --- | --- |
| running / image / `Config.User` | 通过；`dufs:0.46.0-custom-v1-faca49a`、`1000:1000` |
| health / bind / restart policy | 通过；200、`127.0.0.1:5000`、`unless-stopped` |
| authentication | 通过；unauthenticated/invalid 为 401，valid admin 为 200 |
| UI / browse / upload/download / search | 通过；中文 title/favicon 保持 |
| mkdir/delete / archive/hash / WebDAV | 通过；PROPFIND 为 207 |
| symlink outside root | 通过阻断 |
| restart / recreate persistence | 通过；测试数据保持并完成清理 |
| ownership / mounts | 通过；新内容与 `ldzcyh` 一致，assets/config 为 ro |
| logs / secret leak / network boundary | 通过；无凭据泄漏，IPv4-only |

Phase 7 完成；Phase 8 尚未进入。

## Phase 8.1 — Safe Backup/Restore Enablement

新 backup/restore 脚本已通过 `bash -n`，并使用短期、无 `.env` 的测试 archive 验证
manifest、checksum、`--verify`、`--list` 与隔离 `--target` restore。恢复后的结构和
ownership 对齐 `DUFS_UID:GID`。额外测试确认 archive traversal、绝对路径、checksum
损坏、非空 target 与危险 target 均被拒绝。对 `.dufs-phase8-acceptance` 的受控
selective production-path restore 也验证了中文文件名、小型二进制文件、checksum 和
`1000:1000` ownership；测试数据与 archive 均已清理。Phase 8 的 authenticated
DUFS 可读性验收仍待继续执行。
