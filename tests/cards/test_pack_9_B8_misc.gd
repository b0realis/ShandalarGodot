extends GameTest
## Pack 9 (the Tempest block), batch B8: the Tempest one-offs in
## cards/sets/tmp/_misc.gd — Broken Fall, Choke, Dread of Night, Duplicity,
## Earthcraft, Ertai's Meddling, Fevered Convulsions, Furnace of Rath, Hand
## to Hand, Hanna's Custody, Humility (AS PRINTED: timestamped layers),
## Light of Day, Living Death, Nature's Revolt, Root Maze, Rootwater
## Matriarch, Scragnoth and Static Orb.

const CLAIMED := ["Broken Fall", "Choke", "Dread of Night", "Duplicity", "Earthcraft",
	"Ertai's Meddling", "Fevered Convulsions", "Furnace of Rath", "Hand to Hand",
	"Hanna's Custody", "Humility", "Light of Day", "Living Death", "Nature's Revolt",
	"Root Maze", "Rootwater Matriarch", "Scragnoth", "Static Orb"]

const W := Mtg.ManaColor.W
const U := Mtg.ManaColor.U
const B := Mtg.ManaColor.B
const R := Mtg.ManaColor.R
const G := Mtg.ManaColor.G

## Answers yes/no with [member yes] (recording the prompt).
class Seat extends DecisionAgent:
	var yes := true
	var asked: Array[String] = []
	func answer_yes_no(_g: MtgGame, _pid: int, prompt: String, _hint: bool) -> bool:
		asked.append(prompt)
		return yes

func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)

func _seat(pid: int) -> Seat:
	var s := Seat.new()
	g.set_agent(pid, s)
	return s

func _pt(i: CardInstance) -> Array: return [i.cur_power, i.cur_toughness]

func _priority(pid: int) -> void:
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.priority_player, pid)

## Put an Aura onto the battlefield attached to [param host] (setup).
func _enchant(pid: int, card_name: String, host: CardInstance) -> CardInstance:
	var aura := _make_instance(pid, card_name)
	g._put_on_battlefield(aura, pid, host)
	return aura

func _attack(attackers: Array) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(g.active_player, attackers))
	resolve_stack()


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


func test_the_ai_reads_a_declared_role_for_each_card_local_effect() -> void:
	var roles := {"Ertai's Meddling": &"delay_spell", "Living Death": &"living_death"}
	for card_name in roles:
		var c := CardRegistry.get_card(card_name)
		assert_eq(c.spell_effects[0].ai_role, roles[card_name], card_name)
	var matriarch := CardRegistry.get_card("Rootwater Matriarch")
	assert_eq(matriarch.activated_abilities[0].effects[0].ai_role, &"steal_while_enchanted")
	assert_true(CardRegistry.get_card("Scragnoth").cant_be_countered)


# ------------------------------------------------------------- Broken Fall --

func test_broken_fall_returns_to_hand_to_regenerate_target_creature() -> void:
	var fall := put_battlefield(0, "Broken Fall")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, fall, 0, [TargetRef.card(bear)]))
	assert_eq(fall.zone, Mtg.Zone.HAND, "returning it is the cost")
	resolve_stack()
	g.destroy(bear)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "regenerated")
	assert_true(bear.tapped)
	assert_true(fall.data.activated_abilities[0].effects[0].is_regeneration,
		"usable in the 1997 regeneration window")

func test_broken_fall_in_hand_has_nothing_to_activate() -> void:
	var fall := give_hand(0, "Broken Fall")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, fall, 0, [TargetRef.card(bear)]))


# ------------------------------------------------------------------- Choke --

func test_choke_keeps_every_island_tapped() -> void:
	put_battlefield(0, "Choke")
	var island := put_battlefield(1, "Island")
	var forest := put_battlefield(1, "Forest")
	var own := put_battlefield(0, "Island")
	for land in [island, forest, own]: g.tap_permanent(land)
	advance_to_next_turn()
	assert_true(island.tapped)
	assert_false(forest.tapped)
	advance_to_next_turn()
	assert_true(own.tapped, "its controller's Islands too")


