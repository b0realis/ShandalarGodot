extends GameTest
## THE SACRIFICE ARM (2026-09-06). Every activated ability with a
## sacrifice rider was refused outright by AiPlayer._ability_available,
## so in 2,733 battlefield-turns of Strip Mine the AI activated it ZERO
## times — the last big dead card left by the control sweep. A sacrifice
## is a PRICE now: [method AiPlayer._sacrifice_price] charges the body on
## [method AiPlayer._own_value]'s scale against what the effect buys,
## priced by [method AiPlayer._victim_value] / [method Evaluator.land_value].
##
## Only [method AiPlayer._try_activate] may see a priced sacrifice. The
## combat pump paths must not, or a Fallen Angel eats its own board one
## Serra at a time — which is what it did before the gate existed
## (tests/ai/test_ai_sweep_2026_09_02.gd). Gated by
## [member AiProfile.pays_sacrifices], on for Sorcerer and Wizard.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _lands(seat: int, land_name: String, count: int) -> void:
	for _i in count:
		put_battlefield(seat, land_name)


## Advance into the OPPONENT's turn and hand seat 0 priority in [param step].
func _their_turn_at(step: int) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == step) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400, "never reached the opponent's %s" % Mtg.step_name(step))
	assert_eq(g.priority_player, 1, "the active player gets priority first")
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


# ----------------------------------------------------------- Strip Mine --

func test_strip_mine_takes_their_only_land() -> void:
	# Their one land is a turn lost for every turn it stays gone; our Mine
	# is the third of three lands with nothing in hand that needs it.
	var ai := _ai(AiProfile.wizard())
	var mine := put_battlefield(0, "Strip Mine")
	_lands(0, "Forest", 2)
	var plains := put_battlefield(1, "Plains")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "activated Strip Mine")
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD, "the Mine is the cost, paid up front")
	resolve_stack()
	assert_eq(plains.zone, Mtg.Zone.GRAVEYARD, "and their land is gone")


func test_strip_mine_takes_the_dual_over_the_basic() -> void:
	# A Tundra is two colours in one card and their only blue source; the
	# Plains beside it is neither. Evaluator.permanent_value priced every
	# land at 1.0 and could not tell them apart.
	var ai := _ai(AiProfile.wizard())
	put_battlefield(0, "Strip Mine")
	_lands(0, "Forest", 2)
	var tundra := put_battlefield(1, "Tundra")
	var plains := put_battlefield(1, "Plains")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "activated Strip Mine")
	resolve_stack()
	assert_eq(tundra.zone, Mtg.Zone.GRAVEYARD, "the dual")
	assert_eq(plains.zone, Mtg.Zone.BATTLEFIELD, "not the basic")


func test_strip_mine_is_kept_when_the_hand_needs_the_mana() -> void:
	# Two lands on the table and a three-drop in hand: the Mine is a
	# source we cannot spare, whatever the strip would buy. Empty the hand
	# and the same board strips.
	var ai := _ai(AiProfile.wizard())
	put_battlefield(0, "Strip Mine")
	put_battlefield(0, "Forest")
	var minotaur := give_hand(0, "Hurloon Minotaur")   # {1}{R}{R}
	put_battlefield(1, "Plains")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass", "the Mine stays a mana source")
	g.players[0].hand.erase(minotaur)
	minotaur.zone = Mtg.Zone.LIBRARY
	g.priority_player = 0   # the pass handed it over; take it back
	assert_eq(ai.act(g), "activated Strip Mine", "nothing in hand needs it now")


func test_strip_mine_does_not_trade_for_their_fourth_plains() -> void:
	# One of four basics is a spare; a land for a land is no bargain, and
	# the opponent's END STEP — the mana sink's moment, whose low bar is
	# for mana the untap step would waste — must not make it one. A body
	# is not mana about to be lost.
	var ai := _ai(AiProfile.wizard())
	var mine := put_battlefield(0, "Strip Mine")
	_lands(0, "Forest", 2)
	_lands(1, "Plains", 4)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass", "not in our main phase")
	_their_turn_at(Mtg.Step.END)
	assert_eq(ai.act(g), "pass", "and not at their end step either")
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD)


func test_the_bottom_difficulties_never_strip() -> void:
	# The ladder: a capability, like plays_engines — off for the two
	# lowest profiles and on for the two highest.
	assert_false(AiProfile.apprentice().pays_sacrifices)
	assert_false(AiProfile.magician().pays_sacrifices)
	assert_true(AiProfile.sorcerer().pays_sacrifices)
	assert_true(AiProfile.wizard().pays_sacrifices)
	var ai := _ai(AiProfile.magician())
	var mine := put_battlefield(0, "Strip Mine")
	_lands(0, "Forest", 2)
	put_battlefield(1, "Plains")
	advance_to_step(Mtg.Step.MAIN1)
	for _i in 4:
		assert_ne(ai.act(g), "activated Strip Mine")
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------- the body as the price --

