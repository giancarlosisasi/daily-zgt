#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

built="build/Build/Products/Release/DailyZGT.app"
installed="/Applications/DailyZGT.app"

require_not_running() {
  if pgrep -f "^$installed/Contents/MacOS/" >/dev/null; then
    echo "Daily ZGT runs from $installed. Quit the app, then run this script again." >&2
    exit 1
  fi
}

require_not_running

xcodegen generate
xcodebuild \
  -project DailyZGT.xcodeproj \
  -scheme DailyZGT \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath build \
  ONLY_ACTIVE_ARCH=YES \
  build
codesign --verify --deep --strict "$built"

require_not_running

rm -rf "$installed"
ditto "$built" "$installed"
codesign --verify --deep --strict "$installed"

echo "Installed $installed"
