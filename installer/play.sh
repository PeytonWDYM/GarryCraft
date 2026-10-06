#!/usr/bin/env bash
# Launch a GarryCraft session through Steam. Mirrors installer/Play.ps1.
# Usage: play.sh [--package-root DIR]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
if ! . "$SCRIPT_DIR/common.sh" 2>/dev/null; then
  echo "Setup is incomplete for this player folder. Rerun install.sh from the extracted release ZIP." >&2
  exit 1
fi

PACKAGE_ROOT=""
while (($# > 0)); do
  case "$1" in
    --package-root) PACKAGE_ROOT="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

PLAYER_ROOT="$SCRIPT_DIR"
if [[ -n "$PACKAGE_ROOT" ]]; then
  PACKAGE_ROOT="$(gc_realpath "$PACKAGE_ROOT")"
  if [[ ! -f "$PACKAGE_ROOT/player.json" ]]; then
    gc_fail "Run setup first: $PACKAGE_ROOT/install.sh
After setup completes, open play.sh in the same folder."
  fi
  PLAYER_ROOT="$(gc_json_get "$PACKAGE_ROOT/player.json" "root")"
fi

if [[ ! -f "$PLAYER_ROOT/install.json" ]]; then
  SETUP="$SCRIPT_DIR/../install.sh"
  if [[ -f "$SETUP" ]]; then
    gc_fail "Run setup first: $SETUP
After setup completes, open the play.sh path printed by setup."
  fi
  gc_fail "Setup is incomplete for this player folder. Rerun install.sh from the extracted release ZIP, then open the play.sh path printed by setup."
fi

GAME="$(gc_json_get "$PLAYER_ROOT/install.json" "game")"
if [[ ! -d "$GAME/bin/linux64" ]]; then
  gc_fail "Garry's Mod moved. Rerun install.sh with its new folder path."
fi
if [[ -n "$(gc_running_gmod "$GAME")" ]]; then
  gc_fail "Close Garry's Mod, then open play.sh to start a GarryCraft session."
fi
if ! command -v steam >/dev/null 2>&1; then
  gc_fail "The Steam client was not found. Install Steam, keep it open with your Garry's Mod license available, then rerun play.sh."
fi

gc_log "Game: $GAME"
nohup steam -applaunch 4000 -insecure -novid -windowed -w 1920 -h 1080 \
  +sv_lan 1 +maxplayers 1 +exec garrycraft-session.cfg >/dev/null 2>&1 &
gc_log "GarryCraft session requested. Select Start New Game > Sandbox > any map > Single Player."
