# DUFS Production 运维

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
