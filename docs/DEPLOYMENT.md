# Deployment

## Phase 3 skeleton

The runtime directory is `/home/ldzcyh/dockerApps/dufs`. It contains Compose,
configuration, assets, data, logs, backups, and project-scoped scripts.

The current `.env` uses the Phase 2 local baseline image only for static
Compose validation. It is not a production image selection. Phase 3 does not
start DUFS; production start is deferred until security configuration, custom
image construction, and deployment approval are complete.

The default host binding is `127.0.0.1:5000`. The container configuration uses
IPv4 `0.0.0.0:5000`; V1 does not depend on IPv6 because the upstream baseline
test environment cannot bind `::1`.

Run `scripts/doctor.sh` from the runtime directory to inspect, but not repair,
the project. Its Compose commands are scoped to project `dufs` only.
