extends GameTest
## THE AFFECTED PLAYER CHOOSES AMONG APPLICABLE REPLACEMENTS (CR 616.1) —
## 2026-09-10.
##
## "If two or more replacement and/or prevention effects are attempting to
## modify the way an event affects an object or player, the affected
## object's controller or the affected player chooses one to apply" — and
## then the rule is applied again to what is left. Ours applied draw
## replacements in a FIXED order: one-shots first, then the battlefield
## statics in timestamp order.
##
## THE LEDGER ROW SAID IT WAS INVISIBLE. It is not. Chains of
## Mephistopheles catches every draw EXCEPT the first of your own draw
## step; Island Sanctuary offers to skip ANY draw in your own draw step. A
## Howling Mine's extra card is in your draw step and is not the first, so
## BOTH apply to it — and the two disagree completely:
##
##  * Chains first: you discard a card, and the card Chains gives back is a
##    NEW draw event, which Island Sanctuary then catches and skips. You are
##    a card down and have nothing to show for it.
##  * The Sanctuary first: the draw is skipped, the gates close, and the
##    card stays in your hand.
##
## Both cards are in the pool, both are castable in one deck, and Howling
## Mine is a 2ed rare. The question is asked from inside the Mine's own
## trigger resolution, so the §1.3 pre-flight can hold a human seat on it.
##
## The DAMAGE half of that ledger row is a separate finding and is NOT
## built — see the file footer.


## The reproduction, and both branches of the choice. The Watcher answers
## the CR 616.1 question with whichever index the test parked.
class Chooser extends DecisionAgent:
	var take := 0
	var asked: Array[String] = []
	func answer_option(_g: MtgGame, _pid: int, _prompt: String,
			options: Array[String], _hint: int) -> int:
		asked.append(", ".join(options))
		return take
	func answer_yes_no(_g: MtgGame, _pid: int, _prompt: String, _hint: bool) -> bool:
		return true      # the Sanctuary's "you may" is always taken here


func _board(take: int) -> Chooser:
	var chooser := Chooser.new()
	chooser.take = take
	g.set_agent(0, chooser)
	put_battlefield(0, "Chains of Mephistopheles")
	put_battlefield(0, "Island Sanctuary")
	put_battlefield(0, "Howling Mine")
	give_hand(0, "Grizzly Bears")
	advance_to_next_turn()      # P1's turn
	advance_to_next_turn()      # back to P0, past their draw step
	return chooser


func test_the_drawing_player_is_asked_when_two_replacements_apply() -> void:
	var chooser := _board(0)
	assert_eq(chooser.asked, ["Chains of Mephistopheles, Island Sanctuary"],
		"asked once, for the Mine's extra card — the only draw both catch")


## Taking the Chains: a card leaves the hand and nothing comes back,
## because the Chains' own replacement draw is a fresh event the Sanctuary
## is free to catch (CR 614.5 only stops a replacement re-applying to the
## SAME event).
func test_taking_the_chains_costs_the_card() -> void:
	_board(0)
	assert_eq(g.players[0].hand.size(), 0, "the Bears were discarded")
	assert_eq(g.players[0].graveyard.size(), 1)
	assert_eq(g.players[0].graveyard[0].data.card_name, "Grizzly Bears")


## Taking the Sanctuary: the draw is skipped, the Chains never apply to it
## (CR 616.1 is applied again only if the chosen effect did not replace the
## event), and the card stays.
func test_taking_the_sanctuary_keeps_the_card() -> void:
	_board(1)
	assert_eq(g.players[0].hand.size(), 1, "the Bears are still in hand")
	assert_eq(g.players[0].graveyard.size(), 0, "nothing was discarded")


## THE NULL: one applicable replacement is not a choice, and the seat is
## not asked. P0's own first draw of their draw step is exempt from the
## Chains, so only the Sanctuary applies to it.
func test_one_applicable_replacement_asks_nothing() -> void:
	var chooser := Chooser.new()
	g.set_agent(0, chooser)
	put_battlefield(0, "Chains of Mephistopheles")
	put_battlefield(0, "Island Sanctuary")
	give_hand(0, "Grizzly Bears")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(chooser.asked, [], "nobody was asked to order one effect")
	assert_eq(g.players[0].hand.size(), 1, "the Sanctuary skipped the draw alone")


## And the pure predicate really is pure: asking whether a replacement
## applies must not run it, or the candidate list would already have
## discarded a card before the question was put.
func test_the_applies_predicate_runs_nothing() -> void:
	var chains := put_battlefield(0, "Chains of Mephistopheles")
	give_hand(0, "Grizzly Bears")
	var ctx := {"player": 0, "in_draw_step": false, "draw_number": 1}
	assert_true(bool(chains.data.draw_replacement_applies.call(g, chains, 0, ctx)),
		"the Chains catch a draw outside a draw step")
	assert_eq(g.players[0].hand.size(), 1, "and asking cost nothing")
	assert_eq(g.players[0].graveyard.size(), 0)


