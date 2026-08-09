# DUFS Production V1.0 — Phase 0 Discovery

Date: 2026-08-09 (Asia/Singapore)

## Required paths

| Path | State during discovery |
| --- | --- |
| `/home/ldzcyh/aiDev/workspaces/dufs` | Absent; expected initial state |
| `/home/ldzcyh/dockerApps/dufs` | Absent; expected initial state |

Neither absence is a blocker. No existing DUFS source, production
configuration, data, logs, backups, or containers were present.

## Toolchain

| Component | Result |
| --- | --- |
| Git | `2.47.3` |
| GitHub CLI | `2.97.0` |
| Rust compiler | Not installed |
| Cargo | Not installed |
| Docker Engine | `29.7.2` |
| Docker Compose | `v5.4.0` |

Rust/Cargo are required for Phase 2 baseline validation, but do not block
Phase 1.

## GitHub and SSH

Host verification supplied and manually checked by the user is authoritative:

- GitHub CLI is authenticated as active account `ldzcyh309-prog`, uses SSH for
  Git operations, and has `gist`, `read:org`, and `repo` scopes.
- `gh api user --jq '.login'` returns `ldzcyh309-prog`.
- `GH_TOKEN`, `GITHUB_TOKEN`, `GH_HOST`, and `GH_CONFIG_DIR` are unset.
- `ssh -T git@github.com` authenticates as `ldzcyh309-prog`.
- `/etc/ssh/ssh_config.d/20-systemd-ssh-proxy.conf` resolves to
  `/usr/lib/systemd/ssh_config.d/20-systemd-ssh-proxy.conf`, which is
  `0644 root:root`; its parent directory is `0755 root:root`.

The initial Codex `gh` and SSH failures were caused by its execution
environment, and the reported `0777` SSH-file mode was symbolic-link metadata
rather than the resolved target's permissions. They were not host credential
or SSH-configuration failures. No GitHub login, SSH-key operation, or SSH
configuration modification was performed.

## Docker and network

Docker and Compose are installed and operational. Existing containers were
only listed and never changed. Port `5000/tcp` is not listening and is
currently available for DUFS. Existing published ports include 3002, 5005,
5244, 5432, 8008, 8095, 8096, 8097, 9180, 18080, and 18501.

## Result

Phase 0 is complete. Phase 1 may proceed. No Docker deployment, container,
user data, or unrelated `dockerApps` project was modified.
