#!/usr/bin/env bash
# THE LAN SMOKE — TWO Godot processes on this one computer, one whole
# SGManalink duel between them over the ENCRYPTED LAN PATH, and a
# FAILURE on anything either of them prints. The players are
# tools/lan_smoke.gd; read its header for what the two roles do.
#
# Usage:
#   ./tools/lan_smoke.sh                       # discovery + invitation + a duel
#   ./tools/lan_smoke.sh --seed 4250           # replay one referee seed
#   ./tools/lan_smoke.sh --address 192.168.1.5 # pick the adapter by hand
#   ./tools/lan_smoke.sh --no-discovery        # invitation only, no UDP
#   ./tools/lan_smoke.sh --help
#   ./tools/lan_smoke.sh --version             # the one version string
#
# WHAT IT PROVES that the in-process SGManalink suite cannot. Every
# `tests/ui/test_sgmanalink_*.gd` builds its host and its guest in ONE
# process: real sockets and real TLS, but one card registry, one
# `user://` and one frame loop. This runs a SECOND copy of the game with
# its own data home, which has to find the first over UDP broadcast, pin
# its certificate out of a privately handed invitation, take a seat and
# play. It is the rehearsal for two computers that one computer can hold.
#
# THE HOST binds this computer's private IPv4 address — not the
# `127.0.0.1` same-computer fallback — so the duel goes through
# `wss://`, the self-signed certificate and the `sglan1:` invitation.
# The invitation travels through a file in the run directory, which is
# this test's stand-in for the private message a player sends.
#
# TWO DATA HOMES, never the player's. Each process gets its own
# `XDG_DATA_HOME` under the run directory and a distinct project name
# (macOS ignores XDG), so neither can touch the owner's profile. Set
# LAN_SMOKE_DIR to choose the PARENT of a fresh run directory; only that
# owned child is removed. --keep leaves it behind for reading. macOS
# keeps the uniquely named "Shandalar LAN Smoke ..." profiles separately.
#
# EXIT CODES are the two processes' own when either set one: 1 when a
# check failed or a log was not clean, 2 when a run hit its deadline
# with the duel unfinished, 3 for a bad argument, 124 for the whole-run
# guard (SMOKE_TIMEOUT, default 900 s). A run that never printed both
# `LAN host OK` and `LAN guest OK` is a failure whatever it exited.
#
# THE RECIPE IS CONTRIBUTING.md's: `timeout` directly on each Godot,
# output to FILES rather than pipes, stdin closed. Only the two PIDs this
# script started are ever signalled — other agents run their own Godot
# suites on the same machine.
set -uo pipefail
cd "$(dirname "$0")/.."

# THE FAMILY BANNER (tools/banner.sh): stderr, and only on a terminal.
# stdout here is the LAN lines and the verdict, and the greps below read
# the run's own log files, so decoration reaches neither.
. tools/banner.sh
BANNER_ROW_0='┬  ┌─┐┌┐┌  ┌─┐┌┬┐┌─┐┬┌─┌─┐'
BANNER_ROW_1='│  ├─┤│││  └─┐││││ │├┴┐├┤ '
BANNER_ROW_2='┴─┘┴ ┴┘└┘  └─┘┴ ┴└─┘┴ ┴└─┘'
BANNER_CAP_0='Shandalar 1997 · SGManalink'
BANNER_CAP_1='two processes, one encrypted duel'
shandalar_banner_hint "$#" \
	'./tools/lan_smoke.sh                       # discovery + invitation + a duel' \
	'./tools/lan_smoke.sh --seed 4250           # replay one referee seed' \
	'./tools/lan_smoke.sh -h                    # --address, --port, --no-discovery'

