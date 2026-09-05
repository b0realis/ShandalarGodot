extends GameTest
## Card pins from the 2026-08 code review (docs/code-review-2026-08.md).
## Every test here failed before the fix recorded in the same row.


## A seat that declines every optional cost — the other half of every
## "unless you sacrifice ..." clause.
class RefusingAgent extends DecisionAgent:
	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String, _hint: bool) -> bool:
		return false


# ------------------------------------------------------------- Erg Raiders --

func test_erg_raiders_costs_one_generic_and_one_black() -> void:
	# The printed (and Scryfall snapshot) cost is {1}{B}; the card was
	# built with {B}{B}, which is uncastable off a Swamp + any other land.
	var raiders := give_hand(0, "Erg Raiders")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, raiders))
	resolve_stack()
	assert_eq(raiders.zone, Mtg.Zone.BATTLEFIELD)


# ----------------------------------- artifact "put into a graveyard" triggers --

func test_tablet_of_epityr_ignores_a_bounced_artifact() -> void:
	# "Whenever an artifact you control is put into a GRAVEYARD from the
	# battlefield" — the trigger listened to LEAVES_BATTLEFIELD without
	# checking where the artifact went, so Boomerang paid out too.
	put_battlefield(0, "Tablet of Epityr")
	var ring := put_battlefield(0, "Sol Ring")
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	advance_to_step(Mtg.Step.MAIN1)
	var boom := give_hand(0, "Boomerang")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, boom, [TargetRef.card(ring)]))
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].life, 20, "bouncing is not dying — no life gained")
	# Destroying the same artifact DOES pay out.
	var ring2 := put_battlefield(0, "Sol Ring")
	g.destroy(ring2, false)
	resolve_stack()
	assert_eq(g.players[0].life, 21, "a graveyard trip gains the life")


func test_urza_s_miter_ignores_a_bounced_artifact() -> void:
	put_battlefield(0, "Urza's Miter")
	var ring := put_battlefield(0, "Sol Ring")
	for _i in 4:
		put_battlefield(0, "Island")
	advance_to_step(Mtg.Step.MAIN1)
	var hand_before := g.players[0].hand.size()
	var boom := give_hand(0, "Boomerang")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, boom, [TargetRef.card(ring)]))
	resolve_stack()
	# The Sol Ring is back in hand; nothing was drawn on top of that.
	assert_eq(g.players[0].hand.size(), hand_before + 1,
		"only the bounced Sol Ring — no card drawn")


# --------------------------------------------------------------- Coal Golem --

func test_coal_golem_can_be_cashed_in_the_turn_it_arrives() -> void:
	# Oracle: "{3}, Sacrifice this creature: Add {R}{R}{R}." — no {T},
	# so CR 302.6's summoning sickness gate does not apply.
	var golem := put_battlefield(0, "Coal Golem", true)   # sick = just cast
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.tap_for_mana(0, golem))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.R), 3)
	assert_eq(golem.zone, Mtg.Zone.GRAVEYARD, "sacrificed as part of the cost")


# --------------------------------------------------------------- Orc General --

func test_orc_general_pumps_every_other_orc() -> void:
	# "Other Orc creatures get +1/+1" — no "you control", and "other"
	# means other than this permanent, not other than cards with this name.
	var general := put_battlefield(0, "Orc General")
	# The Goblin enters first so the default agent feeds it to the cost.
	var fodder := put_battlefield(0, "Goblin Balloon Brigade")
	var mine := put_battlefield(0, "Orcish Artillery")
	var theirs := put_battlefield(1, "Orcish Artillery")
	advance_to_step(Mtg.Step.MAIN1)
	var my_power := mine.cur_power
	var their_power := theirs.cur_power
	assert_ok(g.activate_ability(0, general, 0))
	resolve_stack()
	assert_eq(fodder.zone, Mtg.Zone.GRAVEYARD, "the Goblin paid the cost")
	assert_eq(mine.cur_power, my_power + 1, "your other Orc")
	assert_eq(theirs.cur_power, their_power + 1, "and the opponent's too")
	assert_eq(general.cur_power, 2, "but never the General itself")


# ------------------------------------------- sacrificed-creature payouts --

