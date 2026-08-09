#!/usr/bin/env bash
# Phase 7 本机交互式验收：凭据仅保存在进程内存，测试只使用专用目录。
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$ROOT/.env"
COMPOSE=(docker compose --project-name dufs --env-file "$ENV_FILE" -f "$ROOT/compose.yaml")
TEST_DIR=".dufs-phase7-acceptance"
TEST_FILE="$TEST_DIR/上传下载验证.txt"
TEST_CONTENT='DUFS Phase 7 专用测试内容'
MARKER_FILE="$ROOT/data/$TEST_DIR/.dufs-phase7-marker"
CLEANUP_ONLY=${1:-}

cleanup_test_data() {
  if [[ -d "$ROOT/data/$TEST_DIR" ]]; then
    if [[ -f $MARKER_FILE ]]; then
      # 使用 DUFS authenticated HTTP DELETE，避免依赖宿主机文件 owner。
      request DELETE "/$TEST_FILE" 204 || true
      request DELETE "/$TEST_DIR/.dufs-phase7-marker" 204 || true
      request DELETE "/$TEST_DIR" 204 || true
      if [[ -e "$ROOT/data/$TEST_DIR" ]]; then
        printf '专用验收测试数据清理失败：%s\n' "$ROOT/data/$TEST_DIR" >&2
        return 1
      fi
      printf '已清理专用验收测试数据。\n'
    else
      printf '发现未带本脚本标记的同名目录；为保护数据拒绝删除：%s\n' "$ROOT/data/$TEST_DIR" >&2
      return 1
    fi
  fi
}

on_exit() {
  local status=$?
  if ! cleanup_test_data; then
    printf '请人工检查上述专用目录；脚本未触碰其他数据。\n' >&2
  fi
  unset password
  exit "$status"
}

read -r -s -p '输入 DUFS 管理员密码以执行 Phase 7 验收：' password
printf '\n'
if [[ -z $password ]]; then
  printf '密码不能为空。\n' >&2
  exit 1
fi
trap on_exit EXIT

# 密码经 stdin 进入 Python；不会出现在 shell history、命令参数或临时文件中。
request() {
  local method=$1 path=$2 expected=$3 body=${4-}
  printf '%s' "$password" | python3 -c '
import base64, hashlib, sys, urllib.error, urllib.parse, urllib.request
method, path, expected, body = sys.argv[1:5]
password = sys.stdin.buffer.read()
token = base64.b64encode(b"admin:" + password).decode("ascii")

def encode_url_path(url):
    """编码 path 和 query，保留 URL 结构及已有合法 percent-encoding。"""
    parts = urllib.parse.urlsplit(url)
    encoded_path = urllib.parse.quote(parts.path, safe="/%:@-._~!$&\u0027()*+,;=")
    encoded_query = urllib.parse.quote(parts.query, safe="%=&/:?@-._~!$\u0027()*+,;")
    return urllib.parse.urlunsplit((
        parts.scheme, parts.netloc, encoded_path, encoded_query, parts.fragment
    ))

request = urllib.request.Request(
    encode_url_path("http://127.0.0.1:5000" + path),
    data=body.encode("utf-8") if method in ("PUT", "PATCH", "POST") else None,
    method=method,
    headers={"Authorization": "Basic " + token},
)
try:
    with urllib.request.urlopen(request, timeout=10) as response:
        status, payload = response.status, response.read()
except urllib.error.HTTPError as error:
    status, payload = error.code, error.read()
if status != int(expected):
    raise SystemExit(f"{method} {path}: expected {expected}, got {status}")
if path.endswith("?hash") and payload.decode().strip() != hashlib.sha256(body.encode("utf-8")).hexdigest():
    raise SystemExit("hash 验证失败")
if path.endswith("上传下载验证.txt") and method == "GET" and payload.decode("utf-8") != body:
    raise SystemExit("下载内容验证失败")
if path == "/" and "DUFS 文件空间" not in payload.decode("utf-8", "replace"):
    raise SystemExit("中文 UI 标题验证失败")
print(f"ok: {method} {path} -> {status}")
' "$method" "$path" "$expected" "$body"
}

cleanup_test_data
if [[ -n $CLEANUP_ONLY ]]; then
  if [[ $CLEANUP_ONLY != --cleanup-only ]]; then
    printf '仅支持 --cleanup-only。\n' >&2
    exit 64
  fi
  printf '专用验收测试数据已通过 DUFS HTTP DELETE 清理。\n'
  exit 0
fi

request GET / 200
request MKCOL "/$TEST_DIR" 201
# 标记文件证明此目录由本脚本创建，允许失败后的安全重试清理。
request PUT "/$TEST_DIR/.dufs-phase7-marker" 201 'phase7-marker'
request PUT "/$TEST_FILE" 201 "$TEST_CONTENT"
request GET "/$TEST_FILE" 200 "$TEST_CONTENT"
request GET "/?q=上传下载验证" 200
request GET "/$TEST_DIR?zip" 200
request GET "/$TEST_FILE?hash" 200 "$TEST_CONTENT"
request PROPFIND "/$TEST_DIR" 207

ln -s /etc/passwd "$ROOT/data/$TEST_DIR/外部符号链接"
request GET "/$TEST_DIR/外部符号链接" 404
rm "$ROOT/data/$TEST_DIR/外部符号链接"

"${COMPOSE[@]}" restart
sleep 2
curl -fsS --max-time 10 http://127.0.0.1:5000/__dufs__/health >/dev/null
request GET "/$TEST_FILE" 200 "$TEST_CONTENT"

"${COMPOSE[@]}" down
"${COMPOSE[@]}" up -d
for _ in $(seq 1 15); do
  if curl -fsS --max-time 3 http://127.0.0.1:5000/__dufs__/health >/dev/null; then break; fi
  sleep 1
done
curl -fsS --max-time 3 http://127.0.0.1:5000/__dufs__/health >/dev/null
request GET "/$TEST_FILE" 200 "$TEST_CONTENT"
request DELETE "/$TEST_FILE" 204
request DELETE "/$TEST_DIR/.dufs-phase7-marker" 204
request DELETE "/$TEST_DIR" 204

printf 'Phase 7 交互式认证、功能、restart 与 recreate 验收通过。\n'
