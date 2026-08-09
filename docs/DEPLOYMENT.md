# 部署

runtime 目录固定为 `/home/ldzcyh/dockerApps/dufs`，包含 Compose、`.env`、
config、assets、data、logs、backup 与项目脚本。源码仓库仅保存脱敏示例。

## 当前 Production 状态

Phase 6.1 后，runtime `.env` 的 `DUFS_IMAGE` 为
`dufs:0.46.0-custom-v1-faca49a`。宿主机发布保持
`127.0.0.1:5000`，容器 bind 保持 `0.0.0.0:5000`，IPv6 不启用。

管理员 `DUFS_ADMIN_AUTH` 已由用户通过 runtime-only 交互式脚本配置；真实规则
不写入本文。`doctor.sh` 和 `start.sh` 在 sentinel 存在时拒绝正式启动。

Production V1.0 正在运行，Phase 8 Production Acceptance 为 **PASS**。当前 production
container 为 non-root `1000:1000`，服务仅发布至 `127.0.0.1:5000`，并保持 IPv4-only。

## assets

镜像内 `/assets/` 来自 `custom/assets/`。runtime
`/home/ldzcyh/dockerApps/dufs/assets:/assets:ro` 是生产覆盖层；更新前应复制
已审查 assets，再运行 `docker compose config`。assets 中不得放入 secret 或
用户数据。

## Phase 7 运行身份

生产 container 使用 runtime `.env` 中宿主机 `ldzcyh` 的实际 `DUFS_UID` 与
`DUFS_GID`，Compose 设置 `user: UID:GID`，不以 root 运行。data 与 logs 对该
numeric identity 可写；config 为 0640 且只读挂载，assets 只读挂载。该设置避免
bind-mounted data 出现 root-owned 文件，并保持宿主机维护路径一致。

## Phase 7 最终状态

最终交互式验收已通过：container running，`Config.User=1000:1000`，image 为
`dufs:0.46.0-custom-v1-faca49a`，health 为 200，宿主机仅发布
`127.0.0.1:5000`。认证、中文 UI、文件操作、WebDAV、symlink blocking、restart
与 recreate persistence 均通过；验收目录已清理。Phase 8 Production Acceptance 为
**PASS**，详见 `docs/ACCEPTANCE.md`。
