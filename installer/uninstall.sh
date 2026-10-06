#!/usr/bin/env bash
# Remove GarryCraft while preserving worlds and settings by default.
# Mirrors installer/Uninstall.ps1 and installer/UninstallPaths.ps1.
# Usage: uninstall.sh [--package-root DIR] [--install-root DIR] [--gmod-path DIR] [--purge]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! . "$SCRIPT_DIR/common.sh" 2>/dev/null; then
  echo "Uninstall failed: setup helpers are missing. Rerun install.sh from the extracted release ZIP." >&2
  exit 1
fi

PACKAGE_ROOT=""
INSTALL_ROOT=""
GMOD_PATH=""
PURGE=0
while (($# > 0)); do
  case "$1" in
    --package-root) PACKAGE_ROOT="$2"; shift 2 ;;
    --install-root) INSTALL_ROOT="$2"; shift 2 ;;
    --gmod-path) GMOD_PATH="$2"; shift 2 ;;
    --purge) PURGE=1; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

assert_no_symlink() {
  # assert_no_symlink <path> [deep] — deletion must never traverse a symlink.
  # The private Java runtime ships upstream symlinks (legal notices, man
  # pages), so runtime program files get a top-level check only. Game targets
  # and the player root itself always get the recursive check.
  local path="$1" deep="${2:-0}"
  if [[ -L "$path" ]]; then
    gc_fail "Remove the symlink before uninstalling: $path"
  fi
  if [[ "$deep" == "1" && -d "$path" ]]; then
    # Upstream archives (Java runtime, Maven libraries) legitimately contain
    # symlinks; their top-level entries are still checked above.
    local link
    link="$(find "$path" \( -path "$path/java" -o -path "$path/libraries" \) -prune -o -type l -print -quit)"
    if [[ -n "$link" ]]; then
      gc_fail "Remove symlinks inside this installation before uninstalling: $link"
    fi
  fi
}

# Resolve the player installation from setup records, not from the ZIP location.
ROOT=""
GAME="$GMOD_PATH"
if [[ -z "$ROOT" && -n "$PACKAGE_ROOT" && -f "$PACKAGE_ROOT/player.json" ]]; then
  ROOT="$(gc_json_get "$PACKAGE_ROOT/player.json" "root")"
fi
if [[ -z "$ROOT" ]]; then
  ROOT="$INSTALL_ROOT"
fi
if [[ -z "$ROOT" && -f "$SCRIPT_DIR/.garrycraft-player" ]]; then
  # Running from the player folder itself selects that installation,
  # mirroring the Windows template's -InstallRoot argument.
  ROOT="$SCRIPT_DIR"