func test_diamond_valley_pays_the_live_toughness() -> void:
	# "You gain life equal to the sacrificed creature's toughness" — the
	# LIVE toughness as the creature was sacrificed (CR 608.2h), not the
	# printed one. The payload used to scan the graveyard for printed stats.
	put_battlefield(0, "Diamond Valley")
	var bear := put_battlefield(0, "Grizzly Bears")
	var strength := give_hand(0, "Holy Strength")   # +1/+2
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, strength, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_toughness, 4)
	var valley := g.find_on_battlefield(0, "Diamond Valley")
	assert_ok(g.activate_ability(0, valley, 0))
	resolve_stack()
	assert_eq(g.players[0].life, 24, "4, not the printed 2")


func test_creature_bond_deals_the_live_toughness() -> void:
	# "…deals damage equal to that creature's toughness" — last known
	# information again: the bond read the printed toughness.
	var bear := put_battlefield(0, "Grizzly Bears")
	var bond := give_hand(0, "Creature Bond")
	var strength := give_hand(0, "Holy Strength")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, bond, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bond.zone, Mtg.Zone.BATTLEFIELD)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, strength, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_toughness, 4, "2 + Holy Strength's +1/+2")
	g.destroy(bear, false)
	resolve_stack()
	assert_eq(g.players[0].life, 16, "20 - 4 (the toughness it died with)")


# ------------------------------------------- counter removal AS A COST --

func test_triskelion_counters_are_a_cost_not_an_effect() -> void:
	# "Remove a +1/+1 counter from this creature:" is a COST (CR 601.2h),
	# paid on activation. Removing it inside the resolving effect instead
	# let a player stack five activations off three counters and ping for
	# five: the activation check kept seeing the untouched counters.
	var tris := put_battlefield(0, "Triskelion")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(tris.cur_power, 4, "1/1 plus three +1/+1 counters")
	var foe := TargetRef.player(1)
	assert_ok(g.activate_ability(0, tris, 0, [foe]))
	assert_ok(g.activate_ability(0, tris, 0, [foe]))
	assert_ok(g.activate_ability(0, tris, 0, [foe]))
	assert_refused(g.activate_ability(0, tris, 0, [foe]), "counter")
	resolve_stack()
	assert_eq(g.players[1].life, 17, "three pings, not five")
	assert_eq(tris.cur_power, 1, "and all three counters are gone")


func test_scavenging_ghoul_spends_a_corpse_per_regeneration() -> void:
	var ghoul := put_battlefield(0, "Scavenging Ghoul")
	g.add_counters(ghoul, "corpse", 1)
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, ghoul, 0))
	assert_refused(g.activate_ability(0, ghoul, 0), "counter")
	resolve_stack()
	assert_eq(ghoul.regeneration_shields, 1, "one counter buys one shield")
	assert_eq(int(ghoul.counters.get("corpse", 0)), 0)


# ------------------------------------------------------------------ Berserk --

func test_berserk_kills_a_creature_that_attacks_after_it_resolves() -> void:
	# "At the beginning of the next end step, destroy that creature if it
	# attacked this turn" — the condition belongs to the END STEP. Checking
	# it at resolution meant a precombat-main Berserk never killed anything.
	var bear := put_battlefield(0, "Grizzly Bears")
	var berserk := give_hand(0, "Berserk")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, berserk, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 4, "+X/+0 where X is its power")
	run_combat([bear.id])
	assert_eq(g.players[1].life, 16)
	advance_to_step(Mtg.Step.END)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "it attacked, so it dies")


func test_berserk_spares_a_creature_that_never_attacked() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var berserk := give_hand(0, "Berserk")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, berserk, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_step(Mtg.Step.END)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "it stayed home — it lives")


# ------------------------------------------- "unless you sacrifice ..." --

func test_elder_spawn_lets_its_controller_decline_the_island() -> void:
	# "…unless you sacrifice an Island" is an OPTIONAL cost the controller
	# chooses to pay. The trigger force-fed the first Island it found, so
	# a player could never choose to let the Spawn go instead.
	g.set_agent(0, RefusingAgent.new())
	var spawn := put_battlefield(0, "Elder Spawn")
	var island := put_battlefield(0, "Island")
	advance_to_next_turn()   # player 1's turn
	advance_to_next_turn()   # back to player 0: their upkeep fires
	assert_eq(island.zone, Mtg.Zone.BATTLEFIELD, "the Island was not taken")
	assert_eq(spawn.zone, Mtg.Zone.GRAVEYARD, "the Spawn paid instead")
	assert_eq(g.players[0].life, 14, "and it dealt 6 to its controller")


func test_elder_spawn_eats_an_island_when_its_controller_agrees() -> void:
	var spawn := put_battlefield(0, "Elder Spawn")
	var island := put_battlefield(0, "Island")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(island.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(spawn.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].life, 20)


