# QNAP NAS 部署 DUFS Production V1.0 —— 保姆级 / 教科书级生产部署教程

适用于 QNAP Container Station + Docker Compose + DUFS 0.46.0 Custom V1。

> 本手册只依据仓库文档、deploy/、compose、scripts 与 Git 历史，不包含任何 secret。生产状态见 [HANDOFF](../HANDOFF.md)，实际 cutover 见 [QNAP_PRODUCTION_CUTOVER_2026-08-09.md](QNAP_PRODUCTION_CUTOVER_2026-08-09.md)。

## 0. 最终架构

QNAP LAN 192.168.120.138；URL http://192.168.120.138:5100；container dufs；内部 5000/tcp；host bind 192.168.120.138:5100 -> 5000/tcp；runtime /share/Container/dufs；image dufs:0.46.0-custom-v1-faca49a；OCI revision faca49a59b6cfdf4a9331451355fc10e32a6f8b3；architecture amd64；UID:GID 1000:100；restart unless-stopped。production-v1.0.0 是 frozen golden baseline，QNAP adaptation 没有修改 Rust Core、UI 或 production image。

## 1. 流程总览

Phase 0 检查 → 1 runtime → 2 image → 3 compose/config/assets/.env → 4 UID/GID → 5 ACL → 6 preflight → 7 启动 → 8 health/auth/upload → 9 scripts → 10 backup → 11 restore → 12 接管 → 13 rollback → 14 运维 → 15 升级/重建 → 16 排障 → 17 验收。

## Phase 0：部署前检查

【做什么】确认架构、Container Station、端口、磁盘和工具。【在哪里】QNAP 交互式 SSH。【为什么】提前发现 host 限制。

```bash
uname -m
id
docker version
docker compose version
hostname -I
df -h /share/Container
bash --version | head -1
openssl version
for c in python3 realpath sha256sum tar find cp getfacl setfacl rsync; do printf '%-12s: ' "$c"; command -v "$c" || true; done
ss -lntp 2>/dev/null | grep -E ':(5000|5100)\b' || true
netstat -lnt 2>/dev/null | grep -E ':(5000|5100)\b' || true
```

实机：bash 3.2.57、Compose v2.29.1-qnap2、OpenSSL 3.0.9；python3 和 realpath 不存在是允许状态。5000 已被其他 QNAP 服务占用，DUFS 使用 5100；不要停止占用者。

### Docker PATH 陷阱

交互 PATH 含 /share/ZFS530_DATA/.qpkg/container-station/bin，command -v docker 实测返回该 wrapper；非交互 PATH 为 /usr/bin:/bin:/usr/sbin:/sbin，所以 ssh qnap-nas 'docker compose version' 可能 command not found。这是 PATH 差异，不是 Docker 未安装。

```bash
DOCKER_BIN=/share/ZFS530_DATA/.qpkg/container-station/bin/docker
"$DOCKER_BIN" compose version
```

该路径只是当前 NAS 观测值，不能写进 portable 逻辑；规则是 DOCKER_BIN override → command -v docker → fail closed。

## Phase 1：runtime

【QNAP】`mkdir -p /share/Container/dufs/{config,assets,data,logs,backup,scripts}`。目录职责：compose 编排、.env secret、config、assets、data、logs、backup、scripts。成功标准：目录齐全；.env 不进 Git。

## Phase 2：image migration

【xhydebian 192.168.120.130】

```bash
docker image inspect dufs:0.46.0-custom-v1-faca49a
docker save dufs:0.46.0-custom-v1-faca49a | gzip > /tmp/dufs-0.46.0-custom-v1-faca49a.tar.gz
sha256sum /tmp/dufs-0.46.0-custom-v1-faca49a.tar.gz
```

传输 archive 和 checksum 后【QNAP】：

```bash
sha256sum dufs-0.46.0-custom-v1-faca49a.tar.gz
docker load -i dufs-0.46.0-custom-v1-faca49a.tar.gz
docker image inspect dufs:0.46.0-custom-v1-faca49a --format 'id={{.Id}} arch={{.Architecture}} revision={{index .Config.Labels "org.opencontainers.image.revision"}} version={{index .Config.Labels "org.opencontainers.image.version"}}'
```

记录：源 ID sha256:a18751a7bb1cf77209b180c558a71cee7108a121cafd04c0f2ec29f0658276ce；archive 两端 checksum ca64e93c1e0820706c033a63b5060efa836599dcb6c0764b9ce1b5b66047131a；QNAP ID sha256:c645e3272251e8e7ee8a1275a2bdba72abccabde29e379eee3c02e87e3aa888a。host image store 可使 ID 不同；checksum、load、labels、arch 正确即可，不要 rebuild/删 image。

## Phase 3：compose、config、assets、.env

