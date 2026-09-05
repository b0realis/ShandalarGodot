#!/usr/bin/env bash
# Release build — exports the "Linux 64" preset (export_presets.cfg) with
# the project-pinned Godot, then smoke-boots what it produced.
#
#   ./build_release.sh              # -> ../shandalar-build/linux64/
#   ./build_release.sh --out DIR    # somewhere else
#   ./build_release.sh --skin       # also (re)link the original graphics
#                                   #    into user://original_skin, so the
#                                   #    exported build looks like the dev
#                                   #    one (see below)
#
# WHAT SHIPS, AND WHAT DOES NOT. The .pck carries game/, engine/, cards/
# (scripts + cards/data/) and every deck under decks/ — about 3 MB. It
# carries NO art: `game/skin.gd` loads the original 1997 graphics and the
# card art with Image.load_from_file from `user://original_skin` (or
# `res://assets/original` in a dev checkout), never through Godot's import
# pipeline, and this project never redistributes the player's copy of the
# original game. An exported build with no skin runs fine and draws the
# clean built-in one. `--skin` symlinks this checkout's assets/ into
# user://original_skin for local testing; `tools/import_original.py
# --dest "$HOME/.local/share/godot/app_userdata/Shandalar/original_skin"`
# is how a player fills it from their own 1997 CD.
#
# Uses the project-pinned Godot (../tools/godot), falling back to PATH.
set -euo pipefail
cd "$(dirname "$0")"

OUT="../shandalar-build/linux64"
PRESET="Linux 64"
LINK_SKIN=0
PACKAGE=0
while [ $# -gt 0 ]; do
	case "$1" in
		--out) OUT="$2"; shift 2 ;;
		--preset) PRESET="$2"; shift 2 ;;
		--skin) LINK_SKIN=1; shift ;;
		--package) PACKAGE=1; shift ;;
		-h|--help) sed -n '2,25p' "$0" | sed 's/^# \?//'; exit 0 ;;
		*) echo "build_release: unknown argument '$1'" >&2; exit 3 ;;
	esac
done

GODOT="${GODOT:-../tools/godot}"
if [ ! -x "$GODOT" ]; then GODOT=godot; fi

mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
BIN="$OUT/Shandalar.x86_64"
LOG="${TMPDIR:-/tmp}/shandalar-export.log"

# Warm the import cache quietly (a cold checkout has no .godot/).
timeout -k 5 900 "$GODOT" --headless --import . >/dev/null 2>&1 </dev/null || true

echo "exporting '$PRESET' -> $BIN"
if ! timeout -k 5 1200 "$GODOT" --headless --path . \
		--export-release "$PRESET" "$BIN" > "$LOG" 2>&1 </dev/null; then
	echo "BUILD FAILED: the export did not finish (log: $LOG)" >&2
	tail -20 "$LOG" >&2
	exit 1
fi
if grep -qiE '^(ERROR|SCRIPT ERROR)|Cannot export project|export template' "$LOG"; then
	echo "BUILD FAILED: the export reported errors (log: $LOG)" >&2
	grep -inE '^(ERROR|SCRIPT ERROR)|Cannot export project|export template' "$LOG" | head -5 >&2
	exit 1
fi
[ -x "$BIN" ] || { echo "BUILD FAILED: no executable at $BIN" >&2; exit 1; }

if [ "$LINK_SKIN" = 1 ]; then
	SKIN="$HOME/.local/share/godot/app_userdata/Shandalar/original_skin"
	mkdir -p "$SKIN"
	# PRUNE BEFORE LINKING. `cp -rsn` only ever ADDS, so anything renamed
	# or deleted in assets/original leaves a DANGLING symlink here — and a
	# dangling link is not nothing: PortraitLibrary lists it as a portrait
	# whose texture is null, so renaming the nine faces to their fourteen
	# 1997 names produced a chooser with nine ghosts in it (2026-09-03).
	find "$SKIN" -xtype l -delete 2>/dev/null || true
	cp -rsn "$PWD/assets/original/." "$SKIN/" 2>/dev/null || true
	[ -e "$SKIN/cardart" ] || ln -s "$PWD/assets/cardart" "$SKIN/cardart"
	echo "linked the original skin + card art into $SKIN"
fi

# Smoke-boot it: a release build that cannot reach its main scene is not a
# build. --quit-after counts FRAMES, so this is a second or two.
SMOKE="${TMPDIR:-/tmp}/shandalar-smoke.log"
if ! timeout -k 5 120 "$BIN" --headless --quit-after 120 \
		> "$SMOKE" 2>&1 </dev/null; then
	echo "BUILD FAILED: the exported game did not boot (log: $SMOKE)" >&2
	tail -20 "$SMOKE" >&2
	exit 1
