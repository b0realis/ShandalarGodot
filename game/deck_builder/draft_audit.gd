class_name DraftAudit
extends RefCounted
## [QoL] Bounded, read-only deck membership checks against a saved dealt pool.
## A local receipt is evidence to compare, not a signature or trusted referee.

const MAX_CARDS := 1110 # 12 boosters + 12 starters + 150 lands + 60 extras.
## [QoL] With community boosters on top (12 more boosters of 15): the
## largest pool and the most packs a pool file or deck may hold.
const MOST_CARDS := MAX_CARDS + DraftRecipe.MOST_COMMUNITY_BOOSTERS * 15
const MOST_PACKS := 26 + DraftRecipe.MOST_COMMUNITY_BOOSTERS
const POOL_BYTES := 1048576
const DECK_BYTES := DraftRecipe.MAX_BYTES
const TRUST_NOTE := "Checks pool membership, not deck-format legality or identity. The organiser must retain the original pool or fingerprint before building. A recipe or hash supplied afterwards can be replaced by the player."


static func check_files(pool_path: String, deck_path: String, expected_fingerprint := "") -> Dictionary:
	var pool := _read(pool_path, POOL_BYTES)
	if not pool.ok: return pool
	var deck := _read(deck_path, DECK_BYTES)
	if not deck.ok: return deck
	var json := JSON.new()
	if json.parse(pool.text) != OK: return _failure("Invalid JSON in draft pool file.")
	return check(json.data, deck.text, expected_fingerprint)


static func reconstruct_file(deck_path: String, expected_fingerprint := "") -> Dictionary:
	var deck := _read(deck_path, DECK_BYTES)
	if not deck.ok: return deck
	return reconstruct_text(deck.text, expected_fingerprint)


static func reconstruct_text(text: String, expected_fingerprint := "") -> Dictionary:
	var embedded := DraftRecipe.from_text(text)
	if not embedded.ok: return embedded
	var replay := DraftRecipe.reconstruct(embedded.recipe)
	if not replay.ok: return replay
	var receipt := {"schema": 1, "counts": replay.pool.counts, "packs": replay.pool.packs, "recipe": embedded.recipe}
	var result := check(receipt, text, expected_fingerprint)
	if not result.ok: return result
	result["receipt"] = receipt
	var options: Dictionary = embedded.recipe.options
	var community := DraftRecipe.community_boosters(embedded.recipe)
	result.message += "\n\nReconstructed from seed: %s\n%d boosters · %d starters%s · %d extra lands per type · %d random extras · %d minutes\nFingerprint: %s" % [
		embedded.recipe.seed, int(options.boosters), int(options.starters),
		" · %d community boosters" % community if community > 0 else "",
		int(options.free_lands), int(options.extras), int(options.minutes), embedded.recipe.fingerprint]
	result.message += "\nMatches the judge's retained fingerprint." if expected_fingerprint != "" else "\nUnanchored replay: no pre-draft fingerprint was supplied."
	for pack in replay.pool.packs:
		result.message += "\n\n%s (%d cards)\n%s" % [pack.title, pack.cards.size(), ", ".join(pack.cards)]
	return result


static func _read(path: String, limit: int) -> Dictionary:
	if path.is_empty(): return _failure("Choose both a saved pool and a deck.")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return _failure("Cannot read " + path.get_file() + ".")
	if file.get_length() > limit:
		file.close()
		return _failure("File is too large for a draft check: " + path.get_file())
	var text := file.get_as_text()
	var error := file.get_error()
	file.close()
	if error != OK: return _failure("Could not finish reading " + path.get_file() + ".")
	return {"ok": true, "text": text}


static func check(receipt: Variant, deck_text: String, expected_fingerprint := "") -> Dictionary:
	var refusal := pool_refusal(receipt)
	if refusal != "": return _failure(refusal)
	if deck_text.to_utf8_buffer().size() > DECK_BYTES:
		return _failure("Deck file is too large for a draft check.")
	if receipt.has("recipe"):
		var replay := DraftRecipe.reconstruct(receipt.recipe)
		if not replay.ok: return replay
		if DraftRecipe.pack_hash(receipt.packs) != receipt.recipe.pool_sha256:
			return _failure("Saved pack contents do not match the reconstructed recipe.")
		var embedded := DraftRecipe.from_text(deck_text)
		if not embedded.ok: return embedded
		if DraftRecipe.fingerprint(embedded.recipe) != receipt.recipe.fingerprint \
				or embedded.recipe.fingerprint != receipt.recipe.fingerprint:
			return _failure("Deck recipe does not match the original pool's fingerprint.")
		if expected_fingerprint != "" and (not DraftRecipe.digest(expected_fingerprint) or expected_fingerprint != receipt.recipe.fingerprint):
			return _failure("Draft fingerprint does not match the judge's retained fingerprint.")
	elif expected_fingerprint != "":
		return _failure("This older pool has no reconstruction fingerprint.")
	# Bound expanded counts BEFORE invoking the shared text-deck parser.
	var total := 0
	for raw in deck_text.split("\n"):
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#") or line.begins_with("//") or line.begins_with("name:"):
			continue
		if line.to_upper().begins_with("SB:"): line = line.substr(3).strip_edges()
		var space := line.find(" ")
		var token := line.substr(0, space) if space > 0 else ""
		if token.to_lower().ends_with("x"): token = token.left(-1)
		if not token.is_valid_int() or token.length() > 4 or token.to_int() < 1:
			return _failure("Invalid deck card count. Choose a native .deck or .dec text file.")
		total += token.to_int()
		if total > MOST_CARDS: return _failure("Deck and sideboard exceed the largest possible draft pool.")
	var deck := DeckList.new()
	deck.parse(deck_text)
	if not deck.errors.is_empty():
		return _failure("Invalid deck: " + deck.errors[0])
	var used: Dictionary = {}
	for card_name in deck.cards + deck.sideboard:
		used[card_name] = int(used.get(card_name, 0)) + 1
	var problems: Array[String] = []
	for card_name in used:
		var allowed := int(receipt.counts.get(card_name, 0))
		if used[card_name] > allowed:
			problems.append("%s: %d in deck + sideboard; %d in pool." % [card_name, used[card_name], allowed])
	if not problems.is_empty(): return _failure("Outside the saved pool:\n" + "\n".join(problems))
	return {"ok": true, "message": "Pool membership matches: %d main-deck cards and %d sideboard cards.\nEvery card and copy is accounted for." % [deck.cards.size(), deck.sideboard.size()]}