# ---------------------------------------------------------- Dread of Night --

func test_dread_of_night_shrinks_white_creatures_only() -> void:
	var knight := put_battlefield(0, "White Knight")
	var lions := put_battlefield(0, "Savannah Lions")
	var bear := put_battlefield(0, "Grizzly Bears")
	var dread := put_battlefield(1, "Dread of Night")
	g.check_state_based_actions()
	assert_eq(_pt(knight), [1, 1])
	assert_eq(_pt(bear), [2, 2])
	assert_eq(lions.zone, Mtg.Zone.GRAVEYARD, "a 1/1 white creature dies")
	g.destroy(dread)
	assert_eq(_pt(knight), [2, 2])


# --------------------------------------------------------------- Duplicity --

func _cast_duplicity(pid: int) -> CardInstance:
	advance_to_step(Mtg.Step.MAIN1)
	var dup := give_hand(pid, "Duplicity")
	add_mana(pid, U, 2)
	add_mana(pid, G, 3)
	assert_ok(g.cast_spell(pid, dup))
	resolve_stack()
	return dup

func _top(pid: int, n: int) -> Array:
	var library := g.players[pid].library
	return library.slice(library.size() - n)

func test_duplicity_exiles_the_top_five_face_down_as_it_enters() -> void:
	var before := g.players[0].library.size()
	var five := _top(0, 5)
	_cast_duplicity(0)
	assert_eq(g.players[0].library.size(), before - 5)
	for card in five:
		assert_eq(card.zone, Mtg.Zone.EXILE)
		assert_true(card.face_down)

func test_duplicity_trades_the_hand_for_the_cards_exiled_with_it() -> void:
	var seat := _seat(0)
	var five := _top(0, 5)
	var dup := _cast_duplicity(0)
	advance_to_next_turn()                     # the opponent's turn
	var bear := give_hand(0, "Grizzly Bears")
	advance_to_next_turn()                     # our upkeep: yes
	assert_eq(seat.asked.size(), 1)
	assert_eq(bear.zone, Mtg.Zone.EXILE)
	assert_true(bear.face_down)
	for card in five:
		assert_eq(card.zone, Mtg.Zone.HAND)
	# The hand that went is now what is exiled with it.
	g.destroy(dup)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "leaving puts the linked cards into the graveyard")

func test_duplicity_declined_moves_nothing() -> void:
	var seat := _seat(0)
	seat.yes = false
	var five := _top(0, 5)
	_cast_duplicity(0)
	advance_to_next_turn()
	var bear := give_hand(0, "Grizzly Bears")
	advance_to_next_turn()
	assert_eq(bear.zone, Mtg.Zone.HAND)
	for card in five:
		assert_eq(card.zone, Mtg.Zone.EXILE)

func test_duplicity_discards_a_card_at_its_controllers_end_step() -> void:
	_cast_duplicity(0)
	give_hand(0, "Grizzly Bears")
	give_hand(0, "Hill Giant")
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 1)
	advance_to_next_turn()
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 1, "only at ITS CONTROLLER's end step")

func test_losing_control_of_duplicity_bins_the_exiled_cards() -> void:
	var five := _top(0, 5)
	var dup := _cast_duplicity(0)
	g.change_control(dup, 1)
	resolve_stack()
	for card in five:
		assert_eq(card.zone, Mtg.Zone.GRAVEYARD)
		assert_eq(g.players[0].graveyard.has(card), true, "its owner's graveyard")


# -------------------------------------------------------------- Earthcraft --

func test_earthcraft_taps_a_creature_even_a_new_one_to_untap_a_basic_land() -> void:
	var craft := put_battlefield(0, "Earthcraft")
	var forest := put_battlefield(0, "Forest")
	var bear := put_battlefield(0, "Grizzly Bears", true)
	g.tap_permanent(forest)
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, craft, 0, [TargetRef.card(forest)]))
	assert_true(bear.tapped, "tapping a creature is not {T}: summoning sickness is no bar")
	resolve_stack()
	assert_false(forest.tapped)

