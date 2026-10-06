#!/usr/bin/env bash
# Own one Java process per map heartbeat. Mirrors tools/Runtime.ps1.
# Usage: runtime.sh -Config <config.json> -DataPath <garrysmod/data> -HostPid <pid>
set -uo pipefail

CONFIG=""
DATA_PATH=""
HOST_PID=""
while (($# > 0)); do
  case "$1" in
    -Config) CONFIG="$2"; shift 2 ;;
    -DataPath) DATA_PATH="$2"; shift 2 ;;
    -HostPid) HOST_PID="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done
if [[ -z "$CONFIG" || -z "$DATA_PATH" || -z "$HOST_PID" ]]; then
  echo "Usage: runtime.sh -Config <config.json> -DataPath <dir> -HostPid <pid>" >&2
  exit 1
fi

ROOT="$(dirname "$CONFIG")"
JAVA="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["java"])' "$CONFIG")"
WORLDS="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["worlds"])' "$CONFIG")"

# Only one launcher owns the runtime. A second map host exits quietly.
exec {LOCK_FD}>"$ROOT/.garrycraft-lock"
if ! flock -n "$LOCK_FD"; then
  exit 0
fi
exec >>"$ROOT/launcher-$HOST_PID.log" 2>&1

REQUEST_PATH="$DATA_PATH/garrycraft-runtime-request.json"
STATUS_PATH="$DATA_PATH/garrycraft-runtime-status.json"
CLIENT_PID=""
CONTROL=""
MAP_ROOT=""
CURRENT_MAP=""
CURRENT_REQUEST=""
FAILED_REQUEST=""
PUBLISHED_STATUS=""
REQUEST_JSON=""
REQUEST_WRITTEN_AT=0

host_start_time() {
  awk '{print $22}' "/proc/$HOST_PID/stat" 2>/dev/null || echo ""
}
HOST_STARTED="$(host_start_time)"

host_alive() {
  [[ -n "$HOST_PID" ]] && kill -0 "$HOST_PID" 2>/dev/null && [[ "$(host_start_time)" == "$HOST_STARTED" ]]
}

publish_status() {
  # publish_status <state> <message>
  local state="$1" message="$2" java_pid=0
  if [[ -n "$CLIENT_PID" ]] && kill -0 "$CLIENT_PID" 2>/dev/null; then
    java_pid="$CLIENT_PID"
  fi
  local json
  json="$(python3 - --id "$CURRENT_REQUEST" --state "$state" --message "$message" --map "$CURRENT_MAP" \
    --host "$HOST_PID" --java "$java_pid" <<'EOF'
import json,sys
args = dict(zip(sys.argv[1::2], sys.argv[2::2]))
print(json.dumps({"id": args["--id"], "state": args["--state"], "message": args["--message"],
    "map": args["--map"], "hostPid": int(args["--host"]), "javaPid": int(args["--java"])}))
EOF
)"
  if [[ "$json" == "$PUBLISHED_STATUS" ]]; then
    return 0
  fi
  # Status is advisory. Atomic rename keeps readers on the last complete snapshot.
  echo "$json" >"$STATUS_PATH.tmp" && mv -f "$STATUS_PATH.tmp" "$STATUS_PATH"
  PUBLISHED_STATUS="$json"
}

write_control() {
  # write_control <true|false> — retain the world lock until Java releases it.
  local stop="$1" attempt=0
  while ((attempt < 100)); do
    if echo "{\"stop\": $stop}" >"$CONTROL.tmp" 2>/dev/null && mv -f "$CONTROL.tmp" "$CONTROL" 2>/dev/null; then
      return 0
    fi
    sleep 0.05
    attempt=$((attempt + 1))
  done
  return 1
}

client_running() {
  [[ -n "$CLIENT_PID" ]] && kill -0 "$CLIENT_PID" 2>/dev/null
}

stop_client() {
  # stop_client <reason> — ask Java to save and exit; never kill a saving process.
  local reason="$1"
  [[ -z "$CLIENT_PID" ]] && return 0
  echo "Stopping Minecraft PID $CLIENT_PID on $CURRENT_MAP: $reason"
  if client_running; then
    publish_status "saving" "Saving the Minecraft world"
    write_control "true"
    local waited=0
    while client_running && ((waited < 60)); do
      sleep 0.5
      waited=$((waited + 1))
    done
    if client_running; then
      echo "Runtime failed: Minecraft has not finished saving. Read its log before restarting."
      publish_status "error" "Minecraft has not finished saving. Read its log before restarting."
      return 1
    fi
  fi
  wait "$CLIENT_PID" 2>/dev/null || true
  CLIENT_PID=""
  CURRENT_MAP=""
  return 0
}

relative_path() {
  python3 - "$ROOT" "$1" <<'EOF'
import os,sys
try:
    print(os.path.relpath(sys.argv[2], sys.argv[1]))
except ValueError:
    print(sys.argv[2])
EOF
}

argfile_quote() {
  python3 -c 'import sys; print("\"" + sys.argv[1].replace(chr(92), chr(92)*2).replace(chr(34), chr(92)+chr(34)) + "\"")' "$1"
}

fail_runtime() {
  echo "Runtime failed: $1"
  publish_status "error" "$1" || true
  if client_running; then
    write_control "true" || true
    while client_running; do sleep 0.5; done
    wait "$CLIENT_PID" 2>/dev/null || true
  fi
}

