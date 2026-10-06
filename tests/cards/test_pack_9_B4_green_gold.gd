extends GameTest
## Pack 9 (the Tempest block), batch B4: the green and gold Tempest
## creatures of cards/sets/tmp/_creatures.gd — Crazed Armodon, Eladamri,
## Heartwood Giant, Krakilin, Pincher Beetles, Rootwalla, Seeker of
## Skybreak, Skyshroud Ranger, Skyshroud Troll, Dracoplasm, Ranger en-Vec,
## Selenia, Vhati il-Dal. Each test drives the card through the public API
## and pins the clause that makes it that card, with its refused case.

const CLAIMED := ["Crazed Armodon", "Eladamri, Lord of Leaves", "Heartwood Giant",
	"Krakilin", "Pincher Beetles", "Rootwalla", "Seeker of Skybreak", "Skyshroud Ranger",
	"Skyshroud Troll", "Dracoplasm", "Ranger en-Vec", "Selenia, Dark Angel", "Vhati il-Dal"]


## FIFO answers; an empty queue falls back to the caller's hint (and a card
## pick to the first candidate).
class Scripted extends DecisionAgent:
	var options: Array = []
	var picks: Array = []
	var window := false

	func wants_damage_prevention_window() -> bool:
		return window

	func answer_option(_g: MtgGame, _p: int, _prompt: String, _labels: Array[String], hint: int) -> int:
		return int(options.pop_front()) if not options.is_empty() else hint

	func answer_card(_g: MtgGame, _p: int, candidates: Array[CardInstance], _prompt: String) -> CardInstance:
		if not picks.is_empty():
			var want: Variant = picks.pop_front()
			if want == null:
				return null
			for c in candidates:
				if c == want:
					return c
		return null if candidates.is_empty() else candidates[0]


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func seat(pid: int) -> Scripted:
	var a := Scripted.new()
	g.set_agent(pid, a)
	return a

## Exactly the mana [param card]'s cost asks for (X paid as colourless).
func fund(pid: int, card: CardInstance, x := 0) -> void:
	var cost := card.data.cost
	for c in cost.colored:
		add_mana(pid, c, int(cost.colored[c]))
	var generic := cost.generic + x * cost.x_count
	if generic > 0:
		add_mana(pid, Mtg.ManaColor.C, generic)

func cast(card_name: String, targets: Array = [], pid := 0, x := 0) -> CardInstance:
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	var card := give_hand(pid, card_name)
	fund(pid, card, x)
	assert_ok(g.cast_spell(pid, card, targets, x))
	resolve_stack()
	return card

## P0 attacks with [param attacker]; P1 is to declare blockers.
func _attack(attacker: CardInstance) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_true(g.awaiting_blockers)


func test_claimed_cards_are_no_longer_pending() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending", card_name)


# --- Crazed Armodon ---------------------------------------------------------

func test_crazed_armodon_rampages_once_and_dies_at_the_end_step() -> void:
	var armodon := put_battlefield(0, "Crazed Armodon")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.activate_ability(0, armodon, 0))
	assert_refused(g.activate_ability(0, armodon, 0), "once")
	resolve_stack()
	assert_eq([armodon.cur_power, armodon.cur_toughness], [6, 3])
	assert_true(armodon.has_keyword(Mtg.Keyword.TRAMPLE))
	assert_true(g.is_doomed_at_end_step(armodon))
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(armodon.zone, Mtg.Zone.BATTLEFIELD)
	advance_to_next_turn()
	assert_eq(armodon.zone, Mtg.Zone.GRAVEYARD, "destroyed at the beginning of the end step")

func test_crazed_armodon_untouched_lives_on() -> void:
	var armodon := put_battlefield(0, "Crazed Armodon")
	advance_to_next_turn()
	assert_eq(armodon.zone, Mtg.Zone.BATTLEFIELD)


# --- Eladamri, Lord of Leaves -----------------------------------------------

func test_eladamri_hides_and_forestwalks_every_other_elf() -> void:
	var lord := put_battlefield(0, "Eladamri, Lord of Leaves")
	var ours := put_battlefield(0, "Llanowar Elves")
	var theirs := put_battlefield(1, "Llanowar Elves")
	var bear := put_battlefield(0, "Grizzly Bears")
	for elf in [ours, theirs]:
		assert_true(elf.cur_shroud)
		assert_true(elf.cur_landwalk.has("forest"))
	assert_false(lord.cur_shroud, "other Elves")
	assert_false(lord.cur_landwalk.has("forest"))
	assert_false(bear.cur_shroud)
	assert_true((lord.cur_supertypes & Mtg.Supertype.LEGENDARY) != 0)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, bolt, [TargetRef.card(theirs)]))
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(lord)]))
	resolve_stack()
	assert_eq(lord.zone, Mtg.Zone.GRAVEYARD)
	assert_false(ours.cur_shroud, "the grant ends with Eladamri")


# --- Heartwood Giant --------------------------------------------------------

