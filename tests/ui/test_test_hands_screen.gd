extends GutTest
## TEST HANDS — the screen (`game/test_hands_screen.gd`), its door on the
## Magic Battle screen, and the test duel it starts (2026-10-19). The
## engine half is `tests/unit/test_duel_position.gd`.
##
## What these pin:
##   1. `Test hands` sits at the BOTTOM of the Magic Battle screen, in the
##      pinned action row between `Back` and `Go!`, and it carries the
##      seats, decks and pilots that screen chose (remembering them as
##      `Go!` does);
##   2. the card picker lists the seat's deck with the copies left, stops
##      at the deck's count, and with `Any card in the pool` adds a card the
##      deck lacks — marked on the seat's list;
##   3. the table rows set tapped and sick, the × takes a card out, and
##      whose turn and the step are set by their controls;
##   4. `Go test!` starts the duel IN THE CHOSEN TURN: the hands exactly as
##      set, the table and the graveyard as set, no opening deal, no
##      mulligan, no splash, no coin toss, no ante, no running duel log —
##      and the test is remembered and reopens;
##   5. a saved test loads back and deletes;
##   6. the test duel's Pause window offers `Restart test` and `Edit test`;
##      Restart is the same test on the same seed; Edit returns to the
##      bench with the position; the table says it is a test;
##   7. a position the pool cannot play is refused before any duel;
##   8. Escape puts the picker away before it leaves the screen;
##   9. `Show both hands` opens the computer's hand on the table.

var bench: TestHandsScreen
## Screens a handover put beside this test (the duel, the bench again),
## freed with it.
var _handed: Array[Node] = []


func _config() -> DuelConfig:
	# White Knights (Seat 1, the player) against Slan's Raiders (Seat 2,
	# the computer) — the starter decks, every name in the base pool.
	var config := DuelConfig.vs_ai_default(AiProfile.wizard())
	config.player_names[0] = "Tester"
	config.deck_names[0] = "White Knights"
	config.deck_names[1] = "Slan's Raiders"
	return config


func _bench(config: DuelConfig = null) -> TestHandsScreen:
	var screen: TestHandsScreen = load("res://game/test_hands_screen.tscn").instantiate()
	screen.config = config if config != null else _config()
	add_child_autofree(screen)
	return screen


func before_each() -> void:
	Settings.clear_value(TestHandsScreen.LAST_KEY)
	Settings.clear_value(TestHandsScreen.SAVED_KEY)
	bench = _bench()
	await get_tree().process_frame


func after_each() -> void:
	for node in _handed:
		if is_instance_valid(node):
			node.queue_free()
	_handed.clear()
	Settings.clear_value(TestHandsScreen.LAST_KEY)
	Settings.clear_value(TestHandsScreen.SAVED_KEY)
	SetupScreen.forget_choices()
	await get_tree().process_frame


func _names(cards: Array) -> Array[String]:
	var out: Array[String] = []
	for inst in cards:
		out.append((inst as CardInstance).data.card_name)
	return out


## The position the duel tests use: Wrath of God in the hand alone, a
## tapped Plains and the Lions on the table, an Angel in the graveyard;
## the computer a random seven; the player's first main phase.
func _set_up_a_test() -> void:
	bench.add_card(0, DuelPosition.HAND, "Wrath of God")
	bench.add_card(0, DuelPosition.TABLE, "Plains")
	bench.test_position.set_tapped(0, 0, true)
	bench.add_card(0, DuelPosition.TABLE, "Savannah Lions")
	bench.add_card(0, DuelPosition.GRAVEYARD, "Serra Angel")
	bench.test_position.random_cards[0] = 0
	bench.test_position.random_cards[1] = 7
	bench.test_position.active_player = 0
	bench.test_position.step = Mtg.Step.MAIN1


## `Go test!`, and the duel it started.
func _go() -> DuelScreen:
	var started: Array[Node] = []
	bench.test_started.connect(func(duel: Control) -> void: started.append(duel))
	bench.go_test()
	assert_eq(started.size(), 1, "Go test! started one duel")
	if started.is_empty():
		return null
	_handed.append(started[0])
	return started[0] as DuelScreen


