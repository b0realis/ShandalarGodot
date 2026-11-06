extends GameTest
## Pack 10 (the Urza block), batch B8: the Urza's Destiny artifacts of
## cards/sets/uds/_artifacts.gd — Braidwood Cup, Braidwood Sextant, Brass
## Secretary, Caltrops, Fodder Cannon, Mantis Engine, Powder Keg, Scrying
## Glass, Thran Foundry, Thran Golem and Urza's Incubator (its as-enters
## type held open for a human seat).

## Answers yes/no with [member yes] (-1 = the hint), cards by [member pick]
## ("" = the first offered), options by [member option] or the label
## [member label] (-1 / "" = the hint), colours by [member color] (-1 =
## the hint); records every question.
class Seat extends DecisionAgent:
	var yes := -1
	var pick := ""
	var option := -1
	var label := ""
	var color := -1
	var asked: Array = []
	func answer_yes_no(_g: MtgGame, _pid: int, prompt: String, hint: bool) -> bool:
		asked.append(["yes_no", prompt, hint])
		return hint if yes < 0 else yes == 1
	func answer_card(_g: MtgGame, _pid: int, candidates: Array[CardInstance], prompt: String) -> CardInstance:
		var names: Array = []
		for c in candidates: names.append(c.data.card_name)
		asked.append(["card", prompt, names])
		for c in candidates:
			if c.data.card_name == pick: return c
		return null if candidates.is_empty() else candidates[0]
	func answer_option(_g: MtgGame, _pid: int, prompt: String, options: Array[String], hint: int) -> int:
		asked.append(["option", prompt, options.duplicate(), hint])
		if label != "" and options.has(label): return options.find(label)
		return hint if option < 0 else option
	func answer_color(_g: MtgGame, _pid: int, prompt: String, hint: int) -> int:
		asked.append(["color", prompt, hint])
		return hint if color < 0 else color

func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func _seat(pid: int) -> Seat:
	var s := Seat.new()
	g.set_agent(pid, s)
	return s

func _on_library_top(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.LIBRARY
	g.players[pid].library.append(inst)
	return inst

func _in_graveyard(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(inst)
	return inst

func _reveals() -> Array:
	var seen: Array = []
	g.information_revealed.connect(func(_viewer: int, title: String, names: Array) -> void:
		seen.append([title, names.duplicate()]))
	return seen


# ------------------------------------------------------------- Braidwood Cup --

func test_braidwood_cup_taps_for_a_life() -> void:
	var cup := put_battlefield(0, "Braidwood Cup")
	assert_ok(g.activate_ability(0, cup, 0))
	resolve_stack()
	assert_eq(g.players[0].life, 21)
	assert_refused(g.activate_ability(0, cup, 0))


# --------------------------------------------------------- Braidwood Sextant --

func test_braidwood_sextant_finds_and_reveals_a_basic_land() -> void:
	var sextant := put_battlefield(0, "Braidwood Sextant")
	_on_library_top(0, "Mishra's Factory")
	_on_library_top(0, "Grizzly Bears")
	var seat := _seat(0)
	var shown := _reveals()
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, sextant, 0))
	assert_eq(sextant.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	var offered: Array = seat.asked[-1][2]
	assert_false(offered.has("Mishra's Factory"), "basic lands only")
	assert_false(offered.has("Grizzly Bears"))
	assert_true(offered.has("Forest"))
	assert_eq(g.players[0].hand.size(), 1)
	assert_eq(g.players[0].hand[0].data.card_name, "Forest")
	assert_eq(shown.size(), 1)
	assert_eq(shown[0][1], ["Forest"])


# ------------------------------------------------------------ Brass Secretary --

func test_brass_secretary_sacrifices_itself_to_draw() -> void:
	var secretary := put_battlefield(0, "Brass Secretary", true)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, secretary, 0))
	assert_eq(secretary.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 1)


# ------------------------------------------------------------------- Caltrops --

func test_caltrops_damages_each_attacking_creature_once() -> void:
	put_battlefield(0, "Caltrops")
	advance_to_next_turn()
	var bears := put_battlefield(1, "Grizzly Bears")
	var elves := put_battlefield(1, "Llanowar Elves")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [bears.id, elves.id]))
	assert_eq(g.stack.size(), 2, "one trigger per attacking creature (CR 603.2c)")
	resolve_stack()
	assert_eq(bears.damage, 1)
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)

