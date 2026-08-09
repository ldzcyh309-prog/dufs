# DUFS Production V1.0 — 交接

**下一次新会话：先读 `HANDOFF.md`。** 随后阅读
[`docs/QNAP_PRODUCTION_CUTOVER_2026-08-09.md`](docs/QNAP_PRODUCTION_CUTOVER_2026-08-09.md)，它是当前生产状态的完整人工验收记录。

## 当前状态

Production V1.0 已冻结；`production-v1.0.0` 是黄金基线，绝不可移动、重写或 force push。
QNAP NAS 已是 Primary：`http://192.168.120.138:5100`，runtime 为
`/share/Container/dufs`，镜像为 `dufs:0.46.0-custom-v1-faca49a`，OCI revision 为
`faca49a59b6cfdf4a9331451355fc10e32a6f8b3`。运行身份为 `1000:100`，restart policy 为
`unless-stopped`；最终人工 health 为 `{"status":"OK"}`。

`.env` 是 runtime secret，绝不提交、读取、输出或写入文档。

## Primary 与 rollback

- QNAP 为唯一 Primary，端口映射 `192.168.120.138:5100 -> 5000/tcp`，架构 `amd64`。
- xhydebian `192.168.120.130` 的 `/home/ldzcyh/dockerApps/dufs` 已停止（人工状态
  `Exited (0)`），保留 runtime、`.env`、config、assets、data、backup、image 与
  compose.yaml 作为 rollback / golden 节点。
- 本次为 **Zero-Data Cutover**：xhydebian 只有测试/非正式 `data/1`，没有迁移正式业务
  数据；QNAP 的测试数据已清理，最终 data 为空。当前没有待继续执行的数据迁移。
- 若未来 QNAP 已产生正式数据，回滚前必须先确认 authoritative data source；不得启动旧
  节点并产生双主写入。Zero-Data Cutover 当前风险较低。

## QNAP 安全边界

`data` 最终 ACL 的硬性边界是：`group::---`、`other::---`、`default:group::---`、
`default:other::---`。不得 `chmod 777`，不得对 production data 递归 chmod/chown，不得
`setfacl -b/-k`，不得修改 QNAP 全局 ACL 或共享目录 ACL。

不要未经隔离 ACL 验证而用 `rsync -a` 向 QNAP production data 批量创建文件；`--no-perms`
等传统 POSIX 选项也不能保证 QNAP ACL 模型。详见 cutover 文档的 rsync ACL lesson。

## Portable scripts 与 host 约束

部署的 `scripts/` 包含 `backup.sh`、`restore.sh`、`set-admin-password.sh`、
`phase7-acceptance.sh`、`phase8-acceptance.sh`，其权限和 owner/group 已人工设置为
`750` / `1000:100`。

- QNAP 为 GNU bash 3.2.57；没有 `python3` 与 `realpath`。
- `backup.sh` 当前可原生使用，已完成真实 host 验收：
  `dufs-backup-20260809T150747Z.tar.gz` 与 checksum 均为 0600、sha256sum PASS，且不含
  `.env`、logs 或已有 backup。
- `restore.sh`、Phase 7、Phase 8 需要安全 Python；当前 QNAP 没有 Python，所以 restore
  按设计 fail closed（return code 69），这不是 DUFS 服务故障。Phase 7/8 未在 QNAP
  production 完整执行，仅 source fixture / portability test PASS。
- Docker 解析顺序为 `DOCKER_BIN` override → `command -v docker` → fail closed。非交互
  QNAP PATH 不含 Docker；当前观测到的 wrapper 路径仅供人工设置 `DOCKER_BIN`，不能硬编码
  进脚本。
- 本次没有在 QNAP 上执行 password rotation；现有 authentication 已人工验证正常。

## 绝对不要做

不要修改 frozen tag、QNAP 全局 ACL、Container Station、NAS PATH/系统 Python；不要把 admin
密码放入命令行或输出 `DUFS_ADMIN_AUTH`；不要 Docker global prune、删除 image、直接运行
完整 disaster restore，或在未确认数据权威源时启动两个可写节点。

下一次维护应从本文件和 cutover 文档开始；任何 upstream sync、新 feature、真实数据迁移、
Python provisioning 或 ACL 变更均需单独批准。
