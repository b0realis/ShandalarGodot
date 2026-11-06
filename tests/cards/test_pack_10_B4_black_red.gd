extends GameTest
## Pack 10 (the Urza block), batch B4: the black and red creatures of
## Urza's Legacy (cards/sets/ulg/_creatures.gd, _triggers.gd, _combat.gd) —
## Eviscerator, Fog of Gnats, Phyrexian Broodlings, the three Carriers
## (Debaser, Defiler, Denouncer), Phyrexian Plaguelord, Rank and File,
## Tethered Skirge, Ghitu Fire-Eater, Goblin Medics, Goblin Welder, Molten
## Hydra, Pygmy Pyrosaur, Shivan Phoenix, Viashino Bey, Viashino
## Cutthroat, Viashino Heretic, Viashino Sandscout. Each test drives the
## card through the public API and pins the clause that makes it that
## card, with its refused case.

const CLAIMED := ["Eviscerator", "Fog of Gnats", "Phyrexian Broodlings",
	"Phyrexian Debaser", "Phyrexian Defiler", "Phyrexian Denouncer",
	"Phyrexian Plaguelord", "Rank and File", "Tethered Skirge", "Ghitu Fire-Eater",
	"Goblin Medics", "Goblin Welder", "Molten Hydra", "Pygmy Pyrosaur", "Shivan Phoenix",
	"Viashino Bey", "Viashino Cutthroat", "Viashino Heretic", "Viashino Sandscout"]


## FIFO card picks; an empty queue falls back to the first candidate.
class Scripted extends DecisionAgent:
	var picks: Array = []

	func answer_card(_g: MtgGame, _p: int, candidates: Array[CardInstance], _prompt: String) -> CardInstance:
		if not picks.is_empty():
			var want: Variant = picks.pop_front()
			for c in candidates:
				if c == want:
					return c
		return null if candidates.is_empty() else candidates[0]


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func seat(pid: int) -> Scripted:
	var a := Scripted.new()
	g.set_agent(pid, a)
	return a

## Exactly the mana [param card]'s cost asks for.
func fund(pid: int, card: CardInstance) -> void:
	var cost := card.data.cost
	for c in cost.colored:
		add_mana(pid, c, int(cost.colored[c]))
	if cost.generic > 0:
		add_mana(pid, Mtg.ManaColor.C, cost.generic)

func cast_only(card_name: String, targets: Array = [], pid := 0) -> CardInstance:
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	var card := give_hand(pid, card_name)
	fund(pid, card)
	assert_ok(g.cast_spell(pid, card, targets))
	return card

func cast(card_name: String, targets: Array = [], pid := 0) -> CardInstance:
	var card := cast_only(card_name, targets, pid)
	resolve_stack()
	return card

func in_graveyard(pid: int, card_name: String) -> CardInstance:
	var card := put_battlefield(pid, card_name)
	g.destroy(card)
	assert_eq(card.zone, Mtg.Zone.GRAVEYARD)
	return card

func _attack(attackers: Array) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	var ids: Array = []
	for a in attackers:
		ids.append((a as CardInstance).id)
	assert_ok(g.declare_attackers(0, ids))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_true(g.awaiting_blockers)


func test_claimed_cards_are_no_longer_pending() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending", card_name)


# --- Eviscerator ---------------------------------------------------------------

func test_eviscerator_costs_five_life_as_it_enters() -> void:
	var eviscerator := cast("Eviscerator")
	assert_eq(eviscerator.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].life, 15)
	assert_eq(eviscerator.cur_protection, Mtg.ManaColor.W)


# --- Fog of Gnats --------------------------------------------------------------

