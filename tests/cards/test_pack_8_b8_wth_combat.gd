extends GameTest
## Pack 8 (the Mirage block), batch B8: the Weatherlight combat cards of
## cards/sets/wth/_combat.gd — block and attack restrictions, combat
## triggers, end-of-combat delayed triggers (CR 603.7) and the E9 helpers
## (two-slot trigger targets, "becomes blocked").

const CLAIMED := ["Foriysian Brigade", "Cloud Djinn", "Fog Elemental", "Manta Ray", "Ophidian",
	"Tolarian Entrancer", "Bone Dancer", "Shadow Rider", "Cinder Wall", "Dwarven Berserker",
	"Goblin Grenadiers", "Goblin Vandal", "Heat Stroke", "Lava Storm", "Sawtooth Ogre",
	"Choking Vines", "Familiar Ground", "Jangling Automaton"]


class Scripted extends DecisionAgent:
	var answers: Array = []   # bool
	func answer_yes_no(_g: MtgGame, _p: int, _prompt: String, hint: bool) -> bool:
		return bool(answers.pop_front()) if not answers.is_empty() else hint


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


## P0 attacks with [param attackers]; P1 declares [param blocks]. Leaves the
## game in the declare-blockers step, the triggers resolved, P0 holding
## priority.
func _combat(attackers: Array, blocks: Dictionary = {}) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	var ids: Array = []
	for a in attackers: ids.append(a.id)
	assert_ok(g.declare_attackers(0, ids))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, blocks))
	resolve_stack()

func _token_named(pid: int, card_name: String) -> CardInstance:
	for i in g.players[pid].battlefield:
		if i.data.card_name == card_name: return i
	return null


func test_claimed_cards_are_no_longer_pending() -> void:
	for name in CLAIMED:
		var c := CardRegistry.get_card(name)
		assert_not_null(c, name)
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending", name)


# --- Foriysian Brigade -------------------------------------------------------------

func test_brigade_blocks_two_attackers() -> void:
	var a := put_battlefield(0, "Llanowar Elves")
	var b := put_battlefield(0, "Llanowar Elves")
	var brigade := put_battlefield(1, "Foriysian Brigade")
	var plain := put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [a.id, b.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {plain.id: [a.id, b.id]}))
	assert_ok(g.declare_blockers(1, {brigade.id: [a.id, b.id]}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20)
	assert_eq(brigade.damage, 2)
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)


# --- Cloud Djinn ----------------------------------------------------------------------

func test_cloud_djinn_blocks_only_flyers() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var angel := put_battlefield(0, "Serra Angel")
	var djinn := put_battlefield(1, "Cloud Djinn")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id, angel.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {djinn.id: bear.id}))
	assert_ok(g.declare_blockers(1, {djinn.id: angel.id}))


# --- Fog Elemental ------------------------------------------------------------------------

func test_fog_elemental_is_sacrificed_after_attacking() -> void:
	var fog := put_battlefield(0, "Fog Elemental")
	_combat([fog])
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(g.players[1].life, 16, "it dealt its damage first")
	assert_eq(fog.zone, Mtg.Zone.GRAVEYARD)

func test_fog_elemental_is_sacrificed_after_blocking() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var fog := put_battlefield(1, "Fog Elemental")
	_combat([bear], {fog.id: bear.id})
	assert_eq(fog.zone, Mtg.Zone.BATTLEFIELD)
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(fog.zone, Mtg.Zone.GRAVEYARD)

func test_an_idle_fog_elemental_stays() -> void:
	var fog := put_battlefield(0, "Fog Elemental")
	var bear := put_battlefield(0, "Grizzly Bears")
	_combat([bear])
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(fog.zone, Mtg.Zone.BATTLEFIELD)


# --- Manta Ray -----------------------------------------------------------------------------

func test_manta_ray_attacks_only_into_an_island_and_only_blue_creatures_block_it() -> void:
	put_battlefield(0, "Island")
	var ray := put_battlefield(0, "Manta Ray")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [ray.id]), "")
	put_battlefield(1, "Island")
	var bear := put_battlefield(1, "Grizzly Bears")
	var merfolk := put_battlefield(1, "Merfolk of the Pearl Trident")
	assert_ok(g.declare_attackers(0, [ray.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {bear.id: ray.id}))
	assert_ok(g.declare_blockers(1, {merfolk.id: ray.id}))

func test_manta_ray_is_sacrificed_without_an_island() -> void:
	var island := put_battlefield(0, "Island")
	var ray := put_battlefield(0, "Manta Ray")
	assert_eq(ray.zone, Mtg.Zone.BATTLEFIELD)
	advance_to_next_turn()
	var rain := give_hand(1, "Stone Rain")
	add_mana(1, Mtg.ManaColor.R, 3)
	assert_ok(g.cast_spell(1, rain, [TargetRef.card(island)]))
	resolve_stack()
	assert_eq(island.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(ray.zone, Mtg.Zone.GRAVEYARD)


# --- Ophidian ----------------------------------------------------------------------------------

func test_ophidian_draws_instead_of_dealing_damage() -> void:
	var snake := put_battlefield(0, "Ophidian")
	var hand := g.players[0].hand.size()
	_combat([snake])
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].hand.size(), hand + 1)
	assert_eq(g.players[1].life, 20, "it assigns no combat damage")

