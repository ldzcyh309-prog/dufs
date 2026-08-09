# DUFS Production 运维

当前 Release 为 **DUFS Production V1.0**，Git tag 为 `production-v1.0.0`（冻结黄金
基线）。QNAP 已是 Primary；完整状态和人工验收以
[`QNAP_PRODUCTION_CUTOVER_2026-08-09.md`](QNAP_PRODUCTION_CUTOVER_2026-08-09.md) 为准。
Git tag 不等同于 Docker image tag；不得自动替换 production image。

## 运行身份

生产 container 不以 root 运行。runtime `.env` 的 `DUFS_UID` 与 `DUFS_GID`
对应 QNAP 的 numeric UID:GID `1000:100`。data ACL 的 `group::---`、`other::---` 及其
default ACL 是安全边界；不得用递归 chmod/chown “修复”权限。

## 常用操作

在 QNAP 交互 SSH 的 `/share/Container/dufs` 执行：

```text
docker compose --project-name dufs --env-file .env -f compose.yaml ps
curl -fsS http://192.168.120.138:5100/__dufs__/health
```

非交互 SSH 必须显式提供已人工确认的 `DOCKER_BIN`；不要把当前 NAS wrapper 路径写入脚本。
管理员密码更新使用 `scripts/set-admin-password.sh`，不得把密码或 hash 写入 Git、文档或聊天。

## 路径、备份与升级

数据位于 `data/`，配置位于 `config/`，UI 覆盖位于 `assets/`，日志位于 `logs/`，
备份位于 `backup/`。生产镜像为 `dufs:0.46.0-custom-v1-faca49a`。升级前备份
compose、`.env`、config、assets 与必要数据；回滚使用已验证的旧镜像 tag，且只
操作 Compose project `dufs`。不得执行 Docker 全局 prune。

## 网络边界

生产服务为 IPv4-only，发布 `192.168.120.138:5100`；不开放公网、IPv6、反向代理或公网域名。

## Backup / Restore

`scripts/backup.sh` 默认生成 `tar.gz`、同名 `.sha256` 和 archive 内
`manifest.txt`，备份 compose、config、assets 与 data。默认不包含 runtime `.env`、
logs 或旧 backup，因此不会备份管理员认证规则。文件权限为 0600。

`scripts/restore.sh --verify BACKUP` 需要安全 Python 解释器，先校验 checksum 和 archive 安全性；
`--list BACKUP` 列出已验证 archive；`--target DIRECTORY BACKUP` 只能恢复到显式、
空且非危险的隔离目录。恢复时 owner/group 对齐 runtime `DUFS_UID`/`DUFS_GID`。
`--production-path RELATIVE --apply BACKUP` 仅恢复 data 内尚不存在的安全相对路径，
不覆盖、不恢复 `.env`、不停止 container。完整 production restore 不在自动化范围内。

QNAP 当前没有 Python，restore 会按设计 fail closed，不能自动安装 Python 或降低 archive
验证。Phase 7/8 未在 QNAP production 完整执行；完整 disaster restore 始终要求人工 staging、
停机窗口与明确运维确认。
