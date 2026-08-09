#!/usr/bin/env bash
# 安全验证并恢复 DUFS 备份；默认只允许恢复至显式隔离目录。
set -Eeuo pipefail
umask 077

ROOT=/home/ldzcyh/dockerApps/dufs
DATA_ROOT="$ROOT/data"
SOURCE_REPO=/home/ldzcyh/aiDev/workspaces/dufs

usage() {
  cat <<'EOF'
用法：
  restore.sh --help
  restore.sh --verify BACKUP
  restore.sh --list BACKUP
  restore.sh --target DIRECTORY BACKUP
  restore.sh --production-path RELATIVE_PATH --apply BACKUP

--target 只允许空的隔离目录，拒绝生产目录和危险目录。
--production-path 仅恢复 data 内尚不存在的安全相对路径，必须同时给出 --apply。
不会恢复 runtime .env；不会停止任何 container。
EOF
}

safe_relative_path() {
  [[ -n $1 && $1 != /* && $1 != . && $1 != .. && $1 != *'..'* && $1 != *$'\n'* ]]
}

verify_archive() {
  local archive=$1 checksum="${1}.sha256"
  [[ -f $archive && -r $archive ]] || { printf '备份文件不存在或不可读。\n' >&2; return 66; }
  [[ -f $checksum && -r $checksum ]] || { printf '缺少 checksum 文件。\n' >&2; return 65; }
  local expected actual
  expected=$(awk 'NR == 1 {print $1}' "$checksum")
  actual=$(sha256sum "$archive" | awk '{print $1}')
  [[ $expected =~ ^[a-fA-F0-9]{64}$ && $expected == "$actual" ]] || {
    printf 'checksum 验证失败。\n' >&2
    return 65
  }
  python3 - "$archive" <<'PY'
import posixpath, sys, tarfile
archive = sys.argv[1]
allowed = ('compose.yaml', 'config', 'assets', 'data', 'manifest.txt')
try:
    with tarfile.open(archive, 'r:gz') as tar:
        names = set()
        for member in tar.getmembers():
            name = member.name
            normalized = posixpath.normpath(name)
            if (not name or name.startswith('/') or normalized == '..' or
                    normalized.startswith('../') or name != normalized or
                    member.issym() or member.islnk() or
                    member.ischr() or member.isblk() or member.isfifo()):
                raise ValueError('unsafe member')
            if not any(name == item or name.startswith(item + '/') for item in allowed):
                raise ValueError('unexpected member')
            names.add(name)
        if 'manifest.txt' not in names:
            raise ValueError('missing manifest')
except (tarfile.TarError, OSError, ValueError):
    raise SystemExit(65)
PY
  local status=$?
  if [[ $status -ne 0 ]]; then
    printf 'archive 安全检查失败。\n' >&2
    return 65
  fi
}

list_archive() {
  verify_archive "$1"
  tar -tzf "$1"
}

target_restore() {
  local target=$1 archive=$2 resolved
  [[ ! -e $target || -d $target ]] || { printf 'target 必须是目录。\n' >&2; return 64; }
  resolved=$(realpath -m "$target")
  case $resolved in
    /|/home|/home/ldzcyh|/home/ldzcyh/dockerApps|"$ROOT"|"$DATA_ROOT")
      printf 'target 是危险或 production 路径，已拒绝。\n' >&2; return 64 ;;
  esac
  if [[ -e $resolved ]] && [[ -n $(find "$resolved" -mindepth 1 -maxdepth 1 -print -quit) ]]; then
    printf 'target 非空，已拒绝覆盖。\n' >&2; return 64
  fi
  verify_archive "$archive"
  mkdir -p "$resolved"
  tar --no-same-owner --no-same-permissions -xzf "$archive" -C "$resolved"
  local uid gid
  uid=$(awk -F= '$1 == "DUFS_UID" {print $2; exit}' "$ROOT/.env")
  gid=$(awk -F= '$1 == "DUFS_GID" {print $2; exit}' "$ROOT/.env")
  [[ $uid =~ ^[0-9]+$ && $gid =~ ^[0-9]+$ ]] || { printf 'DUFS_UID/GID 无效。\n' >&2; return 65; }
  chown -R "$uid:$gid" "$resolved"
  chmod -R u+rwX,go-rwx "$resolved"
  printf '已安全恢复到隔离 target：%s\n' "$resolved"
}

production_path_restore() {
  local relative=$1 archive=$2 staging source target
  safe_relative_path "$relative" || { printf 'production path 必须是安全相对路径。\n' >&2; return 64; }
  target="$DATA_ROOT/$relative"
  [[ ! -e $target ]] || { printf 'production target 已存在，拒绝覆盖。\n' >&2; return 64; }
  staging=$(mktemp -d /tmp/dufs-restore.XXXXXX)
  if ! target_restore "$staging" "$archive"; then
    rm -rf -- "$staging"
    return 1
  fi
  source="$staging/data/$relative"
  if [[ ! -e $source ]]; then
    rm -rf -- "$staging"
    printf '备份不含请求的 data 路径。\n' >&2
    return 66
  fi
  mkdir -p -- "$(dirname "$target")"
  mv "$source" "$target"
  rm -rf -- "$staging"
  printf '已恢复指定 production data 路径。\n'
}

case ${1:-} in
  --help|-h|'') usage; exit 64 ;;
  --verify) [[ $# -eq 2 ]] || { usage >&2; exit 64; }; verify_archive "$2" ;;
  --list) [[ $# -eq 2 ]] || { usage >&2; exit 64; }; list_archive "$2" ;;
  --target) [[ $# -eq 3 ]] || { usage >&2; exit 64; }; target_restore "$2" "$3" ;;
  --production-path)
    [[ $# -eq 4 && $3 == --apply ]] || { usage >&2; exit 64; }
    production_path_restore "$2" "$4"
    ;;
  *) usage >&2; exit 64 ;;
esac
