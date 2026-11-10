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
