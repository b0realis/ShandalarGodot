extends GameTest
## Wave-69 tests: Banshee (split rounding), City of Shadows (an exile-a-
## permanent COST plus a counter-driven battery), Deep Water (a seat-level
## mana recolour), Relic Bind (a mode chosen inside a trigger), Pyramids (a
## DESTRUCTION shield that is not regeneration) and Goblin Artisans (a coin
## flip with a cross-stack targeting restriction).


## Picks a fixed OPTION index — and, for a trigger's "Select target
## player." question (Relic Bind announces its target as it goes on the
## stack, CR 603.3d), the named player.
class ModeAgent extends DecisionAgent:
	var want := 0
	var target_name := "P1"

	func answer_option(_game: MtgGame, _pid: int, prompt: String,
			options: Array[String], _hint: int) -> int:
		if prompt == "Select target player.":
			return maxi(options.find(target_name), 0)
		return clampi(want, 0, options.size() - 1)


func test_registry_loaded_wave69() -> void:
	for name in ["Banshee", "City of Shadows", "Deep Water", "Relic Bind",
			"Pyramids", "Goblin Artisans"]:
		assert_not_null(CardRegistry.get_card(name), name)


# ---------------------------------------------------------------- Banshee --

func test_banshee_splits_an_even_x_evenly() -> void:
	var banshee := put_battlefield(0, "Banshee")
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, banshee, 0, [TargetRef.player(1)], 4))
	resolve_stack()
	assert_eq(g.players[1].life, 18)
	assert_eq(g.players[0].life, 18)


func test_banshee_rounds_the_victims_half_down_and_yours_up() -> void:
	var banshee := put_battlefield(0, "Banshee")
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.activate_ability(0, banshee, 0, [TargetRef.player(1)], 5))
	resolve_stack()
	assert_eq(g.players[1].life, 18, "half of 5 rounded down")
	assert_eq(g.players[0].life, 17, "half of 5 rounded up")


func test_banshee_at_x_of_one_only_hurts_you() -> void:
	var banshee := put_battlefield(0, "Banshee")
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.activate_ability(0, banshee, 0, [TargetRef.player(1)], 1))
	resolve_stack()
	assert_eq(g.players[1].life, 20)
	assert_eq(g.players[0].life, 19)


# -------------------------------------------------------- City of Shadows --

func test_city_of_shadows_eats_a_creature_for_a_counter() -> void:
	var city := put_battlefield(0, "City of Shadows")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, city, 0))
	assert_eq(bear.zone, Mtg.Zone.EXILE, "the creature goes as a COST")
	resolve_stack()
	assert_eq(int(city.counters.get("storage", 0)), 1)


func test_city_of_shadows_taps_for_its_counters() -> void:
	var city := put_battlefield(0, "City of Shadows")
	city.counters["storage"] = 3
	assert_ok(g.tap_for_mana(0, city))
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.C), 3)


func test_city_of_shadows_is_refused_with_no_creature() -> void:
	var city := put_battlefield(0, "City of Shadows")
	assert_refused(g.activate_ability(0, city, 0), "no creature you control to exile")


# ------------------------------------------------------------- Deep Water --

func test_deep_water_turns_your_lands_blue() -> void:
	var water := put_battlefield(0, "Deep Water")
	var forest := put_battlefield(0, "Forest")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(0, water, 0))
	resolve_stack()
	assert_ok(g.tap_for_mana(0, forest))
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.U), 1)
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.G), 0)


func test_deep_water_keeps_the_amount() -> void:
	var water := put_battlefield(0, "Deep Water")
	var city := put_battlefield(0, "City of Shadows")
	city.counters["storage"] = 4
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(0, water, 0))
	resolve_stack()
	assert_ok(g.tap_for_mana(0, city))
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.U), 4,
		"four storage counters, four BLUE")


func test_deep_water_leaves_artifacts_alone() -> void:
	var water := put_battlefield(0, "Deep Water")
	var ring := put_battlefield(0, "Sol Ring")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(0, water, 0))
	resolve_stack()
	assert_ok(g.tap_for_mana(0, ring))
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.C), 2,
		"a Sol Ring is not a land")


func test_deep_water_ends_with_the_turn() -> void:
	var water := put_battlefield(0, "Deep Water")
	var forest := put_battlefield(0, "Forest")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(0, water, 0))
	resolve_stack()
	advance_to_next_turn()
	advance_to_next_turn()
	assert_ok(g.tap_for_mana(0, forest))
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.G), 1)


