extends GameTest
## Pack 10 (the Urza block), the fair AI's SPELLS COUNTED AS THEY RESOLVE
## (stage 4, casting; engine/ai/urza_spells.gd, [member
## AiProfile.forecasts_tactics]).
##
## Corrupt's Swamps, the Scents' revealed cards of a colour (our own hand),
## Titania's Boon's creatures, Congregate's bodies, Goblin Offensive's X,
## Falter's grounded blockers, Last-Ditch Effort's sacrifices, Plow Under's
## two lands and Fatigue's skipped draw. The typed effects these cards
## subclass read 0 until they resolve (a DamageEffect of 0, a GainLife of 2
## per nothing), so the amount is counted off the board here and the cast
## aimed where it does its work. With the gate off the pilot casts as before
## Pack 10.


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-10", true)
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
	for _i in n:
		put_battlefield(pid, land)


func _cast_now(ai: AiPlayer, card: CardInstance) -> bool:
	advance_to_step(Mtg.Step.MAIN1)
	g.players[0].lands_played_this_turn = 99
	for _i in 3:
		if card.zone != Mtg.Zone.HAND:
			break
		ai.act(g)
	return card.zone != Mtg.Zone.HAND


# ---------------------------------------------------------------------- Corrupt --

func test_corrupt_counts_our_swamps_into_lethal() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 7)
	g.players[1].life = 7
	var corrupt := give_hand(0, "Corrupt")
	assert_true(_cast_now(ai, corrupt))
	resolve_stack()
	assert_true(g.game_over)
	assert_eq(g.winner, 0)


# -------------------------------------------------------------------- the Scents --

func test_scent_of_cinder_counts_our_red_cards() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 2)
	for _i in 3: give_hand(0, "Shivan Dragon")
	var giant := put_battlefield(1, "Hill Giant")
	var scent := give_hand(0, "Scent of Cinder")
	assert_true(_cast_now(ai, scent))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "three red cards revealed: 3 damage")


func test_scent_of_cinder_with_no_red_card_is_kept() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 2)
	give_hand(0, "Air Elemental")
	put_battlefield(1, "Hill Giant")
	var scent := give_hand(0, "Scent of Cinder")
	assert_false(_cast_now(ai, scent), "X would be 0")


func test_scent_of_cinder_reads_only_our_hand() -> void:
	var outcomes: Array = []
	for hand in [["Shivan Dragon", "Lightning Bolt"], ["Forest", "Island"]]:
		g = null
		before_each()
		var ai := _ai()
		_lands(0, "Mountain", 2)
		for _i in 3: give_hand(0, "Shivan Dragon")
		put_battlefield(1, "Hill Giant")
		for card_name in hand: give_hand(1, card_name)
		if hand[0] == "Forest":
			g.players[0].library.reverse()
			g.players[1].library.reverse()
		var scent := give_hand(0, "Scent of Cinder")
		outcomes.append(_cast_now(ai, scent))
	assert_eq(outcomes, [true, true])


# --------------------------------------------------------------- Titania's Boon --

func test_titanias_boon_over_a_board() -> void:
	var ai := _ai()
	_lands(0, "Forest", 4)
	for _i in 3: put_battlefield(0, "Grizzly Bears")
	var boon := give_hand(0, "Titania's Boon")
	assert_true(_cast_now(ai, boon))
	resolve_stack()
	assert_eq(g.players[0].creatures()[0].cur_power, 3)


func test_titanias_boon_waits_for_a_board() -> void:
	var ai := _ai()
	_lands(0, "Forest", 4)
	put_battlefield(0, "Grizzly Bears")
	var boon := give_hand(0, "Titania's Boon")
	assert_false(_cast_now(ai, boon))


# ------------------------------------------------------------------- Congregate --

func test_congregate_when_the_life_is_needed() -> void:
	var ai := _ai()
	_lands(0, "Plains", 4)
	for _i in 3: put_battlefield(1, "Craw Wurm")
	for _i in 2: put_battlefield(0, "Grizzly Bears")
	g.players[0].life = 6
	var congregate := give_hand(0, "Congregate")
	assert_true(_cast_now(ai, congregate))
	resolve_stack()
	assert_eq(g.players[0].life, 16)


func test_congregate_waits_at_full_life_with_no_attacker() -> void:
	var ai := _ai()
	_lands(0, "Plains", 4)
	for _i in 2: put_battlefield(0, "Grizzly Bears")
	var congregate := give_hand(0, "Congregate")
	assert_false(_cast_now(ai, congregate))


# ------------------------------------------------------------- Goblin Offensive --

func test_goblin_offensive_at_the_largest_x() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 6)
	var offensive := give_hand(0, "Goblin Offensive")
	assert_true(_cast_now(ai, offensive))
	resolve_stack()
	assert_eq(g.players[0].creatures().size(), 3)


# ------------------------------------------------------------------------ Falter --

func test_falter_opens_a_lethal_attack() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 2)
	for _i in 3: put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Wall of Stone")
	put_battlefield(1, "Wall of Stone")
	g.players[1].life = 6
	var falter := give_hand(0, "Falter")
	assert_true(_cast_now(ai, falter))


func test_falter_against_fliers_only_is_kept() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 2)
	for _i in 3: put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Serra Angel")
	g.players[1].life = 6
	var falter := give_hand(0, "Falter")
	assert_false(_cast_now(ai, falter))


func test_falter_never_on_their_turn() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 2)
	for _i in 3: put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Wall of Stone")
	var falter := give_hand(0, "Falter")
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	if g.priority_player == 1:
		assert_ok(g.pass_priority(1))
	ai.act(g)
	assert_eq(falter.zone, Mtg.Zone.HAND)


# --------------------------------------------------------------- Last-Ditch Effort --

func test_last_ditch_effort_for_the_game() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 1)
	for _i in 3: put_battlefield(0, "Grizzly Bears")
	g.players[1].life = 3
	var effort := give_hand(0, "Last-Ditch Effort")
	assert_true(_cast_now(ai, effort))
	resolve_stack()
	assert_true(g.game_over)


func test_last_ditch_effort_never_eats_a_board_for_nothing() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 1)
	for _i in 3: put_battlefield(0, "Grizzly Bears")
	var effort := give_hand(0, "Last-Ditch Effort")
	assert_false(_cast_now(ai, effort))


# -------------------------------------------------------------------- Plow Under --

func test_plow_under_tops_two_of_their_lands() -> void:
	var ai := _ai()
	_lands(0, "Forest", 5)
	_lands(1, "Mountain", 4)
	var plow := give_hand(0, "Plow Under")
	assert_true(_cast_now(ai, plow))
	resolve_stack()
	assert_eq(g.players[1].battlefield.size(), 2)
	assert_eq(g.players[0].battlefield.size(), 5, "never our own")


# ----------------------------------------------------------------------- Fatigue --

func test_fatigue_at_their_draw() -> void:
	var ai := _ai()
	_lands(0, "Island", 2)
	var fatigue := give_hand(0, "Fatigue")
	assert_true(_cast_now(ai, fatigue))
	resolve_stack()
	assert_eq(g.players[1].skip_draw_steps, 1)
	assert_eq(g.players[0].skip_draw_steps, 0)
