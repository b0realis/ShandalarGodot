extends GutTest
## THE DECK BUILDER'S POLISH (2026-10-28, the owner's "open items" round on
## the builder: *"all four — Redo + deeper undo; right-click menu on an
## Inventory card; Move by color INTO deck; the badge counts both piles (and
## the Eye medallion back)"*):
##  - Undo walks back a history and Redo forward again (Ctrl+Z, Ctrl+Y,
##    Ctrl+Shift+Z) — [method DeckBuilderScreen._undo_last];
##  - a right-click on an Inventory card opens its own mini-menu —
##    [method DeckBuilderScreen._open_card_menu];
##  - `Move by color into deck`, `@DECKSURFACE_ADVENTURE`'s first line, and
##    the basic land of a colour moving with it both ways, as the 1997 code
##    moved it — [method DeckModel.moves_with_colors];
##  - the Inventory badge counts the deck and the sideboard together, and
##    `@ABILITY`'s eye is a medallion on the strip again.

var screen: DeckBuilderScreen
var _had_layout_setting: bool
var _old_layout_setting: Variant


func before_each() -> void:
	_had_layout_setting = Settings.has_value(DeckBuilderScreen.BIG_CARDS_SETTING)
	_old_layout_setting = Settings.get_value(DeckBuilderScreen.BIG_CARDS_SETTING, true)
	Settings.set_value(DeckBuilderScreen.BIG_CARDS_SETTING, false, false)
	CardRegistry.ensure_loaded()
	screen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	if _had_layout_setting:
		Settings.set_value(DeckBuilderScreen.BIG_CARDS_SETTING, _old_layout_setting)
	else:
		Settings.clear_value(DeckBuilderScreen.BIG_CARDS_SETTING)


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


func _key(keycode: Key, shift := false) -> void:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.ctrl_pressed = true
	key.shift_pressed = shift
	key.pressed = true
	screen._unhandled_key_input(key)


# ------------------------------------------------- 1. undo and redo --

func test_undo_walks_back_several_changes_and_redo_forward_again() -> void:
	screen._add_one("Lightning Bolt")
	screen._add_playset("Giant Growth")
	screen._add_basic_land("Mountain", 10)
	assert_eq(screen.deck.total(), 15)
	screen._undo_last()
	assert_eq(screen.deck.count_of("Mountain"), 0, "the lands come out first")
	screen._undo_last()
	assert_eq(screen.deck.count_of("Giant Growth"), 0, "then the playset")
	screen._undo_last()
	assert_eq(screen.deck.total(), 0, "then the first card: three steps back")
	screen._undo_last()
	assert_string_contains(screen._status_label.text, "nothing to undo")
	screen._redo_last()
	screen._redo_last()
	assert_eq(screen.deck.count_of("Giant Growth"), 4, "Redo walks forward")
	assert_eq(screen.deck.count_of("Mountain"), 0)
	screen._redo_last()
	assert_eq(screen.deck.total(), 15, "to where the deck was")
	screen._redo_last()
	assert_string_contains(screen._status_label.text, "nothing to redo")


func test_a_new_change_after_an_undo_ends_the_redo() -> void:
	screen._add_one("Lightning Bolt")
	screen._add_one("Giant Growth")
	screen._undo_last()
	screen._add_one("Shatter")
	screen._redo_last()
	assert_string_contains(screen._status_label.text, "nothing to redo")
	assert_eq(screen.deck.count_of("Giant Growth"), 0, "the undone card stays out")
	assert_eq(screen.deck.count_of("Shatter"), 1)


func test_the_menu_names_what_undo_and_redo_would_change() -> void:
	screen._add_playset("Lightning Bolt")
	screen._undo_last()
	screen._open_mini_menu()
	var texts := _lines(screen.open_dialogs()[0])
	assert_true(texts.has("Redo Add 4 Lightning Bolt"), "Redo names the change")
	assert_true(texts.has("Undo"), "nothing older to undo")
	assert_true(DeckBuilderScreen.EXTRA_COMMANDS.has("Redo"), "a [QoL] command of its own")


