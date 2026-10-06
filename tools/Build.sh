#!/usr/bin/env bash
# Build the Linux x64 native modules and the Fabric mod.
# Mirrors tools/Build.ps1. Requires CMake, a C++20 compiler, and JDK 25.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JAVA_HOME="${JAVA_HOME:-}"

if [[ -z "$JAVA_HOME" ]]; then
  latest="$(ls -d "$HOME/.local/share/GarryCraft/tools/java/"*/ /usr/lib/jvm/java-25-openjdk*/ 2>/dev/null | sort | tail -n 1 || true)"
  if [[ -z "${latest:-}" ]]; then
    echo "Install JDK 25 or set JAVA_HOME." >&2
    exit 1
  fi
  JAVA_HOME="$latest"
fi
export JAVA_HOME

if ! "$JAVA_HOME/bin/java" -version 2>&1 | grep -q 'version "25'; then
  echo "JAVA_HOME must point to JDK 25: $JAVA_HOME" >&2
  exit 1
fi

if ! command -v cmake >/dev/null 2>&1; then
  echo "cmake is required to build the native modules." >&2
  exit 1
fi

cmake -S "$REPO/native" -B "$REPO/native/build" -DCMAKE_BUILD_TYPE=Release
cmake --build "$REPO/native/build" --config Release
"$REPO/fabric/gradlew" -p "$REPO/fabric" build
