# QNAP Deployment（DUFS Production V1.0）

`production-v1.0.0` 是冻结黄金基线：不得移动、重写或 force push 该 tag。

QNAP Deployment 是 deployment adaptation，不改变 V1.0 Rust Core、UI 或正式 image。

## 最终生产运行环境

- QNAP LAN IP：`192.168.120.138`
- DUFS port：`5100`
- runtime：`/share/Container/dufs`
- architecture：`amd64`
- runtime UID:GID：`1000:100`
- Production image：`dufs:0.46.0-custom-v1-faca49a`
- OCI revision：`faca49a59b6cfdf4a9331451355fc10e32a6f8b3`
- port mapping：`192.168.120.138:5100 -> 5000/tcp`
- restart policy：`unless-stopped`
- 最终人工 health：`{"status":"OK"}`

部署脚本位于 runtime 的 `scripts/` 下，并从自身位置计算 runtime root；因此同一套脚本可同时用于 Debian 的 runtime 和 QNAP 的 `/share/Container/dufs`。Compose 调用必须显式使用该 root 下的 `compose.yaml` 和 `.env`。

## QNAP data ACL 边界

`/share/Container/dufs/data` 当前最终 ACL 为：

```
user::rwx
user:admin:rwx
user:guest:---
group::---
group:administrators:rwx
mask::rwx
other::---
default:user::rwx
default:user:admin:rwx
default:user:guest:---
default:group::---
default:group:administrators:rwx
default:mask::rwx
default:other::---
```

QNAP 使用 ACL 继承。portable scripts 不负责修改 QNAP 全局 ACL、共享目录设置或整个 `/share/Container` 的权限。尤其不得对 production data 运行递归 `chmod` 或 `chown`，不得使用 `chmod 777`、`setfacl -b` 或 `setfacl -k`。

生产 selective restore 只可恢复 data 中不存在的安全相对路径，绝不覆盖已有文件；新建项继承 data 的既有默认 ACL。完整 disaster restore 必须由人工执行，不能自动化。

## Host compatibility

人工只读检查确认，QNAP host 使用 GNU bash `3.2.57`；当前没有 `python3`，也没有 `realpath`。OpenSSL 为 `3.0.9`，`/bin/sha256sum`、`/bin/tar`、`/usr/bin/find` 可用，且 `cp` 支持 `--no-preserve=ATTR_LIST`。脚本保持 Bash 3.2 兼容，不依赖 host `realpath`。

- `backup.sh` 可原生运行：即使 Docker、Python 或 realpath 不可用，仍可生成 archive、manifest 与 checksum。无法取得 OCI revision 时记录 `unknown`。
- `set-admin-password.sh` 及高级验收脚本需要 Docker command resolution：优先使用可执行的 `DOCKER_BIN`，否则使用 `command -v docker`；不会猜测 QNAP 安装路径、修改 PATH 或修改 Container Station。
- `restore.sh`、`phase7-acceptance.sh`、`phase8-acceptance.sh` 需要安全 Python：优先 `PYTHON_BIN`，其次 `python3`、`python`，并验证所需标准库。没有可用解释器时它们 fail closed，不会修改数据或 production。

QNAP 当前缺 Python 时，restore 被明确拒绝是设计行为，不代表 DUFS 服务故障。部署脚本不建议也不自动安装 Python、拉取 Python image，或修改 NAS 系统 Python/PATH。

## Docker PATH 与已部署脚本

已部署的 `scripts/` 包含 `backup.sh`、`restore.sh`、`set-admin-password.sh`、
`phase7-acceptance.sh`、`phase8-acceptance.sh`，权限为 `750`，owner/group 为 `1000:100`。

交互 SSH 的 PATH 包含 QNAP Container Station wrapper；当前人工观测 `command -v docker`
返回 `/share/ZFS530_DATA/.qpkg/container-station/bin/docker`，Docker Compose 为
`v2.29.1-qnap2`。非交互 SSH PATH 不含 Docker，因此应显式设置 `DOCKER_BIN`。这个路径
只是当前 NAS 实机观测值，绝不是 portable 脚本的固定路径；脚本规则始终为
`DOCKER_BIN` override → `command -v docker` → fail closed。

完整生产 cutover、backup/restore 实测与 rollback runbook 见
[`QNAP_PRODUCTION_CUTOVER_2026-08-09.md`](QNAP_PRODUCTION_CUTOVER_2026-08-09.md)。