func _handover(duel: DuelScreen, action: Callable) -> Node:
	var next: Array[Node] = []
	duel.handed_over.connect(func(screen: Control) -> void: next.append(screen))
	action.call()
	assert_eq(next.size(), 1, "one screen took over")
	if next.is_empty():
		return null
	_handed.append(next[0])
	return next[0]


# ================================== 1. the door on the Magic Battle screen --

func test_test_hands_sits_at_the_bottom_of_the_magic_battle_screen() -> void:
	var setup: SetupScreen = load("res://game/setup_screen.tscn").instantiate()
	add_child_autofree(setup)
	await get_tree().process_frame
	# The owner moved it (2026-10-19): "move it to the botom of menu under
	# all ante settings - we can also write there to the right the purpose".
	var labels: Array[String] = []
	for child in setup._action_row.get_children():
		if child is Button:
			labels.append((child as Button).text)
	assert_eq(labels, ["Back", "Go!"] as Array[String],
		"the pinned row is the two ways out again")
	var row: Node = setup._test_hands_button.get_parent()
	assert_eq(row.get_parent(), setup._panel_content, "in the scrolled settings")
	assert_eq(row.get_index(), setup._panel_content.get_child_count() - 1,
		"their last row: the bottom of the menu")
	assert_gt(row.get_index(), setup._sideboard_check.get_index(),
		"under the ante and match settings")
	var purpose := row.get_child(setup._test_hands_button.get_index() + 1) as Label
	assert_not_null(purpose, "a sentence to the button's right")
	if purpose != null:
		assert_eq(purpose.text, SetupScreen.TEST_HANDS_PURPOSE)
		assert_string_contains(purpose.text, "combo", "it says what it is for")
	assert_ne(setup._test_hands_button.tooltip_text, "", "it says what it does")


func test_test_hands_carries_the_seats_and_decks_magic_battle_chose() -> void:
	var setup: SetupScreen = load("res://game/setup_screen.tscn").instantiate()
	add_child_autofree(setup)
	await get_tree().process_frame
	setup._apply_mode(SetupScreen.BattleMode.VS_AI)
	# Two decks the screen would play (a listed deck may need a pack).
	assert_gt(setup._playable_paths.size(), 1, "control: two playable decks")
	var paths: Array[String] = []
	for pid in 2:
		var picker: OptionButton = setup._deck_options[pid]
		picker.select(SetupScreen._row_of_metadata(picker, setup._playable_paths[pid]))
		paths.append(str(picker.get_selected_metadata()))
	var opened: Array[Node] = []
	setup.test_hands_opened.connect(func(next: Control) -> void: opened.append(next))
	setup._open_test_hands()
	assert_eq(opened.size(), 1, "the Test hands screen opened")
	if opened.is_empty():
		return
	_handed.append(opened[0])
	var next := opened[0] as TestHandsScreen
	assert_not_null(next)
	await get_tree().process_frame
	for pid in 2:
		assert_eq(next.config.decks[pid], DeckList.load_file(paths[pid], true).cards,
			"seat %d plays the deck Magic Battle chose" % (pid + 1))
	assert_false(next.config.is_ai(0), "you in Seat 1")
	assert_true(next.config.is_ai(1), "the computer in Seat 2")
	assert_eq(str(Settings.get_value(SetupScreen.REMEMBER_PREFIX + "deck_0", "")), paths[0],
		"Magic Battle remembers the choices a test was made with, as Go! does")


# ========================================================== 2. the picker --

func test_the_picker_lists_the_deck_with_the_copies_left() -> void:
	bench.open_picker(0, DuelPosition.HAND)
	assert_true(bench.picker_open())
	bench._picker_search.text = "serra"
	bench._fill_picker()
	assert_eq(bench._picker_list.item_count, 1, "White Knights holds one name with 'serra'")
	assert_string_contains(bench._picker_list.get_item_text(0), "Serra Angel")
	assert_string_contains(bench._picker_list.get_item_text(0), "×2 left")
	bench._add_picked()
	bench._add_picked()
	assert_eq(bench.test_position.names_in(0, DuelPosition.HAND),
		["Serra Angel", "Serra Angel"] as Array[String])
	assert_true(bench._picker_list.is_item_disabled(0), "the deck has no Angel left")
	bench._add_picked()
	assert_eq(bench.test_position.names_in(0, DuelPosition.HAND).size(), 2,
		"from the deck alone, no third copy")
	bench.close_picker()
	assert_false(bench.picker_open())


