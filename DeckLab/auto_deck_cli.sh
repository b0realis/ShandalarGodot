#!/usr/bin/env bash
# AutoDeck CLI — the Deck Builder's AutoDeck tool on the command line, by
# the thousand. All arguments are forwarded to DeckLab/auto_deck_cli.gd;
# run `DeckLab/auto_deck_cli.sh --help` for the full manual, `-V`/`--version`
# for the project's version, and see DeckLab/README.md for the long-form
# documentation.
#
# Uses the project-pinned Godot (../tools/godot), falling back to PATH.
#
# Exit codes (the tool's own; this wrapper adds only 3):
#   0 every deck written
#   1 the run broke   2 the command line was wrong   3 no Godot to run
set -euo pipefail

# THE TOOL LIVES IN THE LAB'S FOLDER, so the Godot project root is one
# level UP from this script — resolved from the script's own path and
# applied exactly once, so that `DeckLab/auto_deck_cli.sh` from the root
# and `./auto_deck_cli.sh` from inside the folder land in the same place.
# (deck_lab.sh's own line, and the reason its comment gives.)
cd "$(cd "$(dirname "$0")/.." && pwd)"

# The family's two shell-side rules, exactly as deck_lab.sh answers them:
# `-V` / `--version` HERE, so a version question never starts an engine,
# and SHANDALAR_NO_BANNER mapped onto the Lab's older DECK_LAB_NO_BANNER
# so one export silences every tool. The banner itself is drawn by
# auto_deck_cli.gd through LabConsole, the Lab's own artwork — this tool
# is the Lab's feeder and wears the Lab's colours.
# AND NO BANNER_HINT HERE, for the Lab's reason: a bare command line is
# answered by the script's own `_usage_hint` with two copyable
# invocations and a pointer to --help, and no artwork on a refusal.
. tools/banner.sh
for arg in "$@"; do
	case "$arg" in
		-V | --version) shandalar_version_line "auto_deck_cli.sh" .; exit 0 ;;
	esac
done
case "${SHANDALAR_NO_BANNER:-}" in
	"" | 0) ;;
	*) export DECK_LAB_NO_BANNER=1 ;;
esac

. tools/runtime.sh
shandalar_find_godot
shandalar_find_timeout

# WHETHER THERE IS A HUMAN LOOKING, which GDScript cannot ask on its own.
# stderr is the channel the banner and the progress bar use, so stderr is
# the stream to test: `auto_deck_cli.sh ... > run.log` keeps the artwork
# on screen and the log clean, while `... > run.log 2>&1` — what a script
# or a cron job writes — gets no decoration at all.
if [ -t 2 ]; then
	export DECK_LAB_TTY=1
	export DECK_LAB_COLUMNS="${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}"
else
	export DECK_LAB_TTY=0
fi

# THE IMPORT WARM-UP, ONLY WHEN IT IS NEEDED — deck_lab.sh's block and
# its reason: Godot's global script-class cache is what `class_name
# AutoDeck` is looked up in, and rebuilding it is otherwise the editor's
# job. It costs ~2.6 s, so it runs when the cache is missing or older
# than a script and not otherwise.
CACHE=.godot/global_script_class_cache.cfg
if [ ! -f "$CACHE" ] \
	|| [ -n "$(find . -name '*.gd' -newer "$CACHE" -not -path './.godot/*' -print -quit 2>/dev/null)" ]; then
	if [ -t 2 ]; then
		echo "auto_deck_cli: importing project resources (first run after an edit)..." >&2
	fi
	"$SHANDALAR_TIMEOUT" -k 5 600 "$GODOT" --headless --import . >/dev/null 2>&1 </dev/null || true
fi

# `--no-header` keeps Godot's own version line out of the output: stdout
# belongs to the tool, and a script reading this run should not have to
# skip two lines of engine banner first.
exec "$GODOT" --headless --no-header --path . \
	--script res://DeckLab/auto_deck_cli.gd -- "$@"
