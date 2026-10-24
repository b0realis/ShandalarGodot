extends GutTest
## THE ADVENTURE'S DECK BUILDER (2026-10-23): the owner's *"cards on the
## bottom are player stack accumulated during play! (Extras button absent,
## and any other conflicting buttons) … the top left deck name pane …
## with GOLD and amount of player gold"* — [AdventureBuilder] over the
## hero's own cards, its decks written back to the hero.

var builder: AdventureBuilder
var player: AdventurePlayer


func _hero() -> AdventurePlayer:
	var hero := AdventurePlayer.new()
	hero.gold = 275
	hero.difficulty = 1
	for card_name in ["Grizzly Bears", "Grizzly Bears", "Giant Growth", "Forest", "Forest", "Forest", "Llanowar Elves"]:
		hero.cards.append({"card": card_name, "decks": [0]})
	hero.cards.append({"card": "Shivan Dragon", "decks": []})
	return hero


func before_each() -> void:
	CardRegistry.ensure_loaded()
	player = _hero()
	builder = AdventureBuilder.new()
	builder.player = player
	add_child_autofree(builder)
	await get_tree().process_frame


func test_the_doors_to_other_cards_are_gone() -> void:
	for door in ["ExtrasButton", "LoadButton"]:
		var button := builder.find_child(door, true, false) as Control
		assert_true(button == null or not button.visible, door + " absent")
	assert_false(builder._dice_button.visible, "no sealed dice")
	assert_false(builder._pool_button.visible, "no AutoDeck pool")
	assert_eq(builder.find_child("DoneButton", true, false).visible, true, "Done stays")
	for label in ["Load deck", "New deck", "AutoDeck", "Add proxy card", "Import deck", "Booster Draft",
			"Sideboard"]:
		assert_false(label in builder._command_labels(), label + " not offered")
	builder._run_command("Load deck")
	assert_eq(builder._menu_entries(), [DeckBuilderScreen.MENU_BACK, "Return to the world", "Exit game"]
		as Array[String], "Escape's menu: back to the world")


func test_the_title_says_the_deck_and_the_gold() -> void:
	assert_eq(builder.gold_text(), "GOLD: 275", "the 1997 title field's words")
	var label := builder._header_label.text
	assert_eq(label, "Deck 1")
	player.gold = 300
	builder.refresh()
	assert_eq(builder.gold_text(), "GOLD: 300", "it follows the purse")
	var gold := builder.find_child("Gold", true, false) as Control
	assert_true(builder._header_slab.is_ancestor_of(gold), "on the deck name pane")
	assert_true(gold is Label, "in words only, no coin")
	assert_null(builder.find_child("Coin", true, false))



func test_the_inventory_is_the_hero_s_cards_less_the_deck() -> void:
	assert_eq(builder.deck.total(), 7, "Deck 1 as the hero holds it")
	assert_eq(builder.sealed.copies_of("Grizzly Bears"), 2)
	assert_false(builder._add_one("Grizzly Bears"), "both copies are in the deck already")
	assert_false(builder._add_one("Black Lotus"), "a card the hero does not own")
	assert_true(builder._add_one("Shivan Dragon"), "an owned card goes in")
	assert_false(builder._add_one("Shivan Dragon"), "but only the one owned")
	builder._add_one_side("Giant Growth")
	assert_eq(builder.deck.side_total(), 0, "no sideboard in the adventure")


func test_done_writes_the_decks_back() -> void:
	var closed := [0]
	builder.closed.connect(func() -> void: closed[0] += 1)
	builder._remove_one("Giant Growth")
	builder._switch_slot(1)
	assert_true(builder._add_one("Grizzly Bears"))
	assert_true(builder._add_one("Shivan Dragon"))
	builder._exit()
	assert_eq(closed[0], 1, "closed")
	assert_eq(player.current_deck, 1, "the deck on the surface is the deck in use")
	var membership := {}
	for card in player.cards:
		var key := String(card["card"])
		if not membership.has(key):
			membership[key] = []
		membership[key].append(card["decks"])
	assert_eq(membership["Giant Growth"], [[]], "out of Deck 1")
	assert_eq(membership["Grizzly Bears"], [[0, 1], [0]], "one copy in both decks")
	assert_eq(membership["Shivan Dragon"], [[1]])


func test_tome_of_enlightenment_eases_the_limit() -> void:
	assert_false(builder._with_tome())
	player.world_magics.append("Tome of Enlightenment")
	assert_true(builder._with_tome())


## The legality line speaks of the adventure's own rule only: no
## Gauntlets, no tournaments, no minimum (1997's adventure builder asked
## none); the Inventory's count is the hero's cards.
func test_the_lines_speak_of_the_adventure() -> void:
	builder._refresh_legality()
	assert_false(builder._legality_said.contains("Gauntlet"), builder._legality_said)
	assert_false(builder._legality_said.contains("tournament"), builder._legality_said)
	builder._switch_slot(2)
	builder._drawn_revision = -1
	builder._refresh_inventory()
	assert_string_contains(builder._count_label.text, "of your cards to add")


