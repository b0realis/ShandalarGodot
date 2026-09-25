#!/usr/bin/env bash
# Run the full GUT test suite headless.
#
# Uses the project-pinned Godot binary in ../tools/godot (4.7.2), falling
# back to `godot` on PATH. First run imports resources; test output follows.
#
# Usage:
#   ./run_tests.sh                 # whole suite
#   ./run_tests.sh -gunit_test_name=test_bolt_kills_a_bear   # one test
#   ./run_tests.sh -gselect=test_deck_lab.gd                  # one script
#   SUITE_TIMEOUT=600 ./run_tests.sh   # whole-run guard in seconds (1800)
#   SHARDS=4 ./run_tests.sh        # the whole suite over 4 Godot processes
#   SHARDS=4 SHARD=2 ./run_tests.sh   # only the 2nd of those 4 deals (CI)
#   ./run_tests.sh --help          # the block above, and the env vars
#   ./run_tests.sh --version       # the one version string, from project.godot
#
# WHY THIS SCRIPT CHECKS THE LOG ITSELF
# -------------------------------------
# GUT SILENTLY SKIPS a test script it cannot parse, and still prints
# "All tests passed." Verified 2026-08-31: with one deliberately broken
# file in tests/, the summary read 1894/1894 passing, 0 failing, while a
# whole file never ran. Anyone reading the summary — or grepping it, which
# is how this project checks itself — would call that green.
#
# So a parse error, a missing GutTest base, or a script GUT reports as
# skipped is treated as a FAILURE here, whatever the summary says. A test
# that does not run is not a test that passes.
#
# THREE MORE THINGS GUT CALLS GREEN AND THIS SCRIPT DOES NOT (2026-09-02):
#  * An error OUTSIDE a test body — in before_each/after_each/before_all,
#    in the queue_free teardown frame, in a deferred callback — is filed
#    by GUT's error tracker under NO_TEST (addons/gut/gut.gd `_run_test`,
#    error_tracker.gd `end_test`), and nothing ever reads that bucket. So
#    every `SCRIPT ERROR:` / `ERROR:` / `USER ERROR:` line Godot printed is
#    a failure here. A green run prints none (measured on seven full runs
#    of 2026-09-02 before this gate went in).
#  * A RISKY test (no asserts) or a SKIPPED script only yellows GUT's
#    summary; GutRunner exits 0 unless `get_fail_count() > 0`. That is the
#    incident in CONTRIBUTING.md ("Scratch files") — four assert-less benchmark
#    functions read as a quirk of the suite for a day.
#  * GUT's own `Errors N` total (its internal errors) is likewise unread.
#
# AND THE RUN CANNOT HANG: `timeout` sits directly on Godot (no wrapper
# between them — CONTRIBUTING.md "Commands that can hang"), stdin is closed, and
# a kill makes `tee` see EOF. A test awaiting a signal that never fires
# used to wedge this script forever.
#
# THE SUITE IN SHARDS (2026-09-17): SHARDS=N deals every script over N
# Godot processes that run at once, each in its own user:// under the
# test profile, each gated exactly as the one run is, and the sum held to
# the count of scripts on disk. Balanced by the JUnit files the last run
# left behind (tools/deal_tests.py): 979 s in one process, ~210 s over
# six. SHARD=i runs one deal — one CI job each (.github/workflows/gate.yml).
#
# THE SKIN (same day): the scripts that pin the 1997 look need the skin
# tools/import_original.py copies into assets/original, which no clone
# and no runner has. Each says so on its first doc line, and where the
# folder is absent they are left out by name and counted as such — see
# the block that finds them.
set -euo pipefail
cd "$(dirname "$0")"

