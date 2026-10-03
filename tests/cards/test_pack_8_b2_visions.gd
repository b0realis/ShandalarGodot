extends GameTest
## Pack 8, batch B2 — Visions' combat cards without flanking
## (cards/sets/vis/_combat.gd): block restrictions and requirements, the
## Heat Wave life tax and the Elephant Grass attack tax (Pack 8 E9),
## "attacks and isn't blocked" riders, divided damage among combatants and
## the per-creature "whenever a creature attacks" triggers.

class Seat extends DecisionAgent:
	var yes := -1
	var option := -1
	var prefer: Array = []
	var asked: Array = []

	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String, hint: bool) -> bool:
		asked.append(prompt)
		return hint if yes < 0 else yes == 1

	func answer_option(_game: MtgGame, _pid: int, prompt: String,
			_options: Array[String], hint: int) -> int:
		asked.append(prompt)
		return hint if option < 0 else option

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		asked.append(prompt)
		for name in prefer:
			for c in candidates:
				if c.data.card_name == name: return c
		return null if candidates.is_empty() else candidates[0]


var me: Seat
var foe: Seat


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	super()
	me = Seat.new()
	foe = Seat.new()
	g.set_agent(0, me)
	g.set_agent(1, foe)
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


func _attack(ids: Array, bands: Array = []) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, ids, bands))


func _attack_and_block(ids: Array, blocks: Dictionary, bands: Array = []) -> void:
	_attack(ids, bands)
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, blocks))


func _on_library_top(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.LIBRARY
	g.players[pid].library.append(inst)
	return inst


# =================================================================== blue

func test_cloud_elemental_blocks_only_flyers() -> void:
	var cloud := put_battlefield(1, "Cloud Elemental")
	var bear := put_battlefield(0, "Grizzly Bears")
	var pegasus := put_battlefield(0, "Mesa Pegasus")
	_attack([bear.id, pegasus.id])
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {cloud.id: bear.id}))
	assert_ok(g.declare_blockers(1, {cloud.id: pegasus.id}))


# ================================================================== black

func test_suq_ata_assassin_poisons_when_unblocked() -> void:
	var assassin := put_battlefield(0, "Suq'Ata Assassin")
	_attack_and_block([assassin.id], {})
	resolve_stack()
	assert_eq(g.players[1].poison, 1)


func test_suq_ata_assassin_has_fear() -> void:
	var assassin := put_battlefield(0, "Suq'Ata Assassin")
	var bear := put_battlefield(1, "Grizzly Bears")
	var zombies := put_battlefield(1, "Scathe Zombies")
	_attack([assassin.id])
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {bear.id: assassin.id}))
	assert_ok(g.declare_blockers(1, {zombies.id: assassin.id}))
	resolve_stack()
	assert_eq(g.players[1].poison, 0, "blocked: no poison")


# ==================================================================== red

func test_dwarven_vigilantes_hit_a_creature_instead_of_the_player() -> void:
	var vigilantes := put_battlefield(0, "Dwarven Vigilantes")
	var elves := put_battlefield(1, "Llanowar Elves")
	_attack_and_block([vigilantes.id], {})
	assert_eq(g.stack.size(), 1)
	assert_eq(g.stack[0].targets[0].instance_id, elves.id, "the enemy creature first")
	resolve_stack()
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20, "it assigned no combat damage")


func test_dwarven_vigilantes_may_decline() -> void:
	var vigilantes := put_battlefield(0, "Dwarven Vigilantes")
	var elves := put_battlefield(1, "Llanowar Elves")
	me.yes = 0
	_attack_and_block([vigilantes.id], {})
	resolve_stack()
	assert_eq(elves.zone, Mtg.Zone.BATTLEFIELD)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 18)


func test_goblin_swine_rider_burns_every_combatant() -> void:
	var rider := put_battlefield(0, "Goblin Swine-Rider")
	var giant := put_battlefield(0, "Hill Giant")
	var stay := put_battlefield(0, "Llanowar Elves")
	var wall := put_battlefield(1, "Wall of Stone")
	var bear := put_battlefield(1, "Grizzly Bears")
	var idle := put_battlefield(1, "Llanowar Elves")
	_attack_and_block([rider.id, giant.id], {wall.id: rider.id, bear.id: giant.id})
	assert_eq(g.stack.size(), 1, "the Swine-Rider's trigger")
	resolve_stack()
	assert_eq(rider.zone, Mtg.Zone.GRAVEYARD, "an attacking creature: itself")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.damage, 2)
	assert_eq(wall.damage, 2)
	assert_eq(stay.zone, Mtg.Zone.BATTLEFIELD, "not in combat")
	assert_eq(idle.zone, Mtg.Zone.BATTLEFIELD, "not in combat")


