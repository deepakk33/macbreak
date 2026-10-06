#!/usr/bin/env bash
# Builds MacBreak, registers it as a login agent, and starts it.
set -euo pipefail

cd "$(dirname "$0")"

LABEL="com.user.macbreak"
EXECUTABLE="$(pwd)/MacBreak"
TARGET="$HOME/Library/LaunchAgents/$LABEL.plist"

./build.sh

mkdir -p "$HOME/Library/LaunchAgents"
sed "s|__MACBREAK_EXECUTABLE__|$EXECUTABLE|" com.user.macbreak.plist > "$TARGET"

# Replace any previous instance before loading the new one.
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$TARGET"

echo "Installed: $TARGET"
echo "Running:"
launchctl list | grep "$LABEL" || echo "  (not listed - check /tmp/macbreak.err.log)"
