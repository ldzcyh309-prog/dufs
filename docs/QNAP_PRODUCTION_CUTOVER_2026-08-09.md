# QNAP Production Cutover — 2026-08-09

本文件固化 DUFS Production V1.0 的人工生产验收事实。它不包含 runtime `.env`、管理员
认证规则或密码。

## Primary 与镜像

QNAP NAS 是当前唯一 Primary：LAN IP `192.168.120.138`，访问地址
`http://192.168.120.138:5100`，端口映射 `192.168.120.138:5100 -> 5000/tcp`。runtime 为
`/share/Container/dufs`，架构 `amd64`，UID:GID 为 `1000:100`，restart policy 为
`unless-stopped`。Production image 为 `dufs:0.46.0-custom-v1-faca49a`，OCI revision 为
`faca49a59b6cfdf4a9331451355fc10e32a6f8b3`。最终人工 health：`{"status":"OK"}`。

`production-v1.0.0` 是冻结黄金基线，禁止移动、重写或 force push。QNAP adaptation 没有
改变 V1.0 Rust Core、UI 或正式 image。

## Runtime 与 ACL

正式 runtime 包含 `compose.yaml`、`.env`、`config/`、`assets/`、`data/`、`logs/`、
`backup/`、`scripts/`；`.env` 是 secret runtime 文件，绝不进入 Git 或本文。

`data` 的最终安全边界为：`group::---`、`other::---`、`default:group::---`、
`default:other::---`。完整 ACL 见 [`QNAP_DEPLOYMENT.md`](QNAP_DEPLOYMENT.md)。不得
`chmod 777`、递归 chmod/chown production data、`setfacl -b/-k`、修改 QNAP 全局 ACL 或
覆盖共享目录 ACL。

## Portable scripts 与 QNAP host

Phase 2 / 2.1 / 2.2 的源码提交为：

- `770d284 feat: make runtime scripts portable for qnap`
- `dd0e92d fix: complete qnap runtime portability`
- `253fffd fix: harden scripts for qnap host compatibility`

QNAP 实测 GNU bash `3.2.57`；`python3` 与 `realpath` 当前不存在；OpenSSL `3.0.9`；
`sha256sum`、`tar`、`find`、`getfacl/setfacl` 可用，`cp` 支持 `--no-preserve`。Docker
Compose 为 `v2.29.1-qnap2`。

`backup.sh` 可原生运行。`restore.sh`、Phase 7、Phase 8 需要安全 Python，解析顺序为
`PYTHON_BIN` → `python3` → `python` → fail closed。当前 QNAP 没有 Python，restore 已实测
return code 69；前后 data digest 一致，`data_unchanged=YES`、`restore_fail_closed=PASS`。
这是设计行为，不是 DUFS 服务故障；不得自动修改 NAS Python、PATH 或拉取 Python image。

Phase 7/8 是高级验收工具。source fixture / portability test 为 PASS，host dependency
preflight 已完成；当前 QNAP 无 Python，未在 QNAP production 完整执行 Phase 7/8。此次
cutover 没有执行 password rotation，现有 authentication 已人工验证正常。

交互 SSH PATH 能解析 QNAP Container Station Docker wrapper；非交互 PATH 为
`/usr/bin:/bin:/usr/sbin:/sbin`，找不到 Docker。当前 wrapper 的存储路径只是实机观测值，
不能写入 portable 程序。规则是 `DOCKER_BIN` override → `command -v docker` → fail closed。

## Backup 与 restore

QNAP 已真实验收 `dufs-backup-20260809T150747Z.tar.gz`：archive 与 checksum 均为 mode
600，`sha256sum` PASS。manifest 记录 image 与 OCI revision，且 `.env`、logs、已有 backup
均未进入 archive。

restore 在缺 Python 时 fail closed；完整 disaster restore 始终是人工高风险流程。不得为了
“恢复可用”降低 archive 的 traversal、link、device、FIFO、unexpected member 或 checksum
安全验证。

## Zero-Data Cutover 与 rsync lesson

本次是 **Zero-Data Cutover**：xhydebian data 仅有测试/非正式 `data/1`，没有正式业务数据
需要迁移；QNAP 测试数据已全部清除，最终 QNAP data 为空。

实机发现 Linux → QNAP 的 rsync 即使使用 `--no-perms --no-owner --no-group`，新建 directory
仍可能得到 `group::r-x`、file 得到 `group::r--`；`--chmod=ugo=rwX` 也会产生不符合基线的
`group::rw-`。因此不得直接使用 `rsync -a`，也不得假设这些选项会自动保持 QNAP ACL。
未来真实 Linux → QNAP 迁移必须另行设计 ACL-aware procedure，并先在隔离目录验证 ACL。
本次测试目录 `1`、`nas_test2`、`.rsync-acl-test`、`.preseed-acl-test` 已从 QNAP production
data 清除。

## Rollback runbook

xhydebian `192.168.120.130` 的 `/home/ldzcyh/dockerApps/dufs` 已通过 `docker compose stop`
停止，最终人工状态 `Exited (0)`；没有执行 down、rm、rmi、删除 runtime 或 Docker prune。
它保留 runtime、`.env`、config、assets、data、backup、image、compose.yaml，作为 rollback /
golden 节点。保留 backup：`dufs-backup-20260809T152708Z.tar.gz` 与
`dufs-backup-20260809T151445Z.tar.gz`。

如需回滚，在确认 authoritative data source 后，于 xhydebian 执行：

```bash
cd /home/ldzcyh/dockerApps/dufs
docker compose --env-file .env -f compose.yaml start
curl -fsS http://127.0.0.1:5000/__dufs__/health
```

若 QNAP 已产生正式数据，禁止直接启动旧节点并同时写入；必须先完成数据权威源决策。当前
Zero-Data Cutover 状态下 rollback 风险较低。

## QNAP 日常只读检查

交互 SSH 中可在 `/share/Container/dufs` 执行：

```bash
docker compose --project-name dufs --env-file .env -f compose.yaml ps
curl -fsS http://192.168.120.138:5100/__dufs__/health
```

非交互 SSH 必须显式提供 `DOCKER_BIN`。不要将管理员密码放入 command line，绝不输出
`DUFS_ADMIN_AUTH`。下一次维护先读 [`../HANDOFF.md`](../HANDOFF.md)。
