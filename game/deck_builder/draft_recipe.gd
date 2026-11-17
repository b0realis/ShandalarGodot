class_name DraftRecipe
extends RefCounted
## [QoL] Self-contained, versioned draft replay. Hashes are commitments only
## when a judge retains one before building; they are not signatures.
## V1 is frozen: SHA-256 counter words + rejection sampling + partial Fisher-Yates.
## [QoL] COMMUNITY BOOSTERS ([method SealedPool.community_booster]) are an
## optional extension of v1: the option [constant COMMUNITY_OPTION] and the
## recipe's own `community` sheets come together or not at all, and only a
## recipe that holds them hashes them, so a recipe without them — every
## recipe saved before them — reads, deals and fingerprints as it always did.

const ALGORITHM := "sha256-counter-fisher-yates-v1"
const PREFIX := "# draft-recipe: "
const MAX_BYTES := 524288
## [QoL] 8192 since community cards (was 4096): every pack on and a few
## hundred community cards passed 4096. Only a bound on what a recipe may
## hold, so every recipe made under 4096 reads as before; the byte bound
## ([constant MAX_BYTES]) still holds the recipe small.
const MAX_ELIGIBLE := 8192
const SLOTS := ["rare", "uncommon", "common", "land"]
const OPTION_KEYS := ["boosters", "starters", "free_lands", "extras", "minutes"]
# Frozen independently of future UI/dealer defaults.
const BOOSTER := {"rare": 1, "uncommon": 3, "common": 10, "land": 1}
const STARTER := {"rare": 3, "uncommon": 9, "common": 26, "land": 22}
const LANDS := ["Plains", "Island", "Swamp", "Mountain", "Forest"]
## The optional option key, absent when a recipe has no community boosters.
const COMMUNITY_OPTION := "community_boosters"
## The community sheets a recipe with that option carries.
const COMMUNITY_TIERS := ["mythic", "rare", "uncommon", "common"]
const MOST_COMMUNITY_BOOSTERS := 12
var _seed := ""
var _counter := 0


static func deal(options: Dictionary, names: Array[String], seed_hex := "") -> SealedPool:
	if DraftPoolConfig.validate(options, names) != "": return null
	if seed_hex.is_empty(): seed_hex = Crypto.new().generate_random_bytes(32).hex_encode()
	if not digest(seed_hex): return null
	var recipe := _unsealed(options, names, seed_hex)
	if _shape_refusal(recipe) != "": return null
	var pool := DraftRecipe.new()._deal(recipe)
	recipe.pool_sha256 = pack_hash(pool.packs)
	recipe.fingerprint = fingerprint(recipe)
	pool.draft_recipe = recipe
	return pool


## The recipe [param options] and [param names] make, before its pool is
## dealt and hashed (both digests zero).
static func _unsealed(options: Dictionary, names: Array[String], seed_hex: String) -> Dictionary:
	var chosen := options.duplicate()
	# No community boosters: the key is left out, and the recipe is v1's own.
	if chosen.has(COMMUNITY_OPTION) and int(chosen[COMMUNITY_OPTION]) == 0:
		chosen.erase(COMMUNITY_OPTION)
	var recipe := {"schema": 1, "algorithm": ALGORITHM, "seed": seed_hex,
		"options": chosen, "sheets": SealedPool.sheets(DraftPoolConfig.library(names)),
		"pool_sha256": "0".repeat(64), "fingerprint": "0".repeat(64)}
	if chosen.has(COMMUNITY_OPTION):
		recipe["community"] = SealedPool.community_sheets(names)
	return recipe


## Why [method deal] would refuse [param options] over [param names]
## although [method DraftPoolConfig.validate] passed them ("" when it
## would not) — the recipe's own bounds, said for the setup's status line.
## Costly: the setup asks it only after a deal came back empty.
static func refusal(options: Dictionary, names: Array[String]) -> String:
	var why := DraftPoolConfig.validate(options, names)
	if why != "": return why
	return _shape_refusal(_unsealed(options, names, "0".repeat(64)))


static func reconstruct(value: Variant) -> Dictionary:
	var refusal := _shape_refusal(value)
	if refusal != "": return {"ok": false, "message": refusal}
	if fingerprint(value) != value.fingerprint:
		return {"ok": false, "message": "Draft recipe fingerprint does not match its contents."}
	var pool := DraftRecipe.new()._deal(value)
	if pack_hash(pool.packs) != value.pool_sha256:
		return {"ok": false, "message": "The seed does not reconstruct the recorded pool."}
	pool.draft_recipe = value.duplicate(true)
	return {"ok": true, "pool": pool, "fingerprint": String(value.fingerprint)}


