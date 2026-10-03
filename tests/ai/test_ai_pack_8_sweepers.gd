extends GameTest
## THE ONE-SIDED SWEEPER AND THE REAL BOARD DELTA (Pack 8, 2026-10-03;
## [member AiProfile.forecasts_tactics]).
##
## Simoon — "Simoon deals 1 damage to each creature target opponent
## controls" — is a [DamageAllEffect] with a PLAYER target and no creature
## filter, so [method AiPlayer._sweep_value] read it as hitting every
## creature on the table: the pilot priced its own 1/1s as dying with
## theirs, read an even board as a wash, and in any case offered the
## engine a cast with NO target, which [method MtgGame.cast_refusal]
## refused. The sweep's SCOPE is now read off its spec
## ([code]mirage_tactics.gd[/code] [code]sweep_scope[/code]) and the target chosen; and a
## damage sweep is priced by what the damage would actually do where the
## table can change it ([method MtgGame.predict_damage] — protection, a
## prevention shield, Benevolent Unicorn), so a creature it cannot kill
## is not counted as a kill.

const M := preload("res://engine/ai/mirage_tactics.gd")


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-8", true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


func _ai(profile: AiProfile = null) -> AiPlayer:
	var ai := AiPlayer.new(0, profile if profile != null else AiProfile.wizard())
	g.set_agent(0, ai)
	return ai


func _null() -> AiProfile:
	var p := AiProfile.wizard()
	p.forecasts_tactics = false
	return p


func _one_one(name := "Test Squire", protection := 0) -> CardData:
	var data := CardData.new(name, "{W}", Mtg.CardType.CREATURE).pt(1, 1)
	if protection != 0:
		data.with_protection_from(protection)
	return data


func _simoon_board() -> CardInstance:
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Llanowar Elves")
	put_battlefield(0, "Llanowar Elves")
	for _i in 3:
		put_synthetic(1, _one_one())
	var simoon := give_hand(0, "Simoon")
	advance_to_step(Mtg.Step.MAIN1)
	return simoon


func test_simoon_sees_only_the_targeted_opponent() -> void:
	var ai := _ai()
	var simoon := _simoon_board()
	var effect: EffectBase = simoon.data.spell_effects[0]
	assert_eq(M.sweep_scope(g, effect, 0), 1, "their creatures, never ours")
	assert_gt(ai._sweep_value(g, effect, 0, simoon), 3.0,
		"three of theirs die, none of ours: a real swing")


func test_simoon_is_cast_at_the_opponent() -> void:
	var ai := _ai()
	var simoon := _simoon_board()
	assert_string_contains(ai.act(g), "cast Simoon")
	assert_eq(g.stack.back().targets[0].player_id, 1)
	resolve_stack()
	assert_eq(g.players[1].creatures().size(), 0, "their three 1/1s are gone")
	assert_eq(g.players[0].creatures().size(), 2, "our Elves never were in it")
	assert_eq(simoon.zone, Mtg.Zone.GRAVEYARD)


func test_simoon_is_held_when_it_kills_nothing() -> void:
	# Their creatures are 2/2s: one damage kills none of them.
	var ai := _ai()
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Forest")
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	var simoon := give_hand(0, "Simoon")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_eq(simoon.zone, Mtg.Zone.HAND)


func test_a_creature_the_damage_cannot_reach_is_no_kill() -> void:
	# Protection from red: Simoon's damage is prevented (CR 702.16e), so
	# the sweep takes ONE 1/1, not two — under the sweeper bar.
	var ai := _ai()
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Forest")
	put_synthetic(1, _one_one("Test Squire"))
	put_synthetic(1, _one_one("Test Warded", Mtg.ManaColor.R))
	var simoon := give_hand(0, "Simoon")
	advance_to_step(Mtg.Step.MAIN1)
	var effect: EffectBase = simoon.data.spell_effects[0]
	var with_ward := ai._sweep_value(g, effect, 0, simoon)
	var plain := put_synthetic(1, _one_one("Test Squire"))
	var with_two := ai._sweep_value(g, effect, 0, simoon)
	assert_lt(with_ward, with_two, "the warded one is not counted")
	assert_eq(plain.zone, Mtg.Zone.BATTLEFIELD, "pricing changed nothing on the table")


func test_savage_twister_still_prices_both_sides() -> void:
	# The untargeted sweeper keeps its symmetric reading: X=1 kills our
	# two Elves and their two 1/1s — an even board is no reason to cast.
	var ai := _ai()
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Llanowar Elves")
	put_battlefield(0, "Llanowar Elves")
	put_synthetic(1, _one_one())
	put_synthetic(1, _one_one())
	var twister := give_hand(0, "Savage Twister")
	advance_to_step(Mtg.Step.MAIN1)
	var effect: EffectBase = twister.data.spell_effects[0]
	assert_eq(M.sweep_scope(g, effect, 0), -1)
	assert_lt(ai._sweep_value(g, effect, 1, twister), 3.0)


func test_null_arm_never_casts_simoon() -> void:
	var ai := _ai(_null())
	var simoon := _simoon_board()
	ai.act(g)
	assert_eq(simoon.zone, Mtg.Zone.HAND, "the pilot as it was")
