#!/usr/bin/env bash
# Package a Linux x64 release archive. Mirrors tools/Package-Release.ps1.
# Usage: Package-Release.sh [--output-root DIR] [--gmod-path DIR] [--local-only]
# --gmod-path measures the local Linux engine .so files into release.json pins.
# --local-only skips the glibc 2.31 check for a package tested on this machine. Never publish it.
set -euo pipefail

OUTPUT_ROOT=""
GMOD_PATH=""
LOCAL_ONLY=0
while (($# > 0)); do
  case "$1" in
    --output-root) OUTPUT_ROOT="$2"; shift 2 ;;
    --gmod-path) GMOD_PATH="$2"; shift 2 ;;
    --local-only) LOCAL_ONLY=1; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done
if [[ -z "$OUTPUT_ROOT" ]]; then
  OUTPUT_ROOT="$HOME/.local/share/GarryCraft/releases"
fi
OUTPUT_ROOT="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$OUTPUT_ROOT")"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for tool in curl python3 tar unzip zip git objdump; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "The '$tool' command is required for packaging. Install it, then rerun Package-Release.sh." >&2
    exit 1
  fi
done
"$REPO/tools/Build.sh"

VERSION="$(grep -oP '^version=\K.+' "$REPO/fabric/gradle.properties" | tr -d '[:space:]')"
STAGE="$OUTPUT_ROOT/GarryCraft-$VERSION-linux-x64"
if [[ -e "$STAGE" ]]; then
  echo "Use a new output root. The staging directory exists: $STAGE" >&2
  exit 1
fi
mkdir -p "$STAGE/payload/garrysmod/lua/bin" "$STAGE/payload/garrysmod/addons/garrycraft" \
  "$STAGE/payload/minecraft/mods" "$STAGE/installer" "$STAGE/docs"

for realm in gmcl gmsv; do
  found="$(find "$REPO/native/build" -maxdepth 2 -name "${realm}_garrycraft_linux64.dll" -print -quit)"
  if [[ -z "$found" ]]; then
    echo "Missing native module: ${realm}_garrycraft_linux64.dll under $REPO/native/build" >&2
    exit 1
  fi
  # GMod runs inside the Steam Runtime (sniper, glibc 2.31). Newer symbol versions fail to load.
  newest="$(objdump -T "$found" | grep -oE 'GLIBC_[0-9]+\.[0-9]+' | sed 's/GLIBC_//' | sort -V | tail -n 1)"
  if ((!LOCAL_ONLY)) && [[ "$(printf '%s\n2.31\n' "$newest" | sort -V | tail -n 1)" != "2.31" ]]; then
    echo "${realm}_garrycraft_linux64.dll requires glibc $newest; releases must load on glibc 2.31." >&2
    echo "Build inside the Steam Runtime sniper SDK. See docs/RELEASING.md." >&2
    exit 1
  fi
  cp -f "$found" "$STAGE/payload/garrysmod/lua/bin/"
done
cp -r "$REPO/gmod/lua" "$STAGE/payload/garrysmod/addons/garrycraft/"
cp -r "$REPO/gmod/cfg" "$STAGE/payload/garrysmod/"
cp -f "$REPO/fabric/build/libs/garrycraft-$VERSION.jar" "$STAGE/payload/minecraft/mods/garrycraft.jar"
cp -f "$REPO/installer/"*.sh "$STAGE/installer/"
cp -f "$REPO/tools/runtime.sh" "$STAGE/installer/"
for name in README.md LICENSE THIRD_PARTY_NOTICES.md MODLOG.md PARITY.md AGENTS.md install.sh play.sh uninstall.sh; do
  cp -f "$REPO/$name" "$STAGE/"
done
for name in INSTALL.md ARCHITECTURE.md RELEASING.md; do
  cp -f "$REPO/docs/$name" "$STAGE/docs/"
done
cp -r "$REPO/docs/images" "$STAGE/docs/"
mkdir -p "$STAGE/protocol" "$STAGE/tests"
cp -f "$REPO/protocol/README.md" "$STAGE/protocol/"
for name in release-install.md launcher-uninstall.md RESULTS.md physics-blocks.md; do
  cp -f "$REPO/tests/$name" "$STAGE/tests/"
