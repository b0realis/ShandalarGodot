extends GutTest
## [QoL] COMMUNITY BOOSTERS ([method SealedPool.community_booster]): community
## cards reach the sealed sheets like any set's cards (a mythic on the rare
## sheet), a community booster is fifteen cards of the community set alone
## but its basic land, a small set fills its short slots and repeats a card
## only when it is smaller than the pack, a recipe that holds community
## boosters reconstructs the identical pool, a recipe without them is the
## frozen v1 recipe it always was, and the setup's row hides without
## community cards.

const ROOT := "user://community_boosters_test"
const SEED := "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
const PREFIX := "Zyx "
const COMMUNITY := "Community Booster"

var _root := ""
var _art := {}
var _icon := {}
var _saved: Dictionary = {}
var _files: Array[String] = []


func before_all() -> void:
	var art := Image.create(510, 396, false, Image.FORMAT_RGBA8)
	art.fill(Color(0.2, 0.6, 0.3))
	_art = {"bytes": art.save_png_to_buffer(), "kind": "png"}
	var icon := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	icon.fill(Color(0.6, 0.3, 0.2))
	_icon = {"bytes": icon.save_png_to_buffer(), "kind": "png"}


func before_each() -> void:
	for key in [DraftPoolConfig.SETTING, DraftPoolConfig.OPTIONS, DeckBuilderScreen.EXTRAS_SETTING]:
		_saved[key] = Settings.get_value(key, 0) if Settings.has_value(key) else null
		Settings.clear_value(key)
	_root = ProjectSettings.globalize_path(ROOT)
	_wipe(_root)
	DirAccess.make_dir_recursive_absolute(_root)
	CommunityCards.folders_override = [_root]


func after_each() -> void:
	await get_tree().process_frame
	CommunityCards.folders_override = []
	CommunityCards.clear_draft()
	_wipe(_root)
	CommunityCards.refresh()
	for key in _saved:
		if _saved[key] == null: Settings.clear_value(key)
		else: Settings.set_value(key, _saved[key], false)
	for path in _files:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	_files.clear()


func _wipe(dir: String) -> void:
	if not dir.contains("community_boosters_test") or not DirAccess.dir_exists_absolute(dir):
		return
	var here := DirAccess.open(dir)
	here.include_hidden = true
	for sub in here.get_directories():
		_wipe(dir.path_join(sub))
	for name in here.get_files():
		DirAccess.remove_absolute(dir.path_join(name))
	DirAccess.remove_absolute(dir)


## A community set of [param sizes] (rarity -> how many), named
## "Zyx Mythic 1" and so on, written as zips and taken into the pool.
func _make_set(sizes: Dictionary) -> void:
	for rarity in sizes:
		for i in int(sizes[rarity]):
			var card_name := "%s%s %d" % [PREFIX, String(rarity).capitalize(), i + 1]
			var spec := {"format": CommunityCard.FORMAT, "version": 1, "name": card_name, "cost": "{G}",
				"types": ["creature"], "power": 1, "toughness": 1, "rarity": rarity,
				"artist": "A. Painter", "set_name": "Test set",
				"look": {"border": "white", "frame": "gold"}, "abilities": []}
			var path := _root.path_join("%s_%d.zip" % [rarity, i + 1])
			assert_eq(CommunityCards.write_zip(path, spec, _art, _icon), "", card_name)
	CommunityCards.refresh()


## Every name in play on a sheet, as the draft's Card pool offers them.
func _names(with_lands := true) -> Array[String]:
	var out: Array[String] = []
	for card_name in CardRegistry.all_names():
		if not with_lands and SealedPool.LAND_NAMES.has(card_name):
			continue
		if SealedPool.SLOT_ORDER.has(SealedPool.slot_of(card_name)):
			out.append(card_name)
	return out


func _options(community: int, boosters := 0, starters := 0, extras := 0) -> Dictionary:
	var options := DraftPoolConfig.defaults()
	options.boosters = boosters
	options.starters = starters
	options.extras = extras
	options[DraftRecipe.COMMUNITY_OPTION] = community
	return options


func _community_packs(pool: SealedPool) -> Array:
	return pool.packs.filter(func(pack: Dictionary) -> bool: return String(pack.title).begins_with(COMMUNITY))


func _tally(cards: Array) -> Dictionary:
	var out := {}
	for card_name in cards:
		out[card_name] = int(out.get(card_name, 0)) + 1
	return out