# THE FAMILY BANNER, AND -h / -V (tools/banner.sh). The wordmark says
# TESTS; the banner itself goes to stderr and only to a terminal, so
# `./run_tests.sh > log 2>&1` and the gate that greps that log never see
# it. Everything else on the command line is GUT's, untouched — GUT's own
# flags all begin with `-g`, so these four can never collide with one.
. tools/banner.sh
BANNER_ROW_0='┌┬┐┌─┐┌─┐┌┬┐┌─┐'
BANNER_ROW_1=' │ ├┤ └─┐ │ └─┐'
BANNER_ROW_2=' ┴ └─┘└─┘ ┴ └─┘'
BANNER_CAP_0='Shandalar 1997 · GUT suite'
BANNER_CAP_1='headless, the whole gate'
# THE MINI-HELP, for a bare `./run_tests.sh` and no other: three lines
# quoted out of usage() below, so there is nothing here to keep in step
# by hand. Anything on the command line is a -gselect or a
# -gunit_test_name and needs no reminder of itself.
shandalar_banner_hint "$#" \
	'./run_tests.sh                             # the whole suite' \
	'./run_tests.sh -gselect=test_deck_lab.gd   # one script' \
	'./run_tests.sh -h                          # every flag and env var'

usage() {
	cat <<'USAGE'
run_tests.sh — the whole GUT suite, headless, and the gate around it.

  ./run_tests.sh                                   the whole suite
  ./run_tests.sh -gunit_test_name=test_bolt_kills_a_bear    one test
  ./run_tests.sh -gselect=test_deck_lab.gd                  one script
  ./run_tests.sh -h | --help                       this
  ./run_tests.sh -V | --version                    the project's version

Every other argument is passed to GUT unchanged (its own flags all start
with `-g`; `-gh` prints GUT's list of them).

Environment:
  GODOT                     the binary to run (default ../tools/godot,
                            then `godot` on PATH)
  SUITE_TIMEOUT             whole-run guard in seconds (default 1800;
                            per process when sharded)
  SHARDS                    Godot processes the whole suite is dealt over
                            (default: half the cores, 1..6, on Linux; 1 on
                            macOS, where every process would share the one
                            profile). SHARDS=1 is the single run.
  SHARD                     with SHARDS=N: run only the SHARD-th deal
                            (1-based) in this one process — one CI runner
                            per shard. Without it, all N run here at once.
  SHANDALAR_TEST_DATA_HOME  where user:// goes, so a test can never write
                            the player's own profile (default
                            $TMPDIR/shandalar-test-data)

Without the imported 1997 skin (assets/original, tools/import_original.py)
the scripts that pin that look — each says "Needs the imported 1997 skin"
on its first doc line — are left out by name, and the last line says how
many. Everything else runs and is gated as before.

On macOS, user:// is the separate "Shandalar Integration Tests" profile in Library/
Application Support/Godot/app_userdata; SHANDALAR_TEST_DATA_HOME controls
the tool log directory, since Godot ignores XDG_DATA_HOME on macOS.

Exit 0 only when GUT's own tally says every test passed AND Godot exited
0 AND the log holds no parse error, no risky/pending test, no ERROR line
and no leaked-object line. Read the header of this file for why each of
those is checked here rather than trusted to GUT.
USAGE
	echo
	shandalar_banner_help
}

for arg in "$@"; do
	case "$arg" in
		-h | --help) usage; exit 0 ;;
		-V | --version) shandalar_version_line "run_tests.sh" .; exit 0 ;;
	esac
done
shandalar_banner .

. tools/runtime.sh
shandalar_find_godot
shandalar_find_timeout
SUITE_TIMEOUT="${SUITE_TIMEOUT:-1800}"

# THE SUITE DOES NOT WRITE THE PLAYER'S PROFILE
# ---------------------------------------------
# On Linux, `user://` is `$XDG_DATA_HOME/godot/app_userdata/Shandalar` — the SAME
# directory the EXPORTED game uses, because it is the same project name.
# So every suite run in this checkout was reading and rewriting the
# player's real `settings.cfg`, decks and portraits, and the tests that
# remember-and-restore a setting only cover themselves: a run killed
# between the write and the restore leaves what it wrote, and `Settings`
# caches a ConfigFile for the process's life, so ANY later write rewrites
# the whole file from that cache and resurrects rows deleted behind its
# back (or drops rows another process added since).
#
# That is not a theory. On 2026-09-04 the owner's own file was watched
# gaining `phase_stoppers=PackedInt32Array(0, 0, 8, 0)` from
# `tests/ui/test_phase_stops.gd` mid-run, and later losing their chosen
# `Portrait1` and `hand_stack_pos` to another agent's run — and a stored
# `phase_stoppers` row is exactly what kept the three default Stops from
# ever reaching them (docs/ROADMAP.md, "WHY THE THREE DOTS DID NOT REACH
# THE OWNER"). A test suite must not be able to do that.
#
# macOS uses the separate feature-selected profile in tools/runtime.sh.
# One directory, reused so the shader cache and GUT's temp dir stay warm.
# Override with SHANDALAR_TEST_DATA_HOME to put it elsewhere; point it at
# "$HOME/.local/share" to get the old behaviour back, which no test needs
# — the whole suite is green from an empty one (`GameSkin` falls back to
# `res://assets/original` in a dev checkout, which is why).
shandalar_test_profile

