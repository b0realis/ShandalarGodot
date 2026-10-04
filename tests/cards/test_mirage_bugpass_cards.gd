extends GameTest
## The Mirage-block bug pass of 2026-10-04, card fixes: Psychic Transfer's
## all-or-nothing exchange (CR 701.12a / 119.7), the live colour of a card in
## a hand (Sirocco, Lure of Prey under Celestial Dawn), the rules text of the
## block's keyword tokens (and Homelands' Wall of Kelp), the activation-menu
## text of abilities whose cost is not mana, Haunting Apparition's journaled
## choice, the "lose a card" asks that the fair AI answered with its BEST
## card (the ranked list now comes ORDERED, PlayerChoice.ordered), and Pygmy
## Hippo's hint under mana burn.


## Records each card ask (prompt, ordered/adverse flags) and answers with
## [member pick] when offered, else the first candidate; yes/no follows
## [member answers], then the hint.
class Scripted extends DecisionAgent:
	var answers: Array = []
	var picks: Array = []
	var asked: Array = []
	func answer_yes_no(_g: MtgGame, _p: int, prompt: String, hint: bool) -> bool:
		asked.append(prompt)
		return bool(answers.pop_front()) if not answers.is_empty() else hint
	func answer_card(_g: MtgGame, _p: int, candidates: Array[CardInstance], prompt: String) -> CardInstance:
		asked.append(prompt)
		if picks.is_empty(): return null if candidates.is_empty() else candidates[0]
		var want: Variant = picks.pop_front()
		for c in candidates:
			if c == want: return c
		return null


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-8", true)
	CardPacks.set_enabled("pack-4", true)   # Homelands: Wall of Kelp
	CardRegistry.ensure_loaded()
	super()

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-4", false)
	CardPacks.set_enabled("pack-8", false)


func fund(pid: int, card: CardInstance, x := 0) -> void:
	var cost := card.data.cost
	for c in cost.colored:
		add_mana(pid, c, int(cost.colored[c]))
	var generic := cost.generic + x * cost.x_count
	if generic > 0:
		add_mana(pid, Mtg.ManaColor.C, generic)


func cast(name: String, targets: Array = [], x := 0, pid := 0) -> CardInstance:
	var card := give_hand(pid, name)
	fund(pid, card, x)
	assert_ok(g.cast_spell(pid, card, targets, x))
	resolve_stack()
	return card


func _ai(seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, AiProfile.wizard())
	g.set_agent(seat, ai)
	return ai


func _tokens(pid: int, name: String) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for inst in g.players[pid].battlefield:
		if inst.is_token and inst.data.card_name == name: out.append(inst)
	return out


## From turn 1 (ours) to our next turn's draw step: our upkeep triggers
## have resolved by then, and seat 1's draws never touch our library.
func _to_our_next_draw() -> void:
	var guard := 0
	while not (g.active_player == 0 and g.turn_number > 1 and g.current_step() == Mtg.Step.DRAW) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)


# ================================================= H2-05 Psychic Transfer --

## CR 701.12a: if the entire exchange can't be completed, no part of it
## occurs; CR 119.7: a player who can't gain life can't be given a higher
## total by it. Forsaken Wastes: "Players can't gain life."
func test_psychic_transfer_does_not_half_exchange_when_the_target_cant_gain() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(1, "Forsaken Wastes")
	g.players[1].life = 16
	cast("Psychic Transfer", [TargetRef.player(1)])
	assert_eq(g.players[0].life, 20, "no exchange: the target can't gain life, so the caster keeps 20")
	assert_eq(g.players[1].life, 16)


func test_psychic_transfer_does_not_half_exchange_when_the_caster_cant_gain() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Forsaken Wastes")
	g.players[0].life = 16
	cast("Psychic Transfer", [TargetRef.player(1)])
	assert_eq(g.players[0].life, 16)
	assert_eq(g.players[1].life, 20, "no exchange: the caster can't gain life, so the target keeps 20")


