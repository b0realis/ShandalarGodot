extends GameTest
## Pack 9 (the Tempest block), batch B10: the Stronghold artifacts in
## cards/sets/sth/_artifacts.gd — Bullwhip, Ensnaring Bridge, Horn of Greed,
## Hornet Cannon, Jinxed Ring, Portcullis, Shifting Wall, Sword of the
## Chosen and Volrath's Laboratory, including the 1997 tapped-artifact rule.

const CLAIMED := ["Bullwhip", "Ensnaring Bridge", "Horn of Greed", "Hornet Cannon", "Jinxed Ring",
	"Portcullis", "Shifting Wall", "Sword of the Chosen", "Volrath's Laboratory"]
const TYPES := preload("res://engine/core/creature_types.gd")

## Answers a colour ask with [member color] and an option ask with the
## label [member option] when it is offered.
class Seat extends DecisionAgent:
	var color := -1
	var option := ""
	func answer_color(g: MtgGame, pid: int, prompt: String, hint: int) -> int:
		return color if color >= 0 else super(g, pid, prompt, hint)
	func answer_option(g: MtgGame, pid: int, prompt: String, options: Array[String], hint: int) -> int:
		var at := options.find(option)
		return at if at >= 0 else super(g, pid, prompt, options, hint)

func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)

func _pt(i: CardInstance) -> Array: return [i.cur_power, i.cur_toughness]

func _respond(pid: int) -> void:
	if g.priority_player != pid: assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.priority_player, pid)

func _tokens(pid: int, card_name: String) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if i.is_token and i.data.card_name == card_name: out.append(i)
	return out


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


# -------------------------------------------------------------------- Bullwhip --

func test_bullwhip_pings_and_forces_the_attack() -> void:
	var whip := put_battlefield(0, "Bullwhip")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, whip, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.damage, 1)
	assert_true(whip.tapped)
	assert_true(bear.must_attack_this_turn)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, []))
	assert_ok(g.declare_attackers(0, [bear.id]))

func test_bullwhip_on_the_opponents_creature_during_their_turn() -> void:
	var whip := put_battlefield(0, "Bullwhip")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_next_turn()   # P1's turn, main phase one
	_respond(0)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, whip, 0, [TargetRef.card(giant)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(1, []), "Hill Giant")
	assert_ok(g.declare_attackers(1, [giant.id]))

func test_bullwhip_killing_its_target_forces_nothing() -> void:
	var whip := put_battlefield(0, "Bullwhip")
	var elves := put_battlefield(1, "Llanowar Elves")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, whip, 0, [TargetRef.card(elves)]))
	resolve_stack()
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)
	assert_false(elves.must_attack_this_turn)

func test_bullwhip_needs_two_mana_and_to_be_untapped() -> void:
	var whip := put_battlefield(0, "Bullwhip")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_refused(g.activate_ability(0, whip, 0, [TargetRef.card(bear)]))
	g.tap_permanent(whip)
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_refused(g.activate_ability(0, whip, 0, [TargetRef.card(bear)]))


# ------------------------------------------------------------ Ensnaring Bridge --

func test_ensnaring_bridge_stops_creatures_bigger_than_your_hand() -> void:
	put_battlefield(0, "Ensnaring Bridge")
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	give_hand(0, "Forest")
	give_hand(0, "Forest")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	g.recalculate()
	assert_eq(g.players[0].hand.size(), 2)
	assert_refused(g.declare_attackers(0, [giant.id]))
	assert_ok(g.declare_attackers(0, [bear.id]))

func test_ensnaring_bridge_reads_its_controllers_hand_for_both_sides() -> void:
	put_battlefield(0, "Ensnaring Bridge")
	var giant := put_battlefield(1, "Hill Giant")
	var elves := put_battlefield(1, "Llanowar Elves")
	for _k in 5: give_hand(1, "Forest")
	g.recalculate()
	assert_true(giant.cur_cant_attack, "P0's empty hand, not P1's five cards")
	assert_true(elves.cur_cant_attack, "power 1 > 0 cards")
	give_hand(0, "Forest")
	g.recalculate()
	assert_false(elves.cur_cant_attack)

