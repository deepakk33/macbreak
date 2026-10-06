#!/usr/bin/env bash
# Compiles Sources/MacBreak/*.swift and wraps the binary in MacBreak.app so
# Spotlight can find it. No Xcode, no project file - swiftc plus an Info.plist.
set -euo pipefail

cd "$(dirname "$0")/.."

OUT="build"
APP="$OUT/MacBreak.app"

mkdir -p "$OUT"
swiftc Sources/MacBreak/*.swift -o "$OUT/MacBreak"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp "$OUT/MacBreak" "$APP/Contents/MacOS/MacBreak"

echo "Built: $(pwd)/$OUT/MacBreak      (bare binary, for demos)"
echo "Built: $(pwd)/$APP  (bundle, for Spotlight)"