# PACK 1 IS A REAL EXTERNAL ZIP, even in tests. Build it with its own
# dedicated standard-library tool and point the process at that exact file;
# this tests discovery/validation without depending on a developer's sibling
# shandalar-packs folder. The Python unit test pins deterministic packaging.
python3 tools/test_pack_1_dotp_complete.py >/dev/null
PACK_ONE_PATH="$SHANDALAR_TEST_DATA_HOME/Pack-1-DotP-complete.zip"
python3 tools/pack_1_dotp_complete.py build "$PACK_ONE_PATH" --metadata-only >/dev/null
export SHANDALAR_PACK_1="$PACK_ONE_PATH"
python3 tools/test_pack_2_fallen_empires.py >/dev/null
PACK_TWO_PATH="$SHANDALAR_TEST_DATA_HOME/Pack-2-Fallen-Empires.zip"
python3 tools/pack_2_fallen_empires.py build "$PACK_TWO_PATH" --metadata-only >/dev/null
export SHANDALAR_PACK_2="$PACK_TWO_PATH"
python3 tools/test_pack_3_ice_age.py >/dev/null
PACK_THREE_PATH="$SHANDALAR_TEST_DATA_HOME/Pack-3-Ice_Age.zip"
python3 tools/pack_3_ice_age.py build "$PACK_THREE_PATH" --metadata-only >/dev/null
export SHANDALAR_PACK_3="$PACK_THREE_PATH"
python3 tools/test_pack_4_homelands.py >/dev/null
PACK_FOUR_PATH="$SHANDALAR_TEST_DATA_HOME/Pack-4-Homelands.zip"
python3 tools/pack_4_homelands.py build "$PACK_FOUR_PATH" --metadata-only >/dev/null
export SHANDALAR_PACK_4="$PACK_FOUR_PATH"
python3 tools/test_pack_5_alliances.py >/dev/null
PACK_FIVE_PATH="$SHANDALAR_TEST_DATA_HOME/Pack-5-Alliances.zip"
python3 tools/pack_5_alliances.py build "$PACK_FIVE_PATH" --metadata-only >/dev/null
export SHANDALAR_PACK_5="$PACK_FIVE_PATH"
python3 tools/test_pack_6_portal.py >/dev/null
PACK_SIX_PATH="$SHANDALAR_TEST_DATA_HOME/Pack-6-Portal.zip"
python3 tools/pack_6_portal.py build "$PACK_SIX_PATH" --metadata-only >/dev/null
export SHANDALAR_PACK_6="$PACK_SIX_PATH"
python3 tools/test_pack_7_fifth_edition.py >/dev/null
PACK_SEVEN_PATH="$SHANDALAR_TEST_DATA_HOME/Pack-7-Fifth-Edition.zip"
python3 tools/pack_7_fifth_edition.py build "$PACK_SEVEN_PATH" --metadata-only >/dev/null
export SHANDALAR_PACK_7="$PACK_SEVEN_PATH"

# Import step (quick no-op when the .godot cache is warm; a cold import
# of the card art is minutes, not hours, so 600 s is generous). ONCE, and
# before any shard: two processes importing the same cache at the same
# time is the one thing below that is not known to be safe.
"$SHANDALAR_TIMEOUT" -k 5 600 "$GODOT" --headless --import . >/dev/null 2>&1 </dev/null || true