func test_any_card_in_the_pool_adds_an_extra_and_the_list_marks_it() -> void:
	bench.open_picker(0, DuelPosition.TABLE)
	bench._picker_any.button_pressed = true
	bench._picker_search.text = "Ashnod's Altar"
	bench._fill_picker()
	assert_gt(bench._picker_list.item_count, 0, "the pool holds the Altar")
	bench._picker_list.select(0)
	bench._add_picked()
	assert_eq(bench.test_position.names_in(0, DuelPosition.TABLE),
		["Ashnod's Altar"] as Array[String])
	bench.close_picker()
	var marked := false
	for node in bench._seat_lists[0].find_children("*", "Label", true, false):
		var text := (node as Label).text
		if text.contains("Ashnod's Altar") and text.contains(TestHandsScreen.EXTRA_MARK):
			marked = true
	assert_true(marked, "the seat's list says the Altar is not from the deck")


# ===================================================== 3. the rows, the turn --

func test_the_table_rows_set_tapped_and_sick_and_the_cross_removes() -> void:
	bench.add_card(0, DuelPosition.TABLE, "Plains")
	bench.add_card(0, DuelPosition.TABLE, "Savannah Lions")
	var boxes := bench._seat_lists[0].find_children("*", "CheckBox", true, false)
	assert_eq(boxes.size(), 4, "Tapped and Sick on each table row")
	if boxes.size() == 4:
		assert_false((boxes[1] as CheckBox).visible, "a land shows no Sick box")
		assert_true((boxes[3] as CheckBox).visible, "a creature does")
		(boxes[0] as CheckBox).button_pressed = true
		(boxes[3] as CheckBox).button_pressed = true
	assert_true(bool(bench.test_position.table_entry(0, 0)["tapped"]), "the Plains is tapped")
	assert_false(bool(bench.test_position.table_entry(0, 1)["tapped"]))
	assert_true(bool(bench.test_position.table_entry(0, 1)["sick"]), "the Lions are sick")
	var crosses: Array[Button] = []
	for node in bench._seat_lists[0].find_children("*", "Button", true, false):
		if (node as Button).text == "×":
			crosses.append(node as Button)
	assert_eq(crosses.size(), 2)
	if not crosses.is_empty():
		crosses[0].pressed.emit()
	assert_eq(bench.test_position.names_in(0, DuelPosition.TABLE),
		["Savannah Lions"] as Array[String], "the × took the Plains out")


func test_whose_turn_and_the_step_are_set_by_their_controls() -> void:
	assert_eq(bench.test_position.active_player, 0, "a fresh test is Seat 1's turn")
	assert_true(bench._turn_buttons[0].button_pressed)
	bench._turn_buttons[1].button_pressed = true
	assert_eq(bench.test_position.active_player, 1)
	assert_false(bench._turn_buttons[0].button_pressed, "one of the two")
	for i in bench._step_option.item_count:
		if int(bench._step_option.get_item_metadata(i)) == Mtg.Step.END:
			bench._step_option.select(i)
			bench._step_option.item_selected.emit(i)
	assert_eq(bench.test_position.step, Mtg.Step.END)
	assert_eq(bench._step_option.item_count, DuelPosition.STEPS.size())


# ============================================== 4. Go test! — into the turn --

