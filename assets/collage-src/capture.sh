#!/bin/zsh
# Capture the running Prizm window (no shadow) to shots/<name>.png.
# Usage: ./capture.sh hero|orgs|search|types
# Needs the winid helper: swiftc winid.swift -o winid
set -e
HERE=${0:A:h}
mkdir -p "$HERE/shots"
PID=$(pgrep -n -x Prizm) || { echo "Prizm is not running"; exit 1; }
WID=$("$HERE/winid" "$PID" | awk '$2 > 600 { print $1; exit }')
[ -z "$WID" ] && { echo "no Prizm window found"; exit 1; }
# Bring Prizm to the front first, otherwise the window is captured in its inactive style.
osascript -e 'tell application "Prizm" to activate' >/dev/null 2>&1 || true
sleep 1.2
screencapture -x -o -l "$WID" "$HERE/shots/$1.png"
sips -g pixelWidth -g pixelHeight "$HERE/shots/$1.png" | tail -2
