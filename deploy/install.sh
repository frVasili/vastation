#!/usr/bin/env bash
# Install or update VAStation on a Wolf host. Run it as the user that owns Wolf's data folder.
#
#   VASTATION_DIR=/path/to/wolf-data/vastation bash install.sh [release tag] [--dry-run]
#
# VASTATION_DIR is a folder INSIDE the folder Wolf mounts as /etc/wolf (so /etc/wolf/vastation in the
# Wolf container). The script downloads the release, puts it in $VASTATION_DIR/app (the previous version
# is kept as app.prev) and creates user/ and state/. It never restarts anything: a running launcher
# keeps the old files until its session ends.
set -euo pipefail
repo=${VASTATION_REPO:-frVasili/vastation}
tag=latest
dry_run=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=1 ;;
    --*) echo "Unknown option: $arg" >&2; exit 2 ;;
    *) tag=$arg ;;
  esac
done
[[ $tag =~ ^[a-zA-Z0-9._-]+$ && $tag != . && $tag != .. ]] || { echo 'Invalid tag' >&2; exit 2; }
base=${VASTATION_DIR:?Set VASTATION_DIR to the vastation folder inside your Wolf data folder}
if (( dry_run )); then
  echo "Would download vastation-linux.tar.gz from $repo release $tag into $base/releases/,"
  echo "swap it in as $base/app (previous version kept as $base/app.prev), and create $base/user and $base/state."
  exit 0
fi
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
asset=vastation-linux.tar.gz
# gh works for private repos too; plain curl is enough for a public one.
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  gh release download "$tag" --repo "$repo" --pattern "$asset" --dir "$work"
else
  curl -fL --retry 3 -o "$work/$asset" "https://github.com/$repo/releases/download/$tag/$asset"
fi
sha=$(sha256sum "$work/$asset" | cut -d ' ' -f1)
release="$base/releases/$tag-${sha:0:16}"
# Validate tar members before extraction: regular files and folders only, no absolute or parent paths.
python3 - "$work/$asset" <<'PY'
import sys, tarfile
allowed_files = {'vastation.x86_64', 'vastation.pck', 'startup-app.sh'}
allowed_dirs = ('themes', 'waybar')
with tarfile.open(sys.argv[1]) as archive:
    names = set()
    for m in archive.getmembers():
        n = m.name.removeprefix('./').rstrip('/')
        assert m.isfile() or m.isdir(), 'Unsafe archive member: ' + n
        assert not n.startswith('/') and '..' not in n.split('/'), 'Unsafe path: ' + n
        assert n in allowed_files or n in allowed_dirs or n.startswith(tuple(d + '/' for d in allowed_dirs)), 'Unexpected: ' + n
        names.add(n)
    assert allowed_files <= names, names
PY
mkdir -p "$base/releases" "$base/user/art" "$base/user/themes" "$base/state"
# Serialize installers without affecting running apps.
exec 9>"$base/.install.lock"
flock -n 9 || { echo 'Another install is running' >&2; exit 1; }
if [[ ! -d "$release" ]]; then
  mkdir "$release"
  tar -xzf "$work/$asset" -C "$release" --no-same-owner
fi
chmod +x "$release/vastation.x86_64" "$release/startup-app.sh"
stage=$(mktemp -d "$base/.app-new.XXXXXX")
chmod 755 "$stage"
cp -a "$release/." "$stage/"
# Sway apps copy the bar with `cp -u`: make ours newer than any copy already in an app's home.
touch "$stage"/waybar/*
python3 - "$base" "$stage" <<'PY'
import ctypes, os, sys, time
base, stage = sys.argv[1:]
app = base + '/app'
previous = base + '/app.prev'
if os.path.lexists(app):
    if os.path.islink(app) or not os.path.isdir(app):
        raise SystemExit('app must be a real directory')
    libc = ctypes.CDLL(None, use_errno=True)
    # Linux renameat2 RENAME_EXCHANGE atomically swaps two nonempty directories.
    if libc.renameat2(-100, os.fsencode(stage), -100, os.fsencode(app), 2):
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error))
    if os.path.lexists(previous):
        os.rename(previous, base + '/app.prev.' + str(time.time_ns()))
    os.rename(stage, previous)
else:
    os.rename(stage, app)
PY
echo "Installed $repo $tag (${sha:0:16}) into $base/app."
echo "Your own tiles, images and themes go in $base/user (see docs/TILES.md and docs/THEMES.md)."
echo "End the launcher session and reconnect to use the new version."