func test_go_test_starts_in_the_chosen_turn_with_no_toss_and_no_mulligan() -> void:
	_set_up_a_test()
	var duel := _go()
	if duel == null:
		return
	await get_tree().process_frame
	var g := duel.game
	assert_true(duel.config.is_test())
	assert_eq(g.turn_number, 1)
	assert_eq(g.active_player, 0, "Seat 1's turn, as chosen")
	assert_eq(g.current_step(), Mtg.Step.MAIN1, "its first main phase")
	assert_false(g.mulligan_open, "no opening hand to keep or throw back")
	assert_eq(g.mulligans_taken, [0, 0] as Array[int])
	assert_eq(_names(g.players[0].hand), ["Wrath of God"] as Array[String],
		"the hand exactly as chosen — nothing dealt")
	assert_eq(g.players[1].hand.size(), 7, "the computer's random seven")
	assert_eq(_names(g.players[0].battlefield), ["Plains", "Savannah Lions"] as Array[String])
	assert_true(g.players[0].battlefield[0].tapped, "the Plains is tapped")
	assert_false(g.players[0].battlefield[1].summoning_sick, "the Lions can attack")
	assert_eq(_names(g.players[0].graveyard), ["Serra Angel"] as Array[String])
	assert_false(duel._toss_active, "no coin toss")
	assert_null(duel._intro_overlay, "no splash")
	assert_null(duel._toss_overlay)
	assert_eq(duel.config.ante, 0)
	assert_true(g.all_ante().is_empty(), "nothing staked")
	assert_null(duel._log_file, "not written into the running duel_log.txt")
	for line in g.log_lines:
		assert_false(String(line).contains("mulligan"), "no mulligan line: %s" % line)
	assert_not_null(duel.find_child("RestartTest", true, false),
		"the table carries Restart test")
	var remembered: Variant = Settings.get_value(TestHandsScreen.LAST_KEY, {})
	assert_true(remembered is Dictionary and (remembered as Dictionary).has("position"),
		"the test is remembered at Go test!")


func test_the_last_test_reopens() -> void:
	_set_up_a_test()
	bench.open_hands = false
	var duel := _go()
	if duel == null:
		return
	var again := _bench()
	await get_tree().process_frame
	assert_eq(again.test_position.names_in(0, DuelPosition.HAND), ["Wrath of God"] as Array[String])
	assert_eq(again.test_position.names_in(0, DuelPosition.TABLE),
		["Plains", "Savannah Lions"] as Array[String])
	assert_true(bool(again.test_position.table_entry(0, 0)["tapped"]))
	assert_false(again.open_hands, "Show both hands is remembered with it")


func test_for_test_is_always_one_free_unstaked_open_duel() -> void:
	var config := _config()
	config.ante = 1
	config.best_of = 3
	config.sideboard_between_duels = true
	config.hotseat_privacy = true
	var position := DuelPosition.new()
	position.lives[0] = 9
	var test := config.for_test(position, 1234, true)
	assert_true(test.is_test())
	assert_eq(test.ante, 0, "never for ante")
	assert_eq(test.best_of, MatchState.FREE_PLAY, "never a match: no record, no match memory")
	assert_false(test.sideboard_between_duels)
	assert_false(test.hotseat_privacy, "one person built both seats")
	assert_eq(test.lives, [9, 20] as Array[int], "the position's lives")
	assert_eq(test.rng_seed, 1234)
	assert_true(test.open_hands)
	position.add(0, DuelPosition.HAND, "Plains")
	assert_true(test.position.names_in(0, DuelPosition.HAND).is_empty(),
		"the duel's position is a copy")
	assert_false(config.is_test(), "and the config it was made from is not a test")


# ============================================================ 5. saved tests --

func test_a_saved_test_loads_back_and_deletes() -> void:
	bench.add_card(0, DuelPosition.TABLE, "Crusade")
	bench._save_name.text = "Crusade on the table"
	bench._save_current()
	assert_true(TestHandsScreen.saved_tests().has("Crusade on the table"))
	bench._clear_all()
	assert_true(bench.test_position.names_in(0, DuelPosition.TABLE).is_empty(), "cleared")
	bench._select_saved("Crusade on the table")
	bench._load_saved()
	assert_eq(bench.test_position.names_in(0, DuelPosition.TABLE), ["Crusade"] as Array[String],
		"loaded back")
	bench._delete_saved()
	assert_false(TestHandsScreen.saved_tests().has("Crusade on the table"), "deleted")


