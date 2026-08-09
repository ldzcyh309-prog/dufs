# Decisions

## D-001: Intentional IPv4-only V1 runtime baseline

The household/lab network, xhydebian host, and Mihomo transparent proxy
intentionally disable IPv6. DUFS Production V1 therefore uses container IPv4
`0.0.0.0:5000` and loopback host publishing `127.0.0.1:5000` only. The Phase 2
upstream tests that require `::1` are expected to be incompatible with this
policy; they are neither a DUFS regression nor a host fault. Do not enable
IPv6 or modify upstream tests merely to change this result.

## D-002: No service start in Phase 3

Phase 3 creates an inspectable production skeleton without starting a service.
Access control has no real credentials yet and is deferred to Phase 4. The
Phase 2 baseline image reference exists only to validate Compose interpolation;
the final custom production image is deferred to Phase 6.

## D-003: SHA-512 Basic admin authentication with least privilege

V1 has one `admin` account with `/:rw`, supplied only through runtime `.env`
as a SHA-512 crypt hash. DUFS uses Basic authentication for hashed passwords.
Global permissions enable upload, delete, search, archive, and hash, but keep
`allow-all` and symlink traversal false. Account and global permissions both
apply, so neither alone grants an operation. No anonymous or guest rule is
created.
