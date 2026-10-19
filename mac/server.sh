#!/usr/bin/env bash
# Start the Xpilot-AI server locally on the native macOS build.
# Usage: mac/server.sh [map.xp] [extra xpilots options...]
#   mac/server.sh                 # simple.xp
#   mac/server.sh pit.xp -switchBase 0.5
# Maps are looked up in mac/lib/xpilot/maps (the repo's maps/ is copied there).
set -euo pipefail
MAC_DIR="$(cd "$(dirname "$0")" && pwd)"
MAP="${1:-simple.xp}"
shift || true
# +reportMeta: do not advertise this server on the public XPilot meta server
# (boolean options use -name for true and +name for false).
exec "$MAC_DIR/bin/xpilots" -map "$MAP" +reportMeta -noQuit "$@"
