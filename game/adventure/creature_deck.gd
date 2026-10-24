class_name CreatureDeck
extends RefCounted
## THE CREATURES' DECKS AS THE 1997 GAME PLAYED THEM — each creature's
## MAINDECK and its COLOUR SECTIONS, read from our deck files
## (`decks/1997/originals/<file>.deck`, [method CreatureBook.deck_path]), and
## the 1997 rules that make a duel's library of them
## (`LoadCreatureDuelDeck` / `ParseDeckFileIntoInitialLibrary`,
## visitLocation.c 2320–2526; retail world/database.c 1140 the same).
##
## THE FILES. A 1997 deck (`Decks/0NNN.dck`, dated 1996-09-27) is a maindeck
## of 57–66 cards (Kiska-Ra's 66, the Dragon Lord's 64; Arzakon's 138) and, in 45 of the 55, six colour sections
## `.vNone`, `.vBlack`, `.vBlue`, `.vGreen`, `.vRed`, `.vWhite` (three cards
## each in 41 of them; the Sainted One's white five; Alt-A-Kesh, Whim,
## Prismat and Arzakon empty). Our `.deck` files list the maindeck WITH the
## `.vNone` section folded in (so each reads as a 60-card deck) and keep the
## six sections, as the 1996 file has them, in the comment table at the
## file's end (`#   .vBlack  3 Weakness`). This class takes them apart
## again: the maindeck is the main list less `.vNone`, the sections are the
## comment table — checked line for line, count for count and in order
## against the local 1996 files (`shandalar-xp/MagicTG/Decks/`, part B
## 2026-10-23; the only differences are our spellings) and pinned by
## `tests/unit/test_b_w1_creature_deck.gd`.
##
## WHAT A CREATURE PLAYS ([method for_meeting]): its maindeck, and each
## colour section whose colour bit is in the FILTER — the colours its own
## colour has learned of the hero's deck ([method
## AdventurePlayer.learned_deck_colors]) or, for henchmen and once the wins
## mount, the hero's colours themselves (the meeting chooses). 1997 never
## sets bit 0x01 in the adventure, so `.vNone` is NEVER played (only the
## main menu's demo loads it, adventure_new_game.c 623–667): [ours: the
## owner's ruling 3 of 2026-10-23, "exact 1997"] — the filter's 0x01 is
## dropped here, whoever passes it.
##
## THE LOADER'S RULES, kept:
##  - a file that is missing loads `0179.dck`, the Centaur Shaman's
##    ([constant FALLBACK_ROW]; [method file_row]);
##  - a card the game does not know is not played, and takes half its count
##    (rounded by the line's place) off the last basic land listed before it
##    when that land has more (the 1997 "basic-land trim"; [method
##    library]). No card of the 55 files is unknown today; a card a pack
##    takes away, or a misspelt one, would meet it.
## The creature's ANTE ([method ante_draw]) and the decks the wise man and
## the Guardian's Ghost show ([method CreatureBook.deck]: the maindeck) are
## here too.
##
## DESIGNED, NEVER USED (and in `docs/adventure-unused-1997-features.md`):
##  - THE `.vNone` SECTION. The designers wrote a "no colour learned yet"
##    section of three cards into 41 decks (57 + 3 = 60), and the loader
##    reads it under bit 0x01 — which the adventure never passes. Switched
##    on, an unlearned creature would play 60 cards with its default answers
##    (the Witch three more Weakness) and swap them for the hero's colours'
##    once it learns them. To switch on: [method for_meeting] lets 0x01
##    through and the meeting passes 0x01 while the colour has learned
##    nothing. RULED OUT for now by the owner (ruling 3).
##  - THE RULES SECTIONS `.vFAST`, `.vLARGE`, `.vDIRECT`, `.vARTIFACT`. The
##    loader keeps such a section's lines only when the creature has learned
##    the hero's matching "speed" (0, 1, 2, 6; learned after a win,
##    world_lair_monster_encounter.c 2638–2645, and never saved). No shipped
##    file has one. Switched on, a creature deck could carry answers to the
##    hero's style — fast attackers, big creatures, burn, artifacts — and
##    bring them once it has seen it. To switch on: such sections in the deck
##    files' comment table, read here beside the colours, and the learned
##    speed saved beside the learned colours.
##  - A COUNT OF 0 MEANS THE DIFFICULTY. The loader means a line's count 0 as
##    the difficulty (0–3 copies) — but both builds store the 0 before putting
##    the difficulty in its place (1.3 `ParseDeckFileIntoInitialLibrary`,
##    retail database.c 1233–1237), the difficulty feeding only the
##    basic-land trim: no copies would load. No shipped line has it. Switched on, a
##    deck could grow sharper with the difficulty — a fourth Lightning Bolt
##    at Wizard only. To switch on: a count the deck format can write for it,
##    and [method library] reading it with the difficulty.

