#!/usr/bin/env bash
# Runs the Sky service from this checkout at login, and restarts it if it exits.
set -euo pipefail

label="com.sahildmk.sky.service"
service_dir="$(cd "$(dirname "$0")/.." && pwd)"
bun_path="$(command -v bun)"
plist="$HOME/Library/LaunchAgents/$label.plist"
log_file="$HOME/Library/Logs/Sky/service.log"

mkdir -p "$(dirname "$plist")" "$(dirname "$log_file")"
cat >"$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$label</string>
  <key>ProgramArguments</key>
  <array>
    <string>$bun_path</string>
    <string>src/main.ts</string>
  </array>
  <key>WorkingDirectory</key>
  <string>$service_dir</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$log_file</string>
  <key>StandardErrorPath</key>
  <string>$log_file</string>
</dict>
</plist>
EOF

domain="gui/$(id -u)"
launchctl bootout "$domain/$label" 2>/dev/null || true
launchctl bootstrap "$domain" "$plist"
echo "Installed $label from $service_dir. Logs: $log_file"
