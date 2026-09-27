#!/usr/bin/env bash
# Shandalar — ONE DOOR to the command-line tools (2026-09-27), so that a
# program (or a person) learns one name and one contract:
#
#   ./shandalar.sh lab ARGS...        the Deck Lab        (DeckLab/deck_lab.sh)
#   ./shandalar.sh autodeck ARGS...   the AutoDeck CLI    (DeckLab/auto_deck_cli.sh)
#   ./shandalar.sh check DECK...      is this deck playable, and why not
#   ./shandalar.sh packs              every card pack: found, on, why not
#   ./shandalar.sh cards NAME...      a card's record     (DeckLab/lab_query.sh)
#   ./shandalar.sh convert IN OUT     .deck <-> .dck      (deck_convert.sh)
#   ./shandalar.sh VERB --help        that tool's own manual
#   ./shandalar.sh -h | --help        this list, on stdout
#   ./shandalar.sh -V | --version     the one version string
#
# Every tool keeps its own exit codes (0 done, 1 broke, 2 the line was
# wrong, 3 no Godot, 4 the Lab's control moved) and its own stdout
# contract — a report, a plan or one JSON document; a refusal is one
# JSON line on stdout, `{"error": {...}}`. A verb this door does not
# know is refused the same way, exit 2. AGENTS.md is the contract page.
set -euo pipefail
cd "$(dirname "$0")"

usage() {
	sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'
}

verb="${1:-}"
case "$verb" in
	"" | -h | --help) usage; exit 0 ;;
	-V | --version) . tools/banner.sh; shandalar_version_line "shandalar.sh" .; exit 0 ;;
esac
shift
case "$verb" in
	lab) exec DeckLab/deck_lab.sh "$@" ;;
	autodeck) exec DeckLab/auto_deck_cli.sh "$@" ;;
	check | packs | cards) exec DeckLab/lab_query.sh "$verb" "$@" ;;
	query) exec DeckLab/lab_query.sh "$@" ;;
	convert) exec ./deck_convert.sh "$@" ;;
esac
# The verb goes into the line with the characters JSON would need
# escaped removed, so the line is always one valid document.
safe="$(printf '%s' "$verb" | tr -d '"\\\n\r\t')"
printf '{"error":{"tool":"shandalar","exit":2,"kind":"option","message":"unknown verb %s — the verbs are lab, autodeck, check, packs, cards, convert","verb":"%s"}}\n' \
	"'$safe'" "$safe"
echo "shandalar.sh: unknown verb '$verb' — try ./shandalar.sh --help" >&2
exit 2
