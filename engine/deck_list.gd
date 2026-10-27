class_name DeckList
extends RefCounted
## Loader for deck files — accepts BOTH this project's .deck conventions
## and the community-standard Apprentice ".dec" format that The Dojo era
## standardized (and Magic Workstation/Arena lists descend from), so a
## classic decklist pastes straight in.
##
## Accepted, line by line:
##   # comment                  (.deck style)
##   // comment                 (.dec style; "// NAME: X" sets the name)
##   name: My Deck Name         (.deck style name header)
##   4 Lightning Bolt           (count, space, exact printed name)
##   4x Lightning Bolt          (Dojo-post style count)
##   SB: 3 Pyroblast            (.dec sideboard line -> [member sideboard])
## Plain .txt files additionally use the first blank line after a main-deck
## card as the sideboard boundary, unless explicit SB: lines are present.
##
## Card names must match the registry EXACTLY. Loading validates every
## line (main AND sideboard) and collects ALL problems instead of stopping
## at the first — a community deck file gets one complete error report.
## No deck-size/copy-limit rules are enforced here; that is deck
## VALIDATION (docs/ROADMAP.md) and layers on top.

## Deck name, from a "name:" / "// NAME:" header, the .dck first line (its
## `;` name line in a player's deck), or the filename as a fallback —
## never empty after a load.
var deck_name := ""
## Expanded maindeck ("4 X" contributes X four times), registry-validated.
var cards: Array[String] = []
## Expanded sideboard (SB: lines). Parsed and validated for round-trip
## fidelity, and — since `Side&board between duels` landed — actually
## PLAYED: `MatchScreen`'s Sideboard window swaps between this and the
## maindeck between the duels of a best-of-N match. The engine still has
## no in-duel sideboarding, so a single duel ignores it.
var sideboard: Array[String] = []
## Human-readable problems; empty = the deck loaded cleanly.
var errors: Array[String] = []
## THE DECK'S PROXIES ([ProxyCard]) — the distinct names in [member cards]
## and [member sideboard] that the registry does not know, in the order
## the file first named them. Only a LENIENT load can fill it: under
## `strict` the very same names become [member errors] and never reach
## either pile, which is the floor the whole proxy boundary stands on
## (ProxyCard's class doc, rule 3).
##
## It is a REPORT, not a second copy: the names are still in [member cards]
## with their counts, so an importer folds the list exactly as it folds any
## other, and this says which of them the player will have to replace.
var proxies: Array[String] = []
## Optional gameplay packs declared by this project's `.deck` format.
## These are comments to older builds and other deck readers, so adding the
## metadata never changes the name-based card lines.
var required_packs: Array[String] = []
## Preferred artwork per name; ignored by game rules and older readers.
var printings: Dictionary = {}

const REQUIRED_PACK_PREFIX := "# requires-pack:"

## The most copies one count line may ask for (bug pass 2026-10-03). No
## deck holds more than 500 cards — `@TOOMANYCARDS`, *"Decks are limited to
## 200 unique cards / 500 total cards"*, which the Deck Builder keeps as
## `DeckModel.MAX_TOTAL` (game/, so not nameable from here) — so a bigger
## count is a broken line, not a deck. Without the cap `5000000 Forest`
## loaded five million copies and a 20-digit count, clamped to INT64_MAX by
## to_int(), expanded forever: one pasted line froze the setup screen and
## the Deck Builder's import.
const MAX_COUNT := 500

## The most cards one list may hold, both piles together (hunt 2026-10-21).
## [constant MAX_COUNT] bounds a LINE and left the FILE open: a 44 KB list
## of 4,000 `500 Forest` lines expanded to two million names, and the
## setup screen, the Load list and the Deck Builder's import parse every
## file they show — a few megabytes of such lines would exhaust memory.
## A hundred thousand is far past any list a player keeps (a collection
## pasted as a card pool — 40,000 names, `test_c2_f_deck_deck_files` —
## still reads whole, and a deck over 500 cards loads for the Deck Builder
## to refuse and the player to trim) and parses in a blink. Past it the
## list stops growing and says so once ([member _overflowed]).
const MAX_TOTAL := 100000


