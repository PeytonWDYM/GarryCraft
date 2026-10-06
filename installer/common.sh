#!/usr/bin/env bash
# Shared Linux installer helpers. Mirrors installer/Downloads.ps1,
# installer/GameFiles.ps1, installer/Release.ps1, and
# tools/Resolve-LocalPath.ps1. Requires bash, curl, python3, and tar.
set -euo pipefail

GC_FLATPAK_STEAM_ID="com.valvesoftware.Steam"
GC_FLATPAK_STEAM_HOME="$HOME/.var/app/$GC_FLATPAK_STEAM_ID"

gc_flatpak_steam() {
  # True when Steam is installed only as the Flathub Flatpak.
  ! command -v steam >/dev/null 2>&1 && command -v flatpak >/dev/null 2>&1 &&
    [[ -d "$GC_FLATPAK_STEAM_HOME/.local/share/Steam" ]]
}

gc_flatpak_sees() {
  # gc_flatpak_sees <path> -> true when the Steam sandbox, and so GMod's child processes, can read <path>.
  flatpak run --command=test "$GC_FLATPAK_STEAM_ID" -e "$1" 2>/dev/null
}

# The sandboxed game starts the Minecraft runtime, so its player folder must be visible inside the sandbox.
if gc_flatpak_steam; then
  GC_PLAYER_DEFAULT="$GC_FLATPAK_STEAM_HOME/.local/share/GarryCraft/player"
else
  GC_PLAYER_DEFAULT="$HOME/.local/share/GarryCraft/player"
fi

gc_log() { echo "$*"; }
gc_warn() { echo "$*" >&2; }
gc_fail() { echo "Installation failed: $*" >&2; exit 1; }

gc_realpath() {
  python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1"
}

gc_json_get() {
  # gc_json_get <file> <dotted.key> -> prints the value
  python3 - "$1" "$2" <<'EOF'
import json,sys
with open(sys.argv[1], encoding="utf-8") as handle:
    value = json.load(handle)
for part in sys.argv[2].split("."):
    value = value[part]
print(value if isinstance(value, str) else json.dumps(value))
EOF
}

gc_sha() {
  # gc_sha <algorithm: SHA1|SHA256> <file> -> lowercase hex
  case "$1" in
    SHA1) sha1sum "$2" | cut -d' ' -f1 ;;
    *) sha256sum "$2" | cut -d' ' -f1 ;;
  esac
}

gc_download_one() {
  # gc_download_one <url> <target> <hash> <algorithm>
  local url="$1" target="$2" hash="$3" algo="${4:-SHA1}"
  local expect
  expect="$(echo "$hash" | tr 'A-F' 'a-f')"
  if [[ -f "$target" ]] && [[ "$(gc_sha "$algo" "$target")" == "$expect" ]]; then
    return 0
  fi
  mkdir -p "$(dirname "$target")"
  local tmp="$target.download"
  rm -f "$tmp"
  if ! curl -fsSL --retry 3 --retry-delay 2 -o "$tmp" "$url"; then
    rm -f "$tmp"
    echo "Download failed: $url" >&2
    echo "Destination: $target" >&2
    echo "Check your connection and rerun install.sh. Verified downloads will be reused." >&2
    return 1
  fi
  if [[ "$(gc_sha "$algo" "$tmp")" != "$expect" ]]; then
    rm -f "$tmp"
    echo "Download failed (wrong checksum): $url" >&2
    echo "Destination: $target" >&2
    return 1
  fi
  mv -f "$tmp" "$target"
}