compose 来自 deploy/examples/compose.yaml：config/assets 只读，data/logs 读写，用户 1000:100，restart unless-stopped，LAN bind 192.168.120.138:5100。非 secret 模板：

```dotenv
COMPOSE_PROJECT_NAME=dufs
DUFS_IMAGE=dufs:0.46.0-custom-v1-faca49a
DUFS_HOST_IP=192.168.120.138
DUFS_PORT=5100
DUFS_DATA_DIR=/share/Container/dufs/data
DUFS_CONFIG_DIR=/share/Container/dufs/config
DUFS_ASSETS_DIR=/share/Container/dufs/assets
DUFS_LOGS_DIR=/share/Container/dufs/logs
DUFS_RESTART_POLICY=unless-stopped
DUFS_UID=1000
DUFS_GID=100
DUFS_ADMIN_AUTH='<此处填写真实 SHA-512 crypt 管理员认证规则>'
```

【QNAP】安全交付真实 .env，执行 `chmod 600 .env`。不要读取、输出或提交认证规则。重置密码才运行 scripts/set-admin-password.sh（hidden input、二次确认、SHA-512 crypt、preflight、0600）；本次 cutover 未 rotation。

## Phase 4：UID/GID

【QNAP】`id 1000; getent group 100; stat -c '%u:%g %a %n' config assets data logs backup scripts`。这是检查，不是递归修复；禁止 production data 的 chmod/chown -R。

## Phase 5：QNAP ACL（核心）

最终 data ACL：

```text
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

硬边界：group::---、other::---、default:group::---、default:other::---。先【QNAP】`getfacl data`，创建测试文件后再 getfacl。实机曾因 default:other::rwx 继承造成 0777，根因是 QNAP ACL，不是 UID/GID。已确认 runtime 的最小修复记录（不是任何 NAS 无脑命令）：

```bash
setfacl -m d:o::--- data
setfacl -m d:g::--- data
setfacl -m o::---,g::--- data
```

禁止 chmod 777、递归 chmod/chown、setfacl -b/-k、修改全局或整个 /share/Container ACL。Zero-Data Cutover 没有正式数据迁移；实测 rsync 即使 --no-perms/--no-owner/--no-group 或 --chmod=ugo=rwX 仍会产生 group::r-x/r--/rw-。不要 rsync -a production data；未来须另开 ACL-aware procedure。

## Phase 6：preflight

【QNAP】

```bash
cd /share/Container/dufs
docker compose --project-name dufs --env-file .env -f compose.yaml config -q
```

非交互使用 DOCKER_BIN override。无输出且 return 0 才成功；不要跳过。

## Phase 7：启动

```bash
docker compose --project-name dufs --env-file .env -f compose.yaml up -d
docker compose --project-name dufs --env-file .env -f compose.yaml ps
docker inspect dufs --format 'status={{.State.Status}} user={{.Config.User}} restart={{.HostConfig.RestartPolicy.Name}}'
docker port dufs
curl -fsS http://192.168.120.138:5100/__dufs__/health
```

成功：running、1000:100、unless-stopped、LAN port、health {"status":"OK"}。浏览器打开该 URL；拒绝连接先查 ps/port/logs。

## Phase 8：验收

【QNAP】未认证 `curl -i http://192.168.120.138:5100/` 应 401；认证用 `curl -i -u admin ...`（密码隐藏提示，不写命令）；用 `curl --upload-file` 上传、再 GET 下载并比对。验证 custom UI/assets、data ACL、.env 0600。Phase7/8 是高级工具，不是日常启动；QNAP 无 Python，只有 source fixture/portability PASS、dependency preflight PASS，full QNAP execution not performed。

## Phase 9：scripts

复制 deploy/scripts 到 runtime，QNAP 执行 `chmod 750 scripts/*.sh`。backup.sh：日常可用、Docker 可选、无需 Python、低风险；restore.sh：需 Python、高风险、fail closed；set-admin-password.sh：需 Docker/OpenSSL、中高风险；phase7/8：需 Docker+Python、维护窗口、高风险、会操作专用数据。

## Phase 10：backup

【QNAP】

```bash
./scripts/backup.sh
latest=$(ls -t backup/dufs-backup-*.tar.gz | head -1)
sha256sum -c "$latest.sha256"
tar -tzf "$latest" | sed -n '1,80p'
```

默认包含 compose/config/assets/data，不含 .env、logs、backup；产出 tar.gz、manifest、.sha256，mode 600。真实文件 dufs-backup-20260809T150747Z.tar.gz checksum PASS；manifest image=dufs:0.46.0-custom-v1-faca49a、revision=faca49a59b6cfdf4a9331451355fc10e32a6f8b3、runtime_env=included:no、logs=included:no。Docker 不可用时 revision 可记录 unknown。

## Phase 11：restore

