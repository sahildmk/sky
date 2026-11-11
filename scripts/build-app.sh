#!/usr/bin/env bash
# Compatibility entry point. The app bundle now lives in apps/macos/build/.
set -euo pipefail
exec bash "$(dirname "$0")/../apps/macos/scripts/build-app.sh" "$@"