func test_goblin_swine_rider_unblocked_does_nothing() -> void:
	var rider := put_battlefield(0, "Goblin Swine-Rider")
	_attack_and_block([rider.id], {})
	assert_eq(g.stack.size(), 0)


func test_heat_wave_bans_blue_blockers_and_taxes_the_rest() -> void:
	put_battlefield(0, "Heat Wave")
	var giant := put_battlefield(0, "Hill Giant")
	var merfolk := put_battlefield(1, "Merfolk of the Pearl Trident")
	var bear := put_battlefield(1, "Grizzly Bears")
	var elves := put_battlefield(1, "Llanowar Elves")
	_attack([giant.id])
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {merfolk.id: giant.id}))
	assert_ok(g.declare_blockers(1, {bear.id: giant.id, elves.id: giant.id}))
	assert_eq(g.players[1].life, 18, "1 life for each blocking creature")


func test_heat_wave_protects_only_its_controller_s_creatures() -> void:
	put_battlefield(1, "Heat Wave")
	var giant := put_battlefield(0, "Hill Giant")
	var merfolk := put_battlefield(1, "Merfolk of the Pearl Trident")
	_attack([giant.id])
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {merfolk.id: giant.id}))
	assert_eq(g.players[1].life, 20)


func test_heat_wave_has_cumulative_upkeep_r() -> void:
	var data := CardRegistry.get_card("Heat Wave")
	assert_true(data.triggered_abilities.any(func(t: TriggeredAbility) -> bool:
		return t.text.begins_with("Cumulative upkeep {R}")))


func test_raging_gorilla_goes_all_in_when_it_blocks() -> void:
	var gorilla := put_battlefield(1, "Raging Gorilla")
	var bear := put_battlefield(0, "Grizzly Bears")
	_attack_and_block([bear.id], {gorilla.id: bear.id})
	resolve_stack()
	assert_eq([gorilla.cur_power, gorilla.cur_toughness], [4, 1])


func test_rock_slide_divides_x_among_grounded_combatants() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var pegasus := put_battlefield(0, "Mesa Pegasus")
	var home := put_battlefield(1, "Llanowar Elves")
	_attack([bear.id, giant.id, pegasus.id])
	resolve_stack()
	assert_ok(g.pass_priority(0))
	var slide := give_hand(1, "Rock Slide")
	add_mana(1, Mtg.ManaColor.R)
	add_mana(1, Mtg.ManaColor.C, 5)
	assert_refused(g.cast_spell(1, slide, [TargetRef.card(pegasus, 3)], 3), "")
	assert_refused(g.cast_spell(1, slide, [TargetRef.card(home, 3)], 3), "")
	assert_ok(g.cast_spell(1, slide, [TargetRef.card(bear, 2), TargetRef.card(giant, 3)], 5))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)


func test_song_of_blood_pumps_each_attacker_per_milled_creature() -> void:
	_on_library_top(0, "Forest")
	_on_library_top(0, "Grizzly Bears")
	_on_library_top(0, "Lightning Bolt")
	_on_library_top(0, "Hill Giant")
	var bear := put_battlefield(0, "Grizzly Bears")
	var elves := put_battlefield(0, "Llanowar Elves")
	var song := give_hand(0, "Song of Blood")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, song, []))
	resolve_stack()
	assert_eq(g.players[0].graveyard.size(), 5, "four milled and the Song")
	_attack([bear.id, elves.id])
	assert_eq(g.stack.size(), 2, "one trigger per attacking creature")
	resolve_stack()
	assert_eq([bear.cur_power, bear.cur_toughness], [4, 2], "two creature cards: +2/+0")
	assert_eq([elves.cur_power, elves.cur_toughness], [3, 1])


func test_song_of_blood_lasts_only_this_turn() -> void:
	_on_library_top(0, "Grizzly Bears")
	var song := give_hand(0, "Song of Blood")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, song, []))
	resolve_stack()
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [bear.id]))
	assert_eq(g.stack.size(), 0, "the trigger ended with the turn it was cast in")


func test_song_of_blood_with_no_creature_milled_pumps_nothing() -> void:
	for n in 4: _on_library_top(0, "Forest")
	var bear := put_battlefield(0, "Grizzly Bears")
	var song := give_hand(0, "Song of Blood")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, song, []))
	resolve_stack()
	_attack([bear.id])
	assert_eq(g.stack.size(), 1, "the trigger still happens, for +0/+0")
	resolve_stack()
	assert_eq(bear.cur_power, 2)


func test_suq_ata_lancer_is_a_hasty_flanker() -> void:
	var lancer := put_battlefield(0, "Suq'Ata Lancer", true)
	assert_eq(Flanking.instances(lancer), 1)
	assert_true(lancer.has_keyword(Mtg.Keyword.HASTE))


