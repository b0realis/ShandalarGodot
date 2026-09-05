#!/usr/bin/env bash
# Deck Lab — headless AI-vs-AI deck testing. All arguments are forwarded
# to tools/simulate.gd; run `./deck_lab.sh --help` for the full manual,
# and see docs/deck-lab.md for the long-form documentation.
#
# Uses the project-pinned Godot (../tools/godot), falling back to PATH.
set -euo pipefail
cd "$(dirname "$0")"

GODOT="${GODOT:-../tools/godot}"
if [ ! -x "$GODOT" ]; then GODOT=godot; fi

# Warm the import cache quietly on first run.
"$GODOT" --headless --import . >/dev/null 2>&1 || true

exec "$GODOT" --headless --path . --script res://tools/simulate.gd -- "$@"