# ------------------------------------------- the existing path, mended --

func test_community_cards_reach_the_card_pool_and_its_sheets_a_mythic_as_a_rare() -> void:
	_make_set({"mythic": 1, "rare": 1, "uncommon": 1, "common": 1})
	assert_eq(SealedPool.slot_of("Zyx Mythic 1"), "rare", "a mythic is on the rare sheet")
	assert_eq(SealedPool.slot_of("Zyx Rare 1"), "rare")
	assert_eq(SealedPool.slot_of("Zyx Uncommon 1"), "uncommon")
	assert_eq(SealedPool.slot_of("Zyx Common 1"), "common")
	assert_eq(SealedPool.community_rarity("Zyx Mythic 1"), "mythic")
	var sheets := SealedPool.sheets(DraftPoolConfig.library(_names()))
	assert_true(sheets.rare.has("Zyx Mythic 1") and sheets.rare.has("Zyx Rare 1"))
	assert_true(sheets.common.has("Zyx Common 1"))
	var everything := DraftPoolConfig.selected()
	for card_name in ["Zyx Mythic 1", "Zyx Rare 1", "Zyx Uncommon 1", "Zyx Common 1"]:
		assert_true(everything.has(card_name), "%s is in the pool nothing narrowed" % card_name)
	Settings.set_value(DraftPoolConfig.SETTING, ["Zyx Mythic 1", "Mountain"], false)
	assert_eq(DraftPoolConfig.selected(), ["Mountain", "Zyx Mythic 1"] as Array[String],
		"a remembered mythic stays remembered")
	Settings.clear_value(DraftPoolConfig.SETTING)
	var chooser := DraftPoolDialog.new()
	add_child_autofree(chooser)
	assert_true(chooser.groups.has(CommunityCard.SET_CODE), "the Community cards set is offered")
	assert_eq(chooser.groups[CommunityCard.SET_CODE].get_text(0), "Community cards")
	assert_eq(chooser.groups[CommunityCard.SET_CODE].get_child_count(), 4, "the mythic among them")
	for card_name in ["Zyx Mythic 1", "Zyx Rare 1", "Zyx Uncommon 1", "Zyx Common 1"]:
		assert_true(chooser.selected_cards.has(card_name), "%s is checked" % card_name)
	# A plain booster deals the community cards like any set's.
	var picked: Array[String] = ["Zyx Mythic 1", "Zyx Rare 1", "Shivan Dragon", "Zyx Uncommon 1",
		"Counterspell", "Serra Angel", "Sol Ring", "Zyx Common 1", "Dark Ritual", "Disenchant",
		"Giant Growth", "Grizzly Bears", "Healing Salve", "Lightning Bolt", "Llanowar Elves",
		"Mons's Goblin Raiders", "Scryb Sprites", "Unholy Strength", "Forest"]
	assert_eq(DraftPoolConfig.validate(_options(0, 12), picked), "")
	var plain := DraftRecipe.deal(_options(0, 12), picked, SEED)
	assert_not_null(plain)
	if plain == null: return
	assert_true(plain.counts.has("Zyx Mythic 1"), "a mythic comes in a rare slot")
	assert_false(plain.draft_recipe.has("community"), "no community boosters, no community sheets")


# ------------------------------------------------- the booster's shape --

func test_a_community_booster_is_one_rare_three_uncommons_ten_commons_and_a_basic_land() -> void:
	_make_set({"mythic": 2, "rare": 6, "uncommon": 8, "common": 16})
	var names := _names()
	var community := SealedPool.community_sheets(names)
	assert_eq(SealedPool.community_count(community), 32)
	assert_eq(SealedPool.community_note(community, 5), "", "a whole set needs no note")
	var mythics := 0
	var rares := 0
	for seed_value in 4:
		var pool := DraftRecipe.deal(_options(12, 1), names, str(seed_value).sha256_text())
		assert_not_null(pool)
		if pool == null: return
		assert_eq(pool.total(), pool.card_total())
		assert_eq(pool.community_boosters, 12)
		var packs := _community_packs(pool)
		assert_eq(packs.size(), 12)
		for pack in packs:
			assert_eq(pack.cards.size(), 15)
			var slots := {"rare": 0, "uncommon": 0, "common": 0, "land": 0}
			for card_name: String in pack.cards:
				if SealedPool.LAND_NAMES.has(card_name):
					slots.land += 1
					continue
				assert_true(card_name.begins_with(PREFIX), "only community cards: %s" % card_name)
				var rarity := SealedPool.community_rarity(card_name)
				if rarity == "mythic": mythics += 1
				if rarity == "rare": rares += 1
				slots["rare" if rarity == "mythic" else rarity] += 1
			assert_eq(slots, {"rare": 1, "uncommon": 3, "common": 10, "land": 1})
			assert_eq(_tally(pack.cards).size(), 15, "no repeat in a whole set")
	assert_gt(mythics, 0, "a mythic takes the rare slot now and then")
	assert_gt(rares, mythics * 3, "about one time in eight")
	# The sealed window's own dealer opens the same shape from its seed.
	var sealed := SealedPool.new()
	sealed.boosters = 0
	sealed.starters = 0
	sealed.community_boosters = 2
	sealed.deal(DraftPoolConfig.library(names), 1997)
	assert_eq(sealed.total(), 30)
	assert_eq(_community_packs(sealed).size(), 2)
	assert_eq(sealed.slot_counts(), {"rare": 2, "uncommon": 6, "common": 20, "land": 2})


