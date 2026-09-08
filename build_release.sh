#!/usr/bin/env bash
# Release build — exports the "Linux 64" preset (export_presets.cfg) with
# the project-pinned Godot, then smoke-boots what it produced; or, with
# `--web`, the "Web" preset, which a browser boots instead.
#
#   ./build_release.sh              # -> ../shandalar-build/linux64/
#   ./build_release.sh --out DIR    # somewhere else
#   ./build_release.sh --skin       # also (re)link the original graphics
#                                   #    into user://original_skin, so the
#                                   #    exported build looks like the dev
#                                   #    one (see below)
#   ./build_release.sh --package    # + the zip a player unpacks and runs:
#                                   #    skin/original_skin.zip,
#                                   #    skin/cardart.zip and the
#                                   #    catalogue, icon.png, shortcut.sh
#   ./build_release.sh --web        # the "Web" preset instead ->
#                                   #    ../shandalar-build/web/index.html
#                                   #    and its .wasm/.pck/.js beside it;
#                                   #    serve the folder over http (a
#                                   #    file:// page cannot fetch the
#                                   #    .wasm). No threads, so any static
#                                   #    host will do — see the preset's
#                                   #    note in export_presets.cfg.example
#   ./build_release.sh --web --skin # + skin/original_skin.zip and
#                                   #    skin/cardart.zip beside the page,
#                                   #    which the game fetches once
#
# WHAT SHIPS, AND WHAT DOES NOT. The .pck carries game/, engine/, cards/
# (scripts + cards/data/) and every deck under decks/ — about 5 MB. It
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
# THE SKIN PACKS (2026-09-08). The art travels as TWO ZIPS the game
# mounts in place at boot (`game/skin_pack.gd`): `skin/original_skin.zip`
# (the 1997 material, 84 MB) and `skin/cardart.zip` (one picture per
# card, 193 MB, from Scryfall and so on another licence) — beside the
# executable in the package, beside `index.html` for the web build, or
# chosen in Options > Skin / dropped on the running game's window on
# either. Next to them goes `skin/SKIN.txt`, the catalogue of everything
# the zips hold (docs/skin-catalogue.txt), so a player can draw a skin
# of their own. Whether the art is HOSTED online is the owner's call:
# `--web --skin` places the zips, plain `--web` removes them.
#
# THE ICON (2026-09-08). The package carries `icon.png` and a
# `shortcut.sh` that writes a desktop entry pointing at the binary and
# the icon — for the player who wants the game in their menu, and only
# then; nothing is installed by unpacking.
#
# Uses the project-pinned Godot (../tools/godot), falling back to PATH.
set -euo pipefail
cd "$(dirname "$0")"

OUT="../shandalar-build/linux64"
PRESET="Linux 64"
LINK_SKIN=0
PACKAGE=0
WEB=0
while [ $# -gt 0 ]; do
	case "$1" in
		--out) OUT="$2"; shift 2 ;;
		--preset) PRESET="$2"; shift 2 ;;
		--skin) LINK_SKIN=1; shift ;;
		--package) PACKAGE=1; shift ;;
		--web) WEB=1; PRESET="Web"; [ "$OUT" = "../shandalar-build/linux64" ] && OUT="../shandalar-build/web"; shift ;;
		-h|--help) sed -n '2,50p' "$0" | sed 's/^# \?//'; exit 0 ;;
		*) echo "build_release: unknown argument '$1'" >&2; exit 3 ;;
	esac
done
if [ "$WEB" = 1 ] && [ "$PACKAGE" = 1 ]; then
	echo "build_release: --package is the Linux build's; the web build is served, not unpacked" >&2
	exit 3
fi

GODOT="${GODOT:-../tools/godot}"
if [ ! -x "$GODOT" ]; then GODOT=godot; fi

mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
BIN="$OUT/Shandalar.x86_64"
[ "$WEB" = 1 ] && BIN="$OUT/index.html"
LOG="${TMPDIR:-/tmp}/shandalar-export.log"

