#!/usr/bin/env bash
# GarryCraft Linux setup entry point. Mirrors Install.cmd.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$ROOT/installer/install.sh" "$@"
