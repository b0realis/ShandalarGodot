#!/usr/bin/env bash
# Shandalar on a Meta Quest: install or update the game over adb, then copy
# the skin, the card art and the card packs into the game's own folders.
# The game's settings and decks are kept. For a clean install from nothing,
# run quest_fresh_install.sh instead.
#
# Run it from the unpacked Shandalar-<version>-meta-quest folder, with the
# headset on USB and `adb devices` listing it:
#
#     ./push_to_quest.sh
#
# THE ROUTE (2026-10-11, the owner's Quest 3). An `adb push` straight into
# the game's folder is refused on current headset software — "remote fchown
# failed: Operation not permitted", after the bytes have gone over. So each
# zip goes to the headset's Download folder first and the headset copies it
# into place (a copy sets no owner), and its size is checked at both stops.
# A zip the headset already holds byte for byte (the same SHA-256) is not
# copied again, and keeps the check the game made of it at an earlier start.
#
# NEVER HALF A ZIP (2026-10-12). The headset copies to `<name>.part` and
# moves it over the old zip only once the size matches, so a headset that
# runs out of space keeps the zip that worked; the free space is read before
# each file (twice the file while it is copied, and 100 MB to spare).
#
# THE FOLDERS must be the game's own: one made from the shell (`adb shell
# mkdir`) is the shell's, and the game cannot enter it. So the game is
# started once to make them before anything is copied.
set -u

P=com.b0realis.shandalar
F=/sdcard/Android/data/$P/files
T=/sdcard/Download/shandalar-push
# The card packs under the names the game reads (each pack's FILE_NAME in
# game/); a zip under any other name is never opened by the game.
PACKS=(Pack-1-DotP-complete.zip Pack-2-Fallen-Empires.zip Pack-3-Ice_Age.zip
	Pack-4-Homelands.zip Pack-5-Alliances.zip Pack-6-Portal.zip
	Pack-7-Fifth-Edition.zip Pack-8-Mirage-Block.zip Pack-9-Tempest-Block.zip)
# Room left free on the headset beyond the copies, so it keeps working.
SPARE_KB=102400

cd -- "$(dirname -- "$0")" || exit 1

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
note() { printf '  %s\n' "$*"; }
ok()   { printf '  \033[32mok\033[0m   %s\n' "$*"; }
warn() { printf '  \033[33m!!\033[0m   %s\n' "$*"; }
fail() { printf '\n  \033[31mSTOPPED:\033[0m %s\n\n' "$*"; exit 1; }
# A command on the headset, its output without Android's carriage returns.
# Every path in one is in single quotes: the headset's shell splits the line.
dev()  { adb shell "$1" 2>/dev/null | tr -d '\r'; }
size_here()  { wc -c < "$1" | tr -d ' '; }
size_there() { dev "stat -c %s '$1' 2>/dev/null"; }
sha_here() {
	if command -v sha256sum > /dev/null; then sha256sum "$1" | cut -d' ' -f1
	else shasum -a 256 "$1" | cut -d' ' -f1; fi
}
sha_there() { dev "sha256sum '$1' 2>/dev/null" | cut -d' ' -f1; }
folders_made() { [ "$(dev "[ -d '$F/skin' ] && [ -d '$F/cardpacks' ] && echo yes")" = yes ]; }
# Free space on the headset in KB, "" when it cannot be read.
free_kb() { dev "df -k /sdcard 2>/dev/null | tail -1" | awk '$4 ~ /^[0-9]+$/ { print $4 }'; }
# KB as megabytes to a tenth, rounded down (room) or up (a need).
mb_down() { awk -v k="$1" 'BEGIN { printf "%.1f", int(k * 10 / 1024) / 10 }'; }
mb_up()   { awk -v k="$1" 'BEGIN { t = k * 10 / 1024; printf "%.1f", (t == int(t) ? t : int(t) + 1) / 10 }'; }
is_pack() { local p; for p in "${PACKS[@]}"; do [ "$p" = "$1" ] && return 0; done; return 1; }
# The pack a misnamed zip most likely is ("Pack-9-… (1).zip"), or "".
pack_like() {
	local n p
	case "$1" in Pack-[0-9]*-*) n=${1#Pack-}; n=${n%%-*} ;; *) return 0 ;; esac
	for p in "${PACKS[@]}"; do case "$p" in "Pack-$n-"*) printf '%s' "$p"; return 0 ;; esac; done
}

VERSION=$(head -1 VERSION.txt 2>/dev/null)
say "Shandalar ${VERSION:-} — install or update on the Meta Quest"
command -v adb > /dev/null || fail "adb is not installed (Debian/Ubuntu: sudo apt install adb)."
[ -f Shandalar.apk ] || fail "Shandalar.apk is not in this folder. Run the script from the unpacked Shandalar-…-meta-quest folder."
DEVICES=$(adb devices 2>/dev/null | tr -d '\r' | awk 'NR > 1 && $2 == "device" { print $1 }')
COUNT=$(printf '%s\n' "$DEVICES" | grep -c . || true)
[ "$COUNT" -eq 1 ] || fail "'adb devices' lists $COUNT ready headsets, not one. Plug the headset in, put it on and allow USB debugging, then run this again."
# Every adb call below goes to this headset, whatever else is plugged in:
# adb counts an unauthorized phone or an offline emulator too, and without
# a serial every command would fail "more than one device/emulator".
export ANDROID_SERIAL="$DEVICES"
[ "$(dev 'echo here')" = here ] || fail "the headset $DEVICES does not answer adb. Unplug it, plug it in again and put it on, then run this again."
ok "headset $DEVICES"

