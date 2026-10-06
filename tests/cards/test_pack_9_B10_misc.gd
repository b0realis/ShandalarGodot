extends GameTest
## Pack 9 (the Tempest block), batch B10: the Stronghold one-offs in
## cards/sets/sth/_misc.gd — Amok, Intruder Alarm, Primal Rage, Pursuit of
## Knowledge, Tortured Existence, Volrath's Gardens and Volrath's
## Shapeshifter (Pack 9 E5's graveyard-top copy).

const CLAIMED := ["Amok", "Intruder Alarm", "Primal Rage", "Pursuit of Knowledge",
	"Tortured Existence", "Volrath's Gardens", "Volrath's Shapeshifter"]

## Answers yes/no with [member yes]; a card ask with the card named
## [member pick] when there is one.
class Seat extends DecisionAgent:
	var yes := true
	var pick := ""
	func answer_yes_no(_g: MtgGame, _pid: int, _prompt: String, _hint: bool) -> bool:
		return yes
	func answer_card(g: MtgGame, pid: int, candidates: Array[CardInstance], prompt: String) -> CardInstance:
		for c in candidates:
			if c.data.card_name == pick: return c
		return super(g, pid, candidates, prompt)
	func answer_discard(g: MtgGame, pid: int, count: int) -> Array[CardInstance]:
		for c in g.players[pid].hand:
			if c.data.card_name == pick: return [c]
		return super(g, pid, count)

func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)

func _pt(i: CardInstance) -> Array: return [i.cur_power, i.cur_toughness]

func _seat(pid: int) -> Seat:
	var s := Seat.new()
	g.set_agent(pid, s)
	return s

func _to_graveyard(pid: int, card_name: String) -> CardInstance:
	var card := give_hand(pid, card_name)
	g.discard_cards(pid, [card])
	return card


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


# ------------------------------------------------------------------------ Amok --

func test_amok_discards_at_random_for_a_counter() -> void:
	var amok := put_battlefield(0, "Amok")
	var bear := put_battlefield(0, "Grizzly Bears")
	var card := give_hand(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, amok, 0, [TargetRef.card(bear)]))
	assert_eq(card.zone, Mtg.Zone.GRAVEYARD, "discarded as the cost")
	resolve_stack()
	assert_eq(int(bear.counters.get("+1/+1", 0)), 1)
	assert_eq(_pt(bear), [3, 3])

func test_amok_needs_a_card_to_discard() -> void:
	var amok := put_battlefield(0, "Amok")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.activate_ability(0, amok, 0, [TargetRef.card(bear)]))


# -------------------------------------------------------------- Intruder Alarm --

func test_intruder_alarm_keeps_creatures_tapped() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var forest := put_battlefield(0, "Forest")
	put_battlefield(1, "Intruder Alarm")   # after the Bears: no entering trigger pending
	g.tap_permanent(bear)
	g.tap_permanent(forest)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(bear.tapped, "creatures don't untap in their controller's untap step")
	assert_false(forest.tapped, "lands still do")

func test_intruder_alarm_untaps_everything_when_a_creature_enters() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	put_battlefield(0, "Intruder Alarm")
	g.tap_permanent(bear)
	g.tap_permanent(giant)
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(1, "Gray Ogre")
	resolve_stack()
	assert_false(bear.tapped)
	assert_false(giant.tapped, "all creatures, both sides")

func test_intruder_alarm_trigger_untaps_what_is_tapped_when_it_resolves() -> void:
	put_battlefield(0, "Intruder Alarm")
	var bear := put_battlefield(0, "Grizzly Bears")   # its entering trigger waits
	g.tap_permanent(bear)
	advance_to_step(Mtg.Step.MAIN1)
	assert_false(bear.tapped, "the trigger resolved after the tap")

func test_intruder_alarm_ignores_a_land_entering() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Intruder Alarm")
	g.tap_permanent(bear)
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Forest")
	resolve_stack()
	assert_true(bear.tapped)


# ----------------------------------------------------------------- Primal Rage --

