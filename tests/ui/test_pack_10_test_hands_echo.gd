extends GutTest
## TEST HANDS AND ECHO (Pack 10, CR 702.30a). A permanent placed on the
## table has been there since before its controller's last upkeep, so it
## owes no echo — unless the bench's `Echo due` box says it arrived since,
## as if just cast (DuelPosition.set_echo_due, read as the position is
## placed by MtgGame.begin_from_position). Only a card with echo has the
## box; the test duel then asks for the echo at its controller's next
## upkeep.

var bench: TestHandsScreen
var _handed: Array[Node] = []


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	Settings.clear_value(TestHandsScreen.LAST_KEY)
	Settings.clear_value(TestHandsScreen.SAVED_KEY)
	var config := DuelConfig.vs_ai_default(AiProfile.wizard())
	config.player_names[0] = "Tester"
	config.deck_names[0] = "White Knights"
	config.deck_names[1] = "Slan's Raiders"
	bench = load("res://game/test_hands_screen.tscn").instantiate()
	bench.config = config
	add_child_autofree(bench)
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
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _boxes(text: String) -> Array:
	return bench._seat_lists[0].find_children("*", "CheckBox", true, false).filter(
		func(box: Node) -> bool: return (box as CheckBox).text == text)


func _go() -> DuelScreen:
	var started: Array[Node] = []
	bench.test_started.connect(func(duel: Control) -> void: started.append(duel))
	bench.go_test()
	assert_eq(started.size(), 1, "Go test! started one duel")
	if started.is_empty():
		return null
	_handed.append(started[0])
	return started[0] as DuelScreen


func _placed(duel: DuelScreen, card_name: String) -> CardInstance:
	for inst in duel.game.players[0].battlefield:
		if inst.data.card_name == card_name:
			return inst
	return null


func test_only_a_card_with_echo_has_the_echo_due_box() -> void:
	assert_true(TestHandsScreen.has_echo(CardRegistry.get_card("Goblin Patrol")))
	assert_false(TestHandsScreen.has_echo(CardRegistry.get_card("Savannah Lions")))
	bench.add_card(0, DuelPosition.TABLE, "Plains")
	bench.add_card(0, DuelPosition.TABLE, "Goblin Patrol")
	var echo := _boxes("Echo due")
	assert_eq(echo.size(), 1, "the Patrol's row alone")
	assert_eq(_boxes("Tapped").size(), 2, "Tapped on every row, as before")
	if echo.is_empty():
		return
	assert_false((echo[0] as CheckBox).button_pressed, "off by default")
	assert_string_contains((echo[0] as CheckBox).tooltip_text, "echo cost")
	(echo[0] as CheckBox).button_pressed = true
	assert_true(bool(bench.test_position.table_entry(0, 1)["echo_due"]), "the box sets the entry")
	assert_false(bool(bench.test_position.table_entry(0, 0)["echo_due"]))


func test_echo_due_makes_the_test_duel_ask_for_it_at_the_next_upkeep() -> void:
	bench.add_card(0, DuelPosition.TABLE, "Goblin Patrol")
	bench.add_card(0, DuelPosition.TABLE, "Herald of Serra")
	bench.test_position.random_cards[0] = 0
	bench.test_position.random_cards[1] = 0
	bench.test_position.active_player = 0
	bench.test_position.step = Mtg.Step.MAIN1
	var echo := _boxes("Echo due")
	assert_eq(echo.size(), 2)
	if echo.size() < 2:
		return
	(echo[0] as CheckBox).button_pressed = true
	var duel := _go()
	if duel == null:
		return
	await get_tree().process_frame
	var patrol := _placed(duel, "Goblin Patrol")
	var herald := _placed(duel, "Herald of Serra")
	assert_not_null(patrol)
	assert_not_null(herald)
	if patrol == null or herald == null:
		return
	assert_true(EchoAbility.due_next_upkeep(duel.game, patrol), "ticked: it owes its echo")
	assert_false(EchoAbility.due_next_upkeep(duel.game, herald), "unticked: it has been there all along")


func test_echo_due_survives_saving_the_test() -> void:
	bench.add_card(0, DuelPosition.TABLE, "Goblin Patrol")
	var echo := _boxes("Echo due")
	if echo.is_empty():
		fail_test("no Echo due box")
		return
	(echo[0] as CheckBox).button_pressed = true
	var again := DuelPosition.from_dict(bench.test_position.to_dict())
	assert_true(bool(again.table_entry(0, 0)["echo_due"]), "the flag round-trips")