func test_ophidian_declined_deals_its_damage() -> void:
	var seat := Scripted.new()
	seat.answers = [false]
	g.agents[0] = seat
	var snake := put_battlefield(0, "Ophidian")
	var hand := g.players[0].hand.size()
	_combat([snake])
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].hand.size(), hand)
	assert_eq(g.players[1].life, 19)


# --- Tolarian Entrancer ----------------------------------------------------------------------

func test_entrancer_steals_its_blocker_at_end_of_combat() -> void:
	var entrancer := put_battlefield(0, "Tolarian Entrancer")
	var wall := put_battlefield(1, "Wall of Stone")
	_combat([entrancer], {wall.id: entrancer.id})
	assert_eq(wall.controller_id, 1, "not until end of combat")
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(wall.controller_id, 0)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(wall.controller_id, 0, "for good")

func test_entrancer_takes_nothing_when_its_blocker_died() -> void:
	var entrancer := put_battlefield(0, "Tolarian Entrancer")
	var elves := put_battlefield(1, "Llanowar Elves")
	_combat([entrancer], {elves.id: entrancer.id})
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(elves.owner_id, 1)


# --- Bone Dancer ---------------------------------------------------------------------------------

func test_bone_dancer_takes_the_top_creature_card_instead_of_damage() -> void:
	var dancer := put_battlefield(0, "Bone Dancer")
	var lower := _make_instance(1, "Grizzly Bears")
	var upper := _make_instance(1, "Hill Giant")
	var spell := _make_instance(1, "Lightning Bolt")
	for c in [lower, upper, spell]:
		c.zone = Mtg.Zone.GRAVEYARD
		g.players[1].graveyard.append(c)
	_combat([dancer])
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(upper.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(upper.controller_id, 0)
	assert_eq(lower.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 20, "it assigns no combat damage")

func test_bone_dancer_with_no_creature_card_deals_damage() -> void:
	var dancer := put_battlefield(0, "Bone Dancer")
	_combat([dancer])
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 18)


# --- Shadow Rider ---------------------------------------------------------------------------------

func test_shadow_rider_has_flanking() -> void:
	var rider := put_battlefield(0, "Shadow Rider")
	assert_true(rider.has_keyword(Mtg.Keyword.FLANKING))
	var wall := put_battlefield(1, "Wall of Stone")
	_combat([rider], {wall.id: rider.id})
	assert_eq(wall.cur_power, -1)
	assert_eq(wall.cur_toughness, 7)


# --- Cinder Wall ------------------------------------------------------------------------------------

func test_cinder_wall_is_destroyed_after_blocking() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Cinder Wall")
	assert_true(wall.has_keyword(Mtg.Keyword.DEFENDER))
	_combat([bear], {wall.id: bear.id})
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD)
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


# --- Dwarven Berserker -------------------------------------------------------------------------------

func test_berserker_gets_three_and_trample_when_blocked() -> void:
	var dwarf := put_battlefield(0, "Dwarven Berserker")
	var elves := put_battlefield(1, "Llanowar Elves")
	_combat([dwarf], {elves.id: dwarf.id})
	assert_eq(dwarf.cur_power, 4)
	assert_true(dwarf.has_keyword(Mtg.Keyword.TRAMPLE))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 17, "3 tramples over the 1-toughness Elves")

func test_berserker_unblocked_stays_small() -> void:
	var dwarf := put_battlefield(0, "Dwarven Berserker")
	_combat([dwarf])
	assert_eq(dwarf.cur_power, 1)


# --- Goblin Grenadiers -------------------------------------------------------------------------------

func test_grenadiers_sacrifice_to_destroy_a_creature_and_a_land() -> void:
	var gren := put_battlefield(0, "Goblin Grenadiers")
	var bear := put_battlefield(1, "Grizzly Bears")
	var land := put_battlefield(1, "Forest")
	_combat([gren])
	assert_eq(gren.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(land.zone, Mtg.Zone.GRAVEYARD)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20)

func test_grenadiers_declined_attack_normally() -> void:
	var seat := Scripted.new()
	seat.answers = [false]
	g.agents[0] = seat
	var gren := put_battlefield(0, "Goblin Grenadiers")
	var bear := put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Forest")
	_combat([gren])
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(gren.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[1].life, 18)


# --- Goblin Vandal --------------------------------------------------------------------------------------

func test_vandal_pays_red_to_destroy_an_artifact_and_deals_no_damage() -> void:
	var vandal := put_battlefield(0, "Goblin Vandal")
	put_battlefield(0, "Mountain")
	var orb := put_battlefield(1, "Winter Orb")
	_combat([vandal])
	assert_eq(orb.zone, Mtg.Zone.GRAVEYARD)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20)

