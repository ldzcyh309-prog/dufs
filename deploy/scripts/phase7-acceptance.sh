#!/usr/bin/env bash
# Phase 7 本机交互式验收：凭据仅保存在进程内存，测试只使用专用目录。
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$ROOT/.env"
TEST_DIR=".dufs-phase7-acceptance"
TEST_FILE="$TEST_DIR/上传下载验证.txt"
TEST_CONTENT='DUFS Phase 7 专用测试内容'
MARKER_FILE="$ROOT/data/$TEST_DIR/.dufs-phase7-marker"
CLEANUP_ONLY=${1:-}

resolve_python() {
  local candidate
  if [[ -n ${PYTHON_BIN:-} ]]; then candidate=$PYTHON_BIN; else candidate=$(command -v python3 2>/dev/null || command -v python 2>/dev/null || true); fi
  if [[ -z $candidate || ! -x $candidate ]] || ! "$candidate" -c 'import base64, hashlib, urllib.request' >/dev/null 2>&1; then
    printf 'Phase 7 需要 Python；当前 host 未提供；未修改 production。\n' >&2; return 69
  fi
  PYTHON_BIN=$candidate
}

resolve_docker() {
  local candidate
  if [[ -n ${DOCKER_BIN:-} ]]; then candidate=$DOCKER_BIN; else candidate=$(command -v docker 2>/dev/null || true); fi
  if [[ -z $candidate || ! -x $candidate ]]; then printf '未找到可执行 Docker；请设置 DOCKER_BIN 或在包含 docker 的运行环境中执行。\n' >&2; return 69; fi
  DOCKER_BIN=$candidate
}

runtime_http_base_url() {
  local host port
  host=$(awk -F= '$1 == "DUFS_HOST_IP" {sub(/\r$/, "", $2); print $2; exit}' "$ENV_FILE")
  port=$(awk -F= '$1 == "DUFS_PORT" {sub(/\r$/, "", $2); print $2; exit}' "$ENV_FILE")
  [[ $host =~ ^[A-Za-z0-9.-]+$ ]] || { printf 'DUFS_HOST_IP 无效。\n' >&2; return 65; }
  [[ $port =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 )) || {
    printf 'DUFS_PORT 必须是 1-65535 的数字。\n' >&2; return 65;
  }
  [[ $host == 0.0.0.0 ]] && host=127.0.0.1
  printf 'http://%s:%s\n' "$host" "$port"
}

BASE_URL=$(runtime_http_base_url)
resolve_python
resolve_docker
COMPOSE=("$DOCKER_BIN" compose --project-name dufs --env-file "$ENV_FILE" -f "$ROOT/compose.yaml")

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
  printf '%s' "$password" | "$PYTHON_BIN" -c '
import base64, hashlib, sys, urllib.error, urllib.parse, urllib.request
base_url, method, path, expected, body = sys.argv[1:6]
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
    encode_url_path(base_url + path),
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
' "$BASE_URL" "$method" "$path" "$expected" "$body"
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
curl -fsS --max-time 10 "$BASE_URL/__dufs__/health" >/dev/null
request GET "/$TEST_FILE" 200 "$TEST_CONTENT"

"${COMPOSE[@]}" down
"${COMPOSE[@]}" up -d
for _ in $(seq 1 15); do
  if curl -fsS --max-time 3 "$BASE_URL/__dufs__/health" >/dev/null; then break; fi
  sleep 1
done
curl -fsS --max-time 3 "$BASE_URL/__dufs__/health" >/dev/null
request GET "/$TEST_FILE" 200 "$TEST_CONTENT"
request DELETE "/$TEST_FILE" 204
request DELETE "/$TEST_DIR/.dufs-phase7-marker" 204
request DELETE "/$TEST_DIR" 204

printf 'Phase 7 交互式认证、功能、restart 与 recreate 验收通过。\n'
