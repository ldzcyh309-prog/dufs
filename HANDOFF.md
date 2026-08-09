# DUFS Production V1.0 — 交接

## 项目目标与目录边界

维护可持续同步 upstream 的 DUFS Fork，并在家庭/实验室环境安全部署。始终遵守：

| 位置 | 职责 |
| --- | --- |
| `/home/ldzcyh/aiDev/workspaces/dufs-project` | 项目控制文档 |
| `/home/ldzcyh/aiDev/workspaces/dufs` | Git、源码、构建、测试、脱敏模板与文档 |
| `/home/ldzcyh/dockerApps/dufs` | runtime Compose、`.env`、config、assets、data、logs、backup |

Build in `~/aiDev/workspaces`；Run in `~/dockerApps`。runtime `.env`、真实
secret、用户数据、日志和备份绝不提交 Git。

## 完成状态与维护模式

Phase 0–9 已完成，DUFS Production V1.0 已发布，进入 **Production Maintenance Mode**。
Phase 8.1 解决 restore blocker，Phase 8 Acceptance Verdict 为 **PASS**。未来 upstream
sync、安全维护、新 feature branch 或 Production V1.1/V2 规划必须单独批准。

## Release 身份

- Release：`DUFS Production V1.0`（identifier：`1.0.0`）。
- Git tag：`production-v1.0.0`（annotated，指向本次 Phase 9 release closeout commit）。
- Release commit：由 `production-v1.0.0` 所指向；不在同一 commit 内自写 SHA，避免
  self-referential commit loop。
- Acceptance：**PASS**，commit
  `4cd4707190dca9a2f8fb0e4e22684bc402da79d0`。

## Git 状态

- 分支：`custom/v1`。
- 镜像 source commit / Phase 6 commit：
  `faca49a59b6cfdf4a9331451355fc10e32a6f8b3`
  （`build: add production custom image`）。
- upstream baseline tag：`v0.1.0-upstream-baseline`。
- baseline commit：`fe7fd564f80dfbac361c8e0589c3845638149d38`。
- `main` 与 `origin/main` 保持 baseline；不得在 `main` 开发。
- `origin`：`git@github.com:ldzcyh309-prog/dufs.git`；`upstream`：
  `https://github.com/sigoden/dufs.git`。
- Rust Core、`Cargo.toml`、`Cargo.lock` 相对 baseline 未修改。

## Phase 6.1 镜像状态

- Dockerfile：`Dockerfile.custom`；官方 `Dockerfile` 未修改。
- 版本：`0.46.0`，来自 `Cargo.toml`。
- 新不可变风格 tag：`dufs:0.46.0-custom-v1-faca49a`。
- 本地 alias：`dufs:0.46.0-custom-v1`，已指向新镜像。
- image ID：
  `sha256:a18751a7bb1cf77209b180c558a71cee7108a121cafd04c0f2ec29f0658276ce`。
- OCI revision：`faca49a59b6cfdf4a9331451355fc10e32a6f8b3`。
- 平台：`linux/amd64`；runtime：scratch；ENTRYPOINT：`[/bin/dufs]`。
- 最终层包含 `/bin/dufs` 与烘焙 `/assets/`。runtime
  `/home/ldzcyh/dockerApps/dufs/assets:/assets:ro` 可覆盖 baked assets。
- baked UI 与 external override 均通过认证、health、中文 UI/title/favicon、
  浏览；baked 测试还通过上传下载、WebDAV PROPFIND 与 symlink blocking。
- 临时容器、临时 SHA-512 凭据和测试数据已清除；未推送外部 registry。

旧 `dufs:0.46.0-custom-v1-153a36f` 已保留，状态为 **Phase 6 pre-closeout
build / superseded local candidate**；仅用于审计，Phase 7 不得引用。
Phase 2 baseline image `dufs:0.46.0-upstream-baseline-local` 也保留。

## runtime 与网络

- runtime `DUFS_IMAGE`：`dufs:0.46.0-custom-v1-faca49a`。
- `.env`：`ldzcyh:ldzcyh`、0600；admin secret 已配置但不在本文记录。
- `DUFS_UID=1000`、`DUFS_GID=1000`，对应宿主机 `ldzcyh` 的实际 numeric UID/GID。
- 正式 production container：运行中，`Config.User=1000:1000`。
- `docker compose config`：通过；Phase 7 已仅对 `dufs` service recreate。
- IPv4-only：container `0.0.0.0:5000`；host `127.0.0.1:5000`。
- IPv6 明确禁用；Mihomo 未修改；其他 `dockerApps` 项目未修改。

