extends GameTest
## Wave-68 tests: Channel (a player-level mana source), Drain Power (mana
## transfer), Rakalite (a delayed end-step action), Scarecrow (a persistent
## predicate shield), Bronze Horse (damage from spells that TARGET it),
## Mana Drain (a delayed next-main-phase action), Equinox (a granted
## conditional counter) and Arena (a fight the defender picks a champion for).


## Picks a CARD by name, else the first candidate.
class PickByName extends DecisionAgent:
	var wanted := ""

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		for inst in candidates:
			if inst.data.card_name == wanted:
				return inst
		return null if candidates.is_empty() else candidates[0]


func test_registry_loaded_wave68() -> void:
	for name in ["Channel", "Drain Power", "Rakalite", "Scarecrow",
			"Bronze Horse", "Mana Drain", "Equinox", "Arena"]:
		assert_not_null(CardRegistry.get_card(name), name)


# --------------------------------------------------------------- Channel --

func test_channel_turns_life_into_mana() -> void:
	var channel := give_hand(0, "Channel")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, channel, []))
	resolve_stack()
	assert_ok(g.pay_life_for_mana(0, 7))
	assert_eq(g.players[0].life, 13)
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.C), 7)


func test_channel_is_refused_without_the_grant() -> void:
	assert_refused(g.pay_life_for_mana(0, 1), "no way to turn life into mana")


func test_channel_will_not_overdraw_your_life() -> void:
	var channel := give_hand(0, "Channel")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, channel, []))
	resolve_stack()
	assert_refused(g.pay_life_for_mana(0, 21), "not enough life")
	# Down to exactly 0 is legal (CR 118.4).
	assert_ok(g.pay_life_for_mana(0, 20))


func test_channel_expires_at_end_of_turn() -> void:
	var channel := give_hand(0, "Channel")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, channel, []))
	resolve_stack()
	advance_to_next_turn()
	assert_refused(g.pay_life_for_mana(0, 1), "no way to turn life into mana")


# ------------------------------------------------------------ Drain Power --

func test_drain_power_taps_their_lands_and_takes_the_mana() -> void:
	for _i in 3:
		put_battlefield(1, "Forest")
	var drain := give_hand(0, "Drain Power")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, drain, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.G), 3)
	assert_eq(g.players[1].mana_pool.total(), 0, "they lose all unspent mana")
	for inst in g.players[1].battlefield:
		assert_true(inst.tapped, "their lands stay tapped")


func test_drain_power_also_takes_mana_they_were_already_holding() -> void:
	put_battlefield(1, "Mountain")
	var drain := give_hand(0, "Drain Power")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(1, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, drain, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.B), 2)
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.R), 1)


# --------------------------------------------------------------- Rakalite --

func test_rakalite_prevents_one_damage_and_goes_home() -> void:
	var rock := put_battlefield(0, "Rakalite")
	var bear := put_battlefield(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, rock, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.prevention, 1)
	advance_to_step(Mtg.Step.END)
	assert_eq(rock.zone, Mtg.Zone.HAND, "returned at the next end step")


func test_rakalite_books_only_one_bounce_however_often_it_is_used() -> void:
	var rock := put_battlefield(0, "Rakalite")
	var bear := put_battlefield(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, rock, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_ok(g.activate_ability(0, rock, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.prevention, 2, "both points are on the pool")
	advance_to_step(Mtg.Step.END)
	assert_eq(rock.zone, Mtg.Zone.HAND)


# -------------------------------------------------------------- Scarecrow --

func test_scarecrow_stops_every_flier_all_turn() -> void:
	var crow := put_battlefield(0, "Scarecrow")
	var angel := put_battlefield(1, "Serra Angel")
	var second := put_battlefield(1, "Serra Angel")
	add_mana(0, Mtg.ManaColor.C, 6)
	assert_ok(g.activate_ability(0, crow, 0))
	resolve_stack()
	g.deal_damage(angel, TargetRef.player(0), 4)
	g.deal_damage(second, TargetRef.player(0), 4)
	assert_eq(g.players[0].life, 20, "a shield that is not consumed")


func test_scarecrow_ignores_the_ground() -> void:
	var crow := put_battlefield(0, "Scarecrow")
	var bear := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 6)
	assert_ok(g.activate_ability(0, crow, 0))
	resolve_stack()
	g.deal_damage(bear, TargetRef.player(0), 2)
	assert_eq(g.players[0].life, 18)


func test_scarecrows_shield_is_gone_next_turn() -> void:
	var crow := put_battlefield(0, "Scarecrow")
	var angel := put_battlefield(1, "Serra Angel")
	add_mana(0, Mtg.ManaColor.C, 6)
	assert_ok(g.activate_ability(0, crow, 0))
	resolve_stack()
	advance_to_next_turn()
	g.deal_damage(angel, TargetRef.player(0), 4)
	assert_eq(g.players[0].life, 16)


# ------------------------------------------------------------ Bronze Horse --

func test_bronze_horse_shrugs_off_a_targeted_spell() -> void:
	var horse := put_battlefield(0, "Bronze Horse")
	put_battlefield(0, "Grizzly Bears")   # "another creature"
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))   # p1 acts in p0's main phase
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(horse)]))
	resolve_stack()
	assert_eq(horse.damage, 0, "the spell targeted it")


