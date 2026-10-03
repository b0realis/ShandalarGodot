extends GameTest
## Pack 8, batch B10: the Weatherlight instants and sorceries
## (cards/sets/wth/_spells.gd). Abeyance rides the E4 floating bans,
## Urborg Justice the E10 owner-keyed death tracker and Gaea's Blessing the
## E7 "put into your graveyard from your library" event.

const DONE := ["Argivian Find", "Argivian Restoration", "Relearn", "Debt of Loyalty", "Gerrard's Wisdom",
	"Blossoming Wreath", "Guided Strike", "Fit of Rage", "Disrupt", "Paradigm Shift", "Agonizing Memories",
	"Buried Alive", "Fatal Blow", "Shattered Crypt", "Boiling Blood", "Cone of Flame", "Thunderbolt",
	"Nature's Resurgence", "Vitalize", "Abeyance", "Urborg Justice", "Gaea's Blessing"]


## Answers every yes/no with [member says]; picks cards by name in the
## order of [member picks], else the first candidate (or null when
## [member stop] — "fail to find").
class Seat extends DecisionAgent:
	var says := true
	var picks: Array[String] = []
	var stop := false
	func answer_yes_no(_g: MtgGame, _pid: int, _prompt: String, _hint: bool) -> bool:
		return says
	func answer_card(_g: MtgGame, _pid: int, candidates: Array[CardInstance], _prompt: String) -> CardInstance:
		if stop: return null
		while not picks.is_empty():
			var want: String = picks.pop_front()
			for c in candidates:
				if c.data.card_name == want: return c
		return null if candidates.is_empty() else candidates[0]


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func _pending(name: String) -> bool:
	var c := CardRegistry.get_card(name)
	return c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"

func cast(name: String, targets: Array = [], pid := 0, x := 0, mode := 0) -> CardInstance:
	var c := give_hand(pid, name)
	for color in Mtg.WUBRG: add_mana(pid, color, 20)
	if g.priority_player != pid: assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.cast_spell(pid, c, targets, x, mode))
	resolve_stack()
	return c

func grave(pid: int, name: String) -> CardInstance:
	var inst := _make_instance(pid, name)
	g.put_into_graveyard(inst)
	return inst

func library_card(pid: int, name: String) -> CardInstance:
	var inst := _make_instance(pid, name)
	inst.zone = Mtg.Zone.LIBRARY
	g.players[pid].library.push_front(inst)
	return inst


func test_batch_spells_are_all_claimed() -> void:
	for name in DONE: assert_false(_pending(name), name)


# ------------------------------------------------------------- Abeyance --

func test_abeyance_stops_instants_sorceries_and_non_mana_abilities_this_turn() -> void:
	var sorcerer := put_battlefield(1, "Prodigal Sorcerer")
	var elves := put_battlefield(1, "Llanowar Elves")
	var forest := put_battlefield(1, "Forest")
	var bolt := give_hand(1, "Lightning Bolt")
	var bear := give_hand(1, "Grizzly Bears")
	advance_to_next_turn()                       # P1's main phase
	assert_ok(g.pass_priority(1))
	var hand := g.players[0].hand.size()
	cast("Abeyance", [TargetRef.player(1)], 0)
	assert_eq(g.players[0].hand.size(), hand + 1, "drew a card (the helper put Abeyance in hand first)")
	add_mana(1, Mtg.ManaColor.R, 1)
	assert_refused(g.cast_spell(1, bolt, [TargetRef.player(0)]), "Abeyance")
	assert_refused(g.activate_ability(1, sorcerer, 0, [TargetRef.player(0)]), "Abeyance")
	assert_ok(g.tap_for_mana(1, elves))
	assert_ok(g.tap_for_mana(1, forest))
	assert_ok(g.cast_spell(1, bear, []))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "creature spells are not instants or sorceries")
	var mine := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(1))
	assert_ok(g.cast_spell(0, mine, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 17, "the caster is untouched")
	advance_to_next_turn()
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 17, "the ban ended with the turn")


