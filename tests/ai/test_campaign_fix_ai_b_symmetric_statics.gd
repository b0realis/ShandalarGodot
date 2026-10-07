extends GameTest
## A SYMMETRIC STATIC, READ BY THE FAIR AI (whole-game campaign 2026-10-07,
## w3-2 / w3-5 and the w3 note on Living Death; engine/ai/tempest_spells.gd
## `symmetric_static_choice`, `living_death_arrivals`, [member
## AiProfile.forecasts_tactics]).
##
## Humility was cast into the pilot's own Serra Angels, Dread of Night into
## its own white weenies, Light of Day against its own black creatures,
## Choke on its own Islands: the generic value priced the card and never the
## board. A noncreature permanent with a static is now put onto the table
## under the search journal and each side's board priced before and after;
## it waits when it costs our side more than theirs. Living Death prices
## the cards it returns as they would arrive (under Humility, 1/1s).
## The opponent's hidden cards move nothing; the gate off reads nothing.

const TS := preload("res://engine/ai/tempest_spells.gd")


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(on := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _lands(pid: int, land: String, n: int) -> void:
	for _i in n: put_battlefield(pid, land)


func _in_graveyard(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(inst)
	return inst


## Our first main phase played out: the pilot acts until it passes.
func _play_main(ai: AiPlayer) -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var turn := g.turn_number
	for _k in 20:
		if g.game_over or g.turn_number != turn or g.current_step() != Mtg.Step.MAIN1: break
		if g.priority_player == ai.pid:
			var did := ai.act(g)
			if did == "" or did == "pass": break
		else:
			g.pass_priority(g.priority_player)
	resolve_stack()


# -------------------------------------------------------------- Humility --

func test_humility_waits_while_it_humbles_our_own_angels() -> void:
	var ai := _ai()
	put_battlefield(0, "Serra Angel")
	put_battlefield(0, "Serra Angel")
	put_battlefield(0, "Femeref Knight")
	_lands(0, "Plains", 4)
	put_battlefield(1, "Grizzly Bears")
	var humility := give_hand(0, "Humility")
	_play_main(ai)
	assert_eq(humility.zone, Mtg.Zone.HAND, "Humility only shrinks our own fliers here")


func test_humility_waits_under_the_fifth_preset_too() -> void:
	g.rules.set_preset("fifth")
	var ai := _ai()
	put_battlefield(0, "Serra Angel")
	put_battlefield(0, "Serra Angel")
	_lands(0, "Plains", 4)
	put_battlefield(1, "Grizzly Bears")
	var humility := give_hand(0, "Humility")
	_play_main(ai)
	assert_eq(humility.zone, Mtg.Zone.HAND)


func test_humility_is_not_vetoed_against_their_bigger_army() -> void:
	var ai := _ai()
	put_battlefield(0, "Grizzly Bears")
	_lands(0, "Plains", 4)
	put_battlefield(1, "Serra Angel")
	put_battlefield(1, "Craw Wurm")
	var humility := give_hand(0, "Humility")
	advance_to_step(Mtg.Step.MAIN1)
	var swing := TS.static_projection(g, ai, humility)
	assert_lt(float(swing["theirs"]), float(swing["ours"]), "their side loses more")
	assert_null(TS.symmetric_static_choice(g, ai, humility), "the generic value decides")


func test_the_projection_leaves_the_game_as_it_was() -> void:
	var ai := _ai()
	var angel := put_battlefield(0, "Serra Angel")
	_lands(0, "Plains", 4)
	put_battlefield(1, "Grizzly Bears")
	var humility := give_hand(0, "Humility")
	advance_to_step(Mtg.Step.MAIN1)
	var state := g.rng.state
	var log_size := g.log_lines.size()
	TS.static_projection(g, ai, humility)
	assert_eq(humility.zone, Mtg.Zone.HAND)
	assert_true(g.players[0].hand.has(humility))
	assert_false(g.players[0].battlefield.has(humility))
	assert_eq(angel.cur_power, 4, "the angel is herself again")
	assert_true(angel.has_keyword(Mtg.Keyword.FLYING))
	assert_eq(g.rng.state, state)
	assert_eq(g.log_lines.size(), log_size)
	assert_null(g.undo_log, "no search journal left open")


# ------------------------------------------------------------ the hosers --

func test_dread_of_night_waits_while_it_kills_our_own_white_army() -> void:
	var ai := _ai()
	put_battlefield(0, "Femeref Knight")
	put_battlefield(0, "Benalish Hero")
	put_battlefield(0, "Soltari Foot Soldier")
	_lands(0, "Swamp", 2)
	put_battlefield(1, "Grizzly Bears")
	var dread := give_hand(0, "Dread of Night")
	_play_main(ai)
	assert_eq(dread.zone, Mtg.Zone.HAND)


func test_dread_of_night_is_not_vetoed_against_their_white_weenies() -> void:
	var ai := _ai()
	put_battlefield(0, "Grizzly Bears")
	_lands(0, "Swamp", 2)
	put_battlefield(1, "Benalish Hero")
	put_battlefield(1, "Savannah Lions")
	var dread := give_hand(0, "Dread of Night")
	advance_to_step(Mtg.Step.MAIN1)
	assert_null(TS.symmetric_static_choice(g, ai, dread))


func test_light_of_day_waits_while_it_stops_our_own_black_creatures() -> void:
	var ai := _ai()
	put_battlefield(0, "Gravedigger")
	put_battlefield(0, "Dauthi Slayer")
	_lands(0, "Plains", 4)
	put_battlefield(1, "Grizzly Bears")
	var light := give_hand(0, "Light of Day")
	_play_main(ai)
	assert_eq(light.zone, Mtg.Zone.HAND)


func test_choke_waits_while_it_locks_our_own_islands() -> void:
	var ai := _ai()
	_lands(0, "Island", 3)
	_lands(0, "Forest", 2)
	_lands(1, "Mountain", 2)
	var choke := give_hand(0, "Choke")
	_play_main(ai)
	assert_eq(choke.zone, Mtg.Zone.HAND)


func test_a_freeze_of_every_untap_step_is_left_to_the_lock_reader() -> void:
	# Stasis: priced by AiPlayer._lock_worth (its rent, a vigilance hole);
	# the projection does not second-guess it.
	var ai := _ai()
	_lands(0, "Island", 3)
	put_battlefield(1, "Serra Angel")
	var stasis := give_hand(0, "Stasis")
	advance_to_step(Mtg.Step.MAIN2)
	assert_null(TS.symmetric_static_choice(g, ai, stasis))


func test_what_stays_tapped_is_read_by_its_tapped_state() -> void:
	# Choke on their TAPPED Islands against our untapped ones: theirs stay
	# tapped for good, ours give one more use each.
	var ai := _ai()
	_lands(0, "Island", 2)
	_lands(0, "Forest", 3)
	for _i in 4:
		var island := put_battlefield(1, "Island")
		island.tapped = true
	var choke := give_hand(0, "Choke")
	advance_to_step(Mtg.Step.MAIN1)
	for inst in g.players[1].battlefield: inst.tapped = true
	var swing := TS.static_projection(g, ai, choke)
	assert_almost_eq(float(swing["ours"]), -1.0, 0.001, "two untapped Islands: half each")
	assert_almost_eq(float(swing["theirs"]), -4.0, 0.001, "four tapped Islands: nothing left")
	assert_null(TS.symmetric_static_choice(g, ai, choke))


func test_choke_is_not_vetoed_against_their_islands() -> void:
	var ai := _ai()
	_lands(0, "Forest", 3)
	_lands(1, "Island", 4)
	var choke := give_hand(0, "Choke")
	advance_to_step(Mtg.Step.MAIN1)
	assert_null(TS.symmetric_static_choice(g, ai, choke))


# --------------------------------------------------------- fair play, gate --

func test_their_hidden_cards_move_nothing() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		put_battlefield(0, "Serra Angel")
		put_battlefield(0, "Femeref Knight")
		_lands(0, "Plains", 4)
		put_battlefield(1, "Grizzly Bears")
		put_battlefield(1, "Craw Wurm")
		give_hand(1, "Disenchant" if variant == 0 else "Serra Angel")
		if variant == 1:
			g.players[1].library.reverse()
		var humility := give_hand(0, "Humility")
		advance_to_step(Mtg.Step.MAIN1)
		var swing := TS.static_projection(g, ai, humility)
		answers.append("%.4f/%.4f %s" % [float(swing["ours"]), float(swing["theirs"]),
			str(TS.symmetric_static_choice(g, ai, humility))])
	assert_eq(answers[0], answers[1], "a hidden card changed the reading")


func test_the_null_arm_reads_no_static() -> void:
	var ai := _ai(false)
	put_battlefield(0, "Serra Angel")
	_lands(0, "Plains", 4)
	var humility := give_hand(0, "Humility")
	advance_to_step(Mtg.Step.MAIN1)
	assert_null(TS.spell_choice(g, ai, humility, 0, 0), "gate off: no Pack 9 reading at all")


# ---------------------------------------------- Living Death under Humility --

## Our two Shivan Dragons against their four Grizzly Bears in the
## graveyards; a Bears of ours against two of theirs on the table.
func _living_death_board(humble: bool) -> CardInstance:
	_lands(0, "Swamp", 5)
	for _i in 2: _in_graveyard(0, "Shivan Dragon")
	for _i in 4: _in_graveyard(1, "Grizzly Bears")
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	if humble:
		put_battlefield(1, "Humility")
	return give_hand(0, "Living Death")


func test_living_death_returns_dragons_as_dragons() -> void:
	var ai := _ai()
	var death := _living_death_board(false)
	advance_to_step(Mtg.Step.MAIN1)
	var arriving: Array = TS.living_death_arrivals(g, ai, death)
	assert_gt(float(arriving[0]), float(arriving[1]), "two Dragons outweigh four Bears")
	assert_false(TS.living_death(g, ai, death).is_empty(), "cast: the Dragons come back big")


func test_living_death_under_humility_returns_one_one_bodies() -> void:
	var ai := _ai()
	var death := _living_death_board(true)
	advance_to_step(Mtg.Step.MAIN1)
	var arriving: Array = TS.living_death_arrivals(g, ai, death)
	# Under Humility each card arrives a 1/1: two of ours, four of theirs.
	assert_lt(float(arriving[0]), float(arriving[1]), "four 1/1s outnumber two")
	assert_true(TS.living_death(g, ai, death).is_empty(),
		"held: under Humility the Dragons come back as two 1/1s")
	assert_null(g.undo_log)
	assert_eq(g.players[0].graveyard.size(), 2, "the graveyards are as they were")
	assert_eq(g.players[1].battlefield.filter(
		func(i: CardInstance) -> bool: return i.is_creature()).size(), 2)
