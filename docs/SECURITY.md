# 安全基线

## 网络

DUFS Production V1.0 为 IPv4-only：容器 `0.0.0.0:5000`，宿主机
`127.0.0.1:5000`。IPv6 已按生产策略禁用；未来 LAN、Tailscale 或公网暴露
需要独立明确决策。

## 认证与权限

仅有 `admin` 账户，规则为 `/:rw`。runtime `.env` 的 `DUFS_ADMIN_AUTH`
必须在部署前由用户提供 SHA-512 crypt hash，并使用 Basic authentication。
仓库和模板只允许占位符，不能保存真实密码或 hash。

| 能力 | 状态 |
| --- | --- |
| `allow-all` | false |
| upload / delete / search / archive / hash | true |
| symlink | false |

账户权限与全局权限均需允许操作。没有匿名规则或 guest。symlink traversal 禁用，
避免访问共享根目录外内容。

## 隐藏名与日志

`.git`、`.DS_Store`、`Thumbs.db`、`*.tmp`、`*.part`、`*.lock` 被隐藏；这不
替代访问控制。日志写入 `/logs/dufs.log`，不记录 Authorization header。
runtime `.env` 为 0600，`config/config.yaml` 为 0640；不得提交 runtime 文件。

## 运行身份与 bind mount

生产 DUFS container 不以 root 运行。runtime `.env` 的 `DUFS_UID` 与
`DUFS_GID` 对应宿主机 `ldzcyh` 的实际 numeric UID/GID，并由 Compose 的
`user: UID:GID` 使用。这样可避免 bind-mounted data 产生 root-owned 文件，保证
宿主机 backup、restore 和 maintenance 可操作，同时降低 container privilege。
不得使用 `chmod 777`；data/logs 只需该运行身份可写，config/assets 继续只读挂载。

Phase 7 最终验证确认：container 为 non-root，未认证与无效凭据返回 401，有效
管理员认证通过；symlink outside root 被阻止，日志未发现 Authorization、密码或
hash 泄漏。IPv4-only 保持，IPv6 未启用，Mihomo 未修改。

## Backup / Restore 安全边界

默认 backup 不包含 runtime `.env`，从而不保存管理员 SHA-512 crypt 规则。恢复前
必须验证 checksum、manifest 与 archive member；拒绝绝对路径、`..` traversal、
symlink/hardlink、device、FIFO 和未知顶层成员。普通恢复只允许显式的空隔离 target，
并拒绝生产和危险路径；selective production restore 需要安全相对路径、`--apply`，
且目标必须不存在。不会使用 `chmod 777`。