done

BUILD_GRADLE="$(cat "$REPO/fabric/build.gradle")"
MINECRAFT="$(echo "$BUILD_GRADLE" | grep -oP "minecraft 'com\.mojang:minecraft:\K[^']+")"
LOADER="$(echo "$BUILD_GRADLE" | grep -oP "implementation 'net\.fabricmc:fabric-loader:\K[^']+")"
API="$(echo "$BUILD_GRADLE" | grep -oP "implementation 'net\.fabricmc\.fabric-api:fabric-api:\K[^']+")"

export STAGE_DIR="$STAGE" MANIFEST_MINECRAFT="$MINECRAFT" MANIFEST_LOADER="$LOADER" MANIFEST_API="$API"
python3 - <<'EOF'
import hashlib, json, os, urllib.request

stage = os.environ["STAGE_DIR"]
minecraft = os.environ["MANIFEST_MINECRAFT"]
loader = os.environ["MANIFEST_LOADER"]
api = os.environ["MANIFEST_API"]
downloads = {}
classpath = []

def fetch_json(url):
    request = urllib.request.Request(url, headers={"User-Agent": "GarryCraft/1.0"})
    with urllib.request.urlopen(request, timeout=300) as response:
        return json.load(response)

def fetch_text(url):
    request = urllib.request.Request(url, headers={"User-Agent": "GarryCraft/1.0"})
    with urllib.request.urlopen(request, timeout=300) as response:
        return response.read().decode("utf-8").strip()

def download(url, path, checksum, algorithm="SHA1"):
    downloads[path] = {"url": url, "path": path, "hash": checksum, "algorithm": algorithm}

def library_path(name):
    parts = name.split(":")
    suffix = "-" + parts[3] if len(parts) == 4 else ""
    return "%s/%s/%s/%s-%s%s.jar" % (
        parts[0].replace(".", "/"), parts[1], parts[2], parts[1], parts[2], suffix)

with urllib.request.urlopen("https://piston-meta.mojang.com/mc/game/version_manifest_v2.json", timeout=300) as response:
    versions = json.load(response)
entry = next((version for version in versions["versions"] if version["id"] == minecraft), None)
if entry is None:
    raise SystemExit("Minecraft %s is missing from Mojang's manifest." % minecraft)
game = fetch_json(entry["url"])
download(game["downloads"]["client"]["url"], "versions/%s/client.jar" % minecraft,
    game["downloads"]["client"]["sha1"])
profile = fetch_json("https://meta.fabricmc.net/v2/versions/loader/%s/%s/profile/json" % (minecraft, loader))
fabric_names = set()
for library in profile["libraries"]:
    path = library_path(library["name"])
    url = library["url"] + path
    sha1 = library.get("sha1") or fetch_text(url + ".sha1")
    download(url, "libraries/" + path, sha1)
    classpath.append("libraries/" + path)
    fabric_names.add(":".join(library["name"].split(":")[:2]))
for library in game["libraries"]:
    allowed = not library.get("rules")
    for rule in library.get("rules", []):
        os_rule = rule.get("os", {})
        matches = (not os_rule.get("name") or os_rule["name"] == "linux") and \
            (not os_rule.get("arch") or os_rule["arch"] in ("x86_64", "amd64", "x64"))
        if matches:
            allowed = rule["action"] == "allow"
    if not allowed or ":".join(library["name"].split(":")[:2]) in fabric_names:
        continue
    artifact = library["downloads"]["artifact"]
    download(artifact["url"], "libraries/" + artifact["path"], artifact["sha1"])
    classpath.append("libraries/" + artifact["path"])
classpath.append("versions/%s/client.jar" % minecraft)
api_url = "https://maven.fabricmc.net/net/fabricmc/fabric-api/fabric-api/%s/fabric-api-%s.jar" % (api, api)
download(api_url, "minecraft/mods/fabric-api.jar", fetch_text(api_url + ".sha1"))
download(game["assetIndex"]["url"], "assets/indexes/%s.json" % game["assetIndex"]["id"], game["assetIndex"]["sha1"])
assets = fetch_json(game["assetIndex"]["url"])
for name, info in assets["objects"].items():
    digest = info["hash"]
    path = "%s/%s" % (digest[:2], digest)
    download("https://resources.download.minecraft.net/%s" % path, "assets/objects/" + path, digest)

