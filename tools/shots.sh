#!/usr/bin/env bash
# Screenshot tour of the launcher (software rendered under xvfb). Usage: tools/shots.sh [outdir] [WxH]
set -euo pipefail
here="$(cd "$(dirname "$0")/../launcher" && pwd)"
out="${1:-$here/../shots}"
res="${2:-1280x720}"
W="${res%x*}"; H="${res#*x}"
mkdir -p "$out"
if [ ! -d "$here/.godot" ]; then
	nice -n 10 godot --headless --path "$here" --import >/dev/null 2>&1 || true
fi
VASTATION_BACKEND=mock VASTATION_SKIP_BOOT= nice -n 10 xvfb-run -a -s "-screen 0 ${W}x${H}x24" \
	godot --path "$here" --rendering-driver opengl3 --audio-driver Dummy \
	--resolution "${W}x${H}" --fixed-fps 30 -- --shots "$out"
