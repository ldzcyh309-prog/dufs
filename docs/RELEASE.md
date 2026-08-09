# DUFS Production V1.0

## 1. Release Identity

| 项目 | 值 |
| --- | --- |
| Release | DUFS Production V1.0 |
| Release identifier | `1.0.0` |
| Git tag | `production-v1.0.0` |
| Release commit | `production-v1.0.0` 所指向的 Phase 9 documentation/release closeout commit |
| Acceptance commit | `4cd4707190dca9a2f8fb0e4e22684bc402da79d0` |
| Image | `dufs:0.46.0-custom-v1-faca49a` |
| Image source revision / OCI revision | `faca49a59b6cfdf4a9331451355fc10e32a6f8b3` |
| Image ID | `sha256:a18751a7bb1cf77209b180c558a71cee7108a121cafd04c0f2ec29f0658276ce` |
| Upstream baseline | `fe7fd564f80dfbac361c8e0589c3845638149d38` |
| Upstream DUFS | `0.46.0` |

Release commit 采用 tag 引用而非在同一 commit 中自写 SHA，避免 self-referential commit
循环。Acceptance commit、Image Source Revision 与 Project Release Commit 职责不同，
它们不相同是正确设计。

## 2. 项目定位

本项目是基于 `sigoden/dufs` 的家庭/实验室 Production V1.0 fork，目标是可维护、
可验证、可回滚的本地生产部署体系；不宣称自己是 upstream DUFS `1.0`。

## 3. Release Scope

Phase 0–8 已完成：upstream baseline、security configuration、Custom UI V1、custom
image 与 provenance、production Compose、non-root UID/GID、backup/restore，以及
Phase 8 production acceptance。Phase 9 封板内容仅为文档与 release metadata。

## 4. Custom UI V1

使用官方 `--assets` 机制提供中文 UI、title/favicon 与 mobile validation。Custom UI
保留原生交互和 WebDAV 兼容性，Rust Core 未修改。

## 5. Security Model

- Basic authentication 使用 runtime-only SHA-512 crypt 规则。
- 仅 `admin /:rw`；`allow-all=false`。
- `upload/delete/search/archive/hash=true`，`symlink=false`。
- 无 guest RW、无 anonymous RW；hidden 规则不替代 Access Control。
- secret 仅存在于 runtime，不进入 Git、release 或本文。

## 6. Runtime Security

production container 使用 runtime `DUFS_UID:GID`，当前 `Config.User=1000:1000`。
config/assets 为只读挂载，data/logs 可写，以避免 root-owned bind mount data 并维持
宿主机可维护性。

## 7. Network Boundary

container bind 为 `0.0.0.0:5000`，宿主机仅发布 `127.0.0.1:5000`。运行策略为
IPv4-only，IPv6 disabled；没有 LAN/public exposure，也未配置 reverse proxy 或 public
HTTPS。

## 8. Image Provenance

已验收 image 为 `dufs:0.46.0-custom-v1-faca49a`，image ID 为
`sha256:a18751a7bb1cf77209b180c558a71cee7108a121cafd04c0f2ec29f0658276ce`。它从
`faca49a59b6cfdf4a9331451355fc10e32a6f8b3` 构建，OCI revision 保持该值。镜像是
`linux/amd64` scratch runtime，含 baked assets，runtime `/assets:ro` 可覆盖。

Project Release Commit 是 Phase 9 文档封板 commit，不是 Image Source Revision。
为 release metadata 重建镜像会引入未验收 image，并伪造 provenance，因此不执行。

## 9. Acceptance

[Phase 8 Acceptance](ACCEPTANCE.md) verdict 为 **PASS**，acceptance commit 为
`4cd4707190dca9a2f8fb0e4e22684bc402da79d0`。认证、中文 UI/mobile、asset routing、
文件兼容性、目录/搜索、archive/hash、WebDAV、ACL、symlink/hidden、non-root、
persistence、运维日志与网络边界均已通过。

## 10. Backup / Restore

备份使用 `tar.gz`、`manifest.txt` 和 SHA-256 sidecar，排除 runtime `.env`。restore
支持 verify/list、隔离 restore、受控 selective restore、ownership 对齐与 archive
member 安全检查。

## 11. Known Limitations / Notes

完整 production disaster restore 不由普通自动脚本直接执行。它需要 staging、停机窗口、
明确人工确认、恢复前备份和 rollback plan。这是设计上的 NOTE，不是 release blocker。

production 当前仅 loopback；不向 LAN 或 public 提供服务。

## 12. Rollback

正式 production image 是 `dufs:0.46.0-custom-v1-faca49a`。baseline audit image 为
`dufs:0.46.0-upstream-baseline-local`。`dufs:0.46.0-custom-v1-153a36f` 仅为
superseded local candidate / audit，不能作为推荐的 production rollback target。

## 13. Upgrade Considerations

未来 upstream upgrade 不得直接在 `main` 开发或覆盖当前 Production V1.0。应先同步
upstream，在新批准的 branch/phase 中重新 build、记录 provenance、执行安全测试与
production acceptance。

## 14. Secret Boundary

Git 与 GitHub Release 不包含 runtime `.env`、admin password、`DUFS_ADMIN_AUTH`、
Authorization header、用户 data、logs 或 backup archive。