## The five basic lands, the 1997 program's first five cards (its card
## indices 0–4): never an ante, and the lands the trim takes from.
const BASICS: Array[String] = ["Forest", "Island", "Mountain", "Plains", "Swamp"]
## The colour sections in the 1997 files' order, with the filter bit of
## each (`.vNone` 0x01, `.vBlack` 0x02 … `.vWhite` 0x20: the colour bit
## `1 << colour`, as [constant CreatureBook.COLORS]).
const SECTIONS: Array[String] = ["None", "Black", "Blue", "Green", "Red", "White"]
const NONE_BIT := 0x01
## The colour bits a filter may let through: never `.vNone` (ruling 3).
const PLAYED_BITS := 0x3E
## The row whose deck a creature with no deck file plays: the Centaur
## Shaman's (1997's `decks\0179.dck`).
const FALLBACK_ROW := 39

## Each file read, by path: `{lines, sections}` ([method parse_text]) —
## names and counts only.
static var _read := {}


## THE CREATURE'S MAINDECK: every card, expanded ("4 Swamp" four times), in
## the 1997 file's order — the deck as data, every name as the file spells
## it. Empty for a row with no deck (after the fallback).
static func maindeck(row: int) -> Array[String]:
	var out: Array[String] = []
	for line: Dictionary in _deck_of(row)["lines"]:
		if int(line["bit"]) == 0:
			for i in int(line["count"]):
				out.append(String(line["name"]))
	return out


## THE CREATURE'S COLOUR SECTIONS, `{colour bit: [names, expanded]}` — all
## six, `.vNone` (0x01) among them as data though it is never played; `{}`
## for the ten decks with none.
static func sections(row: int) -> Dictionary:
	var out := {}
	for line: Dictionary in _deck_of(row)["lines"]:
		var bit := int(line["bit"])
		if bit == 0:
			continue
		if not out.has(bit):
			out[bit] = [] as Array[String]
		for i in int(line["count"]):
			(out[bit] as Array[String]).append(String(line["name"]))
	return out


## THE DECK A CREATURE PLAYS AT A MEETING with filter [param filter_bits]
## (colour bits 0x02 black … 0x20 white; 0 for the maindeck alone): its
## maindeck and each section of a colour in the filter, in the file's order,
## every card the game knows ([method library]). `.vNone` never ([constant
## PLAYED_BITS], ruling 3).
static func for_meeting(row: int, filter_bits: int) -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in library(row, filter_bits):
		if bool(entry["known"]):
			for i in int(entry["count"]):
				out.append(String(entry["name"]))
	return out


## THE LIBRARY 1997 LOADS for [param row] under [param filter_bits]: the
## lines kept, in order, `{name, count, known}` — a card the game does not
## know is kept as 1997 kept it (it counts for the ante's draw) but marked,
## and it has taken from the basic land before it: half its count, plus one
## when its line stands at an odd place among the file's card and section
## lines, off the last basic land kept before it, when that land has more
## copies than it (`ParseDeckFileIntoInitialLibrary`, visitLocation.c
## 2366, the trim at 2428–2450). [param known] answers whether a card is
## known (the card pool by default).
static func library(row: int, filter_bits: int, known := Callable()) -> Array[Dictionary]:
	return library_of(_deck_of(row), filter_bits, known)


## [method library] of a deck already taken apart ([method parse_text]).
static func library_of(parsed: Dictionary, filter_bits: int, known := Callable()) -> Array[Dictionary]:
	var is_known := known
	if not is_known.is_valid():
		is_known = func(card_name: String) -> bool: return CardRegistry.has_card(card_name)
	var filter := filter_bits & PLAYED_BITS
	var out: Array[Dictionary] = []
	var last_basic := -1
	for line: Dictionary in parsed.get("lines", []):
		var bit := int(line["bit"])
		if bit != 0 and filter & bit == 0:
			continue
		var card_name := String(line["name"])
		var entry := {"name": card_name, "count": int(line["count"]), "known": bool(is_known.call(card_name))}
		if bool(entry["known"]):
			if card_name in BASICS:
				last_basic = out.size()
		elif last_basic >= 0 and int(out[last_basic]["count"]) > int(entry["count"]):
			out[last_basic]["count"] = int(out[last_basic]["count"]) \
				- (int(line["at"]) % 2 + int(entry["count"])) / 2
		out.append(entry)
	return out


