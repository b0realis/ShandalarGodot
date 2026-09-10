extends GameTest
## THE LAND THAT IS A BLOCKER, AND THE ONE OF OURS THAT COULD BE
## (2026-09-10, [member AiProfile.reads_manlands]; `docs/forge/combat.md`
## P7, and the third pass's own open row — *"no rung animates a Factory
## to BLOCK on the opponent's turn"*, `docs/ai-difficulty.md` §5).
##
## TWO HALVES OF ONE READ, reproduced on the same afternoon and shipped
## under one knob because either alone is a lie.
##
##  * THEIRS. [method AiPlayer._attack_choice] lists their untapped
##    CREATURES as the blockers an attack is priced against: `blockers the
##    attack reading sees: 0` with a Mishra's Factory and an Island on the
##    table, `_attack_risk = -1.0`, and the body sent into a 2/2 that
##    costs them a mana.
##  * OURS. `declared 0 block(s)`, life 20 → 18, three untapped lands —
##    because [method AiPlayer._animation_value] prices an animation by
##    the attack it enables and answers 0.0 at every moment but our own
##    precombat main.
##
## Ship only the first and the pilot grows timid about a body the AI
## across the table never makes; ship only the second and it makes a body
## the reading opposite cannot see. Every behaviour below is pinned with
## the knob ON and with it OFF.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.reads_manlands = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.reads_manlands = false
	return profile


func _untapped_lands(seat: int) -> int:
	var n := 0
	for inst in g.players[seat].battlefield:
		if inst.is_land() and not inst.tapped:
			n += 1
	return n


func _reach_attackers(ai: AiPlayer) -> void:
	var guard := 0
	while not g.awaiting_attackers and not g.game_over and guard < 40:
		if g.priority_player == 0:
			ai.act(g)
		else:
			assert_ok(g.pass_priority(1))
		guard += 1
	assert_true(g.awaiting_attackers, "reached the declaration")


func _their_turn() -> void:
	var guard := 0
	while (not g.awaiting_attackers or g.active_player != 1) \
			and not g.game_over and guard < 200:
		if g.awaiting_attackers:
			assert_ok(g.declare_attackers(g.active_player, []))
		elif g.awaiting_blockers:
			assert_ok(g.declare_blockers(g.opponent_of(g.active_player), {}))
		else:
			assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_true(g.awaiting_attackers, "reached their declaration")


func _reach_blockers(ai: AiPlayer) -> void:
	var guard := 0
	while not g.awaiting_blockers and not g.game_over and guard < 60:
		if g.priority_player == 0:
			ai.act(g)
		else:
			assert_ok(g.pass_priority(1))
		guard += 1
	assert_true(g.awaiting_blockers, "reached the block declaration")


func _play_out_combat(ai: AiPlayer, foe: AiPlayer) -> void:
	var guard := 0
	while not g.game_over and g.current_step() <= Mtg.Step.COMBAT_END \
			and guard < 120:
		var mine := ai.act(g)
		var theirs := foe.act(g)
		if mine == "" and theirs == "":
			assert_ok(g.pass_priority(g.priority_player))
		guard += 1


# ---------------------------------------------- theirs, when we attack --

func test_the_elves_do_not_walk_into_a_factory_with_a_mana_up() -> void:
	# A 1/1 into a Factory with {1} open is a body handed over for a mana:
	# the 2/2 kills it and walks away a land again at cleanup.
	var ai := _ai(_on())
	var elves := put_battlefield(0, "Llanowar Elves")
	put_battlefield(1, "Mishra's Factory")
	put_battlefield(1, "Island")
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 0 attacker")
	assert_eq(elves.zone, Mtg.Zone.BATTLEFIELD)


func test_off_the_elves_walk_into_it() -> void:
	var ai := _ai(_off())
	var elves := put_battlefield(0, "Llanowar Elves")
	put_battlefield(1, "Mishra's Factory")
	put_battlefield(1, "Island")
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 1 attacker",
		"a Factory is a land and a land does not block")


func test_a_factory_with_no_mana_behind_it_is_still_a_land() -> void:
	# The cost has to come from their OTHER sources — a Factory that taps
	# for its own {1} is a tapped body and no blocker at all (CR 509.1a),
	# which is [method AiPlayer._animation_payable]'s rule read from the
	# other side of the table. Both arms send the Elves.
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		put_battlefield(0, "Llanowar Elves")
		put_battlefield(1, "Mishra's Factory")
		_reach_attackers(ai)
		assert_string_contains(ai.act(g), "declared 1 attacker")


func test_a_tapped_factory_is_no_blocker() -> void:
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		put_battlefield(0, "Llanowar Elves")
		var factory := put_battlefield(1, "Mishra's Factory")
		factory.tapped = true
		put_battlefield(1, "Island")
		put_battlefield(1, "Island")
		g.recalculate()
		_reach_attackers(ai)
		assert_string_contains(ai.act(g), "declared 1 attacker")


func test_the_reading_is_the_shape_and_not_the_land() -> void:
	# Jade Statue is an ARTIFACT with the same shape, and Forge's own
	# reading names "an opposing land or artifact". Its printed rider —
	# "activate only during combat" — is honoured off the ability rather
	# than assumed, which is why the same board answers differently in
	# the main phase and in the declaration this reading is made at.
	var ai := _ai(_on())
	put_battlefield(1, "Jade Statue")
	put_battlefield(1, "Island")
	put_battlefield(1, "Island")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai._animatable_bodies(g, 1).size(), 0,
		"outside combat the Statue may not be activated at all")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_eq(ai._animatable_bodies(g, 1).size(), 1,
		"in the declaration it is a body the attack has to count")