# ---------------------------------------------- a small community set --

func test_a_short_sheet_takes_other_community_cards_and_never_refuses() -> void:
	# No rare at all and two uncommons, but sixteen cards: enough for a pack.
	_make_set({"uncommon": 2, "common": 14})
	var names := _names()
	var community := SealedPool.community_sheets(names)
	assert_eq(DraftPoolConfig.validate(_options(3), names), "", "a short sheet is never refused")
	var note := SealedPool.community_note(community, 5)
	assert_string_contains(note, "too few rare and uncommon cards")
	assert_false(note.contains("repeat"))
	var pool := DraftRecipe.deal(_options(3), names, SEED)
	assert_not_null(pool)
	if pool == null: return
	for pack in _community_packs(pool):
		assert_eq(pack.cards.size(), 15)
		var tally := _tally(pack.cards)
		assert_eq(tally.size(), 15, "no repeat while the set has an unused card")
		assert_true(tally.has("Zyx Uncommon 1") and tally.has("Zyx Uncommon 2"), "both uncommons come")
		var lands := 0
		for card_name in pack.cards:
			lands += int(SealedPool.LAND_NAMES.has(card_name))
		assert_eq(lands, 1)


func test_a_set_smaller_than_the_pack_repeats_every_card_before_any_third_time() -> void:
	_make_set({"rare": 1, "uncommon": 2, "common": 3})
	var names := _names()
	var community := SealedPool.community_sheets(names)
	assert_eq(SealedPool.community_note(community, 5),
		"Community boosters: 6 community cards for 14 slots, so some repeat within a pack.")
	assert_eq(DraftPoolConfig.validate(_options(2), names), "")
	var pool := DraftRecipe.deal(_options(2), names, SEED)
	assert_not_null(pool)
	if pool == null: return
	for pack in _community_packs(pool):
		assert_eq(pack.cards.size(), 15)
		var tally := _tally(pack.cards)
		var community_copies := 0
		for card_name in tally:
			if SealedPool.LAND_NAMES.has(card_name):
				continue
			community_copies += int(tally[card_name])
			assert_between(int(tally[card_name]), 2, 3, "%s: every card twice before any thrice" % card_name)
		assert_eq(community_copies, 14)
		assert_eq(tally.size(), 7, "all six community cards and a basic land")
	# Without a basic land in Card pool, a community card takes the land slot.
	var landless := _names(false)
	assert_string_contains(SealedPool.community_note(SealedPool.community_sheets(landless), 0), "15 slots")
	assert_eq(DraftPoolConfig.validate(_options(1), landless), "")
	var no_land := DraftRecipe.deal(_options(1), landless, SEED)
	assert_not_null(no_land)
	if no_land == null: return
	var cards: Array = _community_packs(no_land)[0].cards
	assert_eq(cards.size(), 15)
	for card_name: String in cards:
		assert_true(card_name.begins_with(PREFIX))
	assert_true(DraftRecipe.reconstruct(no_land.draft_recipe).ok)


# --------------------------------------------- the recipe, reconstructed --

