extends GutTest
## Adventure campaign fix pass 2026-10-23, finding h5-10: THE DECK BUILDER'S
## OPENING COST. Every F1, spellbook and "Edit deck/Sell cards" builds a new
## [AdventureBuilder], and the opening froze the world 0.2-0.5 s a click.
## Measured on the desk under Xvfb (medians of 25 openings, a 39-card
## hero): a later opening 182 ms with every card pack on and 83 ms
## without, the session's first 450 and 347 ms; after this pass 60 and 55
## ms, 259 and 232 ms. Where the time went, and what these pin:
##
##   * THE WHOLE LIBRARY WAS FILTERED, SORTED AND DRAWN FOR NOTHING. The
##     ordinary builder's [method DeckBuilderScreen._ready] filled the
##     Inventory from every card the game has (3,093 with every pack on),
##     and only then did the adventure put the hero's own cards in — 120 ms
##     a time with every pack on, and the art of nine cards nobody saw
##     loaded on the session's first opening. The hero's decks and cards
##     now go in BEFORE the first fill
##     ([method DeckBuilderScreen._before_first_fill]), and the Inventory
##     is walked once, over the hero's cards.
##   * THE PRINTING COUNT asked the card packs for every card's printings
##     on every Inventory fill (30 ms with every pack on, in the ordinary
##     builder's opening and on every filter click). The answer is the
##     registry's, so it is kept per card name for one registry load
##     ([method DeckBuilderScreen._printing_sets_of]); the count is the same.
##
## The counter these read is [member DeckBuilderScreen.filter_passes], one
## per walk of a card list through the filters.

var _had_extras := false
var _extras: Variant = null
var _packs_before: Array = []


func before_each() -> void:
	CardRegistry.ensure_loaded()
	_had_extras = Settings.has_value(DeckBuilderScreen.EXTRAS_SETTING)
	_extras = Settings.get_value(DeckBuilderScreen.EXTRAS_SETTING, null)
	_packs_before = Settings.enabled_card_packs().duplicate()


func after_each() -> void:
	# THE PACKS FIRST, the Extras switches last. A pack toggle refreshes the
	# Inventory of a builder still mounted, and that refresh writes the
	# switches it holds — a test's "1997 cards off" — over whatever was put
	# back before it, for every suite after this one to open on.
	var toggled := false
	for id in CardPacks.available_ids():
		if CardPacks.is_enabled(id) != _packs_before.has(id):
			CardPacks.set_enabled(id, _packs_before.has(id))
			toggled = true
	if toggled:
		# ...and its deferred refreshes retire before GUT counts orphans.
		for i in 3:
			await get_tree().process_frame
	if _had_extras:
		Settings.set_value(DeckBuilderScreen.EXTRAS_SETTING, _extras)
	else:
		Settings.clear_value(DeckBuilderScreen.EXTRAS_SETTING)
	ShellMusic.stop()


# ------------------------------------------------------------ helpers --

## A hero: Deck 1 of seven cards, a Shivan Dragon in no deck, and
## [param spares] more cards of distinct names in no deck.
func _hero(spares := 0) -> AdventurePlayer:
	var hero := AdventurePlayer.new()
	hero.gold = 120
	hero.difficulty = 1
	for card_name in ["Grizzly Bears", "Grizzly Bears", "Giant Growth", "Forest", "Forest", "Forest",
			"Llanowar Elves"]:
		hero.cards.append({"card": card_name, "decks": [0]})
	hero.cards.append({"card": "Shivan Dragon", "decks": []})
	var names := CardRegistry.all_names()
	for i in spares:
		hero.cards.append({"card": String(names[(i * 7) % names.size()]), "decks": []})
	return hero


## [method _hero]'s cards on a hero with a world, which a town's prices need.
func _world_hero() -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "green"
	setup.difficulty = 1
	setup.seed_text = "145729"
	var record := setup.resolve({})
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	hero.cards = _hero().cards
	hero.gold = 120
	return hero


