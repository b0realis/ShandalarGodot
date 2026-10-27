extends GutTest
## WHOSE SCREEN IT IS, AND WHAT IT MAY SHOW (the bug campaign c12, h4-4 and
## h4-6).
##
##  * h4-4 — a Test hands duel with two humans is an OPEN hotseat
##    ([method DuelConfig.for_test] never makes a private one), and every
##    `private_hotseat() ? decision seat : human seat` read seat 1 as seat
##    0: on seat 1's turn, its War Mammoth trampling over Llanowar Elves,
##    a click on the defender's life did nothing and a click on seat 1's
##    OWN life took the point. One read now — [method
##    DuelScreen._viewing_seat] — serves the deciding seat whenever both
##    seats are human, and every place the finding listed asks it.
##  * h4-6 — at a PRIVATE hotseat a card exiled face down for the seat to
##    decide (the Scroll Rack, Gustha's Scepter, Three Wishes shape) was
##    named before that seat's player pressed Show hand: in the exile
##    plate's tooltip, on its face, in the graveyard view and by a click.
##    Now nothing names it until the hand is shown. And a view serving
##    nobody (the MPN player's observer) no longer reads a card nobody may
##    look at.

var screen: DuelScreen


func after_each() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


# ================================== h4-4: two humans at an open hotseat --

## Test hands, two humans, seat 1's beginning of combat: seat 1 has a War
## Mammoth, seat 0 a Llanowar Elves.
func _two_human_test() -> MtgGame:
	var position := DuelPosition.new()
	position.add(1, DuelPosition.TABLE, "War Mammoth")
	position.add(0, DuelPosition.TABLE, "Llanowar Elves")
	position.active_player = 1
	position.step = Mtg.Step.COMBAT_BEGIN
	var config := DuelConfig.hotseat_default().for_test(position, 93400)
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	var g: MtgGame = screen.game
	assert_false(config.private_hotseat(), "control: an open hotseat")
	assert_eq(g.active_player, 1, "control: seat 1's turn")
	return g


func _card(g: MtgGame, pid: int, card_name: String) -> CardInstance:
	for inst in g.players[pid].battlefield:
		if inst.data.card_name == card_name:
			return inst
	fail_test("no %s for seat %d" % [card_name, pid])
	return null


func _pass_until(g: MtgGame, done: Callable) -> void:
	for _i in 40:
		if done.call():
			return
		g.pass_priority(g.priority_player)
	fail_test("the duel never got there")


func test_the_trample_spill_goes_to_the_defender_on_seat_ones_turn() -> void:
	var g := await _two_human_test()
	var mammoth := _card(g, 1, "War Mammoth")
	var elves := _card(g, 0, "Llanowar Elves")
	_pass_until(g, func() -> bool: return g.awaiting_attackers)
	assert_eq(g.declare_attackers(1, [mammoth.id]), "")
	_pass_until(g, func() -> bool: return g.awaiting_blockers)
	assert_eq(g.declare_blockers(0, {elves.id: mammoth.id}), "")
	_pass_until(g, func() -> bool: return g.awaiting_damage_assignment)
	screen._refresh()
	assert_eq(screen.mode, DuelScreen.Mode.DAMAGE, "control: seat 1 divides the damage")
	assert_eq(screen._viewing_seat(), 1, "the screen serves seat 1, who decides")
	screen._assign_one_point(elves.id)
	assert_eq(screen._damage_picks, {elves.id: 1}, "control: lethal to the Elves first")
	screen._on_life_clicked(1)
	assert_false(screen._damage_picks.has(MtgGame.DAMAGE_TO_PLAYER),
		"seat 1's own life takes no point of its own Mammoth")
	screen._on_life_clicked(0)
	assert_eq(int(screen._damage_picks.get(MtgGame.DAMAGE_TO_PLAYER, 0)), 1,
		"the defender's life takes the trample spill")


func test_every_read_serves_the_deciding_human() -> void:
	var g := await _two_human_test()
	g.priority_player = 1
	assert_eq(screen._viewing_seat(), 1, "seat 1 holds priority: seat 1 decides")
	assert_eq(screen._advance_stop_reason(), "", "control: nothing stops a Done here")
	# The graveyard view serves the seat deciding, not seat 0.
	screen._open_graveyard(0)
	screen._repopulate_graveyard()
	assert_eq(screen._grave_view._human, 1, "the graveyard view is seat 1's")
	screen._close_graveyard()
	g.priority_player = 0
	g.active_player = 0
	assert_eq(screen._viewing_seat(), 0, "and seat 0's on seat 0's decision")