if ! host_alive; then
  exit 0
fi

while true; do
  if ! host_alive; then
    break
  fi
  if [[ -f "$REQUEST_PATH" ]]; then
    parsed="$(python3 - "$REQUEST_PATH" <<'EOF' 2>/dev/null
import json,sys
try:
    print(json.dumps(json.load(open(sys.argv[1], encoding="utf-8"))))
except Exception:
    sys.exit(1)
EOF
)" || true
    if [[ -n "${parsed:-}" ]]; then
      REQUEST_JSON="$parsed"
      REQUEST_WRITTEN_AT="$(stat -c %Y "$REQUEST_PATH")"
    fi
  fi
  # Source rewrites the request in place. Empty, partial, or locked reads keep
  # the last complete request. Failed reads never extend the heartbeat deadline.
  now="$(date +%s)"
  fresh=0
  if [[ -n "$REQUEST_JSON" ]] && ((now - REQUEST_WRITTEN_AT < 120)); then
    fresh=1
  fi
  wanted=0
  req_map=""
  req_enabled=""
  if ((fresh)); then
    req_enabled="$(echo "$REQUEST_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("enabled", False))')"
    req_map="$(echo "$REQUEST_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("map", ""))')"
    req_id="$(echo "$REQUEST_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("id", ""))')"
    if [[ "$req_enabled" == "True" ]]; then
      wanted=1
    fi
  fi
  if ((wanted)); then
    # Bash variables cannot hold NUL bytes, so an embedded NUL never survives
    # parsing; reject empty names instead to keep the world folder well-formed.
    if [[ -z "$req_map" ]] || [[ "$req_map" =~ [\\/:*?\"\<\>\|] ]] || [[ "$req_map" == "." || "$req_map" == ".." ]]; then
      fail_runtime "The map name cannot be used as a world folder."
      break
    fi
  fi
  if client_running && { ((wanted == 0)) || [[ "$CURRENT_MAP" != "$req_map" ]]; }; then
    if ((wanted == 0)); then
      FAILED_REQUEST="$CURRENT_REQUEST"
    fi
    if ((fresh == 0)); then
      reason="Source heartbeat expired"
    elif ((wanted == 0)); then
      reason="Source disabled the bridge"
    else
      reason="Map changed to $req_map"
    fi
    stop_client "$reason" || break
  fi
  if [[ -n "$REQUEST_JSON" ]]; then
    CURRENT_REQUEST="$req_id"
  fi
  if [[ -n "$CLIENT_PID" ]] && ! client_running; then
    FAILED_REQUEST="$CURRENT_REQUEST"
    code="unknown"
    wait "$CLIENT_PID" 2>/dev/null && code="0" || code="$?"
    CLIENT_PID=""
    CURRENT_MAP=""
    publish_status "error" "Minecraft exited ($code). Read the map's minecraft-stderr.log and crash-reports."
  fi
  if ((wanted)) && [[ -z "$CLIENT_PID" ]] && [[ "$FAILED_REQUEST" != "$CURRENT_REQUEST" ]]; then
    if [[ ! -f "$ROOT/java.args" ]]; then
      fail_runtime "Missing Java argument file. Rerun install.sh to repair the runtime."
      break
    fi
    CURRENT_MAP="$req_map"
    MAP_ROOT="$WORLDS/$CURRENT_MAP"
    mkdir -p "$MAP_ROOT/minecraft" "$MAP_ROOT/artifacts"
    CONTROL="$MAP_ROOT/control.json"
    READY_PATH="$MAP_ROOT/ready.json"
    rm -f "$READY_PATH"
    write_control "false"
    # Clear the mailbox only after the previous owner has saved and exited.
    BRIDGE="$MAP_ROOT/bridge.bin"
    truncate -s 134217728 "$BRIDGE"
    {
      argfile_quote "-Dgarrycraft.bridge=$(relative_path "$BRIDGE")"
      argfile_quote "-Dgarrycraft.settings=$(relative_path "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["settings"])' "$CONFIG")")"
      argfile_quote "-Dgarrycraft.artifacts=$(relative_path "$MAP_ROOT/artifacts")"
      argfile_quote "-Dgarrycraft.control=$(relative_path "$CONTROL")"
      cat "$ROOT/java.args"
      argfile_quote "--gameDir"
      gamedir="$(relative_path "$MAP_ROOT/minecraft")"
      argfile_quote "$gamedir"
    } >"$MAP_ROOT/launch.args"
    LAUNCH_PATH="$(relative_path "$MAP_ROOT/launch.args")"
    (cd "$ROOT" && exec "$JAVA" @"$LAUNCH_PATH" >>"$MAP_ROOT/minecraft-stdout.log" 2>>"$MAP_ROOT/minecraft-stderr.log") &
    CLIENT_PID=$!
    publish_status "running" "Waiting for Minecraft and map collision"
  elif ((wanted)) && [[ -n "$CLIENT_PID" ]] && [[ -f "$MAP_ROOT/ready.json" ]]; then
    publish_status "ready" "Minecraft is ready"
  elif ((wanted == 0)) && [[ -z "$CLIENT_PID" ]]; then
    publish_status "off" "GarryCraft is off"
  fi
  sleep 0.5
done

stop_client "Source host exited" || true
publish_status "off" "GarryCraft is off" || true