func _town(hero: AdventurePlayer) -> int:
	for slot in hero.world.sites.size():
		if int(hero.world.sites[slot]["type"]) == ShandalarWorld.TOWN:
			return slot
	return -1


func _open(hero: AdventurePlayer, looking := false, sell_site := -1) -> AdventureBuilder:
	var builder := AdventureBuilder.new()
	builder.player = hero
	builder.looking = looking
	builder.sell_site = sell_site
	add_child_autofree(builder)
	await get_tree().process_frame
	return builder


func _main_builder() -> DeckBuilderScreen:
	var screen: DeckBuilderScreen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	return screen


## The Inventory's entries as `{name: copies}`.
func _listed(area: CardArea) -> Dictionary:
	var out := {}
	for entry in area._visible_entries():
		out[(entry[0] as CardData).card_name] = int(entry[1])
	return out


## What the hero holds outside the deck on the surface, by name.
func _spare(builder: AdventureBuilder) -> Dictionary:
	var out := {}
	var owned := AdventureBuilder.owned_counts(builder.player)
	for card_name in owned:
		if not CardRegistry.has_card(card_name):
			continue
		var left: int = int(owned[card_name]) - builder.deck.copies_of(card_name)
		if left > 0:
			out[card_name] = left
	return out


## The printing count as the Inventory used to take it: every listed
## card's printings asked of the card packs, one by one.
func _walked_printings(screen: DeckBuilderScreen) -> int:
	var total := 0
	for data in screen.filter.apply(screen._pool):
		var count := 0
		for printing in CardPrintings.choices(data.card_name):
			if screen.filter.set_on(printing.set) and CardRegistry.card_in_set(data.card_name,
					printing.set, screen.filter.completion_pack_on, screen.filter.original_cards_on):
				count += 1
		total += maxi(1, count)
	return total


# ---------------------------------------- the adventure's builder opens --

func test_the_hero_s_builder_walks_only_the_hero_s_cards_and_once() -> void:
	var builder: AdventureBuilder = await _open(_hero())
	assert_eq(builder.filter_passes, 1,
		"one walk on opening, over the hero's cards (it was three: the whole library, then the hero's twice)")
	assert_not_null(builder.sealed, "the hero's cards are the pool in force")
	assert_eq(_listed(builder._inventory), _spare(builder),
		"the Inventory is the hero's cards less the deck, each with the copies in hand")
	assert_eq(builder._inventory.badge_min, 2, "the badge is the copies in hand, from the second on")
	assert_false(builder._inventory.count_source.is_valid(), "not the copies in the deck")
	assert_eq(builder.deck.total(), 7, "Deck 1 on the surface")
	assert_eq(builder._deck_area.entry_count(), 4, "its four names drawn")
	assert_eq(builder._header_label.text, "Deck 1")
	assert_eq(builder.gold_text(), "GOLD: 120")
	assert_string_contains(builder._count_label.text, "of your cards to add")


func test_a_big_collection_opens_on_one_walk_too() -> void:
	var builder: AdventureBuilder = await _open(_hero(450))
	assert_eq(builder.filter_passes, 1, "one walk, however many cards the hero carries")
	assert_eq(_listed(builder._inventory), _spare(builder))
	assert_eq(builder._inventory.offset(), 0, "the Inventory opens on its first page")
	var total := 0
	for card_name in _spare(builder):
		total += int(_spare(builder)[card_name])
	assert_string_contains(builder._count_label.text, "%d of your cards to add" % total)


func test_the_spellbook_s_builder_still_only_looks_and_says_so() -> void:
	var hero := _hero()
	var looker: AdventureBuilder = await _open(hero, true)
	assert_eq(looker.filter_passes, 1)
	assert_eq(looker._status_label.text, AdventureBuilder.LOOK_ONLY,
		"the opening's last word is where the deck is changed")
	var held := looker.deck.total()
	assert_false(looker._add_one("Shivan Dragon"), "no card goes in")
	assert_eq(looker.deck.total(), held)
	looker._exit()
	assert_eq(hero.cards[-1]["decks"], [], "nothing written back")
	var changer: AdventureBuilder = await _open(_hero(), false)
	assert_eq(changer._status_label.text, "Your cards: 8 · in this deck 7",
		"a builder that may change the deck says what it holds")