fi
if [[ -z "$ROOT" ]]; then
  declare -a games=()
  if [[ -n "$GAME" ]]; then
    games=("$GAME")
  else
    while IFS= read -r found; do [[ -n "$found" ]] && games+=("$found"); done < <(gc_find_gmod)
  fi
  declare -a players=()
  for candidate in ${games[@]+"${games[@]}"}; do
    pointer="$candidate/garrysmod/data/garrycraft-runtime.json"
    if [[ -f "$pointer" ]]; then
      players+=("$(gc_json_get "$pointer" "root")|$candidate")
    fi
  done
  if ((${#players[@]} > 1)); then
    gc_fail "Multiple GarryCraft installations found. Rerun uninstall.sh with --gmod-path or --install-root."
  elif ((${#players[@]} == 1)); then
    ROOT="${players[0]%%|*}"
    GAME="${players[0]#*|}"
  else
    ROOT="$GC_PLAYER_DEFAULT"
  fi
fi
ROOT="$(gc_realpath "$ROOT" 2>/dev/null || echo "$ROOT")"

if [[ -e "$ROOT" ]]; then
  if [[ ! -f "$ROOT/.garrycraft-player" ]] || [[ "$(cat "$ROOT/.garrycraft-player")" != "GarryCraft player installation" ]]; then
    gc_fail "This directory is not an owned GarryCraft player installation: $ROOT"
  fi
  ROOT="$(gc_realpath "$ROOT")"
  assert_no_symlink "$ROOT" 1
  if [[ -z "$GAME" && -f "$ROOT/install.json" ]]; then
    GAME="$(gc_json_get "$ROOT/install.json" "game")"
  fi
fi

if [[ -n "$GAME" && ! -e "$GAME" ]]; then
  while IFS= read -r candidate; do
    [[ -z "$candidate" ]] && continue
    pointer="$candidate/garrysmod/data/garrycraft-runtime.json"
    if [[ -f "$pointer" ]] && [[ "$(gc_realpath "$(gc_json_get "$pointer" "root")")" == "$ROOT" ]]; then
      GAME="$candidate"
      break
    fi
  done < <(gc_find_gmod)
fi
if [[ -n "$GAME" && ! -e "$GAME" ]]; then
  gc_log "The recorded game folder is absent. Removing only the player installation: $GAME"
  GAME=""
fi
if [[ -n "$GAME" ]]; then
  GAME="$(gc_realpath "$GAME")"
  if [[ -d "$GAME/bin/linux64" ]]; then
    :
  else
    gc_fail "Garry's Mod moved or was removed. Supply its current outer folder with --gmod-path: $GAME"
  fi
  if [[ ! -d "$GAME/garrysmod" ]]; then
    gc_fail "Select the outer GarrysMod folder."
  fi
fi

if [[ "$ROOT" == "/" || (-n "$PACKAGE_ROOT" && "$ROOT" == "$(gc_realpath "$PACKAGE_ROOT")") ]]; then
  gc_fail "Refusing to remove a package or drive root: $ROOT"
fi
if [[ -n "$GAME" && ("$ROOT" == "$GAME" || "$GAME" == "$ROOT"/*) ]]; then
  gc_fail "Refusing to remove a game inside the player installation: $ROOT"
fi

if [[ -n "$GAME" && -n "$(gc_running_gmod "$GAME")" ]]; then
  gc_fail "Close the selected Garry's Mod installation before uninstalling GarryCraft."
fi

# A held lock means Minecraft is still running or saving through runtime.sh.
LOCK_FD=""
if [[ -d "$ROOT" ]]; then
  exec {LOCK_FD}>"$ROOT/.garrycraft-lock"
  if ! flock -n "$LOCK_FD"; then
    gc_fail "Minecraft is still running or saving. Wait for it to exit, then rerun uninstall.sh."
  fi
fi

declare -a game_targets=()
if [[ -n "$GAME" ]]; then
  pointer="$GAME/garrysmod/data/garrycraft-runtime.json"
  if [[ -f "$pointer" ]]; then
    owner="$(gc_realpath "$(gc_json_get "$pointer" "root")")"
    if [[ "$owner" != "$ROOT" ]]; then
      gc_log "Another player installation owns this game. Its game files remain."
    else
      game_targets=("$GAME/garrysmod/addons/garrycraft"
        "$GAME/garrysmod/cfg/garrycraft-session.cfg"
        "$GAME/garrysmod/lua/bin/gmcl_garrycraft_linux64.dll"
        "$GAME/garrysmod/lua/bin/gmsv_garrycraft_linux64.dll")
    fi
  else
    game_targets=("$GAME/garrysmod/addons/garrycraft"
      "$GAME/garrysmod/cfg/garrycraft-session.cfg"
      "$GAME/garrysmod/lua/bin/gmcl_garrycraft_linux64.dll"
      "$GAME/garrysmod/lua/bin/gmsv_garrycraft_linux64.dll")
  fi
  if [[ -d "$GAME/garrysmod/data" ]]; then
    while IFS= read -r entry; do
      [[ -n "$entry" ]] && game_targets+=("$entry")
    done < <(find "$GAME/garrysmod/data" -maxdepth 1 -name 'garrycraft-*' || true)
  fi
fi

declare -a runtime_targets=()
if [[ -d "$ROOT" ]]; then
  if ((PURGE)); then
    runtime_targets=("$ROOT")
  else
    # Keep this uninstaller and its helpers for safe repeat runs and reinstalls,
    # mirroring the Windows program list.
    for name in assets backups java libraries manual minecraft versions \
      java.tar.gz java.args config.json play.sh runtime.sh; do
      [[ -e "$ROOT/$name" || -L "$ROOT/$name" ]] && runtime_targets+=("$ROOT/$name")
    done
  fi
fi

for target in ${game_targets[@]+"${game_targets[@]}"}; do
  case "$target" in
    "$GAME"/garrysmod/*) ;;
    *) gc_fail "Invalid cleanup path: $target" ;;
  esac
  assert_no_symlink "$target" 1
done
for target in ${runtime_targets[@]+"${runtime_targets[@]}"}; do
  case "$target" in
    "$ROOT"/*) ;;
    "$ROOT") ;;
    *) gc_fail "Invalid cleanup path: $target" ;;
  esac
  assert_no_symlink "$target"
done

# Best-effort locked-file check: refuse when another process holds a target open.
# Regular files only, excluding this uninstall implementation itself, which the
# running shell necessarily holds open.
if command -v fuser >/dev/null 2>&1; then
  for target in ${game_targets[@]+"${game_targets[@]}"} ${runtime_targets[@]+"${runtime_targets[@]}"}; do
    if [[ -f "$target" && ! -L "$target" && "$target" != "$SCRIPT_DIR"/* ]] && fuser "$target" >/dev/null 2>&1; then
      gc_fail "Close Garry's Mod and Minecraft, then rerun uninstall.sh. A file is busy: $target"
    fi
  done
fi

gc_log "Player installation: $ROOT"
[[ -n "$GAME" ]] && gc_log "Game: $GAME"
for target in ${game_targets[@]+"${game_targets[@]}"} ${runtime_targets[@]+"${runtime_targets[@]}"}; do
  [[ -e "$target" || -L "$target" ]] && rm -rf "$target"
done
if [[ -n "$PACKAGE_ROOT" && -f "$PACKAGE_ROOT/player.json" ]]; then
  pointer="$(gc_json_get "$PACKAGE_ROOT/player.json" "root")"
  if [[ "$(gc_realpath "$pointer")" == "$ROOT" ]]; then
    rm -f "$PACKAGE_ROOT/player.json"
  fi
fi
gc_log "GarryCraft uninstalled. Launch Garry's Mod through Steam for normal play."
if ((PURGE)); then
  gc_log "The selected player installation, worlds, and settings were removed."
elif [[ -d "$ROOT" ]]; then
  gc_log "Worlds and settings remain in: $ROOT
Reinstall into this player folder to use them again. Use --purge for a complete reset."
fi
