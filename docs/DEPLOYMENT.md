# Deployment

## Phase 3 skeleton

The runtime directory is `/home/ldzcyh/dockerApps/dufs`. It contains Compose,
configuration, assets, data, logs, backups, and project-scoped scripts.

The current `.env` uses the Phase 2 local baseline image only for static
Compose validation. It is not a production image selection. Phase 3 does not
start DUFS; production start is deferred until security configuration, custom
image construction, and deployment approval are complete.

The default host binding is `127.0.0.1:5000`. The container configuration uses
IPv4 `0.0.0.0:5000`. IPv6 is disabled by the established production network
policy for xhydebian, Mihomo transparent proxy, and the household/lab network.
The upstream `::1` test incompatibility is therefore expected and is not a
production defect to repair.

Run `scripts/doctor.sh` from the runtime directory to inspect, but not repair,
the project. Its Compose commands are scoped to project `dufs` only.

Phase 4 adds the `DUFS_ADMIN_AUTH` runtime-only secret variable. It must be a
SHA-512 crypt `admin:<hash>@/:rw` rule before deployment. The current sentinel
placeholder deliberately causes `doctor.sh`/`start.sh` to reject a start until
the user supplies that final secret.

## Phase 5 assets

The runtime `/home/ldzcyh/dockerApps/dufs/assets` directory contains the
reviewed contents of `custom/assets/` from this repository. Compose mounts it
read-only and passes `--assets /assets`. Before a future deployment or update,
copy the reviewed tracked assets into that runtime directory, then use
`docker compose config` to confirm the mount and command. Do not place secrets
or user data in assets.

## Phase 6 自定义镜像引用

Phase 6 验证通过后，runtime `.env` 的 `DUFS_IMAGE` 更新为本地不可变风格标签
`dufs:0.46.0-custom-v1-153a36f`。它不是 `latest`，且同时保留便利 alias
`dufs:0.46.0-custom-v1`。`.env` 的管理员 sentinel、0600 权限、IPv4-only
发布和其他变量均不变。

本阶段只执行 `docker compose config` 静态验证，不执行 `docker compose up`。
Phase 7 获得明确授权前，正式 DUFS 容器不得启动。