func test_earthcraft_refuses_a_nonbasic_land_and_needs_an_untapped_creature() -> void:
	var craft := put_battlefield(0, "Earthcraft")
	var factory := put_battlefield(0, "Mishra's Factory")
	var forest := put_battlefield(0, "Forest")
	g.tap_permanent(factory)
	g.tap_permanent(forest)
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, craft, 0, [TargetRef.card(factory)]))
	g.tap_permanent(bear)
	assert_refused(g.activate_ability(0, craft, 0, [TargetRef.card(forest)]))


# ------------------------------------------------- Ertai's Meddling, Scragnoth --

func _meddle(target: CardInstance, x: int) -> String:
	_priority(1)
	var meddle := give_hand(1, "Ertai's Meddling")
	add_mana(1, U, 1 + x)
	return g.cast_spell(1, meddle, [TargetRef.card(target)], x)

func test_ertais_meddling_delays_a_creature_spell_for_x_upkeeps() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := give_hand(0, "Grizzly Bears")
	add_mana(0, G, 2)
	assert_ok(g.cast_spell(0, bear))
	assert_ok(_meddle(bear, 2))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.EXILE)
	assert_eq(int(bear.counters.get("delay", 0)), 2)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(int(bear.counters.get("delay", 0)), 1, "one comes off at ITS CONTROLLER's upkeep")
	assert_eq(bear.zone, Mtg.Zone.EXILE)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "back on the stack, and it resolved")
	assert_eq(bear.controller_id, 0)

func test_ertais_meddling_returns_an_instant_with_its_original_target() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_ok(_meddle(bolt, 1))
	resolve_stack()
	assert_eq(g.players[1].life, 20)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(g.players[1].life, 17)
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)

func test_ertais_meddling_x_cant_be_0() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := give_hand(0, "Grizzly Bears")
	add_mana(0, G, 2)
	assert_ok(g.cast_spell(0, bear))
	assert_refused(_meddle(bear, 0), "X can't be 0")

func test_scragnoth_cant_be_countered_but_can_be_meddled_with() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var scrag := give_hand(0, "Scragnoth")
	add_mana(0, G, 5)
	assert_ok(g.cast_spell(0, scrag))
	_priority(1)
	var counter := give_hand(1, "Counterspell")
	add_mana(1, U, 2)
	assert_ok(g.cast_spell(1, counter, [TargetRef.card(scrag)]))
	resolve_stack()
	assert_eq(scrag.zone, Mtg.Zone.BATTLEFIELD, "Counterspell does nothing to it")
	assert_eq(counter.zone, Mtg.Zone.GRAVEYARD)
	var again := give_hand(0, "Scragnoth")
	add_mana(0, G, 5)
	assert_ok(g.cast_spell(0, again))
	assert_ok(_meddle(again, 1))
	resolve_stack()
	assert_eq(again.zone, Mtg.Zone.EXILE, "exiling is not countering (CR 701.5a)")

func test_scragnoth_has_protection_from_blue() -> void:
	var scrag := put_battlefield(0, "Scragnoth")
	advance_to_step(Mtg.Step.MAIN1)
	_priority(1)
	var unsummon := give_hand(1, "Unsummon")
	add_mana(1, U)
	assert_refused(g.cast_spell(1, unsummon, [TargetRef.card(scrag)]), "abilities")
	assert_eq(_pt(scrag), [3, 4])


# ----------------------------------------------------- Fevered Convulsions --

