#!/usr/bin/env bash
# Compiles main.swift into the MacBreak executable. No Xcode, no bundle.
set -euo pipefail

cd "$(dirname "$0")"
swiftc main.swift -o MacBreak
echo "Built: $(pwd)/MacBreak"