# THE SUITE IN SHARDS
# -------------------
# One headless Godot took sixteen to seventeen minutes for the 469
# scripts (511 on 2026-09-25) on a 22-core machine (the gate of 2026-09-17: 959 s of GUT's
# own time), and a gate nobody runs between commits is a gate that
# catches things a day late. Nothing in the suite needs another script's
# process: every test script is a fresh GutTest, every network test binds
# port 0, and user:// is this script's own profile. So the whole suite is
# dealt round-robin over SHARDS processes — the sorted script list, every
# Nth file to one process, which spreads each directory (ai, cards, ui,
# unit) evenly — and each process gets ITS OWN user:// (`shard-N` under
# the test profile: two processes rewriting one settings.cfg is the
# 2026-09-04 incident one step over), its own --log-file, its own
# `reset_test_packs` and its own log. The gate below is then read once
# per shard and once over the sum, and the sum's script count must equal
# the files on disk — a script GUT never saw is a script that did not
# run.
#
# SHARDS defaults to half the cores, clamped to 1..6, on Linux, and to 1
# on macOS, where Godot ignores XDG_DATA_HOME and every process would
# share the one "Shandalar Integration Tests" profile. SHARDS=1 is the
# old single run. SHARD=i (1-based, with SHARDS=N) runs only the i-th
# deal in this one process, streaming as the single run does — the shape
# CI uses, one runner per shard; it reads the profile itself, so two
# slices on one machine want SHARDS alone, not two SHARDs.
#
# Anything on the command line (a -gselect, a -gunit_test_name) is one
# script or one test: that runs in ONE process as before, whatever SHARDS
# says, because five processes running nothing would each print an empty
# summary and the gate would rightly refuse them.
if [ "$(uname -s)" = Darwin ]; then
	SHARDS="${SHARDS:-1}"
else
	cores="$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)"
	default_shards=$(( cores / 2 ))
	[ "$default_shards" -lt 1 ] && default_shards=1
	[ "$default_shards" -gt 6 ] && default_shards=6
	SHARDS="${SHARDS:-$default_shards}"
fi
case "$SHARDS" in
	'' | *[!0-9]* | 0) echo "SHARDS must be a positive integer, not '$SHARDS'." >&2; exit 2 ;;
esac
if [ -n "${SHARD:-}" ]; then
	case "$SHARD" in
		*[!0-9]* | 0) echo "SHARD must be a positive integer, not '$SHARD'." >&2; exit 2 ;;
	esac
	if [ "$SHARD" -gt "$SHARDS" ]; then
		echo "SHARD=$SHARD but there are only $SHARDS shards." >&2; exit 2
	fi
fi
if [ "$#" -gt 0 ]; then
	SHARDS=1; SHARD=''
fi

# Every test script GUT would find: its prefix, its suffix, its
# directory, its subdirectories (`-gdir=res://tests -ginclude_subdirs`),
# sorted so a deal is the same on every machine.
all_scripts="$(find tests -type f -name 'test_*.gd' | sort)"

# THE SKIN. Some scripts pin the 1997 look itself — the card frames, the
# grave plates, the button faces, the numerals — and can only be read
# against the skin tools/import_original.py copies out of a player's own
# copy of the game into assets/original (gitignored, never released,
# never on a runner). Each such script says so on its first doc line.
# Where the folder is absent (a fresh clone, CI) they are left out BY
# NAME, the count every gate below holds the run to is of what is left,
# and the last line says how many were not run. Nothing is skipped
# silently: a script that needs the skin and does not say so goes red
# here as it always did.
SKIN_MARKER='^## Needs the imported 1997 skin'
skin_left_out=0
if [ -d assets/original ]; then
	scripts_on_disk="$all_scripts"
else
	skin_scripts="$(printf '%s\n' "$all_scripts" | xargs grep -l "$SKIN_MARKER" | sort || true)"
	skin_left_out="$(printf '%s\n' "$skin_scripts" | grep -c . || true)"
	scripts_on_disk="$(printf '%s\n' "$all_scripts" | grep -vxF -f <(printf '%s\n' "$skin_scripts") || true)"
	echo "The imported 1997 skin is not here (assets/original): $skin_left_out of $(printf '%s\n' "$all_scripts" | grep -c .) test scripts pin it and are left out:"
	printf '%s\n' "$skin_scripts" | sed 's/^/  /'
fi
script_count="$(printf '%s\n' "$scripts_on_disk" | grep -c .)"
left_out_note=""
if [ "$skin_left_out" -gt 0 ]; then
	left_out_note=" ($skin_left_out left out: no 1997 skin)"