func test_fevered_convulsions_puts_a_minus_counter_on_target_creature() -> void:
	var convulsions := put_battlefield(0, "Fevered Convulsions")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, B, 3)
	assert_refused(g.activate_ability(0, convulsions, 0, [TargetRef.card(bear)]))
	add_mana(0, B)
	assert_ok(g.activate_ability(0, convulsions, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(_pt(bear), [1, 1])
	assert_eq(int(bear.counters.get("-1/-1", 0)), 1)

func test_fevered_convulsions_counters_cancel_plus_ones_only_under_modern_rules() -> void:
	var convulsions := put_battlefield(0, "Fevered Convulsions")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.add_counters(bear, "+1/+1")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, B, 4)
	assert_ok(g.activate_ability(0, convulsions, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(_pt(bear), [2, 2])
	assert_true(bear.counters.is_empty(), "modern: the two kinds annihilate (CR 704.5q)")

func test_fevered_convulsions_counters_coexist_under_the_1997_rules() -> void:
	g.rules.set_edition("fifth")
	var convulsions := put_battlefield(0, "Fevered Convulsions")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.add_counters(bear, "+1/+1")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, B, 4)
	assert_ok(g.activate_ability(0, convulsions, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(_pt(bear), [2, 2])
	assert_eq(int(bear.counters.get("+1/+1", 0)), 1)
	assert_eq(int(bear.counters.get("-1/-1", 0)), 1)


# ---------------------------------------------------------- Furnace of Rath --

func test_furnace_of_rath_doubles_all_damage() -> void:
	put_battlefield(1, "Furnace of Rath")
	var giant := put_battlefield(0, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 14)
	_attack([giant.id])
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 8, "combat damage too")

func test_two_furnaces_quadruple() -> void:
	put_battlefield(0, "Furnace of Rath")
	put_battlefield(1, "Furnace of Rath")
	var bear := put_battlefield(1, "Grizzly Bears")
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 16)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------------------- Hand to Hand --

func test_hand_to_hand_bans_instants_and_non_mana_abilities_during_combat() -> void:
	put_battlefield(1, "Hand to Hand")
	var bear := put_battlefield(0, "Grizzly Bears")
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	var elves := put_battlefield(0, "Llanowar Elves")
	var growth := give_hand(0, "Giant Growth")
	_attack([bear.id])
	add_mana(0, G)
	assert_refused(g.cast_spell(0, growth, [TargetRef.card(bear)]), "Hand to Hand")
	assert_refused(g.activate_ability(0, sorcerer, 0, [TargetRef.player(1)]), "Hand to Hand")
	assert_ok(g.tap_for_mana(0, elves))
	advance_to_step(Mtg.Step.MAIN2)
	add_mana(0, G)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(bear)]))
	resolve_stack()
	assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.player(1)]))

func test_hand_to_hand_reaches_the_beginning_of_combat_too() -> void:
	put_battlefield(1, "Hand to Hand")
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	assert_refused(g.activate_ability(0, sorcerer, 0, [TargetRef.player(1)]), "Hand to Hand")


## A seat that asks for the 1997 damage-prevention window.
class WindowSeat extends DecisionAgent:
	func wants_damage_prevention_window() -> bool:
		return true

func test_hand_to_hand_closes_the_1997_damage_prevention_window_to_abilities() -> void:
	g.rules.set_edition("fifth")
	g.rules.damage_prevention_window = true
	g.set_agent(1, WindowSeat.new())
	put_battlefield(0, "Hand to Hand")
	var guard := put_battlefield(1, "Safeguard")
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	_attack([giant.id])
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bear.id: giant.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_prevention)
	_priority(1)
	add_mana(1, W)
	add_mana(1, G, 2)
	assert_refused(g.activate_ability(1, guard, 0, [TargetRef.card(giant)]), "Hand to Hand")


# ---------------------------------------------------------- Hanna's Custody --

func test_hannas_custody_gives_every_artifact_shroud() -> void:
	var custody := put_battlefield(1, "Hanna's Custody")
	var ring := put_battlefield(1, "Sol Ring")
	var mine := put_battlefield(0, "Sol Ring")
	assert_true(ring.cur_shroud)
	assert_true(mine.cur_shroud, "every artifact, both players'")
	advance_to_step(Mtg.Step.MAIN1)
	var shatter := give_hand(0, "Shatter")
	add_mana(0, R, 2)
	assert_refused(g.cast_spell(0, shatter, [TargetRef.card(ring)]), "abilities")
	g.destroy(custody)
	assert_ok(g.cast_spell(0, shatter, [TargetRef.card(ring)]))

