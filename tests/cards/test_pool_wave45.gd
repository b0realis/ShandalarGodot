extends GameTest
## Wave-45 tests: the whole ASTRAL set — the 1997 pool's twelve
## "random-effect" cards. Every roll goes through game.rng, so these tests
## set boards where only one outcome is possible (one creature, one
## graveyard with one body) and assert THAT, rather than betting on a seed.


func test_registry_loaded_the_astral_set() -> void:
	for name in ["Aswan Jaguar", "Call from the Grave", "Faerie Dragon",
			"Gem Bazaar", "Goblin Polka Band", "Necropolis of Azar",
			"Orcish Catapult", "Pandora's Box", "Power Struggle",
			"Prismatic Dragon", "Rainbow Knights", "Whimsy"]:
		assert_not_null(CardRegistry.get_card(name), name)


# ------------------------------------------------------------- Gem Bazaar --

func test_gem_bazaar_taps_for_one_mana_of_some_colour() -> void:
	var bazaar := put_battlefield(0, "Gem Bazaar")
	resolve_stack()                                  # the "choose a colour" ETB
	assert_true(bazaar.memory.has("color"), "it chose a colour on arrival")
	var before: int = int(bazaar.memory["color"])
	assert_ok(g.tap_for_mana(0, bazaar))
	var total := 0
	for c in Mtg.WUBRG:
		total += g.players[0].mana_pool.amount_of(c)
	assert_eq(total, 1, "exactly one mana")
	assert_eq(g.players[0].mana_pool.amount_of(before), 1,
		"and it is the colour that was showing")
	assert_true(bazaar.memory.has("color"), "then it rerolls for next time")


# ------------------------------------------------------- Prismatic Dragon --

func test_prismatic_dragon_repaints_itself() -> void:
	var dragon := put_battlefield(0, "Prismatic Dragon")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, dragon, 0, []))
	resolve_stack()
	var single := dragon.cur_colors
	assert_true(Mtg.WUBRG.has(single), "exactly one of the five colours")


func test_prismatic_dragon_repaints_on_your_upkeep() -> void:
	var dragon := put_battlefield(0, "Prismatic Dragon")
	advance_to_next_turn()      # the opponent's upkeep — nothing
	advance_to_next_turn()      # ours
	resolve_stack()
	assert_true(Mtg.WUBRG.has(dragon.cur_colors))
	assert_ne(dragon.color_override, -1, "the upkeep trigger really fired")


# -------------------------------------------------------- Rainbow Knights --

func test_rainbow_knights_gain_protection_on_arrival() -> void:
	var knights := put_battlefield(0, "Rainbow Knights")
	resolve_stack()
	assert_ne(knights.added_protection, 0, "some colour was chosen")
	assert_eq(knights.cur_protection, knights.added_protection,
		"and it shows up in the live protection mask")


func test_rainbow_knights_random_boost_is_zero_to_two() -> void:
	var knights := put_battlefield(0, "Rainbow Knights")
	resolve_stack()
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_ok(g.activate_ability(0, knights, 1, []))
	resolve_stack()
	assert_between(knights.cur_power, 2, 4, "2/1 plus 0, 1 or 2 power")
	assert_eq(knights.cur_toughness, 1)


func test_rainbow_knights_buy_first_strike() -> void:
	var knights := put_battlefield(0, "Rainbow Knights")
	resolve_stack()
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, knights, 0, []))
	resolve_stack()
	assert_true(knights.has_keyword(Mtg.Keyword.FIRST_STRIKE))


# ---------------------------------------------------- Call from the Grave --

func test_call_from_the_grave_raises_the_only_corpse() -> void:
	# Both graveyards hold exactly one creature, so whichever is rolled the
	# result is the same: a bear on our side and 2 damage to us.
	for pid in [0, 1]:
		var dead := give_hand(pid, "Grizzly Bears")
		g.players[pid].hand.erase(dead)
		dead.zone = Mtg.Zone.GRAVEYARD
		g.players[pid].graveyard.append(dead)
	var call := give_hand(0, "Call from the Grave")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, call, []))
	resolve_stack()
	assert_eq(g.players[0].battlefield.size(), 1, "a bear came back to us")
	assert_eq(g.players[0].battlefield[0].data.card_name, "Grizzly Bears")
	assert_eq(g.players[0].life, 18, "and it cost us its mana value in damage")


