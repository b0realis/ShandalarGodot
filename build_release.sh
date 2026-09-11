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
#   ./build_release.sh --package    # + the zip a player unpacks and runs
#                                   #    (the game, the catalogue, icon.png,
#                                   #    shortcut.sh, the tools — NO art),
#                                   #    the same again with the skin zip
#                                   #    in its skin/ ("-with-skin"), the
#                                   #    skin zip beside them as its own
#                                   #    download, the card art zip in
#                                   #    ../shandalar-build/local/ (never
#                                   #    released), and the unzipped folder
#                                   #    left with both packs in its skin/
#                                   #    as the owner's play copy
#   ./build_release.sh --web        # the "Web" preset instead ->
#                                   #    ../shandalar-build/web/index.html
#                                   #    and its .wasm/.pck/.js beside it;
#                                   #    serve the folder over http (a
#                                   #    file:// page cannot fetch the
#                                   #    .wasm). No threads, so any static
#                                   #    host will do — see the preset's
#                                   #    note in export_presets.cfg.example
#   ./build_release.sh --web --skin # + skin/original_skin.zip beside the
#                                   #    page, which the game fetches once
#   ./build_release.sh --web --skin --cardart
#                                   # + skin/cardart.zip beside it too, for
#                                   #    PLAYING THE PAGE LOCALLY — the card
#                                   #    art is never hosted (see below)
#   ./build_release.sh --web --package
#                                   # + the web folder as a zip to unpack
#                                   #    on any static server (the page,
#                                   #    the catalogue, the tools, a
#                                   #    README — NO art) and the same
#                                   #    with the skin zip in ("-with-skin")
#   LINUX_TEMPLATE=release ./build_release.sh …
#                                   # the Linux export on the optimized
#                                   #    template again — with Godot
#                                   #    #87626's error lines in the
#                                   #    terminal (see the export below);
#                                   #    the default is `debug`
#   ./build_release.sh -h           # this block
#   ./build_release.sh -V           # the one version string, from
#                                   #    project.godot — the same one the
#                                   #    zips name themselves with
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
# executable, beside `index.html` for the web build, or chosen in
# Options > Skin / dropped on the running game's window on either (a
# skin zip lands in `user://skins/`, a card pack in `user://cardpacks/`
# where every zip is worn — the places and their settings.cfg keys are
# `game/paths.gd`). With them goes `skin/SKIN.txt`, the catalogue of
# everything the zips hold (docs/skin-catalogue.txt), so a player can
# draw a skin of their own.
#
# WHAT IS RELEASED, AND WHAT IS NOT (the owner, 2026-09-08: "separately
# … Cardart we dont release, only scripts to build it — licence"). The
# package zip carries the game and NO art: it is a 33 MB download (the
# engine deflates well), and the two packs are not folded into it — a
# zip inside a zip does not. The skin zip is its own
# download beside the package (`pkg/original_skin.zip`), dropped into
# the game's `skin/` folder or chosen in Options; and for the player
# who wants one download, the package is written a second time with
# the skin zip already in its `skin/` (`-with-skin.zip`, 117 MB — the
# owner: "a file bundle with release + skin so only cards are needed
# to play"). The web build is zipped the same two ways
# (`-web.zip`, `-web-with-skin.zip`). The card art zip is
# NEVER released: `--package` writes it to `../shandalar-build/local/`
# for the owner's own play, and `tools/fetch_card_art.py` +
# `tools/mtg_assets.py --from-cardart` are how a player builds their
# own. Whether even the skin zip is hosted is the owner's call: `--web
# --skin` places it beside the page, plain `--web` removes it, and
# `--cardart` (with `--web --skin`) adds the card art beside the page
# for a LOCAL serve only — a web folder with `skin/cardart.zip` in it
# is not one to upload.
#
# THE ICON (2026-09-08). The package carries `icon.png` and a
# `shortcut.sh` that writes a desktop entry pointing at the binary and
# the icon — for the player who wants the game in their menu, and only
# then; nothing is installed by unpacking.
#
# Uses the project-pinned Godot (../tools/godot), falling back to PATH.
set -euo pipefail
cd "$(dirname "$0")"