func test_primal_rage_gives_your_creatures_trample() -> void:
	var rage := put_battlefield(0, "Primal Rage")
	var bear := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Gray Ogre")
	g.recalculate()
	assert_true(bear.has_keyword(Mtg.Keyword.TRAMPLE))
	assert_false(theirs.has_keyword(Mtg.Keyword.TRAMPLE))
	g.destroy(rage)
	g.recalculate()
	assert_false(bear.has_keyword(Mtg.Keyword.TRAMPLE))

func test_primal_rage_trample_carries_damage_over() -> void:
	put_battlefield(0, "Primal Rage")
	var giant := put_battlefield(0, "Hill Giant")
	var elves := put_battlefield(1, "Llanowar Elves")
	run_combat([giant.id], {elves.id: giant.id})
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 18, "3 power, 1 to the blocker, 2 trample over")


# --------------------------------------------------------- Pursuit of Knowledge --

func test_pursuit_of_knowledge_studies_instead_of_drawing() -> void:
	var seat := _seat(0)
	var pursuit := put_battlefield(0, "Pursuit of Knowledge")
	advance_to_step(Mtg.Step.MAIN1)
	var hand := g.players[0].hand.size()
	var library := g.players[0].library.size()
	g.draw_cards(0, 3)
	assert_eq(g.players[0].hand.size(), hand)
	assert_eq(g.players[0].library.size(), library)
	assert_eq(int(pursuit.counters.get("study", 0)), 3)
	assert_ok(g.activate_ability(0, pursuit, 0, []))
	assert_eq(pursuit.zone, Mtg.Zone.GRAVEYARD, "sacrificed as the cost")
	seat.yes = false
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 7)

func test_pursuit_of_knowledge_may_be_declined() -> void:
	var seat := _seat(0)
	seat.yes = false
	var pursuit := put_battlefield(0, "Pursuit of Knowledge")
	advance_to_step(Mtg.Step.MAIN1)
	var hand := g.players[0].hand.size()
	g.draw_cards(0, 1)
	assert_eq(g.players[0].hand.size(), hand + 1)
	assert_eq(int(pursuit.counters.get("study", 0)), 0)

func test_pursuit_of_knowledge_needs_three_counters() -> void:
	_seat(0)
	var pursuit := put_battlefield(0, "Pursuit of Knowledge")
	advance_to_step(Mtg.Step.MAIN1)
	g.draw_cards(0, 2)
	assert_refused(g.activate_ability(0, pursuit, 0, []))
	assert_eq(pursuit.zone, Mtg.Zone.BATTLEFIELD)

func test_pursuit_of_knowledge_only_replaces_its_controllers_draws() -> void:
	_seat(0)
	var pursuit := put_battlefield(0, "Pursuit of Knowledge")
	advance_to_step(Mtg.Step.MAIN1)
	var hand := g.players[1].hand.size()
	g.draw_cards(1, 1)
	assert_eq(g.players[1].hand.size(), hand + 1)
	assert_eq(int(pursuit.counters.get("study", 0)), 0)


# ---------------------------------------------------------- Tortured Existence --

func test_tortured_existence_trades_a_creature_card_for_another() -> void:
	var torture := put_battlefield(0, "Tortured Existence")
	var dead := _to_graveyard(0, "Hill Giant")
	var fodder := give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, torture, 0, [TargetRef.card(dead)]))
	assert_eq(fodder.zone, Mtg.Zone.GRAVEYARD, "discarded as the cost")
	resolve_stack()
	assert_eq(dead.zone, Mtg.Zone.HAND)

