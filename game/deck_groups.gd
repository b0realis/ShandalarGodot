class_name DeckGroups
extends RefCounted
## WHERE A DECK CAME FROM — the heading it appears under in the battle
## setup screen's deck list.
##
## The owner asked for three: the decks the 1997 game shipped, the decks
## its 1998 expansion shipped, and the ones the player built. That is a
## question about PROVENANCE, and provenance is answered two different
## ways depending on which of the two things it is. (The list has since
## grown to eleven — the 2026-09-02 port of every deck group the mtg.wiki
## preconstructed-decks page lists, then the same day's split of the
## non-MicroProse decks into tournament / community / extended community,
## `docs/decks-1997.md` — but the two mechanisms below are unchanged, and
## each new heading is one more DECLARED constant.)
##
##  * **[constant USER] is DERIVED, never declared.** A deck in
##    `user://decks` is the player's, full stop — a file cannot claim to be
##    a 1997 original by typing a line into itself. This is also why the
##    Deck Builder needs no change for any of this: it saves into
##    `user://decks`, so everything it saves is correctly grouped the
##    moment it is written, and a shipped deck the player edits and saves
##    correctly stops being a shipped deck (the manual's own rule, p.148:
##    *"If you load and change one of the creature decks used in the full
##    game, you must save your version of the deck under a new name."*).
##    The Deck Builder still carries the LINE through a load and a save
##    ([member DeckModel.group]) — dropping it was silent data loss on a
##    shipped deck — but carrying it cannot forge a heading, because
##    [method of] never asks the file about [constant USER].
##    THE OTHER HALF OF THAT SENTENCE is not a grouping question and could
##    not be answered here: a saved copy is correctly filed under
##    [constant USER] even when it takes the SHIPPED deck's name, and the
##    two then sit in one list under one name. That is what [method
##    DeckStore.is_shipped_name] refuses (2026-09-04,
##    `tests/ui/test_deck_provenance.gd`) — so "the Deck Builder needs no
##    change" was true of the HEADING and not of the NAME.
##  * **The other groups are DECLARED**, by a `# group:` line in the deck
##    file. That shape is not a new invention: it is exactly the trick
##    `# note:` already uses ([method DeckModel.notes_from_text]), and it
##    works for the same reason — [method DeckList.parse] skips every line
##    beginning with `#`, so **every deck file written before this existed
##    still loads, unchanged, and simply has no declaration.**
##
## THE FOURTH GROUP. The owner named three; this file lists four, and the
## extra one is [constant STARTER] — the five decks THIS PROJECT ships
## (`decks/*.deck`, mirrored by [StarterDecks]). They are not 1997 files
## and they are not the expansion's, so filing them under either would be
## a false claim about where they came from. They get their own honest
## heading instead. A shipped deck that declares nothing lands here.
##
## An unrecognised declaration is IGNORED rather than honoured, so a typo
## in one file cannot invent a heading; the deck falls to [constant
## STARTER] and is still listed. Nothing is ever hidden by a bad line.

## The 1997 MicroProse game's own decks — the 55 enemy decks as the base
## game shipped them (`decks/1997/originals/`).
const ORIGINALS := "1997 originals"
## The first expansion's enemy decks — *Spells of the Ancients* (1997)
## replaced every enemy's list (`decks/1997/ancients/`).
const ANCIENTS := "Spells of the Ancients"
## The second expansion's — *Duels of the Planeswalkers* (1998), the add-on
## whose art and strings this project already reads as `Exp1Art` /
## `@DIALOG_ENDEXP1DUEL` (`Program/UIStrings.txt:580`). Its enemy
## variants, the 25 the wiki lists (`decks/1997/duels/`).
const PLANESWALKERS := "Duels of the Planeswalkers"
## The "Play Deck" folder decks the second expansion installed — player
## decks by three sets of MicroProse hands, one heading each, because the
## wiki page that is the authority for the grouping partitions them that
## way (`docs/decks-1997.md`).
const COYOTE_TEX := "Coyote Tex's decks"
const KEVIN_BANE := "Kevin Bane's decks"
const OTHER := "Other MicroProse decks"
## This project's own starter decks — see the class doc.
const STARTER := "Starter decks"
## Real event lists, 1994-97 — NOT MicroProse's. World Championship
## 1994-97, Pro Tour 1996 (the Collector Set finalists among them) and the
## other sanctioned events whose lists carry a pilot, an event and a year
## (`decks/tournament/`).
const TOURNAMENT := "Tournament decks"
## Period decks from the community, 1994-97, that were not event lists —
## The Deck's versions, Necro, Sligh, Turbo Stasis… and the Shandalar
## community's own re-tuned enemy decks (`decks/community/`).
const COMMUNITY := "Community decks"
## Old School 93/94 archetype reference lists and anything else that leans
## on cards outside this project's pool (`decks/extended_community/`).
const EXTENDED_COMMUNITY := "Extended community decks"
## Decks this project MADE rather than ported (`decks/variants/`).
##
## A GROUP OF ITS OWN, because the others are a ledger. Every heading
## above it holds lists somebody really published, and
## `tests/unit/test_decks_1997.gd` pins each folder to "exactly the number
## of decks its sources yielded" — a sentence a deck of ours would make
## false. The Deck's playable variant went into `extended_community` once
## and those tests caught it (2026-09-06), which is the guard working.
##
## So the variants ship, appear in the picker like anything else, and are
## counted separately: the port stays 312 whatever we add here.
const VARIANTS := "Playable variants"
## Everything in `user://decks`. Derived from the path, never declared.
const USER := "User-created"

