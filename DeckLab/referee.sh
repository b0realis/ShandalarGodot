#!/usr/bin/env bash
# Referee — one duel played through a pipe, a program in a seat: every
# decision out on stdout as one JSON line (the seat's legal options and
# its view), the action back on stdin as one JSON line. All arguments
# are forwarded to DeckLab/referee.gd; run `DeckLab/referee.sh --help`
# for the manual, `-V`/`--version` for the project's version, and see
# DeckLab/README.md and AGENTS.md for the long form.
#
# Uses the project-pinned Godot (../tools/godot), falling back to PATH.
#
# Exit codes (the tool's own; this wrapper adds only 3):
#   0 a result line was written   1 a file could not be written
#   2 the line could not be run   3 no Godot to run
set -euo pipefail

# THE TOOL LIVES IN THE LAB'S FOLDER, so the Godot project root is one
# level UP from this script (deck_lab.sh's own line, and its reason).
cd "$(cd "$(dirname "$0")/.." && pwd)"

# `-V` / `--version` here, so a version question never starts an engine.
# No banner: stdout is the pipe and carries JSON lines only.
. tools/banner.sh
for arg in "$@"; do
	case "$arg" in
		-V | --version) shandalar_version_line "referee.sh" .; exit 0 ;;
	esac
done
export DECK_LAB_NO_BANNER=1
export DECK_LAB_TTY=0

. tools/runtime.sh
shandalar_find_godot
shandalar_find_timeout

# THE IMPORT WARM-UP, ONLY WHEN IT IS NEEDED — deck_lab.sh's block and
# its reason: the global script-class cache is what `class_name` is
# looked up in, and it is otherwise the editor's job to rebuild.
CACHE=.godot/global_script_class_cache.cfg
if [ ! -f "$CACHE" ] \
	|| [ -n "$(find . -name '*.gd' -newer "$CACHE" -not -path './.godot/*' -print -quit 2>/dev/null)" ]; then
	if [ -t 2 ]; then
		echo "referee: importing project resources (first run after an edit)..." >&2
	fi
	"$SHANDALAR_TIMEOUT" -k 5 600 "$GODOT" --headless --import . >/dev/null 2>&1 </dev/null || true
fi

# THROUGH THE GAME'S OWN DOOR, not `--script`: the lobby classes the
# referee names read the CardPacks autoload at compile time, and a
# `--script` main loop is compiled before the autoloads exist (the
# note in tools/lan_smoke.gd). game/main.gd routes `--referee` to
# DeckLab/referee.gd before the screen is built, exactly as a release
# does. `--no-header` keeps Godot's own version line off the pipe.
exec "$GODOT" --headless --no-header --path . -- --referee "$@"