func test_bronze_horse_is_hurt_when_it_stands_alone() -> void:
	var horse := put_battlefield(0, "Bronze Horse")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))   # p1 acts in p0's main phase
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(horse)]))
	resolve_stack()
	assert_eq(horse.damage, 3, "no other creature, no shield")


func test_bronze_horse_is_hurt_by_a_creature() -> void:
	var horse := put_battlefield(0, "Bronze Horse")
	put_battlefield(0, "Grizzly Bears")
	var sorcerer := put_battlefield(1, "Prodigal Sorcerer")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, sorcerer, 0, [TargetRef.card(horse)]))
	resolve_stack()
	assert_eq(horse.damage, 1, "an ability is not a spell")


# ------------------------------------------------------------- Mana Drain --

func test_mana_drain_counters_and_pays_out_next_main_phase() -> void:
	var bears := give_hand(1, "Grizzly Bears")   # {1}{G} = 2
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.G)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, bears, []))
	assert_ok(g.pass_priority(1))
	var drain := give_hand(0, "Mana Drain")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, drain, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "countered")
	assert_eq(g.players[0].mana_pool.total(), 0, "nothing yet")
	advance_to_next_turn()   # p0's main phase
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.C), 2)


# --------------------------------------------------------------- Equinox --

func test_equinox_counters_land_destruction() -> void:
	var land := put_battlefield(0, "Forest")
	var aura := give_hand(0, "Equinox")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(land)]))
	resolve_stack()
	# Stone Rain is a SORCERY, so the attack comes on p1's own turn.
	advance_to_next_turn()
	var stone := give_hand(1, "Stone Rain")
	add_mana(1, Mtg.ManaColor.R)
	add_mana(1, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(1, stone, [TargetRef.card(land)]))
	assert_ok(g.pass_priority(1))
	assert_ok(g.activate_ability(0, land, land.cur_activated_abilities.size() - 1,
		[TargetRef.card(stone)]))
	resolve_stack()
	assert_eq(stone.zone, Mtg.Zone.GRAVEYARD, "countered")
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD, "and the land lived")


func test_equinox_does_nothing_to_a_spell_that_spares_lands() -> void:
	var land := put_battlefield(0, "Forest")
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := give_hand(0, "Equinox")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(land)]))
	resolve_stack()
	var terror := give_hand(1, "Terror")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.B)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, terror, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(1))
	assert_ok(g.activate_ability(0, land, land.cur_activated_abilities.size() - 1,
		[TargetRef.card(terror)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "Terror resolved anyway")


func test_equinox_ability_leaves_with_the_aura() -> void:
	var land := put_battlefield(0, "Forest")
	var aura := give_hand(0, "Equinox")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(land)]))
	resolve_stack()
	var granted := land.cur_activated_abilities.size()
	g.destroy(aura)
	assert_eq(land.cur_activated_abilities.size(), granted - 1)


# ----------------------------------------------------------------- Arena --

func test_arena_makes_two_creatures_fight() -> void:
	var arena := put_battlefield(0, "Arena")
	var mine := put_battlefield(0, "Hill Giant")       # 3/3
	var theirs := put_battlefield(1, "Grizzly Bears")  # 2/2
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, arena, 0, [TargetRef.card(mine)]))
	resolve_stack()
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD, "3 kills a 2/2")
	assert_eq(mine.damage, 2)
	assert_true(mine.tapped, "both are tapped")


func test_arena_lets_the_defender_pick_their_champion() -> void:
	var agent := PickByName.new()
	agent.wanted = "Serra Angel"
	g.set_agent(1, agent)
	var arena := put_battlefield(0, "Arena")
	var mine := put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	var angel := put_battlefield(1, "Serra Angel")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, arena, 0, [TargetRef.card(mine)]))
	resolve_stack()
	assert_eq(angel.damage, 2, "their choice took the blow")
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD, "and swung back for 4")


func test_arena_cannot_be_activated_with_no_opposing_creature() -> void:
	# The champion is a TARGET of the opponent's choice (lifted 2026-09-02):
	# with no legal one the ability can't be activated at all (CR 601.2c).
	var arena := put_battlefield(0, "Arena")
	var mine := put_battlefield(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.activate_ability(0, arena, 0, [TargetRef.card(mine)]),
		"no legal target")
	assert_eq(mine.damage, 0)
	assert_false(mine.tapped, "nobody to fight, nothing happens")


func test_arena_refuses_a_creature_you_do_not_control() -> void:
	var arena := put_battlefield(0, "Arena")
	var theirs := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.activate_ability(0, arena, 0, [TargetRef.card(theirs)]),
		"Illegal target")