## Load any supported format; .dck files route to the MicroProse parser.
## [param strict] = validate names against the card registry (gameplay
## needs implemented cards); false = format-only parsing — the converter
## handles historic decks full of not-yet-implemented cards, and the Deck
## Builder's IMPORT reads those same names as [member proxies].
static func load_file(path: String, strict := true) -> DeckList:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var deck := DeckList.new()
		deck.errors.append("cannot open '%s'" % path)
		return deck
	return from_text(file.get_as_text(), path, strict)


## [method load_file] for text already in hand: the format is still the
## file's, read off [param path]'s extension, and the name falls back to
## its stem. For a caller that has the file open for another reason — the
## battle setup screen reads each deck once for its heading AND its cards
## (2026-10-01) — so one read serves both.
static func from_text(text: String, path: String, strict := true) -> DeckList:
	var deck := DeckList.new()
	var base := path.get_file().get_basename()
	if path.get_extension().to_lower() == "dck":
		deck.parse_dck(text, base, strict)
	else:
		deck.parse(text, base, strict, path.get_extension().to_lower() == "txt")
	return deck


## The ORIGINAL MicroProse .dck format (as shipped in the 1997 game's
## Decks folder; format decoded from the real files + s30's converter):
##   line 1: deck name, e.g. "Lord of Fate (Bl/Wh, 4th Edition)"
##   maindeck lines:  .<numeric id> TAB <count> TAB <card name>
## A PLAYER'S deck — one the 1997 deck builder saved, as in its Playdeck
## folder — opens instead with EIGHT `;` lines (deckdll.c `save_deck`,
## 5249-5268 in the decompilation): the name, then description, author,
## e-mail, date, deck face, edition and comments, and a blank line. Its
## name is the first of them, whole; the other seven are not cards and are
## passed over (the bug campaign c12, h5-2: `Fire And Ice.dck` was refused
## with seven "not a .dck card line" errors, and our own export of
## "Sligh (1997 tribute)" came back as "Sligh"). Only a name line WITHOUT
## the `;` — the numbered opponent decks' — is cut at " (", where those
## put the colours and edition.
##   .vNone / .vBlack / .vBlue / .vGreen / .vRed / .vWhite lines open the
##   PER-OPPONENT-COLOR sideboard sections (the original AI's color-keyed
##   swaps). We fold them like s30 does: max count per name across all
##   sections -> [member sideboard]. Numeric ids are ignored on read
##   (names are authoritative; ids are re-emitted from cards/data/
##   dck_ids.txt when writing — see tools/deck_convert.gd).
func parse_dck(text: String, fallback_name := "deck", strict := true) -> void:
	deck_name = fallback_name
	if strict:
		CardRegistry.ensure_loaded()
	var in_sideboard := false
	var sideboard_max := {}
	var first_line := true
	# Did the file open with the deck builder's `;` lines (see above)?
	var player_deck := false
	var line_number := 0
	# A UTF-8 BOM from a Windows editor is not part of the deck's name (the
	# first line); [method parse] has always stripped it (2026-10-03).
	for raw_line in text.trim_prefix("\ufeff").split("\n"):
		line_number += 1
		var line := raw_line.strip_edges(false, true)   # keep leading tabs intact
		if first_line:
			first_line = false
			if line.strip_edges().begins_with(";"):
				player_deck = true
				var title := line.strip_edges().substr(1).strip_edges()
				if not title.is_empty():
					deck_name = title
			elif not line.strip_edges().is_empty():
				deck_name = line.split(" (")[0].strip_edges()
			continue
		if line.strip_edges().is_empty():
			continue
		if player_deck and line.strip_edges().begins_with(";"):
			continue
		if line.begins_with(".v"):
			in_sideboard = true
			continue
		var parts := line.split("\t")
		if parts.size() < 3 or not parts[0].begins_with("."):
			errors.append("line %d: not a .dck card line: '%s'" % [
				line_number, line.strip_edges()])
			continue
		# [QoL] Reproduced 2026-09-13: 2oops / 1.5 / 3x yielded
		# zero errors and six unwanted copies across the two piles.
		# to_int() alone accepts a numeric prefix, not a whole count.
		var count_token := parts[1].strip_edges()
		if not count_token.is_valid_int():
			errors.append("line %d: bad count '%s'" % [line_number, count_token])
			continue
		var count := _read_count(count_token)
		var card_name := parts[2].strip_edges()
		if count < 1:
			errors.append("line %d: bad count" % line_number)
			continue
		if count > MAX_COUNT:
			errors.append(_too_large(line_number))
			continue
		if not CardRegistry.has_card(card_name):
			if strict:
				errors.append("line %d: unknown/unimplemented card '%s'" % [
					line_number, card_name])
				continue
			_note_proxy(card_name)
		if in_sideboard:
			sideboard_max[card_name] = maxi(int(sideboard_max.get(card_name, 0)), count)
		elif _has_room(count, line_number):
			for _i in count:
				cards.append(card_name)
	for card_name in sideboard_max:
		if not _has_room(int(sideboard_max[card_name]), line_number):
			break
		for _i in sideboard_max[card_name]:
			sideboard.append(card_name)