func test_a_statue_they_cannot_pay_for_is_not_a_body() -> void:
	var ai := _ai(_on())
	put_battlefield(1, "Jade Statue")
	put_battlefield(1, "Island")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_eq(ai._animatable_bodies(g, 1).size(), 0, "{2} against one Island")


# ------------------------------------------------ ours, when we block --

func test_our_factory_answers_a_grizzly_bears() -> void:
	var ai := _ai(_on())
	var foe := _ai(AiProfile.wizard(), 1)
	var factory := put_battlefield(0, "Mishra's Factory")
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	var bears := put_battlefield(1, "Grizzly Bears")
	_their_turn()
	assert_ok(g.declare_attackers(1, [bears.id]))
	_reach_blockers(ai)
	assert_true(factory.is_creature(), "the Factory was animated for the block")
	assert_string_contains(ai.act(g), "declared 1 block")
	assert_eq(int(g.combat.blocks.get(factory.id, -1)), bears.id,
		"the Factory is what stepped out")
	_play_out_combat(ai, foe)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "the Bears died")
	assert_eq(g.players[0].life, 20, "and nothing got through")


func test_off_our_factory_watches_the_bears_go_by() -> void:
	var ai := _ai(_off())
	var foe := _ai(AiProfile.wizard(), 1)
	var factory := put_battlefield(0, "Mishra's Factory")
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	var bears := put_battlefield(1, "Grizzly Bears")
	_their_turn()
	assert_ok(g.declare_attackers(1, [bears.id]))
	_reach_blockers(ai)
	assert_string_contains(ai.act(g), "declared 0 block")
	_play_out_combat(ai, foe)
	assert_eq(g.players[0].life, 18, "two landed on us")
	assert_eq(_untapped_lands(0), 3, "with the mana never for anything")


func test_the_land_is_not_thrown_under_a_craw_wurm() -> void:
	# [method AiPlayer._animation_value]'s own refusal, mirrored: what
	# animates here is almost always a LAND, so the body steps out only
	# when it lives, or takes the attacker with it. A 2/2 in front of a
	# 6/4 is a mana source spent on two points of life.
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		var factory := put_battlefield(0, "Mishra's Factory")
		put_battlefield(0, "Island")
		put_battlefield(0, "Island")
		var wurm := put_battlefield(1, "Craw Wurm")
		_their_turn()
		assert_ok(g.declare_attackers(1, [wurm.id]))
		_reach_blockers(ai)
		assert_string_contains(ai.act(g), "declared 0 block")
		assert_eq(factory.zone, Mtg.Zone.BATTLEFIELD)
		assert_eq(_untapped_lands(0), 3, "and the mana is still there")


func test_a_factory_that_can_only_pay_for_itself_stays_a_land() -> void:
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		var factory := put_battlefield(0, "Mishra's Factory")
		var bears := put_battlefield(1, "Grizzly Bears")
		_their_turn()
		assert_ok(g.declare_attackers(1, [bears.id]))
		_reach_blockers(ai)
		assert_string_contains(ai.act(g), "declared 0 block")
		assert_false(factory.is_creature())


func test_the_animation_is_never_bought_after_the_blocks() -> void:
	# The window is their declare-attackers and nothing else: a body
	# animated once the blockers are in did not block.
	var ai := _ai(_on())
	var factory := put_battlefield(0, "Mishra's Factory")
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	var bears := put_battlefield(1, "Grizzly Bears")
	_their_turn()
	assert_ok(g.declare_attackers(1, [bears.id]))
	_reach_blockers(ai)
	assert_ok(g.declare_blockers(0, {}))
	assert_eq(ai._combat_animation(g), "",
		"the blockers are declared: there is nothing left to buy")


func test_the_probe_leaves_no_pump_plan_behind() -> void:
	# [method AiPlayer._block_choice_once_pumped] writes the breath
	# allotment down for [method AiPlayer._combat_planned_pumps] to spend,
	# and that member is not journaled — a probe that left its own
	# allotment there would have the pilot paying for a block on a board
	# that never existed.
	var ai := _ai(_on())
	put_battlefield(0, "Mishra's Factory")
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	var bears := put_battlefield(1, "Grizzly Bears")
	_their_turn()
	assert_ok(g.declare_attackers(1, [bears.id]))
	_reach_blockers(ai)
	ai._pump_plan = {4242: 3}
	ai._pump_plan_turn = 99
	var factory: CardInstance = g.players[0].battlefield[0]
	var anim: AnimateSelfEffect = EffectIntent.read(
		factory.cur_activated_abilities[0].effects, "Mishra's Factory").animates
	var attackers: Array[CardInstance] = [bears]
	ai._would_block_once_animated(g, factory, anim, attackers)
	assert_eq(ai._pump_plan, {4242: 3}, "the plan is put back")
	assert_eq(ai._pump_plan_turn, 99)


# --------------------------------------------------------------- the ladder --

func test_the_ladder_reads_from_sorcerer_up() -> void:
	assert_false(AiProfile.apprentice().reads_manlands)
	assert_false(AiProfile.magician().reads_manlands)
	assert_true(AiProfile.sorcerer().reads_manlands)
	assert_true(AiProfile.wizard().reads_manlands)


func test_the_knob_reads_from_the_lab() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("reads_manlands=off"), "")
	assert_false(profile.reads_manlands)
	assert_eq(profile.apply_overrides("reads_manlands=on"), "")
	assert_true(profile.reads_manlands)
