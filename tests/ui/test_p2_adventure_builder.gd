extends GutTest
## THE ADVENTURE'S DECK BUILDER HOLDS WHAT THE ADVENTURE KEEPS (the owner,
## 2026-10-28: *"check that money (gold) and other Adventure relevant
## functionality is in the Adventure deck builder!"*). The check found the
## gold, the three decks, the copy rule's judging, the worth strip and the
## Sell button there, and these missing — each pinned here:
##  - 1997's "Sell Card for %d" on an Inventory card's own mini-menu, and
##    its "How many to Sell?" for more than one copy (`@SELLCARD`,
##    `@NUMBERTOSELL`);
##  - 1997's `Move by color into deck`, the first line of the adventure's
##    own `@DECKSURFACE_ADVENTURE`;
##  - the card hold (the bag against its 500, or without limit) and the copy
##    rule with the Embark's ban list, said on the screen and not only when
##    a deck breaks it;
##  - the deck in use said on the slots;
##  - Redo, and every deck the history holds giving up a sold card.

var builder: AdventureBuilder
var player: AdventurePlayer


func _hero() -> AdventurePlayer:
	var hero := AdventurePlayer.new()
	hero.gold = 275
	hero.difficulty = 1
	for card_name in ["Grizzly Bears", "Grizzly Bears", "Giant Growth", "Forest", "Forest", "Forest",
			"Llanowar Elves"]:
		hero.cards.append({"card": card_name, "decks": [0]})
	for card_name in ["Shivan Dragon", "Lightning Bolt", "Lightning Bolt", "Mountain", "Mountain",
			"Forest", "Giant Growth"]:
		hero.cards.append({"card": card_name, "decks": []})
	return hero


func before_each() -> void:
	CardRegistry.ensure_loaded()
	player = _hero()


func _open(looking := false) -> void:
	builder = AdventureBuilder.new()
	builder.player = player
	builder.looking = looking
	add_child_autofree(builder)
	await get_tree().process_frame


