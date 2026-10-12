#!/usr/bin/env bash
# Shandalar on a Meta Quest — a clean install from scratch, one step at a time.
# For an update that keeps the game's settings and decks, run
# push_to_quest.sh instead.
#
# Run it from the unpacked Shandalar-<version>-meta-quest folder (Shandalar.apk,
# skin/ and cardpacks/ beside it), with the headset on USB and `adb devices`
# listing it:
#
#     ./quest_fresh_install.sh
#
# It stops before every step and says what comes next:
#   1. removes the installed game and everything it kept on the headset
#   2. installs Shandalar.apk
#   3. has you start the game once in the headset, so it makes its own folders
#   4. copies the skin, the card art and the card packs into them, one file at
#      a time, through the Download folder — a direct `adb push` into the
#      game's folder is refused on current headset software ("remote fchown
#      failed: Operation not permitted") — and checks every file's size; a
#      file is copied to <name>.part and moved into place only whole
#   5. records the game's log while you start it again, and fetches the
#      game's own start report
#
# Written on 2026-10-11 for the owner's Quest 3, where it was the route that
# worked; docs/handhelds.md, "Meta Quest 3".
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
STAMP=$(date +%Y%m%d-%H%M%S)
LOG="quest-$STAMP.log"
REPORT="start_report-$STAMP.txt"
LOGPID=""

cd -- "$(dirname -- "$0")" || exit 1

say()   { printf '\n\033[1m%s\033[0m\n' "$*"; sleep 1; }
note()  { printf '  %s\n' "$*"; }
ok()    { printf '  \033[32mok\033[0m   %s\n' "$*"; }
warn()  { printf '  \033[33m!!\033[0m   %s\n' "$*"; }
fail()  { printf '\n  \033[31mSTOPPED:\033[0m %s\n\n' "$*"; exit 1; }
pause() { printf '\n'; read -r -p "  ${1:-Press Enter to go on (Ctrl+C stops here)} " _; }
ask()   { local a; read -r -p "  $1 [y/n] " a; [ "${a:-}" = y ] || [ "${a:-}" = Y ]; }
# A command on the headset, its output without Android's carriage returns.
# Every path in one is in single quotes: the headset's shell splits the line.
dev()   { adb shell "$1" 2>/dev/null | tr -d '\r'; }
size_here()  { wc -c < "$1" | tr -d ' '; }
size_there() { dev "stat -c %s '$1' 2>/dev/null"; }
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
# A copy that did not complete: take away what it left on the headset (the
# half-made .part and the Download copy), then stop with the reason.
stop_copy() {
	dev "rm -f '$dest/$name.part'; rm -rf '$T'" > /dev/null
	fail "$1"
}
stop_log() {
	if [ -n "$LOGPID" ]; then kill "$LOGPID" 2>/dev/null; wait "$LOGPID" 2>/dev/null; LOGPID=""; fi
}
trap stop_log EXIT

# ------------------------------------------------------------------ checks --
VERSION=$(cat VERSION.txt 2>/dev/null | head -1)
say "Shandalar ${VERSION:-} — clean install on the Meta Quest"
note "from $PWD"
command -v adb > /dev/null || fail "adb is not installed (Debian/Ubuntu: sudo apt install adb)."
[ -f Shandalar.apk ] || fail "Shandalar.apk is not in this folder. Run the script from the unpacked Shandalar-…-meta-quest folder."

FILES=()
for f in skin/original_skin.zip skin/cardart.zip; do
	[ -f "$f" ] && FILES+=("$f")
done
for name in "${PACKS[@]}"; do
	[ -f "cardpacks/$name" ] && FILES+=("cardpacks/$name")
done
TOTAL=0
LARGEST=0
# ${FILES[@]+…}: an empty array is "unbound" to macOS's bash 3.2 under set -u.
for f in ${FILES[@]+"${FILES[@]}"}; do
	s=$(size_here "$f"); TOTAL=$((TOTAL + s)); [ "$s" -gt "$LARGEST" ] && LARGEST=$s
done

