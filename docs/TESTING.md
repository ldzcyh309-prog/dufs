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

runtime `.env` 已改为 `dufs:0.46.0-custom-v1-faca49a`；sentinel 与 0600
权限保持不变。`docker compose config` 通过，未执行 `docker compose up`。