static func pool_refusal(receipt: Variant) -> String:
	if not receipt is Dictionary or not _whole(receipt.get("schema"), 1) or receipt.schema != 1:
		return "Invalid or unsupported draft pool file."
	var counts: Variant = receipt.get("counts")
	var packs: Variant = receipt.get("packs")
	if not counts is Dictionary or counts.is_empty() or counts.size() > MOST_CARDS \
			or not packs is Array or packs.is_empty() or packs.size() > MOST_PACKS:
		return "Invalid pool counts or pack list."
	CardRegistry.ensure_loaded()
	var expected: Dictionary = {}
	var total := 0
	var absent: Array[String] = []
	for card_name in counts:
		if not card_name is String or not _whole(counts[card_name], MOST_CARDS):
			return "Pool contains an unknown card or an invalid quantity."
		if not CardRegistry.has_card(card_name):
			absent.append(String(card_name))
			continue
		expected[card_name] = int(counts[card_name])
		total += int(counts[card_name])
	if not absent.is_empty():
		return _absent_refusal(absent, receipt)
	if total > MOST_CARDS: return "Pool exceeds the largest supported draft."
	var actual: Dictionary = {}
	var dealt := 0
	for pack in packs:
		if not pack is Dictionary or not pack.get("title") is String or not pack.get("cards") is Array:
			return "Invalid pack contents in pool file."
		dealt += pack.cards.size()
		if dealt > MOST_CARDS: return "Pack contents exceed the largest supported draft."
		for card_name in pack.cards:
			if not card_name is String or not expected.has(card_name): return "Pack contents do not match pool counts."
			actual[card_name] = int(actual.get(card_name, 0)) + 1
	if actual != expected: return "Pack contents do not match pool counts."
	return ""


## A pool dealt with a card pack enabled is still a good pool on a machine
## that has the pack switched off; name the shelf it wants instead of
## calling the file corrupt (2026-09-17). The pack identities are trusted
## game data, so this reads correctly with the ZIP absent as well.
##
## [QoL] A NAME NO PACK EXPLAINS is listed itself — a community card a
## pool dealt (through any booster) is not here, or a name this game does
## not have — and it is never counted as the pack's. A name the recipe's
## community sheets hold is called a community card.
static func _absent_refusal(names: Array[String], receipt: Dictionary = {}) -> String:
	var community := _community_named(names, receipt.get("recipe"))
	var rest: Array[String] = []
	for card_name in names:
		if not community.has(card_name):
			rest.append(card_name)
	# One ask for the usual cases (no pack at all, or every name a pack's);
	# name by name only when packs are wanted, to find the names none explains.
	var pack_names: Array[String] = []
	var unknown: Array[String] = []
	if rest.is_empty() or CardPacks.packs_required_by(rest).is_empty():
		unknown = rest
	else:
		for card_name in rest:
			if CardPacks.packs_required_by([card_name] as Array[String]).is_empty():
				unknown.append(card_name)
			else:
				pack_names.append(card_name)
	var parts: Array[String] = []
	if not pack_names.is_empty():
		var labels: Array[String] = []
		for id in CardPacks.packs_required_by(pack_names):
			labels.append(CardPacks.label_for(id))
		parts.append(("This draft pool needs %s: %d of its card names are not in play here. "
			+ "Enable %s in Options > Card Packs and check again.") % [" and ".join(labels),
			pack_names.size(), "it" if labels.size() == 1 else "them"])
	if not community.is_empty():
		parts.append("%s community cards that are not here: %s." % [
			"It also needs" if not parts.is_empty() else "This draft pool needs", _listed(community)])
	if not unknown.is_empty():
		parts.append("%s unknown card names that are not in play here: %s." % [
			"It also has" if not parts.is_empty() else "Pool contains", _listed(unknown)])
	return " ".join(parts)


## [param names] sorted, the first ten of them and how many more.
static func _listed(names: Array[String]) -> String:
	var sorted: Array[String] = names.duplicate()
	sorted.sort()
	var shown := ", ".join(PackedStringArray(sorted.slice(0, 10)))
	return shown if sorted.size() <= 10 else "%s and %d more" % [shown, sorted.size() - 10]


## The names of [param names] that [param recipe]'s community sheets hold.
static func _community_named(names: Array[String], recipe: Variant) -> Array[String]:
	var out: Array[String] = []
	if not recipe is Dictionary or not recipe.get("community") is Dictionary:
		return out
	for tier in DraftRecipe.COMMUNITY_TIERS:
		var sheet: Variant = recipe.community.get(tier)
		if not sheet is Array:
			continue
		for card_name in names:
			if sheet.has(card_name) and not out.has(card_name):
				out.append(card_name)
	out.sort()
	return out


static func _whole(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) == floor(float(value)) and value >= 1 and value <= maximum


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}
