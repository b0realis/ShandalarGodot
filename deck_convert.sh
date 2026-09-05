#!/usr/bin/env bash
# Deck Convert — translate between the community .deck/.dec format and the
# original MicroProse .dck format. `./deck_convert.sh --help` for usage;
# long-form docs in DeckLab/README.md ("Deck formats").
set -euo pipefail
cd "$(dirname "$0")"

GODOT="${GODOT:-../tools/godot}"
if [ ! -x "$GODOT" ]; then GODOT=godot; fi

"$GODOT" --headless --import . >/dev/null 2>&1 || true
exec "$GODOT" --headless --path . --script res://tools/deck_convert.gd -- "$@"
