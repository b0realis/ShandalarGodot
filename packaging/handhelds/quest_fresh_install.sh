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
#      failed: Operation not permitted") — and checks every file's size
#   5. records the game's log while you start it again, and fetches the
#      game's own start report
#
# Written on 2026-10-11 for the owner's Quest 3, where it was the route that
# worked; docs/handhelds.md, "Meta Quest 3".
set -u

P=com.b0realis.shandalar
F=/sdcard/Android/data/$P/files
T=/sdcard/Download/shandalar-push
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
dev()   { adb shell "$1" 2>/dev/null | tr -d '\r'; }
size_here()  { wc -c < "$1" | tr -d ' '; }
size_there() { dev "stat -c %s $1 2>/dev/null"; }
folders_made() { [ "$(dev "[ -d $F/skin ] && [ -d $F/cardpacks ] && echo yes")" = yes ]; }
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
for f in skin/original_skin.zip skin/cardart.zip cardpacks/Pack-*.zip; do
	[ -f "$f" ] && FILES+=("$f")
done
TOTAL=0
LARGEST=0
for f in "${FILES[@]}"; do
	s=$(size_here "$f"); TOTAL=$((TOTAL + s)); [ "$s" -gt "$LARGEST" ] && LARGEST=$s
done

DEVICES=$(adb devices 2>/dev/null | tr -d '\r' | awk 'NR > 1 && $2 == "device" { print $1 }')
COUNT=$(printf '%s\n' "$DEVICES" | grep -c . || true)
[ "$COUNT" -eq 1 ] || fail "'adb devices' lists $COUNT ready headsets, not one. Plug the headset in, put it on and allow USB debugging, then run this again."
ok "headset $DEVICES"
ok "Shandalar.apk ($(( $(size_here Shandalar.apk) / 1048576 )) MB)"
if [ ${#FILES[@]} -eq 0 ]; then
	warn "no skin and no card packs here: the game is installed bare"
else
	for f in "${FILES[@]}"; do ok "$(printf '%-40s %5d MB' "$f" $(( $(size_here "$f") / 1048576 )))"; done
fi
FREE_KB=$(dev "df -k /sdcard | tail -1" | awk '{ print $4 }')
NEED_KB=$(( (TOTAL + LARGEST) / 1024 + 102400 ))
if [ -n "$FREE_KB" ] && [ "$FREE_KB" -gt 0 ] 2>/dev/null; then
	[ "$FREE_KB" -ge "$NEED_KB" ] || fail "the headset has $((FREE_KB / 1024)) MB free; this needs about $((NEED_KB / 1024)) MB."
	ok "$((FREE_KB / 1024)) MB free on the headset (about $((NEED_KB / 1024)) MB needed)"
fi

# ------------------------------------------------------------------ step 1 --
say "Step 1 of 5 — remove the game and everything it kept"
note "This uninstalls Shandalar and deletes what it kept on the headset:"
note "its settings, any decks built on the Quest, the skin, the card art and the packs."
printf '\n'
read -r -p "  Type yes to delete them: " answer
[ "${answer:-}" = yes ] || fail "nothing was deleted."
adb shell am force-stop "$P" > /dev/null 2>&1
if adb uninstall "$P" 2>&1 | tr -d '\r' | grep -q Success; then ok "uninstalled"; else note "it was not installed"; fi
dev "rm -rf /sdcard/Android/data/$P $T" > /dev/null
sleep 2
if [ -z "$(dev "ls -d /sdcard/Android/data/$P 2>/dev/null")" ]; then
	ok "its folders are gone"
else
	warn "/sdcard/Android/data/$P is still there; the reinstall reuses it"
fi

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
	dev "mkdir -p $T" > /dev/null
	i=0
	for f in "${FILES[@]}"; do
		i=$((i + 1))
		name=$(basename "$f")
		case "$f" in skin/*) dest=$F/skin ;; *) dest=$F/cardpacks ;; esac
		want=$(size_here "$f")
		printf '\n  [%d/%d] %s, %d MB\n' "$i" "${#FILES[@]}" "$name" $((want / 1048576))
		adb push "$f" "$T/$name" 2>&1 | tr -d '\r' | tail -1 | sed 's/^/        /'
		got=$(size_there "$T/$name")
		[ "$got" = "$want" ] || fail "$name reached the Download folder with ${got:-no} bytes of $want."
		dev "cp $T/$name $dest/$name; rm -f $T/$name" > /dev/null
		got=$(size_there "$dest/$name")
		[ "$got" = "$want" ] || fail "$name did not arrive in $dest (${got:-no} bytes of $want)."
		ok "$name is in place"
		COPIED=$((COPIED + 1))
		sleep 1
	done
	dev "rm -rf $T" > /dev/null
	printf '\n'
	note "On the headset now:"
	dev "ls -l $F/skin $F/cardpacks" | sed 's/^/    /'
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
