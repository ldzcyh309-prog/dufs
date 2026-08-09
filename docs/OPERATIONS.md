# DUFS Production 运维

当前 Release 为 **DUFS Production V1.0**，Git tag 为 `production-v1.0.0`。Git release
tag 表示项目文档封板，不等同于 Docker image tag；不得因为创建或检出 Git tag 自动替换
production image。当前 production image 仍为 `dufs:0.46.0-custom-v1-faca49a`。

## 运行身份

生产 container 不以 root 运行。runtime `.env` 的 `DUFS_UID` 与 `DUFS_GID`
对应宿主机 `ldzcyh` 的实际 numeric UID/GID。data 与 logs 对该身份可写；
config 与 assets 只读挂载。这样可避免 root-owned 数据并支持宿主机备份、恢复
和日常维护。

## 常用操作

在 `/home/ldzcyh/dockerApps/dufs` 执行：

```text
scripts/start.sh
scripts/stop.sh
scripts/restart.sh
scripts/doctor.sh
docker compose ps
curl -fsS http://127.0.0.1:5000/__dufs__/health
```

日志使用 `scripts/logs.sh`；管理员密码更新使用
`scripts/set-admin-password.sh`，不得把密码或 hash 写入 Git、文档或聊天。

## 路径、备份与升级

数据位于 `data/`，配置位于 `config/`，UI 覆盖位于 `assets/`，日志位于 `logs/`，
备份位于 `backup/`。生产镜像为 `dufs:0.46.0-custom-v1-faca49a`。升级前备份
compose、`.env`、config、assets 与必要数据；回滚使用已验证的旧镜像 tag，且只
操作 Compose project `dufs`。不得执行 Docker 全局 prune。

## 网络边界

生产服务保持 IPv4-only，仅发布 `127.0.0.1:5000`；不开放 LAN、公网、IPv6、
反向代理或公网域名。

## Backup / Restore

`scripts/backup.sh` 默认生成 `tar.gz`、同名 `.sha256` 和 archive 内
`manifest.txt`，备份 compose、config、assets 与 data。默认不包含 runtime `.env`、
logs 或旧 backup，因此不会备份管理员认证规则。文件权限为 0600。

`scripts/restore.sh --verify BACKUP` 先校验 checksum 和 archive 安全性；
`--list BACKUP` 列出已验证 archive；`--target DIRECTORY BACKUP` 只能恢复到显式、
空且非危险的隔离目录。恢复时 owner/group 对齐 runtime `DUFS_UID`/`DUFS_GID`。
`--production-path RELATIVE --apply BACKUP` 仅恢复 data 内尚不存在的安全相对路径，
不覆盖、不恢复 `.env`、不停止 container。完整 production restore 不在自动化范围内。

Phase 8 已验证 selective restore 后 production DUFS 可读取恢复内容。完整 disaster
restore 仍要求人工 staging、停机窗口与明确运维确认。