# ------------------------------------------------------- Urborg Justice --

func test_urborg_justice_counts_creatures_put_into_your_graveyard() -> void:
	g.destroy(put_battlefield(0, "Grizzly Bears"))
	g.destroy(put_battlefield(0, "Hill Giant"))
	g.destroy(put_battlefield(1, "Grizzly Bears"))      # their graveyard: not counted
	var borrowed := put_battlefield(1, "Llanowar Elves")
	g.change_control(borrowed, 0)
	g.destroy(borrowed)                                   # owner-keyed: THEIR graveyard
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Hill Giant")
	var c := put_battlefield(1, "Black Knight")
	var justice := give_hand(0, "Urborg Justice")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_refused(g.cast_spell(0, justice, [TargetRef.player(0)]))
	assert_ok(g.cast_spell(0, justice, [TargetRef.player(1)]))
	resolve_stack()
	var gone := 0
	for i in [a, b, c]:
		if i.zone == Mtg.Zone.GRAVEYARD: gone += 1
	assert_eq(gone, 2, "two of yours died this turn: two sacrifices")


func test_urborg_justice_with_no_deaths_does_nothing_and_resets_each_turn() -> void:
	g.destroy(put_battlefield(0, "Grizzly Bears"))
	advance_to_next_turn()
	advance_to_next_turn()
	var bear := put_battlefield(1, "Grizzly Bears")
	cast("Urborg Justice", [TargetRef.player(1)])
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------------- Gaea's Blessing --

func test_gaeas_blessing_shuffles_up_to_three_cards_back_and_draws() -> void:
	var a := grave(0, "Grizzly Bears")
	var b := grave(0, "Lightning Bolt")
	var theirs := grave(1, "Hill Giant")
	var blessing := give_hand(0, "Gaea's Blessing")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_refused(g.cast_spell(0, blessing, [TargetRef.player(0), TargetRef.card(a), TargetRef.card(theirs)]))
	var hand := g.players[0].hand.size()
	assert_ok(g.cast_spell(0, blessing, [TargetRef.player(0), TargetRef.card(a), TargetRef.card(b)]))
	resolve_stack()
	assert_eq(a.zone, Mtg.Zone.LIBRARY)
	assert_eq(b.zone, Mtg.Zone.LIBRARY)
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].hand.size(), hand - 1 + 1, "cast one, drew one")


func test_gaeas_blessing_can_aim_at_the_opponents_graveyard_or_at_nothing() -> void:
	var theirs := grave(1, "Hill Giant")
	cast("Gaea's Blessing", [TargetRef.player(1), TargetRef.card(theirs)])
	assert_eq(theirs.zone, Mtg.Zone.LIBRARY)
	var hand := g.players[0].hand.size()
	cast("Gaea's Blessing", [TargetRef.player(1)])
	assert_eq(g.players[0].hand.size(), hand + 1, "zero cards is legal; it still draws")


func test_gaeas_blessing_milled_shuffles_your_graveyard_in() -> void:
	var a := grave(0, "Grizzly Bears")
	var b := grave(0, "Lightning Bolt")
	var blessing := _make_instance(0, "Gaea's Blessing")
	blessing.zone = Mtg.Zone.LIBRARY
	g.players[0].library.append(blessing)
	g.mill(0, 1)
	assert_eq(blessing.zone, Mtg.Zone.GRAVEYARD)
	assert_false(g.stack.is_empty(), "a trigger from the graveyard")
	resolve_stack()
	for i in [a, b, blessing]: assert_eq(i.zone, Mtg.Zone.LIBRARY, i.data.card_name)
	assert_true(g.players[0].graveyard.is_empty())


