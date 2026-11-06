extends GameTest
## Pack 10 (the Urza block), batch B6: the activated enchantments and
## Abundance — Attunement, Douse, Diabolic Servitude, No Rest for the
## Wicked, Sneak Attack, Greater Good, Martyr's Cause, Phyrexian
## Reclamation, Ghitu War Cry and Abundance's draw replacement.

const W := Mtg.ManaColor.W
const U := Mtg.ManaColor.U
const B := Mtg.ManaColor.B
const R := Mtg.ManaColor.R
const G := Mtg.ManaColor.G

## A seat whose answers a test scripts: yes/no (-1 follows the hint), an
## option by its text (else the hint), card names to prefer, and
## [member decline] for an optional card question.
class Seat extends DecisionAgent:
	var yes := -1
	var option := ""
	var prefer: Array = []
	var decline := false
	var asked: Array = []
	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String, hint: bool) -> bool:
		asked.append(prompt)
		return hint if yes < 0 else yes == 1
	func answer_option(_game: MtgGame, _pid: int, prompt: String,
			options: Array[String], hint: int) -> int:
		asked.append(prompt)
		var at := options.find(option)
		return at if at >= 0 else hint
	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		asked.append(prompt)
		if decline: return null
		for name in prefer:
			for c in candidates:
				if c.data.card_name == name: return c
		return null if candidates.is_empty() else candidates[0]

var me: Seat
var foe: Seat


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	me = Seat.new()
	foe = Seat.new()
	g.set_agent(0, me)
	g.set_agent(1, foe)
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _priority(pid: int) -> void:
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.priority_player, pid)

func _cast(pid: int, card_name: String, targets: Array = []) -> CardInstance:
	var card := give_hand(pid, card_name)
	for color in [W, U, B, R, G]: add_mana(pid, color, 4)
	assert_ok(g.cast_spell(pid, card, targets))
	resolve_stack()
	return card

func _pt(i: CardInstance) -> Array: return [i.cur_power, i.cur_toughness]

## A card of [param card_name] in [param pid]'s graveyard (setup).
func _in_graveyard(pid: int, card_name: String) -> CardInstance:
	var card := _make_instance(pid, card_name)
	card.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(card)
	return card

## A card of [param card_name] on top of [param pid]'s library (setup).
func _on_top(pid: int, card_name: String) -> CardInstance:
	var card := _make_instance(pid, card_name)
	card.zone = Mtg.Zone.LIBRARY
	g.players[pid].library.append(card)
	return card


# ---------------------------------------------------------------- Attunement --

func test_attunement_returns_itself_to_draw_three_and_discard_four() -> void:
	var tune := put_battlefield(0, "Attunement")
	give_hand(0, "Forest")
	give_hand(0, "Island")
	var graveyard := g.players[0].graveyard.size()
	assert_ok(g.activate_ability(0, tune, 0, []))
	assert_eq(tune.zone, Mtg.Zone.HAND, "returned as the cost")
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 2, "2 + itself + 3 - 4")
	assert_eq(g.players[0].graveyard.size(), graveyard + 4)


# --------------------------------------------------------------------- Douse --

func test_douse_counters_a_red_spell_only() -> void:
	var douse := put_battlefield(0, "Douse")
	_priority(1)
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	_priority(0)
	add_mana(0, U, 2)
	assert_ok(g.activate_ability(0, douse, 0, [TargetRef.card(bolt)]))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 20)
	var bears := give_hand(0, "Grizzly Bears")
	add_mana(0, G, 2)
	assert_ok(g.cast_spell(0, bears))
	add_mana(0, U, 2)
	assert_refused(g.activate_ability(0, douse, 0, [TargetRef.card(bears)]), "")
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)


# -------------------------------------------------------- Diabolic Servitude --

func test_diabolic_servitude_raises_and_trades_back_on_death() -> void:
	var wurm := _in_graveyard(0, "Craw Wurm")
	var servitude := _cast(0, "Diabolic Servitude")
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(wurm.controller_id, 0)
	g.destroy(wurm)
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.EXILE, "exiled from the graveyard")
	assert_eq(servitude.zone, Mtg.Zone.HAND, "the Servitude goes home")


func test_diabolic_servitude_leaving_exiles_its_creature() -> void:
	var wurm := _in_graveyard(0, "Craw Wurm")
	var servitude := _cast(0, "Diabolic Servitude")
	g.destroy(servitude)
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.EXILE)


func test_diabolic_servitude_ignores_a_creature_it_did_not_raise() -> void:
	_in_graveyard(0, "Craw Wurm")
	var servitude := _cast(0, "Diabolic Servitude")
	var bears := put_battlefield(0, "Grizzly Bears")
	g.destroy(bears)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(servitude.zone, Mtg.Zone.BATTLEFIELD)