func test_a_recipe_with_community_boosters_reconstructs_the_identical_pool() -> void:
	_make_set({"mythic": 1, "rare": 3, "uncommon": 4, "common": 9})
	var names := _names()
	var pool := DraftRecipe.deal(_options(3, 1, 1, 5), names, SEED)
	assert_not_null(pool)
	if pool == null: return
	var recipe := pool.draft_recipe
	assert_eq(int(recipe.options[DraftRecipe.COMMUNITY_OPTION]), 3)
	assert_eq(recipe.community, SealedPool.community_sheets(names))
	assert_eq(pool.total(), pool.card_total())
	assert_eq(pool.total(), 15 + 60 + 45 + 5)
	var replay := DraftRecipe.reconstruct(recipe)
	assert_true(replay.ok, String(replay.get("message", "")))
	if not replay.ok: return
	assert_eq(replay.pool.packs, pool.packs)
	assert_eq(replay.pool.counts, pool.counts)
	assert_eq(replay.fingerprint, recipe.fingerprint)
	var json := JSON.new()
	assert_eq(json.parse(JSON.stringify(recipe, "\t")), OK)
	var parsed := DraftRecipe.reconstruct(json.data)
	assert_true(parsed.ok, "a JSON round trip (floats and all) reconstructs")
	if parsed.ok: assert_eq(parsed.pool.packs, pool.packs)
	assert_ne(DraftRecipe.deal(_options(3, 1, 1, 5), names, "a".repeat(64)).packs, pool.packs)
	# Every part of the community extension is hashed or refused whole.
	var fewer := recipe.duplicate(true)
	fewer.options[DraftRecipe.COMMUNITY_OPTION] = 2
	assert_false(DraftRecipe.reconstruct(fewer).ok, "the count is fingerprinted")
	var swapped := recipe.duplicate(true)
	swapped.community.common.remove_at(0)
	assert_false(DraftRecipe.reconstruct(swapped).ok, "the community sheets are fingerprinted")
	swapped.fingerprint = DraftRecipe.fingerprint(swapped)
	assert_false(DraftRecipe.reconstruct(swapped).ok, "and the pool they deal is hashed")
	var orphan := recipe.duplicate(true)
	orphan.erase("community")
	assert_false(DraftRecipe.reconstruct(orphan).ok, "the option needs its sheets")
	var stray := recipe.duplicate(true)
	stray.options.erase(DraftRecipe.COMMUNITY_OPTION)
	assert_false(DraftRecipe.reconstruct(stray).ok, "the sheets need their option")
	var foreign := recipe.duplicate(true)
	foreign.community.rare.append("Zzz Not On A Sheet")
	foreign.fingerprint = DraftRecipe.fingerprint(foreign)
	assert_string_contains(DraftRecipe.reconstruct(foreign).message, "Community sheets")
	for count in [-1, 13, 1.5, "3"]:
		var bad := recipe.duplicate(true)
		bad.options[DraftRecipe.COMMUNITY_OPTION] = count
		assert_false(DraftRecipe.reconstruct(bad).ok, str(count))
	# The saved deck carries the recipe; a judge replays it from the deck alone.
	var store := DraftStore.new()
	assert_eq(store.prepare(ROOT, pool, _options(3, 1, 1, 5)), "")
	_files.append_array([store.deck_path, store.pool_path])
	assert_eq(store.checkpoint(DeckModel.new(), "done"), "")
	var text := FileAccess.get_file_as_string(store.deck_path)
	assert_string_contains(text, "20 minutes, 3 community boosters")
	var judged := DraftAudit.reconstruct_text(text, recipe.fingerprint)
	assert_true(judged.ok, String(judged.message))
	assert_string_contains(String(judged.message), "3 community boosters")
	assert_true(DraftAudit.check_files(store.pool_path, store.deck_path, recipe.fingerprint).ok)
	assert_string_contains(DraftStore.new().prepare(ROOT, pool, _options(2, 1, 1, 5)), "options do not match")
	# Without the community cards here, the judge is told which are missing.
	CommunityCards.folders_override = [_root.path_join("none")]
	CommunityCards.refresh()
	assert_string_contains(String(DraftAudit.reconstruct_text(text).message), "needs community cards")