usage() {
	sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
	cat <<'EOF'

Options (everything else is rejected):
  --address IPV4   the private address to host on (default: the first one)
  --port N         gameplay TCP port (default 0: a free one, in the invitation)
  --seed N         the referee's RNG seed, so a duel replays
  --host-deck P    res:// deck for the host seat
  --guest-deck P   res:// deck for the guest seat
  --drop-turn N    the turn the guest pulls its cable on (0 never)
  --no-discovery   skip UDP entirely; the invitation alone connects them
  --fps N          frame cap, which is also the network poll rate (120)
  --pace-ms N      floor under the gap between one seat's commands (25)
  --deadline S     per-process guard in seconds (600)
  --verbose        print every command and revision
  --keep           keep the run directory and say where it is

Environment:
  GODOT            the binary to run (default ../tools/godot)
  LAN_SMOKE_DIR    parent folder for a fresh run directory and its logs
  SMOKE_TIMEOUT    whole-run guard in seconds (900)
EOF
}

for arg in "$@"; do
	case "$arg" in
		-V | --version) shandalar_version_line "lan_smoke.sh" .; exit 0 ;;
		-h | --help) usage; shandalar_banner_help; exit 0 ;;
	esac
done
shandalar_banner .

. tools/runtime.sh
shandalar_find_godot || exit $?
shandalar_find_timeout || exit $?
SMOKE_TIMEOUT="${SMOKE_TIMEOUT:-900}"

common=()
host_only=()
guest_only=()
keep=0
while [ $# -gt 0 ]; do
	case "$1" in
		--address | --port | --fps | --deadline | --pace-ms)
			[ $# -ge 2 ] || { echo "lan smoke: $1 needs a value" >&2; exit 3; }
			common+=("$1" "$2"); shift 2 ;;
		--seed)
			[ $# -ge 2 ] || { echo "lan smoke: --seed needs a value" >&2; exit 3; }
			host_only+=(--seed "$2"); shift 2 ;;
		--host-deck)
			[ $# -ge 2 ] || { echo "lan smoke: --host-deck needs a value" >&2; exit 3; }
			host_only+=(--deck "$2"); shift 2 ;;
		--guest-deck)
			[ $# -ge 2 ] || { echo "lan smoke: --guest-deck needs a value" >&2; exit 3; }
			guest_only+=(--deck "$2"); shift 2 ;;
		--drop-turn)
			[ $# -ge 2 ] || { echo "lan smoke: --drop-turn needs a value" >&2; exit 3; }
			guest_only+=(--drop-turn "$2"); shift 2 ;;
		--no-discovery | --verbose) common+=("$1"); shift ;;
		--keep) keep=1; shift ;;
		*) echo "lan smoke: unknown argument $1" >&2; usage >&2; exit 3 ;;
	esac
done

run_parent="${LAN_SMOKE_DIR:-${TMPDIR:-/tmp}}"
mkdir -p "$run_parent" || exit 3
dir="$(mktemp -d "$run_parent/shandalar-lan-smoke.XXXXXX")" || exit 3
# Make all mirror paths and the invitation absolute, even with a relative parent.
dir="$(cd "$dir" && pwd -P)" || exit 3
mkdir -p "$dir/host" "$dir/guest" || exit 3

# EVERY BACKGROUND JOB HERE IS A `timeout` (2026-10-03). Each process
# is started in a subshell that `exec`s timeout, so the job IS timeout —
# which passes a TERM on to its Godot and, five seconds later, a KILL.
# Before, `$!` was the subshell: the kill in cleanup ended a shell, while
# timeout (in a process group of its own, out of a Ctrl-C's reach) and
# its Godot played on for up to SMOKE_TIMEOUT in a run directory this
# script had just deleted. Now an INT or a TERM is trapped, this
# script's own running jobs (`jobs -pr`: never a pid already reaped,
# never anyone else's) are signalled AND WAITED FOR, and only then is
# the directory removed. Every process runs in the background and is
# `wait`ed for, even the import that runs alone: bash runs a trap only
# once a foreground command has finished, but `wait` returns to it at
# once.
stop_processes() {
	local running
	running="$(jobs -pr)"
	[ -z "$running" ] || kill -TERM $running 2>/dev/null
	wait
}
cleanup() {
	stop_processes
	[ "$keep" = 1 ] || rm -rf "$dir"
}
trap cleanup EXIT
trap 'stop_processes; exit 130' INT
trap 'stop_processes; exit 143' TERM

