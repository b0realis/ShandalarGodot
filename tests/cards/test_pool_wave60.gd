extends GameTest
## Wave-60 tests: the counter-driven Auras (Venarian Gold, Cocoon, Tangle
## Kelp), the Auras that move or come back (Kudzu, Puppet Master), the
## delayed graveyard watchers (Sandals of Abdallah, Axelrod Gunnarson, The
## Fallen), Cleansing's ransom and Life Matrix's granted regeneration.
##
## Also pins the two engine additions this wave needed:
## MtgGame.grant_keyword_permanently and MtgGame.move_aura.


## Refuses every optional offer.
class StingyAgent extends DecisionAgent:
	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String, _hint: bool) -> bool:
		return false


## Accepts every optional offer and picks a named card when it can.
class EagerAgent extends DecisionAgent:
	var pick_name := ""

	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String, _hint: bool) -> bool:
		return true

	func answer_card(game: MtgGame, pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		for inst in candidates:
			if inst.data.card_name == pick_name:
				return inst
		return super(game, pid, candidates, prompt)


func test_registry_loaded_wave60() -> void:
	for name in ["Venarian Gold", "Cocoon", "Puppet Master", "Axelrod Gunnarson",
			"Kudzu", "Sandals of Abdallah", "Cleansing", "The Fallen",
			"Tangle Kelp", "Life Matrix"]:
		assert_not_null(CardRegistry.get_card(name), name)


# ----------------------------------------------------------- Venarian Gold --

func test_venarian_gold_sleeps_a_creature_for_x_turns() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var gold := give_hand(0, "Venarian Gold")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, gold, [TargetRef.card(bear)], 2))
	resolve_stack()
	assert_true(bear.tapped)
	assert_eq(int(bear.counters.get("sleep", 0)), 2)
	advance_to_next_turn()      # their upkeep removes one; untap was skipped
	assert_true(bear.tapped)
	assert_eq(int(bear.counters.get("sleep", 0)), 1)
	advance_to_next_turn()
	advance_to_next_turn()      # their next upkeep removes the last one
	assert_eq(int(bear.counters.get("sleep", 0)), 0)
	assert_true(bear.tapped, "the lock lifts only at the NEXT untap step")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_false(bear.tapped)


func test_venarian_gold_for_zero_locks_nothing() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var gold := give_hand(0, "Venarian Gold")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, gold, [TargetRef.card(bear)], 0))
	resolve_stack()
	assert_true(bear.tapped, "it still taps on arrival")
	assert_eq(int(bear.counters.get("sleep", 0)), 0)
	advance_to_next_turn()
	assert_false(bear.tapped, "no sleep counter, no lock")


# ------------------------------------------------------------------ Cocoon --

func test_cocoon_hatches_after_three_upkeeps() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var cocoon := give_hand(0, "Cocoon")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, cocoon, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.tapped)
	assert_eq(int(cocoon.counters.get("pupa", 0)), 3)
	# Three upkeeps spend the three counters; the FOURTH is the one that
	# "can't" remove one, and that is when it hatches.
	for _i in 4:
		advance_to_next_turn()
		advance_to_next_turn()
	assert_eq(cocoon.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(int(bear.counters.get("+1/+1", 0)), 1)
	assert_eq(bear.cur_power, 3)
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING),
		"the flying grant outlives the Cocoon that made it")
	assert_false(bear.tapped, "the lock died with the last pupa counter")


func test_cocoon_only_goes_on_your_own_creature() -> void:
	var theirs := put_battlefield(1, "Grizzly Bears")
	var cocoon := give_hand(0, "Cocoon")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_refused(g.cast_spell(0, cocoon, [TargetRef.card(theirs)]))


# ------------------------------------------------------------ Puppet Master --

func test_puppet_master_returns_its_host_and_itself() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := give_hand(0, "Puppet Master")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 3)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.U, 3)
	g.destroy(bear)
	g.check_state_based_actions()
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.HAND)
	assert_eq(aura.zone, Mtg.Zone.HAND, "and the strings came back too")


func test_puppet_master_stays_dead_when_the_toll_is_refused() -> void:
	g.set_agent(0, StingyAgent.new())
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := give_hand(0, "Puppet Master")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 3)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.U, 3)
	g.destroy(bear)
	g.check_state_based_actions()
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.HAND, "the host comes back regardless")
	assert_eq(aura.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------- Axelrod Gunnarson --

func test_axelrod_drains_when_his_victim_dies() -> void:
	var axelrod := put_battlefield(0, "Axelrod Gunnarson")   # 5/5 trample
	var bear := put_battlefield(1, "Grizzly Bears")
	run_combat([axelrod.id], {bear.id: axelrod.id})
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 21, "1 life gained")
	# 3 trample damage plus the trigger's 1.
	assert_eq(g.players[1].life, 16)


func test_axelrod_counts_a_creature_someone_else_finished() -> void:
	var axelrod := put_battlefield(0, "Axelrod Gunnarson")
	var giant := put_battlefield(1, "Hill Giant")    # 3/3
	advance_to_step(Mtg.Step.MAIN1)
	# Axelrod wounds nothing yet: a ping does the wounding, then a bolt kills.
	g.deal_damage(axelrod, TargetRef.card(giant), 1)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 21)
	assert_eq(g.players[1].life, 19)