static func _shape_refusal(value: Variant) -> String:
	var community: bool = value is Dictionary and value.has("community")
	var recipe_keys := ["schema", "algorithm", "seed", "options", "sheets", "pool_sha256", "fingerprint"]
	if community: recipe_keys.append("community")
	if not value is Dictionary or not _keys(value, recipe_keys) \
			or not (value.schema is int or value.schema is float) or value.schema != 1 \
			or not value.algorithm is String or value.algorithm != ALGORITHM:
		return "Invalid or unsupported draft recipe."
	if not digest(value.seed) or not digest(value.pool_sha256) or not digest(value.fingerprint):
		return "Invalid draft seed or SHA-256 fingerprint."
	# The community option and the community sheets come together.
	var option_keys := OPTION_KEYS.duplicate()
	if community: option_keys.append(COMMUNITY_OPTION)
	if not value.options is Dictionary or not _keys(value.options, option_keys): return "Invalid draft options."
	var limits := [12, 12, 30, 60, 1440, MOST_COMMUNITY_BOOSTERS]
	for i in option_keys.size():
		var number: Variant = value.options[option_keys[i]]
		if not (number is int or number is float) or not is_finite(float(number)) \
				or float(number) != floor(float(number)) or number < (1 if i == 4 else 0) or number > limits[i]:
			return "Invalid draft pack count or time limit."
	if int(value.options.boosters) + int(value.options.starters) + int(value.options.free_lands) + int(value.options.extras) \
			+ community_boosters(value) == 0:
		return "The draft recipe deals no cards."
	if not value.sheets is Dictionary or not _keys(value.sheets, SLOTS): return "Invalid draft rarity sheets."
	var seen: Dictionary = {}
	for slot: String in SLOTS:
		var sheet: Variant = value.sheets[slot]
		if not sheet is Array or sheet.size() > MAX_ELIGIBLE: return "Draft rarity sheet is too large or invalid."
		var previous := ""
		for card_name in sheet:
			if not card_name is String or card_name.is_empty() or card_name.to_utf8_buffer().size() > 128 \
					or seen.has(card_name) or (previous != "" and card_name <= previous):
				return "Draft sheets must contain sorted, unique card names."
			for character in card_name:
				if character.unicode_at(0) < 32: return "Invalid card name in draft recipe."
			if (slot == "land") != LANDS.has(card_name): return "Invalid basic-land sheet."
			seen[card_name] = slot
			previous = card_name
		var need := 0
		if value.options.boosters > 0: need = int(BOOSTER[slot])
		if value.options.starters > 0: need = maxi(need, int(STARTER[slot]))
		if slot == "land" and need > 0: need = 1
		if sheet.size() < need: return "Draft recipe has an insufficient %s sheet." % slot
	if seen.size() > MAX_ELIGIBLE or seen.size() < int(value.options.extras): return "Invalid eligible-card count."
	if value.options.free_lands > 0 and value.sheets.land.size() != 5: return "Extra lands require all five basics."
	if community:
		var refusal := _community_refusal(value, seen)
		if refusal != "": return refusal
	if JSON.stringify(value).to_utf8_buffer().size() > MAX_BYTES / 2: return "Draft recipe is too large."
	return ""


## The community sheets: the four tiers, each sorted and unique, every
## name on the main sheet its rarity deals from (a mythic on the rare
## sheet; [param seen] is name -> main sheet); never empty with boosters to
## deal. A name this game plays must be one of its community cards — a
## game card is not — while a name not in play here (a community card
## this machine lacks) is allowed: the recipe replays without it.
static func _community_refusal(value: Dictionary, seen: Dictionary) -> String:
	if not value.community is Dictionary or not _keys(value.community, COMMUNITY_TIERS):
		return "Invalid community sheets."
	var placed: Dictionary = {}
	for tier: String in COMMUNITY_TIERS:
		var sheet: Variant = value.community[tier]
		if not sheet is Array or sheet.size() > MAX_ELIGIBLE: return "Invalid community sheets."
		var previous := ""
		for card_name in sheet:
			if not card_name is String or placed.has(card_name) or (previous != "" and card_name <= previous) \
					or String(seen.get(card_name, "")) != ("rare" if tier == "mythic" else tier):
				return "Community sheets must hold sorted, unique cards of the draft's own sheets."
			if CardRegistry.has_card(card_name) and not CardRegistry.has_community(card_name):
				return "Community sheets may hold community cards only."
			placed[card_name] = true
			previous = card_name
	if community_boosters(value) > 0 and placed.is_empty(): return "Community boosters need community cards."
	return ""


## The community boosters [param recipe] deals; 0 for a recipe without them.
static func community_boosters(recipe: Dictionary) -> int:
	var options: Variant = recipe.get("options")
	return int(options.get(COMMUNITY_OPTION, 0)) if options is Dictionary else 0


static func _keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size(): return false
	for key in keys:
		if not value.has(key): return false
	return true