## Parse the TEXT decklist formats — this project's .deck and the Apprentice
## .dec convention, which overlap enough to share one line loop (see the
## class doc for the accepted line shapes). Appends to [member cards] /
## [member sideboard] and records every bad line in [member errors] rather
## than stopping, so one pass reports the whole file.
## [param fallback_name] names the deck when no header line does;
## [param strict] validates card names against the CardRegistry.
## [param blank_sideboard] enables plain-text blank-line sections. Explicit
## SB: lines take precedence for the entire list; .deck/.dec keep their
## existing meaning of blank lines as formatting, not a section boundary.
## [param foreign] reads OTHER programs' exports as well (campaign
## 2026-10-12; the lenient import path only, see [method parse_foreign]):
## section lines (`Deck`, `Sideboard`, `SIDEBOARD:`, Forge's `[Main]`),
## a name line under Arena's `About` or Forge's `[metadata]`, and a
## printing after a card's name (`(M10) 146`, `[M10]`, `|M10`).
func parse(text: String, fallback_name := "deck", strict := true, blank_sideboard := false,
		foreign := false) -> void:
	deck_name = fallback_name
	if strict:
		CardRegistry.ensure_loaded()
	# [QoL] A UTF-8 BOM from a Windows text editor is not part of a card name.
	var lines := text.trim_prefix("\ufeff").split("\n")
	var infer_sideboard := blank_sideboard
	if infer_sideboard:
		for raw in lines:
			if raw.strip_edges().to_upper().begins_with("SB:") \
					or (foreign and _foreign_section(raw) == SECTION_SIDE):
				infer_sideboard = false
				break
	# What a foreign section line last opened; "" outside any.
	var section := ""
	var tail: RegEx = null
	var saw_main_card := false
	var in_sideboard := false
	var line_number := 0
	for raw_line in lines:
		line_number += 1
		var line := raw_line.strip_edges()
		if line.is_empty():
			if infer_sideboard and saw_main_card: in_sideboard = true
			continue
		if foreign:
			var opened := _foreign_section(line)
			if opened != "":
				section = opened
				if opened == SECTION_MAIN or opened == SECTION_SIDE:
					in_sideboard = opened == SECTION_SIDE
				continue
			if section == SECTION_ABOUT or section == SECTION_SKIP:
				# Arena's `Name X`, Forge's `Name=X`; the rest is not cards.
				var lowered := line.to_lower()
				if lowered.begins_with("name=") or (section == SECTION_ABOUT \
						and lowered.begins_with("name ")):
					var title := line.substr(5).strip_edges()
					if title != "":
						deck_name = title
				continue
		if DeckPrintings.read_comment(line, printings): continue
		if line.to_lower().begins_with(REQUIRED_PACK_PREFIX):
			var pack_id := line.substr(REQUIRED_PACK_PREFIX.length()).strip_edges()
			if pack_id != "" and not required_packs.has(pack_id):
				required_packs.append(pack_id)
			continue
		if line.begins_with("#"):
			continue
		if line.begins_with("//"):
			# .dec headers: "// NAME : Deck Name" names the deck.
			var body := line.trim_prefix("//").strip_edges()
			# A NAME field, not every comment starting with those letters:
			# "// Nameless idea: Also Changed" used to rename the deck.
			var colon := body.find(":")
			if colon != -1 and body.substr(0, colon).strip_edges().to_lower() == "name":
				deck_name = body.substr(colon + 1).strip_edges()
			continue
		if line.begins_with("name:"):
			deck_name = line.trim_prefix("name:").strip_edges()
			continue
		var into_sideboard := in_sideboard
		if line.to_upper().begins_with("SB:"):
			into_sideboard = true
			line = line.substr(3).strip_edges()
		var space := line.find(" ")
		var count_token := line.substr(0, space) if space > 0 else ""
		# Dojo-post style "4x" counts.
		if count_token.to_lower().ends_with("x") \
				and count_token.substr(0, count_token.length() - 1).is_valid_int():
			count_token = count_token.substr(0, count_token.length() - 1)
		if space < 1 or not count_token.is_valid_int():
			errors.append("line %d: expected 'COUNT Card Name', got '%s'" % [
				line_number, line])
			continue
		var count := _read_count(count_token)
		var card_name := line.substr(space + 1).strip_edges()
		if foreign:
			if tail == null:
				tail = _printing_tail()
			card_name = _foreign_name(card_name, tail)
		if count < 1:
			errors.append("line %d: count must be positive" % line_number)
			continue
		if count > MAX_COUNT:
			errors.append(_too_large(line_number))
			continue
		if not into_sideboard: saw_main_card = true
		if not CardRegistry.has_card(card_name):
			if strict:
				errors.append("line %d: unknown/unimplemented card '%s'" % [
					line_number, card_name])
				continue
			_note_proxy(card_name)
		if not _has_room(count, line_number):
			continue
		for _i in count:
			if into_sideboard:
				sideboard.append(card_name)
			else:
				cards.append(card_name)