fi

# The i-th of N deals, as one -gtest= value (GUT splits the list on the
# comma; no path here has one). tools/deal_tests.py deals: every Nth
# script when nothing is known, the slowest first — each to the process
# with the least on it — from the JUnit files the LAST run left in the
# test profile. So the second sharded run on a desk is balanced by the
# first, and a runner that has never run (CI) deals the same way every
# time.
# `deal N i`; an empty deal (a tool error, a shard past N) is a gate
# failure here, not GUT's "no directories configured" minutes later.
deal() {
	local list
	list="$(printf '%s\n' "$scripts_on_disk" | python3 tools/deal_tests.py "$1" "$2" \
		"$SHANDALAR_TEST_DATA_HOME"/gut-junit.xml "$SHANDALAR_TEST_DATA_HOME"/shard-*/gut-junit.xml)" \
		&& [ -n "$list" ] || { echo "SUITE IS NOT GREEN: could not deal shard $2 of $1." >&2; return 1; }
	printf '%s' "$list"
}

# One value out of a GUT totals block (the LAST block in the log, and
# only a line at column 0 — the per-test lines are indented). Empty when
# GUT never printed one; `count_of` says 0 instead, for the sums.
total_of() {
	grep -oE "^$1 +[0-9]+" "$2" | tail -n 1 | grep -oE '[0-9]+$' || true
}
count_of() {
	local value
	value="$(total_of "$1" "$2")"
	echo "${value:-0}"
}

# THE GATE OVER ONE LOG. Every check below is a thing GUT calls green and
# this script does not (the header of this file); the label names the
# process so a red shard is found without reading six logs.
read_gate() {
	local log="$1" status="$2" label="$3"
	if [ "$status" -eq 124 ] || [ "$status" -eq 137 ]; then
		echo
		echo "==============================================" >&2
		echo "SUITE IS NOT GREEN: $label TIMED OUT after $SUITE_TIMEOUT s (Godot exited $status)." >&2
		echo "A test is probably awaiting a signal that never fires. The last" >&2
		echo "test name printed above is the one that hung, or the one before it." >&2
		echo "==============================================" >&2
		return 124
	fi

	# Anything that means "a test file did not run". Kept narrow on purpose:
	# these patterns name the FILE, so the message below is actionable.
	if grep -qE 'Parse Error|does not extend GutTest|Compile Error' "$log"; then
		echo
		echo "=============================================="
		echo "SUITE IS NOT GREEN: a test script failed to LOAD ($label)."
		echo "GUT skips those silently and still reports success —"
		echo "the summary above is wrong. Offending lines:"
		echo "=============================================="
		grep -nE 'Parse Error|does not extend GutTest|Compile Error' "$log" \
			| head -20
		return 1
	fi

	# GUT's own tally decides whether the TESTS passed; the process status
	# decides whether the PROCESS was healthy, and both must hold.
	#
	# Until 2026-09-02 this script accepted exit 134 (SIGABRT) as normal,
	# believing it to be the Compatibility renderer's GL teardown. It was a
	# real heap corruption — the card registry's static dictionary being
	# destroyed after the card scripts were unloaded — and the windowed game
	# aborted the same way on Exit. The `Lifecycle` autoload
	# (game/lifecycle.gd) now clears the registry as the tree finalises, so a
	# clean run exits 0 and an abort is once again a finding, not noise.
	local failing
	failing="$(total_of 'Failing Tests' "$log")"
	if [ -n "$failing" ] && [ "$failing" -gt 0 ]; then
		echo "SUITE IS NOT GREEN: $failing failing test(s) in $label." >&2
		return 1
	fi
	if ! grep -qE '^Passing Tests +[0-9]+' "$log"; then
		echo "SUITE IS NOT GREEN: GUT printed no summary at all ($label)." >&2
		return 1
	fi

	# A risky test (0 asserts), a pending one, a skipped script, or a GUT
	# internal error: GUT prints them in yellow in the totals and exits 0.
	# Only the totals block is read (anchored at column 0 — the per-test
	# lines are indented), and GUT omits a line whose count is zero.
	if grep -qE '^(Risky/Pending|Errors) +[1-9]' "$log"; then
		echo
		echo "=============================================="
		echo "SUITE IS NOT GREEN: GUT reports risky/pending tests or its own errors ($label)."
		echo "A test with no assert is not a test (CONTRIBUTING.md, 'Scratch files')."
		echo "=============================================="
		grep -nE '^(Risky/Pending|Errors) +[1-9]|\[Risky\]|\[Pending\]|Script was skipped' "$log" \
			| head -20
		return 1
	fi

	# Every error Godot printed, wherever it happened. GUT only fails a test
	# for an error raised INSIDE that test's body; one raised in before_each,
	# after_each, before_all, a deferred call or the teardown frame is filed
	# under NO_TEST and never read (see the header). A green run prints none.
	local error_lines='^(SCRIPT ERROR|ERROR|USER ERROR|USER SCRIPT ERROR):'
	if grep -qE "$error_lines" "$log"; then
		echo
		echo "=============================================="
		echo "SUITE IS NOT GREEN: Godot printed an error that no test owned ($label)."
		echo "(Errors outside a test body — setup, teardown, deferred calls —"
		echo "never reach GUT's tally.) Offending lines:"
		echo "=============================================="
		grep -nE "$error_lines" "$log" | head -20
		return 1
	fi

	if [ "$status" -ne 0 ]; then
		echo "SUITE IS NOT GREEN: every test passed but Godot exited $status ($label)." >&2
		echo "(134 = SIGABRT at teardown. See game/lifecycle.gd — something" >&2
		echo "static is being destroyed after the scripts it points into.)" >&2
		return "$status"
	fi
	# The exit-time leak report is a WARNING, and the one WARNING this script
	# reads: an object alive after the tree is gone is the same class of bug
	# as the SIGABRT above, one step earlier.
	if grep -q 'ObjectDB instances were leaked at exit' "$log"; then
		echo "SUITE IS NOT GREEN: Godot exited 0 but leaked objects at exit ($label):" >&2
		grep -n 'ObjectDB instances were leaked at exit' "$log" | head -3 >&2
		return 1
	fi
	return 0
}

