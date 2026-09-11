# THE FAMILY BANNER, SHELL SIDE — sourced by run_tests.sh, duel_soak.sh,
# deck_convert.sh, build_release.sh and DeckLab/deck_lab.sh. Not a script:
# it defines six functions and returns.
#
# This is the shell half of tools/tool_banner.py, which is in turn the
# Python half of DeckLab/lab_console.gd. Read that GDScript header for the
# argument; the rules it settles are repeated here because breaking any one
# of them is a bug, not a style disagreement.
#
# STDOUT IS THE INSTRUMENT'S, STDERR IS THE HUMAN'S. Every one of these
# scripts has a stdout something else reads — build_release.sh's names the
# files a release is made of, run_tests.sh's is GUT's report and its own
# gate greps it, duel_soak.sh's carries the SOAK lines. So the banner goes
# to stderr, and ONLY when stderr is a terminal. `./run_tests.sh > log`
# keeps the artwork on screen and the log clean; `./run_tests.sh > log 2>&1`
# — what a script or an agent writes — gets no decoration at all, without
# anyone having to remember a flag.
#
# ONE SOURCE FOR THE VERSION: project.godot's `config/version=`, found by
# walking up from the script that sourced this. No file, no number — the
# banner says "version unknown" rather than inventing one.
#
# THE OPT-OUT: SHANDALAR_NO_BANNER=1 for every tool in the family (the
# Deck Lab's own DECK_LAB_NO_BANNER still works too, and deck_lab.sh maps
# one onto the other). NO_COLOR=1 (https://no-color.org) keeps the shape
# and drops the colour.
#
# THE MINI-HELP (2026-09-11) is the same decoration and rides the same
# three guards: two or three of the invocations somebody actually types,
# drawn under the wordmark for a BARE command line only, with a last line
# naming -h. `shandalar_banner_hint "$#" 'line' 'line' 'line'` sets it —
# the argument count is the caller's own, taken before any `shift`, and
# anything on the command line means the reader has already said what
# they want. The lines are quoted out of each script's own usage block,
# so the two cannot drift; tools/test_tool_banner.py pins that.
#
# NOTHING HERE MAY FAIL A CALLER. Every function returns 0 and writes only
# to stderr (except shandalar_version_line, which is a --version answer and
# belongs on stdout). A decoration that can fail a release build is worse
# than no decoration at all.

## The project's version, echoed, or nothing at all. Walks up from $1
## (default: the current directory) looking for project.godot.
shandalar_version() {
	local dir version
	dir="$(cd "${1:-.}" 2>/dev/null && pwd)" || return 0
	while [ -n "$dir" ]; do
		if [ -r "$dir/project.godot" ]; then
			version="$(sed -n 's/^config\/version="\(.*\)"/\1/p' \
				"$dir/project.godot" 2>/dev/null | head -1)"
			[ -n "$version" ] && printf '%s' "$version"
			return 0
		fi
		[ "$dir" = "/" ] && break
		dir="$(dirname "$dir")"
	done
	return 0
}

## The whole `--version` answer for TOOL, on stdout. Says where it looked
## when there is no project.godot, rather than printing a number nobody
## can trust — which is what a copy of a script outside a checkout sees.
shandalar_version_line() {
	local tool="$1" dir="${2:-.}" version
	version="$(shandalar_version "$dir")"
	if [ -n "$version" ]; then
		printf '%s — Shandalar %s\n' "$tool" "$version"
	else
		printf '%s — Shandalar version unknown: no project.godot above %s\n' \
			"$tool" "$(cd "$dir" 2>/dev/null && pwd || printf '%s' "$dir")"
	fi
	return 0
}

## Whether to draw anything at all: a terminal on stderr, and no opt-out.
## A pipe, a file, a CI log and an agent's `2>&1` all get nothing.
shandalar_banner_wanted() {
	case "${SHANDALAR_NO_BANNER:-}" in "" | 0) ;; *) return 1 ;; esac
	[ -t 2 ]
}

## THE MINI-HELP FOR A BARE COMMAND LINE. $1 is the caller's own argument
## count — taken before any `shift`, and zero means nobody has said what
## they want yet — and the rest are the lines to show, one invocation
## each. Sets BANNER_HINT, which shandalar_banner draws under the
## wordmark; with arguments on the line it sets nothing, because a reader
## who typed a flag is not looking for a reminder of it.
shandalar_banner_hint() {
	local argc="${1:-0}"
	shift || true
	BANNER_HINT=""
	if [ "$argc" = 0 ] && [ "$#" -gt 0 ]; then
		BANNER_HINT="$(printf '%s\n' "$@")"
	fi
	return 0
}

## The banner on stderr: three rows of wordmark (BANNER_ROW_0..2) with a
## two-line caption beside it (BANNER_CAP_0, BANNER_CAP_1) and the five
## mana pips signing the last row with the version — then the mini-help
## in BANNER_HINT, when there is one. The caller sets those variables;
## this draws them or, off a terminal, draws nothing at all.
shandalar_banner() {
	shandalar_banner_wanted || return 0
	local amber="" dim="" reset="" w="" u="" b="" r="" g="" version line
	if [ -z "${NO_COLOR:-}" ]; then
		amber=$'\033[33m\033[1m'; dim=$'\033[2m'; reset=$'\033[0m'
		# Black is grey because black on black is nothing.
		w=$'\033[97m'; u=$'\033[94m'; b=$'\033[90m'
		r=$'\033[91m'; g=$'\033[92m'
	fi
	version="$(shandalar_version "${1:-.}")"
	[ -n "$version" ] || version="version unknown"
	{
		printf '  %s%s%s   %s%s%s\n' "$amber" "${BANNER_ROW_0:-}" "$reset" \
			"$dim" "${BANNER_CAP_0:-}" "$reset"
		printf '  %s%s%s   %s%s%s\n' "$amber" "${BANNER_ROW_1:-}" "$reset" \
			"$dim" "${BANNER_CAP_1:-}" "$reset"
		printf '  %s%s%s   %sW%s %sU%s %sB%s %sR%s %sG%s   %s%s%s\n\n' \
			"$amber" "${BANNER_ROW_2:-}" "$reset" \
			"$w" "$reset" "$u" "$reset" "$b" "$reset" \
			"$r" "$reset" "$g" "$reset" "$dim" "$version" "$reset"
		# The `# note` after each invocation is dimmed and the command is
		# not, so the eye lands on the thing that gets typed. Same shape
		# as tools/tool_banner.py's hint_lines().
		if [ -n "${BANNER_HINT:-}" ]; then
			while IFS= read -r line; do
				[ -n "$line" ] || continue
				case "$line" in
					?*'#'*) printf '  %s%s%s%s\n' "${line%%#*}" \
						"$dim" "#${line#*#}" "$reset" ;;
					*) printf '  %s\n' "$line" ;;
				esac
			done <<< "${BANNER_HINT:-}"
			printf '\n'
		fi
	} >&2
	return 0
}

## The paragraph every one of these scripts ends its --help with.
shandalar_banner_help() {
	cat <<'BANNERHELP'
The banner goes to stderr and only to a terminal, so a redirected run is
clean. Export SHANDALAR_NO_BANNER=1 to switch it off for every tool here,
NO_COLOR=1 to keep the shape without the colour. -V / --version prints the
version on its own.
BANNERHELP
	return 0
}

:
