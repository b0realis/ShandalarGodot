extends GameTest
## Pack 10 (the Urza block), batch B8: the Urza's Saga artifacts of
## cards/sets/usg/_artifacts.gd, second half — Metrognome, Mishra's Helix,
## Mobile Fort, Noetic Scales, Phyrexian Processor (its as-enters payment
## held open for a human seat), Purging Scythe, Smokestack, Umbilicus,
## Urza's Armor, Whetstone and Wirecat.

## Answers yes/no with [member yes] (-1 = the hint), cards by [member pick]
## ("" = the first offered, "-" = decline), options by [member option]
## (-1 = the hint); records every question.
class Seat extends DecisionAgent:
	var yes := -1
	var pick := ""
	var option := -1
	var asked: Array = []
	func answer_yes_no(_g: MtgGame, _pid: int, prompt: String, hint: bool) -> bool:
		asked.append(["yes_no", prompt, hint])
		return hint if yes < 0 else yes == 1
	func answer_card(_g: MtgGame, _pid: int, candidates: Array[CardInstance], prompt: String) -> CardInstance:
		var names: Array = []
		for c in candidates: names.append(c.data.card_name)
		asked.append(["card", prompt, names])
		if pick == "-": return null
		for c in candidates:
			if c.data.card_name == pick: return c
		return null if candidates.is_empty() else candidates[0]
	func answer_option(_g: MtgGame, _pid: int, prompt: String, options: Array[String], hint: int) -> int:
		asked.append(["option", prompt, options.duplicate(), hint])
		return hint if option < 0 else option

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

func _to_next_turn_of(pid: int) -> void:
	advance_to_next_turn()
	if g.active_player != pid: advance_to_next_turn()
	assert_eq(g.active_player, pid)

## Walk to the UPKEEP of the next turn, its triggers on the stack, unresolved.
func _to_next_upkeep() -> void:
	var turn := g.turn_number
	var guard := 0
	while not (g.turn_number > turn and g.current_step() == Mtg.Step.UPKEEP) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400, "did not reach the next upkeep")

func _named(pid: int, card_name: String) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if i.data.card_name == card_name: out.append(i)
	return out

func _cast(pid: int, card_name: String, generic: int) -> CardInstance:
	var card := give_hand(pid, card_name)
	add_mana(pid, Mtg.ManaColor.C, generic)
	assert_ok(g.cast_spell(pid, card))
	resolve_stack()
	return card


# ---------------------------------------------------------------- Metrognome --

func test_metrognome_discarded_by_an_opponents_ability_makes_four_gnomes() -> void:
	advance_to_next_turn()   # P1's turn: the Scepter is "your turn only"
	var scepter := put_battlefield(1, "Disrupting Scepter")
	var gnome_card := give_hand(0, "Metrognome")
	add_mana(1, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(1, scepter, 0, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(gnome_card.zone, Mtg.Zone.GRAVEYARD)
	var gnomes := _named(0, "Gnome")
	assert_eq(gnomes.size(), 4, "four tokens for the player who discarded it")
	for gnome in gnomes:
		assert_true(gnome.is_token and gnome.is_creature() and gnome.is_type(Mtg.CardType.ARTIFACT))
		assert_eq([gnome.cur_power, gnome.cur_toughness], [1, 1])
		assert_eq(gnome.cur_colors, 0, "colorless")

func test_metrognome_discarded_by_its_owners_own_spell_makes_nothing() -> void:
	give_hand(0, "Metrognome")
	give_hand(1, "Metrognome")
	var wheel := give_hand(0, "Wheel of Fortune")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, wheel))
	resolve_stack()
	assert_eq(_named(0, "Gnome").size(), 0, "your own spell: no gnomes")
	assert_eq(_named(1, "Gnome").size(), 4, "the opponent's spell discarded P1's")

func test_metrognome_makes_a_gnome_for_four() -> void:
	var gnome_maker := put_battlefield(0, "Metrognome")
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, gnome_maker, 0))
	resolve_stack()
	assert_eq(_named(0, "Gnome").size(), 1)
	assert_true(gnome_maker.tapped)


# ------------------------------------------------------------- Mishra's Helix --