func test_vandal_without_red_mana_deals_its_damage() -> void:
	var vandal := put_battlefield(0, "Goblin Vandal")
	var orb := put_battlefield(1, "Winter Orb")
	put_battlefield(0, "Sol Ring")   # an artifact of its own controller is no target
	_combat([vandal])
	assert_eq(orb.zone, Mtg.Zone.BATTLEFIELD)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 19)


# --- Heat Stroke ------------------------------------------------------------------------------------------

func test_heat_stroke_destroys_blockers_and_blocked_creatures() -> void:
	put_battlefield(1, "Heat Stroke")
	var wurm := put_battlefield(0, "Craw Wurm")
	var bear := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Stone")
	var idle := put_battlefield(1, "Hill Giant")
	_combat([wurm, bear], {wall.id: wurm.id})
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "unblocked")
	assert_eq(idle.zone, Mtg.Zone.BATTLEFIELD)


# --- Lava Storm ---------------------------------------------------------------------------------------------

func test_lava_storm_hits_each_attacker_or_each_blocker() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var elves := put_battlefield(1, "Llanowar Elves")
	var wall := put_battlefield(1, "Wall of Stone")
	_combat([bear, giant], {elves.id: giant.id, wall.id: bear.id})
	assert_ok(g.pass_priority(0))
	var storm := give_hand(1, "Lava Storm")
	add_mana(1, Mtg.ManaColor.R, 5)
	assert_ok(g.cast_spell(1, storm, [], 0, 0))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.damage, 2)
	assert_eq(elves.zone, Mtg.Zone.BATTLEFIELD, "blockers untouched in the attackers' mode")

func test_lava_storm_blockers_mode_and_ai_pick() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var elves := put_battlefield(1, "Llanowar Elves")
	_combat([bear], {elves.id: bear.id})
	var data := CardRegistry.get_card("Lava Storm")
	assert_eq(int(data.ai_mode_picker.call(g, 1)), 0, "P1 kills the attacking Bears, not its own Elves")
	assert_eq(int(data.ai_mode_picker.call(g, 0)), 1, "P0 kills the blocking Elves")
	var storm := give_hand(0, "Lava Storm")
	add_mana(0, Mtg.ManaColor.R, 5)
	assert_ok(g.cast_spell(0, storm, [], 0, 1))
	resolve_stack()
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


# --- Sawtooth Ogre ------------------------------------------------------------------------------------------

func test_sawtooth_ogre_bites_its_blocker_at_end_of_combat() -> void:
	var ogre := put_battlefield(0, "Sawtooth Ogre")
	var wall := put_battlefield(1, "Wall of Stone")
	_combat([ogre], {wall.id: ogre.id})
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(wall.damage, 4, "3 in combat, 1 more at end of combat")

func test_sawtooth_ogre_bites_the_creature_it_blocks() -> void:
	advance_to_next_turn()
	var ogre := put_battlefield(0, "Sawtooth Ogre")
	var wurm := put_battlefield(1, "Craw Wurm")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [wurm.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {ogre.id: wurm.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(ogre.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD, "3 in combat + 1 from the dead Ogre (last known information)")


# --- Choking Vines ---------------------------------------------------------------------------------------

func test_choking_vines_blocks_x_attackers_and_pings_them() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	_combat([bear, giant])
	assert_ok(g.pass_priority(0))
	var vines := give_hand(1, "Choking Vines")
	add_mana(1, Mtg.ManaColor.G, 3)
	assert_ok(g.cast_spell(1, vines, [TargetRef.card(bear), TargetRef.card(giant)], 2))
	resolve_stack()
	assert_eq(bear.damage, 1)
	assert_eq(giant.damage, 1)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20, "blocked, with nothing blocking them: no damage")

func test_choking_vines_only_during_declare_blockers() -> void:
	advance_to_next_turn()
	var vines := give_hand(1, "Choking Vines")
	add_mana(1, Mtg.ManaColor.G, 1)
	assert_refused(g.cast_spell(1, vines, [], 0))
	assert_eq(vines.zone, Mtg.Zone.HAND)


# --- Familiar Ground ---------------------------------------------------------------------------------------

func test_familiar_ground_one_blocker_per_attacker() -> void:
	put_battlefield(0, "Familiar Ground")
	var wurm := put_battlefield(0, "Craw Wurm")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {a.id: wurm.id, b.id: wurm.id}))
	assert_ok(g.declare_blockers(1, {a.id: wurm.id}))


# --- Jangling Automaton -----------------------------------------------------------------------------------

func test_jangling_automaton_untaps_the_defenders_creatures() -> void:
	var automaton := put_battlefield(0, "Jangling Automaton")
	var bear := put_battlefield(1, "Grizzly Bears")
	var mine := put_battlefield(0, "Hill Giant")
	bear.tapped = true
	mine.tapped = true
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [automaton.id]))
	resolve_stack()
	assert_false(bear.tapped)
	assert_true(mine.tapped, "only the defending player's creatures")
