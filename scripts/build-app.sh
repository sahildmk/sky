#!/usr/bin/env bash
# Builds Sky and wraps the binary in an app bundle at build/Sky.app.
#
#   CONFIG=debug scripts/build-app.sh                     # debug build
#   SIGN_IDENTITY="Developer ID Application: …" scripts/build-app.sh
#
# Without SIGN_IDENTITY the bundle is signed ad hoc, which is enough to run it
# on the machine that built it.
set -euo pipefail

cd "$(dirname "$0")/.."

config="${CONFIG:-release}"
identity="${SIGN_IDENTITY:--}"
app="build/Sky.app"

swift build -c "$config"
binary="$(swift build -c "$config" --show-bin-path)/Sky"

rm -rf -- "${app:?}"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary" "$app/Contents/MacOS/Sky"
cp Resources/Info.plist "$app/Contents/Info.plist"
if [[ -f Resources/AppIcon.icns ]]; then
  cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
  plutil -replace CFBundleIconFile -string AppIcon "$app/Contents/Info.plist"
fi

codesign --force --options runtime --timestamp=none --sign "$identity" "$app"
echo "Built $app"