# THE FAMILY BANNER (tools/banner.sh). IT CHANGES NOTHING THIS SCRIPT
# WRITES: it goes to stderr and only when stderr is a terminal, while
# every line a build is judged by — "exporting …", "ok: …", "package: …",
# "release files: …", and every BUILD FAILED — is exactly where it was.
# A redirected or logged build (`./build_release.sh > build.log 2>&1`) is
# byte for byte the build it was before 2026-09-11.
. tools/banner.sh
BANNER_ROW_0='┬─┐┌─┐┬  ┌─┐┌─┐┌─┐┌─┐'
BANNER_ROW_1='├┬┘├┤ │  ├┤ ├─┤└─┐├┤ '
BANNER_ROW_2='┴└─└─┘┴─┘└─┘┴ ┴└─┘└─┘'
BANNER_CAP_0='Shandalar 1997 · the build'
BANNER_CAP_1='export, smoke-boot, package'

# THE USAGE BLOCK IS THE TOP OF THIS FILE, read down to the first prose
# heading instead of to a fixed line number. What this replaced was
# `sed -n '2,50p'`, and the header had long since grown past line 50: by
# 2026-09-11 `--help` stopped mid-sentence, in the middle of "WHAT SHIPS,
# AND WHAT DOES NOT" (found by running it). Every prose section under the
# invocations opens with an ALL-CAPS heading, so that is the delimiter —
# the help now grows and shrinks with the block it quotes.
usage() {
	awk 'NR < 2 { next }
	     !/^#/ { exit }
	     /^# [A-Z][A-Z]/ { exit }
	     { sub(/^# ?/, ""); print }' "$0"
	shandalar_banner_help
}

OUT="../shandalar-build/linux64"
PRESET="Linux 64"
LINK_SKIN=0
PACKAGE=0
WEB=0
CARDART=0
while [ $# -gt 0 ]; do
	case "$1" in
		--out) OUT="$2"; shift 2 ;;
		--preset) PRESET="$2"; shift 2 ;;
		--skin) LINK_SKIN=1; shift ;;
		--package) PACKAGE=1; shift ;;
		--cardart) CARDART=1; shift ;;
		--web) WEB=1; PRESET="Web"; [ "$OUT" = "../shandalar-build/linux64" ] && OUT="../shandalar-build/web"; shift ;;
		-h|--help) usage; exit 0 ;;
		-V|--version) shandalar_version_line "build_release.sh" .; exit 0 ;;
		*) echo "build_release: unknown argument '$1'" >&2; exit 3 ;;
	esac
done
if [ "$CARDART" = 1 ] && { [ "$WEB" != 1 ] || [ "$LINK_SKIN" != 1 ]; }; then
	echo "build_release: --cardart goes with --web --skin (the Linux play copy gets the card art on its own)" >&2
	exit 3
fi
shandalar_banner .

GODOT="${GODOT:-../tools/godot}"
if [ ! -x "$GODOT" ]; then GODOT=godot; fi

mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
BIN="$OUT/Shandalar.x86_64"
[ "$WEB" = 1 ] && BIN="$OUT/index.html"
VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)"
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
# a zip of nothing. Each is written ONCE per build, to its own place —
# the skin zip beside the package as a download of its own, the card
# art zip under ../shandalar-build/local/ where nothing is uploaded
# from — and copied to where a build wants it.
# THE STAGE IS ON DISK, AND A SHORT COPY FAILS THE BUILD (2026-09-08).
# The packs were staged under $TMPDIR — a tmpfs here — with the copy's
# errors dropped (`2>/dev/null || true`); the evening /tmp was nearly
# full, `cp` stopped at "No space left on device" unheard, and the
# card art zip shipped 897 pictures of 0 bytes (91 MB where 184 MB was
# due). Now the stage is a folder beside the build output, on the same
# disk as everything else, the copy's error is the build's, and a
# 0-byte file in the stage is one too — a picture is never empty.
stage_copy() {  # stage_copy SRC_DIR STAGE_DIR — copy SRC_DIR/. into STAGE_DIR, whole or not at all
	local src="$1" stage="$2" short
	if ! cp -RLp "$src/." "$stage/" 2> "$stage.cp.log"; then
		echo "BUILD FAILED: could not stage $src (disk full?):" >&2
		tail -5 "$stage.cp.log" >&2
		rm -rf "$stage" "$stage.cp.log"; exit 1
	fi
	rm -f "$stage.cp.log"
	find "$stage" -name '.gdignore' -delete
	short="$(find "$stage" -type f -size 0 | head -3)"
	if [ -n "$short" ]; then
		echo "BUILD FAILED: empty files in the staged copy of $src (disk full?):" >&2
		echo "$short" >&2
		rm -rf "$stage"; exit 1
	fi
}

skin_zip() {  # skin_zip DEST_FILE — the 1997 material, or nothing without assets/original
	local out="$1" stage log
	log="$WORK_DIR/shandalar-skin-zip.log"
	rm -f "$out"
	[ -d assets/original ] || return 0
	mkdir -p "$(dirname "$out")" "$WORK_DIR"
	stage="$(mktemp -d "$WORK_DIR/shandalar-skin.XXXXXX")"
	stage_copy assets/original "$stage"
	# .import sidecars and the checkout's .gdignore are the editor's, not
	# the skin's; any pictures in the dev skin folder belong to the
	# second zip.
	find "$stage" -name '*.import' -delete
	rm -rf "$stage/cardart"
	python3 tools/mtg_assets.py --from-skin "$stage" --out "$out" > "$log" 2>&1 \
		|| { echo "BUILD FAILED: the skin zip was not written" >&2; cat "$log" >&2; rm -rf "$stage"; exit 1; }
	rm -rf "$stage"
	echo "skin zip: $out ($(du -h "$out" | cut -f1))"
}

cardart_zip() {  # cardart_zip DEST_FILE — the card pictures, or nothing without assets/cardart
	local out="$1" stage log
	log="$WORK_DIR/shandalar-cardart-zip.log"
	rm -f "$out"
	[ -d assets/cardart ] || return 0
	mkdir -p "$(dirname "$out")" "$WORK_DIR"
	stage="$(mktemp -d "$WORK_DIR/shandalar-cardart.XXXXXX")"
	stage_copy assets/cardart "$stage"
	find "$stage" -name '*.import' -delete
	python3 tools/mtg_assets.py --from-cardart "$stage" --out "$out" > "$log" 2>&1 \
		|| { echo "BUILD FAILED: the card art zip was not written" >&2; cat "$log" >&2; rm -rf "$stage"; exit 1; }
	rm -rf "$stage"
	echo "card art zip: $out ($(du -h "$out" | cut -f1)) — NOT a release file"
}

# Where the packs are built: the skin zip with the package, the card art
# zip apart from everything that is uploaded, and the staging folder
# beside them on disk (stage_copy above; each stage removed once zipped).
PKG_DIR="$(cd "$(dirname "$OUT")" && pwd)/pkg"
LOCAL_DIR="$(cd "$(dirname "$OUT")" && pwd)/local"
WORK_DIR="$(cd "$(dirname "$OUT")" && pwd)/tmp"

# NOTHING OF THIS MACHINE IN A PACKAGE. A staged folder is searched for
# the builder's home path before it is zipped — a text file written
# from a checkout path once carried one into a package — and the build
# fails rather than ship it.
guard_stage() {  # guard_stage STAGE_DIR
	local hit
	hit="$(grep -rlF --exclude='*.zip' --exclude='*.pck' --exclude='*.wasm' --exclude='*.x86_64' -- "$HOME" "$1" 2>/dev/null || true)"
	if [ -n "$hit" ]; then
		echo "BUILD FAILED: a file in the package names this machine's home folder:" >&2
		echo "$hit" >&2
		exit 1
	fi
}

