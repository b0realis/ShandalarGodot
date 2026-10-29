extends GutTest
## THE DECK BUILDER'S FIXES OF THE 0.50.65 BUG CAMPAIGN (c19, group F2):
##  - k2-1 `Restore deck` is a step of the history: Undo after it puts back
##    the deck it replaced, not an empty one, and Redo starts empty — in the
##    builder, after a fresh sealed deal and in the adventure's builder
##    ([method DeckBuilderScreen._restore_deck]);
##  - k2-2 the mini-menu's Undo and Redo lines keep to one row, so Cancel
##    stays on the stone ([method DeckBuilderScreen._open_mini_menu]);
##  - k2-3 a step a sale left changing nothing is dropped
##    ([method DeckBuilderScreen._drop_idle_steps]);
##  - k6-4 the adventure builder's Rarity filter files Restricted and Banned
##    by the Embark's ban list under the Classic MTG rules
##    ([member DeckFilter.ban_list]);
##  - k2-4 Enter in "How many to Sell?" sells ([method AdventureBuilder._ask_sell]).

var _had_layout_setting: bool
var _old_layout_setting: Variant


func before_each() -> void:
	_had_layout_setting = Settings.has_value(DeckBuilderScreen.BIG_CARDS_SETTING)
	_old_layout_setting = Settings.get_value(DeckBuilderScreen.BIG_CARDS_SETTING, true)
	Settings.set_value(DeckBuilderScreen.BIG_CARDS_SETTING, false, false)
	CardRegistry.ensure_loaded()


func after_each() -> void:
	if _had_layout_setting:
		Settings.set_value(DeckBuilderScreen.BIG_CARDS_SETTING, _old_layout_setting)
	else:
		Settings.clear_value(DeckBuilderScreen.BIG_CARDS_SETTING)
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _screen() -> DeckBuilderScreen:
	var screen: DeckBuilderScreen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	return screen


