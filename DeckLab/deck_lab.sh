#!/usr/bin/env bash
# Deck Lab — headless AI-vs-AI deck testing. All arguments are forwarded
# to DeckLab/simulate.gd; run `DeckLab/deck_lab.sh --help` for the full manual,
# and see DeckLab/README.md for the long-form documentation.
#
# Uses the project-pinned Godot (../tools/godot), falling back to PATH.
set -euo pipefail

# THE LAB LIVES IN ITS OWN FOLDER (2026-09-05), so the Godot project root
# is one level UP from this script. Resolved from the script's own path
# and applied exactly once — the line this replaced did `cd "$(dirname
# "$0")"`, which was right while the script sat at the root and put the
# shell inside DeckLab/ afterwards. Both `DeckLab/deck_lab.sh` from the
# root and `./deck_lab.sh` from inside the folder now land in the same
# place.
cd "$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-../tools/godot}"
if [ ! -x "$GODOT" ]; then GODOT=godot; fi

# Warm the import cache quietly on first run.
"$GODOT" --headless --import . >/dev/null 2>&1 || true

exec "$GODOT" --headless --path . --script res://DeckLab/simulate.gd -- "$@"