func test_axelrod_ignores_a_creature_he_never_touched() -> void:
	put_battlefield(0, "Axelrod Gunnarson")
	var giant := put_battlefield(1, "Hill Giant")
	var bolt := give_hand(0, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	g.deal_damage(giant, TargetRef.card(giant), 0)   # nothing at all
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.damage, 0)
	assert_eq(g.players[0].life, 20)


# ------------------------------------------------------------------- Kudzu --

func test_kudzu_destroys_the_land_that_taps() -> void:
	g.set_agent(1, StingyAgent.new())   # decline the hop
	var forest := put_battlefield(1, "Forest")
	var kudzu := give_hand(0, "Kudzu")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, kudzu, [TargetRef.card(forest)]))
	resolve_stack()
	assert_ok(g.tap_for_mana(1, forest))
	resolve_stack()
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(kudzu.zone, Mtg.Zone.GRAVEYARD, "nowhere to hop, so it dies too")


func test_kudzu_hops_to_another_land_of_their_choice() -> void:
	var agent := EagerAgent.new()
	agent.pick_name = "Island"
	g.set_agent(1, agent)
	var forest := put_battlefield(1, "Forest")
	var island := put_battlefield(1, "Island")
	var kudzu := give_hand(0, "Kudzu")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, kudzu, [TargetRef.card(forest)]))
	resolve_stack()
	assert_ok(g.tap_for_mana(1, forest))
	resolve_stack()
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(kudzu.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(kudzu.attached_to, island.id)
	assert_true(island.attachments.has(kudzu.id))


# ------------------------------------------------------ Sandals of Abdallah --

func test_sandals_grant_islandwalk_and_break_when_the_wearer_dies() -> void:
	var sandals := put_battlefield(0, "Sandals of Abdallah")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, sandals, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.cur_landwalk.has("island"))
	g.destroy(bear)
	resolve_stack()
	assert_eq(sandals.zone, Mtg.Zone.GRAVEYARD)


func test_sandals_forget_their_wearer_after_the_turn() -> void:
	var sandals := put_battlefield(0, "Sandals of Abdallah")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, sandals, 0, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_next_turn()
	g.destroy(bear)
	resolve_stack()
	assert_eq(sandals.zone, Mtg.Zone.BATTLEFIELD, "'this turn' has passed")


# ---------------------------------------------------------------- Cleansing --

func test_cleansing_destroys_the_lands_nobody_pays_for() -> void:
	g.set_agent(0, StingyAgent.new())
	g.set_agent(1, StingyAgent.new())
	var mine := put_battlefield(0, "Forest")
	var theirs := put_battlefield(1, "Island")
	var spell := give_hand(0, "Cleansing")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 3)
	assert_ok(g.cast_spell(0, spell, []))
	resolve_stack()
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 20)


func test_cleansing_spares_a_land_someone_pays_for() -> void:
	var mine := put_battlefield(0, "Forest")
	var theirs := put_battlefield(1, "Island")
	var spell := give_hand(0, "Cleansing")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 3)
	assert_ok(g.cast_spell(0, spell, []))
	resolve_stack()
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD, "we paid for our own")
	assert_eq(theirs.zone, Mtg.Zone.BATTLEFIELD, "and so did they")
	assert_eq(g.players[0].life, 19)
	assert_eq(g.players[1].life, 19)


# --------------------------------------------------------------- The Fallen --

func test_the_fallen_only_haunts_who_it_has_bitten() -> void:
	var fallen := put_battlefield(0, "The Fallen")   # 2/3
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(g.players[1].life, 20, "it has bitten nobody yet")
	run_combat([fallen.id])
	assert_eq(g.players[1].life, 18)
	advance_to_next_turn()
	advance_to_next_turn()      # our upkeep: the grudge pays out
	assert_eq(g.players[1].life, 17)


func test_the_fallen_forgets_when_it_dies() -> void:
	var fallen := put_battlefield(0, "The Fallen")
	run_combat([fallen.id])
	assert_eq(g.players[1].life, 18)
	g.destroy(fallen)
	assert_eq(fallen.memory.size(), 0, "a new object carries no grudges")


# -------------------------------------------------------------- Tangle Kelp --

func test_tangle_kelp_taps_on_arrival() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var kelp := give_hand(0, "Tangle Kelp")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, kelp, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.tapped)
	advance_to_next_turn()
	assert_false(bear.tapped, "it did not attack, so it untaps")


func test_tangle_kelp_keeps_an_attacker_down() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var kelp := give_hand(0, "Tangle Kelp")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, kelp, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_next_turn()      # their turn: it untaps and attacks
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [bear.id]))
	advance_to_next_turn()
	advance_to_next_turn()      # back to their untap step
	assert_true(bear.tapped, "it attacked during its controller's last turn")


# -------------------------------------------------------------- Life Matrix --

func test_life_matrix_hands_out_a_regeneration_shield() -> void:
	var matrix := put_battlefield(0, "Life Matrix")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.UPKEEP)   # our own upkeep
	resolve_stack()
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, matrix, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(int(bear.counters.get("matrix", 0)), 1)
	assert_eq(bear.cur_activated_abilities.size(), 1, "the granted ability")
	assert_ok(g.activate_ability(0, bear, 0, []))
	resolve_stack()
	assert_eq(int(bear.counters.get("matrix", 0)), 0, "the counter was the cost")
	assert_eq(bear.regeneration_shields, 1)
	g.destroy(bear)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "regenerated")


func test_life_matrix_only_fires_in_your_upkeep() -> void:
	var matrix := put_battlefield(0, "Life Matrix")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_refused(g.activate_ability(0, matrix, 0, [TargetRef.card(bear)]))
