#!/usr/bin/env bash
# Stops MacBreak and removes its login agent.
set -euo pipefail

LABEL="com.user.macbreak"
TARGET="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$TARGET"

echo "Removed: $TARGET"
echo "Preferences are kept. To clear them too:"
echo "  defaults delete MacBreak"