FILES=()
for f in skin/original_skin.zip skin/cardart.zip; do
	[ -f "$f" ] && FILES+=("$f")
done
for name in "${PACKS[@]}"; do
	[ -f "cardpacks/$name" ] && FILES+=("cardpacks/$name")
done
for f in cardpacks/*.zip; do
	[ -f "$f" ] || continue
	name=$(basename "$f")
	is_pack "$name" && continue
	like=$(pack_like "$name")
	if [ -z "$like" ]; then
		warn "$f is not copied: it is not one of the card packs the game reads."
	elif [ -f "cardpacks/$like" ]; then
		warn "$f is not copied: a second copy of $like under another name."
	else
		warn "$f is not copied: the game reads a pack only under its own name — rename it to $like."
	fi
done

say "Installing Shandalar.apk (the game's settings and decks are kept)"
OUT=$(adb install -r Shandalar.apk 2>&1 | tr -d '\r')
printf '%s\n' "$OUT" | sed 's/^/  /'
printf '%s' "$OUT" | grep -q Success || fail "the install did not succeed (see above). If it says the signatures do not match, an older install was signed differently: run quest_fresh_install.sh."

if ! folders_made; then
	say "Starting the game once, so it makes its own folders"
	note "Keep the headset on and awake."
	adb shell monkey -p "$P" -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1
	n=0
	while ! folders_made && [ "$n" -lt 30 ]; do sleep 2; n=$((n + 1)); done
	adb shell am force-stop "$P" > /dev/null 2>&1
	folders_made || fail "the game did not make its folders. Put the headset on, start Shandalar once from Library > Unknown Sources, then run this again."
fi
ok "the game's folders are there"
# A folder made from the shell before these scripts existed: open it up.
dev "chmod 775 '$F/skin' '$F/cardpacks' '$F/portraits' '$F/music'" > /dev/null

# A copy that did not complete: take away what it left on the headset (the
# half-made .part and the Download copy — the zip already in place is
# never touched), then stop with the reason.
stop_copy() {
	dev "rm -f '$dest/$name.part'; rm -rf '$T'" > /dev/null
	fail "$1"
}

COPIED=0
KEPT=0
if [ ${#FILES[@]} -eq 0 ]; then
	warn "no skin and no card packs in this folder: only the game was installed"
else
	say "Copying the skin, the card art and the card packs (${#FILES[@]} files)"
	dev "rm -rf '$T'; mkdir -p '$T'" > /dev/null
	i=0
	for f in "${FILES[@]}"; do
		i=$((i + 1))
		name=$(basename "$f")
		case "$f" in skin/*) dest=$F/skin ;; *) dest=$F/cardpacks ;; esac
		want=$(size_here "$f")
		printf '\n  [%d/%d] %s, %d MB\n' "$i" "${#FILES[@]}" "$name" $((want / 1048576))
		if [ "$(size_there "$dest/$name")" = "$want" ] && [ "$(sha_there "$dest/$name")" = "$(sha_here "$f")" ]; then
			ok "$name is already there, the same file"
			KEPT=$((KEPT + 1))
			continue
		fi
		dev "rm -f '$dest/$name.part'" > /dev/null    # left by an interrupted run
		room=$(free_kb)
		need=$(( (2 * want + 1023) / 1024 + SPARE_KB ))
		if [ -z "$room" ]; then
			warn "the headset's free space could not be read; copying anyway"
		elif [ "$room" -lt "$need" ]; then
			stop_copy "the headset is out of space: $name needs about $(mb_up "$need") MB free (twice its size while it is copied, and 100 MB to spare) and the headset has $(mb_down "$room") MB. Free some space on it, then run this again; the files already in place are kept."
		fi
		PUSHED=$(adb push "$f" "$T/$name" 2>&1 | tr -d '\r')
		printf '%s\n' "$PUSHED" | tail -1 | sed 's/^/        /'
		got=$(size_there "$T/$name")
		if [ "$got" != "$want" ]; then
			case "$PUSHED" in
				*"No space"*) stop_copy "the headset is out of space: $name could not reach its Download folder. Free some space on it, then run this again; the files already in place are kept." ;;
				*) stop_copy "$name reached the Download folder with ${got:-no} bytes of $want. Nothing was replaced; run this again." ;;
			esac
		fi
		COPY=$(dev "cp '$T/$name' '$dest/$name.part' 2>&1")
		got=$(size_there "$dest/$name.part")
		if [ "$got" != "$want" ]; then
			case "$COPY" in
				*"No space"*) stop_copy "the headset is out of space: $name did not fit in $dest (${got:-no} bytes of $want). The $name already there is untouched. Free some space on the headset, then run this again." ;;
				*) stop_copy "$name did not arrive in $dest (${got:-no} bytes of $want${COPY:+: $COPY}). The $name already there is untouched; run this again." ;;
			esac
		fi
		dev "mv -f '$dest/$name.part' '$dest/$name'" > /dev/null
		got=$(size_there "$dest/$name")
		[ "$got" = "$want" ] || stop_copy "$name could not be put in place in $dest (${got:-no} bytes of $want); run this again."
		dev "rm -f '$T/$name'" > /dev/null
		ok "$name is in place"
		COPIED=$((COPIED + 1))
	done
	dev "rm -rf '$T'" > /dev/null
fi

say "Done"
ok "$COPIED copied, $KEPT already there"
note "Start Shandalar from Library > Unknown Sources."
if [ "$COPIED" -gt 0 ]; then
	note "The first start after a pack is added or changed checks its card pictures"
	note "once: a screen says which pack and how far. Later starts skip it."
fi
note "What the game saw at its start:  adb pull $F/start_report.txt"
printf '\n'