func test_talruum_champion_strips_first_strike_from_its_attacker() -> void:
	var champion := put_battlefield(1, "Talruum Champion")
	var knight := put_battlefield(0, "White Knight")   # 2/2 first strike
	_attack_and_block([knight.id], {champion.id: knight.id})
	resolve_stack()
	assert_false(knight.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(knight.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(champion.damage, 0, "the Champion struck first")


func test_talruum_champion_strips_first_strike_from_its_blocker() -> void:
	var champion := put_battlefield(0, "Talruum Champion")
	var knight := put_battlefield(1, "White Knight")
	_attack_and_block([champion.id], {knight.id: champion.id})
	assert_eq(g.stack.size(), 1, "blocks or becomes blocked: either side")
	resolve_stack()
	assert_false(knight.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(knight.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(champion.damage, 0)


func test_talruum_piper_draws_every_able_flyer() -> void:
	var piper := put_battlefield(0, "Talruum Piper")
	var pegasus := put_battlefield(1, "Mesa Pegasus")
	put_battlefield(1, "Grizzly Bears")
	_attack([piper.id])
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {}), "")
	assert_ok(g.declare_blockers(1, {pegasus.id: piper.id}))


# ================================================================== green

func test_elephant_grass_stops_black_attackers_and_taxes_the_rest() -> void:
	put_battlefield(1, "Elephant Grass")
	var zombies := put_battlefield(0, "Scathe Zombies")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [zombies.id]))
	assert_refused(g.declare_attackers(0, [bear.id]), "")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.declare_attackers(0, [bear.id]))
	assert_eq(g.players[0].mana_pool.total(), 0, "{2} for the one attacker")


func test_elephant_grass_does_not_tax_its_controller() -> void:
	put_battlefield(0, "Elephant Grass")
	var zombies := put_battlefield(0, "Scathe Zombies")
	_attack([zombies.id])


func test_wind_shear_grounds_attacking_flyers() -> void:
	var angel := put_battlefield(0, "Serra Angel")
	var bear := put_battlefield(0, "Grizzly Bears")
	var home := put_battlefield(0, "Mesa Pegasus")
	_attack([angel.id, bear.id])
	resolve_stack()
	assert_ok(g.pass_priority(0))
	var shear := give_hand(1, "Wind Shear")
	add_mana(1, Mtg.ManaColor.G)
	add_mana(1, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(1, shear, []))
	resolve_stack()
	assert_eq([angel.cur_power, angel.cur_toughness], [2, 2])
	assert_false(angel.has_keyword(Mtg.Keyword.FLYING))
	assert_eq([bear.cur_power, bear.cur_toughness], [2, 2], "no flying, untouched")
	assert_true(home.has_keyword(Mtg.Keyword.FLYING), "not attacking, untouched")


# =================================================================== gold

func test_pygmy_hippo_drains_the_defender_s_lands_into_its_next_main_phase() -> void:
	var hippo := put_battlefield(0, "Pygmy Hippo")
	var forest_a := put_battlefield(1, "Forest")
	var forest_b := put_battlefield(1, "Forest")
	var spent := put_battlefield(1, "Island")
	g.tap_permanent(spent)
	me.yes = 1
	_attack_and_block([hippo.id], {})
	resolve_stack()
	assert_true(forest_a.tapped and forest_b.tapped, "a mana ability of each land")
	assert_eq(g.players[1].mana_pool.total(), 0, "and the mana is lost")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20, "it assigned no combat damage")
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(g.players[0].mana_pool.total(), 2, "{C} for each mana lost")


func test_pygmy_hippo_declined_deals_its_damage() -> void:
	var hippo := put_battlefield(0, "Pygmy Hippo")
	var forest := put_battlefield(1, "Forest")
	me.yes = 0
	_attack_and_block([hippo.id], {})
	resolve_stack()
	assert_false(forest.tapped)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 18)
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_pygmy_hippo_the_defender_picks_which_mana_ability() -> void:
	var hippo := put_battlefield(0, "Pygmy Hippo")
	var tundra := put_battlefield(1, "Tundra")
	me.yes = 1
	_attack_and_block([hippo.id], {})
	resolve_stack()
	assert_true(tundra.tapped)
	assert_true(foe.asked.any(func(q: String) -> bool: return q.begins_with("Pygmy Hippo: activate which")),
		"a land with two mana abilities: the DEFENDING player chooses")
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(g.players[0].mana_pool.total(), 1)


func test_goblin_swine_rider_in_a_band_triggers_when_the_band_is_blocked() -> void:
	var hero := put_battlefield(0, "Benalish Hero")
	var rider := put_battlefield(0, "Goblin Swine-Rider")
	var wall := put_battlefield(1, "Wall of Stone")
	_attack_and_block([hero.id, rider.id], {wall.id: hero.id}, [[hero.id, rider.id]])
	assert_eq(g.stack.size(), 1, "the whole band became blocked (CR 702.22h)")
	resolve_stack()
	assert_eq(hero.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(wall.damage, 2)
