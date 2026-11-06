extends GameTest
## Pack 10 (the Urza block), batch B7: the Urza's Destiny Auras in
## cards/sets/uds/_auras.gd. "When enchanted creature dies" reads the Aura's
## counters as it last existed (it has gone to the graveyard by the time the
## ability resolves); the "you may put a counter" upkeeps are optional.

const CLAIMED := ["Capashen Standard", "Mask of Law and Grace", "Disappear", "Illuminated Wings",
	"Private Research", "Sigil of Sleep", "Chime of Night", "Dying Wail", "Festering Wound",
	"Twisted Experiment", "Incendiary", "Mark of Fury", "Momentum", "Pattern of Rebirth"]

## Scripted answers: every yes/no with [member yes], every card pick by
## [member pick_name] when it is offered; remembers the prompts.
class Seat extends DecisionAgent:
	var yes := true
	var pick_name := ""
	var asked: Array[String] = []
	func answer_yes_no(_g: MtgGame, _pid: int, prompt: String, _hint: bool) -> bool:
		asked.append(prompt)
		return yes
	func answer_card(g: MtgGame, pid: int, candidates: Array[CardInstance], prompt: String) -> CardInstance:
		asked.append(prompt)
		for c in candidates:
			if c.data.card_name == pick_name: return c
		return super.answer_card(g, pid, candidates, prompt)

func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func _seat(pid: int) -> Seat:
	var s := Seat.new()
	g.set_agent(pid, s)
	return s

func _pt(i: CardInstance) -> Array: return [i.cur_power, i.cur_toughness]

func _priority_to(pid: int) -> void:
	if g.priority_player != pid: assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.priority_player, pid)

func _enchant(pid: int, aura_name: String, host: CardInstance, mana: Array) -> CardInstance:
	_priority_to(pid)
	var aura := give_hand(pid, aura_name)
	for m in mana: add_mana(pid, int(m))
	assert_ok(g.cast_spell(pid, aura, [TargetRef.card(host)]))
	resolve_stack()
	assert_eq(aura.attached_to, host.id, aura_name + " is attached")
	return aura

func _cast_at(pid: int, spell: String, target: TargetRef, mana: Array) -> CardInstance:
	_priority_to(pid)
	var card := give_hand(pid, spell)
	for m in mana: add_mana(pid, int(m))
	assert_ok(g.cast_spell(pid, card, [target]))
	resolve_stack()
	return card

func _bolt(pid: int, target: TargetRef) -> void:
	_cast_at(pid, "Lightning Bolt", target, [Mtg.ManaColor.R])

func _terror(pid: int, victim: CardInstance) -> void:
	_cast_at(pid, "Terror", TargetRef.card(victim), [Mtg.ManaColor.B, Mtg.ManaColor.C])

func _to_upkeep_of(pid: int) -> void:
	var turn := g.turn_number
	var guard := 0
	while g.turn_number == turn and guard < 400:
		_advance_once()
		guard += 1
	while not (g.active_player == pid and g.current_step() == Mtg.Step.UPKEEP) and guard < 400:
		_advance_once()
		guard += 1
	assert_eq(g.active_player, pid)
	assert_eq(g.current_step(), Mtg.Step.UPKEEP)


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)
		assert_true(c.is_aura(), "%s enchants something" % card_name)


# ---------------------------------------------- Capashen Standard / Illuminated Wings --

func test_capashen_standard_pumps_and_cashes_in_for_a_card() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := _enchant(0, "Capashen Standard", bear, [Mtg.ManaColor.W])
	assert_eq(_pt(bear), [3, 3])
	assert_refused(g.activate_ability(0, aura, 0, []))
	add_mana(0, Mtg.ManaColor.C, 2)
	var hand := g.players[0].hand.size()
	assert_ok(g.activate_ability(0, aura, 0, []))
	assert_eq(aura.zone, Mtg.Zone.GRAVEYARD, "sacrificed as the cost")
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 1)
	assert_eq(_pt(bear), [2, 2])

func test_illuminated_wings_flies_and_cashes_in_for_a_card() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	var aura := _enchant(0, "Illuminated Wings", bear, [Mtg.ManaColor.U, Mtg.ManaColor.C])
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))
	add_mana(0, Mtg.ManaColor.C, 2)
	var hand := g.players[0].hand.size()
	assert_ok(g.activate_ability(0, aura, 0, []))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 1, "the Aura's controller draws")
	assert_false(bear.has_keyword(Mtg.Keyword.FLYING))


# ------------------------------------------------------------ Mask of Law and Grace --

func test_mask_of_law_and_grace_protects_from_black_and_red() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := _enchant(0, "Mask of Law and Grace", bear, [Mtg.ManaColor.W])
	assert_eq(bear.cur_protection & (Mtg.ManaColor.B | Mtg.ManaColor.R), Mtg.ManaColor.B | Mtg.ManaColor.R)
	assert_eq(aura.zone, Mtg.Zone.BATTLEFIELD)
	_priority_to(1)
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(1, bolt, [TargetRef.card(bear)]))
	var terror := give_hand(1, "Terror")
	add_mana(1, Mtg.ManaColor.B)
	add_mana(1, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(1, terror, [TargetRef.card(bear)]))


