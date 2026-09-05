extends GameTest
## Wave-58 tests: the "rent" creatures (Island Fish Jasconius, Serendib
## Djinn, Yawgmoth Demon, Mishra's War Machine), The Dark's Goblin land
## Auras, Curse Artifact's ransom, Giant Shark's blood frenzy, Cave
## People's attack pump and Witch Hunter's two taps.


## Answers every yes/no offer with a fixed reply, so the "you may" branch of
## an upkeep trigger can be driven from a test.
class WillingAgent extends DecisionAgent:
	var say := true

	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String, _hint: bool) -> bool:
		return say


## Picks a named card out of any candidate list (a land or artifact to
## sacrifice), falling back to the base heuristic.
class PickerAgent extends DecisionAgent:
	var pick_name := ""
	var say := true

	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String, _hint: bool) -> bool:
		return say

	func answer_card(game: MtgGame, pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		for inst in candidates:
			if inst.data.card_name == pick_name:
				return inst
		return super(game, pid, candidates, prompt)


func test_registry_loaded_wave58() -> void:
	for name in ["Witch Hunter", "Cave People", "Island Fish Jasconius",
			"Serendib Djinn", "Yawgmoth Demon", "Mishra's War Machine",
			"Giant Shark", "Curse Artifact", "Goblin Caves", "Goblin Shrine"]:
		assert_not_null(CardRegistry.get_card(name), name)


# ------------------------------------------------------------ Witch Hunter --

func test_witch_hunter_pings_a_player() -> void:
	var hunter := put_battlefield(0, "Witch Hunter")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, hunter, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 19)
	assert_true(hunter.tapped, "the ping costs the tap")


func test_witch_hunter_ping_cannot_aim_at_a_creature() -> void:
	var hunter := put_battlefield(0, "Witch Hunter")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, hunter, 0, [TargetRef.card(bear)]))


func test_witch_hunter_bounces_only_an_opponents_creature() -> void:
	var hunter := put_battlefield(0, "Witch Hunter")
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.activate_ability(0, hunter, 1, [TargetRef.card(mine)]),
		"Illegal target (controller).")
	assert_ok(g.activate_ability(0, hunter, 1, [TargetRef.card(theirs)]))
	resolve_stack()
	assert_eq(theirs.zone, Mtg.Zone.HAND)


func test_witch_hunter_can_only_use_one_ability_a_turn() -> void:
	var hunter := put_battlefield(0, "Witch Hunter")
	var theirs := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, hunter, 0, [TargetRef.player(1)]))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.activate_ability(0, hunter, 1, [TargetRef.card(theirs)]))


# ------------------------------------------------------------- Cave People --

func test_cave_people_swap_toughness_for_power_when_attacking() -> void:
	var people := put_battlefield(0, "Cave People")
	assert_eq(people.cur_power, 1)
	assert_eq(people.cur_toughness, 4)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [people.id]))
	resolve_stack()
	assert_eq(people.cur_power, 2)
	assert_eq(people.cur_toughness, 2)


func test_cave_people_pump_expires_with_the_turn() -> void:
	var people := put_battlefield(0, "Cave People")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [people.id]))
	resolve_stack()
	advance_to_next_turn()
	assert_eq(people.cur_power, 1)
	assert_eq(people.cur_toughness, 4)


func test_cave_people_grant_mountainwalk() -> void:
	var people := put_battlefield(0, "Cave People")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, people, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.cur_landwalk.has("mountain"))


func test_cave_people_mountainwalk_actually_evades() -> void:
	var people := put_battlefield(0, "Cave People")
	var bear := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Stone")
	put_battlefield(1, "Mountain")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, people, 0, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {wall.id: bear.id}), "mountainwalk")


# --------------------------------------------------- Island Fish Jasconius --

func test_island_fish_does_not_untap_on_its_own() -> void:
	put_battlefield(0, "Island")
	var fish := put_battlefield(0, "Island Fish Jasconius")
	g.tap_permanent(fish)
	advance_to_next_turn()
	advance_to_next_turn()   # back to our untap step and past our upkeep
	assert_true(fish.tapped, "one Island cannot pay the {U}{U}{U} ransom")


func test_island_fish_untaps_when_the_ransom_is_paid() -> void:
	for _i in 3:
		put_battlefield(0, "Island")
	var fish := put_battlefield(0, "Island Fish Jasconius")
	g.tap_permanent(fish)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_false(fish.tapped, "three Islands paid for the untap")