func test_gaeas_blessing_discarded_or_resolved_does_not_trigger() -> void:
	var blessing := give_hand(0, "Gaea's Blessing")
	g.discard_cards(0, [blessing])
	assert_true(g.stack.is_empty(), "from the hand, not the library")
	var cast_one := cast("Gaea's Blessing", [TargetRef.player(0)])
	assert_eq(cast_one.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.stack.is_empty())


func test_argivian_find_takes_back_an_artifact_or_enchantment_only() -> void:
	var bear := grave(0, "Grizzly Bears")
	var ring := grave(0, "Sol Ring")
	var find := give_hand(0, "Argivian Find")
	add_mana(0, Mtg.ManaColor.W)
	assert_refused(g.cast_spell(0, find, [TargetRef.card(bear)]))
	assert_ok(g.cast_spell(0, find, [TargetRef.card(ring)]))
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.HAND)
	var theirs := grave(1, "Holy Strength")
	var again := give_hand(0, "Argivian Find")
	add_mana(0, Mtg.ManaColor.W)
	assert_refused(g.cast_spell(0, again, [TargetRef.card(theirs)]), "owner")


func test_argivian_restoration_returns_an_artifact_to_the_battlefield() -> void:
	var ring := grave(0, "Sol Ring")
	cast("Argivian Restoration", [TargetRef.card(ring)])
	assert_eq(ring.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(ring.controller_id, 0)


func test_relearn_returns_an_instant_or_sorcery() -> void:
	var bolt := grave(0, "Lightning Bolt")
	var bear := grave(0, "Grizzly Bears")
	var relearn := give_hand(0, "Relearn")
	add_mana(0, Mtg.ManaColor.U, 3)
	assert_refused(g.cast_spell(0, relearn, [TargetRef.card(bear)]))
	assert_ok(g.cast_spell(0, relearn, [TargetRef.card(bolt)]))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.HAND)


func test_debt_of_loyalty_steals_the_creature_it_regenerates() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	cast("Debt of Loyalty", [TargetRef.card(giant)])
	assert_eq(giant.regeneration_shields, 1)
	assert_eq(giant.controller_id, 1, "nothing changes until it regenerates")
	g.destroy(giant)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(giant.controller_id, 0, "the control change is part of the regeneration, not a trigger")
	assert_true(g.stack.is_empty())


func test_debt_of_loyalty_shield_unused_steals_nothing() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	cast("Debt of Loyalty", [TargetRef.card(giant)])
	advance_to_next_turn()
	assert_eq(giant.regeneration_shields, 0)
	g.destroy(giant)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)


func test_debt_of_loyalty_owner_spends_their_own_shield_first() -> void:
	var boa := put_battlefield(1, "River Boa")
	add_mana(1, Mtg.ManaColor.G)
	cast("Debt of Loyalty", [TargetRef.card(boa)])
	if g.priority_player != 1: assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.activate_ability(1, boa, 0, []))
	resolve_stack()
	assert_eq(boa.regeneration_shields, 2)
	g.destroy(boa)
	assert_eq(boa.controller_id, 1, "the Boa's controller picked its own shield (CR 616.1)")
	g.destroy(boa)
	assert_eq(boa.controller_id, 0, "the Debt shield was the last one")


func test_gerrards_wisdom_counts_the_hand_on_resolution() -> void:
	for n in 3: give_hand(0, "Forest")
	cast("Gerrard's Wisdom")
	assert_eq(g.players[0].life, 26)


func test_blossoming_wreath_counts_creature_cards_only() -> void:
	grave(0, "Grizzly Bears")
	grave(0, "Hill Giant")
	grave(0, "Lightning Bolt")
	grave(1, "Grizzly Bears")
	cast("Blossoming Wreath")
	assert_eq(g.players[0].life, 22)


