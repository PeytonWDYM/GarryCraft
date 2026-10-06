#!/usr/bin/env bash
# Install GarryCraft on Linux x64. Mirrors installer/Install.ps1.
# Usage: install.sh [--gmod-path DIR] [--install-root DIR] [--runtime-only] [--no-download-cache]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"
. "$SCRIPT_DIR/prepare-runtime.sh"

PACKAGE="$(dirname "$SCRIPT_DIR")"
GMOD_PATH=""
INSTALL_ROOT=""
RUNTIME_ONLY=0
NO_DOWNLOAD_CACHE=0
while (($# > 0)); do
  case "$1" in
    --gmod-path) GMOD_PATH="$2"; shift 2 ;;
    --install-root) INSTALL_ROOT="$2"; shift 2 ;;
    --runtime-only) RUNTIME_ONLY=1; shift ;;
    --no-download-cache) NO_DOWNLOAD_CACHE=1; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

MANUAL_READY=0
LOG_FILE=""

install_fail() {
  echo "Installation failed: $*" >&2
  if ((MANUAL_READY)) && [[ -n "${INSTALL_ROOT:-}" && -n "${GMOD_PATH:-}" ]]; then
    gc_show_manual_copy "$INSTALL_ROOT" "$GMOD_PATH"
  fi
  echo "Read $PACKAGE/docs/INSTALL.md for recovery steps."
  [[ -n "$LOG_FILE" ]] && echo "Install log: $LOG_FILE"
  exit 1
}

echo "GarryCraft V1 - Linux x64 / single-player"
echo "[1/4] Check package and Garry's Mod"

if [[ "$(uname -m)" != "x86_64" ]]; then
  install_fail "GarryCraft requires Linux x64 on an Intel or AMD processor."
fi
for tool in curl python3 tar unzip; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    install_fail "The '$tool' command is required for setup. Install it, then rerun install.sh."
  fi
done

if [[ ! -f "$PACKAGE/release.json" ]]; then
  PROPERTIES="$PACKAGE/fabric/gradle.properties"
  if [[ ! -f "$PROPERTIES" ]]; then
    install_fail "Extract the entire release ZIP, then open install.sh from its folder."
  fi
  VERSION="$(grep -oP '^version=\K.+' "$PROPERTIES" | tr -d '[:space:]' || true)"
  if [[ -z "$VERSION" ]]; then
    install_fail "Cannot read the mod version from $PROPERTIES."
  fi
  RELEASE="$(gc_release_package "$VERSION")"
  FORWARD_ARGS=()
  [[ -n "$GMOD_PATH" ]] && FORWARD_ARGS+=(--gmod-path "$GMOD_PATH")
  [[ -n "$INSTALL_ROOT" ]] && FORWARD_ARGS+=(--install-root "$INSTALL_ROOT")
  ((RUNTIME_ONLY)) && FORWARD_ARGS+=(--runtime-only)
  ((NO_DOWNLOAD_CACHE)) && FORWARD_ARGS+=(--no-download-cache)
  if "$RELEASE/installer/install.sh" ${FORWARD_ARGS[@]+"${FORWARD_ARGS[@]}"}; then
    RESULT=0
  else
    RESULT=$?
  fi
  if ((RESULT == 0 && RUNTIME_ONLY == 0)); then
    cp -f "$RELEASE/player.json" "$PACKAGE/player.json"
    echo "Open $PACKAGE/play.sh. Select Start New Game > Sandbox > any map > Single Player."
  fi
  exit "$RESULT"
fi

MANIFEST="$PACKAGE/release.json"
while IFS=$'\t' read -r rel sha; do
  actual="$(sha256sum "$PACKAGE/payload/$rel" | cut -d' ' -f1)"
  if [[ "$actual" != "$(echo "$sha" | tr 'A-F' 'a-f')" ]]; then
    install_fail "Package checksum failed: $rel. Download and extract the release ZIP again."
  fi
done < <(python3 -c 'import json,sys; [print(e["path"] + "\t" + e["sha256"]) for e in json.load(open(sys.argv[1]))["payload"]]' "$MANIFEST")