func test_goblin_digging_team_demolishes_a_wall_worth_more_than_itself() -> void:
	# A 1/1 for a 0/8 Wall of Stone is the trade the card exists for; the
	# same 1/1 for a 0/3 Wall of Wood is not.
	var ai := _ai(AiProfile.wizard())
	var team := put_battlefield(0, "Goblin Digging Team")
	put_battlefield(0, "Mountain")
	var wood := put_battlefield(1, "Wall of Wood")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ne(ai.act(g), "activated Goblin Digging Team", "a Wall of Wood is not worth the goblins")
	var stone := put_battlefield(1, "Wall of Stone")
	g.priority_player = 0   # the pass handed it over; take it back
	assert_eq(ai.act(g), "activated Goblin Digging Team")
	assert_eq(team.zone, Mtg.Zone.GRAVEYARD, "the goblins are the cost")
	resolve_stack()
	assert_eq(stone.zone, Mtg.Zone.GRAVEYARD, "the Wall of Stone is down")
	assert_eq(wood.zone, Mtg.Zone.BATTLEFIELD)


func test_fallen_angel_does_not_eat_a_body_to_win_a_block() -> void:
	# BLOCKED by a 3/3 flier, a +2/+1 would let the Angel kill it and
	# live — the case where the pump is worth wanting. The combat pump
	# path reads the effect and not the cost, so a pump whose price is a
	# body must stay invisible to it; only _try_activate prices one.
	var ai := _ai(AiProfile.wizard())
	var angel := put_battlefield(0, "Fallen Angel")
	var bears := put_battlefield(0, "Grizzly Bears")
	var monster := put_battlefield(1, "Phantom Monster")   # 3/3 flying
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [angel.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {monster.id: angel.id}))
	assert_eq(g.priority_player, 0)
	assert_eq(ai.act(g), "pass")
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "the Bears live")
	assert_eq(angel.cur_power, 3, "and the Angel is unpumped")


# ---------------------------------------------- the same ledger, by spell --

func test_stone_rain_picks_the_dual() -> void:
	# The spell targeter shops by the same land price as the Mine.
	var ai := _ai(AiProfile.wizard())
	_lands(0, "Mountain", 3)
	give_hand(0, "Stone Rain")   # {2}{R}
	put_battlefield(1, "Plains")
	put_battlefield(1, "Plains")
	var tundra := put_battlefield(1, "Tundra")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "cast Stone Rain")
	resolve_stack()
	assert_eq(tundra.zone, Mtg.Zone.GRAVEYARD, "the Tundra, not a Plains")


# --------------------------------------------------- Evaluator.land_value --

func test_land_value_reads_scarcity_duals_only_sources_and_abilities() -> void:
	var plains := put_battlefield(1, "Plains")
	assert_almost_eq(Evaluator.land_value(g, plains), 5.0, 0.01,
		"their only land: 1 + 3/1 scarcity, +1 as the only white source")
	put_battlefield(1, "Plains")
	put_battlefield(1, "Plains")
	assert_almost_eq(Evaluator.land_value(g, plains), 2.0, 0.01,
		"one of three: 1 + 3/3, and white has other sources")
	var tundra := put_battlefield(1, "Tundra")
	assert_almost_eq(Evaluator.land_value(g, tundra), 1.75 + 1.0 + 1.0, 0.01,
		"one of four, +1 a dual, +1 the only blue source")
	var factory := put_battlefield(1, "Mishra's Factory")
	assert_almost_eq(Evaluator.land_value(g, factory), 1.6 + 1.5, 0.01,
		"one of five, +1.5 for doing more than making mana")
	assert_almost_eq(Evaluator.land_value(g, plains, 2), 1.0 + 3.0 / 7.0, 0.01,
		"lands in hand count with the five on the table when a seat prices its own")


# ------------------------------------------ AiProfile.apply_overrides --

func test_profile_overrides_read_knobs_by_their_own_type() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("pays_sacrifices=off,aggression=0.7,chump_threshold=2"), "")
	assert_false(profile.pays_sacrifices)
	assert_almost_eq(profile.aggression, 0.7, 0.001)
	assert_eq(profile.chump_threshold, 2)
	assert_eq(profile.profile_name, "Wizard", "the name is not a knob")


func test_profile_overrides_name_the_knob_they_refuse() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("plays_engine=off"), "plays_engine",
		"a misspelling is refused by name")
	assert_true(profile.plays_engines, "and nothing was applied")
	assert_eq(profile.apply_overrides("profile_name=Bob"), "profile_name")
	assert_eq(profile.apply_overrides("aggression"), "aggression",
		"a knob with no value")
	assert_eq(profile.apply_overrides(""), "", "an empty spec is fine")
