#!/usr/bin/env bash
# One-line installer:
#   curl -fsSL https://raw.githubusercontent.com/deepakk33/macbreak/main/scripts/bootstrap.sh | bash
#
# Clones MacBreak into ~/.local/share/macbreak, compiles it from source and
# registers the login agent. Nothing is downloaded pre-built, so there is no
# Gatekeeper prompt and nothing to trust but the source you can read first.
set -euo pipefail

REPO="https://github.com/deepakk33/macbreak.git"
DEST="${MACBREAK_SRC:-$HOME/.local/share/macbreak}"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "MacBreak is macOS only." >&2
    exit 1
fi

if ! command -v swiftc >/dev/null 2>&1; then
    echo "Swift tooling is missing. Run this first, then try again:" >&2
    echo "  xcode-select --install" >&2
    exit 1
fi

if [ -d "$DEST/.git" ]; then
    echo "Updating $DEST"
    git -C "$DEST" pull --ff-only
else
    echo "Cloning into $DEST"
    mkdir -p "$(dirname "$DEST")"
    git clone --depth 1 "$REPO" "$DEST"
fi

"$DEST/scripts/install.sh"

echo
echo "Source lives in $DEST - update later with:"
echo "  curl -fsSL https://raw.githubusercontent.com/deepakk33/macbreak/main/scripts/bootstrap.sh | bash"
