#!/usr/bin/env bash
# Deck Lab — headless AI-vs-AI deck testing. All arguments are forwarded
# to DeckLab/simulate.gd; run `DeckLab/deck_lab.sh --help` for the full manual,
# and see DeckLab/README.md for the long-form documentation.
#
# Uses the project-pinned Godot (../tools/godot), falling back to PATH.
#
# Exit codes (the Lab's own; this wrapper adds only 3):
#   0 a finished run, every output file written
#   1 the run broke   2 the command line was wrong   3 no Godot to run
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
if [ ! -x "$GODOT" ] && ! command -v "$GODOT" >/dev/null 2>&1; then
	GODOT=godot
fi
if [ ! -x "$GODOT" ] && ! command -v "$GODOT" >/dev/null 2>&1; then
	# A MISSING ENGINE IS NOT A DECK PROBLEM, and `exec: not found` does
	# not say which of the two it is. Exit 3, and say where to point it.
	echo "deck_lab: no Godot binary to run." >&2
	echo "  looked for: ../tools/godot (the project-pinned 4.7.2), then godot on PATH." >&2
	echo "  set one explicitly:  GODOT=/path/to/godot DeckLab/deck_lab.sh ..." >&2
	exit 3
fi

# WHETHER THERE IS A HUMAN LOOKING, which GDScript cannot ask on its own.
# stderr is the channel the banner and the progress bar use, so stderr is
# the stream to test: `deck_lab.sh ... > run.log` keeps the artwork on
# screen and the log clean, while `... > run.log 2>&1` — what a script or
# an agent writes — gets no decoration at all. `tput` needs a terminal
# itself, hence the fallback; DeckLab/lab_console.gd clamps the width.
if [ -t 2 ]; then
	export DECK_LAB_TTY=1
	export DECK_LAB_COLUMNS="${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}"
else
	export DECK_LAB_TTY=0
fi

# THE IMPORT WARM-UP, ONLY WHEN IT IS NEEDED. It costs ~2.6 s, and it ran
# on every invocation — a fifth of a 20-game smoke. What it is actually
# for is Godot's global script-class cache (`class_name` lookups) and the
# import of any new resource, so it runs when that cache is missing or
# older than a script. Rebuilding it is otherwise the editor's job.
CACHE=.godot/global_script_class_cache.cfg
if [ ! -f "$CACHE" ] \
	|| [ -n "$(find . -name '*.gd' -newer "$CACHE" -not -path './.godot/*' -print -quit 2>/dev/null)" ]; then
	if [ -t 2 ]; then
		echo "deck_lab: importing project resources (first run after an edit)..." >&2
	fi
	"$GODOT" --headless --import . >/dev/null 2>&1 </dev/null || true
fi

# `--no-header` keeps Godot's own version line out of the report: stdout
# belongs to the tool, and a machine reading this run should not have to
# skip two lines of engine banner first.
exec "$GODOT" --headless --no-header --path . \
	--script res://DeckLab/simulate.gd -- "$@"