## "Any player may" pays from the seat deciding: seat 1, on its own turn,
## using seat 0's Mercenaries.
func test_an_any_player_may_ability_is_paid_by_the_deciding_human() -> void:
	CardPacks.set_enabled(IceAgePack.ID, true)
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var g: MtgGame = screen.game
	g._probing = true
	g.active_player = 1
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	g.priority_player = 1
	g._probing = false
	var merc := CardInstance.new(CardRegistry.get_card("Mercenaries"), g._next_instance_id, 0)
	g._next_instance_id += 1
	g._instances[merc.id] = merc
	g._put_on_battlefield(merc, 0)
	g.players[1].mana_pool.add(Mtg.ManaColor.C, 3)
	screen._open_ability_menu(merc)
	screen._ability_menu.hide()
	screen._on_ability_chosen(0)
	assert_eq(g.stack.size(), 1, "control: the ability is on the chain")
	if g.stack.size() == 1:
		assert_eq(g.stack[0].controller, 1, "seat 1 activated it")
	assert_eq(g.players[1].mana_pool.total(), 0, "from seat 1's own mana")
	CardPacks.set_enabled(IceAgePack.ID, false)


## Against the computer nothing changes: the screen serves the human.
func test_against_the_computer_the_screen_serves_the_human() -> void:
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 1000.0
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.game.priority_player = 1
	assert_eq(screen._viewing_seat(), 0)


# ======================== h4-6: a face-down card waits for Show hand --

func _private_hotseat() -> MtgGame:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = DuelConfig.hotseat_default()
	screen.config.hotseat_privacy = true
	screen.config.rng_seed = 93400
	add_child_autofree(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	var g: MtgGame = screen.game
	g.active_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	g.priority_player = 0
	screen._refresh()
	assert_true(screen.config.private_hotseat(), "control: a private hotseat")
	return g


## Exile a card from seat 0's hand face down, shown to seat 0 — the Scroll
## Rack / Gustha's Scepter / Three Wishes shape the finding used.
func _exile_a_hand_card_face_down(g: MtgGame) -> CardInstance:
	var data := CardRegistry.get_card("Plains")
	var inst := CardInstance.new(data, g._next_instance_id, 0)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	inst.zone = Mtg.Zone.HAND
	g.players[0].hand.append(inst)
	g.exile_from_hand(inst, true, 0)
	screen._refresh()
	return inst


func test_before_show_hand_nothing_names_the_card() -> void:
	var g := await _private_hotseat()
	var card := _exile_a_hand_card_face_down(g)
	assert_false(screen._may_see_hand(0), "control: the hand is not shown yet")
	assert_false(screen._exile_tooltip(0).contains("Plains"),
		"the exile plate's tooltip keeps it: %s" % screen._exile_tooltip(0))
	assert_true(screen._exile_tooltip(0).contains("(face down)"))
	assert_eq(screen._exile_icons[0].texture,
		ExilePlate.plate(screen.config.panel_colors[0]),
		"the plate wears its own face, not the card's")
	assert_eq(screen._looking_seat(), -1, "nobody is looking yet")
	screen._open_graveyard(0)
	screen._repopulate_graveyard()
	assert_false(screen._grave_view._may_look(card), "the graveyard view shows its back")
	screen._close_graveyard()
	screen._card_preview.show_card(CardInstance.new(CardRegistry.get_card("Island"), 99901, 0))
	screen._on_graveyard_card(card)
	assert_true(screen._card_preview._back.visible, "a click shows the back")


func test_after_show_hand_its_seat_reads_it() -> void:
	var g := await _private_hotseat()
	var card := _exile_a_hand_card_face_down(g)
	screen._toggle_hotseat_hand(0)
	assert_true(screen._may_see_hand(0), "control: Show hand")
	assert_true(screen._exile_tooltip(0).contains("Plains"), "now the seat reads its card")
	assert_eq(screen._looking_seat(), 0)
	screen._open_graveyard(0)
	screen._repopulate_graveyard()
	assert_true(screen._grave_view._may_look(card), "face up in the view for its seat")
	screen._close_graveyard()
	screen._card_preview.show_back()
	screen._on_graveyard_card(card)
	assert_false(screen._card_preview._back.visible, "and a click enlarges it")


## The MPN player's observer serves nobody (-1), which is also a face-down
## card's "nobody may look": the two must not match.
func test_a_view_serving_nobody_reads_no_face_down_card() -> void:
	var view := GraveyardView.new()
	add_child_autofree(view)
	var vault := CardInstance.new(CardRegistry.get_card("Plains"), 99902, 0)
	vault.zone = Mtg.Zone.EXILE
	vault.face_down = true
	vault.exile_visible_to = -1      # Knowledge Vault: nobody may look
	# Through set(): the looker is the serving seat unless told otherwise.
	view.set("_human", -1)
	view.set("_looker", -1)
	assert_false(view._may_look(vault), "nobody's view reads nobody's card")
	view.set("_human", 0)
	view.set("_looker", 0)
	assert_false(view._may_look(vault), "control: nor seat 0's")
	vault.exile_visible_to = 0
	assert_true(view._may_look(vault), "control: the seat shown it reads it")