fi
if grep -qE '^(ERROR|SCRIPT ERROR)' "$SMOKE"; then
	echo "BUILD FAILED: the exported game booted with errors (log: $SMOKE)" >&2
	grep -nE '^(ERROR|SCRIPT ERROR)' "$SMOKE" | head -5 >&2
	exit 1
fi

echo "ok: $(du -sh "$BIN" | cut -f1) binary + $(du -sh "$OUT/Shandalar.pck" | cut -f1) pack"
echo "run it with: $BIN"

# ---------------------------------------------------------------- package --
#
# EVERYTHING IN ONE ZIP, for a machine that has none of this. The .pck
# carries the game and the decks but no art (docs/player-files.md), and the
# art normally lives in the player's own `user://` folder — which does not
# exist on somebody else's computer. So the package puts it BESIDE THE
# EXECUTABLE, where `GameSkin.portable_dir()` looks: unzip, run, done.
#
# Symlinks are DEREFERENCED (`cp -RL`): the dev skin is a tree of links
# into this checkout, and a zip of links is a zip of nothing.
if [ "$PACKAGE" = 1 ]; then
	VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)"
	STAGE="$(dirname "$OUT")/pkg/Shandalar-$VERSION-linux64"
	rm -rf "$STAGE"
	mkdir -p "$STAGE/skin"
	cp -p "$BIN" "$OUT/Shandalar.pck" "$STAGE/"
	[ -f "$OUT/README.txt" ] && cp -p "$OUT/README.txt" "$STAGE/"
	# THE PLAYER'S THREE FILES. setup.txt is the map of every path the
	# built game reads or writes; the two scripts are the only way a
	# player fills those paths, so they travel WITH it rather than being
	# a link in it. All three are read-only text next to the binary.
	cp -p docs/setup.txt "$STAGE/setup.txt"
	# THE DECK LAB, SHIPPED. The scripts ride inside the .pck (the export
	# preset no longer excludes DeckLab/), and the game binary hosts them
	# through its own `--deck-lab` flag — a release template ignores
	# `--script`, so that is the only way in. This launcher is the same
	# one-liner the repo's DeckLab/deck_lab.sh wraps, minus everything
	# that only makes sense in a checkout.
	cp -p DeckLab/README.md "$STAGE/DECKLAB.md"
	cat > "$STAGE/deck_lab.sh" <<'LAB'
#!/usr/bin/env bash
# Deck Lab — headless AI-vs-AI deck testing, run by the game itself.
#
#   ./deck_lab.sh --help
#   ./deck_lab.sh --deck-a res://decks/big_green.deck \
#                 --deck-b res://decks/blue_skies.deck --games 200
#
# The 317 shipped decks live inside the game and are addressed as
# `res://decks/...`; your own are ordinary paths. DECKLAB.md is the manual.
set -euo pipefail
cd "$(dirname "$0")"
[ -t 2 ] && export DECK_LAB_TTY=1 || export DECK_LAB_TTY=0
exec ./Shandalar.x86_64 --headless --no-header -- --deck-lab "$@"
LAB
	chmod +x "$STAGE/deck_lab.sh"
	cp -p tools/mtg_assets.py tools/import_original.py \
	      tools/fetch_card_art.py "$STAGE/"
	echo "packaging art..."
	# The imported 1997 skin (whatever the owner has), its portraits, and
	# the card art, all as real files.
	if [ -d assets/original ]; then
		cp -RLp assets/original/. "$STAGE/skin/" 2>/dev/null || true
		find "$STAGE/skin" -name '*.import' -delete
	fi
	if [ -d assets/cardart ]; then
		mkdir -p "$STAGE/skin/cardart"
		cp -RLp assets/cardart/. "$STAGE/skin/cardart/" 2>/dev/null || true
	fi
	cat > "$STAGE/run.sh" <<'RUNNER'
#!/usr/bin/env bash
# Run the game from wherever this folder happens to be.
cd "$(dirname "$(readlink -f "$0")")"
exec ./Shandalar.x86_64 "$@"
RUNNER
	chmod +x "$STAGE/run.sh"
	ZIP="$(cd "$(dirname "$STAGE")" && pwd)/Shandalar-$VERSION-linux64.zip"
	rm -f "$ZIP"
	(cd "$(dirname "$STAGE")" && zip -qr "$ZIP" "$(basename "$STAGE")")
	echo "package: $ZIP ($(du -h "$ZIP" | cut -f1))"
fi