# Warm the import cache with ONE process first: two cold Godots writing
# the same .godot folder at once is a race nobody needs to debug.
(
	shandalar_test_profile || exit $?
	exec "$SHANDALAR_TIMEOUT" -k 5 900 "$GODOT" --headless --import .
) > "$dir/import.log" 2>&1 </dev/null &
wait $!; import_status=$?
if [ "$import_status" -ne 0 ]; then
	echo "LAN SMOKE IS NOT CLEAN: import failed" >&2
	cat "$dir/import.log" >&2
	exit 1
fi

# Share only the warmed resource cache, not project settings. Each role
# gets its own override before autoloads start; no tracked file changes.
for role in host guest; do
	project="$dir/$role/project"
	mkdir -p "$project" || exit 3
	for source in "$PWD"/* "$PWD"/.[!.]* "$PWD"/..?*; do
		[ -e "$source" ] || [ -L "$source" ] || continue
		case "${source##*/}" in .git | override.cfg) continue ;; esac
		ln -s "$source" "$project/${source##*/}" || exit 3
	done
	printf '[application]\nconfig/name="Shandalar LAN Smoke %s %s"\n' \
		"${dir##*/}" "$role" > "$project/override.cfg"
done

run_role() {  # always started with `&`: it execs, so $! is the timeout
	local role="$1"; shift
	export GODOT_EDITOR_CUSTOM_FEATURES= XDG_DATA_HOME="$dir/$role"
	exec "$SHANDALAR_TIMEOUT" -k 5 "$SMOKE_TIMEOUT" \
		"$GODOT" --headless --path "$dir/$role/project" --log-file "$dir/$role/engine.log" \
		res://tools/lan_smoke.tscn -- --role "$role" --invite "$dir/invite.txt" \
		"$@" > "$dir/$role.log" 2>&1 </dev/null
}

run_role host ${common+"${common[@]}"} ${host_only+"${host_only[@]}"} &
host_pid=$!
run_role guest ${common+"${common[@]}"} ${guest_only+"${guest_only[@]}"} &
guest_pid=$!
wait "$host_pid"; host_status=$?
wait "$guest_pid"; guest_status=$?

for role in host guest; do
	echo "----- $role -----"
	grep -E '^LAN ' "$dir/$role.log" || echo "(no LAN lines: the process never started)"
done

# Godot's headless boot prints nothing of its own on a clean run; every
# ERROR or WARNING line here belongs to this smoke.
noise='wd\.xic|V-Sync'
offending=""
for role in host guest; do
	found="$(grep -nE 'ERROR|WARNING|SCRIPT ERROR|LAN FAIL' "$dir/$role.log" | grep -vE "$noise" | head -20 || true)"
	[ -n "$found" ] && offending="$offending
$role:
$found"
done

echo
[ "$keep" = 1 ] && echo "Run directory kept: $dir"
if [ "$host_status" -ne 0 ] || [ "$guest_status" -ne 0 ]; then
	echo "LAN SMOKE IS NOT CLEAN: host exited $host_status, guest exited $guest_status" >&2
	echo "(1 = a check failed, 2 = the deadline passed, 3 = bad argument, 124 = the whole-run guard)" >&2
	[ -n "$offending" ] && echo "$offending" >&2
	exit $(( host_status != 0 ? host_status : guest_status ))
fi
if [ -n "$offending" ]; then
	echo "LAN SMOKE IS NOT CLEAN — the run printed:" >&2
	echo "$offending" >&2
	exit 1
fi
if ! grep -q '^LAN host OK' "$dir/host.log" || ! grep -q '^LAN guest OK' "$dir/guest.log"; then
	echo "LAN SMOKE IS NOT CLEAN: one of the two never reached its verdict line." >&2
	exit 1
fi
echo "LAN SMOKE IS CLEAN: one encrypted LAN duel between two processes."
exit 0