DEVICES=$(adb devices 2>/dev/null | tr -d '\r' | awk 'NR > 1 && $2 == "device" { print $1 }')
COUNT=$(printf '%s\n' "$DEVICES" | grep -c . || true)
[ "$COUNT" -eq 1 ] || fail "'adb devices' lists $COUNT ready headsets, not one. Plug the headset in, put it on and allow USB debugging, then run this again."
# Every adb call below goes to this headset, whatever else is plugged in:
# adb counts an unauthorized phone or an offline emulator too, and without
# a serial every command would fail "more than one device/emulator".
export ANDROID_SERIAL="$DEVICES"
[ "$(dev 'echo here')" = here ] || fail "the headset $DEVICES does not answer adb. Unplug it, plug it in again and put it on, then run this again."
ok "headset $DEVICES"
APK_KB=$(( ($(size_here Shandalar.apk) + 1023) / 1024 ))
ok "Shandalar.apk ($(( $(size_here Shandalar.apk) / 1048576 )) MB)"
if [ ${#FILES[@]} -eq 0 ]; then
	warn "no skin and no card packs here: the game is installed bare"
else
	for f in "${FILES[@]}"; do ok "$(printf '%-40s %5d MB' "$f" $(( $(size_here "$f") / 1048576 )))"; done
fi
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
# The room this needs: the APK, every zip, the largest twice (its Download
# copy and its copy in place at once) and 100 MB to spare. Step 1 frees
# what the old install kept, so that counts as room.
FREE_KB=$(free_kb)
OLD_KB=$(dev "du -sk '/sdcard/Android/data/$P' 2>/dev/null" | awk '$1 ~ /^[0-9]+$/ { print $1 }')
NEED_KB=$(( (TOTAL + LARGEST + 1023) / 1024 + APK_KB + SPARE_KB ))
if [ -n "$FREE_KB" ]; then
	ROOM_KB=$(( FREE_KB + ${OLD_KB:-0} ))
	if [ "${OLD_KB:-0}" -gt 0 ]; then
		HAS="has $(mb_down "$FREE_KB") MB free, $(mb_down "$ROOM_KB") MB once step 1 has removed the old install"
	else
		HAS="has $(mb_down "$FREE_KB") MB free"
	fi
	[ "$ROOM_KB" -ge "$NEED_KB" ] || fail "the headset $HAS; this needs about $(mb_up "$NEED_KB") MB. Free some space on it, then run this again; nothing was deleted."
	ok "the headset $HAS (about $(mb_up "$NEED_KB") MB needed)"
else
	warn "the headset's free space could not be read"
fi

# ------------------------------------------------------------------ step 1 --
say "Step 1 of 5 — remove the game and everything it kept"
note "This uninstalls Shandalar and deletes what it kept on the headset:"
note "its settings, any decks built on the Quest, the skin, the card art and the packs."
printf '\n'
read -r -p "  Type yes to delete them: " answer
[ "${answer:-}" = yes ] || fail "nothing was deleted."
adb shell am force-stop "$P" > /dev/null 2>&1
# Android answers an uninstall with Success or a Failure (not installed);
# anything else is adb itself failing to reach the headset — an error, not
# "it was not installed".
OUT=$(adb uninstall "$P" 2>&1 | tr -d '\r')
case "$OUT" in
	*Success*) ok "uninstalled" ;;
	*Failure*) note "it was not installed" ;;
	*) fail "the headset did not answer the uninstall (${OUT:-no answer}). Unplug it, plug it in again and put it on, then run this again." ;;
esac
dev "rm -rf '/sdcard/Android/data/$P' '$T'" > /dev/null
sleep 2
case "$(dev "[ -e '/sdcard/Android/data/$P' ] && echo there || echo gone")" in
	gone) ok "its folders are gone" ;;
	there) warn "/sdcard/Android/data/$P is still there; the reinstall reuses it" ;;
	*) fail "the headset stopped answering while its folders were deleted. Unplug it, plug it in again and put it on, then run this again." ;;
esac

# ------------------------------------------------------------------ step 2 --
say "Step 2 of 5 — install Shandalar.apk"
pause
OUT=$(adb install Shandalar.apk 2>&1 | tr -d '\r')
printf '%s\n' "$OUT" | sed 's/^/  /'
printf '%s' "$OUT" | grep -q Success || fail "the install did not succeed (see above)."
ok "installed"

# ------------------------------------------------------------------ step 3 --
say "Step 3 of 5 — start the game once, with nothing added"
note "Put the headset on: Library > Unknown Sources > Shandalar."
note "With nothing to read yet it should reach the title screen within a minute."
note "This first start also makes the game's own folders, which the files go into."
note "Then quit the game and come back here."
pause "Press Enter once you have seen the title screen (or waited a minute)…"
n=0
while ! folders_made && [ "$n" -lt 10 ]; do sleep 2; n=$((n + 1)); done
if ! folders_made; then
	warn "its folders are not there yet — starting the game from here (keep the headset on)"
	adb shell monkey -p "$P" -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1
	n=0
	while ! folders_made && [ "$n" -lt 30 ]; do sleep 2; n=$((n + 1)); done
fi
folders_made || fail "the game did not make its folders. Start it once in the headset, then run this script again (step 1 will ask again before deleting)."
ok "the game made its folders"
printf '\n'
BARE=y
ask "Did the bare game show its title screen?" || BARE=n
adb shell am force-stop "$P" > /dev/null 2>&1
SKIP=n
if [ "$BARE" = n ]; then
	warn "a black screen before any files were added is the game itself, not the files"
	ask "Skip copying the files and go straight to recording the log?" && SKIP=y
