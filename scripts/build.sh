#!/usr/bin/env bash
# Compiles Sources/MacBreak/*.swift and wraps the binary in MacBreak.app so
# Spotlight can find it. No Xcode, no project file - swiftc plus an Info.plist.
set -euo pipefail

cd "$(dirname "$0")/.."

OUT="build"
APP="$OUT/MacBreak.app"

# Left to itself swiftc builds for this Mac's CPU and this Mac's macOS, which
# once shipped a release that needed Apple Silicon and macOS 26. Build both
# CPUs, for the oldest macOS Info.plist promises.
MIN_MACOS=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" Resources/Info.plist)

mkdir -p "$OUT"
for arch in arm64 x86_64; do
    swiftc -target "$arch-apple-macos$MIN_MACOS" Sources/MacBreak/*.swift -o "$OUT/MacBreak-$arch"
done
lipo -create "$OUT/MacBreak-arm64" "$OUT/MacBreak-x86_64" -output "$OUT/MacBreak"
rm "$OUT/MacBreak-arm64" "$OUT/MacBreak-x86_64"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp "$OUT/MacBreak" "$APP/Contents/MacOS/MacBreak"

echo "Built: $(pwd)/$OUT/MacBreak      (bare binary, for demos)"
echo "Built: $(pwd)/$APP  (bundle, for Spotlight)"