## Every static draw replacement in the pool carries both halves — the
## engine cannot build a CR 616.1 candidate list without the predicate, and
## a card that shipped only the runner would be applied out of order for
## ever without anything noticing.
func test_every_draw_replacement_has_a_pure_predicate() -> void:
	var missing: Array[String] = []
	for card_name in CardRegistry.all_names():
		var data := CardRegistry.get_card(card_name)
		if data.draw_replacement.is_valid() \
				and not data.draw_replacement_applies.is_valid():
			missing.append(card_name)
	assert_eq(missing, [], "a draw replacement with no `applies` half")


# ============== THE DAMAGE HALF: SHIELD AGAINST SHIELD, RULED ==============
#
# The same ledger row names damage as well. The two tests below pin WHY
# ordering one SHIELD against another is a ruling rather than a shortcut:
# with the pool's own cards, which shield is consumed first cannot be told
# apart, so there is nothing to ask about.
#
# What IS observable — ordering a prevention against a REPLACEMENT (Nova
# Pentacle's redirect and its four siblings) — was written up at the site
# and left alone here, and BUILT on 2026-09-11: the damaged seat orders a
# packet aimed at a player (tests/unit/test_damage_gate_order_2026_09_11.gd)
# and the permanent's controller orders one aimed at a creature
# (tests/unit/test_creature_damage_gate_order_2026_09_11.gd). The decision
# point in front of every gate in the combat-damage path is what it cost,
# and it is paid for by an early-out rather than by the generic handler
# docs/forge/rules.md §4.2 says not to port.

## REASON ONE. No card writes the colour-keyed shield list, so two
## colour shields can never race: every Circle of Protection in the pool
## names ONE SOURCE (CR 615.1's "a source of your choice") and lands in the
## predicate list bound to that source's id.
func test_no_card_in_the_pool_writes_a_colour_shield() -> void:
	var cop := put_battlefield(0, "Circle of Protection: Red")
	var dragon := put_battlefield(1, "Shivan Dragon")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, cop, 0))
	resolve_stack()
	assert_eq(g.players[0].prevention_shields, ([] as Array[int]),
		"the colour list has no writer in this pool")
	assert_eq(g.players[0].prevention_shield_filters.size(), 1)
	assert_true(g.players[0].prevention_shield_filters[0]["filter"].call(dragon),
		"and the one entry is bound to the source it named")


## REASON TWO. The only pair that can co-apply is a one-shot Circle bound
## to source X and an ALL-TURN class shield that also matches X. Whichever
## is consumed, the all-turn shield covers every later packet from X too —
## so both orders end the turn with the same life total. Activated in both
## orders, which is how the two list orders arise.
func test_two_applicable_shields_are_the_same_either_way() -> void:
	for scarecrow_first in [true, false]:
		var life := _shield_race(scarecrow_first)
		assert_eq(life, 20,
			"both packets prevented whichever shield went first (scarecrow_first=%s)"
				% scarecrow_first)


## Scarecrow's all-turn anti-air up and a Circle of Protection: Red naming
## a Shivan Dragon — a red flier, so both shields match every packet it
## deals. They are activated in the given order, which is the order the
## list holds them in; the Dragon then deals two packets to the shielded
## seat. Returns that seat's life.
func _shield_race(scarecrow_first: bool) -> int:
	before_each()          # a fresh game per order
	var crow := put_battlefield(0, "Scarecrow")
	var cop := put_battlefield(0, "Circle of Protection: Red")
	var dragon := put_battlefield(1, "Shivan Dragon")
	advance_to_step(Mtg.Step.MAIN1)
	var order: Array[CardInstance] = []
	order.assign([crow, cop] if scarecrow_first else [cop, crow])
	for permanent in order:
		add_mana(0, Mtg.ManaColor.C, 6)
		assert_ok(g.activate_ability(0, permanent, 0))
		resolve_stack()
	assert_eq(g.players[0].prevention_shield_filters.size(), 2,
		"both shields are up")
	assert_true(
		g.players[0].prevention_shield_filters[0]["filter"].call(dragon)
		and g.players[0].prevention_shield_filters[1]["filter"].call(dragon),
		"and both of them match the Dragon")
	g.deal_damage(dragon, TargetRef.player(0), 4)
	g.deal_damage(dragon, TargetRef.player(0), 4)
	return g.players[0].life