func test_psychic_transfer_still_exchanges_without_the_wastes() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	g.players[1].life = 16
	cast("Psychic Transfer", [TargetRef.player(1)])
	assert_eq([g.players[0].life, g.players[1].life], [16, 20])


# ============================================ H2-06 live colour in a hand --

## Celestial Dawn: "nonland cards you own that aren't on the battlefield
## ... are white" (layer 5 outside the battlefield). Sirocco asks for a
## BLUE instant card: a Counterspell Celestial Dawn made white is not one.
func test_sirocco_spares_a_counterspell_celestial_dawn_made_white() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var foe := Scripted.new()
	foe.answers = [false]   # would discard if asked
	g.set_agent(1, foe)
	put_battlefield(1, "Celestial Dawn")
	var counter := give_hand(1, "Counterspell")
	g.recalculate()
	assert_false(counter.has_color(Mtg.ManaColor.U), "precondition: the card in hand is white")
	cast("Sirocco", [TargetRef.player(1)])
	assert_eq(counter.zone, Mtg.Zone.HAND, "a WHITE instant card is not a blue instant card")
	assert_eq(g.players[1].life, 20, "and nothing was offered for it")
	assert_eq(foe.asked, [])


func test_sirocco_still_takes_a_blue_instant() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var foe := Scripted.new()
	foe.answers = [false]
	g.set_agent(1, foe)
	var counter := give_hand(1, "Counterspell")
	cast("Sirocco", [TargetRef.player(1)])
	assert_eq(counter.zone, Mtg.Zone.GRAVEYARD)


func _lure_window() -> void:
	# Lure of Prey: "Cast this spell only if an opponent cast a creature
	# spell this turn" — seat 1 casts a Bears, then seat 0 has priority.
	advance_to_next_turn()
	var bears := give_hand(1, "Grizzly Bears")
	add_mana(1, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(1, bears, []))
	resolve_stack()
	assert_ok(g.pass_priority(1))


func test_lure_of_prey_cannot_put_a_creature_celestial_dawn_made_white() -> void:
	var me := Scripted.new()
	g.set_agent(0, me)
	put_battlefield(0, "Celestial Dawn")
	_lure_window()
	var elves := give_hand(0, "Llanowar Elves")
	g.recalculate()
	me.picks = [elves]
	var lure := give_hand(0, "Lure of Prey")
	add_mana(0, Mtg.ManaColor.W, 4)   # Celestial Dawn: white pays as any colour
	assert_ok(g.cast_spell(0, lure, []))
	resolve_stack()
	assert_eq(elves.zone, Mtg.Zone.HAND, "under Celestial Dawn the Elves card is white, not green")


func test_lure_of_prey_still_puts_a_green_creature() -> void:
	var me := Scripted.new()
	g.set_agent(0, me)
	_lure_window()
	var elves := give_hand(0, "Llanowar Elves")
	me.picks = [elves]
	var lure := give_hand(0, "Lure of Prey")
	add_mana(0, Mtg.ManaColor.G, 4)
	assert_ok(g.cast_spell(0, lure, []))
	resolve_stack()
	assert_eq(elves.zone, Mtg.Zone.BATTLEFIELD)


# ================================================ H1-F2 token rules text --

## The card preview prints a token's `oracle_text`, or "(no rules text)"
## when it is empty (game/duel/card_preview.gd).
func test_basalt_golems_wall_token_says_defender() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var golem := put_battlefield(0, "Basalt Golem")
	var wall := put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [golem.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: golem.id}))
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	var tokens := _tokens(1, "Wall")
	assert_eq(tokens.size(), 1)
	if tokens.is_empty(): return
	assert_true(tokens[0].has_keyword(Mtg.Keyword.DEFENDER))
	assert_eq(tokens[0].data.oracle_text, "Defender")