## THE CREATURE'S ANTE: one card drawn from its maindeck on the adventure's
## [param dice] as 1997 draws it (world_lair_monster_encounter.c 1576–1590,
## `DrawRandomCardFromInitialLibrary` duel_ai_support.c 66): a card at
## random, each copy alike (`rand(cards left)`), taken out, and drawn again
## until it is not a basic land, not one of the dungeons' treasures (the
## restricted cards, `extra_ability` 0x100: [constant
## ShandalarWorld.DUNGEON_CARDS]), a card of the game, and not the
## creature's signature card ([method CreatureBook.signature_card]: the
## Warlock never antes Dark Ritual). Henchmen ante nothing (and draw no
## dice); "" when no card is left that may be. [Ours: 1997 read an unknown
## card's draw past the card table's end; it is drawn again here.]
static func ante_draw(row: int, dice: MsvcRandom) -> String:
	if CreatureBook.kind(row) == CreatureBook.HENCHMAN:
		return ""
	var pool := library(row, 0)
	var left := 0
	for entry in pool:
		left += int(entry["count"])
	var signature := CreatureBook.signature_card(row)
	var treasures := {}
	for treasure in ShandalarWorld.DUNGEON_CARDS:
		treasures[String(treasure[1])] = true
	while left > 0:
		var at := dice.below(left)
		left -= 1
		for entry in pool:
			at -= int(entry["count"])
			if at < 0:
				entry["count"] = int(entry["count"]) - 1
				var card_name := String(entry["name"])
				if bool(entry["known"]) and not card_name in BASICS and not treasures.has(card_name) \
						and card_name != signature:
					return card_name
				break
	return ""


## The row whose deck file [param row] plays: its own, or the Centaur
## Shaman's when it has none or the file is missing (1997's `0179.dck`
## fallback — the lair's row has no deck).
static func file_row(row: int) -> int:
	var path := CreatureBook.deck_path(row)
	return row if path != "" and FileAccess.file_exists(path) else FALLBACK_ROW


# ----------------------------------------------------------- the files --

## THE DECK FILE'S TEXT TAKEN APART: `{lines, sections}` — `lines` every
## card line in the 1997 file's order, `{name, count, bit, at}`: the
## maindeck (bit 0) and then, when the file has sections, each section's
## cards in the order `.vNone` … `.vWhite` (its bit); `at` is the line's
## place among the 1997 file's card and section lines, counted from 0 (the
## parity the trim rounds by); `sections` whether the file has them.
## The maindeck is the main list less the `.vNone` section; a `.vNone` card
## the main list lacks (no file has one) is reported.
static func parse_text(text: String) -> Dictionary:
	var main: Array = []
	var table := {}
	for raw in text.split("\n"):
		var line := raw.strip_edges(false, true)
		if line.begins_with("#   .v"):
			var rest := line.substr(6)
			var space := rest.find(" ")
			var section := rest.substr(0, space) if space > 0 else rest
			if section in SECTIONS:
				table[section] = _section_cards(rest.substr(space + 1).strip_edges() if space > 0 else "")
			continue
		if line.begins_with("#") or line.begins_with("name:") or line.to_upper().begins_with("SB:"):
			continue
		var gap := line.find(" ")
		if gap > 0 and line.substr(0, gap).is_valid_int():
			main.append([line.substr(gap + 1).strip_edges(), line.substr(0, gap).to_int()])
	var folded := {}
	for card in table.get("None", []):
		folded[String(card[0])] = int(folded.get(String(card[0]), 0)) + int(card[1])
	var lines: Array[Dictionary] = []
	var at := 0
	for card in main:
		var count := int(card[1]) - int(folded.get(String(card[0]), 0))
		folded.erase(String(card[0]))
		if count > 0:
			lines.append({"name": String(card[0]), "count": count, "bit": 0, "at": at})
			at += 1
	for missing in folded:
		push_warning("CreatureDeck: .vNone's %s is not in the main list" % missing)
	if not table.is_empty():
		for i in SECTIONS.size():
			at += 1
			for card in table.get(SECTIONS[i], []):
				lines.append({"name": String(card[0]), "count": int(card[1]), "bit": 1 << i, "at": at})
				at += 1
	return {"lines": lines, "sections": not table.is_empty()}


## A section's cards from its comment line, "2 Swords to Plowshares, 1
## Disenchant" → `[[name, count], …]`; "(empty)" none.
static func _section_cards(text: String) -> Array:
	var out: Array = []
	if text == "" or text == "(empty)":
		return out
	var parts := RegEx.create_from_string(r"(\d+) (.+?)(?:, (?=\d+ )|$)")
	for found in parts.search_all(text):
		out.append([found.get_string(2).strip_edges(), found.get_string(1).to_int()])
	return out


## The parsed deck [param row] plays ([method file_row]), read once.
static func _deck_of(row: int) -> Dictionary:
	var path := CreatureBook.deck_path(file_row(row))
	if not _read.has(path):
		var file := FileAccess.open(path, FileAccess.READ) if path != "" else null
		_read[path] = parse_text(file.get_as_text()) if file != null else {"lines": [] as Array[Dictionary], "sections": false}
	return _read[path]


## Forget the files read (a test).
static func forget() -> void:
	_read.clear()