func test_ctrl_y_and_ctrl_shift_z_redo_and_ctrl_z_undoes() -> void:
	screen._add_one("Lightning Bolt")
	_key(KEY_Z)
	assert_eq(screen.deck.total(), 0, "Ctrl+Z")
	_key(KEY_Y)
	assert_eq(screen.deck.total(), 1, "Ctrl+Y")
	_key(KEY_Z)
	_key(KEY_Z, true)
	assert_eq(screen.deck.total(), 1, "Ctrl+Shift+Z is Redo, not a second Undo")
	assert_eq(DeckBuilderScreen.SHORTCUTS[KEY_Y], "Redo")


func test_the_history_keeps_a_hundred_steps() -> void:
	for _i in DeckBuilderScreen.UNDO_DEPTH + 5:
		screen._add_one("Mountain")
	for _i in DeckBuilderScreen.UNDO_DEPTH:
		screen._undo_last()
	assert_eq(screen.deck.count_of("Mountain"), 5, "a hundred steps back")
	screen._undo_last()
	assert_string_contains(screen._status_label.text, "nothing to undo", "and no further")


func test_a_slot_switch_starts_the_history_afresh() -> void:
	screen._add_one("Lightning Bolt")
	screen._switch_slot(1)
	screen._undo_last()
	assert_string_contains(screen._status_label.text, "nothing to undo")
	screen._redo_last()
	assert_string_contains(screen._status_label.text, "nothing to redo")


# ------------------------------------- 2. the Inventory card's menu --

func _card_menu() -> OriginalDialog:
	for dialog in screen.open_dialogs():
		if dialog.has_meta("card_menu"):
			return dialog
	return null


func test_a_right_click_on_an_inventory_card_opens_its_menu() -> void:
	screen._inventory.card_bulk.emit("Lightning Bolt")
	var menu := _card_menu()
	assert_not_null(menu, "the card's own mini-menu")
	if menu == null:
		return
	assert_eq(menu.get_meta("card_menu"), "Lightning Bolt")
	var texts := _lines(menu)
	for line in [DeckBuilderScreen.CARD_ADD_ONE, DeckBuilderScreen.CARD_ADD_FOUR,
			DeckBuilderScreen.CARD_VIEW, "Cancel"]:
		assert_true(texts.has(line), line)
	assert_false(texts.has(DeckBuilderScreen.CARD_TAKE_ONE), "nothing to take out yet")
	assert_eq(screen.deck.total(), 0, "the right-click alone adds nothing")
	assert_eq(screen._showcase._shown.data.card_name, "Lightning Bolt", "the card it is about")
	_press(menu, DeckBuilderScreen.CARD_ADD_FOUR)
	assert_eq(screen.deck.count_of("Lightning Bolt"), 4, "Add 4")
	assert_null(_card_menu(), "closed on the pick")


func test_the_menu_adds_one_and_takes_back() -> void:
	screen._inventory.card_bulk.emit("Lightning Bolt")
	_press(_card_menu(), DeckBuilderScreen.CARD_ADD_ONE)
	assert_eq(screen.deck.count_of("Lightning Bolt"), 1, "Add 1")
	screen._add_one("Lightning Bolt")
	screen._inventory.card_bulk.emit("Lightning Bolt")
	var texts := _lines(_card_menu())
	assert_true(texts.has(DeckBuilderScreen.CARD_TAKE_ONE), "the deck holds it now")
	assert_true(texts.has(DeckBuilderScreen.CARD_TAKE_ALL))
	_press(_card_menu(), DeckBuilderScreen.CARD_TAKE_ONE)
	assert_eq(screen.deck.count_of("Lightning Bolt"), 1, "Take 1 out")
	screen._inventory.card_bulk.emit("Lightning Bolt")
	_press(_card_menu(), DeckBuilderScreen.CARD_TAKE_ALL)
	assert_eq(screen.deck.count_of("Lightning Bolt"), 0, "Take all out")


func test_view_large_opens_the_reader_on_the_card() -> void:
	screen._inventory.card_bulk.emit("Shivan Dragon")
	_press(_card_menu(), DeckBuilderScreen.CARD_VIEW)
	assert_true(screen._fullscreen_card.is_open(), "the full-screen reader")
	assert_eq(screen._fullscreen_card._card._shown.data.card_name, "Shivan Dragon")
	screen._fullscreen_card.dismiss()


