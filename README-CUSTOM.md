# DUFS Production V1.0

这是基于 [sigoden/dufs](https://github.com/sigoden/dufs) 的家庭/实验室生产部署
fork；它不是 upstream DUFS 的独立版本声明。上游 `README.md` 保持原样，本文件是
本项目的中文入口。

## 当前 Release

- 项目：DUFS Production V1.0（release identifier：`1.0.0`）
- Git tag：`production-v1.0.0`
- upstream baseline：`fe7fd564f80dfbac361c8e0589c3845638149d38`
  （DUFS `0.46.0`）
- Phase 8 Acceptance：**PASS**，commit
  `4cd4707190dca9a2f8fb0e4e22684bc402da79d0`
- production image：`dufs:0.46.0-custom-v1-faca49a`
- image source revision：`faca49a59b6cfdf4a9331451355fc10e32a6f8b3`

Git release tag 表示项目文档封板；它不等同于 Docker image tag，也不会自动替换
已通过验收的 production image。

## 架构与运行边界

| 位置 | 职责 |
| --- | --- |
| `/home/ldzcyh/aiDev/workspaces/dufs` | Fork、构建、测试、脱敏模板与文档 |
| `/home/ldzcyh/dockerApps/dufs` | 实际 Compose、runtime `.env`、config、assets、data、logs 与 backup |

Build in `~/aiDev/workspaces`；Run in `~/dockerApps`。runtime `.env`、认证规则、
用户数据、日志和备份 archive 均不进入 Git 或 release。

## Production 摘要

Custom UI V1 通过官方 `--assets` 机制实现中文 UI、title/favicon 与 mobile 适配，
未修改 Rust Core。生产 container 使用 runtime `DUFS_UID:GID`，当前为
`1000:1000`，config/assets 只读挂载，data/logs 可写，避免 root-owned bind mount
data。

服务仅发布到 IPv4 loopback `127.0.0.1:5000`；IPv6、LAN 和公网暴露均未启用。
认证采用 Basic authentication + runtime-only SHA-512 crypt 规则：仅 `admin /:rw`，
`allow-all=false`，`symlink=false`，没有 anonymous 或 guest RW。

## Backup、Restore 与回滚

`backup.sh` 生成 `tar.gz`、archive 内 `manifest.txt` 与 SHA-256 sidecar，排除 runtime
`.env`、logs 和旧 backup。`restore.sh` 支持 verify、list、隔离 restore 与受控
selective restore，并验证 archive 安全性和 ownership。

完整 production disaster restore 是需要 staging、停机窗口、明确人工确认、恢复前备份
和 rollback plan 的高风险流程；这不是 release blocker。回滚只使用已验证的 production
image 策略，不因 Git release tag 自动更换镜像。

## 文档索引与升级原则

- [Release Notes / Manifest](docs/RELEASE.md)
- [验收记录](docs/ACCEPTANCE.md)
- [部署](docs/DEPLOYMENT.md)
- [安全](docs/SECURITY.md)
- [运维](docs/OPERATIONS.md)
- [备份与恢复](docs/BACKUP_RESTORE.md)
- [镜像构建](docs/IMAGE_BUILD.md)
- [测试记录](docs/TESTING.md)
- [决策记录](docs/DECISIONS.md)
- [交接](HANDOFF.md)

未来 upstream upgrade 必须从干净的 `main` 同步开始，在独立批准的 phase/branch 中完成
新构建、provenance、安全测试和 acceptance；不得直接覆盖当前 Production V1.0。
