#!/usr/bin/env bash
# VAStation's start script inside the Wolf app container (bind-mounted over /opt/gow/startup-app.sh).
# Folders, as mounted by the Wolf app entry (see deploy/wolf-app.toml):
#   /opt/vastation         the launcher (binary, .pck, themes/, waybar/)             read-only
#   /opt/vastation-user    your tiles.json, art/ and themes/ (docs/TILES.md)          read-only
#   /opt/vastation-state   settings, the HOME-button request folder, debug switches   writable
set -uo pipefail
# The same script is also the child command under sway, so crash handling survives it.
if [[ ${VASTATION_DISPLAY:-wayland} == sway && ${VASTATION_SWAY_CHILD:-0} != 1 ]]; then
  export RUN_SWAY=1 VASTATION_SWAY_CHILD=1 SWAY_STOP_ON_APP_EXIT=yes
  unset RUN_GAMESCOPE
  source /opt/gow/launch-comp.sh
  launcher /opt/gow/startup-app.sh
  exit $?
fi
state=/opt/vastation-state
mkdir -p "$state/data" "$state/ipc" && chmod 777 "$state/ipc"
# Settings survive the container (it is removed after every session).
export XDG_DATA_HOME="$state/data"
export VASTATION_USER_DIR="${VASTATION_USER_DIR:-/opt/vastation-user}"
export VASTATION_IPC_DIR="${VASTATION_IPC_DIR:-$state/ipc}"
# What every launched app gets on top of its own definition: our top bar (sway apps copy /cfg/waybar into
# their home) and the folder where its HOME button drops a "return" request for the launcher to pick up.
# Needs the HOST path of the vastation folder (the launcher asks Wolf to mount host folders into other
# containers): set VASTATION_HOST_DIR in the Wolf app entry. Without it apps keep the stock bar.
if [[ -n ${VASTATION_HOST_DIR:-} ]]; then
  export VASTATION_APP_MOUNTS="${VASTATION_APP_MOUNTS:-$VASTATION_HOST_DIR/app/waybar:/cfg/waybar:ro;$VASTATION_HOST_DIR/state/ipc:/vastation-ipc}"
fi
# Optional debug switches without touching Wolf's config: KEY=VALUE lines in state/debug.env
# (VASTATION_DEBUG_SHOTS=/opt/vastation-state/shots, VASTATION_AUTOLAUNCH=<tile id>, VASTATION_SKIP_BOOT=1).
if [[ -s $state/debug.env ]]; then
  set -a; source "$state/debug.env"; set +a
  echo "[vastation] debug.env loaded"
fi
log=$(mktemp /tmp/vastation-log.XXXXXX)
trap 'rm -f "$log"' EXIT
args=(--rendering-driver opengl3 --fullscreen --resolution "${GAMESCOPE_WIDTH:-1280}x${GAMESCOPE_HEIGHT:-720}")
if [[ ${VASTATION_DISPLAY:-wayland} == sway ]]; then
  args+=(--display-driver x11)
else
  args+=(--display-driver wayland)
fi
/opt/vastation/vastation.x86_64 "${args[@]}" "$@" 2>&1 | tee "$log"
code=${PIPESTATUS[0]}
if (( code != 0 )); then
  echo "[vastation] exited with code $code; last log lines:"
  tail -n 30 "$log"
  sleep 5
fi
exit "$code"