func test_humility_after_hannas_custody_removes_the_older_shroud() -> void:
	put_battlefield(1, "Hanna's Custody")
	var early := put_battlefield(0, "Ornithopter")
	put_battlefield(1, "Humility")
	assert_false(early.cur_shroud, "a Humility that entered later removes the older grant")

func test_hannas_custody_after_humility_still_grants_shroud() -> void:
	put_battlefield(1, "Humility")
	var late := put_battlefield(0, "Ornithopter")
	put_battlefield(1, "Hanna's Custody")
	assert_true(late.cur_shroud, "a Custody that entered after Humility grants it (CR 613.7)")
	assert_false(late.has_keyword(Mtg.Keyword.FLYING), "its own flying is gone either way")


# ----------------------------------------------------------------- Humility --

func test_humility_strips_every_creatures_abilities_and_makes_it_1_1() -> void:
	var angel := put_battlefield(0, "Serra Angel")
	var elves := put_battlefield(1, "Llanowar Elves")
	var sorcerer := put_battlefield(1, "Prodigal Sorcerer")
	var ring := put_battlefield(0, "Sol Ring")
	var humility := put_battlefield(0, "Humility")
	assert_eq(_pt(angel), [1, 1])
	assert_false(angel.has_keyword(Mtg.Keyword.FLYING))
	assert_false(angel.has_keyword(Mtg.Keyword.VIGILANCE))
	assert_true(elves.cur_mana_abilities.is_empty())
	assert_true(sorcerer.cur_activated_abilities.is_empty())
	assert_false(ring.cur_mana_abilities.is_empty(), "a noncreature keeps its abilities")
	g.destroy(humility)
	assert_eq(_pt(angel), [4, 4])
	assert_true(angel.has_keyword(Mtg.Keyword.FLYING))

func test_humility_an_aura_granted_before_it_is_lost_one_after_it_is_kept() -> void:
	var early := put_battlefield(0, "Grizzly Bears")
	_enchant(0, "Flight", early)
	assert_true(early.has_keyword(Mtg.Keyword.FLYING), "precondition")
	put_battlefield(1, "Humility")
	var late := put_battlefield(0, "Grizzly Bears")
	_enchant(0, "Flight", late)
	assert_false(early.has_keyword(Mtg.Keyword.FLYING), "granted before Humility: removed (CR 613.7)")
	assert_true(late.has_keyword(Mtg.Keyword.FLYING), "granted after Humility: kept")
	assert_eq(_pt(late), [1, 1])

func test_humility_a_spell_cast_after_it_grants_and_pumps() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Humility")
	advance_to_step(Mtg.Step.MAIN1)
	var jump := give_hand(0, "Jump")
	var growth := give_hand(0, "Giant Growth")
	add_mana(0, U)
	add_mana(0, G)
	assert_ok(g.cast_spell(0, jump, [TargetRef.card(bear)]))
	resolve_stack()
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING), "the later layer-6 grant survives")
	assert_eq(_pt(bear), [4, 4], "1/1 base, +3/+3 in layer 7c")

func test_humility_a_creature_has_no_ability_to_use_under_it() -> void:
	var queen := put_battlefield(0, "Sorceress Queen")
	var bear := put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Humility")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, queen, 0, [TargetRef.card(bear)]))

func test_humility_a_base_pt_set_before_it_loses_and_after_it_wins() -> void:
	var queen := put_battlefield(0, "Sorceress Queen")
	var bear := put_battlefield(1, "Grizzly Bears")
	var factory := put_battlefield(0, "Mishra's Factory")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, queen, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(_pt(bear), [0, 2], "precondition")
	put_battlefield(1, "Humility")
	assert_eq(_pt(bear), [1, 1], "Humility's 1/1 is the later layer-7b effect")
	add_mana(0, G)
	assert_ok(g.activate_ability(0, factory, 0))
	resolve_stack()
	assert_true(factory.is_creature())
	assert_eq(_pt(factory), [2, 2], "an animation after Humility is the later 7b effect")
	assert_true(factory.cur_mana_abilities.is_empty(), "but as a creature it has no abilities")

