extends GameTest
## GITHUB ISSUE #7 AT A LAN GUEST'S SCREEN: a payment click on a dual land
## or Birds of Paradise taps the colour the bill needs, as at a local table
## ([method SgDuelView._guest_payment_pick]) — the referee is sent the
## option's index, the one thing a mana tap carries over the wire.

var referee: SgPracticeMatch
var revision := 1
var commands: Array = []


func before_each() -> void:
	super.before_each()
	referee = SgPracticeMatch.new(42)
	referee.game = g
	revision = 1
	commands.clear()
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())


func _room(seat := 0) -> Dictionary:
	return {"id": "r1", "name": "Friendly duel", "seat": seat,
		"names": ["Azure Fox", "Amber Owl"], "revision": revision,
		"ready": [true, true], "connected": [true, true], "game": referee.view(seat),
		"deck_names": referee.deck_names.duplicate(), "deck": {}}


func _screen(seat := 0) -> SgDuelView:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var screen := SgDuelView.new()
	screen.stops.from_masks(PackedInt32Array([255, 255, 255, 255]))
	viewport.add_child(screen)
	screen.action_requested.connect(_act.bind(screen, seat))
	screen.present(_room(seat), true, false)
	return screen


func _act(action: Dictionary, screen: SgDuelView, seat: int) -> void:
	commands.append(action.duplicate(true))
	var error := referee.act(seat, action)
	if not error.is_empty():
		screen.show_notice(error)
	else: revision += 1
	screen.present.call_deferred(_room(seat), true, false)


func _pump() -> void:
	for i in 8: await get_tree().process_frame


func _local(screen: SgDuelView, card: CardInstance) -> CardInstance:
	return screen.game.find_instance(screen.projection.local_id(referee._handle(int(screen._room.seat), card)))


func _mana_sent() -> Array:
	return commands.filter(func(a: Dictionary) -> bool: return a.op == "mana")


func test_a_guests_savannah_pays_the_white_savannah_lions_need() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var lions := give_hand(0, "Savannah Lions")
	var savannah := put_battlefield(0, "Savannah")
	var screen := _screen()
	await _pump()
	screen._on_card_clicked(_local(screen, lions))
	await _pump()
	assert_eq(screen.mode, DuelScreen.Mode.PAYING)
	screen._on_card_clicked(_local(screen, savannah))
	await _pump()
	assert_false(screen._ability_menu.visible, "no Green-or-White menu")
	screen._ability_menu.hide()
	assert_eq(_mana_sent().size(), 1)
	if _mana_sent().size() == 1:
		assert_eq(int(_mana_sent()[0].index), 1, "the white ability")
	assert_true(savannah.tapped)
	assert_eq(g.stack.size(), 1, "the referee cast the Lions")
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_a_guests_birds_make_the_green_the_dervish_still_needs() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var dervish := give_hand(0, "Whirling Dervish")
	var forest := put_battlefield(0, "Forest")
	var birds := put_battlefield(0, "Birds of Paradise")
	var screen := _screen()
	await _pump()
	screen._on_card_clicked(_local(screen, dervish))
	await _pump()
	assert_eq(screen.mode, DuelScreen.Mode.PAYING)
	screen._on_card_clicked(_local(screen, forest))
	await _pump()
	screen._on_card_clicked(_local(screen, birds))
	await _pump()
	assert_false(screen._ability_menu.visible)
	screen._ability_menu.hide()
	assert_true(birds.tapped)
	assert_eq(g.stack.size(), 1)
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_a_guests_click_outside_a_payment_still_opens_the_menu() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var savannah := put_battlefield(0, "Savannah")
	var screen := _screen()
	await _pump()
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)
	screen._on_card_clicked(_local(screen, savannah))
	await _pump()
	assert_true(screen._ability_menu.visible)
	screen._ability_menu.hide()
	assert_eq(_mana_sent().size(), 0)
	assert_false(savannah.tapped)


## A guest's Fellwar Stone facing a Plains and an Island, Savannah Lions
## waiting for its {W} (the owner, 2026-11-11: "Yes make them auto select").
func _stone_payment(marked: bool) -> SgDuelView:
	advance_to_step(Mtg.Step.MAIN1)
	var lions := give_hand(0, "Savannah Lions")
	var stone := put_battlefield(0, "Fellwar Stone")
	put_battlefield(1, "Plains")
	put_battlefield(1, "Island")
	var screen := _screen()
	await _pump()
	if marked:
		screen._no_auto_tap[_local(screen, stone).id] = true
	screen._on_card_clicked(_local(screen, lions))
	await _pump()
	assert_eq(screen.mode, DuelScreen.Mode.PAYING)
	screen._on_card_clicked(_local(screen, stone))
	await _pump()
	return screen


func test_a_guests_fellwar_stone_names_the_colour_owed() -> void:
	var screen: SgDuelView = await _stone_payment(false)
	assert_eq(_mana_sent().size(), 1)
	if _mana_sent().size() == 1:
		assert_eq(int(_mana_sent()[0].get("color", -1)), Mtg.ManaColor.W,
			"the mana command names white")
	assert_null(g.awaiting_choice, "the referee asked nothing")
	assert_eq(g.stack.size(), 1, "the referee cast the Lions")
	assert_eq(g.players[0].mana_pool.total(), 0)
	screen._ability_menu.hide()


func test_a_guests_marked_fellwar_stone_is_asked_by_the_referee() -> void:
	var screen: SgDuelView = await _stone_payment(true)
	assert_eq(_mana_sent().size(), 1)
	if _mana_sent().size() == 1:
		assert_false(_mana_sent()[0].has("color"), "no colour: the mark keeps the question")
	assert_not_null(g.awaiting_choice, "What kind of mana? is the guest's")
	assert_eq(g.cancel_choice(), "")
	screen._ability_menu.hide()


func test_the_wire_takes_a_mana_command_with_or_without_a_colour() -> void:
	var message := {"v": SgProtocol.VERSION, "type": "command", "seq": 1, "room": "r1",
		"revision": 1, "action": {"op": "mana", "card": "c1", "index": 0}}
	assert_true(SgProtocol.valid(message), "without a colour")
	message.action["color"] = Mtg.ManaColor.W
	assert_true(SgProtocol.valid(message), "with one")
	message.action["color"] = 0
	assert_false(SgProtocol.valid(message), "no colour is 0")
	message.action["color"] = "white"
	assert_false(SgProtocol.valid(message))
