# THE FAMILY BANNER, SHELL SIDE — sourced by run_tests.sh, duel_soak.sh,
# deck_convert.sh, build_release.sh and DeckLab/deck_lab.sh. Not a script:
# it defines four functions and returns.
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

## The banner on stderr: three rows of wordmark (BANNER_ROW_0..2) with a
## two-line caption beside it (BANNER_CAP_0, BANNER_CAP_1) and the five
## mana pips signing the last row with the version. The caller sets those
## five variables; this draws them or, off a terminal, draws nothing.
shandalar_banner() {
	shandalar_banner_wanted || return 0
	local amber="" dim="" reset="" w="" u="" b="" r="" g="" version
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