func test_humility_and_natures_revolt_settle_the_lands_by_timestamp() -> void:
	var forest := put_battlefield(0, "Forest")
	var revolt := put_battlefield(1, "Nature's Revolt")
	var humility := put_battlefield(1, "Humility")
	assert_true(forest.is_creature())
	assert_eq(_pt(forest), [1, 1], "Humility is the later 7b effect")
	assert_true(forest.cur_mana_abilities.is_empty(), "a creature land loses its mana ability")
	g.destroy(revolt)
	assert_false(forest.is_creature())
	assert_false(forest.cur_mana_abilities.is_empty(), "a land again, not a creature: untouched")
	put_battlefield(1, "Nature's Revolt")
	assert_eq(_pt(forest), [2, 2], "now the Revolt is the later 7b effect")
	g.destroy(humility)
	assert_eq(_pt(forest), [2, 2])
	assert_false(forest.cur_mana_abilities.is_empty())

func test_humility_under_the_1997_rules_keeps_the_same_clock() -> void:
	g.rules.set_edition("fifth")
	var early := put_battlefield(0, "Grizzly Bears")
	_enchant(0, "Flight", early)
	_enchant(0, "Holy Strength", early)
	put_battlefield(1, "Humility")
	assert_false(early.has_keyword(Mtg.Keyword.FLYING))
	assert_eq(_pt(early), [2, 3], "1/1, then the Aura's +1/+2 in layer 7c")


# ------------------------------------------------------------- Light of Day --

func test_light_of_day_black_creatures_cant_attack_or_block() -> void:
	put_battlefield(1, "Light of Day")
	var zombies := put_battlefield(0, "Scathe Zombies")
	var bear := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Scathe Zombies")
	var wall := put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [zombies.id]), "can't attack")
	assert_ok(g.declare_attackers(0, [bear.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {theirs.id: bear.id}))
	assert_ok(g.declare_blockers(1, {wall.id: bear.id}))


# ------------------------------------------------------------- Living Death --

func test_living_death_swaps_every_graveyard_for_every_battlefield() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	g.destroy(giant)
	var angel := put_battlefield(1, "Serra Angel")
	g.destroy(angel)
	var bear := put_battlefield(0, "Grizzly Bears")
	var elves := put_battlefield(1, "Llanowar Elves")
	var ring := put_battlefield(0, "Sol Ring")
	advance_to_step(Mtg.Step.MAIN1)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	var death := give_hand(0, "Living Death")
	add_mana(0, B, 5)
	assert_ok(g.cast_spell(0, death))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(giant.controller_id, 0)
	assert_eq(angel.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(angel.controller_id, 1, "each player's own cards come back under them")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "sacrificed, and not brought back")
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD, "only creature cards are exiled")
	assert_eq(ring.zone, Mtg.Zone.BATTLEFIELD, "only creatures are sacrificed")
	assert_eq(death.zone, Mtg.Zone.GRAVEYARD)

func test_living_death_with_empty_graveyards_is_a_wrath() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var elves := put_battlefield(1, "Llanowar Elves")
	advance_to_step(Mtg.Step.MAIN1)
	var death := give_hand(0, "Living Death")
	add_mana(0, B, 5)
	assert_ok(g.cast_spell(0, death))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)
	for p in g.players:
		for inst in p.battlefield:
			assert_false(inst.is_creature(), "nothing came back: they were sacrificed after the exile")


# ----------------------------------------------------------- Nature's Revolt --

func test_natures_revolt_makes_every_land_a_2_2_creature_land() -> void:
	var forest := put_battlefield(0, "Forest")
	var island := put_battlefield(1, "Island")
	var revolt := put_battlefield(0, "Nature's Revolt")
	for land in [forest, island]:
		assert_true(land.is_creature())
		assert_true(land.is_land())
		assert_eq(_pt(land), [2, 2])
	assert_false(forest.cur_mana_abilities.is_empty(), "still taps for mana")
	g.destroy(revolt)
	assert_false(forest.is_creature())