func test_guided_strike_and_fit_of_rage_pump_with_first_strike() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var before := g.players[0].hand.size()
	cast("Guided Strike", [TargetRef.card(bear)])
	assert_eq([bear.cur_power, bear.cur_toughness], [3, 2])
	assert_true(bear.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_eq(g.players[0].hand.size(), before + 1, "drew a card")
	cast("Fit of Rage", [TargetRef.card(bear)])
	assert_eq([bear.cur_power, bear.cur_toughness], [6, 5])
	advance_to_next_turn()
	assert_false(bear.has_keyword(Mtg.Keyword.FIRST_STRIKE))


func test_guided_strike_fizzles_entirely_without_its_target() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var strike := give_hand(0, "Guided Strike")
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_ok(g.cast_spell(0, strike, [TargetRef.card(bear)]))
	g.destroy(bear)
	var before := g.players[0].hand.size()
	resolve_stack()
	assert_eq(g.players[0].hand.size(), before, "no draw from a fizzled spell (CR 608.2b)")


func test_disrupt_taxes_only_instants_and_sorceries() -> void:
	var bear := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, bear, []))
	assert_ok(g.pass_priority(0))
	var disrupt := give_hand(1, "Disrupt")
	add_mana(1, Mtg.ManaColor.U)
	assert_refused(g.cast_spell(1, disrupt, [TargetRef.card(bear)]))
	resolve_stack()
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_ok(g.pass_priority(0))
	var hand := g.players[1].hand.size()
	assert_ok(g.cast_spell(1, disrupt, [TargetRef.card(bolt)]))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 20, "no {1} to pay: countered")
	assert_eq(g.players[1].hand.size(), hand, "Disrupt left the hand and drew one")


func test_paradigm_shift_exiles_the_library_and_shuffles_the_graveyard_in() -> void:
	grave(0, "Grizzly Bears")
	grave(0, "Lightning Bolt")
	var library := g.players[0].library.duplicate()
	var shift := cast("Paradigm Shift")
	for card in library: assert_eq(card.zone, Mtg.Zone.EXILE)
	assert_eq(g.players[0].library.size(), 2, "the graveyard went in; the Shift itself was still on the stack")
	assert_eq(g.players[0].graveyard, [shift])


func test_agonizing_memories_puts_two_chosen_cards_on_top() -> void:
	var seat := Seat.new()
	seat.picks = ["Hill Giant", "Lightning Bolt"]
	g.agents[0] = seat
	var bolt := give_hand(1, "Lightning Bolt")
	var giant := give_hand(1, "Hill Giant")
	var bear := give_hand(1, "Grizzly Bears")
	cast("Agonizing Memories", [TargetRef.player(1)])
	assert_eq(bear.zone, Mtg.Zone.HAND)
	assert_eq(g.players[1].library.back(), bolt, "the second card chosen ends on top")
	assert_eq(g.players[1].library[g.players[1].library.size() - 2], giant)


func test_agonizing_memories_with_one_card_moves_it() -> void:
	var bolt := give_hand(1, "Lightning Bolt")
	cast("Agonizing Memories", [TargetRef.player(1)])
	assert_eq(g.players[1].library.back(), bolt)


func test_buried_alive_buries_up_to_three_creature_cards() -> void:
	var a := library_card(0, "Grizzly Bears")
	var b := library_card(0, "Hill Giant")
	var c := library_card(0, "Black Knight")
	var d := library_card(0, "Llanowar Elves")
	var bolt := library_card(0, "Lightning Bolt")
	cast("Buried Alive")
	var buried := 0
	for card in [a, b, c, d]:
		if card.zone == Mtg.Zone.GRAVEYARD: buried += 1
	assert_eq(buried, 3)
	assert_eq(bolt.zone, Mtg.Zone.LIBRARY)


func test_buried_alive_may_find_fewer() -> void:
	var seat := Seat.new()
	seat.stop = true
	g.agents[0] = seat
	var a := library_card(0, "Grizzly Bears")
	cast("Buried Alive")
	assert_eq(a.zone, Mtg.Zone.LIBRARY)


