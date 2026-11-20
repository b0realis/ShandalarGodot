extends GutTest
## THE TUTOR'S LIST SHOWS ITS CARDS, AND THE ARROWS WALK EVERY SELECTION
## WINDOW (the owner, 2026-11-20): "When casting vampiric tutor. The
## selection menu should show the cards you are hovering over in big card
## on the left! Also you should be able to go through the menu with up and
## down arrow. This holds true for all selection menus in magic battles."
##
## The library picker a tutor opens before its cast (DuelScreen
## ._open_search_dialog), the question window (._build_choice_overlay) and
## the mode menu (._open_mode_menu). The keys are real key events pushed
## through the viewport, so the engine's own focus walk is what is tested.

var screen: DuelScreen


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	get_viewport().gui_release_focus()


func after_each() -> void:
	if screen != null and is_instance_valid(screen) and screen.game != null:
		screen.game.awaiting_choice = null
	get_viewport().gui_release_focus()
	CardPacks.set_enabled("pack-8", false)


func _card(pid: int, card_name: String, zone: int) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name), g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	inst.zone = zone
	match zone:
		Mtg.Zone.HAND: g.players[pid].hand.append(inst)
		Mtg.Zone.LIBRARY: g.players[pid].library.push_front(inst)
		Mtg.Zone.BATTLEFIELD: g._put_on_battlefield(inst, pid)
	return inst


func _main_phase() -> void:
	var g: MtgGame = screen.game
	g.active_player = 0
	g.priority_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))


