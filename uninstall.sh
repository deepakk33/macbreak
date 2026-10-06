#!/usr/bin/env bash
# Stops MacBreak, removes its login agent and the installed app bundle.
set -euo pipefail

LABEL="com.user.macbreak"
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$AGENT"
rm -rf "/Applications/MacBreak.app" "$HOME/Applications/MacBreak.app"

echo "Removed the launch agent and the app bundle."
echo "Preferences are kept. To clear them too:"
echo "  defaults delete com.user.macbreak"