func test_one_menu_at_a_time() -> void:
	screen._inventory.card_bulk.emit("Lightning Bolt")
	screen._inventory.card_bulk.emit("Giant Growth")
	assert_eq(screen.open_dialogs().size(), 1, "rapid right-clicks do not stack menus")


# ------------------------------------------ 3. move by color into deck --

func test_move_by_color_into_deck_is_on_the_menu() -> void:
	assert_true(DeckBuilderScreen.MENU_COMMANDS.has("Move by color into deck"),
		"@DECKSURFACE_ADVENTURE's first line")
	screen._run_command("Move by color into deck")
	var dialog := screen.open_dialogs()[0]
	assert_eq(dialog.get_meta("group_move"), "into")
	for entry in DeckBuilderScreen.GROUP_MOVE:
		assert_true(_lines(dialog).has("[  ] %s" % String(entry[0])), String(entry[0]))
	dialog.dismiss()


func test_over_the_library_it_puts_in_one_of_each_card_the_inventory_shows() -> void:
	screen.filter.text = "Lightning Bolt"
	screen._refresh_inventory()
	screen._move_in_by_color([Mtg.ManaColor.R])
	assert_eq(screen.deck.count_of("Lightning Bolt"), 1, "one copy of the card in view")
	assert_eq(screen.deck.total(), 1, "nothing the Inventory did not show")
	screen.filter.text = "Mountain"
	screen._refresh_inventory()
	var offered := screen._group_move_candidates([Mtg.ManaColor.R]).map(
		func(entry: Array) -> String: return String(entry[0]))
	assert_false(offered.has("Mountain"), "the library's lands are Add basic land's")
	screen.filter.text = "Lightning Bolt"
	screen._refresh_inventory()
	screen._move_in_by_color([Mtg.ManaColor.R])
	assert_eq(screen.deck.count_of("Lightning Bolt"), 1, "not again: the deck holds it")
	screen._undo_last()
	assert_eq(screen.deck.total(), 0, "one undo step")


func test_under_a_pool_every_copy_of_the_colour_goes_in() -> void:
	var pool := SealedPool.new()
	pool.counts = {"Lightning Bolt": 3, "Mountain": 30, "Giant Growth": 2, "Forest": 30,
		"Shatter": 1}
	screen._enter_sealed(pool)
	screen._add_one("Lightning Bolt")
	screen._move_in_by_color([Mtg.ManaColor.R])
	assert_eq(screen.deck.count_of("Lightning Bolt"), 3, "every copy left")
	assert_eq(screen.deck.count_of("Shatter"), 1)
	assert_eq(screen.deck.count_of("Mountain"), 0,
		"a pool's free lands stay for Add basic land, not thirty at a stroke")
	assert_eq(screen.deck.count_of("Giant Growth"), 0, "no other colour")
	screen._leave_sealed()


func test_out_of_deck_takes_the_colour_s_basic_land_too() -> void:
	# `move_colors_fromto_global_deck` moves the Mountain with Red — the
	# builder used to leave every land behind.
	for card_name in ["Lightning Bolt", "Giant Growth"]:
		for _i in 4:
			screen._add_one(card_name)
	screen._add_basic_land("Mountain", 10)
	screen._add_basic_land("Forest", 6)
	screen._move_out_by_color([Mtg.ManaColor.R])
	assert_eq(screen.deck.count_of("Lightning Bolt"), 0)
	assert_eq(screen.deck.count_of("Mountain"), 0, "red's land went with red")
	assert_eq(screen.deck.count_of("Giant Growth"), 4)
	assert_eq(screen.deck.count_of("Forest"), 6, "green's stayed")