func test_caltrops_damages_its_controllers_attackers_too() -> void:
	put_battlefield(0, "Caltrops")
	var bears := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bears.id]))
	resolve_stack()
	assert_eq(bears.damage, 1)


# -------------------------------------------------------------- Fodder Cannon --

func test_fodder_cannon_sacrifices_a_creature_for_four_damage() -> void:
	var cannon := put_battlefield(0, "Fodder Cannon")
	var elves := put_battlefield(0, "Llanowar Elves")
	var giant := put_battlefield(1, "Hill Giant")
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, cannon, 0, [TargetRef.card(giant)]))
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD, "the sacrifice is a cost")
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)

func test_fodder_cannon_needs_a_creature_to_sacrifice() -> void:
	var cannon := put_battlefield(0, "Fodder Cannon")
	var giant := put_battlefield(1, "Hill Giant")
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_refused(g.activate_ability(0, cannon, 0, [TargetRef.card(giant)]))


# -------------------------------------------------------------- Mantis Engine --

func test_mantis_engine_buys_flying_and_first_strike() -> void:
	var mantis := put_battlefield(0, "Mantis Engine")
	assert_false(mantis.has_keyword(Mtg.Keyword.FLYING))
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, mantis, 0))
	resolve_stack()
	assert_true(mantis.has_keyword(Mtg.Keyword.FLYING))
	assert_false(mantis.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_ok(g.activate_ability(0, mantis, 1))
	resolve_stack()
	assert_true(mantis.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_eq([mantis.cur_power, mantis.cur_toughness], [3, 3])
	advance_to_next_turn()
	assert_false(mantis.has_keyword(Mtg.Keyword.FLYING), "until end of turn")


# ----------------------------------------------------------------- Powder Keg --

func test_powder_keg_destroys_artifacts_and_creatures_of_its_fuse_count() -> void:
	var keg := put_battlefield(0, "Powder Keg")
	g.add_counters(keg, "fuse", 2)
	var bears := put_battlefield(1, "Grizzly Bears")
	var mine := put_battlefield(0, "Grizzly Bears")
	var ring := put_battlefield(1, "Sol Ring")
	var giant := put_battlefield(1, "Hill Giant")
	var crusade := put_battlefield(1, "Crusade")
	assert_ok(g.activate_ability(0, keg, 0))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD, "every mana value 2, yours too")
	assert_eq(ring.zone, Mtg.Zone.BATTLEFIELD, "mana value 1")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "mana value 4")
	assert_eq(crusade.zone, Mtg.Zone.BATTLEFIELD, "artifacts and creatures only")

func test_an_empty_powder_keg_destroys_mana_value_zero_and_tokens() -> void:
	var keg := put_battlefield(0, "Powder Keg")
	var thopter := put_battlefield(1, "Ornithopter")
	var made := g.create_token(1, CardData.new("Saproling", "", Mtg.CardType.CREATURE).pt(1, 1))
	var bears := put_battlefield(1, "Grizzly Bears")
	assert_ok(g.activate_ability(0, keg, 0))
	resolve_stack()
	assert_eq(thopter.zone, Mtg.Zone.GRAVEYARD)
	assert_ne(made[0].zone, Mtg.Zone.BATTLEFIELD, "a token's mana value is 0")
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)

func test_powder_keg_gains_a_fuse_each_upkeep_by_default() -> void:
	var keg := put_battlefield(0, "Powder Keg")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(int(keg.counters.get("fuse", 0)), 1)


# -------------------------------------------------------------- Scrying Glass --

func _glass_setup() -> CardInstance:
	var glass := put_battlefield(0, "Scrying Glass")
	give_hand(1, "Lightning Bolt")
	give_hand(1, "Shivan Dragon")
	give_hand(1, "Forest")
	return glass