## The owner: "the deck 1 name can also be renamed" — a click on the title
## slab names the deck, and the hero keeps the name.
func test_a_deck_is_renamed_and_keeps_its_name() -> void:
	builder._header_slab.pressed.emit()
	await get_tree().process_frame
	var field: LineEdit = null
	for edit in builder.find_children("*", "LineEdit", true, false):
		if (edit as LineEdit).text == "Deck 1":
			field = edit
	assert_not_null(field, "Deck Info, the deck's title in it")
	field.text = "Goya's Fliers"
	var ok: Button = null
	for button in builder.find_children("*", "Button", true, false):
		if (button as Button).text == "OK" and (button as Button).is_visible_in_tree():
			ok = button
	ok.pressed.emit()
	await get_tree().process_frame
	assert_eq(builder._header_label.text, "Goya's Fliers", "the title slab says the new name")
	assert_eq(builder.gold_text(), "GOLD: 275", "the gold under it still")
	builder._exit()
	assert_eq(player.deck_names[0], "Goya's Fliers", "the hero keeps the name")
	assert_eq(player.deck_names[1], "", "the others keep theirs")
	var again := AdventureBuilder.new()
	again.player = player
	add_child_autofree(again)
	await get_tree().process_frame
	assert_eq(again._header_label.text, "Goya's Fliers", "and it is there next time")


## The bug hunt of 2026-10-23: what the builder keeps and how it trims.
func test_the_deck_keeps_its_name_notes_and_cards_it_cannot_show() -> void:
	builder._clear_deck()
	assert_eq(builder.deck.deck_name, "Deck 1", "Clear deck keeps the name")
	builder.deck.notes = "Fliers first."
	player.cards.append({"card": "No Such Card", "decks": [0, 2]})
	builder._run_command("Save deck")
	assert_eq(player.deck_notes[0], "Fliers first.", "the notes kept (Save deck, Ctrl+S)")
	assert_eq(player.cards[-1]["decks"], [0, 2], "a card the game does not know keeps its decks")
	builder._exit()
	var again := AdventureBuilder.new()
	again.player = player
	add_child_autofree(again)
	await get_tree().process_frame
	assert_eq(again.deck.notes, "Fliers first.", "and they come back")


func test_remove_extra_cards_counts_tome_of_enlightenment() -> void:
	player.world_magics.append("Tome of Enlightenment")
	for i in 4:
		player.cards.append({"card": "Giant Growth", "decks": [0]})
	var again := AdventureBuilder.new()
	again.player = player
	add_child_autofree(again)
	await get_tree().process_frame
	assert_eq(again.deck.count_of("Giant Growth"), 5)
	again._trim_duplicates()
	assert_eq(again.deck.count_of("Giant Growth"), DeckModel.copies_allowed_1997(12, true),
		"trimmed to the limit the Tome allows by 1997's builder: four under 59 cards")



## The owner: "Implement the same 1997 here … it could only be edited in
## towns, or outdoors with Conjurer's Will" — the spellbook's builder only
## looks (1997's `DeckBuilderMain(…, 1, 0)`).
func test_outdoors_the_builder_only_looks() -> void:
	var looker := AdventureBuilder.new()
	looker.player = player
	looker.looking = true
	add_child_autofree(looker)
	await get_tree().process_frame
	var held := looker.deck.total()
	assert_false(looker._add_one("Shivan Dragon"), "no card goes in")
	looker._remove_one("Grizzly Bears")
	assert_eq(looker.deck.total(), held, "nor out")
	assert_eq(looker._status_label.text, AdventureBuilder.LOOK_ONLY, "it says where the deck is changed")
	assert_eq(looker._status_label.tooltip_text, AdventureBuilder.LOOK_WHY, "the whole reason on the tooltip")
	# Another message has its few seconds; then the well says so again.
	looker._say("Sorted.")
	looker._process(5.0)
	assert_eq(looker._status_label.text, AdventureBuilder.LOOK_ONLY, "kept while it only looks")
	assert_eq(looker._command_labels(), AdventureBuilder.LOOK_ALLOWED, "only the views")
	looker._run_command("Clear deck")
	assert_eq(looker.deck.total(), held, "Clear refused")
	looker._switch_slot(1)
	looker._exit()
	assert_eq(player.current_deck, 0, "Done writes nothing back: the deck in use stays")
	assert_eq(player.cards[0]["decks"], [0])
	# A builder that may change the deck lets its message go.
	builder._say("Sorted.")
	builder._process(5.0)
	assert_eq(builder._status_label.text, "", "the well empties after its few seconds")


