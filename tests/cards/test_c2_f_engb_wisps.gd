extends GameTest
## Campaign 2026-10-12 (b4-1) — Withering Wisps (Ice Age):
## "{B}: This enchantment deals 1 damage to each creature and each player.
##  Activate no more times each turn than the number of snow Swamps you
##  control."
##
## The limit (cards/sets/ice/_snow.gd _wisps_limit) reads
## CardInstance.ability_uses, which MtgGame.activate_ability only kept for
## an ability with a fixed max_per_turn — so the count stayed 0 and one
## snow Swamp allowed any number of activations. Every activation is now
## counted.

const PRESETS := ["modern_mana_burn", "fifth"]


func before_each() -> void:
	CardPacks.set_enabled(IceAgePack.ID, true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled(IceAgePack.ID, false)


func _board(preset: String, swamps: int) -> CardInstance:
	before_each()
	g.rules.set_preset(preset)
	var wisps := put_battlefield(0, "Withering Wisps")
	for n in swamps:
		put_battlefield(0, "Snow-Covered Swamp")
	put_battlefield(0, "Craw Wurm")   # keeps a creature on the board
	advance_to_step(Mtg.Step.MAIN1)
	return wisps


func test_one_snow_swamp_allows_one_activation_a_turn() -> void:
	for preset in PRESETS:
		var wisps := _board(preset, 1)
		add_mana(0, Mtg.ManaColor.B, 3)
		assert_ok(g.activate_ability(0, wisps, 0))
		resolve_stack()
		assert_refused(g.activate_ability(0, wisps, 0), "snow Swamps")
		assert_eq(g.players[1].life, 19, "one activation (%s)" % preset)


func test_two_snow_swamps_allow_two() -> void:
	for preset in PRESETS:
		var wisps := _board(preset, 2)
		add_mana(0, Mtg.ManaColor.B, 3)
		assert_ok(g.activate_ability(0, wisps, 0))
		assert_ok(g.activate_ability(0, wisps, 0))   # in response to itself counts too
		assert_refused(g.activate_ability(0, wisps, 0), "snow Swamps")
		resolve_stack()
		assert_eq(g.players[1].life, 18, "two activations (%s)" % preset)


func test_no_snow_swamp_allows_none() -> void:
	var wisps := _board("modern_mana_burn", 0)
	add_mana(0, Mtg.ManaColor.B)
	assert_refused(g.activate_ability(0, wisps, 0), "snow Swamps")


func test_the_count_starts_again_next_turn() -> void:
	var wisps := _board("modern_mana_burn", 1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, wisps, 0))
	resolve_stack()
	advance_to_next_turn()   # the opponent's turn: a new turn, a new count
	assert_ok(g.pass_priority(1))   # P0 gets priority in P1's main phase
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, wisps, 0))
	resolve_stack()
	assert_eq(g.players[1].life, 18)