func test_island_fish_needs_an_enemy_island_to_attack() -> void:
	put_battlefield(0, "Island")
	var fish := put_battlefield(0, "Island Fish Jasconius")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [fish.id]), "Island")
	put_battlefield(1, "Island")
	assert_ok(g.declare_attackers(0, [fish.id]))


func test_island_fish_beaches_itself_without_islands() -> void:
	var island := put_battlefield(0, "Island")
	var fish := put_battlefield(0, "Island Fish Jasconius")
	assert_eq(fish.zone, Mtg.Zone.BATTLEFIELD)
	g.destroy(island)
	g.check_state_based_actions()
	assert_eq(fish.zone, Mtg.Zone.GRAVEYARD)


# ----------------------------------------------------------- Serendib Djinn --

func test_serendib_djinn_eats_a_non_island_first() -> void:
	put_battlefield(0, "Forest")
	var island := put_battlefield(0, "Island")
	put_battlefield(0, "Serendib Djinn")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(g.players[0].life, 20, "a Forest costs no life")
	assert_eq(island.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].battlefield.filter(
		func(i: CardInstance) -> bool: return i.is_land()).size(), 1)


func test_serendib_djinn_bites_when_it_eats_an_island() -> void:
	put_battlefield(0, "Island")
	put_battlefield(0, "Serendib Djinn")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(g.players[0].life, 17, "the Island cost 3")


func test_serendib_djinn_dies_with_your_last_land() -> void:
	var forest := put_battlefield(0, "Forest")
	var djinn := put_battlefield(0, "Serendib Djinn")
	g.destroy(forest)
	g.check_state_based_actions()
	assert_eq(djinn.zone, Mtg.Zone.GRAVEYARD, "no lands, no Djinn")


# ----------------------------------------------------------- Yawgmoth Demon --

func test_yawgmoth_demon_eats_an_artifact() -> void:
	var agent := PickerAgent.new()
	agent.pick_name = "Sol Ring"
	g.set_agent(0, agent)
	var ring := put_battlefield(0, "Sol Ring")
	put_battlefield(0, "Yawgmoth Demon")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 20)


func test_yawgmoth_demon_taps_and_bites_when_refused() -> void:
	var agent := WillingAgent.new()
	agent.say = false
	g.set_agent(0, agent)
	var ring := put_battlefield(0, "Sol Ring")
	var demon := put_battlefield(0, "Yawgmoth Demon")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(ring.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].life, 18)
	assert_true(demon.tapped)


func test_yawgmoth_demon_bites_with_no_artifacts_at_all() -> void:
	var demon := put_battlefield(0, "Yawgmoth Demon")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(g.players[0].life, 18)
	assert_true(demon.tapped)


# ------------------------------------------------------ Mishra's War Machine --

func test_war_machine_takes_a_card_instead_of_three() -> void:
	var machine := put_battlefield(0, "Mishra's War Machine")
	give_hand(0, "Grizzly Bears")
	give_hand(0, "Grizzly Bears")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(g.players[0].graveyard.size(), 1, "one card fed the Machine")
	assert_eq(g.players[0].life, 20, "no damage while the hand can pay")
	assert_false(machine.tapped)


func test_war_machine_bites_and_taps_on_an_empty_hand() -> void:
	var machine := put_battlefield(0, "Mishra's War Machine")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(g.players[0].life, 17)
	assert_true(machine.tapped)


func test_war_machine_has_banding() -> void:
	var machine := put_battlefield(0, "Mishra's War Machine")
	assert_true(machine.has_keyword(Mtg.Keyword.BANDING))


# ------------------------------------------------------------- Giant Shark --

func test_giant_shark_needs_an_enemy_island_to_attack() -> void:
	put_battlefield(0, "Island")
	var shark := put_battlefield(0, "Giant Shark")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [shark.id]), "Island")


func test_giant_shark_frenzies_on_a_wounded_attacker() -> void:
	put_battlefield(1, "Island")
	var shark := put_battlefield(1, "Giant Shark")
	var tim := put_battlefield(1, "Prodigal Sorcerer")
	var giant := put_battlefield(0, "Hill Giant")   # 3/3
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	resolve_stack()
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, tim, 0, [TargetRef.card(giant)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {shark.id: giant.id}))
	resolve_stack()
	assert_eq(shark.cur_power, 6, "blood in the water")
	assert_true(shark.has_keyword(Mtg.Keyword.TRAMPLE))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(shark.zone, Mtg.Zone.BATTLEFIELD)


