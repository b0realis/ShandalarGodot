extends GameTest
## THE LAND SWEEP (2026-09-10, [member AiProfile.levels_boards]'s second
## reading) — and THE NEXT-ATTACK TEST, which was already built.
##
## `docs/AI-next-wave.md` wave 1 row 8 asked for two things inside
## [member AiProfile.levels_boards]. One of them did not reproduce and is
## pinned here as the thing that already works, so nobody builds it twice:
##
##  * THE NEXT-ATTACK TEST — "a Wrath at a board that kills us next turn
##    even when we are ahead on value" — is THE RELIEF ([method
##    AiPlayer._sweep_relief], 2026-09-08, [member AiProfile.times_sweeps],
##    the same rung). It reads their next attack through the block planner
##    and prices the sweep at [constant AiPlayer.LETHAL_WORTH] when the
##    attack as it stands is lethal and the sweep's remainder is not. The
##    test below is the row's own board and the shipped Wizard casts on it.
##  * ARMAGEDDON WAS CAST ON A HEAD COUNT. [method AiPlayer._sweep_value]
##    priced every land at [method Evaluator.permanent_value]'s flat 1.0
##    and read no creature at all, so an all-lands sweep fired whenever
##    the opponent had two more lands — with two Serra Angels across the
##    table, and with three duals and a Library of Alexandria on ours
##    against seven Plains.
##
## Nothing here names a card. A land sweep is read off the board — every
## permanent the sweep would kill is a land, and it would kill at least
## one ([method AiPlayer._land_sweep]) — and the two readings are [method
## Evaluator.land_value] and the CLOCK each board would be left holding
## ([method AiPlayer._drought_clock], the damage [method
## AiPlayer._damage_through_blocks] puts through the other side's best
## blocks — the same reading the relief asks their next attack with).


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.levels_boards = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.levels_boards = false
	return profile


func _many(pid: int, card_name: String, n: int) -> void:
	for _i in n:
		put_battlefield(pid, card_name)


## What the pilot prices [param card_name] at as a sweeper right now.
func _price(ai: AiPlayer, card_name: String) -> float:
	var data := CardRegistry.get_card(card_name)
	var intent := EffectIntent.read(data.spell_effects, data.card_name)
	assert_not_null(intent.sweeper, "%s is a sweeper" % card_name)
	return ai._sweep_value(g, intent.sweeper, 0)


func _casts(ai: AiPlayer, card_name: String) -> bool:
	return _price(ai, card_name) >= AiPlayer.SWEEP_BAR


# ----------------------------------------- the next-attack test, already there --

func test_the_wrath_is_cast_from_ahead_when_their_attack_is_lethal() -> void:
	# THE ROW'S OWN BOARD: our Colossus of Sardia is worth 18 and their
	# five Savannah Lions 15, so the raw board swing is AGAINST the sweep
	# (-8.00) — and ten power is more than our six life.
	g.players[0].life = 6
	put_battlefield(0, "Colossus of Sardia")
	_many(1, "Savannah Lions", 5)
	var shipped := AiProfile.wizard()
	assert_true(shipped.times_sweeps, "the shipped Sorcerer and Wizard have it")
	var ai := _ai(shipped)
	assert_true(_casts(ai, "Wrath of God"),
		"the relief prices the out at LETHAL_WORTH")
	assert_gt(_price(ai, "Wrath of God"), AiPlayer.LETHAL_WORTH,
		"and it is priced as the lethal it answers")
	# And the arm without the relief is the one that declines — which is
	# the state the row was written against.
	var blind := AiProfile.wizard()
	blind.times_sweeps = false
	var ai2 := _ai(blind)
	assert_false(_casts(ai2, "Wrath of God"))
	assert_lt(_price(ai2, "Wrath of God"), 0.0, "the raw board swing alone")


func test_the_next_attack_test_is_not_the_levellers_to_gate() -> void:
	# Both readings ship at Sorcerer and above, so a second copy of the
	# lethal test under levels_boards would fire on exactly the boards
	# times_sweeps already answers.
	for profile in [AiProfile.sorcerer(), AiProfile.wizard()]:
		assert_eq(profile.times_sweeps, profile.levels_boards,
			"%s: the two knobs turn on together" % profile.profile_name)


# ------------------------------------------------------- reading the shape --

func test_a_land_sweep_is_read_off_the_board() -> void:
	var ai := _ai(_on())
	_many(0, "Plains", 2)
	_many(1, "Forest", 2)
	var geddon: EffectBase = EffectIntent.read(
		CardRegistry.get_card("Armageddon").spell_effects, "Armageddon").sweeper
	var wrath: EffectBase = EffectIntent.read(
		CardRegistry.get_card("Wrath of God").spell_effects, "Wrath of God").sweeper
	assert_true(ai._land_sweep(g, geddon, 0), "every kill is a land")
	assert_false(ai._land_sweep(g, wrath, 0), "and this one kills none at all")
	put_battlefield(1, "Grizzly Bears")
	assert_true(ai._land_sweep(g, geddon, 0), "the Bears is not one of its kills")
	assert_false(ai._land_sweep(g, wrath, 0), "the Bears IS, and it is no land")


