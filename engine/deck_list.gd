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
##
## Card names must match the registry EXACTLY. Loading validates every
## line (main AND sideboard) and collects ALL problems instead of stopping
## at the first — a community deck file gets one complete error report.
## No deck-size/copy-limit rules are enforced here; that is deck
## VALIDATION (docs/ROADMAP.md) and layers on top.

## Deck name, from a "name:" / "// NAME:" header, the .dck first line, or
## the filename as a fallback — never empty after a load.
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


## Load any supported format; .dck files route to the MicroProse parser.
## [param strict] = validate names against the card registry (gameplay
## needs implemented cards); false = format-only parsing — the converter
## handles historic decks full of not-yet-implemented cards, and the Deck
## Builder's IMPORT reads those same names as [member proxies].
static func load_file(path: String, strict := true) -> DeckList:
	var deck := DeckList.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		deck.errors.append("cannot open '%s'" % path)
		return deck
	var base := path.get_file().get_basename()
	if path.get_extension().to_lower() == "dck":
		deck.parse_dck(file.get_as_text(), base, strict)
	else:
		deck.parse(file.get_as_text(), base, strict)
	return deck


## The ORIGINAL MicroProse .dck format (as shipped in the 1997 game's
## Decks folder; format decoded from the real files + s30's converter):
##   line 1: deck name, e.g. "Lord of Fate (Bl/Wh, 4th Edition)"
##   maindeck lines:  .<numeric id> TAB <count> TAB <card name>
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
	var line_number := 0
	for raw_line in text.split("\n"):
		line_number += 1
		var line := raw_line.strip_edges(false, true)   # keep leading tabs intact
		if first_line:
			first_line = false
			if not line.strip_edges().is_empty():
				deck_name = line.split(" (")[0].strip_edges()
			continue
		if line.strip_edges().is_empty():
			continue
		if line.begins_with(".v"):
			in_sideboard = true
			continue
		var parts := line.split("\t")
		if parts.size() < 3 or not parts[0].begins_with("."):
			errors.append("line %d: not a .dck card line: '%s'" % [
				line_number, line.strip_edges()])
			continue
		var count := parts[1].strip_edges().to_int()
		var card_name := parts[2].strip_edges()
		if count < 1:
			errors.append("line %d: bad count" % line_number)
			continue
		if not CardRegistry.has_card(card_name):
			if strict:
				errors.append("line %d: unknown/unimplemented card '%s'" % [
					line_number, card_name])
				continue
			_note_proxy(card_name)
		if in_sideboard:
			sideboard_max[card_name] = maxi(int(sideboard_max.get(card_name, 0)), count)
		else:
			for _i in count:
				cards.append(card_name)
	for card_name in sideboard_max:
		for _i in sideboard_max[card_name]:
			sideboard.append(card_name)


## Parse the TEXT decklist formats — this project's .deck and the Apprentice
## .dec convention, which overlap enough to share one line loop (see the
## class doc for the accepted line shapes). Appends to [member cards] /
## [member sideboard] and records every bad line in [member errors] rather
## than stopping, so one pass reports the whole file.
## [param fallback_name] names the deck when no header line does;
## [param strict] validates card names against the CardRegistry.
func parse(text: String, fallback_name := "deck", strict := true) -> void:
	deck_name = fallback_name
	if strict:
		CardRegistry.ensure_loaded()
	var line_number := 0
	for raw_line in text.split("\n"):
		line_number += 1
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("//"):
			# .dec headers: "// NAME : Deck Name" names the deck.
			var body := line.trim_prefix("//").strip_edges()
			if body.to_lower().begins_with("name"):
				var colon := body.find(":")
				if colon != -1:
					deck_name = body.substr(colon + 1).strip_edges()
			continue
		if line.begins_with("name:"):
			deck_name = line.trim_prefix("name:").strip_edges()
			continue
		var into_sideboard := false
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
		var count := count_token.to_int()
		var card_name := line.substr(space + 1).strip_edges()
		if count < 1:
			errors.append("line %d: count must be positive" % line_number)
			continue
		if not CardRegistry.has_card(card_name):
			if strict:
				errors.append("line %d: unknown/unimplemented card '%s'" % [
					line_number, card_name])
				continue
			_note_proxy(card_name)
		for _i in count:
			if into_sideboard:
				sideboard.append(card_name)
			else:
				cards.append(card_name)


## Record one name the registry does not know, ONCE. Both parsers call it
## on the lenient path and only there; a name that appears four times is
## one proxy the player has to replace, not four.
func _note_proxy(card_name: String) -> void:
	if not proxies.has(card_name):
		proxies.append(card_name)


func _to_string() -> String:
	if sideboard.is_empty():
		return "%s (%d cards)" % [deck_name, cards.size()]
	return "%s (%d + %d sideboard)" % [deck_name, cards.size(), sideboard.size()]
