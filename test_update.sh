#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
cd "$ROOT"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/state-update-XXXXXX")
PORT=${STATE_UPDATE_TEST_PORT:-0}
SERVER_PID=""
cleanup() {
	if [ -n "$SERVER_PID" ]; then kill "$SERVER_PID" 2>/dev/null || true; fi
	rm -rf "$TMP"
}
trap cleanup EXIT

./build.sh >/dev/null
cp "$ROOT/state" "$TMP/state"
chmod +x "$TMP/state"
mkdir -p "$TMP/www"
cp "$TMP/state" "$TMP/www/state-new"
printf '\nstate-update-candidate\n' >> "$TMP/www/state-new"
chmod +x "$TMP/www/state-new"

PORT_FILE="$TMP/port"
python3 - "$TMP/www" "$PORT" "$PORT_FILE" <<'PY' >/dev/null 2>&1 &
import http.server
import os
import sys

os.chdir(sys.argv[1])
requested = int(sys.argv[2])
server = http.server.ThreadingHTTPServer(("127.0.0.1", requested), http.server.SimpleHTTPRequestHandler)
with open(sys.argv[3], "w") as f:
    f.write(str(server.server_address[1]))
server.serve_forever()
PY
SERVER_PID=$!
for _ in $(seq 1 30); do [ -s "$PORT_FILE" ] && break; sleep 0.1; done
[ -s "$PORT_FILE" ]
PORT=$(cat "$PORT_FILE")

candidate_sha=$(sha256sum "$TMP/www/state-new" | awk '{print $1}')
candidate_ver=$(printf '%s' "$candidate_sha" | cut -c1-12)
printf '%s\n' '{"ok":true,"version":"'"$candidate_ver"'","download":"state-new","sha256":"'"$candidate_sha"'"}' > "$TMP/www/version.json"
export STATE_UPDATE_URL="http://127.0.0.1:$PORT/version.json"
export STATE_UPDATE_BASE="http://127.0.0.1:$PORT"
export HOME="$TMP/home"
mkdir -p "$HOME"

json=$($TMP/state help-json)
printf '%s\n' "$json" | jq -e '.commands.update.flags | index("--check") and index("--force")' >/dev/null
$TMP/state guide | jq -e '.commands.update and (.gotchas | length > 0)' >/dev/null
$TMP/state version | jq -e '.ok == true and .tool == "state"' >/dev/null

set +e
check_out=$($TMP/state update --check 2>"$TMP/check.err")
check_rc=$?
set -e
[ "$check_rc" -eq 5 ]
printf '%s\n' "$check_out" | jq -e '.up_to_date == false and .local and .remote' >/dev/null
[ ! -s "$TMP/check.err" ]

cp "$TMP/state" "$TMP/state.before-bad"
printf '%s\n' '{"ok":true,"version":"'"$candidate_ver"'","download":"state-new","sha256":"'$(printf bad | sha256sum | awk '{print $1}')'"}' > "$TMP/www/version.json"
set +e
$TMP/state update >"$TMP/bad.out" 2>"$TMP/bad.err"
bad_rc=$?
set -e
[ "$bad_rc" -eq 100 ]
jq -e '.ok == false and .error.code == 100 and .error.type == "update_hash_mismatch"' "$TMP/bad.out" >/dev/null
cmp -s "$TMP/state" "$TMP/state.before-bad"

printf '%s\n' '{"ok":true,"version":"'"$candidate_ver"'","download":"state-new","sha256":"'"$candidate_sha"'"}' > "$TMP/www/version.json"
update_out=$($TMP/state update 2>"$TMP/update.err")
printf '%s\n' "$update_out" | jq -e '.ok == true and .updated == true and .from and .to and .backup' >/dev/null
ls "$TMP"/state.bak-"$candidate_ver"-* >/dev/null 2>&1
$TMP/state version | jq -e '.ok == true and .version == "1.1.0"' >/dev/null
# Matching manifest is a no-op and exits 0.
current_sha=$(sha256sum "$TMP/state" | awk '{print $1}')
current_ver=$(printf '%s' "$current_sha" | cut -c1-12)
printf '%s\n' '{"ok":true,"version":"'"$current_ver"'","download":"state-new","sha256":"'"$current_sha"'"}' > "$TMP/www/version.json"
up_out=$($TMP/state update --check 2>"$TMP/up.err")
printf '%s\n' "$up_out" | jq -e '.up_to_date == true and .updated == false' >/dev/null
[ ! -s "$TMP/up.err" ]

printf '%s\n' 'state update smoke: ok' >&2