# Record the exact Java archive and checksum in each release, even if newer Java 25 builds appear later.
java = fetch_json("https://api.adoptium.net/v3/assets/latest/25/hotspot?architecture=x64&image_type=jre&os=linux")[0]
download(java["binary"]["package"]["link"], "java.tar.gz", java["binary"]["package"]["checksum"], "SHA256")
java_home = java["release_name"] + "-jre"

with open(os.path.join(stage, "manifest-downloads.json"), "w", encoding="utf-8") as handle:
    json.dump({"downloads": sorted(downloads.values(), key=lambda item: item["path"]),
        "classpath": classpath, "minecraft": minecraft, "loader": loader, "api": api,
        "javaHome": java_home, "assetIndex": game["assetIndex"]["id"],
        "mainClass": profile["mainClass"]}, handle, indent=2)
EOF

# Assemble release.json: payload hashes plus the download manifest above.
python3 - "$STAGE" "$REPO" "$VERSION" "$GMOD_PATH" <<'EOF'
import hashlib, json, os, subprocess, sys
stage, repo, version, gmod = sys.argv[1:5]
with open(os.path.join(stage, "manifest-downloads.json"), encoding="utf-8") as handle:
    parts = json.load(handle)
payload = []
for root, _dirs, files in os.walk(os.path.join(stage, "payload")):
    for name in files:
        full = os.path.join(root, name)
        digest = hashlib.sha256()
        with open(full, "rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
        payload.append({"path": os.path.relpath(full, os.path.join(stage, "payload")).replace(os.sep, "/"),
            "sha256": digest.hexdigest().upper()})
payload.sort(key=lambda item: item["path"])
linux_libs = ["bin/linux64/client_client.so", "bin/linux64/engine_client.so",
    "bin/linux64/studiorender_client.so", "bin/linux64/materialsystem_client.so"]
engine_builds = []
for rel in linux_libs:
    entry = {"linuxPath": rel, "size": None, "sha256": None}
    if gmod and os.path.isfile(os.path.join(gmod, rel)):
        full = os.path.join(gmod, rel)
        digest = hashlib.sha256()
        with open(full, "rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
        entry["size"] = os.path.getsize(full)
        entry["sha256"] = digest.hexdigest()
    engine_builds.append(entry)
commit = subprocess.run(["git", "-C", repo, "rev-parse", "HEAD"],
    capture_output=True, text=True).stdout.strip()
manifest = {"version": version, "commit": commit, "os": "linux",
    "minecraft": parts["minecraft"], "loader": parts["loader"], "api": parts["api"],
    "javaHome": parts["javaHome"], "assetIndex": parts["assetIndex"], "mainClass": parts["mainClass"],
    "payload": payload, "downloads": parts["downloads"], "classpath": parts["classpath"],
    "engineBuilds": engine_builds}
with open(os.path.join(stage, "release.json"), "w", encoding="utf-8") as handle:
    json.dump(manifest, handle, indent=2)
    handle.write("\n")
os.remove(os.path.join(stage, "manifest-downloads.json"))
EOF

ZIP="$STAGE.zip"
rm -f "$ZIP"
# Archive the stage contents (like Compress-Archive "$stage/*"), so the
# release root holds installer/, payload/, install.sh, and release.json.
(cd "$STAGE" && zip -qr "$ZIP" . -x '*/.*')
(cd "$OUTPUT_ROOT" && sha256sum "$(basename "$ZIP")" >"$ZIP.sha256")
echo "Release: $ZIP"
echo "Checksum: $ZIP.sha256"
NOTES="$OUTPUT_ROOT/GarryCraft-$VERSION-release-notes.md"
sed "s/{version}/$VERSION/g" "$REPO/docs/RELEASE_NOTES_LINUX.md" >"$NOTES"
echo "Release notes: $NOTES"
