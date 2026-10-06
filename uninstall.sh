#!/usr/bin/env bash
# GarryCraft Linux uninstall entry point. Mirrors Uninstall.cmd.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$ROOT/installer/uninstall.sh" --package-root "$ROOT" "$@"