func test_tortured_existence_needs_a_creature_card_to_discard() -> void:
	var torture := put_battlefield(0, "Tortured Existence")
	var dead := _to_graveyard(0, "Hill Giant")
	give_hand(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_refused(g.activate_ability(0, torture, 0, [TargetRef.card(dead)]))

func test_tortured_existence_returns_only_creature_cards_of_yours() -> void:
	var torture := put_battlefield(0, "Tortured Existence")
	var land := _to_graveyard(0, "Forest")
	var theirs := _to_graveyard(1, "Hill Giant")
	give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_refused(g.activate_ability(0, torture, 0, [TargetRef.card(land)]))
	assert_refused(g.activate_ability(0, torture, 0, [TargetRef.card(theirs)]))


# ----------------------------------------------------------- Volrath's Gardens --

func test_volraths_gardens_taps_a_creature_for_two_life() -> void:
	var gardens := put_battlefield(0, "Volrath's Gardens")
	var bear := put_battlefield(0, "Grizzly Bears", true)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.activate_ability(0, gardens, 0, []))
	assert_true(bear.tapped, "a summoning-sick creature may pay (CR 302.6)")
	resolve_stack()
	assert_eq(g.players[0].life, 22)

func test_volraths_gardens_needs_an_untapped_creature() -> void:
	var gardens := put_battlefield(0, "Volrath's Gardens")
	var bear := put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	g.tap_permanent(bear)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_refused(g.activate_ability(0, gardens, 0, []))

func test_volraths_gardens_only_as_a_sorcery() -> void:
	var gardens := put_battlefield(0, "Volrath's Gardens")
	put_battlefield(0, "Grizzly Bears")
	advance_to_next_turn()   # P1's turn
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_refused(g.activate_ability(0, gardens, 0, []), "sorcery")


# ------------------------------------------------------ Volrath's Shapeshifter --

func test_volraths_shapeshifter_is_itself_with_no_creature_on_top() -> void:
	var shifter := put_battlefield(0, "Volrath's Shapeshifter")
	_to_graveyard(0, "Forest")
	g.recalculate()
	assert_eq(shifter.data.card_name, "Volrath's Shapeshifter")
	assert_eq(_pt(shifter), [0, 1])
	assert_eq(shifter.cur_activated_abilities.size(), 1)
	assert_eq(shifter.cur_activated_abilities[0].text, "{2}: Discard a card.")

func test_volraths_shapeshifter_takes_the_top_creature_cards_text() -> void:
	var shifter := put_battlefield(0, "Volrath's Shapeshifter")
	_to_graveyard(0, "Hill Giant")
	g.recalculate()
	assert_eq(shifter.data.card_name, "Hill Giant")
	assert_eq(_pt(shifter), [3, 3])
	var texts: Array = []
	for a in shifter.cur_activated_abilities: texts.append(a.text)
	assert_true(texts.has("{2}: Discard a card."), "and the discard ability")

func test_volraths_shapeshifter_reads_only_its_controllers_graveyard() -> void:
	var shifter := put_battlefield(0, "Volrath's Shapeshifter")
	_to_graveyard(1, "Hill Giant")
	g.recalculate()
	assert_eq(shifter.data.card_name, "Volrath's Shapeshifter")

func test_volraths_shapeshifter_discards_to_change_shape() -> void:
	var seat := _seat(0)
	seat.pick = "Shivan Dragon"
	var shifter := put_battlefield(0, "Volrath's Shapeshifter")
	_to_graveyard(0, "Hill Giant")
	give_hand(0, "Shivan Dragon")
	advance_to_step(Mtg.Step.MAIN1)
	g.recalculate()
	var at := -1
	for n in shifter.cur_activated_abilities.size():
		if shifter.cur_activated_abilities[n].text == "{2}: Discard a card.": at = n
	assert_ne(at, -1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, shifter, at, []))
	resolve_stack()
	assert_eq(shifter.data.card_name, "Shivan Dragon")
	assert_eq(_pt(shifter), [5, 5])
	assert_true(shifter.has_keyword(Mtg.Keyword.FLYING))

func test_volraths_shapeshifter_discard_needs_mana() -> void:
	var shifter := put_battlefield(0, "Volrath's Shapeshifter")
	give_hand(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_refused(g.activate_ability(0, shifter, 0, []))

func test_volraths_shapeshifter_restores_itself_when_it_leaves() -> void:
	var shifter := put_battlefield(0, "Volrath's Shapeshifter")
	_to_graveyard(0, "Hill Giant")
	g.recalculate()
	g.return_to_hand(shifter)
	assert_eq(shifter.data.card_name, "Volrath's Shapeshifter")