func test_fog_of_gnats_regenerates() -> void:
	var gnats := put_battlefield(0, "Fog of Gnats")
	assert_true(gnats.has_keyword(Mtg.Keyword.FLYING))
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, gnats, 0))
	resolve_stack()
	g.destroy(gnats)
	assert_eq(gnats.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(gnats.tapped, "regenerated")


# --- Phyrexian Broodlings ------------------------------------------------------

func test_phyrexian_broodlings_eat_a_creature_for_a_counter() -> void:
	var a := seat(0)
	var brood := put_battlefield(0, "Phyrexian Broodlings")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_refused(g.activate_ability(0, brood, 0), "")
	add_mana(0, Mtg.ManaColor.C)
	a.picks = [bear]
	assert_ok(g.activate_ability(0, brood, 0))
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the sacrifice is a cost")
	resolve_stack()
	assert_eq(int(brood.counters.get("+1/+1", 0)), 1)
	assert_eq([brood.cur_power, brood.cur_toughness], [3, 3])

func test_phyrexian_broodlings_may_sacrifice_themselves() -> void:
	var a := seat(0)
	var brood := put_battlefield(0, "Phyrexian Broodlings")
	add_mana(0, Mtg.ManaColor.C)
	a.picks = [brood]
	assert_ok(g.activate_ability(0, brood, 0))
	assert_eq(brood.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_true(brood.counters.is_empty(), "nothing lands on the card in the graveyard")


# --- the Carriers ---------------------------------------------------------------

func test_the_carriers_shrink_a_creature_by_their_number() -> void:
	for row in [["Phyrexian Denouncer", "Llanowar Elves", 1], ["Phyrexian Debaser", "Grizzly Bears", 2],
			["Phyrexian Defiler", "Hill Giant", 3]]:
		var carrier := put_battlefield(0, String(row[0]))
		var victim := put_battlefield(1, String(row[1]))
		var survivor := put_battlefield(1, "Craw Wurm")
		assert_ok(g.activate_ability(0, carrier, 0, [TargetRef.card(victim)]))
		assert_eq(carrier.zone, Mtg.Zone.GRAVEYARD, "%s: sacrificed as the cost" % row[0])
		resolve_stack()
		assert_eq(victim.zone, Mtg.Zone.GRAVEYARD, String(row[0]))
		assert_ok(g.activate_ability(0, put_battlefield(0, String(row[0])), 0, [TargetRef.card(survivor)]))
		resolve_stack()
		var n := int(row[2])
		assert_eq([survivor.cur_power, survivor.cur_toughness], [6 - n, 4 - n], String(row[0]))
	assert_true(CardRegistry.get_card("Phyrexian Debaser").keywords.has(Mtg.Keyword.FLYING))

func test_a_summoning_sick_carrier_cannot_pay_its_tap() -> void:
	var carrier := put_battlefield(0, "Phyrexian Denouncer", true)
	var elves := put_battlefield(1, "Llanowar Elves")
	assert_refused(g.activate_ability(0, carrier, 0, [TargetRef.card(elves)]), "")
	assert_eq(carrier.zone, Mtg.Zone.BATTLEFIELD)


# --- Phyrexian Plaguelord -------------------------------------------------------

func test_phyrexian_plaguelord_has_both_abilities() -> void:
	var a := seat(0)
	var lord := put_battlefield(0, "Phyrexian Plaguelord")
	var bear := put_battlefield(0, "Grizzly Bears")
	var elves := put_battlefield(1, "Llanowar Elves")
	var wurm := put_battlefield(1, "Craw Wurm")
	a.picks = [bear]
	assert_ok(g.activate_ability(0, lord, 1, [TargetRef.card(elves)]))
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "a creature sacrificed as the cost")
	assert_false(lord.tapped, "no {T}")
	resolve_stack()
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)
	assert_ok(g.activate_ability(0, lord, 0, [TargetRef.card(wurm)]))
	assert_eq(lord.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD, "a 6/4 at -4/-4")

func test_phyrexian_plaguelord_may_sacrifice_itself_to_its_second_ability() -> void:
	var a := seat(0)
	var lord := put_battlefield(0, "Phyrexian Plaguelord")
	var elves := put_battlefield(1, "Llanowar Elves")
	a.picks = [lord]
	assert_ok(g.activate_ability(0, lord, 1, [TargetRef.card(elves)]))
	assert_eq(lord.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)


# --- Rank and File -------------------------------------------------------------

func test_rank_and_file_shrinks_the_green_creatures_as_it_enters() -> void:
	var elves := put_battlefield(1, "Llanowar Elves")
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var rank := cast("Rank and File")
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)
	assert_eq([bear.cur_power, bear.cur_toughness], [1, 1], "its controller's green creatures too")
	assert_eq([giant.cur_power, giant.cur_toughness], [3, 3])
	assert_eq([rank.cur_power, rank.cur_toughness], [3, 3])
	var late := put_battlefield(1, "Grizzly Bears")
	g.recalculate()
	assert_eq([late.cur_power, late.cur_toughness], [2, 2], "the set was locked as it resolved")


# --- Tethered Skirge -----------------------------------------------------------

