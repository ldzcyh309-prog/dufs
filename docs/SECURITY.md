# Security

## Network policy

DUFS Production V1.0 is IPv4 only. IPv6 is disabled by the production network
policy of the household/lab network, xhydebian, and Mihomo transparent proxy.

```text
container bind: 0.0.0.0:5000
safe host publish: 127.0.0.1:5000
IPv6: disabled by policy
```

Future LAN, Tailscale, or public exposure requires an explicit later decision.
It must not be created by changing the default Compose publication.

## Authentication and permissions

DUFS uses a single `admin` role with `/:rw`. The runtime-only
`DUFS_ADMIN_AUTH` variable in `/home/ldzcyh/dockerApps/dufs/.env` must contain
an `admin:<sha-512-crypt-hash>@/:rw` rule before deployment. DUFS SHA-512
password hashes require Basic authentication, so Compose passes
`--auth-method basic`.

No actual password or hash is stored in the Git repository. The checked-in
examples contain only placeholders. The runtime `.env` is mode 0600 and
contains a fail-safe placeholder until the user supplies the final admin hash;
`doctor.sh` and `start.sh` reject that state.

DUFS account permissions do not override global permissions: both must allow
an operation. V1 enables the following global capabilities for the admin role:

| Capability | State |
| --- | --- |
| `allow-all` | false |
| upload | true |
| delete | true |
| search | true |
| archive | true |
| hash | true |
| symlink | false |

Symlink traversal remains disabled because it can expose content outside the
shared root. There is no anonymous rule and no guest account.

## Hidden names

The policy hides `.git`, `.DS_Store`, `Thumbs.db`, `*.tmp`, `*.part`, and
`*.lock`. DUFS hidden globs match names rather than paths and hide entries from
directory listings, search, and WebDAV listings. They are not access control
and do not replace authentication or path permissions.

## Logging and runtime files

DUFS writes project-scoped logs to `/home/ldzcyh/dockerApps/dufs/logs` through
the container path `/logs/dufs.log`. The configured format records time,
remote address, authenticated user, request line, and status. It deliberately
does not include the Authorization header.

Runtime directory owner is `ldzcyh:ldzcyh`; `.env` is 0600 and
`config/config.yaml` is 0640. Do not commit runtime `.env`, data, logs, or
backups.