func test_diabolic_servitude_with_an_empty_graveyard_raises_nothing() -> void:
	var servitude := _cast(0, "Diabolic Servitude")
	assert_eq(servitude.zone, Mtg.Zone.BATTLEFIELD)
	g.destroy(servitude)
	resolve_stack()
	assert_eq(servitude.zone, Mtg.Zone.GRAVEYARD)


# --------------------------------------------------- No Rest for the Wicked --

func test_no_rest_for_the_wicked_returns_this_turns_dead_only() -> void:
	var rest := put_battlefield(0, "No Rest for the Wicked")
	var old := put_battlefield(0, "Hill Giant")
	g.destroy(old)
	advance_to_next_turn()
	advance_to_next_turn()
	var bears := put_battlefield(0, "Grizzly Bears")
	var wurm := put_battlefield(0, "Craw Wurm")
	var theirs := put_battlefield(1, "Llanowar Elves")
	for i in [bears, wurm, theirs]: g.destroy(i)
	var never := _in_graveyard(0, "Savannah Lions")
	resolve_stack()
	assert_ok(g.activate_ability(0, rest, 0, []))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.HAND)
	assert_eq(wurm.zone, Mtg.Zone.HAND)
	assert_eq(old.zone, Mtg.Zone.GRAVEYARD, "it died on an earlier turn")
	assert_eq(never.zone, Mtg.Zone.GRAVEYARD, "never on the battlefield")
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD, "not in your graveyard")


# -------------------------------------------------------------- Sneak Attack --

func test_sneak_attack_puts_the_creature_in_with_haste_then_sacrifices_it() -> void:
	var sneak := put_battlefield(0, "Sneak Attack")
	var wurm := give_hand(0, "Craw Wurm")
	give_hand(0, "Grizzly Bears")
	add_mana(0, R)
	assert_ok(g.activate_ability(0, sneak, 0, []))
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD, "the biggest is the heuristic's pick")
	assert_true(wurm.has_keyword(Mtg.Keyword.HASTE))
	run_combat([wurm.id])
	assert_eq(g.players[1].life, 14, "it attacks the turn it arrives")
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD, "sacrificed at the next end step")


func test_sneak_attack_may_put_nothing() -> void:
	var sneak := put_battlefield(0, "Sneak Attack")
	var bears := give_hand(0, "Grizzly Bears")
	me.decline = true
	add_mana(0, R)
	assert_ok(g.activate_ability(0, sneak, 0, []))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.HAND)


func test_sneak_attack_with_no_creature_card_does_nothing() -> void:
	var sneak := put_battlefield(0, "Sneak Attack")
	var forest := give_hand(0, "Forest")
	add_mana(0, R)
	assert_ok(g.activate_ability(0, sneak, 0, []))   # legal, and nothing to put
	resolve_stack()
	assert_eq(forest.zone, Mtg.Zone.HAND)
	assert_eq(me.asked.size(), 0, "nothing to ask")


func test_sneak_attack_does_not_sacrifice_a_creature_it_no_longer_controls() -> void:
	var sneak := put_battlefield(0, "Sneak Attack")
	var bears := give_hand(0, "Grizzly Bears")
	add_mana(0, R)
	assert_ok(g.activate_ability(0, sneak, 0, []))
	resolve_stack()
	g.change_control(bears, 1)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "CR 603.7d: you sacrifice only what you control")


# -------------------------------------------------------------- Greater Good --

func test_greater_good_draws_the_sacrificed_power_then_discards_three() -> void:
	var good := put_battlefield(0, "Greater Good")
	put_battlefield(0, "Glorious Anthem")
	var giant := put_battlefield(0, "Hill Giant")
	me.prefer = ["Hill Giant"]
	assert_ok(g.activate_ability(0, good, 0, []))
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "sacrificed as the cost")
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 1, "draws 4 (its power with the Anthem), discards 3")


func test_greater_good_needs_a_creature() -> void:
	var good := put_battlefield(0, "Greater Good")
	assert_refused(g.activate_ability(0, good, 0, []))


# ------------------------------------------------------------ Martyr's Cause --

func test_martyrs_cause_prevents_the_chosen_sources_next_damage() -> void:
	var cause := put_battlefield(0, "Martyr's Cause")
	var bears := put_battlefield(0, "Grizzly Bears")
	_priority(1)
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	_priority(0)
	me.prefer = ["Grizzly Bears", "Lightning Bolt"]
	assert_ok(g.activate_ability(0, cause, 0, [TargetRef.player(0)]))
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "a creature is sacrificed as the cost")
	resolve_stack()
	assert_eq(g.players[0].life, 20)


# ----------------------------------------------------- Phyrexian Reclamation --

