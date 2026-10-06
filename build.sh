#!/usr/bin/env bash
# Compiles main.swift and wraps it in MacBreak.app so Spotlight can find it.
# No Xcode, no project file - swiftc plus a hand-written Info.plist.
set -euo pipefail

cd "$(dirname "$0")"

swiftc main.swift -o MacBreak

APP="MacBreak.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
cp MacBreak "$APP/Contents/MacOS/MacBreak"

echo "Built: $(pwd)/MacBreak      (bare binary, for demos)"
echo "Built: $(pwd)/$APP  (bundle, for Spotlight)"