## The bug pass after the campaign (r2-1, r2-2, r2-5): the complaint line's
## Remove Extra Cards and the artwork picker were ways round looking only;
## Consolidate only shows duplicates differently and is a view.
func test_looking_refuses_the_side_doors_and_lets_the_views_be() -> void:
	player.cards.append({"card": "Giant Growth", "decks": [0]})
	player.cards.append({"card": "Giant Growth", "decks": [0]})
	player.cards.append({"card": "Giant Growth", "decks": [0]})
	var looker := AdventureBuilder.new()
	looker.player = player
	looker.looking = true
	add_child_autofree(looker)
	await get_tree().process_frame
	var held := looker.deck.count_of("Giant Growth")
	assert_eq(held, 4, "control: over the limit for a small deck")
	looker._trim_duplicates()
	assert_eq(looker.deck.count_of("Giant Growth"), held, "Remove Extra Cards refused")
	assert_eq(looker._status_label.text, AdventureBuilder.LOOK_ONLY)
	looker._choose_printing("Forest", "4ed")
	assert_false(looker.deck.printings.has("Forest"), "no artwork chosen")
	var grouped: bool = looker._deck_area.consolidated
	looker._run_command("Consolidate duplicate cards")
	assert_ne(looker._deck_area.consolidated, grouped, "Consolidate is a view: allowed")
	looker._show_in_showcase(CardRegistry.get_card("Forest"))
	assert_false(looker._variant_button.visible, "no artwork picker in the adventure")
	# A builder that may change the deck still keeps no artwork.
	builder._choose_printing("Forest", "4ed")
	assert_false(builder.deck.printings.has("Forest"), "the hero's decks keep no printing")
	assert_eq(builder._status_label.text, AdventureBuilder.NO_ARTWORK)


## The 1997 adventure deck builder's copy rule (the owner, 2026-10-24): a
## first deck with three copies of a spell is fair — nothing said; a fourth
## is asked about as the builder is left, as 1997 asked (the Extra Cards
## box): Remove Extra Cards takes it out and leaves, Edit Deck stays.
func test_the_deck_is_judged_and_asked_about_as_1997_left_it() -> void:
	for i in 2:
		player.cards.append({"card": "Giant Growth", "decks": [0]})
	var three := AdventureBuilder.new()
	three.player = player
	add_child_autofree(three)
	await get_tree().process_frame
	assert_eq(three.deck.count_of("Giant Growth"), 3)
	assert_true(three.deck.over_duplicate_limit(false, three._copy_rule()).is_empty(),
		"three in a small deck: a fair deck")
	var closed: Array[int] = [0]
	three.closed.connect(func() -> void: closed[0] += 1)
	three._exit()
	assert_eq(closed[0], 1, "Done: nothing asked")
	player.cards.append({"card": "Giant Growth", "decks": [0]})
	var four := AdventureBuilder.new()
	four.player = player
	add_child_autofree(four)
	await get_tree().process_frame
	var left: Array[int] = [0]
	four.closed.connect(func() -> void: left[0] += 1)
	four._exit()
	assert_eq(left[0], 0, "a fourth copy: asked first")
	var buttons := four.find_children("*", "Button", true, false).filter(
		func(b: Node) -> bool: return (b as Button).text in ["Remove Extra Cards", "Edit Deck"])
	assert_eq(buttons.size(), 2, "the Extra Cards box: Remove Extra Cards, Edit Deck")
	for b in buttons:
		if (b as Button).text == "Edit Deck":
			(b as Button).pressed.emit()
	await get_tree().process_frame
	assert_eq(left[0], 0, "Edit Deck: the builder stays")
	four._exit()
	await get_tree().process_frame
	for b in four.find_children("*", "Button", true, false):
		if (b as Button).text == "Remove Extra Cards":
			(b as Button).pressed.emit()
	await get_tree().process_frame
	assert_eq(left[0], 1, "Remove Extra Cards: the extra out, the builder left")
	var in_deck := 0
	for entry in player.cards:
		if entry["card"] == "Giant Growth" and (entry["decks"] as Array).has(0):
			in_deck += 1
	assert_eq(in_deck, 3, "three Giant Growth in the deck written back")


## A builder that only looks has nothing to change: never asked.
func test_a_builder_that_only_looks_is_never_asked() -> void:
	for i in 3:
		player.cards.append({"card": "Giant Growth", "decks": [0]})
	var looker := AdventureBuilder.new()
	looker.player = player
	looker.looking = true
	add_child_autofree(looker)
	await get_tree().process_frame
	var left: Array[int] = [0]
	looker.closed.connect(func() -> void: left[0] += 1)
	looker._exit()
	assert_eq(left[0], 1, "left at once")