func test_a_sweep_that_finds_no_land_is_not_a_land_sweep() -> void:
	# Nothing on the table to destroy: the reading needs a kill to read.
	var ai := _ai(_on())
	_many(0, "Plains", 2)
	var tsunami: EffectBase = EffectIntent.read(
		CardRegistry.get_card("Tsunami").spell_effects, "Tsunami").sweeper
	assert_false(ai._land_sweep(g, tsunami, 0), "no Island anywhere")
	put_battlefield(1, "Island")
	assert_true(ai._land_sweep(g, tsunami, 0))


# -------------------------------------------------- the drought's own clock --

func test_armageddon_is_refused_when_their_clock_is_the_faster() -> void:
	for arm in ["on", "off"]:
		before_each()
		var ai := _ai(_on() if arm == "on" else _off())
		_many(0, "Plains", 4)
		_many(1, "Plains", 7)
		put_battlefield(1, "Serra Angel")
		put_battlefield(1, "Serra Angel")
		if arm == "on":
			assert_false(_casts(ai, "Armageddon"),
				"eight power a turn against a board that answers nothing")
			# Four Plains at 1.75 against seven at 1.43 is a swing of 6.00;
			# eight points of clock at half a point a life takes 4.00 off it.
			assert_almost_eq(_price(ai, "Armageddon"), 2.0, 0.001)
		else:
			assert_true(_casts(ai, "Armageddon"),
				"the null counts land heads and nothing else")


func test_armageddon_is_cast_when_our_clock_is_the_faster() -> void:
	for arm in ["on", "off"]:
		before_each()
		var ai := _ai(_on() if arm == "on" else _off())
		_many(0, "Plains", 4)
		put_battlefield(0, "Serra Angel")
		put_battlefield(0, "Serra Angel")
		_many(1, "Plains", 7)
		assert_true(_casts(ai, "Armageddon"), arm)


func test_the_deficit_is_a_price_and_not_a_veto() -> void:
	# THE READING THE MEASUREMENT CHANGED, twice. A veto on the clock
	# refused an Armageddon whenever their board got anything through, and
	# against Big Green — where the reason to cast is the four fatties in
	# THEIR HAND that will never be paid for, which nothing in this engine
	# can see — it lost 18 of the 21 games that turned. Two Grizzly Bears'
	# worth of clock is one point of price, not a wall; a Serra Angel's is
	# four, and four is what the land swing cannot carry.
	var ai := _ai(_on())
	_many(0, "Plains", 4)
	_many(1, "Plains", 7)
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Savannah Lions")
	assert_eq(ai._drought_clock(g, 1), 2, "their spare walks in")
	assert_eq(ai._drought_clock(g, 0), 0, "ours is blocked")
	assert_almost_eq(_price(ai, "Armageddon"), 5.0, 0.001,
		"six of swing less two points at half a life each")
	assert_true(_casts(ai, "Armageddon"), "a close call, not a blunder")
	put_battlefield(1, "Serra Angel")
	put_battlefield(1, "Serra Angel")
	assert_eq(ai._drought_clock(g, 1), 10, "and now two fliers nothing blocks")
	assert_false(_casts(ai, "Armageddon"), "five of price against six of swing")


func test_our_own_clock_pays_the_deficit_down() -> void:
	# Only what gets PAST US is charged: a board of ours that answers
	# theirs owes nothing, however big both of them are.
	var ai := _ai(_on())
	_many(0, "Plains", 4)
	_many(1, "Plains", 7)
	put_battlefield(1, "Serra Angel")
	put_battlefield(1, "Serra Angel")
	assert_eq(ai._drought_clock(g, 1), 8, "eight a turn at an empty board")
	assert_false(_casts(ai, "Armageddon"))
	put_battlefield(0, "Serra Angel")
	put_battlefield(0, "Serra Angel")
	assert_eq(ai._drought_clock(g, 1), 0, "two fliers each and neither gets by")
	assert_eq(ai._drought_clock(g, 0), 0)
	assert_true(_casts(ai, "Armageddon"), "no deficit, no price")


func test_a_board_neither_side_gets_through_leaves_it_to_the_lands() -> void:
	# Two Bears staring at each other: no clock either way, so nothing
	# about the creatures argues against the sweep and the land swing
	# decides it, which is what the reading was for.
	var ai := _ai(_on())
	_many(0, "Plains", 4)
	_many(1, "Plains", 7)
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	assert_eq(ai._drought_clock(g, 0), 0)
	assert_eq(ai._drought_clock(g, 1), 0)
	assert_true(_casts(ai, "Armageddon"))


