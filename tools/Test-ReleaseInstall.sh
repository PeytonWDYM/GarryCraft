#!/usr/bin/env bash
# Linux release-install checks. Mirrors tools/Test-ReleaseInstall.ps1.
# Offline package checks always run. With --download, performs a runtime-only
# install into a game-shaped fixture with external caches disabled.
# Usage: Test-ReleaseInstall.sh --package <zip> [--run-root DIR] [--download]
set -euo pipefail

PACKAGE=""
RUN_ROOT=""
DOWNLOAD=0
while (($# > 0)); do
  case "$1" in
    --package) PACKAGE="$2"; shift 2 ;;
    --run-root) RUN_ROOT="$2"; shift 2 ;;
    --download) DOWNLOAD=1; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done
if [[ -z "$PACKAGE" ]]; then
  echo "Usage: Test-ReleaseInstall.sh --package <zip> [--run-root DIR] [--download]" >&2
  exit 1
fi
for tool in unzip python3; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "The '$tool' command is required for release-install checks." >&2
    exit 1
  fi
done
if command -v file >/dev/null 2>&1; then
  HAVE_FILE=1
else
  HAVE_FILE=0
fi
if [[ -z "$RUN_ROOT" ]]; then
  RUN_ROOT="$HOME/.local/share/GarryCraft/release-tests/$(date +%Y%m%d-%H%M%S)"
fi
mkdir -p "$RUN_ROOT"
RESULT="$RUN_ROOT/release-install-result.json"

declare -a PASSED=()
declare -a FAILED=()
check() {
  # check <name> <command...>
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    PASSED+=("$name")
  else
    FAILED+=("$name")
  fi
  return 0
}

EXTRACT="$RUN_ROOT/extract"
rm -rf "$EXTRACT"
mkdir -p "$EXTRACT"
unzip -q "$PACKAGE" -d "$EXTRACT"
# Releases archive the stage contents, so the package root is either the
# extract directory itself or its single top-level directory.
PKGDIR="$EXTRACT"
if [[ ! -f "$PKGDIR/release.json" ]]; then
  PKGDIR="$(find "$EXTRACT" -maxdepth 1 -mindepth 1 -type d -print -quit)"
fi
if [[ ! -f "$PKGDIR/release.json" ]]; then
  echo "Cannot find release.json in $PACKAGE." >&2
  exit 1
fi

# Package layout: install.sh and play.sh beside each other, no build tools needed.
check "entry-scripts-beside-each-other" test -f "$PKGDIR/install.sh" -a -f "$PKGDIR/play.sh" -a -f "$PKGDIR/uninstall.sh"
check "scripts-executable" test -x "$PKGDIR/install.sh" -a -x "$PKGDIR/installer/install.sh"
check "release-manifest-present" test -f "$PKGDIR/release.json"

# Payload hashes match release.json.
check "payload-hashes" python3 - "$PKGDIR" <<'EOF'
import hashlib, json, os, sys
pkg = sys.argv[1]
manifest = json.load(open(os.path.join(pkg, "release.json")))
for entry in manifest["payload"]:
    full = os.path.join(pkg, "payload", entry["path"])
    digest = hashlib.sha256()
    with open(full, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    assert digest.hexdigest().upper() == entry["sha256"], entry["path"]
EOF

# Both Linux native modules are present with GMod's Linux module names.
check "linux64-server-module" test -f "$PKGDIR/payload/garrysmod/lua/bin/gmsv_garrycraft_linux64.dll"
check "linux64-client-module" test -f "$PKGDIR/payload/garrysmod/lua/bin/gmcl_garrycraft_linux64.dll"
if ((HAVE_FILE)); then
  check "linux64-modules-are-elf" bash -c "file '$PKGDIR/payload/garrysmod/lua/bin/'*_linux64.dll | grep -q ELF"
fi

# Shell syntax for every shipped script.
SYNTAX_OK=1
while IFS= read -r script; do
  bash -n "$script" || SYNTAX_OK=0
done < <(find "$PKGDIR" -name '*.sh')
if ((SYNTAX_OK)); then PASSED+=("shell-syntax"); else FAILED+=("shell-syntax"); fi

# play.sh before setup exits with setup instructions, not a missing-file error.
play_output="$("$PKGDIR/play.sh" 2>&1 || true)"
if echo "$play_output" | grep -qi "setup" && echo "$play_output" | grep -q "install.sh"; then
  PASSED+=("play-before-setup-message")
else
  FAILED+=("play-before-setup-message")
fi

if ((DOWNLOAD)); then
  # First-download run: clean fixture, caches disabled, exact folders recorded.
  FIXTURE="$RUN_ROOT/game-fixture"
  PLAYER="$RUN_ROOT/player"
  rm -rf "$FIXTURE" "$PLAYER"
  mkdir -p "$FIXTURE/bin/linux64" "$FIXTURE/garrysmod/addons" "$FIXTURE/garrysmod/lua/bin" \
    "$FIXTURE/garrysmod/data" "$FIXTURE/garrysmod/cfg"
  echo "clean-fixture: game=$FIXTURE player=$PLAYER (both absent before setup)"
  check "runtime-only-install" "$PKGDIR/install.sh" --gmod-path "$FIXTURE" --install-root "$PLAYER" \
    --runtime-only --no-download-cache
  check "manual-addon-tree" test -d "$PLAYER/manual/garrysmod/addons/garrycraft"
  check "manual-server-module" test -f "$PLAYER/manual/garrysmod/lua/bin/gmsv_garrycraft_linux64.dll"
  check "manual-client-module" test -f "$PLAYER/manual/garrysmod/lua/bin/gmcl_garrycraft_linux64.dll"
  check "manual-runtime-pointer" test -f "$PLAYER/manual/garrysmod/data/garrycraft-runtime.json"
  check "player-mods" test -f "$PLAYER/minecraft/mods/garrycraft.jar"
  check "player-java" test -x "$PLAYER/java/"*"/bin/java"
  check "player-launcher" test -x "$PLAYER/play.sh" -a -x "$PLAYER/runtime.sh"
  # Repeat install preserves worlds, settings, and unrelated addons.
  mkdir -p "$PLAYER/worlds/keep" "$PLAYER/settings"
  echo "keep" >"$PLAYER/worlds/keep/marker.txt"
  mkdir -p "$FIXTURE/garrysmod/addons/unrelated"
  echo "unrelated" >"$FIXTURE/garrysmod/addons/unrelated/marker.txt"
  check "repeat-install" "$PKGDIR/install.sh" --gmod-path "$FIXTURE" --install-root "$PLAYER" \
    --runtime-only --no-download-cache
  check "worlds-preserved" test -f "$PLAYER/worlds/keep/marker.txt"
  check "unrelated-addon-preserved" test -f "$FIXTURE/garrysmod/addons/unrelated/marker.txt"
fi

python3 - "$RESULT" <<EOF
import json
passed = """${PASSED[*]}""".split()
failed = """${FAILED[*]}""".split()
with open("$RESULT", "w", encoding="utf-8", newline="\n") as handle:
    json.dump({"passed": passed, "failed": failed,
        "ok": len(failed) == 0}, handle, indent=2)
print("passed %d, failed %d" % (len(passed), len(failed)))
for name in failed:
    print("FAILED:", name)
EOF
if ((${#FAILED[@]} > 0)); then exit 1; fi
