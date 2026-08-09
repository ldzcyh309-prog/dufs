# 决策记录

## D-001：IPv4-only runtime

家庭网络、xhydebian 与 Mihomo 禁用 IPv6。因此 DUFS 使用容器
`0.0.0.0:5000` 与宿主机 `127.0.0.1:5000`。依赖 `::1` 的 upstream 测试失败
属于预期环境差异，不启用 IPv6，也不修改 upstream 测试。

## D-002：生产启动延后

Phase 3 仅建立 skeleton。Phase 7 明确获批前不得启动正式 Compose。

## D-003：最小权限 SHA-512 Basic 认证

`admin` 使用 runtime-only SHA-512 crypt hash 和 `/:rw`；`allow-all` 为 false，
symlink 为 false。无匿名或 guest。

## D-004：官方 complete-assets override

Custom UI V1 使用官方 `--assets` 机制。`custom/assets/` 保留完整上游结构，
保持 `__INDEX_DATA__`、`__ASSETS_PREFIX__` 与原生交互逻辑；不修改 Rust、
Access Control、WebDAV 或文件 API。

## D-005：scratch runtime 与 baked assets fallback

`Dockerfile.custom` 不修改官方 Dockerfile，使用 amd64 Rust musl builder 与
scratch runtime。`/assets/` 从 `custom/assets/` 烘焙，runtime 只读 assets
挂载拥有覆盖优先级。config、`.env`、secret、data、logs 与 backup 不进镜像。

## D-006：中文规范

项目新增或实际修改的自定义代码注释、运维脚本说明和自行维护文档使用中文。
上游源码及其英文注释保持原样；Git、Docker、WebDAV、配置键、协议名、
API 路径与 Docker 标签键保持官方英文名称。

## D-007：Phase 6.1 镜像修订可追踪性

镜像必须从已提交的完整构建状态生成。Phase 6.1 将 image source revision
固定为 `faca49a59b6cfdf4a9331451355fc10e32a6f8b3`，tag 为
`dufs:0.46.0-custom-v1-faca49a`。旧 `153a36f` 镜像保留作审计，但标记为
superseded local candidate，Phase 7 不得引用它。

## D-008：Phase 7 non-root UID/GID hardening

首次生产验收发现默认 root container 在 bind-mounted data 中创建了 root-owned
文件，造成宿主机 `ldzcyh` 无法进行 symlink 测试和 maintenance。这是
Production bind-mount UID/GID mismatch，不是 DUFS regression。生产 Compose
改用 runtime `DUFS_UID:DUFS_GID`，取宿主机 `ldzcyh` 的实际 numeric 值；不修改
scratch 镜像，不使用 `chmod 777`，并保持 config/assets 只读挂载。

Phase 7 最终验收确认该决策有效：DUFS 新建内容的 ownership 与宿主机
`ldzcyh` numeric identity 一致，restart/recreate 后数据保持，宿主机维护路径可用。

## D-009：安全隔离 Backup / Restore

旧 backup 会包含 runtime `.env`，旧 restore 则主动返回 64，无法满足 Phase 8。
新工作流默认备份 compose、config、assets 和 data，但排除 `.env`、logs、旧 backup；
使用 `tar.gz`、manifest 和 SHA-256 checksum。restore 默认仅允许隔离空 target，
按 runtime numeric UID/GID 对齐 ownership，并拒绝危险 archive member 与危险 target。
只读/隔离恢复优先；完整 production restore 不作为自动化操作。

## D-010：Phase 8 动态 asset URL 验收

DUFS 通过 rendered HTML 的 `__ASSETS_PREFIX__` 动态提供 favicon、CSS、JS。验收脚本
不得硬编码 `/favicon.svg` 或特定版本前缀；改为解析 HTML 并使用 `urljoin` 请求真实
URL。该问题仅是验收脚本 bug，不修改 production UI、image 或 Rust。

## D-011：Project Release Commit 与 Image Source Revision 分离

production image 在 Phase 6.1 从
`faca49a59b6cfdf4a9331451355fc10e32a6f8b3` 构建，并在 Phase 8 完成验收。Phase 9
只修改 release/documentation，因此 `production-v1.0.0` 指向最终 project release
commit，而 OCI revision 继续指向真正的 image source revision。不为 release metadata
重建 image，保证 provenance 可追踪且不引入未验收 image。

## D-012：完整 Production Disaster Restore 保持人工流程

完整 production disaster restore 需要 staging、停机窗口、明确人工确认、恢复前备份和
rollback plan，风险超出普通脚本自动化边界。默认 restore 保持 verify/list、隔离 restore
与受控 selective production-path restore；完整流程作为运维 NOTE，不构成 release
blocker。