func test_mold_demon_lets_its_controller_decline_the_swamps() -> void:
	g.set_agent(0, RefusingAgent.new())
	var a := put_battlefield(0, "Swamp")
	var b := put_battlefield(0, "Swamp")
	var demon := give_hand(0, "Mold Demon")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.cast_spell(0, demon))
	resolve_stack()
	assert_eq(demon.zone, Mtg.Zone.GRAVEYARD, "the Demon went instead")
	assert_eq(a.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(b.zone, Mtg.Zone.BATTLEFIELD)


# ---------------------------------------------------------------- Jihad --

func test_jihad_sacrifices_itself_when_the_colour_leaves() -> void:
	# "When the chosen player controls no nontoken permanents of the chosen
	# color, sacrifice this enchantment." — the clause was missing entirely,
	# so a spent Jihad lingered and re-armed itself later.
	var theirs := put_battlefield(1, "Grizzly Bears")   # green
	var mine := put_battlefield(0, "Savannah Lions")    # white
	var jihad := give_hand(0, "Jihad")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 3)
	assert_ok(g.cast_spell(0, jihad))
	resolve_stack()
	assert_eq(jihad.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(mine.cur_power, 4, "2/1 Lions with Jihad's +2/+1")
	var terror := give_hand(0, "Terror")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, terror, [TargetRef.card(theirs)]))
	resolve_stack()
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(jihad.zone, Mtg.Zone.GRAVEYARD,
		"no green left on their board — Jihad is sacrificed")
	assert_eq(mine.cur_power, 2, "and the anthem is gone with it")


# -------------------------------------------------------- Instill Energy --

func test_instill_energy_does_not_hand_out_real_haste() -> void:
	# "Enchanted creature can attack as though it had haste" — attacking
	# only. Granting the HASTE keyword also unlocked {T} abilities the turn
	# a creature arrived, which the printed card does not do.
	var druid := put_battlefield(0, "Llanowar Elves", true)   # sick, {T}: add {G}
	var energy := give_hand(0, "Instill Energy")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, energy, [TargetRef.card(druid)]))
	resolve_stack()
	assert_false(druid.has_keyword(Mtg.Keyword.HASTE), "no real haste")
	assert_refused(g.tap_for_mana(0, druid), "summoning sickness")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [druid.id]))   # but it may still attack
	assert_true(g.combat.attackers.has(druid.id))


# ----------------------------------------------- "Cast this spell only ..." --

func test_reset_only_casts_on_an_opponents_turn_after_upkeep() -> void:
	# "Cast this spell only during an opponent's turn after their upkeep
	# step." Ignoring the rider turned Reset into a RITUAL: tap N lands for
	# mana in your own main phase, spend {U}{U}, untap all N.
	var reset := give_hand(0, "Reset")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_refused(g.cast_spell(0, reset), "opponent's turn")
	advance_to_step(Mtg.Step.UPKEEP)          # the opponent's upkeep
	assert_eq(g.active_player, 1)
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_refused(g.cast_spell(0, reset), "upkeep")
	advance_to_step(Mtg.Step.MAIN1)           # their main phase: legal
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, reset))
	resolve_stack()
	assert_eq(reset.zone, Mtg.Zone.GRAVEYARD)


# ----------------------------------------------------------- Titania's Song --

func test_titanias_song_silences_artifact_triggers() -> void:
	# "Each noncreature artifact LOSES ALL ABILITIES" — only the mana and
	# activated lists were cleared, so an animated Ankh of Mishra kept
	# stinging, an animated Howling Mine kept drawing, and so on.
	put_battlefield(1, "Ankh of Mishra")
	put_battlefield(0, "Titania's Song")
	var ankh := g.find_on_battlefield(1, "Ankh of Mishra")
	assert_true(ankh.is_creature(), "the Song animated it")
	var forest := give_hand(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.play_land(0, forest))
	resolve_stack()
	assert_eq(g.players[0].life, 20, "a silenced Ankh deals nothing")


func test_titanias_song_silences_artifact_statics() -> void:
	# Meekstone's "creatures with power 3 or greater don't untap" is a
	# STATIC ability, and it too must go.
	put_battlefield(1, "Meekstone")
	var giant := put_battlefield(0, "Hill Giant")   # 3/3
	g.tap_permanent(giant)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(giant.tapped, "Meekstone holds the 3-power creature down")
	put_battlefield(0, "Titania's Song")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_false(giant.tapped, "a silenced Meekstone locks nothing")