## Live hand size, with no test-side recalculation: a card drawn in the
## draw step lets the Giant through; a card cast from the hand shuts it out.
func test_ensnaring_bridge_reads_the_hand_when_attackers_are_declared() -> void:
	put_battlefield(0, "Ensnaring Bridge")
	var giant := put_battlefield(0, "Hill Giant")
	give_hand(0, "Forest")
	give_hand(0, "Forest")
	advance_to_next_turn()   # P1's turn
	advance_to_next_turn()   # P0's: three cards after the draw
	assert_eq(g.players[0].hand.size(), 3)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))

func test_ensnaring_bridge_a_card_played_from_hand_counts_at_once() -> void:
	put_battlefield(0, "Ensnaring Bridge")
	var giant := put_battlefield(0, "Hill Giant")
	give_hand(0, "Forest")
	give_hand(0, "Forest")
	var land := give_hand(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	g.recalculate()
	assert_false(giant.cur_cant_attack, "three cards")
	assert_ok(g.play_land(0, land))
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [giant.id]))

func test_ensnaring_bridge_a_discard_counts_at_once() -> void:
	put_battlefield(0, "Ensnaring Bridge")
	var giant := put_battlefield(0, "Hill Giant")
	var cards: Array[CardInstance] = []
	for _k in 3: cards.append(give_hand(0, "Forest"))
	g.recalculate()
	assert_false(giant.cur_cant_attack)
	g.discard_cards(0, [cards[0]])
	assert_true(giant.cur_cant_attack, "two cards now, with no other recalculation")

func test_ensnaring_bridge_tapped_stops_under_the_1997_rule() -> void:
	g.rules.tapped_artifacts_stop = true
	var bridge := put_battlefield(0, "Ensnaring Bridge")
	var giant := put_battlefield(0, "Hill Giant")
	g.recalculate()
	assert_true(giant.cur_cant_attack)
	g.tap_permanent(bridge)
	g.recalculate()
	assert_false(giant.cur_cant_attack, "a tapped artifact's continuous effect ceases")
	g.rules.tapped_artifacts_stop = false
	g.recalculate()
	assert_true(giant.cur_cant_attack, "modern rules: tapping does nothing")


# --------------------------------------------------------------- Horn of Greed --

func test_horn_of_greed_draws_for_whoever_plays_a_land() -> void:
	put_battlefield(1, "Horn of Greed")
	advance_to_step(Mtg.Step.MAIN1)
	var land := give_hand(0, "Forest")
	var hand := g.players[0].hand.size()
	assert_ok(g.play_land(0, land))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand, "the land left, a card came")
	var p1 := g.players[1].hand.size()
	put_battlefield(1, "Forest")   # put onto the battlefield, not played
	resolve_stack()
	assert_eq(g.players[1].hand.size(), p1)


# --------------------------------------------------------------- Hornet Cannon --

func test_hornet_cannon_makes_a_hasty_hornet_that_dies_at_end_step() -> void:
	var cannon := put_battlefield(0, "Hornet Cannon")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, cannon, 0, []))
	resolve_stack()
	var hornets := _tokens(0, "Hornet")
	assert_eq(hornets.size(), 1)
	var hornet := hornets[0]
	assert_eq(_pt(hornet), [1, 1])
	assert_true(hornet.is_type(Mtg.CardType.ARTIFACT))
	assert_true(hornet.has_subtype("insect"))
	assert_true(hornet.has_keyword(Mtg.Keyword.FLYING))
	assert_true(hornet.has_keyword(Mtg.Keyword.HASTE))
	assert_eq(hornet.cur_colors, 0)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [hornet.id]))
	advance_to_next_turn()
	assert_eq(_tokens(0, "Hornet").size(), 0, "destroyed at the end step")

func test_hornet_cannon_needs_three() -> void:
	var cannon := put_battlefield(0, "Hornet Cannon")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, cannon, 0, []))


# ----------------------------------------------------------------- Jinxed Ring --