func _walk(node: Node) -> Array:
	var out := [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out


# --------------------------------------------- k2-1: Restore is a step --

func test_undo_after_restore_puts_back_the_deck_restore_replaced() -> void:
	var screen := await _screen()
	screen._add_playset("Lightning Bolt")
	screen._add_playset("Shivan Dragon")
	assert_eq(screen.deck.total(), 8)
	screen._clear_deck()
	screen._add_one("Giant Growth")
	screen._clear_deck()    # Restore deck
	assert_eq(screen.deck.total(), 8, "the cleared deck is back")
	assert_eq(screen._undo_menu_label(), "Undo Restore deck", "the step Undo would take back")
	screen._undo_last()
	assert_eq(screen.deck.total(), 1, "the deck as it was just before Restore")
	assert_eq(screen.deck.count_of("Giant Growth"), 1)
	assert_string_contains(screen._status_label.text, "Undone: Restore deck")
	screen._redo_last()
	assert_eq(screen.deck.total(), 8, "Redo restores it again")
	assert_eq(screen.deck.count_of("Giant Growth"), 0)


func test_restore_ends_whatever_redo_held() -> void:
	var screen := await _screen()
	screen._add_playset("Lightning Bolt")
	screen._clear_deck()
	screen._add_one("Giant Growth")
	screen._add_one("Shatter")
	screen._undo_last()    # Shatter waits for Redo
	screen._clear_deck()    # Restore deck
	screen._redo_last()
	assert_string_contains(screen._status_label.text, "nothing to redo")
	assert_eq(screen.deck.total(), 4, "the restored deck stays as it is")
	assert_eq(screen.deck.count_of("Shatter"), 0)


func test_restore_after_a_fresh_sealed_deal_is_a_step_too() -> void:
	var screen := await _screen()
	var pool := SealedPool.new()
	pool.counts = {"Lightning Bolt": 4, "Mountain": 30, "Giant Growth": 4, "Forest": 30}
	screen._enter_sealed(pool)
	screen._add_playset("Lightning Bolt")
	screen._add_playset("Giant Growth")
	var fresh := SealedPool.new()
	fresh.counts = {"Lightning Bolt": 4, "Mountain": 30, "Giant Growth": 4, "Forest": 30}
	screen._enter_sealed(fresh, true)
	assert_eq(screen.deck.total(), 0, "a fresh deal clears the deck")
	screen._add_one("Giant Growth")
	screen._clear_deck()    # Restore deck
	assert_eq(screen.deck.total(), 8)
	screen._undo_last()
	assert_eq(screen.deck.total(), 1, "back to the one card, not to an empty deck")
	assert_eq(screen.deck.count_of("Giant Growth"), 1)
	screen._leave_sealed()


func _hero() -> AdventurePlayer:
	var hero := AdventurePlayer.new()
	hero.gold = 275
	hero.difficulty = 1
	for card_name in ["Grizzly Bears", "Grizzly Bears", "Giant Growth", "Forest", "Forest", "Forest",
			"Llanowar Elves"]:
		hero.cards.append({"card": card_name, "decks": [0]})
	for card_name in ["Shivan Dragon", "Lightning Bolt", "Lightning Bolt", "Mountain", "Mountain",
			"Forest", "Giant Growth", "Mind Twist", "Mana Vault", "Jihad"]:
		hero.cards.append({"card": card_name, "decks": []})
	return hero


func _builder(hero: AdventurePlayer) -> AdventureBuilder:
	var builder := AdventureBuilder.new()
	builder.player = hero
	add_child_autofree(builder)
	await get_tree().process_frame
	return builder


func test_the_adventure_builder_s_restore_is_a_step() -> void:
	var builder := await _builder(_hero())
	assert_eq(builder.deck.total(), 7, "Deck1 as the hero keeps it")
	builder._clear_deck()
	builder._add_one("Lightning Bolt")
	builder._clear_deck()    # Restore deck
	assert_eq(builder.deck.total(), 7)
	builder._undo_last()
	assert_eq(builder.deck.total(), 1, "the deck just before Restore, not an empty one")
	assert_eq(builder.deck.count_of("Lightning Bolt"), 1)
	builder._redo_last()
	assert_eq(builder.deck.total(), 7, "and Redo brings the restored deck back")


# ------------------------------------- k2-2: one row for Undo and Redo --

func test_long_undo_and_redo_lines_keep_cancel_on_the_stone() -> void:
	var screen := await _screen()
	screen.size = Vector2(1280, 800)
	var cop := "Circle of Protection: Artifacts"
	screen._add_one_side(cop)
	screen._add_one_side(cop)
	screen._remove_all_side(cop)
	screen._undo_last()
	screen._open_mini_menu()
	await get_tree().process_frame
	await get_tree().process_frame
	var dialog: OriginalDialog = screen.open_dialogs()[0]
	var stone := dialog.get_global_rect()
	var undo_words := "Undo Add %s to the sideboard" % cop
	var redo_words := "Redo Remove all %s from the sideboard" % cop
	var found := 0
	for node in _walk(dialog):
		if not node is Button:
			continue
		var line := node as Button
		assert_true(stone.encloses(line.get_global_rect()),
			"'%s' on the stone: %s in %s" % [line.text, line.get_global_rect(), stone])
		if line.text == undo_words or line.text == redo_words:
			found += 1
			assert_eq(line.autowrap_mode, TextServer.AUTOWRAP_OFF, "one row: %s" % line.text)
			assert_eq(line.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS)
			assert_eq(line.tooltip_text, line.text, "the whole words on the tooltip")
			assert_lt(line.size.y, 30.0, "one row high: %s" % line.size)
	assert_eq(found, 2, "both lines name their change")
	dialog.dismiss()


func test_a_bare_undo_line_has_no_tooltip() -> void:
	var screen := await _screen()
	screen._open_mini_menu()
	await get_tree().process_frame
	var dialog: OriginalDialog = screen.open_dialogs()[0]
	for node in _walk(dialog):
		if node is Button and (node.text == "Undo" or node.text == "Redo"):
			assert_eq(node.tooltip_text, "", "nothing more to say than the word")
	dialog.dismiss()


# -------------------------------- k2-3: no step that changes nothing --

const SAVES := "user://adventure_tests_c19_f2"


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


func _town(screen: WorldScreen) -> int:
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == ShandalarWorld.TOWN:
			return slot
	return -1


func test_a_redo_the_sale_emptied_is_dropped() -> void:
	var screen := _world()
	await get_tree().process_frame
	screen.player.cards.append({"card": "Mahamoti Djinn", "decks": []})
	var sold := screen.show_deck(_town(screen))
	await get_tree().process_frame
	var total := sold.deck.total()
	assert_true(sold._add_one("Mahamoti Djinn"))
	sold._undo_last()
	assert_gt(sold.sell("Mahamoti Djinn"), 0)
	assert_eq(sold._redo_menu_label(), "Redo", "no change left for Redo to name")
	sold._redo_last()
	assert_string_contains(sold._status_label.text, "nothing to redo",
		"not 'Redone: Add Mahamoti Djinn' over an unchanged deck")
	assert_eq(sold.deck.total(), total)


func test_undo_steps_the_sale_emptied_are_dropped_and_the_rest_kept() -> void:
	var screen := _world()
	await get_tree().process_frame
	screen.player.cards.append({"card": "Mahamoti Djinn", "decks": []})
	screen.player.cards.append({"card": "Mountain", "decks": []})
	var sold := screen.show_deck(_town(screen))
	await get_tree().process_frame
	var total := sold.deck.total()
	assert_true(sold._add_one("Mahamoti Djinn"))
	sold._remove_one("Mahamoti Djinn")
	assert_true(sold._add_one("Mountain"))
	assert_gt(sold.sell("Mahamoti Djinn"), 0)
	assert_eq(sold._undo_menu_label(), "Undo Add Mountain", "the land is still a change")
	sold._undo_last()
	assert_eq(sold.deck.total(), total, "the Mountain taken back")
	sold._undo_last()
	assert_string_contains(sold._status_label.text, "nothing to undo",
		"the Djinn's two steps went with the Djinn")
	sold._redo_last()
	assert_string_contains(sold._status_label.text, "Redone: Add Mountain")
	assert_eq(sold.deck.total(), total + 1)


func test_same_as_reads_every_field_undo_keeps() -> void:
	var deck := DeckModel.new()
	deck.add("Lightning Bolt")
	assert_true(deck.same_as(deck.duplicate_model()))
	var renamed := deck.duplicate_model()
	renamed.deck_name = "Burn"
	assert_false(deck.same_as(renamed), "a rename is a change")
	var noted := deck.duplicate_model()
	noted.notes = "fast"
	assert_false(deck.same_as(noted), "so are the notes")
	var side := deck.duplicate_model()
	side.add_side("Shatter")
	assert_false(deck.same_as(side), "and the sideboard")
	var more := deck.duplicate_model()
	more.add("Lightning Bolt")
	more.remove("Lightning Bolt")
	assert_true(deck.same_as(more), "the same cards by another road")
	assert_false(deck.same_as(null))


# ------------------------------- k6-4: the Rarity filter's ban list --

## Only [param kind] ticked, the filter on.
func _only(filter: DeckFilter, kind: int) -> void:
	filter.rarity_on = true
	for each in DeckFilter.Rarity.values():
		filter.tick_rarity(each, each == kind)


func test_under_classic_rules_the_rarity_filter_files_by_the_embark_s_list() -> void:
	var hero := _hero()
	hero.card_rule = AdventurePlayer.RULE_CLASSIC
	hero.ban_list = ClassicBans.OLD
	var builder := await _builder(hero)
	var twist := CardRegistry.get_card("Mind Twist")
	var vault := CardRegistry.get_card("Mana Vault")
	_only(builder.filter, DeckFilter.Rarity.BANNED)
	assert_true(builder.filter.matches_rarity(twist),
		"1998 bans Mind Twist: under Banned, as the Extra Cards box judges it")
	builder._refresh_inventory()
	var shown: Array = []
	for cell in builder._inventory.cell_nodes():
		if cell.visible:
			shown.append(cell.card_name)
	assert_true(shown.has("Mind Twist"), "the Inventory shows it under Banned: %s" % [shown])
	_only(builder.filter, DeckFilter.Rarity.RESTRICTED)
	assert_false(builder.filter.matches_rarity(twist), "not Restricted as well")
	assert_false(builder.filter.matches_rarity(vault), "1998 frees Mana Vault")


func test_the_modern_list_bans_the_2020_cards() -> void:
	var hero := _hero()
	hero.card_rule = AdventurePlayer.RULE_CLASSIC
	hero.ban_list = ClassicBans.MODERN
	var builder := await _builder(hero)
	_only(builder.filter, DeckFilter.Rarity.BANNED)
	assert_true(builder.filter.matches_rarity(CardRegistry.get_card("Jihad")), "banned in 2020")


func test_without_classic_rules_and_outside_the_adventure_the_tournament_lists_stay() -> void:
	assert_true(DeckFormat.RESTRICTED.has("Mind Twist"), "the tournament lists restrict it")
	var twist := CardRegistry.get_card("Mind Twist")
	var builder := await _builder(_hero())
	_only(builder.filter, DeckFilter.Rarity.RESTRICTED)
	assert_true(builder.filter.matches_rarity(twist), "1997's copy rule: the tournament lists")
	var screen := await _screen()
	screen.filter.reset()
	_only(screen.filter, DeckFilter.Rarity.RESTRICTED)
	assert_true(screen.filter.matches_rarity(twist), "the builder's own, as before")


# --------------------------------------------- k2-4: Enter sells --

func _sell_dialog(of: DeckBuilderScreen) -> OriginalDialog:
	for dialog in of.open_dialogs():
		if dialog.has_meta("sell_count"):
			return dialog
	return null


func _enter(pressed: bool) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.physical_keycode = KEY_ENTER
	key.pressed = pressed
	return key


func test_enter_in_how_many_to_sell_sells_the_number_typed() -> void:
	var screen := _world()
	await get_tree().process_frame
	for _i in 3:
		screen.player.cards.append({"card": "Shivan Dragon", "decks": []})
	var town := _town(screen)
	var sold := screen.show_deck(town)
	await get_tree().process_frame
	var price := CardShop.sell_price_at(screen.player, town, "Shivan Dragon")
	var gold := screen.player.gold
	var owned := int(AdventureBuilder.owned_counts(screen.player).get("Shivan Dragon", 0))
	sold._ask_sell("Shivan Dragon")
	await get_tree().process_frame
	var asks := _sell_dialog(sold)
	assert_not_null(asks, "How many to Sell?")
	if asks == null:
		return
	var field: LineEdit = null
	for node in _walk(asks):
		if node is SpinBox:
			field = (node as SpinBox).get_line_edit()
	assert_eq(get_viewport().gui_get_focus_owner(), field, "the number has the keyboard")
	field.text = "2"
	get_viewport().push_input(_enter(true))
	get_viewport().push_input(_enter(false))
	await get_tree().process_frame
	assert_eq(screen.player.gold, gold + 2 * price, "Enter sold the two typed")
	assert_eq(int(AdventureBuilder.owned_counts(screen.player).get("Shivan Dragon", 0)), owned - 2)
	assert_null(_sell_dialog(sold), "and closed the question")