## A count token that is_valid_int() already passed, read WITHOUT letting
## to_int() see more digits than a count could need: on an overflow it
## clamps to INT64_MAX and prints an ERROR. Anything over six significant
## digits reads as one past [constant MAX_COUNT] (or -1 when negative).
static func _read_count(token: String) -> int:
	if token.trim_prefix("+").trim_prefix("-").lstrip("0").length() > 6:
		return -1 if token.begins_with("-") else MAX_COUNT + 1
	return token.to_int()


## May [param count] more cards join the list without passing
## [constant MAX_TOTAL]? The first line that would pass it is reported, and
## no card line after it is taken — one reason, not thousands.
func _has_room(count: int, line_number: int) -> bool:
	if not _overflowed and cards.size() + sideboard.size() + count <= MAX_TOTAL:
		return true
	if not _overflowed:
		_overflowed = true
		errors.append("line %d: too many cards — a list holds at most %d, so the rest was not read" % [
			line_number, MAX_TOTAL])
	return false


## Did a line already pass [constant MAX_TOTAL]? See [method _has_room].
var _overflowed := false


static func _too_large(line_number: int) -> String:
	return "line %d: count too large (no deck holds more than %d cards)" % [
		line_number, MAX_COUNT]


## Record one name the registry does not know, ONCE. Both parsers call it
## on the lenient path and only there; a name that appears four times is
## one proxy the player has to replace, not four.
##
## A SET BESIDE THE LIST (campaign 2026-10-12): `proxies.has` per line made
## a lenient parse quadratic in unknown names — 20,000 of them took a
## second and a half, and the setup screen, the Load list and AutoDeck's
## card pool parse every file they open.
func _note_proxy(card_name: String) -> void:
	if not _proxy_seen.has(card_name):
		_proxy_seen[card_name] = true
		proxies.append(card_name)