# THE TWO ZIPS OF A STAGE: the folder as it is (no art), then again
# with the skin zip in its skin/ — one download for the player who
# wants the 1997 look without assembling it. The stage is left with
# the skin zip in; the caller adds the card art for the play copy.
zip_stage() {  # zip_stage STAGE_DIR NAME — writes PKG_DIR/NAME.zip and NAME-with-skin.zip
	local stage="$1" name="$2" zip
	guard_stage "$stage"
	zip="$PKG_DIR/$name.zip"
	rm -f "$zip" "$PKG_DIR/$name-with-skin.zip"
	(cd "$PKG_DIR" && zip -qr "$zip" "$(basename "$stage")")
	echo "package: $zip ($(du -h "$zip" | cut -f1)) — the game, no art"
	skin_zip "$PKG_DIR/original_skin.zip"
	if [ -f "$PKG_DIR/original_skin.zip" ]; then
		cp -p "$PKG_DIR/original_skin.zip" "$stage/skin/"
		zip="$PKG_DIR/$name-with-skin.zip"
		(cd "$PKG_DIR" && zip -qr "$zip" "$(basename "$stage")")
		echo "package: $zip ($(du -h "$zip" | cut -f1)) — the game with the skin zip in skin/"
	fi
}

# Warm the import cache quietly (a cold checkout has no .godot/).
timeout -k 5 900 "$GODOT" --headless --import . >/dev/null 2>&1 </dev/null || true

# THE DESKTOP BUILD USES THE DEBUG TEMPLATE (2026-09-08), ON PURPOSE.
# Godot's optimized (release) templates carry a bug in embedded popups
# — godotengine/godot #87626 (open since 4.2; the fix in PR #95100 is
# unmerged as of 4.7.2): `Popup::_initialize_visible_parents` connects
# two signals on the parent window, and in the release template the
# disconnect on close no longer matches them, so EVERY tooltip, menu
# and dropdown prints two "Attempt to disconnect a nonexistent
# connection … Signal: 'focus_entered' / 'tree_exited', callable: ''"
# lines on close, two "already connected" on reopen, and at quit the
# whole pile again as the root's tree_exited fires the stale ones —
# the owner's terminal after a game of 0.19.0 (2026-09-08). Nothing
# in the game misbehaves; the connections are no-ops. Reproduced with
# a two-widget project (an OptionButton and a tooltip) exported with
# the 4.7.stable templates: release 14 + 6 lines, debug 0. The debug
# template is the same engine with DEBUG_ENABLED — the build the gate
# tests (the editor binary is one), the same look and the same
# behaviour, 0.2 MB larger, and the headless Deck Lab ~13% slower
# (600 games: 6.4 s -> 7.3 s here). The other cure, native popups
# (`display/window/subwindows/embed_subwindows=false`, 0 lines with
# the release template), makes every tooltip an OS window — a look to
# check on each desktop, not a change to make blind. The web build
# keeps the release template: it never leaves embedding and never
# prints the lines. Needs `custom_template/debug` set in the preset
# (export_presets.cfg.example has both paths).
#
# WHY THE DEBUG TEMPLATE IS QUIET is not pinned, here or upstream — the
# issue's thread reproduces the same split (editor, debug export and
# web clean; release export and every desktop loud) without naming a
# cause, and this repository has not read the optimized binary's
# behaviour, only observed it. What differs between the two templates
# on this path is DEBUG_ENABLED: a `callable_mp` callable is built with
# its method's text only under it (hence the empty `callable: ''` in
# the release lines), and the two callables are matched by a byte
# comparison of {instance, object id, method pointer}. Which of those
# the optimized build gets wrong, and how, is upstream's to find; the
# game just chooses the template that matches.
#
# THE REVERT (2026-09-08). The owner tests 0.20.0-dev on the debug
# template; should a later Godot fix the bug — or the 13% matter more
# than the lines — `LINUX_TEMPLATE=release ./build_release.sh …`
# exports the optimized binary again with nothing else changed (the
# preset keeps both template paths), and the default below is one
# word to edit. Native popups are ruled out (2026-09-08): the owner
# likes the game's windows as they are.
LINUX_TEMPLATE="${LINUX_TEMPLATE:-debug}"
case "$LINUX_TEMPLATE" in
	debug|release) ;;
	*) echo "LINUX_TEMPLATE must be 'debug' or 'release', not '$LINUX_TEMPLATE'" >&2; exit 2 ;;