# GUT's totals block ends with GUT's own time; the sum's ends with the
# wall time, which is the number sharding is for.
print_totals() {
	local label="$1" scripts="$2" tests="$3" passing="$4" failing="$5" asserts="$6" seconds="$7"
	echo
	echo "$label"
	printf '%s\n' "$label" | sed 's/./-/g'
	echo
	printf 'Scripts        %8d\n' "$scripts"
	printf 'Tests          %8d\n' "$tests"
	printf 'Passing Tests  %8d\n' "$passing"
	if [ "$failing" -gt 0 ]; then printf 'Failing Tests  %8d\n' "$failing"; fi
	printf 'Asserts        %8d\n' "$asserts"
	printf 'Time           %8ds (wall)\n' "$seconds"
}

# A killed test cannot run after_each; do not inherit its enabled packs.
# The helper refuses to touch a non-test profile, and changes no player data.
reset_packs() {
	"$SHANDALAR_TIMEOUT" -k 5 60 "$GODOT" --headless --path . \
		-s tools/reset_test_packs.gd >"$XDG_DATA_HOME/reset-packs.log" 2>&1 </dev/null
}

# ONE PROCESS: the whole suite, one deal of it, or whatever the command
# line selects — streamed through tee as it always was, then gated.
if [ "$SHARDS" -eq 1 ] || [ -n "${SHARD:-}" ]; then
	reset_packs
	if [ -n "${SHARD:-}" ]; then
		selection="-gtest=$(deal "$SHARDS" "$SHARD")" || exit 1
		echo "Shard $SHARD of $SHARDS: $(printf '%s' "$selection" | tr ',' '\n' | grep -c .) of $script_count scripts."
	elif [ "$skin_left_out" -gt 0 ]; then
		# The one deal of one, so GUT gets the list and not the directory.
		selection="-gtest=$(deal 1 1)" || exit 1
	else
		selection="-gdir=res://tests -ginclude_subdirs"
	fi
	log="$(mktemp)"
	trap 'rm -f "$log"' EXIT
	started=$SECONDS
	set +e
	# shellcheck disable=SC2086  # the selection is one or two GUT flags
	"$SHANDALAR_TIMEOUT" -k 5 "$SUITE_TIMEOUT" "$GODOT" --headless --path . \
		--log-file "$SHANDALAR_TEST_DATA_HOME/gut-engine.log" \
		-s addons/gut/gut_cmdln.gd \
		$selection -gjunit_xml_file="$SHANDALAR_TEST_DATA_HOME/gut-junit.xml" \
		-gexit "$@" </dev/null 2>&1 | tee "$log"
	status=${PIPESTATUS[0]}
	set -e
	read_gate "$log" "$status" "the run" || exit $?
	if [ -z "${SHARD:-}" ] && [ "$#" -eq 0 ]; then
		ran="$(total_of Scripts "$log")"
		if [ "$ran" != "$script_count" ]; then
			echo "SUITE IS NOT GREEN: $script_count test scripts on disk$left_out_note, GUT ran ${ran:-none}." >&2
			exit 1
		fi
		echo "---- The suite passed: $script_count scripts$left_out_note. ----"
	fi
	exit 0
