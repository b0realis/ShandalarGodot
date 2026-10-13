#!/usr/bin/env bash
# THE DUEL SOAK — whole duels played through the LIVE duel screen under
# Xvfb on Linux or native windows on macOS, and a FAILURE on anything
# Godot prints while they play. The
# player is tools/duel_soak.gd; read its header for what the two modes do.
#
# Usage:
#   ./duel_soak.sh                          # 3 seeds, demo AND human seat
#   ./duel_soak.sh --mode human --count 10  # fuzz the human seat harder
#   ./duel_soak.sh --seeds 4242             # replay one seed (both modes)
#   ./duel_soak.sh --rules fifth            # every fork the 1997 way
#   ./duel_soak.sh --help
#   ./duel_soak.sh --version                # the one version string
#
# Exit 0 only when every duel reached game over AND the log holds no
# ERROR, WARNING or SCRIPT ERROR line beyond Xvfb's own two (the X input
# method and the V-Sync line, which every headless X server prints).
# A duel that stands still for --stall seconds (240) is a failure too —
# a stuck prompt is exactly what this exists to catch.
#
# EXIT CODES are the .gd's own when it set one: 2 for a STALL (a duel
# that stood still, or never started), 3 for a bad argument (and from this
# script for a missing Godot, timeout or xvfb), 124 for the whole-run
# guard (137 when Godot had to be killed after it), 130/143 for a Ctrl-C
# or a TERM — and 1 when Godot exited 0 but printed an error or a
# warning, or never reached `SOAK done`. Godot's status is read FIRST,
# because a STALL line is also an "ERROR/WARNING/STALL" line and reading
# the grep first turned every exit 2 into an exit 1.
#
# THE RECIPE IS CONTRIBUTING.md's, and every part of it is load-bearing:
# `timeout` INSIDE xvfb-run so it signals Godot itself; output to a FILE,
# never a pipe (`--help` included — it used to pipe a headless Godot into
# grep); stdin closed. Ten duels take about three minutes; the whole-run
# guard is SOAK_TIMEOUT seconds (default 1800).
set -uo pipefail
cd "$(dirname "$0")"

# THE FAMILY BANNER (tools/banner.sh): stderr, and only on a terminal.
# stdout here is the SOAK lines and the "not clean" report, and this
# script's own grep reads the run's log — decoration may reach neither.
. tools/banner.sh
BANNER_ROW_0='┌┬┐┬ ┬┌─┐┬    ┌─┐┌─┐┌─┐┬┌─'
BANNER_ROW_1=' │││ │├┤ │    └─┐│ │├─┤├┴┐'
BANNER_ROW_2='─┴┘└─┘└─┘┴─┘  └─┘└─┘┴ ┴┴ ┴'
BANNER_CAP_0='Shandalar 1997 · live duels'
BANNER_CAP_1='whole games through the live screen'
# THE MINI-HELP, for a bare `./duel_soak.sh` and no other: the two
# invocations from the Usage block at the top of this file, so there is
# nothing here to keep in step by hand, and the flag that has the rest. A
# bare run is three seeds in both modes and takes minutes — worth saying
# before it starts.
shandalar_banner_hint "$#" \
	'./duel_soak.sh                          # 3 seeds, demo AND human seat' \
	'./duel_soak.sh --mode human --count 10  # fuzz the human seat harder' \
	'./duel_soak.sh -h                       # --rules, --seeds, --stall'

for arg in "$@"; do
	case "$arg" in
		-V | --version) shandalar_version_line "duel_soak.sh" .; exit 0 ;;
	esac
done
shandalar_banner .

. tools/runtime.sh
shandalar_find_godot || exit $?
shandalar_find_timeout || exit $?

# THE SOAK DOES NOT WRITE THE PLAYER'S PROFILE — the same isolation
# `run_tests.sh` carries, and for the same reason: `user://` is the
# EXPORTED game's own directory, and the soak fuzzes the live options
# panel inside it. It already put `settings.cfg` back byte for byte
# afterwards (`tools/duel_soak.gd`, `restore_settings`), which covers a
# run that finishes and not one that is killed. This covers both.
#
# Side effect worth knowing: with no player file to read, a soak with no
# `--rules` argument plays under the BUILT-IN rules defaults rather than
# under whatever the player last chose — which is what a soak wanted
# anyway. Override with SHANDALAR_TEST_DATA_HOME.
shandalar_test_profile || exit $?

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

for arg in "$@"; do
	if [ "$arg" = "--help" ] || [ "$arg" = "-h" ]; then
		"$SHANDALAR_TIMEOUT" -k 5 60 "$GODOT" --headless --path . -s res://tools/duel_soak.gd -- --help \
			> "$log" 2>&1 </dev/null
		status=$?
		grep -v '^Godot Engine' "$log"
		[ "$status" -eq 0 ] || exit "$status"
		echo
		shandalar_banner_help
		exit 0
	fi
done

display_runner=("$SHANDALAR_TIMEOUT" -k 5 "${SOAK_TIMEOUT:-1800}")
display_options=(--path .)
# Explicit renderer-free UI soak for locked/headless desktops and CI.
if [ "${SOAK_HEADLESS:-0}" = 1 ]; then
	display_options=(--headless "${display_options[@]}")
elif [ "$(uname -s)" != Darwin ]; then
	command -v xvfb-run >/dev/null 2>&1 || { echo "Install xvfb to run the duel soak." >&2; exit 3; }
	display_runner=(xvfb-run -a "${display_runner[@]}")
fi
# A CTRL-C MUST REACH GODOT (2026-10-13, run_tests.sh's pattern).
# `timeout` puts itself in a process group of its own, so the terminal's
# INT never reached it: the script waited up to SOAK_TIMEOUT and then
# carried on. So the soak runs in the background and an INT or a TERM is
# trapped, passed on and waited for. Under xvfb-run the pid is xvfb-run,
# which passes nothing on, so its own children (`timeout`, which passes
# it to Godot, and Xvfb) get the TERM as well.
"${display_runner[@]}" "$GODOT" "${display_options[@]}" \
	--log-file "$SHANDALAR_TEST_DATA_HOME/soak-engine.log" \
	-s res://tools/duel_soak.gd -- "$@" > "$log" 2>&1 </dev/null &
soak_pid=$!
trap 'pkill -TERM -P "$soak_pid" 2>/dev/null; kill -TERM "$soak_pid" 2>/dev/null; wait; exit 130' INT
trap 'pkill -TERM -P "$soak_pid" 2>/dev/null; kill -TERM "$soak_pid" 2>/dev/null; wait; exit 143' TERM
wait "$soak_pid"
status=$?
trap - INT TERM

grep -E '^SOAK ' "$log" || true

noise='wd\.xic|V-Sync'
offending="$(grep -nE 'ERROR|WARNING|STALL' "$log" | grep -vE "$noise" | head -40 || true)"

if [ "$status" -ne 0 ]; then
	echo
	echo "SOAK IS NOT CLEAN: Godot exited $status (2 = a duel stood still or never started, 3 = bad argument, 124 or 137 = the whole-run timeout)." >&2
	if [ -n "$offending" ]; then
		echo "Godot printed:" >&2
		echo "$offending" >&2
	fi
	exit "$status"
fi
if [ -n "$offending" ]; then
	echo
	echo "SOAK IS NOT CLEAN — Godot printed:"
	echo "$offending"
	exit 1
fi
if ! grep -q '^SOAK done' "$log"; then
	echo "SOAK IS NOT CLEAN: the run never reached its last duel." >&2
	exit 1
fi
exit 0
