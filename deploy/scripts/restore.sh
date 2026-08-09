#!/usr/bin/env bash
# 安全验证并恢复 DUFS 备份；默认只允许恢复至显式隔离目录。
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
DATA_ROOT="$ROOT/data"

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

runtime_uid_gid() {
  local uid gid
  uid=$(awk -F= '$1 == "DUFS_UID" {sub(/\r$/, "", $2); print $2; exit}' "$ROOT/.env")
  gid=$(awk -F= '$1 == "DUFS_GID" {sub(/\r$/, "", $2); print $2; exit}' "$ROOT/.env")
  [[ $uid =~ ^[0-9]+$ && $gid =~ ^[0-9]+$ ]] || {
    printf 'DUFS_UID/GID 无效。\n' >&2
    return 65
  }
  printf '%s:%s\n' "$uid" "$gid"
}

resolve_python() {
  local candidate
  if [[ -n ${PYTHON_BIN:-} ]]; then
    candidate=$PYTHON_BIN
  else
    candidate=$(command -v python3 2>/dev/null || command -v python 2>/dev/null || true)
  fi
  if [[ -z $candidate || ! -x $candidate ]] || ! "$candidate" -c 'import os, posixpath, sys, tarfile' >/dev/null 2>&1; then
    printf '当前主机缺少安全恢复所需的 Python 解释器；backup 功能不受影响；restore 已拒绝执行，未修改任何数据。\n' >&2
    return 69
  fi
  PYTHON_BIN=$candidate
}

canonical_path() {
  "$PYTHON_BIN" -c 'import os, sys; print(os.path.realpath(os.path.abspath(sys.argv[1])))' "$1"
}

dangerous_target() {
  local target=$1 ancestor=$ROOT
  [[ $target == "$ROOT" || $target == "$ROOT/"* ||
     $target == "$DATA_ROOT" || $target == "$DATA_ROOT/"* ]] && return 0
  while :; do
    [[ $target == "$ancestor" ]] && return 0
    [[ $ancestor == / ]] && break
    ancestor=$(dirname "$ancestor")
  done
  return 1
}

verify_archive() {
  local archive=$1 checksum="${1}.sha256"
  resolve_python || return
  [[ -f $archive && -r $archive ]] || { printf '备份文件不存在或不可读。\n' >&2; return 66; }
  [[ -f $checksum && -r $checksum ]] || { printf '缺少 checksum 文件。\n' >&2; return 65; }
  local expected actual
  expected=$(awk 'NR == 1 {print $1}' "$checksum")
  actual=$(sha256sum "$archive" | awk '{print $1}')
  [[ $expected =~ ^[a-fA-F0-9]{64}$ && $expected == "$actual" ]] || {
    printf 'checksum 验证失败。\n' >&2
    return 65
  }
  "$PYTHON_BIN" - "$archive" <<'PY'
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
  local target=$1 archive=$2 resolved canonical_root canonical_data_root
  resolve_python || return
  [[ ! -e $target || -d $target ]] || { printf 'target 必须是目录。\n' >&2; return 64; }
  canonical_root=$(canonical_path "$ROOT") || return 65
  canonical_data_root=$(canonical_path "$DATA_ROOT") || return 65
  ROOT=$canonical_root
  DATA_ROOT=$canonical_data_root
  resolved=$(canonical_path "$target") || return 65
  if dangerous_target "$resolved"; then
    printf 'target 是危险或 production 路径，已拒绝。\n' >&2
    return 64
  fi
  if [[ -e $resolved ]] && [[ -n $(find "$resolved" -mindepth 1 -maxdepth 1 -print -quit) ]]; then
    printf 'target 非空，已拒绝覆盖。\n' >&2; return 64
  fi
  verify_archive "$archive"
  mkdir -p "$resolved"
  tar --no-same-owner --no-same-permissions -xzf "$archive" -C "$resolved"
  local uid gid ownership
  ownership=$(runtime_uid_gid) || return
  uid=${ownership%:*}
  gid=${ownership#*:}
  chown -R "$uid:$gid" "$resolved"
  chmod -R u+rwX,go-rwx "$resolved"
  printf '已安全恢复到隔离 target：%s\n' "$resolved"
}

production_path_restore() {
  local relative=$1 archive=$2 staging source target canonical_data_root ownership uid gid
  resolve_python || return
  safe_relative_path "$relative" || { printf 'production path 必须是安全相对路径。\n' >&2; return 64; }
  canonical_data_root=$(canonical_path "$DATA_ROOT") || return 65
  DATA_ROOT=$canonical_data_root
  target=$(canonical_path "$DATA_ROOT/$relative") || return 65
  [[ $target == "$DATA_ROOT/"* ]] || {
    printf 'production path 超出 data 目录，已拒绝。\n' >&2; return 64;
  }
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
  ownership=$(runtime_uid_gid) || { rm -rf -- "$staging"; return; }
  uid=${ownership%:*}
  gid=${ownership#*:}
  # 新建目录由 data 父目录的 default ACL 继承。不得对 production data 递归 chmod/chown。
  mkdir -p -- "$(dirname "$target")"
  if [[ -f $source ]]; then
    cp --no-preserve=mode,ownership -- "$source" "$target"
    chown "$uid:$gid" "$target"
  elif [[ -d $source ]]; then
    mkdir -- "$target"
    chown "$uid:$gid" "$target"
    while IFS= read -r -d '' item; do
      local destination=${item#"$source"/}
      if [[ -d $item ]]; then
        mkdir -- "$target/$destination"
        chown "$uid:$gid" "$target/$destination"
      elif [[ -f $item ]]; then
        cp --no-preserve=mode,ownership -- "$item" "$target/$destination"
        chown "$uid:$gid" "$target/$destination"
      else
        rm -rf -- "$staging"
        printf '恢复源包含不安全成员，已拒绝。\n' >&2
        return 65
      fi
    done < <(find -P "$source" -mindepth 1 -print0)
  else
    rm -rf -- "$staging"
    printf '恢复源不是常规文件或目录，已拒绝。\n' >&2
    return 65
  fi
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