func test_jinxed_ring_burns_for_your_nontoken_permanents() -> void:
	put_battlefield(0, "Jinxed Ring")
	var bear := put_battlefield(0, "Grizzly Bears")
	var forest := put_battlefield(0, "Forest")
	var theirs := put_battlefield(1, "Gray Ogre")
	var token: CardInstance = g.create_token(0, CardData.new("Saproling", "", Mtg.CardType.CREATURE).pt(1, 1))[0]
	advance_to_step(Mtg.Step.MAIN1)
	g.destroy(bear)
	resolve_stack()
	assert_eq(g.players[0].life, 19)
	g.destroy(forest)
	resolve_stack()
	assert_eq(g.players[0].life, 18, "any nontoken permanent")
	g.destroy(token)
	g.destroy(theirs)
	resolve_stack()
	assert_eq(g.players[0].life, 18, "neither a token nor the opponent's card")
	assert_eq(g.players[1].life, 20)

func test_jinxed_ring_bounced_permanent_does_not_count() -> void:
	put_battlefield(0, "Jinxed Ring")
	var bear := put_battlefield(0, "Grizzly Bears")
	g.return_to_hand(bear)
	resolve_stack()
	assert_eq(g.players[0].life, 20)

func test_jinxed_ring_itself_going_to_the_graveyard() -> void:
	var ring := put_battlefield(0, "Jinxed Ring")
	advance_to_step(Mtg.Step.MAIN1)
	g.destroy(ring)
	resolve_stack()
	assert_eq(g.players[0].life, 19, "it looks back (CR 603.10a)")

func test_jinxed_ring_given_away_for_a_creature() -> void:
	var ring := put_battlefield(0, "Jinxed Ring")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, ring, 0, [TargetRef.player(0)]))
	assert_ok(g.activate_ability(0, ring, 0, [TargetRef.player(1)]))
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "sacrificed as the cost")
	resolve_stack()
	assert_eq(g.players[0].life, 19, "the sacrificed Bears were P0's")
	assert_eq(ring.controller_id, 1)
	var ogre := put_battlefield(1, "Gray Ogre")
	g.destroy(ogre)
	resolve_stack()
	assert_eq(g.players[1].life, 19, "now P1's graveyard and P1's Ring")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(ring.controller_id, 1, "indefinitely")

func test_jinxed_ring_needs_a_creature_to_sacrifice() -> void:
	var ring := put_battlefield(0, "Jinxed Ring")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, ring, 0, [TargetRef.player(1)]))
	assert_eq(ring.controller_id, 0)


# ------------------------------------------------------------------ Portcullis --

func test_portcullis_exiles_a_third_creature_and_returns_it() -> void:
	var gate := put_battlefield(0, "Portcullis")
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Gray Ogre")
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(1, "Hill Giant")
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.EXILE)
	g.destroy(gate)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(giant.controller_id, 1, "under its owner's control")

func test_portcullis_lets_the_first_two_in() -> void:
	put_battlefield(0, "Portcullis")
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	resolve_stack()
	var ogre := put_battlefield(1, "Gray Ogre")
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(ogre.zone, Mtg.Zone.BATTLEFIELD, "only one other creature")

func test_portcullis_rechecks_as_it_resolves() -> void:
	put_battlefield(0, "Portcullis")
	var bear := put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Gray Ogre")
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(1, "Hill Giant")
	assert_false(g.stack.is_empty())
	g.destroy(bear)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "the intervening if failed (CR 603.4)")

func test_portcullis_gone_before_its_trigger_resolves_exiles_for_good() -> void:
	var gate := put_battlefield(0, "Portcullis")
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Gray Ogre")
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(1, "Hill Giant")
	g.destroy(gate)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.EXILE, "no Portcullis left to link it to")

func test_portcullis_exiled_token_is_gone() -> void:
	var gate := put_battlefield(0, "Portcullis")
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Gray Ogre")
	advance_to_step(Mtg.Step.MAIN1)
	var token: CardInstance = g.create_token(1, CardData.new("Saproling", "", Mtg.CardType.CREATURE).pt(1, 1))[0]
	resolve_stack()
	assert_false(g.players[1].battlefield.has(token))
	g.destroy(gate)
	resolve_stack()
	assert_false(g.players[1].battlefield.has(token))


