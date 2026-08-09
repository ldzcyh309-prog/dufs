# 部署

runtime 目录固定为 `/home/ldzcyh/dockerApps/dufs`，包含 Compose、`.env`、
config、assets、data、logs、backup 与项目脚本。源码仓库仅保存脱敏示例。

## 当前部署前状态

Phase 6.1 后，runtime `.env` 的 `DUFS_IMAGE` 为
`dufs:0.46.0-custom-v1-faca49a`。宿主机发布保持
`127.0.0.1:5000`，容器 bind 保持 `0.0.0.0:5000`，IPv6 不启用。

管理员 `DUFS_ADMIN_AUTH` 仍是 fail-safe sentinel；其必须在未来由用户提供
runtime-only SHA-512 crypt 规则。`doctor.sh` 和 `start.sh` 在 sentinel 存在
时拒绝正式启动。

Phase 6.1 只执行 `docker compose config` 静态验证，未执行
`docker compose up`。Phase 7 获得明确授权前不得启动正式容器。

## assets

镜像内 `/assets/` 来自 `custom/assets/`。runtime
`/home/ldzcyh/dockerApps/dufs/assets:/assets:ro` 是生产覆盖层；更新前应复制
已审查 assets，再运行 `docker compose config`。assets 中不得放入 secret 或
用户数据。