gc_download_all() {
  # gc_download_all <release.json> <root> [cacheRoot...]
  # Verifies cached files and replaces incomplete downloads, up to 8 at once.
  local manifest="$1" root="$2"
  shift 2
  local -a caches=("$@")
  local total failed=0
  total="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["downloads"]))' "$manifest")"
  local done=0
  local -a pending=()
  while IFS=$'\t' read -r url rel hash algo; do
    (
      expect="$(echo "$hash" | tr 'A-F' 'a-f')"
      target="$root/$rel"
      if [[ -f "$target" ]] && [[ "$(gc_sha "$algo" "$target")" == "$expect" ]]; then
        exit 0
      fi
      for cache in ${caches[@]+"${caches[@]}"}; do
        if [[ -f "$cache/$rel" ]] && [[ "$(gc_sha "$algo" "$cache/$rel")" == "$expect" ]]; then
          mkdir -p "$(dirname "$target")"
          cp -f "$cache/$rel" "$target"
          exit 0
        fi
      done
      gc_download_one "$url" "$target" "$hash" "$algo"
    ) &
    pending+=($!)
    if ((${#pending[@]} >= 8)); then
      wait "${pending[0]}" || failed=1
      pending=("${pending[@]:1}")
      done=$((done + 1))
      if ((done % 100 == 0)); then gc_log "  Downloaded $done / $total files"; fi
    fi
  done < <(python3 - "$manifest" <<'EOF'
import json,sys
manifest = json.load(open(sys.argv[1]))
for entry in manifest["downloads"]:
    print(entry["url"] + "\t" + entry["path"] + "\t" + entry["hash"] + "\t" + entry.get("algorithm", "SHA1"))
EOF
)
  for pid in "${pending[@]}"; do wait "$pid" || failed=1; done
  if ((failed != 0)); then gc_fail "One or more downloads failed (see messages above)."; fi
  gc_log "  Verified $total files"
}

gc_steam_roots() {
  local -a roots=()
  for candidate in "$HOME/.steam/steam" "$HOME/.local/share/Steam" \
    "$GC_FLATPAK_STEAM_HOME/.steam/steam" "$GC_FLATPAK_STEAM_HOME/.local/share/Steam"; do
    [[ -d "$candidate" ]] && roots+=("$candidate")
  done
  printf '%s\n' "${roots[@]}"
}

gc_find_gmod() {
  # Prints each GarrysMod game folder with a Linux client layout.
  local -a libraries=()
  while IFS= read -r root; do
    [[ -n "$root" ]] && libraries+=("$root")
    local vdf="$root/steamapps/libraryfolders.vdf"
    if [[ -f "$vdf" ]]; then
      while IFS= read -r path; do
        [[ -n "$path" ]] && libraries+=("$path")
      done < <(grep -oP '"path"\s+"\K[^"]+' "$vdf" || true)
    fi
  done < <(gc_steam_roots)
  local -a seen=()
  for library in "${libraries[@]}"; do
    local game="$library/steamapps/common/GarrysMod"
    local skip=0
    for have in "${seen[@]:-}"; do [[ "$have" == "$game" ]] && skip=1; done
    ((skip)) && continue
    seen+=("$game")
    if [[ -d "$game/bin/linux64" && -d "$game/garrysmod" ]]; then
      echo "$game"
    fi
  done
}

gc_elf_identity() {
  # gc_elf_identity <file> -> "ELF64-X86_64 size=<bytes> sha256=<hex>" or fails
  python3 - "$1" <<'EOF'
import hashlib,os,sys
path = sys.argv[1]
with open(path, "rb") as handle:
    header = handle.read(64)
if len(header) < 64 or header[:4] != b"\x7fELF":
    sys.exit("Not an ELF file: " + path)
if header[4] != 2:
    sys.exit("Not a 64-bit ELF file: " + path)
machine = int.from_bytes(header[18:20], "little")
if machine != 62:
    sys.exit("Not an x86-64 ELF file: " + path)
digest = hashlib.sha256()
with open(path, "rb") as handle:
    for chunk in iter(lambda: handle.read(1024 * 1024), b""):
        digest.update(chunk)
print("ELF64-X86_64 size=%d sha256=%s" % (os.path.getsize(path), digest.hexdigest()))
EOF
}

gc_assert_game() {
  # gc_assert_game <game> <release.json> -> prints the resolved game path.
  # Verifies the Linux client layout and every pinned Linux engine build.
  # Prints diagnostics and returns nonzero on failure; the caller reports it.
  local game="$1" manifest="$2"
  if [[ ! -d "$game/bin/linux64" ]]; then
    echo "Cannot find bin/linux64 in: $game
In Steam, select Garry's Mod > Properties > Betas > x86-64.
Wait for the update. Then use Installed Files > Browse and select that folder." >&2
    return 1
  fi
  if [[ ! -d "$game/garrysmod" ]]; then
    echo "Select the GarrysMod folder that contains bin and garrysmod." >&2
    return 1
  fi
  local failures=0
  while IFS=$'\t' read -r rel size sha; do
    local path="$game/$rel"
    if [[ ! -f "$path" ]]; then
      echo "Missing engine file: $path" >&2
      failures=1
      continue
    fi
    local identity
    if ! identity="$(gc_elf_identity "$path" 2>&1)"; then
      echo "$identity" >&2
      failures=1
      continue
    fi
    if [[ -n "$sha" && "$sha" != "null" && "$sha" != "None" ]]; then
      local actual
      actual="$(echo "$identity" | grep -oP 'sha256=\K[0-9a-f]+')"
      local actual_size
      actual_size="$(echo "$identity" | grep -oP 'size=\K[0-9]+')"
      if [[ "$actual" != "$sha" || "$actual_size" != "$size" ]]; then
        echo "Unsupported engine build: $path ($identity)" >&2
        echo "GarryCraft V1 requires the engine builds in docs/INSTALL.md." >&2
        echo "Steam updates can change these files. Use a matching GarryCraft release. Do not replace game .so files." >&2
        failures=1
      fi
    else
      # No pin yet for this Linux build: record measurements for future pinning.
      # Notices go to stderr; only the resolved game path uses stdout.
      echo "Unpinned Linux engine file: $path ($identity)" >&2
    fi
  done < <(python3 - "$manifest" <<'EOF'
import json,sys
manifest = json.load(open(sys.argv[1]))
for entry in manifest.get("engineBuilds", []):
    if "linuxPath" not in entry:
        continue
    print(entry["linuxPath"] + "\t" + str(entry.get("size") or "") + "\t" + str(entry.get("sha256") or ""))
EOF
)
  if ((failures != 0)); then
    echo "Engine build check failed (see messages above)." >&2
    return 1
  fi
  gc_realpath "$game"
}

gc_running_gmod() {
  # gc_running_gmod <game> -> prints PIDs of processes executing inside <game>.
  # Mirrors the Windows check, which compares resolved executable paths: a
  # substring match alone would catch our own --gmod-path argument.
  local game="$1" resolved="$1"
  resolved="$(gc_realpath "$game" 2>/dev/null || echo "$game")"
  local pid
  for pid in $(pgrep -f "GarrysMod" || true); do
    # Skip our own process tree.
    local ancestor="$pid"
    while [[ -n "$ancestor" && "$ancestor" != "0" && "$ancestor" != "1" ]]; do
      [[ "$ancestor" == "$$" ]] && break
      ancestor="$(awk '{print $4}' "/proc/$ancestor/stat" 2>/dev/null || true)"
    done
    [[ "$ancestor" == "$$" ]] && continue
    local exe
    exe="$(readlink "/proc/$pid/exe" 2>/dev/null || true)"
    [[ -z "$exe" ]] && continue
    if [[ "$exe" == "$resolved"* ]]; then
      echo "$pid"
    fi
  done
}

gc_native_targets() {
  # gc_native_targets -> prints the relative Linux native module paths
  echo "garrysmod/lua/bin/gmcl_garrycraft_linux64.dll"
  echo "garrysmod/lua/bin/gmsv_garrycraft_linux64.dll"
}

gc_install_game_files() {
  # gc_install_game_files <manual> <game> <backup> [relative...]
  # Copies game files with full rollback when any copy fails.
  local manual="$1" game="$2" backup="$3"
  shift 3
  local -a changed=() existed=()
  local rel
  for rel in "$@"; do
    local destination="$game/$rel" previous="$backup/$rel"
    if [[ -e "$destination" || -L "$destination" ]]; then
      mkdir -p "$(dirname "$previous")"
      cp -a "$destination" "$previous"
      existed+=("1")
    else
      existed+=("0")
    fi
    mkdir -p "$(dirname "$destination")"
    changed+=("$destination")
    if ! cp -f "$manual/$rel" "$destination"; then
      local failure="$rel" i
      for i in "${!changed[@]}"; do
        if [[ "${existed[$i]}" == "1" ]]; then
          cp -f "$backup/${changed[$i]#$game/}" "${changed[$i]}" || gc_warn "Restore this backup manually: $backup/${changed[$i]#$game/} -> ${changed[$i]}"
        else
          rm -f "${changed[$i]}"
        fi
      done
      gc_fail "Cannot install game files: $failure
Close Garry's Mod and rerun install.sh. Previous files are in: $backup"
    fi
  done
}

gc_show_manual_copy() {
  # gc_show_manual_copy <root> <game>
  local root="$1" game="$2"
  gc_log "Manual copy (close Garry's Mod first):"
  gc_log "  $root/manual/garrysmod/addons/garrycraft -> $game/garrysmod/addons/garrycraft"
  gc_log "  $root/manual/garrysmod/lua/bin/gmcl_garrycraft_linux64.dll -> $game/garrysmod/lua/bin/gmcl_garrycraft_linux64.dll"
  gc_log "  $root/manual/garrysmod/lua/bin/gmsv_garrycraft_linux64.dll -> $game/garrysmod/lua/bin/gmsv_garrycraft_linux64.dll"
  gc_log "  $root/manual/garrysmod/data/garrycraft-runtime.json -> $game/garrysmod/data/garrycraft-runtime.json"
  gc_log "  $root/manual/garrysmod/cfg/garrycraft-session.cfg -> $game/garrysmod/cfg/garrycraft-session.cfg"
  gc_log "Minecraft mods: $root/minecraft/mods (already installed)"
  gc_log "After all copies, open: $root/play.sh"
}

gc_release_package() {
  # gc_release_package <version> -> prints the extracted release directory.
  # Source checkouts use the published binaries; build tools stay optional.
  local version="$1"
  local name="GarryCraft-$version-linux-x64.zip"
  local url="https://github.com/PeytonWDYM/GarryCraft/releases/download/v$version/$name"
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local local_release="$(dirname "$script_dir")/release"
  # Progress goes to stderr: stdout carries only the resulting path, which the
  # caller captures with command substitution.
  gc_log "Source checkout detected. Preparing the compiled installer for $version." >&2
  local checksum
  if [[ -f "$local_release/$name.sha256" ]]; then
    checksum="$(cat "$local_release/$name.sha256")"
  else
    checksum="$(curl -fsSL --retry 3 "$url.sha256")" || {
      echo "Cannot download release $version. Check your connection or download the release ZIP from GitHub.
URL: $url.sha256" >&2
      return 1
    }
  fi
  local hash
  hash="$(echo "$checksum" | grep -oP '^[a-fA-F0-9]{64}(?=\s+\*?'"$name"')')" || {
    echo "Invalid release checksum: $url.sha256. Download the release ZIP again." >&2
    return 1
  }
  local cache="$HOME/.local/share/GarryCraft/installers/$version"
  mkdir -p "$cache"
  # A matching local package wins over the published release, so source
  # checkouts install without requiring a published asset.
  if [[ -f "$local_release/$name" ]]; then
    gc_log "Using local release package: $local_release/$name" >&2
    gc_download_one "file://$local_release/$name" "$cache/$name" "$hash" "SHA256" ||
      gc_warn "Local package failed verification, downloading the published release."
  fi
  gc_download_one "$url" "$cache/$name" "$hash" "SHA256"
  local destination="$cache/$hash"
  rm -rf "$destination"
  mkdir -p "$destination"
  unzip -q "$cache/$name" -d "$destination"
  echo "$destination"
}
