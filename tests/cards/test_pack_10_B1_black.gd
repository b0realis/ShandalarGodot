extends GameTest
## Pack 10 (the Urza block), batch B1: the black instants and sorceries of
## cards/sets/usg/_spells.gd and cards/sets/ulg/_spells.gd (Exhume has its
## own script) — every card claimed, its main effect, a refused or illegal
## case, and the interactions its text implies (Befoul's "can't be
## regenerated", Corrupt's life for the damage actually dealt, Duress's
## revealed hand and held human choice, Rain of Filth's granted mana
## ability and the planner, the choices made after the discards).

const CLAIMED := ["Befoul", "Breach", "Corrupt", "Duress", "Ill-Gotten Gains", "Rain of Filth",
	"Reprocess", "Unnerve", "Ostracize", "Sick and Tired"]


## Scripted answers: a card by name from [member picks] (else the first
## candidate), an option by label from [member labels] (else the hint),
## discards by name from [member drops]. [member seen] keeps the names
## offered by the last card question.
class Seat extends DecisionAgent:
	var picks: Array[String] = []
	var labels: Array[String] = []
	var drops: Array[String] = []
	var seen: Array[String] = []
	func answer_card(_g: MtgGame, _pid: int, candidates: Array[CardInstance], _prompt: String) -> CardInstance:
		seen.clear()
		for c in candidates: seen.append(c.data.card_name)
		for n in picks.size():
			for c in candidates:
				if c.data.card_name == picks[n]:
					picks.remove_at(n)
					return c
		return null if candidates.is_empty() else candidates[0]
	func answer_option(_g: MtgGame, _pid: int, _prompt: String, options: Array[String], hint: int) -> int:
		for n in labels.size():
			var at := options.find(labels[n])
			if at >= 0:
				labels.remove_at(n)
				return at
		return hint
	func answer_discard(g: MtgGame, pid: int, count: int) -> Array[CardInstance]:
		if drops.is_empty(): return super(g, pid, count)
		var out: Array[CardInstance] = []
		for want in drops:
			for c in g.players[pid].hand:
				if c.data.card_name == want and not out.has(c):
					out.append(c)
					break
		return out


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-10", false)


func _seat(pid: int) -> Seat:
	var s := Seat.new()
	g.set_agent(pid, s)
	return s

func _pay(pid: int, card_name: String, x := 0) -> void:
	var cost := CardRegistry.get_card(card_name).cost
	for color in cost.colored:
		add_mana(pid, int(color), int(cost.colored[color]))
	var generic := cost.generic + x * cost.x_count
	if generic > 0:
		add_mana(pid, Mtg.ManaColor.C, generic)

func _try(pid: int, card_name: String, targets: Array = [], x := 0) -> String:
	var card := give_hand(pid, card_name)
	_pay(pid, card_name, x)
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	return g.cast_spell(pid, card, targets, x)

func _cast(pid: int, card_name: String, targets: Array = [], x := 0) -> void:
	assert_ok(_try(pid, card_name, targets, x))

func _cast_resolve(pid: int, card_name: String, targets: Array = [], x := 0) -> void:
	_cast(pid, card_name, targets, x)
	resolve_stack()

func _grave(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	g.put_into_graveyard(inst)
	return inst


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


# ------------------------------------------------------------------- Befoul --

func test_befoul_destroys_a_land() -> void:
	var land := put_battlefield(1, "Forest")
	_cast_resolve(0, "Befoul", [TargetRef.card(land)])
	assert_eq(land.zone, Mtg.Zone.GRAVEYARD)

func test_befoul_ignores_a_regeneration_shield() -> void:
	var troll := put_battlefield(1, "Uthden Troll")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(1, troll, 0, []))
	resolve_stack()
	assert_eq(troll.regeneration_shields, 1)
	_cast_resolve(0, "Befoul", [TargetRef.card(troll)])
	assert_eq(troll.zone, Mtg.Zone.GRAVEYARD, "it can't be regenerated")

func test_befoul_refuses_a_black_creature_and_an_enchantment() -> void:
	var vampire := put_battlefield(1, "Sengir Vampire")
	assert_refused(_try(0, "Befoul", [TargetRef.card(vampire)]))
	var pest := put_battlefield(1, "Pestilence")
	assert_refused(_try(0, "Befoul", [TargetRef.card(pest)]))


# ------------------------------------------------------------------- Breach --

func test_breach_gives_plus_two_and_fear_until_end_of_turn() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	_cast_resolve(0, "Breach", [TargetRef.card(bear)])
	assert_eq([bear.cur_power, bear.cur_toughness], [4, 2])
	assert_true(bear.has_keyword(Mtg.Keyword.FEAR))
	advance_to_next_turn()
	assert_eq(bear.cur_power, 2)
	assert_false(bear.has_keyword(Mtg.Keyword.FEAR))


# ------------------------------------------------------------------ Corrupt --

