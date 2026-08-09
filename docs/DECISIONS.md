# 决策记录

## D-001：IPv4-only runtime

家庭网络、xhydebian 与 Mihomo 禁用 IPv6。因此 DUFS 使用容器
`0.0.0.0:5000` 与宿主机 `127.0.0.1:5000`。依赖 `::1` 的 upstream 测试失败
属于预期环境差异，不启用 IPv6，也不修改 upstream 测试。

## D-002：生产启动延后

Phase 3 仅建立 skeleton。Phase 7 明确获批前不得启动正式 Compose。

## D-003：最小权限 SHA-512 Basic 认证

`admin` 使用 runtime-only SHA-512 crypt hash 和 `/:rw`；`allow-all` 为 false，
symlink 为 false。无匿名或 guest。

## D-004：官方 complete-assets override

Custom UI V1 使用官方 `--assets` 机制。`custom/assets/` 保留完整上游结构，
保持 `__INDEX_DATA__`、`__ASSETS_PREFIX__` 与原生交互逻辑；不修改 Rust、
Access Control、WebDAV 或文件 API。

## D-005：scratch runtime 与 baked assets fallback

`Dockerfile.custom` 不修改官方 Dockerfile，使用 amd64 Rust musl builder 与
scratch runtime。`/assets/` 从 `custom/assets/` 烘焙，runtime 只读 assets
挂载拥有覆盖优先级。config、`.env`、secret、data、logs 与 backup 不进镜像。

## D-006：中文规范

项目新增或实际修改的自定义代码注释、运维脚本说明和自行维护文档使用中文。
上游源码及其英文注释保持原样；Git、Docker、WebDAV、配置键、协议名、
API 路径与 Docker 标签键保持官方英文名称。

## D-007：Phase 6.1 镜像修订可追踪性

镜像必须从已提交的完整构建状态生成。Phase 6.1 将 image source revision
固定为 `faca49a59b6cfdf4a9331451355fc10e32a6f8b3`，tag 为
`dufs:0.46.0-custom-v1-faca49a`。旧 `153a36f` 镜像保留作审计，但标记为
superseded local candidate，Phase 7 不得引用它。