## A recipe dealt with community boosters is replayed by a frozen dealer:
## this hand-made recipe (its names need not be in play) must keep dealing
## the same two packs. The two hashes were also calculated independently,
## by a Python reference of the same steps (hashlib, little-endian uint32
## words, rejection sampling, compact UTF-8 JSON); no Godot RNG is involved.
func test_the_community_dealer_is_frozen() -> void:
	var recipe := {"schema": 1, "algorithm": DraftRecipe.ALGORITHM, "seed": SEED,
		"options": {"boosters": 0, "starters": 0, "free_lands": 0, "extras": 0, "minutes": 20,
			"community_boosters": 2},
		"sheets": {"rare": ["Shivan Dragon", "Zyx Mythic", "Zyx Rare"], "uncommon": ["Counterspell", "Zyx Uncommon"],
			"common": ["Giant Growth", "Zyx Common A", "Zyx Common B"],
			"land": ["Forest", "Island", "Mountain", "Plains", "Swamp"]},
		"community": {"mythic": ["Zyx Mythic"], "rare": ["Zyx Rare"], "uncommon": ["Zyx Uncommon"],
			"common": ["Zyx Common A", "Zyx Common B"]},
		"pool_sha256": "0".repeat(64), "fingerprint": "0".repeat(64)}
	recipe.pool_sha256 = DraftRecipe.pack_hash(DraftRecipe.new()._deal(recipe).packs)
	recipe.fingerprint = DraftRecipe.fingerprint(recipe)
	assert_eq(recipe.pool_sha256, "2f98930476d9a4677cab872f0acf4f93717963f97862d20edc472ede362c48fe")
	assert_eq(recipe.fingerprint, "e75ed2ac99b2fb0852aa7476f07eb8eb10bbefdee45a3476a8a2ea45264b1c67")
	var replay := DraftRecipe.reconstruct(recipe)
	assert_true(replay.ok)
	if not replay.ok: return
	assert_eq(replay.pool.packs.size(), 2)
	assert_eq(replay.pool.packs[0].cards, ["Zyx Rare", "Zyx Mythic", "Zyx Uncommon", "Zyx Uncommon",
		"Zyx Common A", "Zyx Common A", "Zyx Common A", "Zyx Common B", "Zyx Common B", "Zyx Common B",
		"Zyx Mythic", "Zyx Rare", "Zyx Rare", "Zyx Uncommon", "Swamp"] as Array[String],
		"five cards for fourteen slots: each twice before any thrice")
	for pack in replay.pool.packs:
		assert_eq(pack.cards.size(), 15)
		assert_false(pack.cards.has("Shivan Dragon") or pack.cards.has("Giant Growth"), "community cards only")


## A community card a pool dealt — through ordinary boosters too, with no
## community sheets in the recipe — is named when it is missing, and a pool
## missing a pack card and a community card names both, the pack counting
## only its own names.
func test_a_missing_community_card_is_named_whatever_booster_dealt_it() -> void:
	_make_set({"rare": 1, "uncommon": 3, "common": 10})
	var picked: Array[String] = ["Zyx Rare 1", "Zyx Uncommon 1", "Zyx Uncommon 2", "Zyx Uncommon 3", "Forest"]
	for i in 10:
		picked.append("Zyx Common %d" % (i + 1))
	var pool := DraftRecipe.deal(_options(0, 2), picked, SEED)
	assert_not_null(pool)
	if pool == null: return
	assert_false(pool.draft_recipe.has("community"))
	var store := DraftStore.new()
	assert_eq(store.prepare(ROOT, pool, _options(0, 2)), "")
	_files.append_array([store.deck_path, store.pool_path])
	assert_eq(store.checkpoint(DeckModel.new(), "done"), "")
	var text := FileAccess.get_file_as_string(store.deck_path)
	CommunityCards.folders_override = [_root.path_join("none")]
	CommunityCards.refresh()
	var judged := DraftAudit.reconstruct_text(text)
	assert_false(judged.ok)
	assert_string_contains(String(judged.message), "unknown card names that are not in play here: Zyx Common 1")
	assert_string_contains(String(judged.message), "Zyx Common 9 and 4 more.", "ten named, the rest counted")
	var receipt := {"schema": 1, "counts": {"Wiitigo": 1, "Zyx Gone": 1, "Zyx Lost": 1},
		"packs": [{"title": "Test pack", "cards": ["Wiitigo", "Zyx Gone", "Zyx Lost"]}],
		"recipe": {"community": {"mythic": [], "rare": ["Zyx Gone"], "uncommon": [], "common": []}}}
	var refusal := DraftAudit.pool_refusal(receipt)
	assert_string_contains(refusal, "Pack 3: 1 of its card names", "the pack counts its own names only")
	assert_string_contains(refusal, "It also needs community cards that are not here: Zyx Gone.")
	assert_string_contains(refusal, "It also has unknown card names that are not in play here: Zyx Lost.")