func test_fatal_blow_needs_a_damaged_creature_and_beats_regeneration() -> void:
	var boa := put_battlefield(1, "River Boa")
	var blow := give_hand(0, "Fatal Blow")
	add_mana(0, Mtg.ManaColor.B)
	assert_refused(g.cast_spell(0, blow, [TargetRef.card(boa)]), "damaged")
	boa.regeneration_shields = 1
	g.deal_damage(put_battlefield(0, "Grizzly Bears"), TargetRef.card(boa), 0 + 1)
	assert_ok(g.cast_spell(0, blow, [TargetRef.card(boa)]))
	resolve_stack()
	assert_eq(boa.zone, Mtg.Zone.GRAVEYARD)


func test_shattered_crypt_returns_x_creatures_and_costs_x_life() -> void:
	var bear := grave(0, "Grizzly Bears")
	var giant := grave(0, "Hill Giant")
	grave(0, "Lightning Bolt")
	cast("Shattered Crypt", [TargetRef.card(bear), TargetRef.card(giant)], 0, 2)
	assert_eq(bear.zone, Mtg.Zone.HAND)
	assert_eq(giant.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].life, 18)
	cast("Shattered Crypt", [], 0, 0)
	assert_eq(g.players[0].life, 18, "X = 0 loses nothing")


func test_boiling_blood_forces_the_attack_and_draws() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var before := g.players[0].hand.size()
	advance_to_next_turn()
	assert_ok(g.pass_priority(1))
	cast("Boiling Blood", [TargetRef.card(bear)], 0)
	assert_eq(g.players[0].hand.size(), before + 1)
	assert_true(bear.must_attack_this_turn)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(1, []))
	assert_ok(g.declare_attackers(1, [bear.id]))


func test_cone_of_flame_needs_three_different_targets() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var cone := give_hand(0, "Cone of Flame")
	for color in Mtg.WUBRG: add_mana(0, color, 5)
	assert_refused(g.cast_spell(0, cone, [TargetRef.card(bear), TargetRef.card(bear), TargetRef.player(1)]))
	assert_ok(g.cast_spell(0, cone, [TargetRef.player(1), TargetRef.card(bear), TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(g.players[1].life, 19)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)


func test_thunderbolt_modes() -> void:
	var drake := put_battlefield(1, "Spitting Drake")
	var bear := put_battlefield(1, "Grizzly Bears")
	cast("Thunderbolt", [TargetRef.player(1)], 0, 0, 0)
	assert_eq(g.players[1].life, 17)
	var bolt := give_hand(0, "Thunderbolt")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_refused(g.cast_spell(0, bolt, [TargetRef.card(bear)], 0, 1))
	assert_refused(g.cast_spell(0, bolt, [TargetRef.card(drake)], 0, 0))
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(drake)], 0, 1))
	resolve_stack()
	assert_eq(drake.zone, Mtg.Zone.GRAVEYARD)
	var data := CardRegistry.get_card("Thunderbolt")
	assert_eq(int(data.ai_mode_picker.call(g, 0)), 0, "no flyer left: the player mode")


func test_natures_resurgence_draws_per_creature_card_for_each_player() -> void:
	grave(0, "Grizzly Bears")
	grave(0, "Hill Giant")
	grave(1, "Grizzly Bears")
	grave(1, "Lightning Bolt")
	var mine := g.players[0].hand.size()
	var theirs := g.players[1].hand.size()
	cast("Nature's Resurgence")
	assert_eq(g.players[0].hand.size(), mine + 2)
	assert_eq(g.players[1].hand.size(), theirs + 1)


func test_vitalize_untaps_only_your_creatures() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var land := put_battlefield(0, "Forest")
	var theirs := put_battlefield(1, "Grizzly Bears")
	for i in [bear, land, theirs]: g.tap_permanent(i)
	cast("Vitalize")
	assert_false(bear.tapped)
	assert_true(land.tapped)
	assert_true(theirs.tapped)