func test_mishras_helix_taps_x_target_lands() -> void:
	var helix := put_battlefield(0, "Mishra's Helix")
	var a := put_battlefield(1, "Forest")
	var b := put_battlefield(1, "Forest")
	var c := put_battlefield(1, "Forest")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, helix, 0, [TargetRef.card(a), TargetRef.card(b)], 2))
	resolve_stack()
	assert_true(a.tapped and b.tapped)
	assert_false(c.tapped)
	assert_true(helix.tapped)

func test_mishras_helix_targets_lands_only() -> void:
	var helix := put_battlefield(0, "Mishra's Helix")
	var bears := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_refused(g.activate_ability(0, helix, 0, [TargetRef.card(bears)], 1))


# --------------------------------------------------------------- Mobile Fort --

func test_mobile_fort_cannot_attack_until_it_is_pumped() -> void:
	var fort := put_battlefield(0, "Mobile Fort")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [fort.id]))
	assert_ok(g.declare_attackers(0, []))

func test_mobile_fort_pumped_once_each_turn_may_attack() -> void:
	var fort := put_battlefield(0, "Mobile Fort")
	add_mana(0, Mtg.ManaColor.C, 6)
	assert_ok(g.activate_ability(0, fort, 0))
	resolve_stack()
	assert_eq([fort.cur_power, fort.cur_toughness], [3, 5])
	assert_refused(g.activate_ability(0, fort, 0), "once")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [fort.id]))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 17)


# ------------------------------------------------------------- Noetic Scales --

func test_noetic_scales_returns_each_creature_bigger_than_the_upkeep_players_hand() -> void:
	put_battlefield(0, "Noetic Scales")
	var giant := put_battlefield(1, "Hill Giant")
	var elves := put_battlefield(1, "Llanowar Elves")
	var dragon := put_battlefield(0, "Shivan Dragon")
	give_hand(1, "Lightning Bolt")   # one card in P1's hand at their upkeep
	_to_next_upkeep()
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.HAND, "power 3 > 1 card")
	assert_eq(elves.zone, Mtg.Zone.BATTLEFIELD, "power 1 is not greater than 1")
	assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD, "only the upkeep player's creatures")


# ------------------------------------------------------- Phyrexian Processor --

func test_phyrexian_processor_pays_life_as_it_enters_and_makes_that_big_a_minion() -> void:
	var seat := _seat(0)
	seat.option = 6
	var processor := _cast(0, "Phyrexian Processor", 4)
	assert_eq(processor.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].life, 14)
	var asked: Array = seat.asked[-1]
	assert_eq(asked[0], "option")
	assert_eq((asked[2] as Array).size(), 21, "0 to 20 life")
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, processor, 0))
	resolve_stack()
	var minions := _named(0, "Phyrexian Minion")
	assert_eq(minions.size(), 1)
	assert_eq([minions[0].cur_power, minions[0].cur_toughness], [6, 6])
	assert_eq(minions[0].cur_colors, Mtg.ManaColor.B)
	assert_true(minions[0].has_subtype("phyrexian") and minions[0].has_subtype("minion"))

func test_phyrexian_processor_sizes_the_token_even_if_it_has_gone() -> void:
	_seat(0).option = 5
	var processor := _cast(0, "Phyrexian Processor", 4)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, processor, 0))
	g.destroy(processor)   # in response
	resolve_stack()
	var minions := _named(0, "Phyrexian Minion")
	assert_eq(minions.size(), 1)
	assert_eq(minions[0].cur_power, 5, "the life paid, recorded with the cost (CR 608.2h)")

func test_phyrexian_processor_paying_nothing_makes_a_dying_zero_zero() -> void:
	_seat(0).option = 0
	var processor := _cast(0, "Phyrexian Processor", 4)
	assert_eq(g.players[0].life, 20)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, processor, 0))
	resolve_stack()
	assert_eq(_named(0, "Phyrexian Minion").size(), 0, "a 0/0 token")

func test_phyrexian_processor_at_zero_life_pays_nothing_and_asks_nothing() -> void:
	var seat := _seat(0)
	g.players[0].life = 0
	g.rules.life_checked_at_phase_end = true
	var processor := give_hand(0, "Phyrexian Processor")
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, processor))
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_eq(int(processor.memory.get("paid", -1)), 0)
	for q in seat.asked:
		assert_ne(q[0], "option", "no amount is offered (CR 119.4)")