## The bounds a recipe keeps are said before a deal: a pool past the
## recipe's eligible cap is refused with its reason, a community sheet
## naming a game card is refused, the window's own dealer deals no empty
## community booster, and one card is one card.
func test_the_recipe_s_bounds_and_an_empty_community_set_are_said_plainly() -> void:
	var huge: Array[String] = []
	for i in DraftRecipe.MAX_ELIGIBLE + 1:
		huge.append("Card %d" % i)
	assert_string_contains(DraftPoolConfig.validate(DraftPoolConfig.defaults(), huge),
		"a draft deals from at most %d" % DraftRecipe.MAX_ELIGIBLE)
	var tampered := {"schema": 1, "algorithm": DraftRecipe.ALGORITHM, "seed": SEED,
		"options": {"boosters": 0, "starters": 0, "free_lands": 0, "extras": 0, "minutes": 20,
			"community_boosters": 1},
		"sheets": {"rare": ["Shivan Dragon"], "uncommon": [], "common": [],
			"land": ["Forest", "Island", "Mountain", "Plains", "Swamp"]},
		"community": {"mythic": ["Shivan Dragon"], "rare": [], "uncommon": [], "common": []},
		"pool_sha256": "0".repeat(64), "fingerprint": "0".repeat(64)}
	assert_eq(DraftRecipe.reconstruct(tampered).message, "Community sheets may hold community cards only.")
	var sealed := SealedPool.new()
	sealed.boosters = 0
	sealed.starters = 0
	sealed.community_boosters = 2
	sealed.deal(DraftPoolConfig.library(_names()), 1997)
	assert_true(sealed.packs.is_empty(), "no community card, no community booster")
	assert_eq(sealed.total(), sealed.card_total())
	assert_eq(SealedPool.community_note({"mythic": [], "rare": [], "uncommon": [], "common": ["Zyx Lone"]}, 5),
		"Community boosters: 1 community card for 14 slots, so it repeats within a pack.")


# ------------------------------------------------- old recipes unchanged --

func test_recipes_without_community_boosters_read_and_deal_exactly_as_before() -> void:
	# The v1 reference vector (tests/ui/test_draft_recipe.gd), independently computed.
	var old := {"schema": 1, "algorithm": DraftRecipe.ALGORITHM, "seed": SEED,
		"options": {"boosters": 1, "starters": 0, "free_lands": 1, "extras": 2, "minutes": 20},
		"sheets": {"rare": ["Shivan Dragon"], "uncommon": ["Counterspell", "Serra Angel", "Sol Ring"],
			"common": ["Dark Ritual", "Disenchant", "Giant Growth", "Grizzly Bears", "Healing Salve", "Lightning Bolt", "Llanowar Elves", "Mons's Goblin Raiders", "Scryb Sprites", "Unholy Strength"],
			"land": ["Forest", "Island", "Mountain", "Plains", "Swamp"]},
		"pool_sha256": "3231e8474ee8be69f58b972d1febb6c7261f11d6f2a08b3a7ac7bec2de4ef879",
		"fingerprint": "ba56d2dcd6a70463fbfec7e3f7fdbd3848685a912f854eaf697bef54451b95da"}
	assert_eq(DraftRecipe.fingerprint(old), old.fingerprint)
	var replay := DraftRecipe.reconstruct(old)
	assert_true(replay.ok)
	if not replay.ok: return
	assert_eq(replay.pool.community_boosters, 0)
	assert_eq(replay.pool.packs[-1].cards, ["Forest", "Shivan Dragon"] as Array[String])
	assert_false(DraftRecipe.comments(old).contains("community"))
	# With community cards in play, a deal without community boosters is
	# still the plain v1 recipe: no new key, the v1 fingerprint formula.
	_make_set({"rare": 1, "uncommon": 3, "common": 10})
	var names := _names()
	for options in [DraftPoolConfig.defaults(), _options(0, 3, 1)]:
		var pool := DraftRecipe.deal(options, names, SEED)
		assert_not_null(pool)
		if pool == null: return
		var recipe := pool.draft_recipe
		assert_false(recipe.has("community"))
		assert_eq(recipe.options.keys().size(), DraftRecipe.OPTION_KEYS.size())
		var opts: Array = []
		var sheets: Array = []
		for key in DraftRecipe.OPTION_KEYS: opts.append(int(recipe.options[key]))
		for slot in DraftRecipe.SLOTS: sheets.append(recipe.sheets[slot])
		assert_eq(recipe.fingerprint, JSON.stringify([1, DraftRecipe.ALGORITHM, recipe.seed, opts, sheets,
			recipe.pool_sha256]).sha256_text(), "the v1 fingerprint")
		assert_true(_community_packs(pool).is_empty())
	assert_eq(DraftRecipe.deal(DraftPoolConfig.defaults(), names, SEED).packs,
		DraftRecipe.deal(_options(0, 3, 1), names, SEED).packs, "a zero count is no count")


