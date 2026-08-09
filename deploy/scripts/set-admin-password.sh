#!/usr/bin/env bash
# 安全写入 runtime 管理员 SHA-512 crypt 认证规则；不得在源码仓库内运行。
set -Eeuo pipefail
umask 077

ROOT=/home/ldzcyh/dockerApps/dufs
ENV_FILE="$ROOT/.env"
DOCTOR="$ROOT/scripts/doctor.sh"
COMPOSE=(docker compose --project-name dufs --env-file "$ENV_FILE" -f "$ROOT/compose.yaml")

if [[ ${EUID} -ne $(id -u ldzcyh) ]] || [[ $(id -un) != ldzcyh ]]; then
  printf '请以 ldzcyh 用户运行此脚本。\n' >&2
  exit 1
fi

if [[ ! -f $ENV_FILE || ! -x $DOCTOR ]]; then
  printf 'runtime 环境不完整：需要 %s 与 %s。\n' "$ENV_FILE" "$DOCTOR" >&2
  exit 1
fi

if ! command -v openssl >/dev/null || ! openssl passwd -help 2>&1 | grep -q -- '-stdin'; then
  printf '当前 OpenSSL 不支持所需的 passwd -stdin；拒绝使用不安全替代方式。\n' >&2
  exit 1
fi

trap 'unset password password_confirm password_hash admin_rule; rm -f "${temporary_env:-}"' EXIT
read -r -s -p '输入新的 DUFS 管理员密码：' password
printf '\n'
read -r -s -p '再次输入新的 DUFS 管理员密码：' password_confirm
printf '\n'

if [[ -z $password ]]; then
  printf '密码不能为空。\n' >&2
  exit 1
fi
if [[ $password != "$password_confirm" ]]; then
  printf '两次密码不一致；未修改 .env。\n' >&2
  exit 1
fi

password_hash=$(printf '%s\n' "$password" | openssl passwd -6 -stdin)
unset password password_confirm
if [[ $password_hash != '$6$'* ]]; then
  printf '未生成 DUFS 所需的 SHA-512 crypt hash；未修改 .env。\n' >&2
  exit 1
fi
admin_rule="admin:${password_hash}@/:rw"

temporary_env=$(mktemp "$ROOT/.env.XXXXXX")
chmod 600 "$temporary_env"
found=0
while IFS= read -r line || [[ -n $line ]]; do
  if [[ $line == DUFS_ADMIN_AUTH=* ]]; then
    # 单引号让 Docker Compose 按字面量读取 SHA-512 crypt 中的 $。
    printf "DUFS_ADMIN_AUTH='%s'\n" "$admin_rule" >> "$temporary_env"
    found=1
  else
    printf '%s\n' "$line" >> "$temporary_env"
  fi
done < "$ENV_FILE"

if [[ $found -ne 1 ]]; then
  printf '未找到 DUFS_ADMIN_AUTH；未修改 .env。\n' >&2
  exit 1
fi

chown ldzcyh:ldzcyh "$temporary_env"
mv -f "$temporary_env" "$ENV_FILE"
temporary_env=
chmod 600 "$ENV_FILE"

# 仅输出验证结果，绝不输出认证规则或 hash。
"$DOCTOR"
"${COMPOSE[@]}" config -q
printf '管理员认证规则已安全写入 runtime .env，并通过 preflight。\n'
