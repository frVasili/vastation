#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
work=$(mktemp -d)
fake_pid=
trap 'if [[ -n "$fake_pid" ]]; then kill "$fake_pid" 2>/dev/null || true; wait "$fake_pid" 2>/dev/null || true; fi; rm -rf "$work"' EXIT
python3 tools/fake_wolf.py --socket "$work/wolf.sock" --record "$work/requests.jsonl" >"$work/fake.log" 2>&1 &
fake_pid=$!
for _ in {1..100}; do [[ -S "$work/wolf.sock" ]] && break; sleep .02; done
export XDG_DATA_HOME="$work/data"
export XDG_CONFIG_HOME="$work/config"
export XDG_CACHE_HOME="$work/cache"
if [[ ! -S "$work/wolf.sock" ]]; then cat "$work/fake.log"; echo "Fake Wolf failed to bind its Unix socket" >&2; exit 1; fi
project=launcher
if [[ ! -f launcher/project.godot ]]; then
  project="$work/project"
  mkdir -p "$project/src/backend"
  cp launcher/src/backend/*.gd "$project/src/backend/"
  printf 'config_version=5\n[application]\nconfig/name="Backend test"\n' > "$project/project.godot"
  echo 'UI project not ready: using temporary test project'
fi
# Import registers class_name types; timeout guards syntax errors that leave Godot alive.
nice -n 10 timeout 30 godot --headless --path "$project" --editor --import >"$work/import.log" 2>&1
WOLF_SOCKET_PATH="$work/wolf.sock" WOLF_SESSION_ID=42 nice -n 10 timeout 25 godot --headless --path "$project" --script res://src/backend/test_wolf_backend.gd 2>&1 | tee "$work/test.log"
if ! grep -q 'BACKEND TEST PASSED' "$work/test.log"; then cat "$work/import.log" "$work/fake.log"; exit 1; fi
if grep -q NEVER_LOG_THIS "$work/test.log"; then echo 'Stream keys leaked'; exit 1; fi
python3 - "$work/requests.jsonl" <<'PY'
import json, sys
requests = [json.loads(line) for line in open(sys.argv[1])]
paths = [r['path'] for r in requests if r['path'] != '/events']
expected = ['/sessions', '/profiles', '/lobbies', '/docker/images/inspect', '/docker/images/pull', '/lobbies/create', '/lobbies/join', '/lobbies', '/control', '/lobbies/join', '/lobbies', '/lobbies/stop', '/docker/images/inspect', '/lobbies/create', '/lobbies/join', '/lobbies', '/control']
assert paths == expected, paths
assert all(r['body']['moonlight_session_id'] == '42' for r in requests if r['path'] == '/lobbies/join')
print('Request sequence verified')
PY
