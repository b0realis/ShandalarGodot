extends GameTest
## AT A PRIVATE HOTSEAT THE SEAT AT THE SCREEN ACTS ONLY FOR ITSELF (gap
## review 2026-11-10, r3-1). Both seats are human there, and the table's
## click gate asked only "is the card's controller human?" — so the seat
## deciding could tap the OTHER seat's lands (the mana floated in that
## seat's pool and burned it a life at the step's end under the 1997
## rules) and start the other seat's abilities, paid by their controller.
## Now a click acts for [method DuelScreen._private_decision_seat] alone,
## and the two allowances that hand a seat someone else's permanent stay:
## a land it may tap (Piracy) and an ability its card lets any player or
## only an opponent activate (Mercenaries).

var screen: DuelScreen


func after_each() -> void:
	for id in CardPacks.available_ids():
		CardPacks.set_enabled(id, false)
	await get_tree().process_frame
	await get_tree().process_frame


func _open(seed := 93801) -> void:
	var config := DuelConfig.hotseat_default()
	config.hotseat_privacy = true
	config.rng_seed = seed
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	g = screen.game


func _stand(pid: int, step := Mtg.Step.MAIN1) -> void:
	g.active_player = pid
	g._enter_step(Mtg.STEP_ORDER.find(step))
	g.priority_player = pid
	screen.mode = DuelScreen.Mode.NORMAL
	screen._refresh()


func test_the_deciding_seat_does_not_tap_the_other_seats_land(pid = use_parameters([0, 1])) -> void:
	await _open()
	var other := 1 - int(pid)
	var forest := put_battlefield(other, "Forest")
	_stand(int(pid))
	assert_true(screen.config.private_hotseat(), "control: a private hotseat")
	assert_eq(screen._private_decision_seat(), int(pid), "control: seat %d decides" % int(pid))
	screen._on_card_clicked(forest)
	assert_false(forest.tapped, "seat %d must not tap seat %d's Forest" % [int(pid), other])
	assert_eq(g.players[other].mana_pool.total(), 0, "no mana floats in the other seat's pool")
	assert_eq(g.players[int(pid)].mana_pool.total(), 0, "nor in the deciding seat's")


func test_the_other_seat_is_not_burned_by_the_deciding_seats_click() -> void:
	await _open(93802)
	var forest := put_battlefield(0, "Forest")
	_stand(1)
	var before := g.players[0].life
	screen._on_card_clicked(forest)
	var step := g.current_step()
	var guard := 0
	while g.current_step() == step and guard < 6:
		g.pass_priority(g.priority_player)
		guard += 1
	assert_ne(g.current_step(), step, "control: the step ended")
	assert_eq(g.players[0].life, before, "Player 2's click costs Player 1 no life")


func test_the_deciding_seat_does_not_start_the_other_seats_ability() -> void:
	await _open(93803)
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	_stand(1)
	assert_eq(screen._private_decision_seat(), 1, "control: Player 2 decides")
	screen._on_card_clicked(sorcerer)
	var opened := screen._ability_menu.visible
	if opened:
		screen._ability_menu.hide()
		screen._on_ability_chosen(0)
	assert_false(opened, "no ability menu for the other seat's Prodigal Sorcerer")
	assert_null(screen._pending_card, "Player 2 must not start Player 1's Prodigal Sorcerer")


# ========================================================== the controls --

func test_the_deciding_seat_still_taps_its_own_land(pid = use_parameters([0, 1])) -> void:
	await _open(93804)
	var forest := put_battlefield(int(pid), "Forest")
	_stand(int(pid))
	screen._on_card_clicked(forest)
	assert_true(forest.tapped, "its own Forest taps")
	assert_eq(g.players[int(pid)].mana_pool.total_of(Mtg.ManaColor.G), 1, "for its own pool")


func test_the_deciding_seat_still_starts_its_own_ability() -> void:
	await _open(93805)
	var sorcerer := put_battlefield(1, "Prodigal Sorcerer")
	_stand(1)
	screen._on_card_clicked(sorcerer)
	assert_true(screen._ability_menu.visible, "control: its own menu opens")
	screen._ability_menu.hide()
	screen._on_ability_chosen(0)
	assert_eq(screen._pending_card, sorcerer, "its own Prodigal Sorcerer is aimed")
	assert_eq(screen._pending_pid, 1)
	screen._on_cancel()


## "Any player may activate this ability" (Mercenaries): still offered to
## the seat deciding on the other seat's permanent, and paid by it.
func test_an_any_player_may_ability_is_still_the_deciding_seats() -> void:
	CardPacks.set_enabled(IceAgePack.ID, true)
	await _open(93806)
	var merc := put_battlefield(0, "Mercenaries")
	_stand(1)
	g.players[1].mana_pool.add(Mtg.ManaColor.C, 3)
	screen._on_card_clicked(merc)
	assert_true(screen._ability_menu.visible, "the other seat's Mercenaries offers its ability")
	screen._ability_menu.hide()
	screen._on_ability_chosen(0)
	assert_eq(g.stack.size(), 1, "the ability is on the chain")
	if g.stack.size() == 1:
		assert_eq(g.stack[0].controller, 1, "activated by the seat deciding")
	assert_eq(g.players[1].mana_pool.total(), 0, "from its own mana")


## Piracy: "you may tap lands you don't control for mana" — a seat may
## still tap the other seat's land, for its own pool.
func test_a_land_piracy_lends_is_still_tapped_for_the_deciding_seat() -> void:
	CardPacks.set_enabled("pack-6", true)
	await _open(93807)
	var island := put_battlefield(0, "Island")
	_stand(1)
	var piracy := give_hand(1, "Piracy")
	for color in Mtg.WUBRG:
		add_mana(1, color, 4)
	assert_ok(g.cast_spell(1, piracy))
	resolve_stack()
	g.players[1].mana_pool.clear()
	_stand(1)
	assert_true(g.may_tap_foreign_land(1, island), "control: Piracy lends the Island")
	screen._on_card_clicked(island)
	if screen._ability_menu.visible:
		screen._ability_menu.hide()
		screen._on_ability_chosen(0)
	assert_true(island.tapped, "the lent Island taps")
	assert_eq(g.players[1].mana_pool.total(), 1, "for the seat deciding")
	assert_eq(g.players[0].mana_pool.total(), 0, "not for its controller")