func test_heartwood_giant_throws_a_forest_at_a_player() -> void:
	var giant := put_battlefield(0, "Heartwood Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_refused(g.activate_ability(0, giant, 0, [TargetRef.player(1)]), "Forest")
	var forest := put_battlefield(0, "Forest")
	assert_refused(g.activate_ability(0, giant, 0, [TargetRef.card(bear)]))
	assert_ok(g.activate_ability(0, giant, 0, [TargetRef.player(1)]))
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)
	assert_true(giant.tapped)
	resolve_stack()
	assert_eq(g.players[1].life, 18)


# --- Krakilin ---------------------------------------------------------------

func test_krakilin_enters_with_x_counters_and_regenerates() -> void:
	var krakilin := cast("Krakilin", [], 0, 3)
	assert_eq(int(krakilin.counters.get("+1/+1", 0)), 3)
	assert_eq([krakilin.cur_power, krakilin.cur_toughness], [3, 3])
	add_mana(0, Mtg.ManaColor.G)
	assert_refused(g.activate_ability(0, krakilin, 0), "mana")
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, krakilin, 0))
	resolve_stack()
	g.destroy(krakilin)
	assert_eq(krakilin.zone, Mtg.Zone.BATTLEFIELD)

func test_krakilin_for_x_zero_dies() -> void:
	var krakilin := cast("Krakilin", [], 0, 0)
	assert_eq(krakilin.zone, Mtg.Zone.GRAVEYARD)


# --- Pincher Beetles --------------------------------------------------------

func test_pincher_beetles_have_shroud_against_both_sides() -> void:
	var beetles := put_battlefield(0, "Pincher Beetles")
	assert_true(beetles.cur_shroud)
	var growth := give_hand(0, "Giant Growth")
	add_mana(0, Mtg.ManaColor.G)
	assert_refused(g.cast_spell(0, growth, [TargetRef.card(beetles)]))
	var bolt := give_hand(1, "Lightning Bolt")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(1, bolt, [TargetRef.card(beetles)]))


# --- Rootwalla --------------------------------------------------------------

func test_rootwalla_pumps_only_once_a_turn() -> void:
	var walla := put_battlefield(0, "Rootwalla")
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, walla, 0))
	assert_refused(g.activate_ability(0, walla, 0), "once")
	resolve_stack()
	assert_eq([walla.cur_power, walla.cur_toughness], [4, 4])
	advance_to_next_turn()
	advance_to_next_turn()
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, walla, 0))


# --- Seeker of Skybreak -----------------------------------------------------

func test_seeker_of_skybreak_untaps_a_creature() -> void:
	var seeker := put_battlefield(0, "Seeker of Skybreak")
	var sick := put_battlefield(0, "Seeker of Skybreak", true)
	var bear := put_battlefield(0, "Grizzly Bears")
	g.tap_permanent(bear)
	assert_refused(g.activate_ability(0, sick, 0, [TargetRef.card(bear)]))
	assert_ok(g.activate_ability(0, seeker, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_false(bear.tapped)
	assert_true(seeker.tapped)


# --- Skyshroud Ranger -------------------------------------------------------

func test_skyshroud_ranger_puts_a_land_without_using_the_land_drop() -> void:
	var ranger := put_battlefield(0, "Skyshroud Ranger")
	var forest := give_hand(0, "Forest")
	var mountain := give_hand(0, "Mountain")
	var p0 := seat(0)
	p0.picks = [forest]
	assert_ok(g.activate_ability(0, ranger, 0))
	resolve_stack()
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
	assert_ok(g.play_land(0, mountain))
	assert_eq(mountain.zone, Mtg.Zone.BATTLEFIELD, "the turn's land drop was still there")

func test_skyshroud_ranger_may_decline() -> void:
	var ranger := put_battlefield(0, "Skyshroud Ranger")
	var forest := give_hand(0, "Forest")
	var p0 := seat(0)
	p0.picks = [null]
	assert_ok(g.activate_ability(0, ranger, 0))
	resolve_stack()
	assert_eq(forest.zone, Mtg.Zone.HAND)

func test_skyshroud_ranger_only_as_a_sorcery() -> void:
	var ranger := put_battlefield(0, "Skyshroud Ranger")
	give_hand(0, "Forest")
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	assert_ok(g.pass_priority(1))
	assert_refused(g.activate_ability(0, ranger, 0), "sorcery")


# --- Skyshroud Troll / Ranger en-Vec ----------------------------------------

func test_skyshroud_troll_and_ranger_en_vec_regenerate() -> void:
	var troll := put_battlefield(0, "Skyshroud Troll")
	var ranger := put_battlefield(0, "Ranger en-Vec")
	assert_true(ranger.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	add_mana(0, Mtg.ManaColor.G)
	assert_refused(g.activate_ability(0, troll, 0), "mana")
	assert_ok(g.activate_ability(0, ranger, 0))
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, troll, 0))
	resolve_stack()
	g.destroy(troll)
	g.destroy(ranger)
	assert_eq(troll.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(ranger.zone, Mtg.Zone.BATTLEFIELD)


## The 1997 regeneration step (fifth): the lethal damage has landed and the
## Troll regenerates in the window that opens for it.
func test_skyshroud_troll_regenerates_in_the_1997_regeneration_window() -> void:
	g.rules.set_preset("fifth")
	g.rules.damage_prevention_window = true
	var p1 := seat(1)
	p1.window = true
	var wurm := put_battlefield(0, "Craw Wurm")
	var troll := put_battlefield(1, "Skyshroud Troll")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {troll.id: wurm.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_regeneration, "about to go to the graveyard")
	assert_true(troll.damage >= troll.cur_toughness)
	assert_ok(g.end_damage_prevention(0))
	add_mana(1, Mtg.ManaColor.G)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(1, troll, 0))
	resolve_stack()
	assert_ok(g.end_damage_prevention(g.priority_player))
	if g.awaiting_damage_prevention or g.awaiting_regeneration:
		assert_ok(g.end_damage_prevention(g.priority_player))
	assert_eq(troll.zone, Mtg.Zone.BATTLEFIELD, "regenerated in the window")
	assert_true(troll.tapped)


# --- Dracoplasm -------------------------------------------------------------

func test_dracoplasm_absorbs_the_creatures_it_eats() -> void:
	var p0 := seat(0)
	p0.options = [2]
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var spared := put_battlefield(0, "Llanowar Elves")
	p0.picks = [bear, giant]
	var plasm := cast("Dracoplasm")
	assert_eq(plasm.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(spared.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq([plasm.cur_power, plasm.cur_toughness], [5, 5])
	assert_true(plasm.has_keyword(Mtg.Keyword.FLYING))
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, plasm, 0))
	resolve_stack()
	assert_eq([plasm.cur_power, plasm.cur_toughness], [6, 5])

func test_dracoplasm_eating_nothing_dies() -> void:
	var p0 := seat(0)
	p0.options = [0]
	var bear := put_battlefield(0, "Grizzly Bears")
	var plasm := cast("Dracoplasm")
	assert_eq(plasm.zone, Mtg.Zone.GRAVEYARD, "a 0/0")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)

