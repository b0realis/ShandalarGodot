extends GutTest
## ONE REDRAW PER FRAME, WHATEVER MOVED THE GAME (campaign 2026-10-12,
## finding r1-1). The engine announces `state_changed` from 89 places, and
## one action can announce it dozens of times: an AI paying a big X one
## land at a time announces every tap. Outside private hotseat the duel
## screen used to rebuild the whole board on EVERY announcement, inside
## the one frame — 51 full rebuilds for one Fireball paid with 24 lands,
## a multi-second freeze and hundreds of megabytes of replaced widgets
## alive until the frame ended. The screen now draws an engine change once,
## deferred to the end of the frame, in every mode; its own UI handlers
## still redraw at once after the call they make.

var screen: DuelScreen


func _battlefield(pid: int, card_name: String) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name), g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, pid)
	inst.summoning_sick = false
	return inst


## A demo duel whose pacing timer never fires: the test steps the AI.
func _demo(deck_a: Array[String], deck_b: Array[String], seed_value: int) -> void:
	var config := DuelConfig.demo_default()
	config.pace = 1000.0
	config.rng_seed = seed_value
	config.decks = [deck_a, deck_b]
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame


## Seat 1 to its own first main phase with priority, 24 Mountains and a
## Fireball in hand, ten creatures across the table to aim at.
func _fireball_table() -> void:
	var a: Array[String] = []
	var b: Array[String] = []
	for i in 40:
		a.append("Forest")
		b.append("Mountain")
	await _demo(a, b, 99)
	var g: MtgGame = screen.game
	for _i in 40:
		if g.active_player == 1 and g.current_step() == Mtg.Step.MAIN1 \
				and g.priority_player == 1 and g.stack.is_empty():
			break
		g.pass_priority(g.priority_player)
	assert_eq(g.active_player, 1, "control: seat 1's turn")
	for i in 24:
		_battlefield(1, "Mountain")
	for i in 10:
		_battlefield(0, "Grizzly Bears")
	var fireball := CardInstance.new(CardRegistry.get_card("Fireball"), g._next_instance_id, 1)
	g._next_instance_id += 1
	g._instances[fireball.id] = fireball
	fireball.zone = Mtg.Zone.HAND
	g.players[1].hand.append(fireball)
	screen._refresh()
	await get_tree().process_frame


func test_a_big_x_cast_is_drawn_once_not_once_per_land() -> void:
	await _fireball_table()
	var g: MtgGame = screen.game
	var emissions := [0]
	g.state_changed.connect(func() -> void: emissions[0] += 1)
	var worst := 0
	var worst_line := ""
	var busiest := 0
	for _step in 6:
		emissions[0] = 0
		var before := screen.refresh_count
		screen._ai_step()
		await get_tree().process_frame
		var drawn := screen.refresh_count - before
		busiest = maxi(busiest, emissions[0])
		if drawn > worst:
			worst = drawn
			worst_line = String(g.log_lines[g.log_lines.size() - 1])
	assert_gt(busiest, 20, "control: one AI action announced the state %d times" % busiest)
	assert_lte(worst, 2, "one AI action (%s) redrew the whole board %d times" % [worst_line, worst])


func test_the_computers_action_is_not_drawn_while_it_is_being_taken() -> void:
	await _fireball_table()
	var g: MtgGame = screen.game
	var seen_during: Array[int] = []
	var record := func() -> void: seen_during.append(screen.refresh_count)
	g.state_changed.connect(record)
	var before := screen.refresh_count
	var did: String = screen._ais[1].act(g)
	g.state_changed.disconnect(record)
	assert_ne(did, "", "control: the computer did something")
	assert_false(seen_during.is_empty(), "control: the engine announced it")
	assert_eq(screen.refresh_count, before,
		"nothing was redrawn inside the computer's action (and nothing passed for the player inside it)")
	for count in seen_during:
		assert_eq(count, before, "no redraw between two of the engine's announcements")
	await get_tree().process_frame
	assert_eq(screen.refresh_count, before + 1, "...and the frame drew it once")


func test_a_busy_board_is_drawn_at_most_twice_per_computer_action() -> void:
	var a: Array[String] = []
	var b: Array[String] = []
	for i in 20:
		a.append("Forest")
		b.append("Plains")
	for i in 20:
		a.append("Grizzly Bears")
		b.append("Savannah Lions")
	await _demo(a, b, 4242)
	var g: MtgGame = screen.game
	for i in 12:
		_battlefield(0, "Grizzly Bears")
		_battlefield(1, "Savannah Lions")
	var worst := 0
	var worst_where := ""
	for _step in 300:
		if g.game_over:
			break
		var where := "turn %d %s" % [g.turn_number, Mtg.step_name(g.current_step())]
		var before := screen.refresh_count
		screen._ai_step()
		await get_tree().process_frame
		var drawn := screen.refresh_count - before
		if drawn > worst:
			worst = drawn
			worst_where = where
	assert_gt(g.turn_number, 2, "control: the duel went on for turns")
	assert_lte(worst, 2, "one AI action redrew the board %d times (at %s)" % [worst, worst_where])


## A change no handler of the screen made — here a draw — is on the table
## by the end of the frame, drawn once.
func test_a_change_from_outside_the_screen_is_drawn_by_the_next_frame() -> void:
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 1000.0
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	var g: MtgGame = screen.game
	var before := screen.refresh_count
	g.draw_cards(0, 3)
	g.draw_cards(1, 2)
	await get_tree().process_frame
	assert_eq(screen.refresh_count, before + 1, "two engine calls, one redraw")
	assert_eq(screen._lib_labels[0].text, str(g.players[0].library.size()),
		"the library count shows the draw")
	assert_eq(screen._lib_labels[1].text, str(g.players[1].library.size()))


## The screen's own handlers still answer at once: Done passes and the
## board is redrawn before the click returns.
func test_the_players_own_click_is_drawn_at_once() -> void:
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 1000.0
	config.rng_seed = 31337
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	var g: MtgGame = screen.game
	# Seat 0's own first main phase, with priority and its land drop unspent.
	g.active_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	g.priority_player = 0
	g.players[0].lands_played_this_turn = 0
	await get_tree().process_frame
	assert_eq(g.current_step(), Mtg.Step.MAIN1, "control: seat 0's main phase")
	var land := CardInstance.new(CardRegistry.get_card("Forest"), g._next_instance_id, 0)
	g._next_instance_id += 1
	g._instances[land.id] = land
	land.zone = Mtg.Zone.HAND
	g.players[0].hand.append(land)
	screen._refresh()
	var before := screen.refresh_count
	screen._on_card_clicked(land)
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD, "control: the land was played")
	assert_gt(screen.refresh_count, before, "the click redrew the table before it returned")
	var shown := false
	for card in screen.find_children("*", "MiniCard", true, false):
		if not card.is_queued_for_deletion() and card.instance != null \
				and card.instance.id == land.id:
			shown = true
	assert_true(shown, "the land is on the table at once")