func test_natures_revolt_lands_are_summoning_sick_the_turn_they_arrive() -> void:
	var old := put_battlefield(0, "Forest")
	put_battlefield(0, "Nature's Revolt")
	advance_to_step(Mtg.Step.MAIN1)
	var fresh := give_hand(0, "Forest")
	assert_ok(g.play_land(0, fresh))
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [fresh.id]), "summoning sickness")
	assert_ok(g.declare_attackers(0, [old.id]))


# --------------------------------------------------------------- Root Maze --

func test_root_maze_artifacts_and_lands_enter_tapped() -> void:
	put_battlefield(1, "Root Maze")
	advance_to_step(Mtg.Step.MAIN1)
	var forest := give_hand(0, "Forest")
	assert_ok(g.play_land(0, forest))
	assert_true(forest.tapped)
	var ring := give_hand(0, "Sol Ring")
	add_mana(0, G)
	assert_ok(g.cast_spell(0, ring))
	resolve_stack()
	assert_true(ring.tapped)
	var bear := give_hand(0, "Grizzly Bears")
	add_mana(0, G, 2)
	assert_ok(g.cast_spell(0, bear))
	resolve_stack()
	assert_false(bear.tapped, "creatures are untouched")


# ------------------------------------------------------- Rootwater Matriarch --

func test_rootwater_matriarch_steals_an_enchanted_creature_while_it_stays_enchanted() -> void:
	var matriarch := put_battlefield(0, "Rootwater Matriarch")
	var bear := put_battlefield(1, "Grizzly Bears")
	var aura := _enchant(1, "Holy Strength", bear)
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, matriarch, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.controller_id, 0)
	g.destroy(matriarch)
	assert_eq(bear.controller_id, 0, "the duration follows the victim, not the Matriarch")
	g.destroy(aura)
	assert_eq(bear.controller_id, 1, "no longer enchanted: control returns")

func test_rootwater_matriarch_on_an_unenchanted_creature_does_nothing() -> void:
	var matriarch := put_battlefield(0, "Rootwater Matriarch")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, matriarch, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.controller_id, 1)
	_enchant(1, "Holy Strength", bear)
	assert_eq(bear.controller_id, 1, "the duration was already over")

func test_rootwater_matriarch_needs_to_tap() -> void:
	var matriarch := put_battlefield(0, "Rootwater Matriarch", true)
	var bear := put_battlefield(1, "Grizzly Bears")
	_enchant(1, "Holy Strength", bear)
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, matriarch, 0, [TargetRef.card(bear)]), "summoning")


# ---------------------------------------------------------------- Static Orb --

func _tapped(pid: int, names: Array) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for card_name in names:
		var inst := put_battlefield(pid, String(card_name))
		g.tap_permanent(inst)
		out.append(inst)
	return out

func _untapped(cards: Array[CardInstance]) -> int:
	var n := 0
	for inst in cards:
		if not inst.tapped: n += 1
	return n

func test_static_orb_lets_each_player_untap_two_permanents() -> void:
	put_battlefield(0, "Static Orb")
	var mine := _tapped(0, ["Forest", "Island", "Grizzly Bears", "Hill Giant"])
	var theirs := _tapped(1, ["Forest", "Mountain", "Grizzly Bears"])
	advance_to_next_turn()
	assert_eq(_untapped(theirs), 2)
	advance_to_next_turn()
	assert_eq(_untapped(mine), 2)

func test_a_tapped_static_orb_caps_nothing() -> void:
	var orb := put_battlefield(0, "Static Orb")
	g.tap_permanent(orb)
	var theirs := _tapped(1, ["Forest", "Mountain", "Grizzly Bears"])
	advance_to_next_turn()
	assert_eq(_untapped(theirs), 3)
