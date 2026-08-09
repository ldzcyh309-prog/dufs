#!/usr/bin/env bash
# 生成不含 runtime .env 的 DUFS 备份；支持只备份指定 data 相对路径。
set -Eeuo pipefail
umask 077

ROOT=/home/ldzcyh/dockerApps/dufs
BACKUP_DIR="$ROOT/backup"
SOURCE_REPO=/home/ldzcyh/aiDev/workspaces/dufs
data_path=

usage() {
  cat <<'EOF'
用法：backup.sh [--data-path 相对路径]

默认备份 compose.yaml、config、assets 和完整 data；不会备份 runtime .env、logs
或已有 backup。--data-path 仅备份该 data 相对路径，适合隔离验收。
EOF
}

safe_relative_path() {
  [[ -n $1 && $1 != /* && $1 != . && $1 != .. && $1 != *'..'* && $1 != *$'\n'* ]]
}

case ${1:-} in
  '') ;;
  --help|-h) usage; exit 0 ;;
  --data-path)
    [[ $# -eq 2 ]] || { usage >&2; exit 64; }
    safe_relative_path "$2" || { printf 'data 路径必须是安全的相对路径。\n' >&2; exit 64; }
    data_path=$2
    ;;
  *) usage >&2; exit 64 ;;
esac

[[ -d $BACKUP_DIR && -f $ROOT/compose.yaml && -d $ROOT/config && -d $ROOT/assets && -d $ROOT/data ]] || {
  printf 'DUFS runtime 目录不完整。\n' >&2
  exit 1
}
if [[ -n $data_path && ! -e "$ROOT/data/$data_path" ]]; then
  printf '指定 data 路径不存在。\n' >&2
  exit 66
fi

stamp=$(date -u +%Y%m%dT%H%M%SZ)
archive="$BACKUP_DIR/dufs-backup-${stamp}.tar.gz"
checksum="$archive.sha256"
stage=$(mktemp -d "$BACKUP_DIR/.dufs-backup.XXXXXX")
temporary_archive="$BACKUP_DIR/.dufs-backup-${stamp}.tar.gz"
temporary_checksum="$BACKUP_DIR/.dufs-backup-${stamp}.sha256"
trap 'rm -rf -- "$stage" "$temporary_archive" "$temporary_checksum"' EXIT

revision=$(git -C "$SOURCE_REPO" rev-parse HEAD 2>/dev/null || printf 'unknown')
image=$(awk -F= '$1 == "DUFS_IMAGE" {print $2; exit}' "$ROOT/.env")
components='compose.yaml,config,assets,data'
data_member=data
if [[ -n $data_path ]]; then
  components="compose.yaml,config,assets,data/$data_path"
  data_member="data/$data_path"
fi
cat > "$stage/manifest.txt" <<EOF
format_version=1
created_utc=$stamp
dufs_image=$image
source_git_revision=$revision
components=$components
runtime_env=included:no
logs=included:no
EOF

tar -C "$ROOT" -czf "$temporary_archive" compose.yaml config assets "$data_member" -C "$stage" manifest.txt
chmod 600 "$temporary_archive"
digest=$(sha256sum "$temporary_archive" | awk '{print $1}')
printf '%s  %s\n' "$digest" "$(basename "$archive")" > "$temporary_checksum"
chmod 600 "$temporary_checksum"
mv -f "$temporary_archive" "$archive"
mv -f "$temporary_checksum" "$checksum"
printf '%s\n' "$archive"
