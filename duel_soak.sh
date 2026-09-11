#!/usr/bin/env bash
# THE DUEL SOAK — whole duels played through the LIVE duel screen under
# Xvfb, and a FAILURE on anything Godot prints while they play. The
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
# that stood still, or never started), 3 for a bad argument, 124 for the
# whole-run guard — and 1 when Godot exited 0 but printed an error or a
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
BANNER_CAP_1='whole games under Xvfb'
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

GODOT="${GODOT:-../tools/godot}"
if [ ! -x "$GODOT" ]; then GODOT=godot; fi

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
: "${SHANDALAR_TEST_DATA_HOME:=${TMPDIR:-/tmp}/shandalar-test-data}"
mkdir -p "$SHANDALAR_TEST_DATA_HOME"
export XDG_DATA_HOME="$SHANDALAR_TEST_DATA_HOME"

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

for arg in "$@"; do
	if [ "$arg" = "--help" ] || [ "$arg" = "-h" ]; then
		timeout -k 5 60 "$GODOT" --headless --path . -s res://tools/duel_soak.gd -- --help \
			> "$log" 2>&1 </dev/null
		grep -v '^Godot Engine' "$log"
		echo
		shandalar_banner_help
		exit 0
	fi
done

xvfb-run -a timeout -k 5 "${SOAK_TIMEOUT:-1800}" "$GODOT" --path . \
	-s res://tools/duel_soak.gd -- "$@" > "$log" 2>&1 </dev/null
status=$?

grep -E '^SOAK ' "$log" || true

noise='wd\.xic|V-Sync'
offending="$(grep -nE 'ERROR|WARNING|STALL' "$log" | grep -vE "$noise" | head -40 || true)"

if [ "$status" -ne 0 ]; then
	echo
	echo "SOAK IS NOT CLEAN: Godot exited $status (2 = a duel stood still or never started, 3 = bad argument, 124 = the whole-run timeout)." >&2
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
