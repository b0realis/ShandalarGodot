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
set -euo pipefail
cd "$(dirname "$0")"

GODOT="${GODOT:-../tools/godot}"
if [ ! -x "$GODOT" ]; then GODOT=godot; fi
SUITE_TIMEOUT="${SUITE_TIMEOUT:-1800}"

# THE SUITE DOES NOT WRITE THE PLAYER'S PROFILE
# ---------------------------------------------
# `user://` is `$XDG_DATA_HOME/godot/app_userdata/Shandalar` — the SAME
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
# One directory, reused so the shader cache and GUT's temp dir stay warm.
# Override with SHANDALAR_TEST_DATA_HOME to put it elsewhere; point it at
# "$HOME/.local/share" to get the old behaviour back, which no test needs
# — the whole suite is green from an empty one (`GameSkin` falls back to
# `res://assets/original` in a dev checkout, which is why).
: "${SHANDALAR_TEST_DATA_HOME:=${TMPDIR:-/tmp}/shandalar-test-data}"
mkdir -p "$SHANDALAR_TEST_DATA_HOME"
export XDG_DATA_HOME="$SHANDALAR_TEST_DATA_HOME"

# Import step (quick no-op when the .godot cache is warm; a cold import
# of the card art is minutes, not hours, so 600 s is generous).
timeout -k 5 600 "$GODOT" --headless --import . >/dev/null 2>&1 </dev/null || true

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

set +e
timeout -k 5 "$SUITE_TIMEOUT" "$GODOT" --headless --path . \
	-s addons/gut/gut_cmdln.gd \
	-gdir=res://tests -ginclude_subdirs -gexit "$@" </dev/null 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
set -e

if [ "$status" -eq 124 ] || [ "$status" -eq 137 ]; then
	echo
	echo "==============================================" >&2
	echo "SUITE IS NOT GREEN: TIMED OUT after $SUITE_TIMEOUT s (Godot exited $status)." >&2
	echo "A test is probably awaiting a signal that never fires. The last" >&2
	echo "test name printed above is the one that hung, or the one before it." >&2
	echo "==============================================" >&2
	exit 124
fi

# Anything that means "a test file did not run". Kept narrow on purpose:
# these patterns name the FILE, so the message below is actionable.
if grep -qE 'Parse Error|does not extend GutTest|Compile Error' "$log"; then
	echo
	echo "=============================================="
	echo "SUITE IS NOT GREEN: a test script failed to LOAD."
	echo "GUT skips those silently and still reports success —"
	echo "the summary above is wrong. Offending lines:"
	echo "=============================================="
	grep -nE 'Parse Error|does not extend GutTest|Compile Error' "$log" \
		| head -20
	exit 1
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
failing="$(grep -oE '^Failing Tests +[0-9]+' "$log" | tail -1 \
	| grep -oE '[0-9]+' || true)"
if [ -n "$failing" ] && [ "$failing" -gt 0 ]; then
	exit 1
fi
if ! grep -qE '^Passing Tests +[0-9]+' "$log"; then
	echo "SUITE IS NOT GREEN: GUT printed no summary at all." >&2
	exit 1
fi

# A risky test (0 asserts), a pending one, a skipped script, or a GUT
# internal error: GUT prints them in yellow in the totals and exits 0.
# Only the totals block is read (anchored at column 0 — the per-test
# lines are indented), and GUT omits a line whose count is zero.
if grep -qE '^(Risky/Pending|Errors) +[1-9]' "$log"; then
	echo
	echo "=============================================="
	echo "SUITE IS NOT GREEN: GUT reports risky/pending tests or its own errors."
	echo "A test with no assert is not a test (CONTRIBUTING.md, 'Scratch files')."
	echo "=============================================="
	grep -nE '^(Risky/Pending|Errors) +[1-9]|\[Risky\]|\[Pending\]|Script was skipped' "$log" \
		| head -20
	exit 1
fi

# Every error Godot printed, wherever it happened. GUT only fails a test
# for an error raised INSIDE that test's body; one raised in before_each,
# after_each, before_all, a deferred call or the teardown frame is filed
# under NO_TEST and never read (see the header). A green run prints none.
error_lines='^(SCRIPT ERROR|ERROR|USER ERROR|USER SCRIPT ERROR):'
if grep -qE "$error_lines" "$log"; then
	echo
	echo "=============================================="
	echo "SUITE IS NOT GREEN: Godot printed an error that no test owned."
	echo "(Errors outside a test body — setup, teardown, deferred calls —"
	echo "never reach GUT's tally.) Offending lines:"
	echo "=============================================="
	grep -nE "$error_lines" "$log" | head -20
	exit 1
fi

if [ "$status" -ne 0 ]; then
	echo "SUITE IS NOT GREEN: every test passed but Godot exited $status." >&2
	echo "(134 = SIGABRT at teardown. See game/lifecycle.gd — something" >&2
	echo "static is being destroyed after the scripts it points into.)" >&2
	exit "$status"
fi
# The exit-time leak report is a WARNING, and the one WARNING this script
# reads: an object alive after the tree is gone is the same class of bug
# as the SIGABRT above, one step earlier.
if grep -q 'ObjectDB instances were leaked at exit' "$log"; then
	echo "SUITE IS NOT GREEN: Godot exited 0 but leaked objects at exit:" >&2
	grep -n 'ObjectDB instances were leaked at exit' "$log" | head -3 >&2
	exit 1
fi
exit 0