static func digest(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for character in value:
		if not "0123456789abcdef".contains(character): return false
	return true


## Canonical hash payload uses arrays and integer options, so a JSON float
## round-trip, dictionary key order or pretty-printing cannot change the hash.
static func fingerprint(recipe: Dictionary) -> String:
	var options: Array = []
	var sheets: Array = []
	for key in OPTION_KEYS: options.append(int(recipe.options[key]))
	for slot in SLOTS: sheets.append(recipe.sheets[slot])
	var payload := [1, ALGORITHM, recipe.seed, options, sheets, recipe.pool_sha256]
	# Only a recipe that holds community boosters hashes them, so every
	# other recipe keeps the fingerprint it always had.
	if recipe.options.has(COMMUNITY_OPTION) or recipe.has("community"):
		var community: Array = []
		for tier in COMMUNITY_TIERS: community.append(recipe.get("community", {}).get(tier, []))
		payload.append([int(recipe.options.get(COMMUNITY_OPTION, 0)), community])
	return JSON.stringify(payload).sha256_text()


static func pack_hash(packs: Array) -> String:
	var rows: Array = []
	for pack in packs: rows.append([pack.title, pack.cards])
	return JSON.stringify(rows).sha256_text()


func _below(bound: int) -> int:
	var limit := 4294967296 - (4294967296 % bound)
	while true:
		var bytes := ("Shandalar draft v1\n" + _seed + "\n" + str(_counter)).sha256_buffer()
		_counter += 1
		var word := bytes.decode_u32(0) # Explicit little-endian unsigned word.
		if word < limit: return word % bound
	return 0


func _draw(sheet: Array, wanted: int) -> Array[String]:
	var available := sheet.duplicate()
	var result: Array[String] = []
	for i in wanted:
		var j := i + _below(available.size() - i)
		var item: String = available[i]
		available[i] = available[j]
		available[j] = item
		result.append(available[i])
	result.sort()
	return result


func _deal(recipe: Dictionary) -> SealedPool:
	_seed = recipe.seed
	_counter = 0
	var pool := SealedPool.new()
	for key in ["boosters", "starters", "free_lands", "extras"]: pool.set(key, int(recipe.options[key]))
	pool.community_boosters = community_boosters(recipe)
	for i in pool.starters: _pack(pool, "Starter Pack %d" % (i + 1), STARTER, recipe.sheets)
	for i in pool.boosters: _pack(pool, "Booster Pack %d" % (i + 1), BOOSTER, recipe.sheets)
	for i in pool.community_boosters:
		pool._keep("Community Booster %d" % (i + 1), SealedPool.community_booster(recipe.community, recipe.sheets.land, _below, BOOSTER))
	if pool.free_lands > 0:
		var lands: Array[String] = []
		for land in LANDS:
			for _i in pool.free_lands: lands.append(land)
		pool._keep("Free Lands", lands)
	if pool.extras > 0:
		var all_cards: Array = []
		for slot in SLOTS: all_cards.append_array(recipe.sheets[slot])
		pool._keep("Random Cards", _draw(all_cards, pool.extras))
	return pool


func _pack(pool: SealedPool, title: String, shape: Dictionary, sheets: Dictionary) -> void:
	var cards: Array[String] = []
	for slot in SLOTS:
		if slot != "land": cards.append_array(_draw(sheets[slot], int(shape[slot])))
		else:
			var lands: Array[String] = []
			for _i in int(shape.land): lands.append(sheets.land[_below(sheets.land.size())])
			lands.sort()
			cards.append_array(lands)
	pool._keep(title, cards)


static func comments(recipe: Dictionary) -> String:
	var community := community_boosters(recipe)
	return "# draft-seed: %s\n# draft-packs: %d boosters, %d starters, %d extra lands per type, %d random extras, %d minutes%s\n# draft-fingerprint: %s\n%s%s" % [
		recipe.seed, int(recipe.options.boosters), int(recipe.options.starters), int(recipe.options.free_lands),
		int(recipe.options.extras), int(recipe.options.minutes),
		", %d community boosters" % community if community > 0 else "", recipe.fingerprint, PREFIX, JSON.stringify(recipe)]


static func from_text(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_BYTES: return {"ok": false, "message": "Draft deck file is too large."}
	var records: Array[String] = []
	for line in text.split("\n"):
		if line.strip_edges().begins_with(PREFIX.strip_edges()):
			records.append(line.strip_edges().trim_prefix(PREFIX.strip_edges()).strip_edges())
	if records.size() != 1: return {"ok": false, "message": "The deck must contain exactly one draft recipe comment. Older drafts need their saved pool file."}
	var json := JSON.new()
	if json.parse(records[0]) != OK: return {"ok": false, "message": "Malformed draft recipe comment."}
	var refusal := _shape_refusal(json.data)
	if refusal != "": return {"ok": false, "message": refusal}
	return {"ok": true, "recipe": json.data}