func test_a_town_s_builder_still_sells_and_hides_the_doors() -> void:
	var hero := _world_hero()
	var builder: AdventureBuilder = await _open(hero, false, _town(hero))
	var sell := builder._command_row.get_node_or_null("SellButton") as Button
	assert_not_null(sell, "Sell is on the bar")
	if sell == null:
		return
	assert_eq(sell.get_index(), builder._command_row.get_node("DoneButton").get_index() - 1,
		"just before Done")
	for door in ["LoadButton", "ExtrasButton"]:
		assert_false((builder._command_row.get_node(door) as Control).visible, door + " hidden")
	assert_false(builder._dice_button.visible)
	assert_false(builder._pool_button.visible)
	builder._show_in_showcase(CardRegistry.get_card("Shivan Dragon"))
	assert_false(sell.disabled, "a copy in no deck may be sold")
	var gold := hero.gold
	var price := builder.sell("Shivan Dragon")
	assert_gt(price, 0, "sold")
	assert_eq(hero.gold, gold + price)
	assert_eq(builder.gold_text(), "GOLD: %d" % hero.gold, "the title slab follows at once")
	assert_false(_listed(builder._inventory).has("Shivan Dragon"), "and the Inventory loses it")


# ------------------------------------------- the ordinary builder opens --

func test_the_ordinary_builder_still_opens_on_the_whole_library() -> void:
	var screen: DeckBuilderScreen = await _main_builder()
	assert_eq(screen.filter_passes, 1, "one walk of the library")
	assert_null(screen.sealed)
	assert_eq(screen._inventory.entry_count(), screen.filter.apply(screen._pool).size())
	assert_eq(screen._inventory.badge_min, 1, "the badge is the copies in the deck")
	assert_true(screen._inventory.count_source.is_valid())
	assert_eq(screen._header_label.text, screen.deck.deck_name)


func test_the_printing_count_is_the_walk_over_every_printing() -> void:
	# Portal's twenty basic lands, where the pack is on this machine: the
	# count then differs from the card count, which is what it is for.
	if CardPacks.has_pack("pack-6"):
		CardPacks.set_enabled("pack-6", true)
	var screen: DeckBuilderScreen = await _main_builder()
	assert_eq(screen._printing_count, _walked_printings(screen), "on opening")
	var code := ""
	for one in screen.filter.sets:
		if screen.filter.set_on(String(one)):
			code = String(one)
	screen.filter.sets[code] = false
	screen.filter.revision += 1
	screen._refresh_inventory()
	assert_eq(screen._printing_count, _walked_printings(screen), "after a set is switched off")
	screen.filter.original_cards_on = false
	screen.filter.revision += 1
	screen._refresh_inventory()
	assert_eq(screen._printing_count, _walked_printings(screen), "after the 1997 cards are")


func test_the_kept_printings_answer_for_one_registry_load() -> void:
	var sets := PackedStringArray()
	for printing in CardPrintings.choices("Forest"):
		sets.append(String(printing.set))
	assert_eq(DeckBuilderScreen._printing_sets_of("Forest"), sets, "what the card packs say")
	assert_eq(DeckBuilderScreen._printing_sets_revision, CardRegistry.revision)
	assert_true(DeckBuilderScreen._printing_sets.has("Forest"), "kept, by name")
	# A pack toggle or a rescan reloads the registry, and that is the one
	# moment the printings can change: what was kept is let go.
	CardRegistry.revision += 1
	assert_eq(DeckBuilderScreen._printing_sets_of("Island").size(), CardPrintings.choices("Island").size())
	assert_false(DeckBuilderScreen._printing_sets.has("Forest"), "the old load's answers dropped")
	assert_eq(DeckBuilderScreen._printing_sets_revision, CardRegistry.revision)
