#!/usr/bin/env bash
# Prepare the private Linux Minecraft runtime. Mirrors
# installer/Prepare-Runtime.ps1. Sourced by install.sh.
set -euo pipefail

prepare_runtime() {
  # prepare_runtime <release.json> <root> <package> [noDownloadCache: 0|1]
  local manifest="$1" root="$2" package="$3" no_cache="${4:-0}"
  local -a caches=()
  if [[ "$no_cache" != "1" ]]; then
    caches=("$HOME/.minecraft" "$HOME/.gradle/caches/fabric-loom")
  else
    gc_log "External download caches disabled. Fresh installations download every dependency."
  fi
  gc_log "[2/4] Download Java 25, Minecraft, Fabric, and assets"
  gc_download_all "$manifest" "$root" "${caches[@]+"${caches[@]}"}"

  local java_home_name
  java_home_name="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["javaHome"])' "$manifest")"
  local java_dir="$root/java"
  if [[ ! -x "$java_dir/$java_home_name/bin/java" ]]; then
    if [[ ! -f "$root/java.tar.gz" ]]; then
      gc_fail "Missing Java archive: $root/java.tar.gz. Rerun install.sh to download it."
    fi
    mkdir -p "$java_dir"
    tar -xzf "$root/java.tar.gz" -C "$java_dir"
  fi
  local java
  java="$(gc_realpath "$java_dir/$java_home_name/bin/java")"
  local release_info
  release_info="$(cat "$java_dir/$java_home_name/release")"
  if ! echo "$release_info" | grep -q 'JAVA_VERSION="25\.'; then
    gc_fail "The downloaded Java runtime must be Java 25."
  fi
  if ! echo "$release_info" | grep -q 'OS_ARCH="\(amd64\|x86_64\)"'; then
    gc_fail "The downloaded Java runtime must be Linux x64."
  fi
  if ! echo "$release_info" | grep -qi 'OS_NAME="Linux"'; then
    gc_fail "The downloaded Java runtime must be a Linux build."
  fi

  mkdir -p "$root/minecraft/mods" "$root/settings" "$root/worlds"
  cp -f "$package/payload/minecraft/mods/garrycraft.jar" "$root/minecraft/mods/garrycraft.jar"

  local classpath mods main_class minecraft_version asset_index
  classpath="$(python3 -c 'import json,sys; print(":".join(json.load(open(sys.argv[1]))["classpath"]))' "$manifest")"
  mods="minecraft/mods/garrycraft.jar:minecraft/mods/fabric-api.jar"
  main_class="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["mainClass"])' "$manifest")"
  minecraft_version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["minecraft"])' "$manifest")"
  asset_index="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["assetIndex"])' "$manifest")"

  # One double-quoted Java argument-file entry per line. The argfile format is
  # platform independent; only the classpath and module separators are Linux.
  python3 - "$root/java.args" "$mods" "$classpath" "$main_class" "$minecraft_version" "$asset_index" <<'EOF'
import sys
_ignored, target, mods, classpath, main_class, minecraft_version, asset_index = sys.argv
values = ['-Xmx3G', '-Dstdout.encoding=UTF-8', '-Dstderr.encoding=UTF-8',
    '--enable-native-access=ALL-UNNAMED', '--add-exports', 'java.base/jdk.internal.misc=ALL-UNNAMED',
    '-XX:StackShadowPages=32', '-Dgarrycraft.autoWorld=true', '-Dfabric.addMods=' + mods, '-cp', classpath,
    main_class, '--username', 'GarryCraft', '--version', minecraft_version,
    '--accessToken', '0', '--assetIndex', asset_index, '--assetsDir', 'assets', '--versionType', 'release']
with open(target, 'w', encoding='utf-8', newline='\n') as handle:
    for value in values:
        handle.write('"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"\n')
EOF

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for name in common.sh play.sh uninstall.sh; do
    cp -f "$script_dir/$name" "$root/$name"
  done
  # tools/runtime.sh ships inside installer/ in the release package.
  if [[ -f "$script_dir/runtime.sh" ]]; then
    cp -f "$script_dir/runtime.sh" "$root/runtime.sh"
  else
    cp -f "$script_dir/../tools/runtime.sh" "$root/runtime.sh"
  fi
  chmod +x "$root/play.sh" "$root/uninstall.sh" "$root/runtime.sh"
  python3 - "$root/config.json" "$java" "$root/worlds" "$root/settings" <<'EOF'
import json,sys
with open(sys.argv[1], 'w', encoding='utf-8', newline='\n') as handle:
    json.dump({"java": sys.argv[2], "worlds": sys.argv[3], "settings": sys.argv[4]}, handle)
EOF
}
