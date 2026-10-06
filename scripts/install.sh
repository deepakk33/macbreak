#!/usr/bin/env bash
# Builds MacBreak, installs the app bundle, registers the login agent, starts it.
set -euo pipefail

cd "$(dirname "$0")/.."

LABEL="com.user.macbreak"
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"

./scripts/build.sh

# /Applications when writable (Spotlight indexes it for every user), else ~/Applications.
if [ -w /Applications ]; then
    APPS="/Applications"
else
    APPS="$HOME/Applications"
    mkdir -p "$APPS"
fi
APP="$APPS/MacBreak.app"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true

rm -rf "$APP"
cp -R build/MacBreak.app "$APP"
# Nudge Spotlight so "macbreak" is findable immediately rather than eventually.
mdimport "$APP" 2>/dev/null || true

mkdir -p "$HOME/Library/LaunchAgents"
sed "s|__MACBREAK_EXECUTABLE__|$APP/Contents/MacOS/MacBreak|" \
    launchd/com.user.macbreak.plist > "$AGENT"
launchctl bootstrap "gui/$(id -u)" "$AGENT"

echo
echo "Installed app:   $APP"
echo "Installed agent: $AGENT"
echo "Running:"
launchctl list | grep "$LABEL" || echo "  (not listed - check /tmp/macbreak.err.log)"
echo
echo "Press Cmd-Space and type 'macbreak' to open preferences."