# --------------------------------------------------------------- Shifting Wall --

func test_shifting_wall_enters_with_x_counters() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var wall := give_hand(0, "Shifting Wall")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, wall, [], 3))
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(int(wall.counters.get("+1/+1", 0)), 3)
	assert_eq(_pt(wall), [3, 3])
	assert_true(wall.has_keyword(Mtg.Keyword.DEFENDER))
	assert_true(wall.is_type(Mtg.CardType.ARTIFACT))

func test_shifting_wall_for_zero_dies() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var wall := give_hand(0, "Shifting Wall")
	assert_ok(g.cast_spell(0, wall, [], 0))
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD, "a 0/0 (CR 704.5f)")


# --------------------------------------------------------- Sword of the Chosen --

func test_sword_of_the_chosen_pumps_a_legend_only() -> void:
	var sword := put_battlefield(0, "Sword of the Chosen")
	var jedit := put_battlefield(0, "Jedit Ojanen")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, sword, 0, [TargetRef.card(bear)]))
	assert_ok(g.activate_ability(0, sword, 0, [TargetRef.card(jedit)]))
	resolve_stack()
	assert_eq(_pt(jedit), [7, 7])
	assert_true(sword.tapped)
	advance_to_next_turn()
	assert_eq(_pt(jedit), [5, 5])

func test_sword_of_the_chosen_is_itself_a_legend() -> void:
	var first := put_battlefield(0, "Sword of the Chosen")
	var second := put_battlefield(0, "Sword of the Chosen")
	g.check_state_based_actions()
	assert_eq(first.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD, "the newer one is buried")


# --------------------------------------------------------- Volrath's Laboratory --

func test_volraths_laboratory_makes_tokens_of_its_choice() -> void:
	var seat := Seat.new()
	seat.color = Mtg.ManaColor.R
	seat.option = "Goblin"
	g.set_agent(0, seat)
	advance_to_step(Mtg.Step.MAIN1)
	var lab := give_hand(0, "Volrath's Laboratory")
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.cast_spell(0, lab, []))
	resolve_stack()
	assert_eq(lab.memory.get("lab_type"), "goblin")
	assert_eq(int(lab.memory.get("lab_color")), Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.activate_ability(0, lab, 0, []))
	resolve_stack()
	var tokens := _tokens(0, "Goblin")
	assert_eq(tokens.size(), 1)
	assert_eq(_pt(tokens[0]), [2, 2])
	assert_eq(tokens[0].cur_colors, Mtg.ManaColor.R)
	assert_true(tokens[0].has_subtype("goblin"))
	assert_true(lab.tapped)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_refused(g.activate_ability(0, lab, 0, []), "")

func test_volraths_laboratory_token_survives_the_lab_leaving() -> void:
	var seat := Seat.new()
	seat.color = Mtg.ManaColor.G
	seat.option = "Elf"
	g.set_agent(0, seat)
	advance_to_step(Mtg.Step.MAIN1)
	var lab := give_hand(0, "Volrath's Laboratory")
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.cast_spell(0, lab, []))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.activate_ability(0, lab, 0, []))
	g.destroy(lab)
	resolve_stack()
	var tokens := _tokens(0, "Elf")
	assert_eq(tokens.size(), 1, "the choice was read with the cost (CR 608.2h)")
	assert_eq(tokens[0].cur_colors, Mtg.ManaColor.G)

func test_volraths_laboratory_the_default_choice_reads_the_board() -> void:
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Llanowar Elves")
	put_battlefield(0, "Scryb Sprites")
	var lab := put_battlefield(0, "Volrath's Laboratory")
	assert_eq(int(lab.memory.get("lab_color")), Mtg.ManaColor.G)
	assert_ne(String(lab.memory.get("lab_type", "")), "")
	assert_true(TYPES.ALL.has(String(lab.memory.get("lab_type")).capitalize()))
