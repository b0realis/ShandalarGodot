#!/usr/bin/env bash
# Lab Query — the questions a program asks before it spends a run:
# `check DECK...`, `packs`, `cards NAME...`, each answered as one JSON
# document on stdout. All arguments are forwarded to DeckLab/lab_query.gd;
# run `DeckLab/lab_query.sh --help` for the manual, `-V`/`--version` for
# the project's version, and see DeckLab/README.md for the long form.
#
# Uses the project-pinned Godot (../tools/godot), falling back to PATH.
#
# Exit codes (the tool's own; this wrapper adds only 3):
#   0 answered (a deck that cannot be played is an answer)
#   1 the answer could not be written   2 the line could not be answered
#   3 no Godot to run
set -euo pipefail

# THE TOOL LIVES IN THE LAB'S FOLDER, so the Godot project root is one
# level UP from this script (deck_lab.sh's own line, and its reason).
cd "$(cd "$(dirname "$0")/.." && pwd)"

# `-V` / `--version` here, so a version question never starts an engine.
# No banner: every answer is one JSON document and stderr carries only a
# refusal's one human line, so there is nothing to decorate.
. tools/banner.sh
for arg in "$@"; do
	case "$arg" in
		-V | --version) shandalar_version_line "lab_query.sh" .; exit 0 ;;
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
		echo "lab_query: importing project resources (first run after an edit)..." >&2
	fi
	"$SHANDALAR_TIMEOUT" -k 5 600 "$GODOT" --headless --import . >/dev/null 2>&1 </dev/null || true
fi

# `--no-header` keeps Godot's own version line out of the output: stdout
# is the answer and nothing else.
exec "$GODOT" --headless --no-header --path . \
	--script res://DeckLab/lab_query.gd -- "$@"