## [member proxies] as a set, for [method _note_proxy].
var _proxy_seen: Dictionary = {}


# --- campaign 2026-10-12 f-deck: other programs' exports (lenient only) ---

const SECTION_MAIN := "main"
const SECTION_SIDE := "side"
## Arena's `About` block: a `Name …` line, nothing to deal.
const SECTION_ABOUT := "about"
## A section that holds no card of a deck — Forge's `[metadata]` (its
## `Name=` line is read), a maybeboard, a Forge section for another game.
const SECTION_SKIP := "skip"


## LENIENT READING OF ANOTHER PROGRAM'S LIST — the paste box's and Import
## deck's door, which is where these arrive: MTG Arena's export (`Deck` /
## `Sideboard` headers, `4 Lightning Bolt (M10) 146`), Moxfield and MTGO
## text (`SIDEBOARD:`), Forge's `.dck` (`[metadata]` / `Name=` / `[Main]`,
## `4 Lightning Bolt|M10`). Each used to be refused whole, or read as
## proxies named "Lightning Bolt (M10) 146". Never [param strict]: a name
## the registry does not know is a proxy, as on every import. The strict
## loaders — a `.deck` the setup screen plays — are untouched.
func parse_foreign(text: String, fallback_name := "deck", blank_sideboard := true) -> void:
	parse(text, fallback_name, false, blank_sideboard, true)


## Is [param text] a Forge deck file? Its `[metadata]` or `[Main]` line
## says so — no other format this reads has a bracketed section line.
static func looks_like_forge(text: String) -> bool:
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges().to_lower()
		if line == "[metadata]" or line == "[main]":
			return true
	return false


## The section a foreign list's line opens, or "" for any other line.
static func _foreign_section(raw_line: String) -> String:
	var word := raw_line.strip_edges().to_lower()
	var bracketed := word.begins_with("[") and word.ends_with("]")
	if bracketed:
		word = word.substr(1, word.length() - 2).strip_edges()
	word = word.trim_suffix(":").strip_edges()
	match word:
		"deck", "main", "maindeck", "main deck", "mainboard", "commander":
			return SECTION_MAIN
		"sideboard", "side", "side board", "companion":
			return SECTION_SIDE
		"about":
			return SECTION_ABOUT
		"metadata", "maybeboard", "considering":
			return SECTION_SKIP
	# Forge's other sections ([Avatar], [Planes], [Schemes]) hold cards of
	# other games; an unknown bracketed line is never a card line.
	return SECTION_SKIP if bracketed else ""


## A card name as another program writes it, less the printing after it:
## `Lightning Bolt (M10) 146`, `Lightning Bolt (2X2) 117 *F*`,
## `Lightning Bolt [M10]`, `Lightning Bolt|M10|1`. A name the registry
## knows as written is left alone; no card is named like those tails.
static func _foreign_name(card_name: String, tail: RegEx) -> String:
	if CardRegistry.has_card(card_name):
		return card_name
	var bar := card_name.find("|")
	if bar > 0:
		return card_name.substr(0, bar).strip_edges()
	var found := tail.search(card_name) if tail != null else null
	if found != null:
		return found.get_string(1).strip_edges()
	return card_name


## The printing tail [method _foreign_name] strips, compiled once per parse.
static func _printing_tail() -> RegEx:
	return RegEx.create_from_string(
		"^(.+?)\\s+[\\(\\[][A-Za-z0-9]{2,6}[\\)\\]](\\s+[A-Za-z0-9\\-]+)?(\\s+\\*[A-Za-z]+\\*)?$")


func _to_string() -> String:
	if sideboard.is_empty():
		return "%s (%d cards)" % [deck_name, cards.size()]
	return "%s (%d + %d sideboard)" % [deck_name, cards.size(), sideboard.size()]
