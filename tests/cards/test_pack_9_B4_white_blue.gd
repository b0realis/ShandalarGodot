extends GameTest
## Pack 9 (the Tempest block), batch B4: the white and blue Tempest
## creatures of cards/sets/tmp/_creatures.gd — Advance Scout, Auratog,
## Clergy en-Vec, Knight of Dawn, Marble Titan, Master Decoy, Orim,
## Escaped Shapeshifter, Fylamarid, Giant Crab, Manta Riders, Mawcor,
## Rootwater Diver, Rootwater Hunter, Tradewind Rider, Wind Dancer. Each
## test drives the card through the public API and pins the clause that
## makes it that card, with its refused case.

const CLAIMED := ["Advance Scout", "Auratog", "Clergy en-Vec", "Knight of Dawn",
	"Marble Titan", "Master Decoy", "Orim, Samite Healer", "Escaped Shapeshifter",
	"Fylamarid", "Giant Crab", "Manta Riders", "Mawcor", "Rootwater Diver",
	"Rootwater Hunter", "Tradewind Rider", "Wind Dancer"]


## FIFO answers; an empty queue falls back to the caller's hint.
class Scripted extends DecisionAgent:
	var colors: Array = []
	var options: Array = []
	var answers: Array = []
	var window := false

	func wants_damage_prevention_window() -> bool:
		return window

	func answer_color(_g: MtgGame, _p: int, _prompt: String, hint: int) -> int:
		return int(colors.pop_front()) if not colors.is_empty() else hint

	func answer_option(_g: MtgGame, _p: int, _prompt: String, _labels: Array[String], hint: int) -> int:
		return int(options.pop_front()) if not options.is_empty() else hint

	func answer_yes_no(_g: MtgGame, _p: int, _prompt: String, hint: bool) -> bool:
		return bool(answers.pop_front()) if not answers.is_empty() else hint


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

## Exactly the mana [param card]'s cost asks for.
func fund(pid: int, card: CardInstance) -> void:
	var cost := card.data.cost
	for c in cost.colored:
		add_mana(pid, c, int(cost.colored[c]))
	if cost.generic > 0:
		add_mana(pid, Mtg.ManaColor.C, cost.generic)

## [param pid] casts [param card_name] at [param targets] and keeps the
## stack (priority stays with the caster).
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


# --- Advance Scout ----------------------------------------------------------

func test_advance_scout_lends_first_strike_until_end_of_turn() -> void:
	var scout := put_battlefield(0, "Advance Scout")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_true(scout.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_refused(g.activate_ability(0, scout, 0, [TargetRef.card(bear)]), "mana")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.activate_ability(0, scout, 0, [TargetRef.card(bear)]))
	assert_false(scout.tapped, "no {T} in the cost")
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	advance_to_next_turn()
	assert_false(bear.has_keyword(Mtg.Keyword.FIRST_STRIKE))


# --- Auratog ----------------------------------------------------------------

func test_auratog_eats_an_enchantment_you_control_for_two_two() -> void:
	var tog := put_battlefield(0, "Auratog")
	put_battlefield(1, "Bad Moon")
	assert_refused(g.activate_ability(0, tog, 0), "enchantment")
	var crusade := put_battlefield(0, "Crusade")
	assert_eq([tog.cur_power, tog.cur_toughness], [2, 3], "Crusade's +1/+1 first")
	assert_ok(g.activate_ability(0, tog, 0))
	assert_eq(crusade.zone, Mtg.Zone.GRAVEYARD, "the sacrifice is a cost, paid at once")
	resolve_stack()
	assert_eq([tog.cur_power, tog.cur_toughness], [3, 4])


# --- Clergy en-Vec ----------------------------------------------------------

func test_clergy_en_vec_shields_one_point_and_must_be_able_to_tap() -> void:
	var sick := put_battlefield(0, "Clergy en-Vec", true)
	assert_refused(g.activate_ability(0, sick, 0, [TargetRef.player(0)]))
	var clergy := put_battlefield(0, "Clergy en-Vec")
	assert_ok(g.activate_ability(0, clergy, 0, [TargetRef.player(0)]))
	resolve_stack()
	cast("Lightning Bolt", [TargetRef.player(0)])
	assert_eq(g.players[0].life, 18, "3 - 1")
	assert_true(CardRegistry.get_card("Clergy en-Vec").activated_abilities[0].effects[0].is_damage_prevention)


# --- Knight of Dawn ---------------------------------------------------------

