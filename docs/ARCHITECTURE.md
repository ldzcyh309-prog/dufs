# 架构

DUFS Production V1.0 将控制、构建与运行分离。

| 位置 | 职责 |
| --- | --- |
| `/home/ldzcyh/aiDev/workspaces/dufs-project` | 项目设计与执行控制文档 |
| `/home/ldzcyh/aiDev/workspaces/dufs` | Fork、Git、构建、测试、模板与文档 |
| `/home/ldzcyh/dockerApps/dufs` | runtime Compose、`.env`、config、assets、data、logs 与 backup |

Git 仓库只保存脱敏模板；runtime `.env`、真实 secret、用户数据、日志和备份
不得提交。Compose 项目名为 `dufs`。

## 网络与安全边界

生产策略为 IPv4-only：容器 `0.0.0.0:5000`，宿主机仅
`127.0.0.1:5000`。IPv6 由家庭网络、主机和 Mihomo 策略禁用；不得因测试
而启用它。

## Custom UI V1

`custom/assets/` 是基线提交 `fe7fd56` 官方 `assets/` 的完整可比较副本。
Compose 传入 `--assets /assets`，runtime 以只读 `/assets` 挂载。UI 不修改
Rust、认证、HTTP 路由或 WebDAV；升级时使用
`git diff --no-index assets custom/assets` 审查差异。

## Custom Image

`Dockerfile.custom` 保留官方 amd64 Rust musl 多阶段构建与 scratch runtime。
最终层只有 `/bin/dufs`、`/assets/` 和 OCI metadata。镜像内 assets 是
fallback；runtime `/assets:ro` bind mount 可覆盖它。runtime config、`.env`、
secret、data、logs 和 backup 不进入 build context 或最终镜像。
