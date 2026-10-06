#!/usr/bin/env bash
# GarryCraft Linux play entry point. Mirrors Play.cmd.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$ROOT/installer/play.sh" --package-root "$ROOT" "$@"