## The headings, in the order the deck list shows them: what the game
## shipped first, then what its two expansions added, then the expansion's
## player decks by designer, then ours, then the tournament lists, the
## community's, the community's extended lists, then yours.
const ORDER: Array[String] = [ORIGINALS, ANCIENTS, PLANESWALKERS,
	COYOTE_TEX, KEVIN_BANE, OTHER, STARTER, TOURNAMENT, COMMUNITY,
	EXTENDED_COMMUNITY, VARIANTS, USER]

## The line a deck file declares its group with. Written this way; read
## back tolerantly (see [method declared_in]).
const PREFIX := "# group:"


## Which group [param path] belongs to. Never returns "" — every deck has
## a heading, so no deck can fall out of the list.
static func of(path: String) -> String:
	if DeckStore.is_user_deck(path):
		return USER
	var declared := declared_in(read_text(path))
	return declared if declared != "" else STARTER


## The `# group:` declaration in a deck file's raw text, or "" when there
## is none or it names a group we do not know. Case-insensitive on the
## value, because the heading is prose and a file may reasonably spell it
## "1997 Originals".
static func declared_in(text: String) -> String:
	var value := raw_in(text).to_lower()
	if value == "":
		return ""
	for group in ORDER:
		# USER IS DERIVED FROM THE PATH AND NEVER DECLARED (class doc), and
		# it is in ORDER because ORDER is the display order. Walking ORDER
		# without this made the class doc's promise false in the one
		# direction it did not think of: a shipped `decks/*.deck` could
		# type `# group: User-created` into itself and be filed under the
		# player's own heading.
		if group == USER:
			continue
		if group.to_lower() == value:
			return group
	return ""


## THE DECLARATION EXACTLY AS THE FILE WROTE IT, recognised or not, or ""
## when there is none. [method declared_in] is what MEANS something — it
## drops a value no [constant ORDER] entry matches, which is what stops a
## typo inventing a heading. This is for the one caller that must not
## judge: the Deck Builder carries the line THROUGH a load-and-save
## untouched ([member DeckModel.group]), and re-emitting only the values
## we happen to recognise would quietly rewrite a file we were asked to
## keep.
##
## Tolerant of the spacing a hand-edited file will actually have:
## `#group:`, `# group:` and `#   group:` all declare. `# note:` does not
## need this because only the Deck Builder writes those.
static func raw_in(text: String) -> String:
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		if not line.begins_with("#"):
			continue
		var body := line.substr(1).strip_edges()
		if not body.to_lower().begins_with("group:"):
			continue
		return body.substr(6).strip_edges()
	return ""


## group heading -> its deck paths, in the given order, listing ONLY the
## groups that actually have decks. An empty heading over an empty list is
## the one thing a grouped picker must not show.
static func grouped(paths: Array[String]) -> Dictionary:
	var out := {}
	for path in paths:
		var group := of(path)
		if not out.has(group):
			out[group] = [] as Array[String]
		out[group].append(path)
	# Rebuilt in ORDER so the caller can simply iterate the dictionary.
	var ordered := {}
	for group in ORDER:
		if out.has(group):
			ordered[group] = out[group]
	return ordered


## One reader for the whole project — [DeckStore] owns the file layer and
## reads the same text back for `# note:`.
static func read_text(path: String) -> String:
	return DeckStore.read_text(path)