func test_corrupt_deals_your_swamp_count_and_drains_it() -> void:
	for _i in 3:
		put_battlefield(0, "Swamp")
	put_battlefield(1, "Swamp")
	put_battlefield(0, "Forest")
	_cast_resolve(0, "Corrupt", [TargetRef.player(1)])
	assert_eq(g.players[1].life, 17, "three Swamps you control; theirs do not count")
	assert_eq(g.players[0].life, 23)

func test_corrupt_gains_the_damage_dealt_not_the_toughness() -> void:
	for _i in 3:
		put_battlefield(0, "Swamp")
	var bear := put_battlefield(1, "Grizzly Bears")
	_cast_resolve(0, "Corrupt", [TargetRef.card(bear)])
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 23, "3 damage was dealt to the 2/2")

func test_corrupt_gains_nothing_when_the_damage_is_prevented() -> void:
	for _i in 3:
		put_battlefield(0, "Swamp")
	var bear := put_battlefield(1, "Grizzly Bears")
	_cast_resolve(0, "Redeem", [TargetRef.card(bear)])
	_cast_resolve(0, "Corrupt", [TargetRef.card(bear)])
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].life, 20)


# ------------------------------------------------------------------- Duress --

func test_duress_takes_a_noncreature_nonland_card_of_your_choice() -> void:
	var seat := _seat(0)
	var bolt := give_hand(1, "Lightning Bolt")
	var bear := give_hand(1, "Grizzly Bears")
	var land := give_hand(1, "Forest")
	var pest := give_hand(1, "Pestilence")
	seat.picks = ["Pestilence"]
	_cast_resolve(0, "Duress", [TargetRef.player(1)])
	assert_eq(pest.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bolt.zone, Mtg.Zone.HAND)
	assert_eq(bear.zone, Mtg.Zone.HAND)
	assert_eq(land.zone, Mtg.Zone.HAND)
	seat.seen.sort()
	assert_eq(seat.seen, ["Lightning Bolt", "Pestilence"] as Array[String],
		"only noncreature, nonland cards are offered")

func test_duress_finds_nothing_in_a_hand_of_creatures_and_lands() -> void:
	give_hand(1, "Grizzly Bears")
	give_hand(1, "Forest")
	_cast_resolve(0, "Duress", [TargetRef.player(1)])
	assert_eq(g.players[1].hand.size(), 2)

func test_duress_targets_an_opponent_only() -> void:
	assert_refused(_try(0, "Duress", [TargetRef.player(0)]))

func test_duress_holds_a_human_seat_open_on_the_choice() -> void:
	var bolt := give_hand(1, "Lightning Bolt")
	var pest := give_hand(1, "Pestilence")
	g.set_agent(0, HumanAgent.new())
	g.interactive_choices = true
	_cast(0, "Duress", [TargetRef.player(1)])
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_not_null(g.awaiting_choice)
	if g.awaiting_choice == null: return
	assert_has(g.awaiting_choice.candidates, bolt)
	assert_has(g.awaiting_choice.candidates, pest)
	assert_eq(bolt.zone, Mtg.Zone.HAND)
	assert_ok(g.answer_choice(bolt.id))
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(pest.zone, Mtg.Zone.HAND)


# --------------------------------------------------------- Ill-Gotten Gains --

func test_ill_gotten_gains_discards_then_each_player_regrows_up_to_three() -> void:
	var mine := _seat(0)
	var bolt := give_hand(0, "Lightning Bolt")
	var growth := _grave(0, "Giant Growth")
	var bear := _grave(0, "Grizzly Bears")
	var giant := give_hand(1, "Hill Giant")
	mine.labels = ["2"]
	mine.picks = ["Lightning Bolt", "Grizzly Bears"]
	var spell := give_hand(0, "Ill-Gotten Gains")
	_pay(0, "Ill-Gotten Gains")
	assert_ok(g.cast_spell(0, spell))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.HAND, "a card just discarded may come back")
	assert_eq(bear.zone, Mtg.Zone.HAND)
	assert_eq(growth.zone, Mtg.Zone.GRAVEYARD, "two of three chosen")
	assert_eq(giant.zone, Mtg.Zone.HAND, "the other player took back their discarded giant")
	assert_eq(spell.zone, Mtg.Zone.EXILE, "Exile Ill-Gotten Gains")

func test_ill_gotten_gains_may_return_nothing() -> void:
	var mine := _seat(0)
	var bolt := give_hand(0, "Lightning Bolt")
	mine.labels = ["0"]
	_cast_resolve(0, "Ill-Gotten Gains")
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].hand.size(), 0)


# ------------------------------------------------------------ Rain of Filth --

func test_rain_of_filth_lands_you_control_gain_a_sacrifice_mana_ability() -> void:
	var swamp := put_battlefield(0, "Swamp")
	var forest := put_battlefield(0, "Forest")
	var theirs := put_battlefield(1, "Mountain")
	_cast_resolve(0, "Rain of Filth")
	assert_eq(forest.cur_mana_abilities.size(), 2)
	assert_eq(swamp.cur_mana_abilities.size(), 2)
	assert_eq(theirs.cur_mana_abilities.size(), 1, "only lands you control")
	g.tap_permanent(forest)
	assert_ok(g.tap_for_mana(0, forest, 1))
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD, "no {T} in the cost: a tapped land still pays")
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 1)