func test_knight_of_dawn_takes_protection_from_the_chosen_color() -> void:
	var p0 := seat(0)
	p0.colors = [Mtg.ManaColor.B]
	var knight := put_battlefield(0, "Knight of Dawn")
	assert_true(knight.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	add_mana(0, Mtg.ManaColor.W)
	assert_refused(g.activate_ability(0, knight, 0), "mana")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.activate_ability(0, knight, 0))
	resolve_stack()
	assert_eq(knight.cur_protection & Mtg.ManaColor.B, Mtg.ManaColor.B)
	assert_eq(knight.cur_protection & Mtg.ManaColor.R, 0, "one colour only")
	var terror := give_hand(1, "Terror")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.B, 2)
	assert_refused(g.cast_spell(1, terror, [TargetRef.card(knight)]))
	advance_to_next_turn()
	assert_eq(knight.cur_protection, 0, "until end of turn")

## The default seat follows the hint, and the hint reads the public stack:
## a black Terror aimed at the Knight is answered with protection from
## black (not the red the hint falls back to on an empty stack).
func test_knight_of_dawn_answers_a_terror_with_protection_from_black() -> void:
	var knight := put_battlefield(0, "Knight of Dawn")
	put_battlefield(1, "Mons's Goblin Raiders")
	var terror := cast_only("Terror", [TargetRef.card(knight)], 1)
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_ok(g.activate_ability(0, knight, 0))
	resolve_stack()
	assert_eq(terror.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(knight.cur_protection, Mtg.ManaColor.B)
	assert_eq(CardRegistry.get_card("Knight of Dawn").activated_abilities[0].effects[0].ai_role, &"self_bounce")


# --- Marble Titan -----------------------------------------------------------

func test_marble_titan_holds_every_creature_of_power_three_or_more() -> void:
	var titan := put_battlefield(0, "Marble Titan")
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	for i in [titan, giant, bear, theirs]: g.tap_permanent(i)
	advance_to_next_turn()
	assert_true(theirs.tapped, "their 3/3 stays tapped through their untap step")
	advance_to_next_turn()
	assert_true(giant.tapped)
	assert_true(titan.tapped, "the 3/3 Titan locks itself too")
	assert_false(bear.tapped, "a 2/2 untaps")
	g.destroy(titan)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_false(giant.tapped, "with the Titan gone the Giant untaps")


# --- Master Decoy -----------------------------------------------------------

func test_master_decoy_taps_a_creature_for_w_and_its_own_tap() -> void:
	var sick := put_battlefield(0, "Master Decoy", true)
	var decoy := put_battlefield(0, "Master Decoy")
	var giant := put_battlefield(1, "Hill Giant")
	add_mana(0, Mtg.ManaColor.W)
	assert_refused(g.activate_ability(0, sick, 0, [TargetRef.card(giant)]))
	assert_ok(g.activate_ability(0, decoy, 0, [TargetRef.card(giant)]))
	assert_true(decoy.tapped)
	resolve_stack()
	assert_true(giant.tapped)
	assert_refused(g.activate_ability(0, decoy, 0, [TargetRef.card(giant)]))


# --- Orim, Samite Healer ----------------------------------------------------

func test_orim_prevents_three_and_is_legendary() -> void:
	var orim := put_battlefield(0, "Orim, Samite Healer")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, orim, 0, [TargetRef.card(bear)]))
	resolve_stack()
	cast("Lightning Bolt", [TargetRef.card(bear)])
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.damage, 0)
	var second := put_battlefield(0, "Orim, Samite Healer")
	g.check_state_based_actions()
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD, "the 1997 legend rule buries the newer one")
	assert_eq(orim.zone, Mtg.Zone.BATTLEFIELD)

## The 1997 damage-prevention step (fifth): the giant's damage waits, and
## Orim — a prevention ability — may be used inside the window.
func test_orim_works_inside_the_1997_damage_prevention_window() -> void:
	var p1 := seat(1)
	g.rules.set_preset("fifth")
	g.rules.damage_prevention_window = true
	p1.window = true
	var giant := put_battlefield(0, "Hill Giant")
	var orim := put_battlefield(1, "Orim, Samite Healer")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_prevention, "the damage waits")
	if g.priority_player != 1:
		assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.activate_ability(1, orim, 0, [TargetRef.player(1)]))
	var guard := 0
	while (g.awaiting_damage_prevention or not g.stack.is_empty()) and guard < 20:
		if g.stack.is_empty():
			assert_ok(g.end_damage_prevention(g.priority_player))
		else:
			assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_eq(g.players[1].life, 20, "Orim's 3 met the Giant's 3")


# --- Escaped Shapeshifter ---------------------------------------------------