func test_phyrexian_reclamation_buys_back_a_creature_card_for_two_life() -> void:
	var reclamation := put_battlefield(0, "Phyrexian Reclamation")
	var wurm := _in_graveyard(0, "Craw Wurm")
	var bolt := _in_graveyard(0, "Lightning Bolt")
	add_mana(0, B, 2)
	assert_refused(g.activate_ability(0, reclamation, 0, [TargetRef.card(bolt)]))
	assert_ok(g.activate_ability(0, reclamation, 0, [TargetRef.card(wurm)]))
	assert_eq(g.players[0].life, 18)
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.HAND)


# ------------------------------------------------------------- Ghitu War Cry --

func test_ghitu_war_cry_pumps_any_creature() -> void:
	var cry := put_battlefield(0, "Ghitu War Cry")
	var theirs := put_battlefield(1, "Grizzly Bears")
	add_mana(0, R, 2)
	assert_ok(g.activate_ability(0, cry, 0, [TargetRef.card(theirs)]))
	assert_ok(g.activate_ability(0, cry, 0, [TargetRef.card(theirs)]))
	resolve_stack()
	assert_eq(_pt(theirs), [4, 2])


# ----------------------------------------------------------------- Abundance --

func test_abundance_reveals_until_a_land_and_bottoms_the_rest() -> void:
	put_battlefield(0, "Abundance")
	var bears := _on_top(0, "Grizzly Bears")
	var giant := _on_top(0, "Hill Giant")
	me.option = "Reveal until a land"
	var hand := g.players[0].hand.size()
	g.draw_cards(0, 1)
	assert_eq(g.players[0].hand.size(), hand + 1)
	assert_eq(g.players[0].hand[-1].data.card_name, "Forest")
	var library := g.players[0].library
	assert_true(library.slice(0, 2).has(bears), "the revealed rest on the bottom")
	assert_true(library.slice(0, 2).has(giant))


func test_abundance_reveals_until_a_nonland() -> void:
	put_battlefield(0, "Abundance")
	var giant := _on_top(0, "Hill Giant")
	_on_top(0, "Forest")
	_on_top(0, "Forest")
	me.option = "Reveal until a nonland card"
	var size := g.players[0].library.size()
	g.draw_cards(0, 1)
	assert_eq(giant.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].library.size(), size - 1)
	assert_eq(g.players[0].drawn_this_turn.size(), 0, "putting it into the hand is not a draw")


func test_abundance_may_simply_draw() -> void:
	put_battlefield(0, "Abundance")
	var giant := _on_top(0, "Hill Giant")
	me.option = "Draw the card"
	g.draw_cards(0, 1)
	assert_eq(giant.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].drawn_this_turn.size(), 1)


func test_abundance_only_replaces_its_controllers_draws() -> void:
	put_battlefield(0, "Abundance")
	var giant := _on_top(1, "Hill Giant")
	g.draw_cards(1, 1)
	assert_eq(giant.zone, Mtg.Zone.HAND)
	assert_eq(foe.asked.size(), 0)


func test_abundance_with_an_empty_library_reveals_nothing_and_does_not_lose() -> void:
	put_battlefield(0, "Abundance")
	for card in g.players[0].library: card.zone = Mtg.Zone.EXILE
	g.players[0].library.clear()
	me.option = "Reveal until a land"
	g.draw_cards(0, 1)
	g.check_state_based_actions()
	assert_false(g.game_over, "the draw was replaced: nothing was drawn from an empty library")


func test_abundance_hint_wants_a_land_when_short_of_them() -> void:
	put_battlefield(0, "Abundance")
	_on_top(0, "Hill Giant")
	var hand := g.players[0].hand.size()
	g.draw_cards(0, 1)   # the seat follows the hint: no land in hand, none in play
	assert_eq(g.players[0].hand.size(), hand + 1)
	assert_eq(g.players[0].hand[-1].data.card_name, "Forest")


## The draw step's draw is a turn-based action: Pack 10 E11 holds the
## question for a human seat (MtgGame._hold_draw_step) and replays the step
## with the answer.
func test_abundance_in_the_draw_step_holds_a_human_seat() -> void:
	put_battlefield(0, "Abundance")
	var giant := _on_top(0, "Hill Giant")
	advance_to_next_turn()
	g.agents[0] = HumanAgent.new()
	g.interactive_choices = true
	var guard := 0
	while g.awaiting_choice == null and not g.game_over and guard < 200 \
			and not (g.active_player == 0 and g.current_step() == Mtg.Step.MAIN1):
		_advance_once()
		guard += 1
	assert_not_null(g.awaiting_choice, "the player is asked in the draw step")
	if g.awaiting_choice == null: return
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.OPTION)
	assert_true(g.awaiting_choice.prompt.begins_with("Abundance"))
	assert_eq(g.current_step(), Mtg.Step.DRAW)
	assert_ok(g.answer_choice(2))   # reveal until a nonland card
	g.interactive_choices = false
	g.agents[0] = me
	assert_eq(giant.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].drawn_this_turn.size(), 0, "revealed, not drawn")
	assert_eq(g.unanswered_choices.size(), 0, "the player answered it")