esac
MODE="--export-$LINUX_TEMPLATE"
[ "$WEB" = 1 ] && MODE=--export-release
echo "exporting '$PRESET' ($MODE) -> $BIN"
if ! timeout -k 5 1200 "$GODOT" --headless --path . \
		"$MODE" "$PRESET" "$BIN" > "$LOG" 2>&1 </dev/null; then
	echo "BUILD FAILED: the export did not finish (log: $LOG)" >&2
	tail -20 "$LOG" >&2
	exit 1
fi
if grep -qiE '^(ERROR|SCRIPT ERROR)|Cannot export project|export template' "$LOG"; then
	echo "BUILD FAILED: the export reported errors (log: $LOG)" >&2
	grep -inE '^(ERROR|SCRIPT ERROR)|Cannot export project|export template' "$LOG" | head -5 >&2
	if grep -q 'Failed to copy export template' "$LOG"; then
		echo "hint: the preset must name BOTH templates by path (custom_template/debug and" >&2
		echo "      custom_template/release) — see export_presets.cfg.example" >&2
	fi
	exit 1
fi

# THE WEB BUILD ENDS HERE: nothing to smoke-boot without a browser (the
# template is JavaScript around a .wasm), so the check is that the three
# files a page needs came out, and the sizes are printed for the hosting
# question — the .wasm is the engine and gzips to a quarter. With
# `--skin` the skin zip goes beside the page as `skin/original_skin.zip`
# with its catalogue (the game fetches it once if it lacks a skin);
# `--cardart` adds `skin/cardart.zip` the same way, for a page served on
# this machine only; without `--skin`, any earlier ones are removed so a
# build without it never hosts the art by accident.
if [ "$WEB" = 1 ]; then
	for f in index.html index.js index.wasm index.pck; do
		[ -s "$OUT/$f" ] || { echo "BUILD FAILED: no $f in $OUT" >&2; exit 1; }
	done
	rm -rf "$OUT/skin"
	if [ "$LINK_SKIN" = 1 ]; then
		mkdir -p "$OUT/skin"
		skin_zip "$PKG_DIR/original_skin.zip"
		[ -f "$PKG_DIR/original_skin.zip" ] && cp -p "$PKG_DIR/original_skin.zip" "$OUT/skin/"
		cp -p docs/skin-catalogue.txt "$OUT/skin/SKIN.txt"
		if [ "$CARDART" = 1 ]; then
			cardart_zip "$LOCAL_DIR/cardart.zip"
			[ -f "$LOCAL_DIR/cardart.zip" ] && cp -p "$LOCAL_DIR/cardart.zip" "$OUT/skin/"
			echo "web: skin/cardart.zip is beside the page for a LOCAL serve — do not upload $OUT with it in"
		fi
	fi
	echo "ok: $(du -sh "$OUT/index.wasm" | cut -f1) engine + $(du -sh "$OUT/index.pck" | cut -f1) pack in $OUT"
	echo "serve it with: python3 -m http.server --directory $OUT 8000   # then open http://localhost:8000/"
	# THE WEB PACKAGE: the page's files, the catalogue, the tools and
	# docs/setup-web.txt as README.txt, zipped twice (zip_stage) — never
	# the card art, whatever `--cardart` put beside the page here.
	if [ "$PACKAGE" = 1 ]; then
		STAGE="$PKG_DIR/Shandalar-$VERSION-web"
		rm -rf "$STAGE"
		mkdir -p "$STAGE/skin" "$STAGE/tools"
		cp -p "$OUT"/index.* "$STAGE/"
		cp -p docs/skin-catalogue.txt "$STAGE/skin/SKIN.txt"
		cp -p docs/setup-web.txt "$STAGE/README.txt"
		# tool_banner.py is NOT optional here: the four scripts above
		# import it for their banner and their --version, and the stage
		# is flat, so leaving it behind ships four tools that cannot
		# start. tools/test_tool_banner.py pins this list to that fact.
		cp -p tools/mtg_assets.py tools/import_original.py \
		      tools/fetch_card_art.py tools/skin_catalogue.py \
		      tools/tool_banner.py "$STAGE/tools/"
		zip_stage "$STAGE" "Shandalar-$VERSION-web"
		echo "release files: $PKG_DIR/Shandalar-$VERSION-web.zip + $PKG_DIR/Shandalar-$VERSION-web-with-skin.zip"
	fi
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
# THE GAME IN ONE ZIP, for a machine that has none of this — and the art
# apart from it. The .pck carries the game and the decks but no art
# (docs/player-files.md); the package carries the `skin/` folder with
# only the catalogue in it, which is the door: `skin/original_skin.zip`
# dropped there (its own download, written beside the package) is
# mounted at the next start, and a card pack built with the tools goes
# beside it as `skin/cardart.zip`. The staged folder the zip was made
# from is then given both packs, so the owner has a copy to play
# without assembling one; the zip has neither.
if [ "$PACKAGE" = 1 ]; then
	STAGE="$PKG_DIR/Shandalar-$VERSION-linux64"
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
	# THE PLAYER'S THREE FILES. setup.txt is the map of every path the
	# built game reads or writes; the two scripts are the only way a
	# player fills those paths, so they travel WITH it rather than being
	# a link in it. All three are read-only text next to the binary.
	cp -p docs/setup.txt "$STAGE/setup.txt"
	# THE DECK LAB, SHIPPED. The scripts ride inside the .pck (the export
	# preset no longer excludes DeckLab/), and the game binary hosts them
	# through its own `--deck-lab` flag — an export template ignores
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
# The 319 shipped decks live inside the game and are addressed as
# `res://decks/...`; your own are ordinary paths. DECKLAB.md is the manual.
set -euo pipefail
cd "$(dirname "$0")"
[ -t 2 ] && export DECK_LAB_TTY=1 || export DECK_LAB_TTY=0
exec ./Shandalar.x86_64 --headless --no-header -- --deck-lab "$@"
LAB
	chmod +x "$STAGE/deck_lab.sh"
	# tool_banner.py rides with them — see the web stage above.
	cp -p tools/mtg_assets.py tools/import_original.py \
	      tools/fetch_card_art.py tools/skin_catalogue.py \
	      tools/tool_banner.py "$STAGE/"
	cp -p docs/skin-catalogue.txt "$STAGE/skin/SKIN.txt"
	cat > "$STAGE/run.sh" <<'RUNNER'
#!/usr/bin/env bash
# Run the game from wherever this folder happens to be.
cd "$(dirname "$(readlink -f "$0")")"
exec ./Shandalar.x86_64 "$@"
RUNNER
	chmod +x "$STAGE/run.sh"
	# The two zips, then the card art — where nothing is released from,
	# and into the play copy.
	echo "packaging art..."
	zip_stage "$STAGE" "Shandalar-$VERSION-linux64"
	cardart_zip "$LOCAL_DIR/cardart.zip"
	[ -f "$LOCAL_DIR/cardart.zip" ] && cp -p "$LOCAL_DIR/cardart.zip" "$STAGE/skin/"
	echo "release files: $PKG_DIR/Shandalar-$VERSION-linux64.zip + $PKG_DIR/Shandalar-$VERSION-linux64-with-skin.zip + $PKG_DIR/original_skin.zip"
	echo "play copy (both packs in skin/, not for release): $STAGE/"
fi