func test_scrying_glass_draws_on_the_exact_number_of_the_color() -> void:
	var glass := _glass_setup()
	var seat := _seat(0)
	seat.option = 1   # the number 2
	seat.color = Mtg.ManaColor.R
	var shown := _reveals()
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, glass, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 1, "two red cards: you draw")
	assert_eq(shown.size(), 1, "the hand is revealed to both seats")
	var revealed: Array = shown[0][1]
	revealed.sort()
	assert_eq(revealed, ["Forest", "Lightning Bolt", "Shivan Dragon"])
	var numbers: Array = []
	for q in seat.asked:
		if q[0] == "option": numbers = q[2]
	assert_eq(numbers, ["1", "2", "3"], "greater than 0, up to the hand size")

func test_scrying_glass_draws_nothing_on_a_miss() -> void:
	var glass := _glass_setup()
	var seat := _seat(0)
	seat.option = 0   # the number 1
	seat.color = Mtg.ManaColor.R
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, glass, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 0)

func test_scrying_glass_targets_an_opponent_only() -> void:
	var glass := _glass_setup()
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.activate_ability(0, glass, 0, [TargetRef.player(0)]))


# -------------------------------------------------------------- Thran Foundry --

func test_thran_foundry_shuffles_a_target_players_graveyard_into_their_library() -> void:
	var foundry := put_battlefield(0, "Thran Foundry")
	_in_graveyard(1, "Lightning Bolt")
	_in_graveyard(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.activate_ability(0, foundry, 0, [TargetRef.player(1)]))
	assert_eq(foundry.zone, Mtg.Zone.EXILE, "exiled as the cost")
	resolve_stack()
	assert_eq(g.players[1].graveyard.size(), 0)
	assert_eq(g.players[1].library.size(), 32)


# ---------------------------------------------------------------- Thran Golem --

func test_thran_golem_grows_and_gains_keywords_while_enchanted() -> void:
	var golem := put_battlefield(0, "Thran Golem")
	assert_eq([golem.cur_power, golem.cur_toughness], [3, 3])
	assert_false(golem.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	var strength := give_hand(0, "Holy Strength")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, strength, [TargetRef.card(golem)]))
	resolve_stack()
	assert_eq([golem.cur_power, golem.cur_toughness], [6, 7], "3/3 + 2/2 + 1/2")
	for keyword in [Mtg.Keyword.FLYING, Mtg.Keyword.FIRST_STRIKE, Mtg.Keyword.TRAMPLE]:
		assert_true(golem.has_keyword(keyword))
	g.destroy(strength)
	g.recalculate()
	assert_eq([golem.cur_power, golem.cur_toughness], [3, 3])
	assert_false(golem.has_keyword(Mtg.Keyword.FLYING))


# ------------------------------------------------------------ Urza's Incubator --

func test_urzas_incubator_discounts_creature_spells_of_the_chosen_type() -> void:
	var seat := _seat(0)
	seat.label = "Bear"
	var incubator := give_hand(0, "Urza's Incubator")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, incubator))
	resolve_stack()
	assert_eq(String(incubator.memory.get("incubator_type", "")), "bear")
	var bears := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, bears))   # {1}{G} costs {G}: never below its coloured pip
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	var giant := give_hand(0, "Hill Giant")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(0, giant))   # a Giant is not of the chosen type: {3}{R} in full
	advance_to_next_turn()
	var theirs := give_hand(1, "Grizzly Bears")
	add_mana(1, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(1, theirs))   # every caster's creature spells

func test_urzas_incubator_holds_a_human_seat_on_the_creature_type() -> void:
	g.agents[0] = HumanAgent.new()
	g.interactive_choices = true
	var incubator := give_hand(0, "Urza's Incubator")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, incubator))
	var guard := 0
	while not g.stack.is_empty() and g.awaiting_choice == null and guard < 20:
		g.pass_priority(g.priority_player)
		guard += 1
	assert_not_null(g.awaiting_choice)
	if g.awaiting_choice == null: return
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.OPTION)
	assert_eq(g.awaiting_choice.source, "Urza's Incubator")
	var goblin: int = g.awaiting_choice.options.find("Goblin")
	assert_gt(goblin, -1)
	assert_ok(g.answer_choice(goblin))
	assert_eq(incubator.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(String(incubator.memory.get("incubator_type", "")), "goblin")