if [[ -z "$GMOD_PATH" ]]; then
  mapfile -t GAMES < <(gc_find_gmod)
  if ((${#GAMES[@]} == 1)); then
    GMOD_PATH="${GAMES[0]}"
  else
    for game in ${GAMES[@]+"${GAMES[@]}"}; do echo "Found: $game"; done
    echo "Steam > Garry's Mod > Properties > Installed Files > Browse"
    read -r -p "Paste the GarrysMod folder path: " GMOD_PATH
    GMOD_PATH="$(echo "$GMOD_PATH" | sed -e 's/^"//' -e 's/"$//')"
  fi
fi
GMOD_PATH="$(gc_assert_game "$GMOD_PATH" "$MANIFEST")" || install_fail "Engine build check failed."
echo "Game: $GMOD_PATH"
if [[ -n "$(gc_running_gmod "$GMOD_PATH")" ]]; then
  install_fail "Close the selected Garry's Mod installation before setup."
fi

if [[ -z "$INSTALL_ROOT" ]]; then
  INSTALL_ROOT="$GC_PLAYER_DEFAULT"
fi
if [[ -e "$INSTALL_ROOT" && ! -f "$INSTALL_ROOT/.garrycraft-player" ]]; then
  install_fail "This directory is not a GarryCraft player installation: $INSTALL_ROOT. Select a new empty path with --install-root."
fi
mkdir -p "$INSTALL_ROOT"
if [[ ! -f "$INSTALL_ROOT/.garrycraft-player" ]]; then
  echo "GarryCraft player installation" >"$INSTALL_ROOT/.garrycraft-player"
fi
INSTALL_ROOT="$(gc_realpath "$INSTALL_ROOT")"
if gc_flatpak_steam && ! gc_flatpak_sees "$INSTALL_ROOT/.garrycraft-player"; then
  install_fail "Flatpak Steam cannot see $INSTALL_ROOT. Omit --install-root, or grant access with:
  flatpak override --user --filesystem=$INSTALL_ROOT $GC_FLATPAK_STEAM_ID"
fi

exec {SETUP_LOCK}>"$INSTALL_ROOT/.garrycraft-lock"
if ! flock -n "$SETUP_LOCK"; then
  install_fail "Minecraft is still running or saving. Wait for it to exit, then rerun install.sh."
fi

LOG_FILE="$INSTALL_ROOT/install-$(date +%Y%m%d-%H%M%S-%3N).log"
exec > >(tee "$LOG_FILE") 2>&1 || true
echo "Player installation: $INSTALL_ROOT"

prepare_runtime "$MANIFEST" "$INSTALL_ROOT" "$PACKAGE" "$NO_DOWNLOAD_CACHE" || install_fail "Runtime preparation failed."

echo "[3/4] Prepare game files"
MANUAL="$INSTALL_ROOT/manual"
while IFS= read -r rel; do
  target="$MANUAL/$rel"
  mkdir -p "$(dirname "$target")"
  cp -f "$PACKAGE/payload/$rel" "$target" || install_fail "Cannot stage the manual copy tree."
done < <(python3 -c 'import json,sys; [print(e["path"]) for e in json.load(open(sys.argv[1]))["payload"] if e["path"].startswith("garrysmod/")]' "$MANIFEST")
mkdir -p "$MANUAL/garrysmod/data"
python3 - "$MANUAL/garrysmod/data/garrycraft-runtime.json" "$INSTALL_ROOT" <<'EOF'
import json,sys
with open(sys.argv[1], 'w', encoding='utf-8', newline='\n') as handle:
    json.dump({"root": sys.argv[2]}, handle)
EOF
VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$MANIFEST")"
python3 - "$INSTALL_ROOT/install.json" "$VERSION" "$GMOD_PATH" <<'EOF'
import json,sys
with open(sys.argv[1], 'w', encoding='utf-8', newline='\n') as handle:
    json.dump({"version": sys.argv[2], "game": sys.argv[3]}, handle)
EOF
MANUAL_READY=1

if ((RUNTIME_ONLY)); then
  gc_show_manual_copy "$INSTALL_ROOT" "$GMOD_PATH"
else
  if [[ -n "$(gc_running_gmod "$GMOD_PATH")" ]]; then
    install_fail "The selected Garry's Mod installation started during setup. Close it, then rerun install.sh."
  fi
  mapfile -t PATHS < <(python3 -c 'import json,sys; [print(e["path"]) for e in json.load(open(sys.argv[1]))["payload"] if e["path"].startswith("garrysmod/")]' "$MANIFEST")
  PATHS+=("garrysmod/data/garrycraft-runtime.json")
  BACKUP="$INSTALL_ROOT/backups/$(date +%Y%m%d-%H%M%S-%3N)"
  gc_install_game_files "$MANUAL" "$GMOD_PATH" "$BACKUP" "${PATHS[@]}" || install_fail "Game file installation failed."
  python3 - "$PACKAGE/player.json" "$INSTALL_ROOT" <<'EOF'
import json,sys
with open(sys.argv[1], 'w', encoding='utf-8', newline='\n') as handle:
    json.dump({"root": sys.argv[2]}, handle)
EOF
  echo "[4/4] Installation complete"
  echo "Open $PACKAGE/play.sh. Select Start New Game > Sandbox > any map > Single Player."
  echo "Use Spawn Menu > Utilities > GarryCraft to enable or disable the bridge."
fi
echo "Install log: $LOG_FILE"
echo "Worlds: $INSTALL_ROOT/worlds"
echo "Minecraft mods: $INSTALL_ROOT/minecraft/mods"