func test_escaped_shapeshifter_copies_an_opposing_flyer_only() -> void:
	var shifter := put_battlefield(0, "Escaped Shapeshifter")
	put_battlefield(0, "Serra Angel")
	assert_false(shifter.has_keyword(Mtg.Keyword.FLYING), "our own flyer does not count")
	var angel := put_battlefield(1, "Serra Angel")
	assert_true(shifter.has_keyword(Mtg.Keyword.FLYING))
	assert_false(shifter.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_false(shifter.has_keyword(Mtg.Keyword.VIGILANCE), "vigilance is not one of the four")
	g.destroy(angel)
	assert_false(shifter.has_keyword(Mtg.Keyword.FLYING))

func test_escaped_shapeshifter_copies_first_strike_and_protection() -> void:
	var shifter := put_battlefield(0, "Escaped Shapeshifter")
	put_battlefield(1, "Black Knight")
	assert_true(shifter.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_eq(shifter.cur_protection & Mtg.ManaColor.W, Mtg.ManaColor.W)
	put_battlefield(1, "Rootbreaker Wurm")
	assert_true(shifter.has_keyword(Mtg.Keyword.TRAMPLE))
	var swords := give_hand(1, "Swords to Plowshares")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.W)
	assert_refused(g.cast_spell(1, swords, [TargetRef.card(shifter)]))

func test_escaped_shapeshifter_ignores_another_escaped_shapeshifter() -> void:
	var ours := put_battlefield(0, "Escaped Shapeshifter")
	var theirs := put_battlefield(1, "Escaped Shapeshifter")
	g.continuous.add_until_eot_keywords(theirs.id, [Mtg.Keyword.FLYING])
	g.recalculate()
	assert_true(theirs.has_keyword(Mtg.Keyword.FLYING))
	assert_false(ours.has_keyword(Mtg.Keyword.FLYING), "not named Escaped Shapeshifter")

## CR 613.8a: a flying a Jump grants their creature later is seen.
func test_escaped_shapeshifter_sees_a_jump_on_their_creature() -> void:
	var shifter := put_battlefield(0, "Escaped Shapeshifter")
	var bear := put_battlefield(1, "Grizzly Bears")
	cast("Jump", [TargetRef.card(bear)], 1)
	assert_true(shifter.has_keyword(Mtg.Keyword.FLYING))
	advance_to_next_turn()
	assert_false(shifter.has_keyword(Mtg.Keyword.FLYING))

## Protection granted to their creature until end of turn (Goblin Wizard)
## and by a Ward Aura is merged after layer 6; the Shapeshifter still sees it.
func test_escaped_shapeshifter_sees_floating_and_ward_protection() -> void:
	var shifter := put_battlefield(0, "Escaped Shapeshifter")
	var wizard := put_battlefield(1, "Goblin Wizard")
	var raiders := put_battlefield(1, "Mons's Goblin Raiders")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(1, wizard, 1, [TargetRef.card(raiders)]))
	resolve_stack()
	assert_eq(raiders.cur_protection & Mtg.ManaColor.W, Mtg.ManaColor.W)
	assert_eq(shifter.cur_protection & Mtg.ManaColor.W, Mtg.ManaColor.W, "a floating grant")
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	assert_eq(shifter.cur_protection, 0)
	cast("Black Ward", [TargetRef.card(raiders)], 1)
	assert_eq(shifter.cur_protection & Mtg.ManaColor.B, Mtg.ManaColor.B, "a Ward's booked grant")


# --- Fylamarid --------------------------------------------------------------

func test_fylamarid_cannot_be_blocked_by_blue_creatures() -> void:
	var squid := put_battlefield(0, "Fylamarid")
	var air := put_battlefield(1, "Air Elemental")
	var angel := put_battlefield(1, "Serra Angel")
	_attack(squid)
	assert_refused(g.declare_blockers(1, {air.id: squid.id}))
	assert_ok(g.declare_blockers(1, {angel.id: squid.id}))

func test_fylamarid_paints_a_blocker_blue_until_end_of_turn() -> void:
	var squid := put_battlefield(0, "Fylamarid")
	var angel := put_battlefield(1, "Serra Angel")
	assert_refused(g.activate_ability(0, squid, 0, [TargetRef.card(angel)]), "mana")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(0, squid, 0, [TargetRef.card(angel)]))
	resolve_stack()
	assert_eq(angel.cur_colors, Mtg.ManaColor.U)
	_attack(squid)
	assert_refused(g.declare_blockers(1, {angel.id: squid.id}))
	assert_ok(g.declare_blockers(1, {}))
	advance_to_next_turn()
	assert_eq(angel.cur_colors, Mtg.ManaColor.W)


