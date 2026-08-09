# Phase 8 — Production Acceptance

## 验收环境

- 验收日期：2026-08-09
- Acceptance branch：`custom/v1`
- Acceptance commit：`4cd4707190dca9a2f8fb0e4e22684bc402da79d0`
- production image：`dufs:0.46.0-custom-v1-faca49a`
- container：`dufs`，`Config.User=1000:1000`
- 网络：host `127.0.0.1:5000`，container `0.0.0.0:5000`，IPv4-only

## 验收结果

| 项目 | 结果 |
| --- | --- |
| authentication | PASS：health 200；anonymous/invalid 为 401；admin 为 200 |
| 中文 UI / mobile | PASS：`DUFS 文件空间`、favicon、390×844、430×932 |
| asset routing | PASS：从 rendered HTML 动态解析 favicon、CSS、JS URL |
| filename compatibility | PASS：ASCII、中文、空格、空文件、文本、binary、长合法文件名 |
| directories / search | PASS：普通、中文、多级目录；ASCII/中文/不存在搜索 |
| archive / SHA-256 | PASS：ZIP 可读且内容正确；hash 一致 |
| WebDAV | PASS：PROPFIND Depth 0/1 均为 207 |
| Access Control | PASS：admin `/:rw`；无 anonymous/guest RW；`allow-all=false` |
| symlink / hidden policy | PASS：outside-root symlink 被阻断；hidden 规则有效，且 hidden 不替代 access control |
| non-root / ownership | PASS：container `1000:1000`；DUFS 新建内容与 logs 归属一致 |
| restart / recreate persistence | PASS：marker、认证、UI 和 ownership 均保持 |
| operations / logs | PASS：脚本语法、作用域与 fail-safe 检查通过；无 secret leak |
| network / Docker safety | PASS：仅 loopback IPv4；无其他项目修改、无 Docker prune |
| rollback readiness | PASS：当前 image、baseline 与 superseded audit image 可追踪 |

## Backup / Restore

Phase 8 初始 blocker 是 `restore.sh` fail-safe placeholder 返回 64。Phase 8.1
在 `539c54a` 中解决：backup、manifest、checksum、`--verify`、`--list`、隔离
restore、selective production-path restore、中文/binary integrity、ownership 以及
危险 archive/target 拒绝均通过。production DUFS 在 selective restore 后可正常读取。

完整 production disaster restore 保持为人工高风险运维流程，需要 staging、停机窗口
与明确确认；它不作为本次自动化验收的 FAIL 条件。

## Phase 8 发现与修复

验收脚本曾错误假设 `/favicon.svg` 必须可用。DUFS 实际从 rendered HTML 的
`__ASSETS_PREFIX__` 动态生成 asset URL。脚本已改为解析 production HTML，并用
`urljoin` 请求真实 favicon、CSS、JS URL。这是验收脚本 bug，不是 DUFS UI regression。

## Verdict

**PASS**

Notes：完整 production disaster restore 仍需人工 staging、停机窗口和明确运维确认。