fi

# SHARDS PROCESSES, all here, all at once. Each shard's log is printed
# whole as it finishes (in deal order, so the output reads like N single
# runs back to back), then the gate reads every log, then the sum.
echo "Dealing $script_count test scripts over $SHARDS Godot processes."
started=$SECONDS
i=1
while [ "$i" -le "$SHARDS" ]; do
	home="$SHANDALAR_TEST_DATA_HOME/shard-$i"
	mkdir -p "$home"
	# Dealt here, before any shard runs, so every deal reads the SAME last
	# run's JUnit files (GUT writes its own only as it ends).
	list="$(deal "$SHARDS" "$i")" || exit 1
	(
		export XDG_DATA_HOME="$home"
		reset_packs
		"$SHANDALAR_TIMEOUT" -k 5 "$SUITE_TIMEOUT" "$GODOT" --headless --path . \
			--log-file "$home/gut-engine.log" \
			-s addons/gut/gut_cmdln.gd \
			-gtest="$list" -gjunit_xml_file="$home/gut-junit.xml" \
			-gexit </dev/null >"$home/gut.log" 2>&1
	) &
	eval "pid_$i=$!"
	i=$(( i + 1 ))
done

set +e
sum_scripts=0; sum_tests=0; sum_passing=0; sum_failing=0; sum_asserts=0
red=0
i=1
while [ "$i" -le "$SHARDS" ]; do
	eval "pid=\$pid_$i"
	wait "$pid"; status=$?
	home="$SHANDALAR_TEST_DATA_HOME/shard-$i"
	log="$home/gut.log"
	cat "$log"
	echo
	echo "---- shard $i of $SHARDS: Scripts $(count_of Scripts "$log"), Tests $(count_of Tests "$log"), Passing $(count_of 'Passing Tests' "$log"), Asserts $(count_of Asserts "$log"), Godot exit $status ----"
	if ! read_gate "$log" "$status" "shard $i of $SHARDS"; then
		red=1
	fi
	sum_scripts=$(( sum_scripts + $(count_of Scripts "$log") ))
	sum_tests=$(( sum_tests + $(count_of Tests "$log") ))
	sum_passing=$(( sum_passing + $(count_of 'Passing Tests' "$log") ))
	sum_failing=$(( sum_failing + $(count_of 'Failing Tests' "$log") ))
	sum_asserts=$(( sum_asserts + $(count_of Asserts "$log") ))
	i=$(( i + 1 ))
done
set -e

print_totals "Totals ($SHARDS shards)" "$sum_scripts" "$sum_tests" "$sum_passing" "$sum_failing" "$sum_asserts" $(( SECONDS - started ))
echo
if [ "$red" -ne 0 ]; then
	echo "SUITE IS NOT GREEN: see the shard(s) named above." >&2
	exit 1
fi
if [ "$sum_scripts" != "$script_count" ]; then
	echo "SUITE IS NOT GREEN: $script_count test scripts on disk$left_out_note, the shards ran $sum_scripts." >&2
	exit 1
fi
echo "---- All $SHARDS shards passed: $sum_tests tests, $sum_asserts asserts, $script_count scripts$left_out_note. ----"
exit 0