func test_tethered_skirge_costs_its_controller_a_life_when_targeted() -> void:
	var skirge := put_battlefield(0, "Tethered Skirge")
	assert_true(skirge.has_keyword(Mtg.Keyword.FLYING))
	cast("Giant Growth", [TargetRef.card(skirge)])
	assert_eq(g.players[0].life, 19)
	assert_eq([skirge.cur_power, skirge.cur_toughness], [5, 5])
	cast("Lightning Bolt", [TargetRef.player(1)])
	assert_eq(g.players[0].life, 19, "only targeting it costs life")


# --- Ghitu Fire-Eater ----------------------------------------------------------

func test_ghitu_fire_eater_deals_its_power_as_it_last_existed() -> void:
	var eater := put_battlefield(0, "Ghitu Fire-Eater")
	cast("Giant Growth", [TargetRef.card(eater)])
	assert_ok(g.activate_ability(0, eater, 0, [TargetRef.player(1)]))
	assert_eq(eater.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[1].life, 15)

func test_ghitu_fire_eater_hits_a_creature() -> void:
	var eater := put_battlefield(0, "Ghitu Fire-Eater")
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_ok(g.activate_ability(0, eater, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


# --- Goblin Medics -------------------------------------------------------------

func test_goblin_medics_ping_when_they_become_tapped() -> void:
	var medics := put_battlefield(0, "Goblin Medics")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [medics.id]))
	assert_false(g.stack.is_empty(), "attacking taps it")
	resolve_stack()
	assert_eq(g.players[1].life, 19)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 18)

func test_goblin_medics_aim_at_a_creature_the_ping_kills_first() -> void:
	var medics := put_battlefield(0, "Goblin Medics")
	var elves := put_battlefield(1, "Llanowar Elves")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [medics.id]))
	resolve_stack()
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD, "the 1/1 the ping kills")
	assert_eq(giant.damage, 0)
	assert_eq(g.players[1].life, 20)

func test_goblin_medics_ping_even_after_they_have_died() -> void:
	var medics := put_battlefield(0, "Goblin Medics")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [medics.id]))
	assert_false(g.stack.is_empty())
	g.destroy(medics)   # in response: the trigger exists apart from its source
	resolve_stack()
	assert_eq(g.players[1].life, 19)

func test_goblin_medics_ping_when_an_effect_taps_them() -> void:
	var medics := put_battlefield(0, "Goblin Medics")
	var icy := put_battlefield(1, "Icy Manipulator")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(1, icy, 0, [TargetRef.card(medics)]))
	resolve_stack()
	assert_true(medics.tapped)
	assert_eq(g.players[1].life, 19)


# --- Goblin Welder -------------------------------------------------------------

func test_goblin_welder_swaps_an_artifact_for_one_in_that_players_graveyard() -> void:
	var welder := put_battlefield(0, "Goblin Welder")
	var rod := put_battlefield(1, "Rod of Ruin")
	var tome := in_graveyard(1, "Jayemdae Tome")
	var mine := in_graveyard(0, "Sol Ring")
	assert_refused(g.activate_ability(0, welder, 0, [TargetRef.card(rod), TargetRef.card(mine)]))
	assert_false(welder.tapped)
	assert_ok(g.activate_ability(0, welder, 0, [TargetRef.card(rod), TargetRef.card(tome)]))
	resolve_stack()
	assert_eq(rod.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(tome.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(tome.controller_id, 1, "returned under that player's control")
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD)

func test_goblin_welder_does_nothing_when_one_target_is_gone() -> void:
	var welder := put_battlefield(0, "Goblin Welder")
	var rod := put_battlefield(0, "Rod of Ruin")
	var tome := in_graveyard(0, "Jayemdae Tome")
	assert_ok(g.activate_ability(0, welder, 0, [TargetRef.card(rod), TargetRef.card(tome)]))
	g.destroy(rod)   # in response
	resolve_stack()
	assert_eq(tome.zone, Mtg.Zone.GRAVEYARD, "no half of the swap happens")
	assert_eq(rod.zone, Mtg.Zone.GRAVEYARD)


# --- Molten Hydra --------------------------------------------------------------

func test_molten_hydra_grows_then_fires_its_counters() -> void:
	var hydra := put_battlefield(0, "Molten Hydra")
	for i in 2:
		add_mana(0, Mtg.ManaColor.R, 2)
		add_mana(0, Mtg.ManaColor.C)
		assert_ok(g.activate_ability(0, hydra, 0))
		resolve_stack()
	assert_eq([hydra.cur_power, hydra.cur_toughness], [3, 3])
	assert_ok(g.activate_ability(0, hydra, 1, [TargetRef.player(1)]))
	assert_true(hydra.counters.is_empty(), "removing them is the cost")
	assert_eq([hydra.cur_power, hydra.cur_toughness], [1, 1])
	resolve_stack()
	assert_eq(g.players[1].life, 18)

func test_molten_hydra_without_counters_deals_nothing() -> void:
	var hydra := put_battlefield(0, "Molten Hydra")
	assert_ok(g.activate_ability(0, hydra, 1, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 20)


# --- Pygmy Pyrosaur -------------------------------------------------------------

func test_pygmy_pyrosaur_cannot_block_and_breathes_fire() -> void:
	var pyro := put_battlefield(1, "Pygmy Pyrosaur")
	var bear := put_battlefield(0, "Grizzly Bears")
	_attack([bear])
	assert_refused(g.declare_blockers(1, {pyro.id: bear.id}))
	assert_ok(g.declare_blockers(1, {}))
	var mine := put_battlefield(0, "Pygmy Pyrosaur")
	if g.priority_player != 0:
		assert_ok(g.pass_priority(g.priority_player))
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, mine, 0))
	resolve_stack()
	assert_eq([mine.cur_power, mine.cur_toughness], [2, 1])