func test_a_land_that_is_not_basic_moves_with_no_colour() -> void:
	assert_false(DeckModel.moves_with_colors("Volcanic Island", [Mtg.ManaColor.R, Mtg.ManaColor.U, 0]))
	assert_false(DeckModel.moves_with_colors("Strip Mine", [0]), "colourless, but a land")
	assert_true(DeckModel.moves_with_colors("Sol Ring", [0]), "Artifact: the colourless cards")
	assert_true(DeckModel.moves_with_colors("Plains", [Mtg.ManaColor.W]))
	assert_false(DeckModel.moves_with_colors("Plains", [Mtg.ManaColor.G]))


func test_a_colour_with_nothing_to_move_is_greyed() -> void:
	# 1997 lit only the colours there was something to move
	# (`check_colors_inout_edited_deck`).
	for _i in 4:
		screen._add_one("Lightning Bolt")
	screen._run_command("Move by color out of deck")
	var dialog := screen.open_dialogs()[0]
	for node in _walk(dialog):
		if node is Button and node.text == "[  ] Red":
			assert_false(node.disabled, "the deck holds red")
		elif node is Button and node.text == "[  ] Blue":
			assert_true(node.disabled, "and no blue")
	dialog.dismiss()


# ---------------------------------------- 4. the badge and the eye --

func _bolt_cell() -> CardArea.Cell:
	screen.filter.text = "Lightning Bolt"
	screen._refresh_inventory()
	for cell in screen._inventory.cell_nodes():
		if cell.visible and cell.card_name == "Lightning Bolt":
			return cell
	return null


func test_the_inventory_badge_counts_both_piles() -> void:
	screen._add_one("Lightning Bolt")
	screen._add_one_side("Lightning Bolt")
	screen._add_one_side("Lightning Bolt")
	var cell := _bolt_cell()
	assert_not_null(cell)
	if cell == null:
		return
	assert_true(cell.badge.visible)
	assert_eq(cell.badge_label.text, "3", "one in the deck and two in the sideboard")
	screen._remove_one("Lightning Bolt")
	assert_eq(cell.badge_label.text, "2", "a sideboard alone still badges")


func test_the_eye_is_back_on_the_strip_as_the_1997_ability_switch() -> void:
	var others: Array = screen._filter_bar.group_buttons("Other Filters")
	assert_eq(others.size(), 5, "cost, power, toughness, the eye and the funnel")
	var eye: Button = others[3]
	assert_eq(eye.get_meta("icon_cell"), FilterBar.ABILITY_CELL, "the 1997 eye")
	assert_eq(eye.get_meta("cue"), "ability")
	assert_eq(others[4].get_meta("icon_cell"), FilterBar.FUNNEL_CELL, "the funnel still closes the group")
	assert_false(eye.button_pressed, "up at rest")
	var whole := screen._inventory.entry_count()
	eye.pressed.emit()
	assert_true(screen.filter.ability_on, "a click is the filter's switch")
	assert_true(eye.button_pressed, "lit while it is on")
	assert_lt(screen._inventory.entry_count(), whole, "only the cards with an ability")
	eye.pressed.emit()
	assert_eq(screen._inventory.entry_count(), whole, "and off again")


func test_the_eye_s_right_click_opens_the_abilities_page() -> void:
	var eye: Button = screen._filter_bar.group_buttons("Other Filters")[3]
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	eye.gui_input.emit(click)
	await get_tree().process_frame
	assert_eq(screen._window_page, "abilities", "its own page of the Filters window")
	for dialog in screen.open_dialogs():
		dialog.dismiss()


func test_the_strip_still_fits_the_window_the_game_opens_in() -> void:
	assert_lte(screen._filter_bar.get_combined_minimum_size().x, 1280.0,
		"twenty-five medallions and the tail")


func test_the_longer_mini_menu_still_needs_no_scroll_at_1280_by_800() -> void:
	# Two more lines (Redo, Move by color into deck) took it to 26: a 4px gap
	# put it past the window's margin and behind a scroll.
	screen.size = Vector2(1280, 800)
	screen._open_mini_menu()
	await get_tree().process_frame
	var dialog := screen.open_dialogs()[0]
	assert_null(dialog.find_child("BodyScroll", true, false), "every line in view")
	assert_lte(dialog.size.y, 800.0 - 2 * OriginalDialog.SCREEN_MARGIN)
	dialog.dismiss()
