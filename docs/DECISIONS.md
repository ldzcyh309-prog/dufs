# Decisions

## D-001: IPv4-only V1 runtime baseline

The Phase 2 upstream test environment could not bind `::1`. Phase 3 therefore
uses container IPv4 `0.0.0.0` and loopback host publishing `127.0.0.1` only.
This does not modify upstream and does not attempt to repair host IPv6.

## D-002: No service start in Phase 3

Phase 3 creates an inspectable production skeleton without starting a service.
Access control has no real credentials yet and is deferred to Phase 4. The
Phase 2 baseline image reference exists only to validate Compose interpolation;
the final custom production image is deferred to Phase 6.