# ------------------------------------------------------- Orcish Catapult --

func test_orcish_catapult_dumps_every_counter_on_the_only_creature() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")   # 2/2
	var catapult := give_hand(0, "Orcish Catapult")
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, catapult, [], 3))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "three -0/-1 counters kill a 2/2")


func test_orcish_catapult_with_an_empty_board_does_nothing() -> void:
	# Lifted 2026-09-02 (docs/simplified-cards.md, "Astral random
	# targeting"): the targets are rolled as the spell is cast, so X>0 with
	# no creature to roll can't be cast at all — X=0 has no counter to give
	# and takes no target, so it still resolves doing nothing.
	var catapult := give_hand(0, "Orcish Catapult")
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.cast_spell(0, catapult, [], 2), "no legal target")
	assert_ok(g.cast_spell(0, catapult, [], 0))
	resolve_stack()
	assert_eq(catapult.zone, Mtg.Zone.GRAVEYARD)


# ----------------------------------------------------- Goblin Polka Band --

func test_polka_band_taps_a_random_creature_and_pays_red_per_target() -> void:
	# Lifted 2026-09-02 (docs/simplified-cards.md, "Astral random
	# targeting"): ANY creature can be rolled, the Band itself included, so
	# X=2 on a two-creature board is what guarantees the Wall is hit.
	var band := put_battlefield(0, "Goblin Polka Band")
	var victim := put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.activate_ability(0, band, 0, [], 2), "not enough mana")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, band, 0, [], 2))
	resolve_stack()
	assert_true(victim.tapped)


func test_polka_band_keeps_goblins_down_an_extra_turn() -> void:
	var band := put_battlefield(0, "Goblin Polka Band")
	var goblin := put_battlefield(1, "Mons's Goblin Raiders")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.activate_ability(0, band, 0, [], 2))   # both creatures: the Band and the Raiders
	resolve_stack()
	assert_true(goblin.tapped)
	assert_true(goblin.skip_next_untap, "Goblins tapped this way stay down")
	advance_to_next_turn()
	assert_true(goblin.tapped, "it skipped its controller's untap step")


# ---------------------------------------------------- Necropolis of Azar --

func test_necropolis_collects_husks_and_spawns() -> void:
	var necropolis := put_battlefield(0, "Necropolis of Azar")
	var bear := put_battlefield(1, "Grizzly Bears")     # green, so it counts
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, necropolis, 0, []), "husk")
	g.destroy(bear)
	g.check_state_based_actions()
	resolve_stack()
	assert_eq(int(necropolis.counters.get("husk", 0)), 1)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.activate_ability(0, necropolis, 0, []))
	resolve_stack()
	var spawn := g.find_on_battlefield(0, "Spawn of Azar")
	assert_not_null(spawn)
	assert_between(spawn.cur_power, 1, 3)
	assert_between(spawn.cur_toughness, 1, 3)
	assert_true(spawn.cur_landwalk.has("swamp"))
	assert_eq(int(necropolis.counters.get("husk", 0)), 0, "the husk was spent")


func test_necropolis_ignores_black_creatures() -> void:
	var necropolis := put_battlefield(0, "Necropolis of Azar")
	var knight := put_battlefield(1, "Black Knight")
	g.destroy(knight)
	g.check_state_based_actions()
	resolve_stack()
	assert_eq(int(necropolis.counters.get("husk", 0)), 0)


# ------------------------------------------------------------ Aswan Jaguar --

