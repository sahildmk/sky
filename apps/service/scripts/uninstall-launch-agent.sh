#!/usr/bin/env bash
# Stops the Sky service and removes its launch agent. The database is left in place.
set -euo pipefail

label="com.sahildmk.sky.service"
plist="$HOME/Library/LaunchAgents/$label.plist"

launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
rm -f -- "$plist"
echo "Removed $label."