func test_wall_of_kelps_token_says_defender() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var kelp := put_battlefield(0, "Wall of Kelp")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.activate_ability(0, kelp, 0))
	resolve_stack()
	var tokens := _tokens(0, "Kelp")
	assert_eq(tokens.size(), 1)
	if tokens.is_empty(): return
	assert_eq(tokens[0].data.oracle_text, "Defender")


func test_sacred_mesas_pegasus_says_flying() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var mesa := put_battlefield(0, "Sacred Mesa")
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, mesa, 0))
	resolve_stack()
	var tokens := _tokens(0, "Pegasus")
	assert_eq(tokens.size(), 1)
	if tokens.is_empty(): return
	assert_eq(tokens[0].data.oracle_text, "Flying")


func test_goblin_scouts_say_mountainwalk() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	cast("Goblin Scouts")
	var tokens := _tokens(0, "Goblin Scout")
	assert_eq(tokens.size(), 3)
	if tokens.is_empty(): return
	assert_eq(tokens[0].data.oracle_text, "Mountainwalk")


func test_afterlifes_spirit_says_flying() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bears := put_battlefield(1, "Grizzly Bears")
	cast("Afterlife", [TargetRef.card(bears)])
	var tokens := _tokens(1, "Spirit")
	assert_eq(tokens.size(), 1)
	if tokens.is_empty(): return
	assert_eq(tokens[0].data.oracle_text, "Flying")


func test_giant_caterpillars_butterfly_says_flying() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var caterpillar := put_battlefield(0, "Giant Caterpillar")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, caterpillar, 0, []))
	resolve_stack()
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	var tokens := _tokens(0, "Butterfly")
	assert_eq(tokens.size(), 1)
	if tokens.is_empty(): return
	assert_eq(tokens[0].data.oracle_text, "Flying")


# ======================================== H5-F5 activation-menu cost text --

## The ability menu shows ActivatedAbility.text. These three were built by
## F._ability, which writes only the MANA and {T} part of the cost.
func test_menu_text_of_the_three_weatherlight_abilities_is_their_oracle_line() -> void:
	for name in ["Orcish Settlers", "Llanowar Druid", "Soul Shepherd"]:
		var card := CardRegistry.get_card(name)
		assert_eq(card.activated_abilities.size(), 1, name)
		assert_eq(card.activated_abilities[0].text, card.oracle_text, name)


## The whole block: an ability whose cost sacrifices, exiles or returns its
## source, exiles a graveyard card or pays life names that in its menu text.
func test_every_mirage_block_ability_names_its_non_mana_cost() -> void:
	var missing: Array[String] = []
	for set_code in ["mir", "vis", "wth"]:
		for name in CardRegistry.names_in_set(set_code):
			var card := CardRegistry.get_card(name)
			if card == null: continue
			for a: ActivatedAbility in card.activated_abilities:
				var text := a.text.to_lower()
				if a.sacrifice_cost and text.find("sacrifice") < 0: missing.append(name + ": sacrifice")
				if a.exile_cost and text.find("exile") < 0: missing.append(name + ": exile")
				if a.return_cost and text.find("return") < 0: missing.append(name + ": return")
				if a.graveyard_exile_filter.is_valid() and text.find("exile") < 0: missing.append(name + ": graveyard exile")
				if a.life_cost > 0 and text.find("life") < 0: missing.append(name + ": life")
	assert_eq(missing, [] as Array[String])


# ============================================ H1-S3 Haunting Apparition --