# ----------------------------------------------------- the setup's row --

func test_the_row_is_hidden_without_community_cards() -> void:
	var plain := DraftSetup.new()
	add_child_autofree(plain)
	assert_not_null(plain.community_row)
	assert_false(plain.community_row.visible, "no community cards, no row")
	assert_eq(plain.options(), DraftPoolConfig.defaults(), "and no count")
	assert_false(plain.pool_summary.text.contains("Community"))
	_make_set({"rare": 1, "uncommon": 2, "common": 3})
	var setup := DraftSetup.new()
	add_child_autofree(setup)
	assert_true(setup.community_row.visible, "the pool holds community cards")
	assert_eq(int(setup.options()[DraftRecipe.COMMUNITY_OPTION]), 0)
	setup.community_field.value = 2
	assert_string_contains(setup.status.text, "135 cards", "two boosters more")
	assert_string_contains(setup.pool_summary.text, "6 community cards for 14 slots", "a small set says so")
	# A pool narrowed to leave the community cards out hides the row again.
	Settings.set_value(DraftPoolConfig.SETTING, ["Mountain", "Forest", "Shivan Dragon"], false)
	setup._refresh()
	assert_false(setup.community_row.visible)
	assert_false(setup.options().has(DraftRecipe.COMMUNITY_OPTION))
	assert_false(setup.pool_summary.text.contains("Community"))


# --------------------------------------------- the deck editor's Extras --

func test_the_extras_community_row_wears_its_own_medallion_and_switches_the_set() -> void:
	_make_set({"common": 1})
	var screen: DeckBuilderScreen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen._open_extra_sets()
	assert_not_null(screen.find_child("ExtraSourceRow_Community", true, false), "the row is there")
	assert_not_null(GameSkin.our_art("filter_comm_on"))
	assert_not_null(GameSkin.our_art("filter_comm_off"))
	for state in ["On", "Off"]:
		var tile := screen.find_child("ExtraCommunity" + state, true, false) as Button
		assert_not_null(tile, state)
		if tile == null:
			return
		var lit := tile.get_theme_stylebox("pressed") as StyleBoxTexture
		var dim := tile.get_theme_stylebox("normal") as StyleBoxTexture
		assert_not_null(lit, "a carved medallion, not a blank tile")
		assert_not_null(dim)
		if lit == null or dim == null:
			return
		assert_eq(lit.texture, GameSkin.our_art("filter_comm_on"))
		assert_eq(dim.texture, GameSkin.our_art("filter_comm_off"))
		assert_string_contains(tile.tooltip_text, "color, type")
	assert_false(screen.filter.set_on(CommunityCard.SET_CODE), "community cards start off")
	(screen.find_child("ExtraCommunityOn", true, false) as Button).pressed.emit()
	assert_true(screen.filter.set_on(CommunityCard.SET_CODE), "their own switch turns them on")
	(screen.find_child("ExtraCommunityOff", true, false) as Button).pressed.emit()
	assert_false(screen.filter.set_on(CommunityCard.SET_CODE), "and off again")


func _builder() -> DeckBuilderScreen:
	var screen: DeckBuilderScreen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	return screen


func _shows_community(screen: DeckBuilderScreen) -> bool:
	screen._refresh_inventory()
	for entry in screen._inventory._visible_entries():
		if String(entry[0].card_name).begins_with(PREFIX):
			return true
	return false


func _press(screen: DeckBuilderScreen, button_name: String) -> void:
	(screen.find_child(button_name, true, false) as Button).pressed.emit()


## Every source the bulk buttons move, as the filter has it now.
func _bulk_state(screen: DeckBuilderScreen) -> Array:
	var out: Array = [screen.filter.original_cards_on]
	if CardRegistry.optional_pack_enabled():
		out.append(screen.filter.completion_pack_on)
	for code in screen._bulk_codes():
		out.append(screen.filter.set_on(code))
	return out


