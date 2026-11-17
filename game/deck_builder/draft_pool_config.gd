class_name DraftPoolConfig
extends RefCounted
## [QoL] Remembered eligibility and fresh, machine-entropy sealed-style deals.
## Artwork archives do not enable unimplemented cards. No duel RNG is touched.

const SETTING := "draft_pool_cards"
const OPTIONS := "draft_options"


## The remembered eligible cards that are in play and on a sheet, once
## each, sorted. LINEAR (whole-game campaign 2026-10): the draft setup asks
## this on every spin-box step and keystroke, and the de-duplication was an
## `Array.has` per entry — ~56 ms of a 3,093-card pool on every ask. The
## whole library is only listed when nothing is remembered.
static func selected() -> Array[String]:
	CardRegistry.ensure_loaded()
	var out: Array[String] = []
	var saved: Variant = Settings.get_value(SETTING, []) if Settings.has_value(SETTING) \
		else CardRegistry.all_names()
	if saved is Array or saved is PackedStringArray:
		var seen := {}
		for entry in saved:
			if entry is String and not seen.has(entry):
				seen[entry] = true
				if CardRegistry.has_card(entry) and SealedPool.SLOT_ORDER.has(SealedPool.slot_of(entry)):
					out.append(entry)
	out.sort()
	return out


static func library(names: Array[String]) -> Array:
	var cards: Array = []
	for card_name in names:
		if CardRegistry.has_card(card_name):
			cards.append(CardRegistry.get_card(card_name))
	return cards


static func defaults() -> Dictionary:
	return {"boosters": 3, "starters": 1, "free_lands": 0, "extras": 0, "minutes": 20}


## [QoL] Community boosters ([constant DraftRecipe.COMMUNITY_OPTION]) are
## optional, 0 when absent, and need community cards in the pool; a short
## community sheet never refuses ([method SealedPool.community_booster]).
static func validate(options: Dictionary, names: Array[String]) -> String:
	var limits := {"boosters": 12, "starters": 12, "free_lands": 30, "extras": 60, "minutes": 1440}
	if options.has(DraftRecipe.COMMUNITY_OPTION):
		limits[DraftRecipe.COMMUNITY_OPTION] = DraftRecipe.MOST_COMMUNITY_BOOSTERS
	for key in limits:
		var value: Variant = options.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) \
				or float(value) != floor(float(value)) or value < (1 if key == "minutes" else 0) or value > limits[key]:
			return "Choose valid pack counts and a time limit between 1 and 1440 minutes."
	if names.is_empty():
		return "Choose at least one card in Card pool."
	# The bounds a recipe records the pool within ([method DraftRecipe.deal]
	# refuses past them): its eligible cards, and its size — the names once,
	# and the community ones again for community boosters — with room for
	# the rest of the record. Said here, not as a failed deal.
	if names.size() > DraftRecipe.MAX_ELIGIBLE:
		return "Card pool holds %d cards; a draft deals from at most %d. Leave some out in Card pool." % [
			names.size(), DraftRecipe.MAX_ELIGIBLE]
	var community := community_boosters(options)
	if int(options.boosters) + int(options.starters) + int(options.free_lands) + int(options.extras) + community == 0:
		return "Add a booster, starter pack, extra land or random card."
	var recorded := JSON.stringify(names).to_utf8_buffer().size() + 1024
	if community > 0:
		var community_sheets := SealedPool.community_sheets(names)
		if SealedPool.community_count(community_sheets) == 0:
			return "Community boosters need community cards in Card pool."
		recorded += JSON.stringify(community_sheets).to_utf8_buffer().size()
	if recorded > DraftRecipe.MAX_BYTES / 2:
		return "Card pool is too large to record with the draft. Leave some cards out in Card pool."
	var sheets := SealedPool.sheets(library(names))
	for shape in [[int(options.boosters), SealedPool.BOOSTER], [int(options.starters), SealedPool.STARTER]]:
		if shape[0] == 0:
			continue
		for slot in SealedPool.SLOT_ORDER:
			var need := 1 if slot == "land" else int(shape[1].get(slot, 0))
			if sheets[slot].size() < need:
				return "Card pool needs at least %d different %s cards for these packs (currently %d)." % [need, slot, sheets[slot].size()]
	if int(options.free_lands) > 0:
		for land in SealedPool.LAND_NAMES:
			if not names.has(land):
				return "Extra lands require all five basic lands in Card pool; enable %s or set extra lands to zero." % land
	if int(options.extras) > names.size():
		return "Random extras draw without duplicates: choose at least %d eligible cards." % int(options.extras)
	return ""


## The community boosters [param options] ask for; 0 when they name none.
static func community_boosters(options: Dictionary) -> int:
	var value: Variant = options.get(DraftRecipe.COMMUNITY_OPTION, 0)
	return int(value) if value is int or value is float else 0


## Whether [param names] hold a community card — the setup's Community
## boosters row shows only then.
static func has_community(names: Array[String]) -> bool:
	for card_name in CardRegistry.community_names():
		if names.has(card_name):
			return true
	return false


static func deal(options: Dictionary, names: Array[String]) -> SealedPool:
	return DraftRecipe.deal(options, names)