## "As this creature enters, choose an opponent" is written to the card's
## memory: through the journal, so an AI search that puts it onto the
## battlefield rewinds it. (Cast, its own resolution records the card whole
## — MtgGame._rec_resolution — so the hole was an arrival by ANOTHER card's
## resolution: Flash, Lure of Prey.)
func test_haunting_apparitions_choice_rewinds_with_the_search() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var seat := Scripted.new()
	seat.answers = [true, true]   # put it in; pay {U}{B} to keep it
	g.set_agent(0, seat)
	var ghost := give_hand(0, "Haunting Apparition")
	var flash := give_hand(0, "Flash")
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	var mark := g.make_mark()
	assert_ok(g.cast_spell(0, flash, []))
	resolve_stack()
	assert_eq(ghost.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(ghost.memory.has("chosen_player"), "precondition: chosen as it entered")
	g.unmake_to(mark)
	g.end_search()
	assert_eq(ghost.zone, Mtg.Zone.HAND)
	assert_false(ghost.memory.has("chosen_player"), "the rewind takes the choice back")


# ===================================== H7-F3 "lose a card" asks, ordered --

func test_wildebeests_returns_the_cheapest_green_creature() -> void:
	_ai(0)
	var beest := put_battlefield(0, "Stampeding Wildebeests")
	var wall := put_battlefield(0, "Wall of Roots")
	_to_our_next_draw()
	assert_eq(beest.zone, Mtg.Zone.BATTLEFIELD, "the AI kept its 5/4 trampler")
	assert_eq(wall.zone, Mtg.Zone.HAND, "and returned the Wall of Roots (the card's least valuable first)")


func test_the_ranked_ask_comes_ordered() -> void:
	var seat := Scripted.new()
	g.set_agent(0, seat)
	put_battlefield(0, "Stampeding Wildebeests")
	put_battlefield(0, "Wall of Roots")
	_to_our_next_draw()
	var found := false
	for choice: PlayerChoice in g.choice_log:
		if choice.kind == PlayerChoice.Kind.CARD and choice.prompt.begins_with("Return a green creature"):
			found = true
			assert_true(choice.ordered, "the candidates come ranked for the seat")
			assert_eq(choice.hint, choice.candidates[0])
	assert_true(found)


func test_shrieking_drake_returns_itself_not_our_angel() -> void:
	_ai(0)
	var angel := put_battlefield(0, "Serra Angel")
	var drake := give_hand(0, "Shrieking Drake")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, drake, []))
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(drake.zone, Mtg.Zone.HAND)


func _plant_library(pid: int, names: Array) -> Dictionary:
	# The LAST name ends on top.
	var lib: Array = g.players[pid].library
	var cards := {}
	for n in names:
		var c := _make_instance(pid, n)
		c.zone = Mtg.Zone.LIBRARY
		lib.append(c)
		cards[n] = c
	return cards


func test_preferred_selection_buries_the_weaker_card() -> void:
	_ai(0)
	for _i in 5: put_battlefield(0, "Forest")
	put_battlefield(0, "Preferred Selection")
	var cards := _plant_library(0, ["Serra Angel", "Forest"])   # top: Forest
	_to_our_next_draw()
	var lib: Array = g.players[0].library
	assert_ne(lib.find(cards["Serra Angel"]), 0, "the Serra Angel is not on the bottom")
	assert_eq(lib.find(cards["Forest"]), 0, "the sixth Forest is")


func test_flash_puts_in_the_creature_it_can_pay_for() -> void:
	_ai(0)
	put_battlefield(0, "Forest")
	put_battlefield(0, "Mountain")
	var bears := give_hand(0, "Grizzly Bears")    # {1}{G} - {2} = {G}: payable
	var shivan := give_hand(0, "Shivan Dragon")   # {4}{R}{R} - {2} = {2}{R}{R}: not
	var flash := give_hand(0, "Flash")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, flash, []))
	resolve_stack()
	assert_eq(shivan.zone, Mtg.Zone.HAND, "the unpayable Dragon was not put in and sacrificed")
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)


func test_sealed_fate_leaves_their_worst_card_on_top() -> void:
	_ai(0)
	var cards := _plant_library(1, ["Grizzly Bears", "Forest", "Serra Angel"])   # top: Serra Angel
	var fate := give_hand(0, "Sealed Fate")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, fate, [TargetRef.player(1)], 3))
	resolve_stack()
	assert_eq(cards["Serra Angel"].zone, Mtg.Zone.EXILE)
	var lib: Array = g.players[1].library
	assert_eq(lib.back(), cards["Forest"], "their Forest, not their Bears, goes back on top")