func test_dracoplasm_cannot_eat_the_opponents_creatures() -> void:
	var theirs := put_battlefield(1, "Hill Giant")
	var plasm := cast("Dracoplasm")
	assert_eq(theirs.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(plasm.zone, Mtg.Zone.GRAVEYARD, "nothing of ours to sacrifice")


# --- Selenia, Dark Angel ----------------------------------------------------

func test_selenia_pays_two_life_to_go_home() -> void:
	var selenia := put_battlefield(0, "Selenia, Dark Angel")
	assert_true(selenia.has_keyword(Mtg.Keyword.FLYING))
	assert_ok(g.activate_ability(0, selenia, 0))
	assert_eq(g.players[0].life, 18)
	resolve_stack()
	assert_eq(selenia.zone, Mtg.Zone.HAND)
	assert_eq(selenia.owner_id, 0)
	assert_eq(CardRegistry.get_card("Selenia, Dark Angel").activated_abilities[0].effects[0].ai_role, &"self_bounce")

func test_selenia_answers_a_terror_by_going_home() -> void:
	var selenia := put_battlefield(0, "Selenia, Dark Angel")
	var p1_terror := give_hand(1, "Terror")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.B, 2)
	assert_refused(g.cast_spell(1, p1_terror, [TargetRef.card(selenia)]), "", )
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(selenia)]))
	assert_ok(g.pass_priority(1))
	assert_ok(g.activate_ability(0, selenia, 0))
	resolve_stack()
	assert_eq(selenia.zone, Mtg.Zone.HAND)
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)


# --- Vhati il-Dal -----------------------------------------------------------

func test_vhati_sets_base_power_one() -> void:
	var p0 := seat(0)
	p0.options = [0]
	var vhati := put_battlefield(0, "Vhati il-Dal")
	var giant := put_battlefield(1, "Hill Giant")
	assert_ok(g.activate_ability(0, vhati, 0, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq([giant.cur_power, giant.cur_toughness], [1, 3])
	advance_to_next_turn()
	assert_eq([giant.cur_power, giant.cur_toughness], [3, 3])

func test_vhati_sets_base_toughness_one_and_a_pump_still_adds() -> void:
	var p0 := seat(0)
	p0.options = [1]
	var vhati := put_battlefield(0, "Vhati il-Dal")
	var giant := put_battlefield(0, "Hill Giant")
	cast("Giant Growth", [TargetRef.card(giant)])
	assert_ok(g.activate_ability(0, vhati, 0, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq([giant.cur_power, giant.cur_toughness], [6, 4], "base 3/1, +3/+3 on top (CR 613.4)")

func test_vhati_default_hint_kills_a_damaged_creature() -> void:
	var vhati := put_battlefield(0, "Vhati il-Dal")
	var slinger := put_battlefield(0, "Fireslinger")
	var giant := put_battlefield(1, "Hill Giant")
	assert_ok(g.activate_ability(0, slinger, 0, [TargetRef.card(giant)]))
	resolve_stack()
	assert_ok(g.activate_ability(0, vhati, 0, [TargetRef.card(giant)]))
	assert_refused(g.activate_ability(0, vhati, 0, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "base toughness 1 with 1 damage marked")
	assert_true((vhati.cur_supertypes & Mtg.Supertype.LEGENDARY) != 0)
