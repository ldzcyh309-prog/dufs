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