## The as-enters payment of a RESOLVING permanent is reached by the
## resolution pre-flight: a human seat is held open on it (OPTION), nothing
## has entered or been paid meanwhile, and the answer is the life paid.
func test_phyrexian_processor_holds_a_human_seat_on_the_amount() -> void:
	g.agents[0] = HumanAgent.new()
	g.interactive_choices = true
	var processor := give_hand(0, "Phyrexian Processor")
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, processor))
	var guard := 0
	while not g.stack.is_empty() and g.awaiting_choice == null and guard < 20:
		g.pass_priority(g.priority_player)
		guard += 1
	assert_not_null(g.awaiting_choice, "the resolution is held for the player")
	if g.awaiting_choice == null: return
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.OPTION)
	assert_eq(g.awaiting_choice.pid, 0)
	assert_eq(g.awaiting_choice.source, "Phyrexian Processor")
	assert_eq(g.awaiting_choice.options.size(), 21)
	assert_eq(processor.zone, Mtg.Zone.STACK, "nothing has entered while the question is open")
	assert_eq(g.players[0].life, 20, "and nothing is paid")
	assert_ok(g.answer_choice(7))
	assert_null(g.awaiting_choice)
	assert_eq(processor.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(int(processor.memory.get("paid", -1)), 7)
	assert_eq(g.players[0].life, 13)
	assert_eq(g.unanswered_choices.size(), 0, "the player answered it themselves")


# ------------------------------------------------------------ Purging Scythe --

func test_purging_scythe_hits_the_creature_with_the_least_toughness() -> void:
	put_battlefield(0, "Purging Scythe")
	var giant := put_battlefield(0, "Hill Giant")
	var elves := put_battlefield(1, "Llanowar Elves")
	_to_next_turn_of(0)
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.damage, 0)

func test_purging_scythe_lets_you_choose_among_the_tied() -> void:
	put_battlefield(0, "Purging Scythe")
	var birds := put_battlefield(0, "Birds of Paradise")
	var elves := put_battlefield(1, "Llanowar Elves")
	var seat := _seat(0)
	_to_next_turn_of(0)
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD, "the hint offers the opponent's first")
	assert_eq(birds.zone, Mtg.Zone.BATTLEFIELD)
	var tie: Array = []
	for q in seat.asked:
		if q[0] == "card" and String(q[1]).begins_with("Purging Scythe"): tie = q[2]
	assert_eq(tie, ["Llanowar Elves", "Birds of Paradise"])

func test_purging_scythe_picks_your_own_if_you_say_so() -> void:
	put_battlefield(0, "Purging Scythe")
	var birds := put_battlefield(0, "Birds of Paradise")
	var elves := put_battlefield(1, "Llanowar Elves")
	var seat := _seat(0)
	seat.pick = "Birds of Paradise"
	_to_next_turn_of(0)
	assert_eq(birds.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(elves.zone, Mtg.Zone.BATTLEFIELD)


# ---------------------------------------------------------------- Smokestack --

func test_smokestack_makes_the_upkeep_player_sacrifice_a_permanent_per_soot() -> void:
	var stack := put_battlefield(0, "Smokestack")
	g.add_counters(stack, "soot", 2)
	for _n in 3: put_battlefield(1, "Forest")
	advance_to_next_turn()
	assert_eq(g.players[1].battlefield.size(), 1, "two of three sacrificed")

func test_smokestack_in_your_upkeep_sacrifices_before_the_new_soot() -> void:
	var stack := put_battlefield(0, "Smokestack")
	g.add_counters(stack, "soot", 1)
	for _n in 3: put_battlefield(0, "Forest")
	_to_next_turn_of(0)
	assert_eq(stack.zone, Mtg.Zone.BATTLEFIELD, "a land goes before the Smokestack")
	assert_eq(_named(0, "Forest").size(), 2, "one soot as the sacrifice resolved")
	assert_eq(int(stack.counters.get("soot", 0)), 2, "then the new counter (the hint: more permanents than the opponent)")

func test_smokestack_counts_its_soot_as_last_known_when_it_has_gone() -> void:
	var stack := put_battlefield(0, "Smokestack")
	g.add_counters(stack, "soot", 2)
	for _n in 3: put_battlefield(1, "Forest")
	_to_next_upkeep()
	assert_false(g.stack.is_empty())
	g.destroy(stack)
	resolve_stack()
	assert_eq(g.players[1].battlefield.size(), 1, "two soot as it last existed (CR 608.2h)")

func test_smokestack_soot_is_declined_while_its_controller_has_fewer_permanents() -> void:
	var stack := put_battlefield(0, "Smokestack")
	for _n in 3: put_battlefield(1, "Forest")
	_to_next_turn_of(0)
	assert_eq(int(stack.counters.get("soot", 0)), 0)
	_seat(0).yes = 1
	_to_next_turn_of(0)
	assert_eq(int(stack.counters.get("soot", 0)), 1, "a yes adds it")


# ----------------------------------------------------------------- Umbilicus --

func test_umbilicus_asks_the_upkeep_player_to_pay_two_life() -> void:
	put_battlefield(0, "Umbilicus")
	var bears := put_battlefield(1, "Grizzly Bears")
	var seat := _seat(1)
	advance_to_next_turn()
	assert_eq(g.players[1].life, 18, "the hint pays at 20 life")
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(seat.asked[0][0], "yes_no", "the upkeep player is asked")
	assert_eq(g.players[0].life, 20)

func test_umbilicus_returns_a_permanent_of_their_choice_if_they_dont_pay() -> void:
	put_battlefield(0, "Umbilicus")
	var bears := put_battlefield(1, "Grizzly Bears")
	var forest := put_battlefield(1, "Forest")
	var seat := _seat(1)
	seat.yes = 0
	seat.pick = "Grizzly Bears"
	advance_to_next_turn()
	assert_eq(g.players[1].life, 20)
	assert_eq(bears.zone, Mtg.Zone.HAND)
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)