restore 解析 PYTHON_BIN→python3→python；当前 QNAP 无 Python 返回 69，不修改 data；实测 data_unchanged=YES、restore_fail_closed=PASS。不要降低 traversal/link/device/FIFO/checksum 验证，不用 grep 代替 Python，不自动安装 Python 或拉 Python image。完整 disaster restore 是人工高风险操作。

## Phase 12–13：接管与 rollback

QNAP 是唯一 Primary。rollback 节点 xhydebian 192.168.120.130，runtime /home/ldzcyh/dockerApps/dufs，container Exited (0)，保留 runtime/.env/config/assets/data/backup/image/compose；备份 dufs-backup-20260809T152708Z.tar.gz、dufs-backup-20260809T151445Z.tar.gz。确认 authoritative data source 后【xhydebian】：

```bash
cd /home/ldzcyh/dockerApps/dufs
docker compose --env-file .env -f compose.yaml start
curl -fsS http://127.0.0.1:5000/__dufs__/health
```

QNAP 有正式数据时禁止旧节点和 QNAP 同时写入，防止 dual-primary/split-brain。

## Phase 14：运维与重启检查

【QNAP】运行 `docker compose ps`、`docker inspect`、health curl、`docker port`、`getfacl data`、`ls -l backup`。unless-stopped 不保证 NAS reboot 后一定正常，必须人工确认 container、health、port、ACL、backup。

## Phase 15：升级与灾难重建

V1.0 冻结；升级必须新 branch、测试、image、acceptance、release，不覆盖 frozen tag。重建顺序：新 NAS/Container Station → runtime → image → compose → config → assets → 单独安全交付 .env → ACL → scripts → data restore → acceptance → cutover。archive 不含 .env，secret 必须单独保管。

## Phase 16：常见排障

- 非交互找不到 docker：PATH 差异，设置 DOCKER_BIN；不要硬编码 ZFS path。
- 5000 occupied：保持 5100，不停其他服务。
- image ID 不同：核对 archive checksum、labels、arch；不要 rebuild。
- health/连接失败：查 ps、inspect、logs、port；不要盲目 down。
- 401：隐藏输入认证；不把密码写 URL/命令。
- 770/777 或 ACL 错：getfacl 后隔离测试和最小修复；不 chmod 777、chmod/chown -R、setfacl -b/-k。
- revision unknown：诚实保留 unknown；不手写。
- restore 69、Python/realpath absent：已知 fail closed；不降级验证或自动装 Python。
- Compose/.env 错：修变量、chmod 600、重跑 config -q；不输出 .env。
- UI/assets 缺失：查只读挂载/版本；不改 image。
- reboot/restart 异常：按 Phase 14 人工检查；不同时启动 rollback。

## Phase 17：最终验收与 10 分钟复核

- [ ] amd64；image tag、OCI revision 正确
- • 已完成 Phase 5.2 文档编写。h 
   
    \- 教程：docs/QNAP_NAS_DUFS_PRODUCTION_DEPLOYMENT_TUTORIAL.md 
    \- 章节：Phase 0–17、ACL、镜像迁移、backup/restore、rollback、排障、重建与验收清单边 
    \- 规模：223 行  
    \- 更新：README.md、HANDOFF.md 交叉入口c 
    \- 安全审计：git diff --check 通过；未引入真实密码、hash、.env 或 token 
    \- Core/UI/image diff：未修改k 
   
    Git 提交受限：.git 当前为只读，无法创建 index.lock，因此未能 commit/push。验 
   
    本阶段未访问或修改 QNAP、xhydebian runtime，也未启停任何 production container。 

   

- [ ] compose config -q；UID:GID 1000:100；LAN bind 192.168.120.138:5100
- [ ] health OK；未认证 401；认证/upload/download/UI/assets PASS
- [ ] data ACL 四条硬边界 PASS；.env 0600；scripts 750
- [ ] backup checksum/manifest PASS；restore 缺 Python return 69 且 data unchanged
- [ ] rollback node known；HANDOFF updated

10 分钟复核仅快速重复 architecture、image、revision、config、UID/GID、bind、health/auth、ACL、secret 权限、scripts、backup、rollback、HANDOFF，不能替代全文。

## 交叉链接与安全框

[HANDOFF](../HANDOFF.md) · [QNAP_DEPLOYMENT](QNAP_DEPLOYMENT.md) · [cutover](QNAP_PRODUCTION_CUTOVER_2026-08-09.md) · [OPERATIONS](OPERATIONS.md)

绝对不要：docker system prune、docker image prune、未经批准的 docker compose down、rm -rf runtime、chmod 777、递归 chmod/chown production data、setfacl -b/-k、提交/输出 .env 或 DUFS_ADMIN_AUTH、硬编码 QNAP ZFS path、rsync -a production data，或同时启用两个可写 Primary。