# ===================================================== 6. inside the test --

func test_a_test_duels_pause_window_offers_restart_and_edit() -> void:
	var test := _config().for_test(DuelPosition.new(), 99)
	var menu := DuelPause.new()
	add_child_autofree(menu)
	menu.build(test)
	assert_eq(menu.button_labels(), PackedStringArray(DuelPause.TEST_ENTRIES))
	var seen: Array[int] = []
	menu.chosen.connect(func(action: int) -> void: seen.append(action))
	assert_true(menu.press("Restart test"))
	assert_true(menu.press("Edit test"))
	assert_false(menu.press("Concede duel"), "a test is not conceded from here")
	assert_eq(seen, [int(DuelPause.Action.RESTART_TEST), int(DuelPause.Action.EXIT_DUEL)] as Array[int])
	var plain := DuelPause.new()
	add_child_autofree(plain)
	plain.build(_config())
	assert_eq(plain.button_labels(), PackedStringArray(DuelPause.ENTRIES),
		"an ordinary duel keeps its five (the control)")


func test_restart_is_the_same_test_on_the_same_seed() -> void:
	_set_up_a_test()
	var duel := _go()
	if duel == null:
		return
	await get_tree().process_frame
	var seed_value := duel.config.rng_seed
	var their_hand := _names(duel.game.players[1].hand)
	var their_library := _names(duel.game.players[1].library)
	var again := _handover(duel, duel.restart_test) as DuelScreen
	if again == null:
		return
	await get_tree().process_frame
	assert_eq(again.config.rng_seed, seed_value, "the same seed")
	assert_eq(_names(again.game.players[1].hand), their_hand, "the same random seven")
	assert_eq(_names(again.game.players[1].library), their_library, "the same library under it")
	assert_eq(_names(again.game.players[0].hand), ["Wrath of God"] as Array[String])
	assert_eq(again.game.current_step(), Mtg.Step.MAIN1)


func test_edit_test_goes_back_to_the_bench_with_the_position() -> void:
	_set_up_a_test()
	var built := bench.test_position.to_dict()
	var duel := _go()
	if duel == null:
		return
	await get_tree().process_frame
	var next := _handover(duel, duel.edit_test) as TestHandsScreen
	if next == null:
		return
	await get_tree().process_frame
	assert_eq(next.test_position.to_dict(), built, "the position as it was built")
	assert_eq(next.config.player_names[0], "Tester", "the same seats")


# ============================================================ 7. refusals --

func test_a_card_the_pool_lacks_is_refused_before_any_duel() -> void:
	bench.add_card(0, DuelPosition.HAND, "Not A Real Card")
	assert_null(bench.build_test_config())
	assert_not_null(UiChrome.open_popup(bench), "the refusal is said on the screen")
	var started: Array[Node] = []
	bench.test_started.connect(func(duel: Control) -> void: started.append(duel))
	bench.go_test()
	assert_eq(started.size(), 0, "no duel")
	assert_false(bench._leaving)


# ================================================================ 8. Escape --

func test_escape_puts_the_picker_away_first() -> void:
	bench.open_picker(0, DuelPosition.TABLE)
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	bench._unhandled_input(escape)
	assert_false(bench.picker_open(), "the picker is away")
	assert_false(bench._leaving, "and the screen is still here")


# ======================================================= 9. Show both hands --

func test_show_both_hands_opens_the_computers_hand() -> void:
	_set_up_a_test()
	bench.open_hands = true
	var duel := _go()
	if duel == null:
		return
	await get_tree().process_frame
	assert_true(duel.hidden_hands.is_empty(), "both hands open on the table")
	var shut := _bench()
	await get_tree().process_frame
	shut.open_hands = false
	var started: Array[Node] = []
	shut.test_started.connect(func(next: Control) -> void: started.append(next))
	shut.go_test()
	if started.is_empty():
		return
	_handed.append(started[0])
	await get_tree().process_frame
	assert_eq((started[0] as DuelScreen).hidden_hands, [1] as Array[int],
		"unticked, the computer's hand stays hidden (the control)")