# THE SKIN ZIPS, `original_skin.zip` and `cardart.zip`: this checkout's
# assets/original (the imported 1997 skin, whatever the owner has) with
# its portraits, as real files under one `skin/` folder; and the card
# art apart from it, as `skin/cardart/` — the owner, 2026-09-08: "the
# skin assets should be a separate zip, card art pack should be
# separate!" Both written by the same tools/mtg_assets.py a player uses
# on their own disc, so a player's zips and the shipped ones are the
# same shape. Symlinks are DEREFERENCED (`cp -RL`) on the way: the dev
# skin can be a tree of links into this checkout, and a zip of links is
# a zip of nothing. Beside them, the catalogue.
skin_pack() {  # skin_pack DEST_DIR
	local dest="$1" stage log
	log="${TMPDIR:-/tmp}/shandalar-skin-zip.log"
	stage="$(mktemp -d "${TMPDIR:-/tmp}/shandalar-skin.XXXXXX")"
	mkdir -p "$dest"
	rm -f "$dest/original_skin.zip" "$dest/cardart.zip"
	if [ -d assets/original ]; then
		cp -RLp assets/original/. "$stage/" 2>/dev/null || true
		find "$stage" \( -name '*.import' -o -name '.gdignore' \) -delete
		# Any pictures in the dev skin folder belong to the second zip.
		rm -rf "$stage/cardart"
		python3 tools/mtg_assets.py --from-skin "$stage" --out "$dest/original_skin.zip" \
			> "$log" 2>&1 \
			|| { echo "BUILD FAILED: the skin zip was not written" >&2; cat "$log" >&2; rm -rf "$stage"; exit 1; }
	fi
	rm -rf "$stage"
	if [ -d assets/cardart ]; then
		stage="$(mktemp -d "${TMPDIR:-/tmp}/shandalar-cardart.XXXXXX")"
		cp -RLp assets/cardart/. "$stage/" 2>/dev/null || true
		# .import sidecars and the checkout's .gdignore are the editor's,
		# not the skin's.
		find "$stage" \( -name '*.import' -o -name '.gdignore' \) -delete
		python3 tools/mtg_assets.py --from-cardart "$stage" --out "$dest/cardart.zip" \
			> "$log" 2>&1 \
			|| { echo "BUILD FAILED: the card art zip was not written" >&2; cat "$log" >&2; rm -rf "$stage"; exit 1; }
		rm -rf "$stage"
	fi
	cp -p docs/skin-catalogue.txt "$dest/SKIN.txt"
	local said="" f
	for f in original_skin.zip cardart.zip; do
		[ -f "$dest/$f" ] && said="$said $f ($(du -h "$dest/$f" | cut -f1))"
	done
	echo "skin pack: $dest/ —${said:- nothing to zip} + SKIN.txt"
}

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

# THE WEB BUILD ENDS HERE: nothing to smoke-boot without a browser (the
# template is JavaScript around a .wasm), so the check is that the three
# files a page needs came out, and the sizes are printed for the hosting
# question — the .wasm is the engine and gzips to a quarter. With
# `--skin` the two zips go beside the page as `skin/original_skin.zip`
# and `skin/cardart.zip` (the game fetches each it lacks from there,
# once); without, any earlier ones are removed so a build without
# `--skin` never hosts the art by accident.
if [ "$WEB" = 1 ]; then
	for f in index.html index.js index.wasm index.pck; do
		[ -s "$OUT/$f" ] || { echo "BUILD FAILED: no $f in $OUT" >&2; exit 1; }
	done
	if [ "$LINK_SKIN" = 1 ]; then
		skin_pack "$OUT/skin"
	else
		rm -rf "$OUT/skin"
	fi
	echo "ok: $(du -sh "$OUT/index.wasm" | cut -f1) engine + $(du -sh "$OUT/index.pck" | cut -f1) pack in $OUT"
	echo "serve it with: python3 -m http.server --directory $OUT 8000   # then open http://localhost:8000/"
	exit 0
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
# EXECUTABLE as `skin/original_skin.zip` and `skin/cardart.zip`, where
# `SkinPack` mounts them at boot: unzip the package, run, done — the
# zips themselves stay zips.
if [ "$PACKAGE" = 1 ]; then
	VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)"
	STAGE="$(dirname "$OUT")/pkg/Shandalar-$VERSION-linux64"
	rm -rf "$STAGE"
	mkdir -p "$STAGE/skin"
	cp -p "$BIN" "$OUT/Shandalar.pck" "$STAGE/"
	# THE ICON, and the shortcut that uses it — opt-in, run by hand.
	cp -p game/icon.png "$STAGE/icon.png"
	cat > "$STAGE/shortcut.sh" <<'SHORTCUT'
#!/usr/bin/env bash
# Put Shandalar in your application menu, with its icon — or take it out.
#
#   ./shortcut.sh            # write ~/.local/share/applications/shandalar.desktop
#   ./shortcut.sh --remove   # delete it again
#
# The entry points at THIS folder, so move the folder and run it again.
# Nothing else is touched: no files are copied anywhere, and unpacking
# the game never runs this.
set -euo pipefail
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
ENTRY="${XDG_DATA_HOME:-$HOME/.local/share}/applications/shandalar.desktop"
if [ "${1:-}" = "--remove" ]; then
	rm -f "$ENTRY"
	echo "removed $ENTRY"
	exit 0
fi
mkdir -p "$(dirname "$ENTRY")"
cat > "$ENTRY" <<ENTRY
[Desktop Entry]
Type=Application
Name=Shandalar
Comment=A remake of the 1997 Magic: The Gathering
Exec=$HERE/Shandalar.x86_64
Path=$HERE
Icon=$HERE/icon.png
Terminal=false
Categories=Game;CardGame;
ENTRY
chmod +x "$ENTRY"
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$(dirname "$ENTRY")" 2>/dev/null || true
echo "wrote $ENTRY — Shandalar is in your menu (./shortcut.sh --remove undoes it)"
SHORTCUT
	chmod +x "$STAGE/shortcut.sh"
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
	      tools/fetch_card_art.py tools/skin_catalogue.py "$STAGE/"
	echo "packaging art..."
	skin_pack "$STAGE/skin"
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