fi

# ------------------------------------------------------------------ step 4 --
COPIED=0
if [ "$SKIP" = y ] || [ ${#FILES[@]} -eq 0 ]; then
	say "Step 4 of 5 — copying skipped"
else
	say "Step 4 of 5 — copy the skin, the card art and the card packs (${#FILES[@]} files, $((TOTAL / 1048576)) MB)"
	note "Each file goes to the headset's Download folder first, then the headset"
	note "copies it into the game's folder and the Download copy is deleted."
	note "Every file's size is checked at both stops. This takes a few minutes."
	pause
	dev "rm -rf '$T'; mkdir -p '$T'" > /dev/null
	i=0
	for f in "${FILES[@]}"; do
		i=$((i + 1))
		name=$(basename "$f")
		case "$f" in skin/*) dest=$F/skin ;; *) dest=$F/cardpacks ;; esac
		want=$(size_here "$f")
		printf '\n  [%d/%d] %s, %d MB\n' "$i" "${#FILES[@]}" "$name" $((want / 1048576))
		room=$(free_kb)
		need=$(( (2 * want + 1023) / 1024 + SPARE_KB ))
		if [ -n "$room" ] && [ "$room" -lt "$need" ]; then
			stop_copy "the headset is out of space: $name needs about $(mb_up "$need") MB free (twice its size while it is copied, and 100 MB to spare) and the headset has $(mb_down "$room") MB. Free some space on it, then run this script again."
		fi
		PUSHED=$(adb push "$f" "$T/$name" 2>&1 | tr -d '\r')
		printf '%s\n' "$PUSHED" | tail -1 | sed 's/^/        /'
		got=$(size_there "$T/$name")
		if [ "$got" != "$want" ]; then
			case "$PUSHED" in
				*"No space"*) stop_copy "the headset is out of space: $name could not reach its Download folder. Free some space on it, then run this script again." ;;
				*) stop_copy "$name reached the Download folder with ${got:-no} bytes of $want." ;;
			esac
		fi
		COPY=$(dev "cp '$T/$name' '$dest/$name.part' 2>&1")
		got=$(size_there "$dest/$name.part")
		if [ "$got" != "$want" ]; then
			case "$COPY" in
				*"No space"*) stop_copy "the headset is out of space: $name did not fit in $dest (${got:-no} bytes of $want). Free some space on it, then run this script again." ;;
				*) stop_copy "$name did not arrive in $dest (${got:-no} bytes of $want${COPY:+: $COPY})." ;;
			esac
		fi
		dev "mv -f '$dest/$name.part' '$dest/$name'" > /dev/null
		got=$(size_there "$dest/$name")
		[ "$got" = "$want" ] || stop_copy "$name could not be put in place in $dest (${got:-no} bytes of $want)."
		dev "rm -f '$T/$name'" > /dev/null
		ok "$name is in place"
		COPIED=$((COPIED + 1))
		sleep 1
	done
	dev "rm -rf '$T'" > /dev/null
	printf '\n'
	note "On the headset now:"
	dev "ls -l '$F/skin' '$F/cardpacks'" | sed 's/^/    /'
fi

# ------------------------------------------------------------------ step 5 --
say "Step 5 of 5 — start it and record what it does"
note "The game's log is written to $LOG here while you start it."
if [ "$COPIED" -gt 0 ]; then
	note "The first start with card packs checks every card picture once: a screen says"
	note "which pack and how far. It takes minutes on the headset, once; let it finish."
fi
pause "Press Enter, then start Shandalar in the headset…"
adb logcat -c > /dev/null 2>&1
adb logcat -v time -s godot Godot > "$LOG" 2>&1 &
LOGPID=$!
ok "recording"
pause "Press Enter when the title screen is up (or if nothing moves for five minutes)…"
printf '\n'
RESULT=y
ask "Did it reach the title screen?" || RESULT=n
sleep 2
stop_log
ok "log: $LOG ($(grep -c . "$LOG" 2>/dev/null || echo 0) lines)"
if adb pull "$F/start_report.txt" "$REPORT" > /dev/null 2>&1; then
	ok "the game's start report: $REPORT"
	note "its last lines:"
	tail -n 12 "$REPORT" | sed 's/^/    /'
else
	warn "no start report on the headset"
fi

# ----------------------------------------------------------------- summary --
say "Done"
if [ "$RESULT" = y ]; then
	ok "Shandalar ${VERSION:-} is installed with $COPIED files of skin, card art and packs."
	note "Its folders on the headset: $F"
else
	warn "it did not reach the title screen. Keep these two files for the report:"
	note "  $PWD/$LOG"
	note "  $PWD/$REPORT"
fi
printf '\n'