func test_giant_shark_ignores_an_unwounded_attacker() -> void:
	put_battlefield(1, "Island")
	var shark := put_battlefield(1, "Giant Shark")
	var giant := put_battlefield(0, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {shark.id: giant.id}))
	resolve_stack()
	assert_eq(shark.cur_power, 4, "no wounds, no frenzy")


func test_giant_shark_is_sacrificed_without_islands() -> void:
	var island := put_battlefield(0, "Island")
	var shark := put_battlefield(0, "Giant Shark")
	g.destroy(island)
	g.check_state_based_actions()
	assert_eq(shark.zone, Mtg.Zone.GRAVEYARD)


# ----------------------------------------------------------- Curse Artifact --

func test_curse_artifact_bites_the_hosts_controller() -> void:
	var ring := put_battlefield(1, "Sol Ring")
	var curse := give_hand(0, "Curse Artifact")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, curse, [TargetRef.card(ring)]))
	resolve_stack()
	assert_eq(g.players[0].life, 20, "not OUR upkeep")
	advance_to_next_turn()      # player 1's turn: their upkeep pays
	assert_eq(g.players[1].life, 18)
	assert_eq(ring.zone, Mtg.Zone.BATTLEFIELD)


func test_curse_artifact_can_be_bought_off_with_the_artifact() -> void:
	var agent := WillingAgent.new()
	g.set_agent(1, agent)
	var ring := put_battlefield(1, "Sol Ring")
	var curse := give_hand(0, "Curse Artifact")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, curse, [TargetRef.card(ring)]))
	resolve_stack()
	advance_to_next_turn()
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 20)
	assert_eq(curse.zone, Mtg.Zone.GRAVEYARD, "the Aura falls off with its host")


# ------------------------------------------------- Goblin Caves and Shrine --

func test_goblin_caves_toughens_goblins_from_a_basic_mountain() -> void:
	var mountain := put_battlefield(0, "Mountain")
	var raiders := put_battlefield(0, "Mons's Goblin Raiders")
	var caves := give_hand(0, "Goblin Caves")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, caves, [TargetRef.card(mountain)]))
	resolve_stack()
	assert_eq(raiders.cur_power, 1)
	assert_eq(raiders.cur_toughness, 3)


func test_goblin_caves_does_nothing_on_a_nonbasic_land() -> void:
	var city := put_battlefield(0, "City of Brass")
	var raiders := put_battlefield(0, "Mons's Goblin Raiders")
	var caves := give_hand(0, "Goblin Caves")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, caves, [TargetRef.card(city)]))
	resolve_stack()
	assert_eq(raiders.cur_toughness, 1, "City of Brass is no basic Mountain")


func test_goblin_caves_helps_both_sides_goblins() -> void:
	var mountain := put_battlefield(0, "Mountain")
	var theirs := put_battlefield(1, "Mons's Goblin Raiders")
	var caves := give_hand(0, "Goblin Caves")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, caves, [TargetRef.card(mountain)]))
	resolve_stack()
	assert_eq(theirs.cur_toughness, 3, "the printed text says Goblin creatures")


func test_goblin_shrine_pumps_and_then_burns_them_down() -> void:
	var mountain := put_battlefield(0, "Mountain")
	var raiders := put_battlefield(0, "Mons's Goblin Raiders")
	var shrine := give_hand(0, "Goblin Shrine")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, shrine, [TargetRef.card(mountain)]))
	resolve_stack()
	assert_eq(raiders.cur_power, 2)
	# Killing the land drops the Aura, and the Aura's parting shot finishes
	# the very Goblins it was buffing.
	g.destroy(mountain)
	g.check_state_based_actions()
	resolve_stack()
	assert_eq(shrine.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(raiders.zone, Mtg.Zone.GRAVEYARD, "1 damage on a 1/1 Goblin")


func test_goblin_shrine_shot_ignores_non_goblins() -> void:
	var mountain := put_battlefield(0, "Mountain")
	var bear := put_battlefield(0, "Grizzly Bears")
	var shrine := give_hand(0, "Goblin Shrine")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, shrine, [TargetRef.card(mountain)]))
	resolve_stack()
	assert_eq(bear.cur_power, 2, "no Goblin, no anthem")
	g.destroy(mountain)
	g.check_state_based_actions()
	resolve_stack()
	assert_eq(bear.damage, 0)
