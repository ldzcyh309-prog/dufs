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

## 完成状态与下一阶段

Phase 0–6 已完成，Phase 6.1（镜像可追踪性与中文文档 closeout）已完成。
当前停点为审核：下一阶段是 Phase 7 — Production Compose Deployment，但未经
明确授权不得进入 Phase 7，且不得启动正式 production DUFS。

## Git 状态

- 分支：`custom/v1`。
- 镜像 source commit / Phase 6 commit：
  `faca49a59b6cfdf4a9331451355fc10e32a6f8b3`
  （`build: add production custom image`）。
- 本次 Phase 6.1 文档 closeout commit：提交后以 `git rev-parse HEAD` 为准。
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
- `.env`：`ldzcyh:ldzcyh`、0600；最终 admin secret 未配置，仍为安全 sentinel。
- 正式 production container：未启动。
- `docker compose config`：通过；禁止执行 `docker compose up`。
- IPv4-only：container `0.0.0.0:5000`；host `127.0.0.1:5000`。
- IPv6 明确禁用；Mihomo 未修改；其他 `dockerApps` 项目未修改。

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
   `.env`、`docker compose config` 与 sentinel。
4. 保持 IPv4-only，不启动 production Compose。仅在用户明确授权后进入
   Phase 7。
