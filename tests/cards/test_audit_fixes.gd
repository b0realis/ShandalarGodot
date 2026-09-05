extends GameTest
## Card-level pins from the mage-go scrutiny audit (docs/audit-vs-mage-go.md):
## Regeneration's real cost, Drain Life's damage-actually-dealt life gain,
## Animate Dead's sacrifice (regeneration can't save the host), Ankh of
## Mishra on FETCHED lands, Mishra's Factory pumping itself, Ashes to
## Ashes needing two DIFFERENT creatures, Land Tax re-checking its
## intervening "if" at resolution, and the became-tapped triggers (City of
## Brass / Psychic Venom stung by Icy Manipulator).


# ------------------------------------------------------------- Regeneration --

func test_regeneration_costs_one_generic_and_a_green() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := give_hand(0, "Regeneration")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_refused(g.cast_spell(0, aura, [TargetRef.card(bear)]), "not enough mana")
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))


# --------------------------------------------------------------- Drain Life --

func test_drain_life_gains_only_damage_actually_dealt() -> void:
	# A Samite Healer shield eats 1 of the X=2 — the caster gains only the
	# 1 damage that was DEALT ("equal to the damage dealt this way").
	var bear := put_battlefield(1, "Grizzly Bears")
	var healer := put_battlefield(1, "Samite Healer")
	var drain := give_hand(0, "Drain Life")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 3)   # {B} + X=2 in black (lifted 2026-09-02)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, drain, [TargetRef.card(bear)], 2))
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, healer, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.damage, 1, "1 of 2 prevented")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].life, 21, "gained 1, not 2")


func test_drain_life_gain_capped_by_victims_remaining_life() -> void:
	# "...but not more life than the player's life total before the damage."
	g.players[1].life = 2
	var drain := give_hand(0, "Drain Life")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 6)   # {B} + X=5 in black (lifted 2026-09-02)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, drain, [TargetRef.player(1)], 5))
	resolve_stack()
	assert_true(g.game_over)
	assert_eq(g.winner, 0)
	assert_eq(g.players[0].life, 22, "gained 2 (victim's life), not 5")


# ------------------------------------------------------------- Animate Dead --

func test_animate_dead_host_is_sacrificed_not_destroyed() -> void:
	# When the aura leaves, the host's controller SACRIFICES it (modern
	# oracle) — a regeneration shield cannot save it.
	var skel := put_battlefield(1, "Drudge Skeletons")
	g.destroy(skel, false)
	assert_eq(skel.zone, Mtg.Zone.GRAVEYARD)
	var animate := give_hand(0, "Animate Dead")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, animate, [TargetRef.card(skel)]))
	resolve_stack()
	assert_eq(skel.zone, Mtg.Zone.BATTLEFIELD)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, skel, 0, []))
	resolve_stack()
	assert_eq(skel.regeneration_shields, 1)
	g.destroy(animate, false)
	assert_eq(skel.zone, Mtg.Zone.GRAVEYARD,
		"sacrificed — the shield is useless against a sacrifice")


# ----------------------------------------------------------- Ankh of Mishra --

func test_ankh_triggers_on_fetched_lands_too() -> void:
	# "Whenever a land ENTERS" — Untamed Wilds putting a Forest onto the
	# battlefield stings exactly like playing one.
	put_battlefield(0, "Ankh of Mishra")
	var wilds := give_hand(0, "Untamed Wilds")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, wilds, []))
	resolve_stack()
	assert_eq(g.players[0].life, 18, "the fetched land triggered the Ankh")


# --------------------------------------------------------- Mishra's Factory --

func test_animated_factory_pumps_itself() -> void:
	# The classic line: animate, then tap to pump ITSELF to 3/3.
	var factory := put_battlefield(0, "Mishra's Factory")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, factory, 0, []))
	resolve_stack()
	assert_true(factory.is_creature())
	assert_ok(g.activate_ability(0, factory, 1, [TargetRef.card(factory)]))
	resolve_stack()
	assert_eq(factory.cur_power, 3, "2/2 pumped itself to 3/3")
	assert_eq(factory.cur_toughness, 3)


# ----------------------------------------------------------- Ashes to Ashes --

func test_ashes_to_ashes_needs_two_different_creatures() -> void:
	# "Two target nonartifact creatures" — the same creature can't fill
	# both slots (CR 601.2c: targets of one requirement must be distinct).
	var bear := put_battlefield(1, "Grizzly Bears")
	var ashes := give_hand(0, "Ashes to Ashes")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(0, ashes, [TargetRef.card(bear), TargetRef.card(bear)]),
		"same target")


# ----------------------------------------------------------------- Land Tax --

func test_land_tax_rechecks_its_condition_at_resolution() -> void:
	# Intervening "if" (CR 603.4): the land-count condition is checked
	# again when the trigger RESOLVES. Fissure the opponent's only land in
	# response and the search never happens.
	put_battlefield(0, "Land Tax")
	var mountain := put_battlefield(1, "Mountain")
	var fissure := give_hand(0, "Fissure")
	advance_to_step(Mtg.Step.MAIN1)      # turn 1 (the game starts in upkeep)
	advance_to_step(Mtg.Step.UPKEEP)     # turn 2 — the opponent's upkeep
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_step(Mtg.Step.UPKEEP)     # turn 3 — OUR upkeep: trigger is up
	assert_eq(g.stack.size(), 1, "Land Tax trigger waiting")
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, fissure, [TargetRef.card(mountain)]))
	resolve_stack()
	assert_eq(mountain.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].hand.size(), 0, "condition false at resolution — no lands fetched")


# ------------------------------------------------- became-tapped triggers --

func test_city_of_brass_stung_by_icy_manipulator() -> void:
	# "Whenever City of Brass becomes tapped" — ANY tap, not just for mana.
	var city := put_battlefield(1, "City of Brass")
	var icy := put_battlefield(0, "Icy Manipulator")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, icy, 0, [TargetRef.card(city)]))
	resolve_stack()
	assert_true(city.tapped)
	assert_eq(g.players[1].life, 19, "the City burned its controller")


func test_psychic_venom_stings_on_any_tap() -> void:
	var swamp := put_battlefield(1, "Swamp")
	var venom := give_hand(0, "Psychic Venom")
	var icy := put_battlefield(0, "Icy Manipulator")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, venom, [TargetRef.card(swamp)]))
	resolve_stack()
	assert_not_null(venom)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, icy, 0, [TargetRef.card(swamp)]))
	resolve_stack()
	assert_eq(g.players[1].life, 18, "Icy tap stings for 2")
