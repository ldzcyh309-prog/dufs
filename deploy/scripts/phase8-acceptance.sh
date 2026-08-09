#!/usr/bin/env bash
# Phase 8 黑盒验收：密码仅在进程内存中使用，所有可写操作限定在专用目录。
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
BASE=.dufs-phase8-acceptance
ARCHIVE=

read_runtime_uid_gid() {
  local uid gid
  uid=$(awk -F= '$1 == "DUFS_UID" {sub(/\r$/, "", $2); print $2; exit}' "$ROOT/.env")
  gid=$(awk -F= '$1 == "DUFS_GID" {sub(/\r$/, "", $2); print $2; exit}' "$ROOT/.env")
  [[ $uid =~ ^[0-9]+$ && $gid =~ ^[0-9]+$ ]] || { printf 'DUFS_UID/GID 无效。\n' >&2; exit 65; }
  printf '%s:%s\n' "$uid" "$gid"
}
read -r -s -p '输入 DUFS 管理员密码以执行 Phase 8 验收：' password
printf '\n'
[[ -n $password ]] || { printf '密码不能为空。\n' >&2; exit 1; }

run_http() {
  local action=$1
  python3 - "$action" "$BASE" 3<<<"$password" <<'PY'
import base64, hashlib, io, os, sys, urllib.error, urllib.parse, urllib.request, zipfile
from html.parser import HTMLParser
action, base = sys.argv[1:3]
password = os.fdopen(3, 'rb').read().rstrip(b'\n')
token = base64.b64encode(b'admin:' + password).decode('ascii')

def url(path):
    parts = urllib.parse.urlsplit('http://127.0.0.1:5000' + path)
    return urllib.parse.urlunsplit((parts.scheme, parts.netloc,
        urllib.parse.quote(parts.path, safe="/%:@-._~!$&'()*+,;="),
        urllib.parse.quote(parts.query, safe="%=&/:?@-._~!$'()*+,;"), parts.fragment))

BASE_URL = 'http://127.0.0.1:5000/'

def request_url(method, actual_url, expected, body=None, headers=None):
    h = {'Authorization': 'Basic ' + token}
    h.update(headers or {})
    req = urllib.request.Request(actual_url, data=body, method=method, headers=h)
    try:
        with urllib.request.urlopen(req, timeout=15) as r: status, data, content_type = r.status, r.read(), r.headers.get_content_type()
    except urllib.error.HTTPError as e: status, data, content_type = e.code, e.read(), e.headers.get_content_type()
    if status != expected: raise SystemExit(f'{method} {actual_url}: expected {expected}, got {status}')
    return data, content_type

def request(method, path, expected, body=None, headers=None):
    return request_url(method, url(path), expected, body, headers)[0]

class AssetParser(HTMLParser):
    """从实际渲染的 HTML 取得 asset href，避免依赖 DUFS 内部版本前缀。"""
    def __init__(self):
        super().__init__()
        self.assets = {}
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'link':
            rel = set(attrs.get('rel', '').lower().split())
            if 'icon' in rel and attrs.get('href'): self.assets['favicon'] = attrs['href']
            if 'stylesheet' in rel and attrs.get('href'): self.assets['css'] = attrs['href']
        if tag == 'script' and attrs.get('src'): self.assets['js'] = attrs['src']

def parse_asset_urls(html):
    parser = AssetParser()
    parser.feed(html)
    required = {'favicon', 'css', 'js'}
    if set(parser.assets) != required: raise SystemExit('渲染 HTML 缺少必要 asset URL')
    return parser.assets

files = {
    'ascii.txt': b'ascii phase8 text\n',
    '中文 文件.txt': '中文内容\n'.encode(),
    'space name.txt': b'space name\n',
    'empty.txt': b'',
    'binary.bin': bytes(range(256)) * 4,
    ('a' * 120) + '.txt': b'long filename\n',
    'marker.txt': b'phase8-persistence-marker\n',
}

def check_root():
    html = request('GET', '/', 200).decode('utf-8', 'replace')
    if 'DUFS 文件空间' not in html: raise SystemExit('中文 UI title 验证失败')
    for kind, href in parse_asset_urls(html).items():
        asset_url = urllib.parse.urljoin(BASE_URL, href)
        payload, content_type = request_url('GET', asset_url, 200)
        if not payload: raise SystemExit(f'{kind} asset 响应为空')
        if kind == 'favicon' and content_type not in ('image/svg+xml', 'image/x-icon', 'image/vnd.microsoft.icon'):
            raise SystemExit('favicon Content-Type 不符合预期')

if action == 'setup':
    check_root()
    request('MKCOL', '/' + base, 201)
    request('MKCOL', '/' + base + '/nested', 201)
    request('MKCOL', '/' + base + '/nested/中文目录', 201)
    for name, content in files.items(): request('PUT', '/' + base + '/' + name, 201, content)
    for hidden in ('.git', '.DS_Store', 'Thumbs.db', 'hidden.tmp', 'hidden.part', 'hidden.lock'):
        request('PUT', '/' + base + '/' + hidden, 201, b'hidden')
    for name, content in files.items():
        got = request('GET', '/' + base + '/' + name, 200)
        if hashlib.sha256(got).digest() != hashlib.sha256(content).digest(): raise SystemExit('下载 checksum 验证失败')
        digest = request('GET', '/' + base + '/' + name + '?hash', 200).decode().strip()
        if digest != hashlib.sha256(content).hexdigest(): raise SystemExit('hash 验证失败')
    for term in ('ascii', '中文', '不存在的阶段八文件'):
        request('GET', '/?q=' + term, 200)
    archive = request('GET', '/' + base + '?zip', 200)
    with zipfile.ZipFile(io.BytesIO(archive)) as z:
        if not any('中文 文件.txt' in n for n in z.namelist()): raise SystemExit('ZIP 中文成员缺失')
    for depth in ('0', '1'):
        request('PROPFIND', '/' + base, 207, headers={'Depth': depth})
    print('HTTP setup/files/search/archive/hash/WebDAV: passed')
elif action == 'persist':
    check_root()
    for name, content in files.items():
        got = request('GET', '/' + base + '/' + name, 200)
        if hashlib.sha256(got).digest() != hashlib.sha256(content).digest(): raise SystemExit('persistence 内容不一致')
    print('HTTP persistence/UI: passed')
elif action == 'symlink':
    request('GET', '/' + base + '/outside-link', 404)
    print('symlink blocking: passed')
elif action == 'cleanup':
    for name in list(files) + ['.git', '.DS_Store', 'Thumbs.db', 'hidden.tmp', 'hidden.part', 'hidden.lock']:
        try: request('DELETE', '/' + base + '/' + name, 204)
        except SystemExit: pass
    for path in ('nested/中文目录', 'nested', ''):
        try: request('DELETE', '/' + base + ('/' + path if path else ''), 204)
        except SystemExit: pass
    print('acceptance cleanup: passed')
else:
    raise SystemExit('未知验收动作')
PY
}