# --- Giant Crab -------------------------------------------------------------

func test_giant_crab_gains_shroud_and_a_bolt_cannot_aim_at_it() -> void:
	var crab := put_battlefield(0, "Giant Crab")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(0, crab, 0))
	resolve_stack()
	assert_true(crab.cur_shroud)
	var bolt := give_hand(1, "Lightning Bolt")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(1, bolt, [TargetRef.card(crab)]))
	advance_to_next_turn()
	assert_false(crab.cur_shroud)

func test_giant_crab_shroud_in_response_fizzles_the_bolt() -> void:
	var crab := put_battlefield(0, "Giant Crab")
	var bolt := cast_only("Lightning Bolt", [TargetRef.card(crab)], 1)
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(0, crab, 0))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(crab.damage, 0)
	assert_eq(crab.cur_activated_abilities[0].effects[0].ai_role, &"self_bounce")


# --- Manta Riders / Wind Dancer ---------------------------------------------

func test_manta_riders_flies_for_u_until_end_of_turn() -> void:
	var riders := put_battlefield(0, "Manta Riders")
	assert_refused(g.activate_ability(0, riders, 0), "mana")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(0, riders, 0))
	resolve_stack()
	assert_true(riders.has_keyword(Mtg.Keyword.FLYING))
	advance_to_next_turn()
	assert_false(riders.has_keyword(Mtg.Keyword.FLYING))
	var shape: EffectBase = riders.cur_activated_abilities[0].effects[0]
	assert_eq([shape.ai_role, shape.ai_parameters.get("keyword")], [&"self_keyword", Mtg.Keyword.FLYING])

func test_wind_dancer_lends_flying_with_its_tap() -> void:
	var dancer := put_battlefield(0, "Wind Dancer")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_true(dancer.has_keyword(Mtg.Keyword.FLYING))
	assert_ok(g.activate_ability(0, dancer, 0, [TargetRef.card(bear)]))
	assert_true(dancer.tapped)
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))
	assert_refused(g.activate_ability(0, dancer, 0, [TargetRef.card(bear)]))


# --- Mawcor / Rootwater Hunter ----------------------------------------------

func test_mawcor_and_rootwater_hunter_ping_any_target() -> void:
	var mawcor := put_battlefield(0, "Mawcor")
	var hunter := put_battlefield(0, "Rootwater Hunter")
	var sick := put_battlefield(0, "Rootwater Hunter", true)
	var elves := put_battlefield(1, "Llanowar Elves")
	assert_true(mawcor.has_keyword(Mtg.Keyword.FLYING))
	assert_ok(g.activate_ability(0, mawcor, 0, [TargetRef.player(1)]))
	assert_ok(g.activate_ability(0, hunter, 0, [TargetRef.card(elves)]))
	assert_refused(g.activate_ability(0, sick, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 19)
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)


# --- Rootwater Diver --------------------------------------------------------

func test_rootwater_diver_fishes_an_artifact_card_back() -> void:
	var diver := put_battlefield(0, "Rootwater Diver")
	var icy := put_battlefield(0, "Icy Manipulator")
	g.sacrifice_permanent(icy)
	var bear := put_battlefield(0, "Grizzly Bears")
	g.sacrifice_permanent(bear)
	var their_ring := put_battlefield(1, "Sol Ring")
	g.sacrifice_permanent(their_ring)
	assert_refused(g.activate_ability(0, diver, 0, [TargetRef.card(bear)]))
	assert_refused(g.activate_ability(0, diver, 0, [TargetRef.card(their_ring)]))
	assert_ok(g.activate_ability(0, diver, 0, [TargetRef.card(icy)]))
	assert_eq(diver.zone, Mtg.Zone.GRAVEYARD, "sacrificed as part of the cost")
	resolve_stack()
	assert_eq(icy.zone, Mtg.Zone.HAND)


# --- Tradewind Rider --------------------------------------------------------

func test_tradewind_rider_taps_two_more_creatures_to_bounce_a_permanent() -> void:
	var rider := put_battlefield(0, "Tradewind Rider")
	var first := put_battlefield(0, "Grizzly Bears", true)
	var giant := put_battlefield(1, "Hill Giant")
	assert_refused(g.activate_ability(0, rider, 0, [TargetRef.card(giant)]))
	var second := put_battlefield(0, "Grizzly Bears", true)
	assert_ok(g.activate_ability(0, rider, 0, [TargetRef.card(giant)]))
	assert_true(rider.tapped and first.tapped and second.tapped,
		"summoning-sick creatures may pay the tap cost")
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.HAND)