func test_the_clock_is_what_gets_through_and_not_what_it_weighs() -> void:
	# THE READING THE MEASUREMENT CHANGED. Two Savannah Lions against one
	# Ironroot Treefolk: on power-plus-toughness the Treefolk (8) outweighs
	# the pair (6) and an Armageddon deck reads as behind — but the wall
	# stops one Lion and the other keeps hitting, which is what a game
	# with no mana in it is decided by.
	var ai := _ai(_on())
	_many(0, "Plains", 4)
	_many(1, "Plains", 7)
	put_battlefield(0, "Savannah Lions")
	put_battlefield(0, "Savannah Lions")
	put_battlefield(1, "Ironroot Treefolk")
	assert_gt(Evaluator.permanent_value(g.players[1].battlefield[-1]),
		Evaluator.permanent_value(g.players[0].battlefield[-1])
			+ Evaluator.permanent_value(g.players[0].battlefield[-2]),
		"the Treefolk weighs more than the two Lions together")
	assert_eq(ai._drought_clock(g, 0), 2, "one Lion is blocked, one gets in")
	assert_eq(ai._drought_clock(g, 1), 0, "and a 3/5 does not get past two blockers")
	assert_true(_casts(ai, "Armageddon"), "the clock is ours")


func test_a_board_that_cannot_attack_has_no_clock() -> void:
	# A Wall is no reason to hold the sweep: it wins nothing once the mana
	# stops. Summoning sickness is not asked either — the drought lasts
	# turns, not one step.
	var ai := _ai(_on())
	_many(0, "Plains", 4)
	_many(1, "Plains", 7)
	put_battlefield(1, "Wall of Stone")
	assert_eq(ai._drought_clock(g, 1), 0, "Defender")
	assert_true(_casts(ai, "Armageddon"))
	put_battlefield(0, "Serra Angel", true)
	assert_gt(ai._drought_clock(g, 0), 0, "a sick Angel still has a clock")


func test_the_lock_across_an_empty_board_is_still_cast() -> void:
	# Forge's own clause — the creature test is asked only when THEY have
	# creatures. A control deck locking a creatureless opponent out of its
	# mana is the plan, not a blunder.
	for arm in ["on", "off"]:
		before_each()
		var ai := _ai(_on() if arm == "on" else _off())
		_many(0, "Plains", 4)
		_many(1, "Plains", 7)
		assert_true(_casts(ai, "Armageddon"), arm)


# ------------------------------------------------- the manabase, not the heads --

func test_a_good_manabase_is_worth_more_than_a_pile_of_plains() -> void:
	# Three duals, a Library of Alexandria and a City of Brass against
	# seven Plains: the null sees five lands to seven and casts; the
	# reading sees what each one is worth to its controller and declines.
	for arm in ["on", "off"]:
		before_each()
		var ai := _ai(_on() if arm == "on" else _off())
		for name_ in ["Underground Sea", "Tundra", "Volcanic Island",
				"Library of Alexandria", "City of Brass"]:
			put_battlefield(0, name_)
		put_battlefield(0, "Serra Angel")
		put_battlefield(0, "Serra Angel")
		_many(1, "Plains", 7)
		if arm == "on":
			assert_false(_casts(ai, "Armageddon"),
				"we would lose the better half of the world")
		else:
			assert_true(_casts(ai, "Armageddon"), "five heads against seven")


func test_the_one_sided_sweeper_still_takes_their_lands() -> void:
	# Tsunami takes Islands and we play none: every land it kills is
	# theirs, so the swing is all gain — and land_value says the two
	# Underground Seas are worth more than two heads.
	var ai := _ai(_on())
	_many(0, "Plains", 4)
	put_battlefield(0, "Serra Angel")
	put_battlefield(1, "Underground Sea")
	put_battlefield(1, "Underground Sea")
	assert_true(_casts(ai, "Tsunami"))
	assert_gt(_price(ai, "Tsunami"), 4.0 * Evaluator.W_BOARD,
		"two duals price above two flat permanents")


# ------------------------------------------- what the reading must not touch --

func test_a_wrath_prices_exactly_as_it_always_did() -> void:
	for arm in ["on", "off"]:
		before_each()
		var ai := _ai(_on() if arm == "on" else _off())
		_many(0, "Plains", 2)
		put_battlefield(1, "Serra Angel")
		put_battlefield(1, "Serra Angel")
		assert_true(_casts(ai, "Wrath of God"), arm)
		assert_almost_eq(_price(ai, "Wrath of God"), 44.0, 0.001, arm)


func test_an_earthquake_is_no_land_sweep_however_the_board_looks() -> void:
	var ai := _ai(_on())
	_many(0, "Plains", 4)
	_many(1, "Plains", 7)
	var quake: EffectBase = EffectIntent.read(
		CardRegistry.get_card("Earthquake").spell_effects, "Earthquake").sweeper
	assert_false(ai._land_sweep(g, quake, 3), "it kills creatures and faces")


# ------------------------------------------------------------ the ladder --

func test_the_rung_is_the_levellers_own() -> void:
	assert_false(AiProfile.apprentice().levels_boards)
	assert_false(AiProfile.magician().levels_boards)
	assert_true(AiProfile.sorcerer().levels_boards)
	assert_true(AiProfile.wizard().levels_boards)


func test_the_lab_can_run_both_arms() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("levels_boards=off"), "")
	assert_false(profile.levels_boards)
	assert_eq(profile.apply_overrides("levels_boards=on"), "")
	assert_true(profile.levels_boards)
