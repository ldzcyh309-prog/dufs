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