# ------------------------------------------------------------------- Disappear --

func test_disappear_returns_the_creature_and_itself() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(1, "Hill Giant")
	var aura := _enchant(0, "Disappear", giant, [Mtg.ManaColor.U, Mtg.ManaColor.U, Mtg.ManaColor.C, Mtg.ManaColor.C])
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(0, aura, 0, []))
	resolve_stack()
	assert_true(g.players[1].hand.has(giant), "to its owner's hand")
	assert_true(g.players[0].hand.has(aura))

func test_disappear_still_returns_the_creature_if_the_aura_is_gone() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := _enchant(0, "Disappear", bear, [Mtg.ManaColor.U, Mtg.ManaColor.U, Mtg.ManaColor.C, Mtg.ManaColor.C])
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(0, aura, 0, []))
	assert_ok(g.pass_priority(0))
	var disenchant := give_hand(1, "Disenchant")
	add_mana(1, Mtg.ManaColor.W)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, disenchant, [TargetRef.card(aura)]))
	resolve_stack()
	assert_eq(aura.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.players[0].hand.has(bear), "the creature it enchanted when activated")


# ------------------------------------------------------------- Private Research --

func test_private_research_draws_a_card_per_page_counter_when_its_creature_dies() -> void:
	var seat := _seat(0)
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := _enchant(0, "Private Research", bear, [Mtg.ManaColor.U])
	_to_upkeep_of(0)
	resolve_stack()
	_to_upkeep_of(0)
	resolve_stack()
	assert_eq(int(aura.counters.get("page", 0)), 2)
	assert_eq(seat.asked.size(), 2)
	advance_to_step(Mtg.Step.MAIN1)
	var hand := g.players[0].hand.size()
	_terror(1, bear)
	assert_eq(aura.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].hand.size(), hand + 2, "two page counters as it last existed")

func test_private_research_counter_is_optional() -> void:
	var seat := _seat(0)
	seat.yes = false
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := _enchant(0, "Private Research", bear, [Mtg.ManaColor.U])
	_to_upkeep_of(0)
	resolve_stack()
	assert_eq(int(aura.counters.get("page", 0)), 0)
	advance_to_step(Mtg.Step.MAIN1)
	var hand := g.players[0].hand.size()
	_terror(1, bear)
	assert_eq(g.players[0].hand.size(), hand)


# --------------------------------------------------------------- Sigil of Sleep --

func test_sigil_of_sleep_bounces_a_creature_of_the_damaged_opponent() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var mine := put_battlefield(0, "Llanowar Elves")
	_enchant(0, "Sigil of Sleep", bear, [Mtg.ManaColor.U])
	run_combat([bear.id])
	resolve_stack()
	assert_eq(g.players[1].life, 18)
	assert_true(g.players[1].hand.has(giant), "a creature THAT player controls")
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD)

func test_sigil_of_sleep_on_an_opponents_creature_bounces_your_own() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(1, "Hill Giant")
	var mine := put_battlefield(0, "Llanowar Elves")
	_enchant(0, "Sigil of Sleep", giant, [Mtg.ManaColor.U])
	advance_to_next_turn()
	run_combat([giant.id])
	resolve_stack()
	assert_eq(g.players[0].life, 17)
	assert_true(g.players[0].hand.has(mine), "the damaged player is the Aura's controller")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)


# --------------------------------------------------------------- Chime of Night --

func test_chime_of_night_destroys_a_nonblack_creature_as_it_goes_to_the_graveyard() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var knight := put_battlefield(1, "Black Knight")
	var chime := _enchant(0, "Chime of Night", bear, [Mtg.ManaColor.B, Mtg.ManaColor.C])
	_bolt(0, TargetRef.card(bear))
	assert_eq(chime.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "the nonblack target its controller chose")
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD, "black: not a legal target")

func test_chime_of_night_shed_by_state_based_actions_triggers() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var chime := _enchant(0, "Chime of Night", bear, [Mtg.ManaColor.B, Mtg.ManaColor.C])
	_cast_at(1, "Unsummon", TargetRef.card(bear), [Mtg.ManaColor.U])
	assert_true(g.players[0].hand.has(bear))
	assert_eq(chime.zone, Mtg.Zone.GRAVEYARD, "its creature left: the Chime was put into the graveyard")
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "and it triggered")