func test_umbilicus_cannot_be_paid_with_one_life() -> void:
	put_battlefield(0, "Umbilicus")
	var bears := put_battlefield(1, "Grizzly Bears")
	g.players[1].life = 1
	var seat := _seat(1)
	seat.yes = 1
	advance_to_next_turn()
	assert_eq(g.players[1].life, 1, "2 life can't be paid from 1 (CR 119.4)")
	assert_eq(bears.zone, Mtg.Zone.HAND)
	for q in seat.asked:
		assert_ne(q[0], "yes_no", "the payment is not even offered")

func test_umbilicus_also_triggers_in_its_controllers_upkeep() -> void:
	put_battlefield(0, "Umbilicus")
	g.players[0].life = 5
	var bears := put_battlefield(0, "Grizzly Bears")
	_to_next_turn_of(0)
	assert_eq(g.players[0].life, 5, "the hint keeps 5 life")
	assert_eq(bears.zone, Mtg.Zone.HAND, "and returns the permanent instead")


# --------------------------------------------------------------- Urza's Armor --

func test_urzas_armor_prevents_one_of_each_damage_to_you() -> void:
	put_battlefield(0, "Urza's Armor")
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 18, "3 - 1")

func test_urzas_armor_prevents_one_per_attacking_source() -> void:
	put_battlefield(0, "Urza's Armor")
	advance_to_next_turn()
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	run_combat([a.id, b.id])
	assert_eq(g.players[0].life, 18, "(2 - 1) + (2 - 1)")

func test_urzas_armor_leaves_your_creatures_and_the_opponent_alone() -> void:
	put_battlefield(0, "Urza's Armor")
	var bears := put_battlefield(0, "Grizzly Bears")
	g.deal_damage(bears, TargetRef.player(1), 2)
	g.deal_damage(bears, TargetRef.card(bears), 1)
	assert_eq(g.players[1].life, 18)
	assert_eq(bears.damage, 1)


# ----------------------------------------------------------------- Whetstone --

func test_whetstone_mills_two_from_each_player_each_time() -> void:
	var stone := put_battlefield(0, "Whetstone")
	add_mana(0, Mtg.ManaColor.C, 6)
	assert_ok(g.activate_ability(0, stone, 0))
	resolve_stack()
	assert_ok(g.activate_ability(0, stone, 0))
	resolve_stack()
	assert_eq(g.players[0].library.size(), 26)
	assert_eq(g.players[1].library.size(), 26)


# -------------------------------------------------------------------- Wirecat --

func test_wirecat_attacks_while_no_enchantment_is_on_the_battlefield() -> void:
	var cat := put_battlefield(0, "Wirecat")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [cat.id]))

func test_wirecat_cant_attack_or_block_while_any_enchantment_is_out() -> void:
	var cat := put_battlefield(0, "Wirecat")
	put_battlefield(1, "Crusade")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [cat.id]))
	assert_ok(g.declare_attackers(0, []))
	advance_to_next_turn()
	var bears := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [bears.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(0, {cat.id: bears.id}))