# --- Shivan Phoenix -------------------------------------------------------------

func test_shivan_phoenix_returns_to_hand_when_it_dies() -> void:
	var phoenix := put_battlefield(0, "Shivan Phoenix")
	assert_true(phoenix.has_keyword(Mtg.Keyword.FLYING))
	g.destroy(phoenix)
	assert_eq(phoenix.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(phoenix.zone, Mtg.Zone.HAND)
	assert_true(g.players[0].hand.has(phoenix))

func test_shivan_phoenix_stays_put_once_it_has_left_the_graveyard() -> void:
	var phoenix := put_battlefield(0, "Shivan Phoenix")
	g.destroy(phoenix)
	g.exile_from_graveyard(phoenix)
	resolve_stack()
	assert_eq(phoenix.zone, Mtg.Zone.EXILE)

func test_shivan_phoenix_returns_to_its_owners_hand() -> void:
	var phoenix := put_battlefield(1, "Shivan Phoenix")
	g.change_control(phoenix, 0)
	g.destroy(phoenix)
	resolve_stack()
	assert_true(g.players[1].hand.has(phoenix))


# --- Viashino Bey ---------------------------------------------------------------

func test_viashino_bey_drags_every_creature_you_control_along() -> void:
	var bey := put_battlefield(0, "Viashino Bey")
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	put_battlefield(0, "Gray Ogre", true)   # summoning sick: unable, so not required
	put_battlefield(1, "Llanowar Elves")    # not theirs to drag
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [bey.id]), "Viashino Bey")
	assert_refused(g.declare_attackers(0, [bey.id, bear.id]), "Viashino Bey")
	assert_ok(g.declare_attackers(0, [bey.id, bear.id, giant.id]))

func test_without_the_bey_nothing_is_required() -> void:
	put_battlefield(0, "Viashino Bey")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))


# --- Viashino Cutthroat / Sandscout --------------------------------------------

func test_the_hasty_viashino_go_home_at_every_end_step() -> void:
	for card_name in ["Viashino Cutthroat", "Viashino Sandscout"]:
		before_each()
		var viashino := put_battlefield(0, card_name, true)
		assert_true(viashino.has_keyword(Mtg.Keyword.HASTE), card_name)
		advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
		assert_ok(g.declare_attackers(0, [viashino.id]))
		advance_to_step(Mtg.Step.END)
		assert_false(g.stack.is_empty(), card_name)
		resolve_stack()
		assert_eq(viashino.zone, Mtg.Zone.HAND, card_name)
		var other := put_battlefield(0, card_name)
		advance_to_next_turn()   # the opponent's turn
		advance_to_step(Mtg.Step.END)
		resolve_stack()
		assert_eq(other.zone, Mtg.Zone.HAND, "%s: each end step, not only yours" % card_name)


# --- Viashino Heretic -----------------------------------------------------------

func test_viashino_heretic_destroys_an_artifact_and_burns_its_controller() -> void:
	var heretic := put_battlefield(0, "Viashino Heretic")
	var tome := put_battlefield(1, "Jayemdae Tome")
	var bear := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.activate_ability(0, heretic, 0, [TargetRef.card(bear)]))
	assert_ok(g.activate_ability(0, heretic, 0, [TargetRef.card(tome)]))
	resolve_stack()
	assert_eq(tome.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 16, "the Tome's mana value")
	assert_eq(g.players[0].life, 20)