func test_rain_of_filth_is_a_locked_set_that_ends_with_the_turn() -> void:
	var swamp := put_battlefield(0, "Swamp")
	_cast_resolve(0, "Rain of Filth")
	var late := put_battlefield(0, "Plains")
	assert_eq(late.cur_mana_abilities.size(), 1, "a land arriving later is not affected (CR 611.2c)")
	advance_to_next_turn()
	assert_eq(swamp.cur_mana_abilities.size(), 1)

func test_rain_of_filth_the_planner_taps_before_it_sacrifices() -> void:
	var swamp := put_battlefield(0, "Swamp")
	_cast_resolve(0, "Rain of Filth")
	var plan := ManaPlanner.plan(g, 0, ManaCost.parse("{B}"), 0)
	assert_false(plan.is_empty())
	ManaPlanner.run_plan(g, 0, plan)
	assert_eq(swamp.zone, Mtg.Zone.BATTLEFIELD, "the {T} row is planned first")
	assert_true(swamp.tapped)


# ---------------------------------------------------------------- Reprocess --

func test_reprocess_sacrifices_any_number_and_draws_that_many() -> void:
	var seat := _seat(0)
	var ring := put_battlefield(0, "Sol Ring")
	var bear := put_battlefield(0, "Grizzly Bears")
	var land := put_battlefield(0, "Forest")
	var theirs := put_battlefield(1, "Hill Giant")
	seat.labels = ["2"]
	seat.picks = ["Sol Ring", "Forest"]
	var hand := g.players[0].hand.size()
	_cast_resolve(0, "Reprocess")
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(land.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(theirs.zone, Mtg.Zone.BATTLEFIELD, "only your own permanents")
	assert_eq(g.players[0].hand.size(), hand + 2)

func test_reprocess_for_nothing_draws_nothing() -> void:
	var seat := _seat(0)
	put_battlefield(0, "Grizzly Bears")
	seat.labels = ["0"]
	var hand := g.players[0].hand.size()
	_cast_resolve(0, "Reprocess")
	assert_eq(g.players[0].hand.size(), hand)


# ------------------------------------------------------------------ Unnerve --

func test_unnerve_each_opponent_discards_two_of_their_choice() -> void:
	var theirs := _seat(1)
	var mine := give_hand(0, "Lightning Bolt")
	var a := give_hand(1, "Forest")
	var b := give_hand(1, "Lightning Bolt")
	var c := give_hand(1, "Grizzly Bears")
	theirs.drops = ["Forest", "Lightning Bolt"]
	_cast_resolve(0, "Unnerve")
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(c.zone, Mtg.Zone.HAND)
	assert_eq(mine.zone, Mtg.Zone.HAND, "you discard nothing")

func test_unnerve_takes_a_single_card_hand() -> void:
	var only := give_hand(1, "Grizzly Bears")
	_cast_resolve(0, "Unnerve")
	assert_eq(only.zone, Mtg.Zone.GRAVEYARD)


# ---------------------------------------------------------------- Ostracize --

func test_ostracize_takes_a_creature_card_of_your_choice() -> void:
	var seat := _seat(0)
	var bolt := give_hand(1, "Lightning Bolt")
	var bear := give_hand(1, "Grizzly Bears")
	var giant := give_hand(1, "Hill Giant")
	seat.picks = ["Hill Giant"]
	_cast_resolve(0, "Ostracize", [TargetRef.player(1)])
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.HAND)
	assert_eq(bolt.zone, Mtg.Zone.HAND)
	seat.seen.sort()
	assert_eq(seat.seen, ["Grizzly Bears", "Hill Giant"] as Array[String])

func test_ostracize_without_a_creature_card_does_nothing() -> void:
	give_hand(1, "Lightning Bolt")
	_cast_resolve(0, "Ostracize", [TargetRef.player(1)])
	assert_eq(g.players[1].hand.size(), 1)


# ----------------------------------------------------------- Sick and Tired --

func test_sick_and_tired_shrinks_two_target_creatures() -> void:
	var a := put_battlefield(1, "Llanowar Elves")
	var b := put_battlefield(1, "Llanowar Elves")
	var giant := put_battlefield(1, "Hill Giant")
	assert_refused(_try(0, "Sick and Tired", [TargetRef.card(a)]))
	_cast_resolve(0, "Sick and Tired", [TargetRef.card(a), TargetRef.card(b)])
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)
	_cast_resolve(0, "Sick and Tired", [TargetRef.card(giant), TargetRef.card(put_battlefield(0, "Grizzly Bears"))])
	assert_eq([giant.cur_power, giant.cur_toughness], [2, 2])