## One key, down and up, through the viewport, as a keyboard sends it.
func _press(keycode: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	get_viewport().push_input(down)
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	get_viewport().push_input(up)
	await get_tree().process_frame


func _focused() -> Control:
	return get_viewport().gui_get_focus_owner()


func _row_of(card_name: String) -> int:
	for i in screen._search_list.item_count:
		if screen._search_list.get_item_text(i) == card_name:
			return i
	return -1


func _open_vampiric_tutor() -> CardInstance:
	_main_phase()
	_card(0, "Serra Angel", Mtg.Zone.LIBRARY)
	_card(0, "Ancestral Recall", Mtg.Zone.LIBRARY)
	var tutor := _card(0, "Vampiric Tutor", Mtg.Zone.HAND)
	screen.game.players[0].mana_pool.add(Mtg.ManaColor.B, 1)
	screen._click_hand_card(tutor)
	return tutor


# ------------------------------------------------- the tutor's large card --

func test_the_tutor_picker_shows_the_tutor_then_the_name_under_the_pointer() -> void:
	var tutor := await _open_vampiric_tutor()
	assert_not_null(screen._search_dialog, "control: the picker opens before the cast")
	var face: CardPreview = screen._search_face
	assert_not_null(face, "the picker has a large card")
	assert_true(screen._search_dialog.is_ancestor_of(face), "in the picker's own window")
	assert_eq(face._shown, tutor, "Vampiric Tutor first")
	await get_tree().process_frame
	assert_lt(face.position.x + face.size.x * face.scale.x, screen._search_list.global_position.x
		- screen._search_dialog.global_position.x + 1.0, "on the window's left, beside the list")
	var row := _row_of("Serra Angel")
	assert_gt(row, -1, "control: Serra Angel is listed")
	screen._search_list.force_update_list_size()
	var motion := InputEventMouseMotion.new()
	motion.position = screen._search_list.get_item_rect(row).get_center()
	screen._on_search_list_input(motion)
	assert_eq(face._shown.data.card_name, "Serra Angel", "the name under the pointer, big")
	screen._search_list.mouse_exited.emit()
	assert_eq(face._shown, tutor, "nothing selected: the tutor again when the pointer leaves")
	screen._search_list.select(_row_of("Ancestral Recall"))
	screen._search_list.item_selected.emit(_row_of("Ancestral Recall"))
	assert_eq(face._shown.data.card_name, "Ancestral Recall", "a selected name shows")
	screen._search_list.mouse_exited.emit()
	assert_eq(face._shown.data.card_name, "Ancestral Recall", "and stays when the pointer leaves")
	screen._on_search_canceled()


func test_the_arrows_walk_the_tutor_picker_and_enter_takes_the_row() -> void:
	var tutor := await _open_vampiric_tutor()
	assert_not_null(screen._search_dialog, "control: the picker is up")
	assert_null(_focused(), "control: nothing holds the keys")
	var face: CardPreview = screen._search_face
	await _press(KEY_DOWN)
	assert_eq(_focused(), screen._search_list, "the first Down gives the list the keys")
	assert_eq(Array(screen._search_list.get_selected_items()), [0], "on its first row")
	assert_eq(face._shown.data.card_name, screen._search_list.get_item_text(0), "the card follows")
	await _press(KEY_DOWN)
	assert_eq(Array(screen._search_list.get_selected_items()), [1], "Down steps a row")
	assert_eq(face._shown.data.card_name, screen._search_list.get_item_text(1), "the card follows")
	await _press(KEY_UP)
	assert_eq(Array(screen._search_list.get_selected_items()), [0], "Up steps back")
	var wanted := screen._search_list.get_item_text(0)
	var log_size := screen.game.log_lines.size()
	await _press(KEY_ENTER)
	assert_null(screen._search_dialog, "Enter is the OK")
	assert_eq(screen.game.priority_player, 0, "and not Done as well: the seat still holds priority")
	assert_eq(tutor.zone, Mtg.Zone.STACK, "the cast went on")
	assert_true(screen._humans[0].has_preselection(), "with the walked row parked")
	assert_eq(screen._humans[0]._preselected_name, wanted, "the row the arrows reached")
	assert_eq(screen.game.stack.size(), 1, "the tutor waits on the stack, unresolved")
	assert_gt(screen.game.log_lines.size(), log_size, "control: the cast was logged")


func test_up_first_starts_on_the_last_row() -> void:
	await _open_vampiric_tutor()
	await _press(KEY_UP)
	var last := screen._search_list.item_count - 1
	assert_eq(Array(screen._search_list.get_selected_items()), [last], "Up starts at the foot")
	screen._on_search_canceled()


func test_the_picker_takes_the_keys_from_the_clicked_card() -> void:
	_main_phase()
	var tutor := _card(0, "Vampiric Tutor", Mtg.Zone.HAND)
	screen.game.players[0].mana_pool.add(Mtg.ManaColor.B, 1)
	screen._refresh()
	await get_tree().process_frame
	var holder := Button.new()
	screen.add_child(holder)
	holder.grab_focus()
	assert_eq(_focused(), holder, "control: a table button holds the keys, as after a click")
	screen._click_hand_card(tutor)
	assert_not_null(screen._search_dialog, "control: the picker is up")
	assert_null(_focused(), "the picker took the keys off the table")
	await _press(KEY_DOWN)
	assert_eq(_focused(), screen._search_list, "so the arrow reaches the list")
	screen._on_search_canceled()
	holder.queue_free()


# --------------------------------------------------- the question window --

func _discard_question(count: int) -> Array:
	var g: MtgGame = screen.game
	var bears := _card(0, "Grizzly Bears", Mtg.Zone.HAND)
	var bolt := _card(0, "Lightning Bolt", Mtg.Zone.HAND)
	var angel := _card(0, "Serra Angel", Mtg.Zone.HAND)
	var choice := PlayerChoice.new(PlayerChoice.Kind.DISCARD, 0, "")
	choice.count = count
	choice.source = "Bazaar of Baghdad"
	choice.candidates = [bears, bolt, angel] as Array[CardInstance]
	g.awaiting_choice = choice
	screen._choice_picks = PackedInt32Array()
	screen._choice_walking = false
	screen._choice_focus = -1
	screen._build_choice_overlay(choice)
	return [bears, bolt, angel]


func _line(text: String) -> Button:
	for button: Button in screen._choice_overlay.find_children("*", "Button", true, false):
		if button.text.begins_with(text):
			return button
	return null


func _choice_face() -> CardPreview:
	var found := screen._choice_overlay.find_children("*", "CardPreview", true, false)
	return found[0] if not found.is_empty() else null


func test_the_arrows_walk_the_question_window_and_wrap() -> void:
	var cards := _discard_question(2)
	var face := _choice_face()
	assert_null(_focused(), "control: no line holds the keys as the question opens")
	await _press(KEY_SPACE)
	assert_true(screen._choice_picks.is_empty(), "a Space as it opens answers nothing")
	await _press(KEY_DOWN)
	assert_eq(_focused(), _line("1. Grizzly Bears"), "the first Down: the first line")
	assert_eq(face._shown, cards[0], "its card, big")
	await _press(KEY_DOWN)
	assert_eq(_focused(), _line("2. Lightning Bolt"), "Down steps a line")
	assert_eq(face._shown, cards[1], "the card follows")
	_line("3. Serra Angel").mouse_entered.emit()
	assert_eq(face._shown, cards[2], "the pointer still shows its own line")
	_line("3. Serra Angel").mouse_exited.emit()
	assert_eq(face._shown, cards[1], "and leaving gives back the walked line, not the source")
	await _press(KEY_UP)
	await _press(KEY_UP)
	assert_eq(_focused(), _line("3. Serra Angel"), "Up from the first wraps to the last")
	await _press(KEY_DOWN)
	assert_eq(_focused(), _line("1. Grizzly Bears"), "and Down from the last to the first")
	await _press(KEY_LEFT)
	assert_eq(_focused(), _line("1. Grizzly Bears"), "Left never leaves the window")


func test_enter_ticks_the_walked_line_and_the_redraw_keeps_the_keys() -> void:
	_discard_question(2)
	await _press(KEY_DOWN)
	await _press(KEY_DOWN)
	var step := screen.game.current_step()
	await _press(KEY_ENTER)
	assert_eq(Array(screen._choice_picks), [1], "Enter ticked the walked line")
	assert_eq(screen.game.current_step(), step, "and was nothing else")
	await get_tree().process_frame
	var ticked := _line("2. Lightning Bolt")
	assert_not_null(ticked, "control: the window redrew")
	assert_true(ticked.text.ends_with("*"), "control: with the tick")
	assert_eq(_focused(), ticked, "the keys stay on the same line after the redraw")


func test_a_clicked_line_does_not_keep_the_keys_through_a_redraw() -> void:
	_discard_question(2)
	var line := _line("2. Lightning Bolt")
	line.grab_focus()   # what a click does to a button
	line.pressed.emit()
	assert_eq(Array(screen._choice_picks), [1], "control: the click ticked it")
	await get_tree().process_frame
	assert_null(_focused(), "no line holds the keys after a click's redraw")
	await _press(KEY_SPACE)
	assert_eq(Array(screen._choice_picks), [1], "so a later Space unticks nothing")


# --------------------------------------------------------- the mode menu --

func test_the_arrows_walk_the_mode_menu() -> void:
	_main_phase()
	for i in 3: _card(0, "Plains", Mtg.Zone.BATTLEFIELD)
	var potion := _card(0, "Alabaster Potion", Mtg.Zone.HAND)
	screen._on_card_clicked(potion)
	assert_not_null(screen._mode_overlay, "control: the mode menu is up")
	var rows: Array = []
	for button: Button in screen._mode_overlay.find_children("*", "Button", true, false):
		if not button.disabled: rows.append(button)
	assert_gt(rows.size(), 2, "control: two modes and Cancel")
	await _press(KEY_DOWN)
	assert_eq(_focused(), rows[0], "the first Down: the first mode")
	await _press(KEY_DOWN)
	assert_eq(_focused(), rows[1], "Down steps a mode")
	await _press(KEY_UP)
	await _press(KEY_UP)
	assert_eq(_focused(), rows[rows.size() - 1], "Up from the first wraps to Cancel")
	var step := screen.game.current_step()
	await _press(KEY_ENTER)
	assert_null(screen._mode_overlay, "Enter on Cancel cancels")
	assert_null(screen._pending_card, "and the cast is dropped")
	assert_eq(screen.game.priority_player, 0, "and Enter was not Done too")
	assert_eq(screen.game.current_step(), step, "the step stands")


# ------------------------------------- the Sideboard window between duels --

func _sideboard_runner() -> MatchScreen:
	var config := DuelConfig.hotseat_default()
	config.best_of = 3
	config.sideboard_between_duels = true
	var deck := DeckList.load_file("res://decks/white_knights.deck", true)
	config.decks[0] = deck.cards.duplicate()
	config.sideboards[0] = deck.sideboard.duplicate()
	config.sideboards[1] = deck.sideboard.duplicate()
	var runner: MatchScreen = load("res://game/match_screen.tscn").instantiate()
	runner.config = config
	add_child_autofree(runner)
	await get_tree().process_frame
	return runner


func test_the_sideboards_keys_stay_in_the_pile_after_a_move() -> void:
	var runner := await _sideboard_runner()
	runner._open_sideboard(0)
	await get_tree().process_frame
	var rows := runner._sideboard_rows(0)
	assert_not_null(rows, "control: your deck's lines")
	var lines: Array = rows.get_children().filter(func(n: Node) -> bool: return n is Button)
	assert_gt(lines.size(), 3, "control: several names")
	(lines[2] as Control).grab_focus()
	var size := (runner.config.decks[0] as Array).size()
	await _press(KEY_ENTER)
	assert_eq((runner.config.decks[0] as Array).size(), size - 1, "Enter moved one copy")
	var held := _focused()
	assert_not_null(held, "the keys did not go with the redraw")
	assert_true(runner._sideboard_rows(0).is_ancestor_of(held), "they stay in your deck's pile")
	assert_eq(held.get_index(), 2, "on the same row")
	await _press(KEY_DOWN)
	assert_eq(_focused().get_index(), 3, "and Down walks on from there")
	assert_eq(runner._sb_preview._shown.data.card_name,
		(_focused() as Button).text.get_slice("  ", 1), "the card follows the walk")
	runner._close_sideboard()
