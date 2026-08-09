# QNAP Deployment（DUFS Production V1.0）

`production-v1.0.0` 是冻结黄金基线：不得移动、重写或 force push 该 tag。

QNAP Deployment 是 deployment adaptation，不改变 V1.0 Rust Core、UI 或正式 image。

## 目标运行环境

- QNAP LAN IP：`192.168.120.138`
- DUFS port：`5100`
- runtime：`/share/Container/dufs`
- architecture：`amd64`
- runtime UID:GID：`1000:100`
- Production image：`dufs:0.46.0-custom-v1-faca49a`

部署脚本位于 runtime 的 `scripts/` 下，并从自身位置计算 runtime root；因此同一套脚本可同时用于 Debian 的 runtime 和 QNAP 的 `/share/Container/dufs`。Compose 调用必须显式使用该 root 下的 `compose.yaml` 和 `.env`。

## QNAP data ACL 边界

`/share/Container/dufs/data` 已人工验证必须保持以下 ACL：

```
group::---
other::---
default:group::---
default:other::---
```

QNAP 使用 ACL 继承。portable scripts 不负责修改 QNAP 全局 ACL、共享目录设置或整个 `/share/Container` 的权限。尤其不得对 production data 运行递归 `chmod` 或 `chown`，不得使用 `chmod 777`、`setfacl -b` 或 `setfacl -k`。

生产 selective restore 只可恢复 data 中不存在的安全相对路径，绝不覆盖已有文件；新建项继承 data 的既有默认 ACL。完整 disaster restore 必须由人工执行，不能自动化。