func _walk(node: Node) -> Array:
	var out := [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out


func _lines(dialog: Control) -> Array:
	var out := []
	for node in _walk(dialog):
		if node is Button and node.text != "":
			out.append(node.text)
	return out


func _press(dialog: Control, text: String) -> void:
	for node in _walk(dialog):
		if node is Button and node.text == text:
			node.pressed.emit()
			return
	fail_test("no '%s' in the dialog" % text)


func _card_menu(of: DeckBuilderScreen) -> OriginalDialog:
	for dialog in of.open_dialogs():
		if dialog.has_meta("card_menu"):
			return dialog
	return null


# ------------------------------------------------------ the card hold --

func test_the_card_hold_is_on_the_screen() -> void:
	await _open()
	assert_string_contains(builder._keeps.text, "Your cards: 14 of 500",
		"the bag against the 1997 hold")
	assert_true(builder._worth.is_ancestor_of(builder._keeps), "at the worth strip's foot")
	builder._show_worth("Shivan Dragon")
	assert_string_contains(builder._keeps.text, "Your cards: 14", "whatever card is pointed at")
	assert_false(builder.bag_nearly_full())
	for _i in AdventurePlayer.BAG_WARN - 14:
		player.cards.append({"card": "Mountain", "decks": []})
	builder.refresh()
	assert_true(builder.bag_nearly_full(), "from 450, where the spoils warn")
	assert_eq(builder._keeps.get_theme_color("font_color"), DeckBuilderScreen.WELL_WARNING,
		"the line warms")
	player.card_hold = AdventurePlayer.HOLD_UNLIMITED
	builder.refresh()
	assert_string_contains(builder._keeps.text, "Your cards: 450")
	assert_false(builder._keeps.text.contains("of 500"), "no limit to count against")
	assert_false(builder.bag_nearly_full(), "nor a full bag to warn of")


# ------------------------------------------------- the copy rule --

func test_the_copy_rule_and_the_ban_list_are_on_the_screen() -> void:
	await _open()
	assert_string_contains(builder._keeps.text, AdventureBuilder.RULE_1997)
	player.world_magics.append("Tome of Enlightenment")
	builder.refresh()
	assert_string_contains(builder._keeps.text, AdventureBuilder.RULE_1997_TOME,
		"Tome of Enlightenment's allowance")
	player.card_rule = AdventurePlayer.RULE_CLASSIC
	player.ban_list = ClassicBans.OLD
	builder.refresh()
	assert_string_contains(builder._keeps.text,
		"Copies: Classic MTG rules, 1998 (the original game's) list", "the Embark's own name")


# ------------------------------------------------- the deck in use --

func test_the_slots_say_which_deck_is_duelled_with() -> void:
	await _open()
	for i in AdventureBuilder.SLOTS:
		assert_eq(builder._slot_buttons[i].tooltip_text, AdventureBuilder.SLOT_TIP % (i + 1))
	builder.queue_free()
	player.current_deck = 1
	await _open(true)
	assert_eq(builder._slot_buttons[0].tooltip_text, AdventureBuilder.SLOT_TIP_LOOKING % [1, 2],
		"looking only: the deck in use stays the one it was")


# ------------------------------------------------ the colour moves --

func test_move_by_color_into_deck_moves_every_copy_with_its_land() -> void:
	await _open()
	assert_true(builder._command_labels().has("Move by color into deck"),
		"the adventure's own 1997 command")
	builder._move_in_by_color([Mtg.ManaColor.R])
	assert_eq(builder.deck.count_of("Lightning Bolt"), 2, "every copy the hero owns")
	assert_eq(builder.deck.count_of("Shivan Dragon"), 1)
	assert_eq(builder.deck.count_of("Mountain"), 2, "and red's basic land (1997)")
	assert_eq(builder.deck.count_of("Forest"), 3, "green's own stay as they were")
	builder._undo_last()
	assert_eq(builder.deck.count_of("Lightning Bolt"), 0, "one undo step")
	builder._redo_last()
	assert_eq(builder.deck.count_of("Lightning Bolt"), 2, "Redo here too")
	assert_true(builder._command_labels().has("Redo"))


func test_looking_only_moves_nothing() -> void:
	await _open(true)
	builder._move_in_by_color([Mtg.ManaColor.R])
	assert_eq(builder.deck.count_of("Lightning Bolt"), 0)
	assert_eq(builder._status_label.text, AdventureBuilder.LOOK_ONLY)


# --------------------------------------------- the card's own menu --

func test_the_card_menu_looking_only_offers_the_reader_alone() -> void:
	await _open(true)
	builder._inventory.card_bulk.emit("Lightning Bolt")
	var menu := _card_menu(builder)
	assert_not_null(menu)
	if menu == null:
		return
	assert_eq(_lines(menu), [DeckBuilderScreen.CARD_VIEW, "Cancel"], "nothing that changes a deck")
	menu.dismiss()


func test_the_card_menu_outdoors_offers_no_sale() -> void:
	await _open()
	builder._inventory.card_bulk.emit("Lightning Bolt")
	var texts := _lines(_card_menu(builder))
	assert_true(texts.has(DeckBuilderScreen.CARD_ADD_ONE))
	for text in texts:
		assert_false(String(text).begins_with("Sell"), "no town to sell to: %s" % text)
	_press(_card_menu(builder), DeckBuilderScreen.CARD_ADD_FOUR)
	assert_eq(builder.deck.count_of("Lightning Bolt"), 2, "only the copies owned")


# ------------------------------------------------- selling in a town --

const SAVES := "user://adventure_tests_p2_sell"


func _world() -> WorldScreen:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	var screen := WorldScreen.new()
	screen.record = setup.resolve({})
	add_child_autofree(screen)
	return screen


func after_each() -> void:
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _town(screen: WorldScreen) -> int:
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == ShandalarWorld.TOWN:
			return slot
	return -1


func test_in_a_town_the_card_menu_sells_and_asks_how_many() -> void:
	var screen := _world()
	await get_tree().process_frame
	for _i in 3:
		screen.player.cards.append({"card": "Shivan Dragon", "decks": []})
	var town := _town(screen)
	var sold := screen.show_deck(town)
	await get_tree().process_frame
	var price := CardShop.sell_price_at(screen.player, town, "Shivan Dragon")
	var gold := screen.player.gold
	# The starting deck may hold a Shivan Dragon of its own: it stays.
	var held := sold.deck.count_of("Shivan Dragon")
	var owned := int(AdventureBuilder.owned_counts(screen.player).get("Shivan Dragon", 0))
	assert_eq(owned - held, 3, "three outside the deck on show")
	sold._inventory.card_bulk.emit("Shivan Dragon")
	var menu := _card_menu(sold)
	assert_not_null(menu)
	if menu == null:
		return
	var line := AdventureBuilder.SELL_CARD % price
	assert_true(_lines(menu).has(line), "1997's words, the town's price")
	_press(menu, line)
	await get_tree().process_frame
	var asks: OriginalDialog = null
	for dialog in sold.open_dialogs():
		if dialog.has_meta("sell_count"):
			asks = dialog
	assert_not_null(asks, "three to sell: How many to Sell?")
	if asks == null:
		return
	assert_true(_walk(asks).any(func(node: Node) -> bool:
		return node is Label and (node as Label).text == AdventureBuilder.NUMBER_TO_SELL),
		"@NUMBERTOSELL's own question")
	var spin: SpinBox = null
	for node in _walk(asks):
		if node is SpinBox:
			spin = node
	assert_eq(int(spin.max_value), 3, "every copy outside the deck on show")
	spin.value = 2
	_press(asks, "Sell")
	assert_eq(screen.player.gold, gold + 2 * price, "two sold at the town's price")
	assert_eq(AdventureBuilder.owned_counts(screen.player).get("Shivan Dragon", 0), owned - 2,
		"one kept")
	assert_eq(sold.gold_text(), AdventureBuilder.GOLD_TITLE % screen.player.gold, "the slab at once")
	# The last copy: no question.
	sold._inventory.card_bulk.emit("Shivan Dragon")
	_press(_card_menu(sold), line)
	assert_eq(AdventureBuilder.owned_counts(screen.player).get("Shivan Dragon", 0), held,
		"the deck's own copies are never sold")
	assert_eq(screen.player.gold, gold + 3 * price)
	sold._inventory.card_bulk.emit("Shivan Dragon")
	for text in _lines(_card_menu(sold)):
		assert_false(String(text).begins_with("Sell"), "nothing left to sell: %s" % text)


func test_a_sold_card_leaves_every_deck_the_history_holds() -> void:
	var screen := _world()
	await get_tree().process_frame
	# A card the starting deck cannot hold, so every copy is the test's.
	screen.player.cards.append({"card": "Mahamoti Djinn", "decks": []})
	var town := _town(screen)
	var sold := screen.show_deck(town)
	await get_tree().process_frame
	assert_true(sold._add_one("Mahamoti Djinn"))
	sold._undo_last()
	assert_eq(sold.deck.count_of("Mahamoti Djinn"), 0)
	assert_eq(sold.sell("Mahamoti Djinn"), CardShop.sell_price_at(screen.player, town, "Mahamoti Djinn"))
	sold._redo_last()
	assert_eq(sold.deck.count_of("Mahamoti Djinn"), 0, "Redo cannot bring back a card that was sold")
