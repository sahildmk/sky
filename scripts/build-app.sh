#!/usr/bin/env bash
# Builds Sky and wraps the binary in an app bundle at build/Sky.app.
#
#   scripts/build-app.sh                                   # release, universal, signed ad hoc
#   CONFIG=debug scripts/build-app.sh                      # debug, this Mac's architecture only
#   SIGN_IDENTITY="Developer ID Application: …" scripts/build-app.sh
#
# Release builds run on both Apple silicon and Intel Macs. Signed ad hoc, the
# app runs on the Mac that built it. Signed with a Developer ID, it carries a
# secure timestamp and the hardened runtime, ready for notarisation.
set -euo pipefail

cd "$(dirname "$0")/.."

config="${CONFIG:-release}"
identity="${SIGN_IDENTITY:--}"
app="build/Sky.app"

arch_flags=()
if [[ "$config" == "release" ]]; then
  arch_flags=(--arch arm64 --arch x86_64)
fi

swift build -c "$config" "${arch_flags[@]}"
binary="$(swift build -c "$config" "${arch_flags[@]}" --show-bin-path)/Sky"

rm -rf -- "${app:?}"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary" "$app/Contents/MacOS/Sky"
cp Resources/Info.plist "$app/Contents/Info.plist"
if [[ -f Resources/AppIcon.icns ]]; then
  cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
  plutil -replace CFBundleIconFile -string AppIcon "$app/Contents/Info.plist"
fi

timestamp=(--timestamp)
if [[ "$identity" == "-" ]]; then
  timestamp=(--timestamp=none)
fi
codesign --force --options runtime "${timestamp[@]}" --sign "$identity" "$app"
codesign --verify --strict --verbose=1 "$app"
echo "Built $app"