## Phase 7 non-root hardening checkpoint

- 根因：首次验收发现默认 root container 创建了 root-owned acceptance data，记录为
  `Production bind-mount UID/GID mismatch`，不是 DUFS regression。
- 当前镜像仍为 `dufs:0.46.0-custom-v1-faca49a`；health 为 200；host bind 仍为
  `127.0.0.1:5000`；restart policy 为 `unless-stopped`。
- `/data`、`/logs` 可由 `1000:1000` 写入；`/config`、`/assets` 为只读挂载；历史
  日志文件 owner 已修正为 `ldzcyh:ldzcyh`，未使用 `chmod 777`。
- `.dufs-phase7-acceptance` 已通过 authenticated HTTP DELETE 清理；最终交互式验收
  已通过，未记录任何密码或 hash。

## Phase 8.1 — Safe Backup/Restore Enablement

- `backup.sh` 与 `restore.sh` 的正式版本位于 `deploy/scripts/`，并同步到 runtime。
- 默认 backup 为 0600 `tar.gz` + `manifest.txt` + SHA-256 sidecar，包含 compose、
  config、assets、data，明确排除 runtime `.env`、logs 和旧 backup；不会保存 admin
  hash。
- restore 支持 `--verify`、`--list`、隔离 `--target`，以及严格限制的
  `--production-path RELATIVE --apply`。默认拒绝；拒绝 traversal、绝对路径、
  link/special member、checksum 错误、非空/危险 target；按 `DUFS_UID/GID` 对齐。
- Phase 8.1 隔离备份、checksum、list、verify、ownership、负面安全测试与受控
  selective production-path restore 均通过；中文文件名和小型二进制 integrity 已验证，
  测试 archive/data 已清理。Phase 8 authenticated 黑盒验收已通过，详见
  `docs/ACCEPTANCE.md`。

## Phase 8 closeout

- 最终 production 状态：image `dufs:0.46.0-custom-v1-faca49a`，container running，
  `Config.User=1000:1000`，host bind `127.0.0.1:5000`，IPv4-only。
- 认证、中文 UI/mobile、动态 asset routing、文件兼容性、WebDAV、ACL、symlink、hidden
  policy、non-root ownership、restart/recreate persistence、backup/restore 与日志安全均
  通过。Phase 8 结论为 **PASS**。
- 完整 production disaster restore 保持人工高风险运维流程，需要 staging、停机窗口和
  明确确认；这是 NOTE，不是验收 blocker。
- `phase8-acceptance.sh` 从 rendered HTML 动态解析 favicon、CSS、JS URL；此前
  `/favicon.svg` 硬编码问题仅为验收脚本 bug，不是 UI regression。

## 安全策略

`allow-all: false`；全局 upload、delete、search、archive、hash 为 true，
symlink 为 false。只有 `admin` `/:rw`，没有匿名或 guest。SHA-512 crypt hash
通过 Basic authentication 在 runtime 提供。hidden 名称、日志不含 Authorization
header 与 sentinel 防启动行为均已验证。

不得执行 Docker 全局 prune，不得删除 baseline 或 superseded image，不得设置
最终 admin secret，不得启用 IPv6，不得修改 Mihomo。

## 中文规范

本项目新增或实际修改的自定义代码注释、运维脚本说明与自行维护文档统一使用
中文。上游原始源码和英文注释保持原样，避免无关 upstream diff。Git、Docker、
Docker Compose、Rust、Cargo、WebDAV、PROPFIND、HTTP、IPv4、SHA-512、
ENTRYPOINT、DUFS_IMAGE、allow-all 和 OCI label keys 保持官方英文名称。

项目控制文档
`DUFS_Production_V1.0_Project_Design.md` 与
`DUFS_Production_V1.0_Codex_Master_Prompt.md` 已为中文。`CHANGELOG.md` 为
upstream baseline 文件，不作为项目自维护文档翻译。

## 下一会话清单

1. 先读本文件、两个项目控制文档和 `docs/IMAGE_BUILD.md`。
2. 核验 `git status`、`git branch -vv`、`git log --oneline --decorate -8`。
3. 核验 `docker image inspect dufs:0.46.0-custom-v1-faca49a`、runtime
   `.env`、`DUFS_UID/DUFS_GID` 与 `docker compose config`。
4. 保持 IPv4-only 与 non-root runtime；Production V1.0 已发布。
5. 仅在获得单独批准后处理 upstream sync、安全维护或新的 feature branch；不得直接
   开始 V1.1、V2 或上游升级。