func test_community_cards_start_off_and_no_bulk_command_turns_them_on() -> void:
	_make_set({"common": 2})
	var screen: DeckBuilderScreen = await _builder()
	assert_false(screen.filter.set_on(CommunityCard.SET_CODE), "off at the opening")
	assert_false(_shows_community(screen), "and not in the Inventory")
	assert_false(screen.filter.active(), "off is where they start, not a narrowing")
	screen._open_extra_sets()
	assert_false(screen._bulk_codes().has(CommunityCard.SET_CODE))
	for button_name in ["ExtraOnly1997", "ExtraAll", "ExtraAll"]:
		_press(screen, button_name)
		assert_false(screen.filter.set_on(CommunityCard.SET_CODE), button_name + " leaves them off")
	screen.filter.select_all()
	assert_false(screen.filter.set_on(CommunityCard.SET_CODE), "the strip's Select All too")
	assert_true(_pressed_named(screen, "ExtraCommunityOff"), "the row still says Off")
	# Switched on by hand, they stay on through every bulk command.
	_press(screen, "ExtraCommunityOn")
	assert_true(_shows_community(screen))
	for button_name in ["ExtraOnly1997", "ExtraAll", "ExtraAll"]:
		_press(screen, button_name)
		assert_true(screen.filter.set_on(CommunityCard.SET_CODE), button_name + " leaves them on")
	assert_true(_pressed_named(screen, "ExtraCommunityOn"))
	screen._refresh_inventory()
	assert_eq(Settings.get_value(DeckBuilderScreen.EXTRAS_SETTING, {}).get("community"), true,
		"remembered under its own key")


func _pressed_named(screen: DeckBuilderScreen, button_name: String) -> bool:
	return (screen.find_child(button_name, true, false) as Button).button_pressed


func test_a_hand_turned_on_switch_comes_back_but_an_old_save_s_does_not() -> void:
	_make_set({"common": 1})
	Settings.set_value(DeckBuilderScreen.EXTRAS_SETTING,
		{"original": true, "pack1": true, "sets": {CommunityCard.SET_CODE: true}}, false)
	var old: DeckBuilderScreen = await _builder()
	assert_false(old.filter.set_on(CommunityCard.SET_CODE),
		"a save from when they started on is not a hand on the switch")
	Settings.set_value(DeckBuilderScreen.EXTRAS_SETTING,
		{"original": true, "pack1": true, "sets": {}, "community": true}, false)
	var turned: DeckBuilderScreen = await _builder()
	assert_true(turned.filter.set_on(CommunityCard.SET_CODE), "switched on by hand, it stays on")
	assert_true(_shows_community(turned))


func test_1997_shows_the_originals_alone_and_all_turns_everything_on_then_off() -> void:
	_make_set({"common": 1})
	var screen: DeckBuilderScreen = await _builder()
	screen._open_extra_sets()
	var bulk := screen.find_child("ExtraBulkRow", true, false) as HBoxContainer
	assert_not_null(bulk, "the two buttons sit above the switches")
	if bulk == null:
		return
	assert_eq((bulk.get_child(0) as Button).text, "1997")
	assert_eq((bulk.get_child(1) as Button).text, "All")
	assert_false((bulk.get_child(0) as Button).toggle_mode, "one press, not a switch")
	assert_false((bulk.get_child(1) as Button).toggle_mode)
	# With or without packs: one source off, so not everything is on.
	_press(screen, "ExtraOriginalOff")
	_press(screen, "ExtraAll")
	assert_false(_bulk_state(screen).has(false), "All: every source on")
	assert_true(_pressed_named(screen, "ExtraOriginalOn"), "the row follows at once")
	_press(screen, "ExtraAll")
	assert_false(_bulk_state(screen).has(true), "All again, every one on: all off")
	assert_true(_pressed_named(screen, "ExtraOriginalOff"))
	assert_eq(screen._inventory.entry_count(), 0, "nothing on, nothing shown")
	_press(screen, "ExtraAll")
	assert_false(_bulk_state(screen).has(false), "and on again")
	_press(screen, "ExtraOnly1997")
	var only := [true]
	for _i in _bulk_state(screen).size() - 1:
		only.append(false)
	assert_eq(_bulk_state(screen), only, "1997: the 1997 cards on, every pack off")
	assert_true(_pressed_named(screen, "ExtraOriginalOn"))
	assert_eq(screen._inventory.entry_count(), 897, "only the 1997 cards")
