#!/usr/bin/env bash
# Deck Convert — translate between the community .deck/.dec format and the
# original MicroProse .dck format. `./deck_convert.sh --help` for usage;
# long-form docs in DeckLab/README.md ("Deck formats").
#
#   ./deck_convert.sh INPUT OUTPUT     # formats come from the extensions
#   ./deck_convert.sh -h | --help      # the converter's own manual
#   ./deck_convert.sh -V | --version   # the one version string
set -euo pipefail
cd "$(dirname "$0")"

# THE FAMILY BANNER (tools/banner.sh): stderr, and only on a terminal —
# this tool's stdout is a converted deck's report and the converter's own
# manual, so nothing decorative may land in it.
. tools/banner.sh
BANNER_ROW_0='┌─┐┌─┐┌┐┌┬  ┬┌─┐┬─┐┌┬┐'
BANNER_ROW_1='│  │ ││││└┐┌┘├┤ ├┬┘ │ '
BANNER_ROW_2='└─┘└─┘┘└┘ └┘ └─┘┴└─ ┴ '
BANNER_CAP_0='Shandalar 1997 · deck files'
BANNER_CAP_1='.deck/.dec and the 1997 .dck'
# THE MINI-HELP, for a bare `./deck_convert.sh`. It is the tool with the
# shortest command line and the least obvious one — two paths, and the
# formats come from their extensions — and a bare run used to answer
# "expected INPUT OUTPUT (try --help)" and nothing else. The lines are
# this script's own header and tools/deck_convert.gd's EXAMPLES.
shandalar_banner_hint "$#" \
	'./deck_convert.sh INPUT OUTPUT              # formats from the extensions' \
	'./deck_convert.sh my_brew.deck my_brew.dck  # one of those, for real' \
	'./deck_convert.sh -h                        # the whole manual'

want_help=0
for arg in "$@"; do
	case "$arg" in
		-V | --version) shandalar_version_line "deck_convert.sh" .; exit 0 ;;
		-h | --help) want_help=1 ;;
	esac
done
shandalar_banner .

GODOT="${GODOT:-../tools/godot}"
if [ ! -x "$GODOT" ]; then GODOT=godot; fi

"$GODOT" --headless --import . >/dev/null 2>&1 || true

# `--no-header` keeps Godot's own version line out of stdout, the same
# reason DeckLab/deck_lab.sh passes it: stdout belongs to the tool, and
# whoever reads a conversion should not have to skip an engine banner
# first. (Until 2026-09-11 both `--help` and every conversion opened with
# `Godot Engine v4.7.2.stable...`.)
if [ "$want_help" = 1 ]; then
	# NOT `exec`: the family's banner paragraph is printed after the
	# converter's own manual, so `-h` names the opt-out like every other
	# tool here does.
	"$GODOT" --headless --no-header --path . \
		--script res://tools/deck_convert.gd -- --help
	echo
	shandalar_banner_help
	exit 0
fi
exec "$GODOT" --headless --no-header --path . \
	--script res://tools/deck_convert.gd -- "$@"