# ------------------------------------------------------------ Relic Bind --

func _bound_ring() -> Array:
	var ring := put_battlefield(1, "Sol Ring")
	var aura := give_hand(0, "Relic Bind")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(ring)]))
	resolve_stack()
	return [ring, aura]


func test_relic_bind_burns_when_the_artifact_taps() -> void:
	var agent := ModeAgent.new()
	agent.want = 1   # "Take damage."
	g.set_agent(0, agent)
	var pair := _bound_ring()
	var ring: CardInstance = pair[0]
	assert_ok(g.tap_for_mana(1, ring))
	resolve_stack()
	assert_eq(g.players[1].life, 19)


func test_relic_bind_can_gain_life_instead() -> void:
	var agent := ModeAgent.new()
	agent.want = 0   # "Gain life."
	agent.target_name = "P0"
	g.set_agent(0, agent)
	var pair := _bound_ring()
	var ring: CardInstance = pair[0]
	assert_ok(g.tap_for_mana(1, ring))
	resolve_stack()
	assert_eq(g.players[1].life, 20)
	assert_eq(g.players[0].life, 21)


func test_relic_bind_cannot_enchant_your_own_artifact() -> void:
	var mine := put_battlefield(0, "Sol Ring")
	var aura := give_hand(0, "Relic Bind")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.cast_spell(0, aura, [TargetRef.card(mine)]), "Illegal target")


# --------------------------------------------------------------- Pyramids --

func test_pyramids_destroy_an_aura_on_a_land() -> void:
	var pyramids := put_battlefield(0, "Pyramids")
	var land := put_battlefield(1, "Forest")
	var aura := put_battlefield(1, "Wild Growth")
	g.attach_aura_from_anywhere(aura, land, 1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, pyramids, 0, [TargetRef.card(aura)]))
	resolve_stack()
	assert_eq(aura.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD, "the land itself is untouched")


func test_pyramids_shelter_a_land_from_destruction() -> void:
	var pyramids := put_battlefield(0, "Pyramids")
	var land := put_battlefield(0, "Forest")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, pyramids, 1, [TargetRef.card(land)]))
	resolve_stack()
	assert_eq(land.destruction_shields, 1)
	g.destroy(land)
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD, "the destruction was replaced")
	assert_false(land.tapped, "and NOT regenerated — no tap")
	g.destroy(land)
	assert_eq(land.zone, Mtg.Zone.GRAVEYARD, "one shelter, one destruction")


func test_pyramids_shield_beats_cant_be_regenerated() -> void:
	var pyramids := put_battlefield(0, "Pyramids")
	var land := put_battlefield(0, "Forest")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, pyramids, 1, [TargetRef.card(land)]))
	resolve_stack()
	g.destroy(land, false)
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD,
		"it is a replacement, not regeneration")


func test_pyramids_shield_lasts_only_this_turn() -> void:
	var pyramids := put_battlefield(0, "Pyramids")
	var land := put_battlefield(0, "Forest")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, pyramids, 1, [TargetRef.card(land)]))
	resolve_stack()
	advance_to_next_turn()
	assert_eq(land.destruction_shields, 0)


# -------------------------------------------------------- Goblin Artisans --

func test_goblin_artisans_needs_an_artifact_spell_of_yours() -> void:
	var goblin := put_battlefield(0, "Goblin Artisans")
	assert_refused(g.activate_ability(0, goblin, 0, []), "target")


func test_goblin_artisans_flips_for_a_card_or_your_own_spell() -> void:
	var goblin := put_battlefield(0, "Goblin Artisans")
	var ring := give_hand(0, "Sol Ring")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, ring, []))
	var hand_before := g.players[0].hand.size()
	assert_ok(g.activate_ability(0, goblin, 0, [TargetRef.card(ring)]))
	resolve_stack()
	var drew := g.players[0].hand.size() > hand_before
	var countered := ring.zone == Mtg.Zone.GRAVEYARD
	assert_true(drew != countered, "exactly one of the two outcomes happened")


func test_a_second_artisans_cannot_claim_the_same_spell() -> void:
	var first := put_battlefield(0, "Goblin Artisans")
	var second := put_battlefield(0, "Goblin Artisans")
	var ring := give_hand(0, "Sol Ring")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, ring, []))
	assert_ok(g.activate_ability(0, first, 0, [TargetRef.card(ring)]))
	assert_refused(g.activate_ability(0, second, 0, [TargetRef.card(ring)]),
		"Illegal target")