func test_chime_of_night_with_no_legal_target_does_nothing() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	var knight := put_battlefield(1, "Black Knight")
	var chime := _enchant(0, "Chime of Night", bear, [Mtg.ManaColor.B, Mtg.ManaColor.C])
	_bolt(0, TargetRef.card(bear))
	assert_eq(chime.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(g.stack.is_empty())


# ------------------------------------------------------------------ Dying Wail --

func test_dying_wail_makes_the_target_player_discard_two() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	_enchant(0, "Dying Wail", bear, [Mtg.ManaColor.B, Mtg.ManaColor.C])
	give_hand(1, "Lightning Bolt")
	give_hand(1, "Giant Growth")
	give_hand(1, "Unsummon")
	_terror(1, bear)
	assert_eq(g.players[1].hand.size(), 1, "the opponent is the default target; two discarded")


# -------------------------------------------------------------- Festering Wound --

func test_festering_wound_grows_and_burns_the_creatures_controller() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	var aura := _enchant(0, "Festering Wound", bear, [Mtg.ManaColor.B, Mtg.ManaColor.C])
	_to_upkeep_of(1)
	resolve_stack()
	assert_eq(g.players[1].life, 20, "no infection counter yet")
	_to_upkeep_of(0)
	resolve_stack()
	assert_eq(int(aura.counters.get("infection", 0)), 1)
	_to_upkeep_of(1)
	resolve_stack()
	assert_eq(g.players[1].life, 19)
	_to_upkeep_of(0)
	resolve_stack()
	_to_upkeep_of(1)
	resolve_stack()
	assert_eq(g.players[1].life, 17, "two counters")
	assert_eq(g.players[0].life, 20)


# ----------------------------------------------------------- Twisted Experiment --

func test_twisted_experiment_is_plus_three_minus_one() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var elves := put_battlefield(1, "Llanowar Elves")
	_enchant(0, "Twisted Experiment", bear, [Mtg.ManaColor.B, Mtg.ManaColor.C])
	assert_eq(_pt(bear), [5, 1])
	var aura := give_hand(0, "Twisted Experiment")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(elves)]))
	resolve_stack()
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD, "a 1/1 becomes 4/0")
	assert_eq(aura.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------------------ Incendiary --

func test_incendiary_deals_its_fuse_counters_when_its_creature_dies() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := _enchant(0, "Incendiary", bear, [Mtg.ManaColor.R])
	_to_upkeep_of(0)
	resolve_stack()
	_to_upkeep_of(0)
	resolve_stack()
	assert_eq(int(aura.counters.get("fuse", 0)), 2)
	advance_to_step(Mtg.Step.MAIN1)
	_terror(1, bear)
	assert_eq(g.players[1].life, 18, "two fuse counters, at the opponent by default")


# ---------------------------------------------------------------- Mark of Fury --

func test_mark_of_fury_gives_haste_and_goes_home_at_the_end_step() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears", true)
	var aura := _enchant(0, "Mark of Fury", bear, [Mtg.ManaColor.R])
	assert_true(bear.has_keyword(Mtg.Keyword.HASTE))
	run_combat([bear.id])
	assert_eq(g.players[1].life, 18, "attacked the turn it arrived")
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_true(g.players[0].hand.has(aura))
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)

func test_mark_of_fury_returns_in_the_opponents_end_step_too() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	var aura := _enchant(1, "Mark of Fury", bear, [Mtg.ManaColor.R])
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_true(g.players[1].hand.has(aura))


# -------------------------------------------------------------------- Momentum --

func test_momentum_grows_with_its_growth_counters() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := _enchant(0, "Momentum", bear, [Mtg.ManaColor.G, Mtg.ManaColor.C, Mtg.ManaColor.C])
	assert_eq(_pt(bear), [2, 2])
	_to_upkeep_of(0)
	resolve_stack()
	assert_eq(int(aura.counters.get("growth", 0)), 1)
	assert_eq(_pt(bear), [3, 3])
	assert_eq(int(bear.counters.get("+1/+1", 0)), 0, "the counters are on the Aura")


# ---------------------------------------------------------- Pattern of Rebirth --

func test_pattern_of_rebirth_lets_the_creatures_controller_fetch_a_creature() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := give_hand(1, "Hill Giant")
	g.put_from_hand_on_top_of_library(giant)
	var seat := _seat(1)
	seat.pick_name = "Hill Giant"
	_enchant(0, "Pattern of Rebirth", bear, [Mtg.ManaColor.G, Mtg.ManaColor.C, Mtg.ManaColor.C, Mtg.ManaColor.C])
	_terror(0, bear)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "the dead creature's controller searched")
	assert_eq(giant.controller_id, 1)

func test_pattern_of_rebirth_search_is_optional() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := give_hand(0, "Hill Giant")
	g.put_from_hand_on_top_of_library(giant)
	var seat := _seat(0)
	seat.yes = false
	seat.pick_name = "Hill Giant"
	_enchant(0, "Pattern of Rebirth", bear, [Mtg.ManaColor.G, Mtg.ManaColor.C, Mtg.ManaColor.C, Mtg.ManaColor.C])
	_terror(1, bear)
	assert_eq(giant.zone, Mtg.Zone.LIBRARY, "declined")
	assert_eq(g.players[0].library.back(), giant, "and no shuffle")
