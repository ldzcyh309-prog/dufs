# Architecture

DUFS Production V1.0 separates planning, building, and running.

| Location | Responsibility |
| --- | --- |
| `/home/ldzcyh/aiDev/workspaces/dufs-project` | Project design and execution control documents |
| `/home/ldzcyh/aiDev/workspaces/dufs` | Upstream Fork, custom branch, builds, tests, templates, and documentation |
| `/home/ldzcyh/dockerApps/dufs` | Runtime Compose files, local environment, data, logs, backups, and scripts |

The Git repository contains only sanitized deployment examples. The runtime
directory is deliberately outside that repository so that production `.env`,
secrets, data, logs, and backups cannot be committed accidentally.

DUFS uses an explicit Compose project name, `dufs`. The xhydebian host, Mihomo
transparent proxy, and household/lab network intentionally use IPv4 only:
DUFS listens on `0.0.0.0:5000` in the container while the host publishes
`127.0.0.1:5000`. IPv6 is disabled by production network policy. Any broader
exposure is deferred to later explicit deployment approval. Phase 4 adds a
runtime-only admin secret structure; no authentication secret is stored in the
source repository.