cleanup() {
  if [[ -n ${password:-} ]]; then run_http cleanup || printf '专用验收数据清理失败，请检查 %s。\n' "$BASE" >&2; fi
  if [[ -n ${ARCHIVE:-} ]]; then rm -f -- "$ARCHIVE" "${ARCHIVE}.sha256"; fi
  unset password
}
trap cleanup EXIT

run_http setup
ln -s /etc/passwd "$ROOT/data/$BASE/outside-link"
run_http symlink
rm -f -- "$ROOT/data/$BASE/outside-link"

runtime_ownership=$(read_runtime_uid_gid)
for path in "$ROOT/data/$BASE" "$ROOT/logs"; do
  [[ $(stat -c '%u:%g' "$path") == "$runtime_ownership" ]] || { printf 'ownership 验证失败。\n' >&2; exit 1; }
done

docker compose --project-name dufs --env-file "$ROOT/.env" -f "$ROOT/compose.yaml" restart
sleep 2
curl -fsS --max-time 10 http://127.0.0.1:5000/__dufs__/health >/dev/null
run_http persist

docker compose --project-name dufs --env-file "$ROOT/.env" -f "$ROOT/compose.yaml" down
docker compose --project-name dufs --env-file "$ROOT/.env" -f "$ROOT/compose.yaml" up -d
for _ in $(seq 1 15); do curl -fsS --max-time 3 http://127.0.0.1:5000/__dufs__/health >/dev/null && break; sleep 1; done
curl -fsS --max-time 3 http://127.0.0.1:5000/__dufs__/health >/dev/null
run_http persist

ARCHIVE=$($ROOT/scripts/backup.sh --data-path "$BASE")
$ROOT/scripts/restore.sh --verify "$ARCHIVE"
$ROOT/scripts/restore.sh --list "$ARCHIVE" >/dev/null
target=$(mktemp -d /tmp/dufs-phase8-restore.XXXXXX)
rmdir "$target"
$ROOT/scripts/restore.sh --target "$target" "$ARCHIVE"
[[ -f "$target/data/$BASE/中文 文件.txt" && -f "$target/data/$BASE/binary.bin" ]]
rm -rf -- "$target"

run_http cleanup
$ROOT/scripts/restore.sh --production-path "$BASE" --apply "$ARCHIVE"
run_http persist
printf 'Phase 8 交互式黑盒验收通过。\n'