func test_aswan_jaguar_hunts_the_type_it_rolled() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")     # the only type around
	var jaguar := put_battlefield(0, "Aswan Jaguar")
	resolve_stack()
	assert_eq(String(jaguar.memory.get("type", "")), "bear")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.activate_ability(0, jaguar, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


func test_aswan_jaguar_refuses_the_wrong_type() -> void:
	put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var jaguar := put_battlefield(0, "Aswan Jaguar")
	resolve_stack()
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	if String(jaguar.memory.get("type", "")) != "giant":
		assert_refused(g.activate_ability(0, jaguar, 0, [TargetRef.card(giant)]),
			"Illegal target")


# ---------------------------------------------------------- Pandora's Box --

func test_pandoras_box_copies_a_summon_card_from_a_library() -> void:
	# Seed both libraries with exactly one creature card so the roll is
	# forced; each player then flips for a token copy of it.
	for pid in [0, 1]:
		var card := _make_instance(pid, "Grizzly Bears")
		card.zone = Mtg.Zone.LIBRARY
		g.players[pid].library.append(card)
	var box := put_battlefield(0, "Pandora's Box")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, box, 0, []))
	resolve_stack()
	var tokens := 0
	for inst in g.all_battlefield():
		if inst.is_token and inst.data.card_name == "Grizzly Bears":
			tokens += 1
	assert_between(tokens, 0, 2, "one coin flip per player")
	assert_eq(g.players[0].library.back().data.card_name, "Grizzly Bears",
		"the chosen card itself stays in the deck")


# ---------------------------------------------------------- Power Struggle --

func test_power_struggle_swaps_a_permanent_each_upkeep() -> void:
	put_battlefield(0, "Power Struggle")
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	# The opponent's upkeep comes first, and they control exactly one
	# swappable permanent, so the trade is forced.
	advance_to_next_turn()
	resolve_stack()
	assert_eq(theirs.controller_id, 0, "their Giant crossed over")
	assert_eq(mine.controller_id, 1, "and our bear went the other way")
	# Our own upkeep trades them back — the enchantment is symmetric.
	advance_to_next_turn()
	resolve_stack()
	assert_eq(theirs.controller_id, 1)
	assert_eq(mine.controller_id, 0)


# --------------------------------------------- Whimsy and the Faerie Dragon --

func test_whimsy_plays_x_random_effects() -> void:
	put_battlefield(1, "Grizzly Bears")
	var whimsy := give_hand(0, "Whimsy")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 4)
	var log_before := g.log_lines.size()
	assert_ok(g.cast_spell(0, whimsy, [], 4))
	resolve_stack()
	assert_gt(g.log_lines.size(), log_before, "four rolls left a trail")
	assert_eq(whimsy.zone, Mtg.Zone.GRAVEYARD)


func test_whimsy_is_deterministic_under_a_seed() -> void:
	# The whole point of routing the rolls through game.rng: the same seed
	# must produce the same table entries.
	var first := _run_whimsy(7777)
	var second := _run_whimsy(7777)
	assert_eq(first, second, "same seed, same random effects")


func _run_whimsy(seed_value: int) -> String:
	var sim := MtgGame.new()
	var filler: Array = []
	for _i in 30:
		filler.append("Forest")
	sim.setup(filler, filler, "P0", "P1", 20, 20, seed_value)
	sim.start(0)
	var bear := CardInstance.new(CardRegistry.get_card("Grizzly Bears"),
		sim._next_instance_id, 1)
	sim._next_instance_id += 1
	sim._instances[bear.id] = bear
	sim._put_on_battlefield(bear, 1)
	var whimsy := CardInstance.new(CardRegistry.get_card("Whimsy"),
		sim._next_instance_id, 0)
	sim._next_instance_id += 1
	sim._instances[whimsy.id] = whimsy
	whimsy.zone = Mtg.Zone.HAND
	sim.players[0].hand.append(whimsy)
	while sim.current_step() != Mtg.Step.MAIN1 and not sim.game_over:
		sim.pass_priority(sim.priority_player)
	sim.players[0].mana_pool.add(Mtg.ManaColor.U, 2)
	sim.players[0].mana_pool.add(Mtg.ManaColor.C, 3)
	sim.cast_spell(0, whimsy, [], 3)
	var guard := 0
	while not sim.stack.is_empty() and not sim.game_over and guard < 50:
		sim.pass_priority(sim.priority_player)
		guard += 1
	return "\n".join(sim.log_lines)


func test_faerie_dragon_plays_one_random_effect() -> void:
	var dragon := put_battlefield(0, "Faerie Dragon")
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C)
	var log_before := g.log_lines.size()
	assert_ok(g.activate_ability(0, dragon, 0, []))
	resolve_stack()
	assert_gt(g.log_lines.size(), log_before)