func test_dream_cache_keeps_our_best_card() -> void:
	_ai(0)
	var angel := give_hand(0, "Serra Angel")
	var cache := give_hand(0, "Dream Cache")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, cache, []))
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.HAND, "two of the three drawn Forests went, not the Angel")
	assert_eq(g.players[0].hand.size(), 2)


# ============================================ H7-F1 Pygmy Hippo, mana burn --

## Hippo (P0, an AI) attacks P1 unblocked; the trigger resolves.
func _hippo_unblocked(hippo: CardInstance) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [hippo.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	resolve_stack()


func _untapped(pid: int) -> int:
	var n := 0
	for i in g.players[pid].battlefield:
		if i.is_land() and not i.tapped: n += 1
	return n


func test_hippo_declines_mana_it_cannot_spend_under_mana_burn() -> void:
	g.rules.set_edition("fifth")
	assert_true(g.rules.mana_burn)
	_ai(0)
	var hippo := put_battlefield(0, "Pygmy Hippo")
	for _i in 8: put_battlefield(1, "Plains")
	g.players[0].life = 4
	_hippo_unblocked(hippo)
	assert_eq(_untapped(1), 8, "the AI declined: eight {C} with nothing to spend them on is 8 burn")
	advance_to_step(Mtg.Step.END)
	assert_false(g.game_over)
	assert_eq(g.players[0].life, 4, "no mana burn")
	assert_eq(g.players[1].life, 18, "the Hippo assigned its combat damage instead")


func test_hippo_takes_mana_it_can_spend_under_mana_burn() -> void:
	g.rules.mana_burn = true
	_ai(0)
	var hippo := put_battlefield(0, "Pygmy Hippo")
	put_battlefield(0, "Mountain")
	give_hand(0, "Hill Giant")   # {3}{R}: the three {C} plus our Mountain
	for _i in 3: put_battlefield(1, "Plains")
	_hippo_unblocked(hippo)
	assert_eq(_untapped(1), 0, "three mana a Hill Giant in hand will use is worth more than 2 damage")


## Fair information (CONTRIBUTING rule 8): the hint reads its OWN hand. The
## same Hill Giant in the opponent's hidden hand buys nothing.
func test_hippo_does_not_read_the_opponents_hand() -> void:
	g.rules.mana_burn = true
	_ai(0)
	var hippo := put_battlefield(0, "Pygmy Hippo")
	put_battlefield(0, "Mountain")
	give_hand(1, "Hill Giant")
	for _i in 3: put_battlefield(1, "Plains")
	_hippo_unblocked(hippo)
	assert_eq(_untapped(1), 3, "nothing of ours spends the three {C}")


func test_hippo_never_takes_a_haul_that_could_burn_it_to_death() -> void:
	g.rules.mana_burn = true
	_ai(0)
	var hippo := put_battlefield(0, "Pygmy Hippo")
	put_battlefield(0, "Mountain")
	give_hand(0, "Hill Giant")
	for _i in 3: put_battlefield(1, "Plains")
	g.players[0].life = 3
	_hippo_unblocked(hippo)
	assert_eq(_untapped(1), 3, "three unspent {C} would be lethal at 3 life: not worth the risk")


func test_hippo_takes_the_mana_freely_without_mana_burn() -> void:
	g.rules.mana_burn = false
	_ai(0)
	var hippo := put_battlefield(0, "Pygmy Hippo")
	for _i in 8: put_battlefield(1, "Plains")
	g.players[0].life = 4
	_hippo_unblocked(hippo)
	assert_eq(_untapped(1), 0, "without mana burn unspent mana costs nothing")
