extends GameTest
## Pack 9 (the Tempest block), batch B9: the Stronghold triggered permanents
## of cards/sets/sth/_triggers.gd — real stack triggers, whose choice each
## "may" is, last known information for a departed source (CR 603.6 /
## 608.2h), the per-occurrence facts captured as each ability triggers, and
## Sacred Ground's "a spell or ability an opponent controls causes".

const CLAIMED := ["Awakening", "Bottomless Pit", "Burgeoning", "Contemplation",
	"Crovax the Cursed", "Foul Imp", "Grave Pact", "Heat of Battle", "Hesitation",
	"Lowland Basilisk", "Megrim", "Mogg Bombers", "Mogg Maniac", "Mortuary",
	"Sacred Ground", "Spindrift Drake", "Wall of Blossoms", "Wall of Essence",
	"Wall of Souls", "Warrior Angel"]

## A seat whose answers a test scripts: yes/no (-1 follows the hint), card
## names to prefer (else the first, ranked candidate), or a declined card
## question.
class Seat extends DecisionAgent:
	var yes := -1
	var prefer: Array = []
	var decline := false
	var asked: Array = []

	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String, hint: bool) -> bool:
		asked.append(prompt)
		return hint if yes < 0 else yes == 1

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
	CardPacks.set_enabled("pack-9", true)
	CardRegistry.ensure_loaded()
	super()
	me = Seat.new()
	foe = Seat.new()
	g.set_agent(0, me)
	g.set_agent(1, foe)
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)


func fund(pid: int, card: CardInstance) -> void:
	var cost := card.data.cost
	for c in cost.colored:
		add_mana(pid, c, int(cost.colored[c]))
	if cost.generic > 0:
		add_mana(pid, Mtg.ManaColor.C, cost.generic)

## [param pid] casts [param card_name] at [param targets]; the stack stays.
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

## Pass until [param pid]'s upkeep of a LATER turn, its triggers waiting.
func _to_upkeep(pid: int) -> void:
	var start := g.turn_number
	var guard := 0
	while not g.game_over and guard < 800 and not (g.turn_number > start
			and g.active_player == pid and g.current_step() == Mtg.Step.UPKEEP):
		_advance_once()
		guard += 1
	assert_lt(guard, 800, "never reached the upkeep")

## P0 attacks with [param attacker]; P1 blocks as [param blocks] says; the
## combat runs to its end step.
func _fight(attacker: CardInstance, blocks: Dictionary) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, blocks))
	resolve_stack()

## Resolve only the topmost stack object: both players pass once.
func resolve_stack_top_spell_only() -> void:
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))

func _counter(i: CardInstance) -> int:
	return int(i.counters.get("+1/+1", 0))


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending",
			"%s is still pending" % card_name)
		assert_false(c.triggered_abilities.is_empty(), "%s has its trigger" % card_name)


# ---------------------------------------------------------------- Awakening --

func test_awakening_untaps_every_creature_and_land_in_each_upkeep() -> void:
	put_battlefield(0, "Awakening")
	var bear := put_battlefield(0, "Grizzly Bears")
	run_combat([bear.id])
	assert_true(bear.tapped)
	_to_upkeep(1)
	assert_eq(g.stack.size(), 1, "the opponent's upkeep too")
	resolve_stack()
	assert_false(bear.tapped, "our attacker untapped in their upkeep")


# ----------------------------------------------------------- Bottomless Pit --

func test_bottomless_pit_makes_the_upkeeps_player_discard_at_random() -> void:
	put_battlefield(0, "Bottomless Pit")
	give_hand(1, "Forest")
	give_hand(1, "Grizzly Bears")
	var mine := give_hand(0, "Island")
	_to_upkeep(1)
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 1, "one of theirs, at random")
	assert_eq(g.players[1].graveyard.size(), 1)
	assert_eq(mine.zone, Mtg.Zone.HAND, "not ours in their upkeep")


# --------------------------------------------------------------- Burgeoning --

func test_burgeoning_answers_an_opponents_land_drop() -> void:
	put_battlefield(0, "Burgeoning")
	var forest := give_hand(0, "Forest")
	var own := give_hand(0, "Island")
	assert_ok(g.play_land(0, own))
	assert_true(g.stack.is_empty(), "our own land drop does not trigger it")
	advance_to_next_turn()
	var theirs := give_hand(1, "Mountain")
	assert_ok(g.play_land(1, theirs))
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(forest.controller_id, 0)


func test_burgeoning_may_be_declined() -> void:
	put_battlefield(0, "Burgeoning")
	var forest := give_hand(0, "Forest")
	me.decline = true
	advance_to_next_turn()
	assert_ok(g.play_land(1, give_hand(1, "Mountain")))
	resolve_stack()
	assert_eq(forest.zone, Mtg.Zone.HAND)


# ------------------------------------------------------------ Contemplation --

func test_contemplation_gains_a_life_for_each_of_your_spells() -> void:
	put_battlefield(0, "Contemplation")
	cast("Grizzly Bears")
	assert_eq(g.players[0].life, 21)
	advance_to_next_turn()
	cast("Grizzly Bears", [], 1)
	assert_eq(g.players[0].life, 21, "not the opponent's")


# -------------------------------------------------------- Crovax the Cursed --

func test_crovax_feeds_on_a_sacrifice_or_shrinks() -> void:
	var crovax := put_battlefield(0, "Crovax the Cursed")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_eq([crovax.cur_power, crovax.cur_toughness], [4, 4], "four counters on a 0/0")
	me.yes = 1
	me.prefer = ["Grizzly Bears"]
	_to_upkeep(0)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(_counter(crovax), 5)
	me.yes = 0
	_to_upkeep(0)
	resolve_stack()
	assert_eq(_counter(crovax), 4, "no sacrifice: one counter off")


func test_crovax_gains_flying_for_black() -> void:
	var crovax := put_battlefield(0, "Crovax the Cursed")
	assert_false(crovax.has_keyword(Mtg.Keyword.FLYING))
	assert_refused(g.activate_ability(0, crovax, 0), "")
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, crovax, 0))
	resolve_stack()
	assert_true(crovax.has_keyword(Mtg.Keyword.FLYING))
	assert_true((crovax.data.supertypes & Mtg.Supertype.LEGENDARY) != 0)


func test_crovax_sacrificing_itself_gets_no_counter() -> void:
	var crovax := put_battlefield(0, "Crovax the Cursed")
	me.yes = 1
	me.prefer = ["Crovax the Cursed"]
	_to_upkeep(0)
	resolve_stack()
	assert_eq(crovax.zone, Mtg.Zone.GRAVEYARD)


# ----------------------------------------------------------------- Foul Imp --

func test_foul_imp_costs_two_life_as_it_enters() -> void:
	var imp := cast("Foul Imp")
	assert_eq(g.players[0].life, 18)
	assert_true(imp.has_keyword(Mtg.Keyword.FLYING))


# --------------------------------------------------------------- Grave Pact --

func test_grave_pact_makes_each_other_player_sacrifice_a_creature() -> void:
	put_battlefield(0, "Grave Pact")
	var bear := put_battlefield(0, "Grizzly Bears")
	var elves := put_battlefield(1, "Llanowar Elves")
	var giant := put_battlefield(1, "Hill Giant")
	cast("Lightning Bolt", [TargetRef.card(bear)])
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD, "their choice: the cheapest by default")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	cast("Lightning Bolt", [TargetRef.card(giant)])
	var other := put_battlefield(0, "Grizzly Bears")
	cast("Lightning Bolt", [TargetRef.card(other)])
	assert_true(g.stack.is_empty(), "nothing left to sacrifice: the trigger does nothing")


func test_grave_pact_ignores_the_opponents_deaths_and_lets_them_choose() -> void:
	put_battlefield(0, "Grave Pact")
	var bear := put_battlefield(0, "Grizzly Bears")
	var elves := put_battlefield(1, "Llanowar Elves")
	var giant := put_battlefield(1, "Hill Giant")
	cast("Lightning Bolt", [TargetRef.card(elves)])
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "their creature died: nothing")
	foe.prefer = ["Hill Giant"]
	put_battlefield(1, "Llanowar Elves")
	cast("Lightning Bolt", [TargetRef.card(bear)])
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "the sacrificing player chose")


# ----------------------------------------------------------- Heat of Battle --

func test_heat_of_battle_burns_each_blockers_controller() -> void:
	put_battlefield(0, "Heat of Battle")
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	_fight(giant, {bear.id: giant.id})
	assert_eq(g.players[1].life, 19)
	assert_eq(g.players[0].life, 20)


func test_heat_of_battle_is_quiet_without_blocks() -> void:
	put_battlefield(0, "Heat of Battle")
	var giant := put_battlefield(0, "Hill Giant")
	put_battlefield(1, "Grizzly Bears")
	_fight(giant, {})
	assert_true(g.stack.is_empty())
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(g.players[1].life, 17, "only the Giant's damage")


# --------------------------------------------------------------- Hesitation --

func test_hesitation_counters_the_next_spell_and_goes() -> void:
	var hesitation := put_battlefield(1, "Hesitation")
	var bear := cast_only("Grizzly Bears")
	assert_eq(g.stack.size(), 2, "the trigger above the spell")
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "countered")
	assert_eq(hesitation.zone, Mtg.Zone.GRAVEYARD, "sacrificed")
	var giant := cast("Hill Giant")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "only once")


## A response is a spell too: its own trigger counters it and takes the
## sacrifice, and the first trigger still counters the first spell with
## Hesitation already gone (CR 608.2c: each instruction as far as it can go).
func test_hesitation_triggers_on_a_response_and_both_spells_are_countered() -> void:
	var hesitation := put_battlefield(1, "Hesitation")
	var bear := cast_only("Grizzly Bears")
	var counter := cast_only("Counterspell", [TargetRef.card(bear)])
	assert_eq(g.stack.size(), 4, "two spells, two triggers")
	resolve_stack()
	assert_eq(hesitation.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(counter.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].graveyard.size(), 1, "sacrificed once")


func test_hesitation_also_counters_its_controllers_spell() -> void:
	put_battlefield(0, "Hesitation")
	var bear := cast("Grizzly Bears")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


# --------------------------------------------------------- Lowland Basilisk --

func test_lowland_basilisk_dooms_what_it_damages_at_end_of_combat() -> void:
	var basilisk := put_battlefield(1, "Lowland Basilisk")
	var giant := put_battlefield(0, "Hill Giant")
	_fight(giant, {basilisk.id: giant.id})
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	resolve_stack()
	assert_eq(basilisk.zone, Mtg.Zone.GRAVEYARD, "3 damage on a 1/3")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "not yet")
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "destroyed at end of combat")


func test_lowland_basilisk_hitting_a_player_dooms_nobody() -> void:
	var basilisk := put_battlefield(0, "Lowland Basilisk")
	var bear := put_battlefield(1, "Grizzly Bears")
	_fight(basilisk, {})
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(g.players[1].life, 19)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------------------------- Megrim --

func test_megrim_burns_an_opponent_for_each_discard() -> void:
	put_battlefield(0, "Megrim")
	var a := give_hand(1, "Forest")
	var b := give_hand(1, "Island")
	g.discard_cards(1, [a, b])
	resolve_stack()
	assert_eq(g.players[1].life, 16, "two cards, two triggers")
	g.discard_cards(0, [give_hand(0, "Forest")])
	resolve_stack()
	assert_eq(g.players[0].life, 20, "not our own discards")


func test_megrim_hears_bottomless_pits_random_discard() -> void:
	put_battlefield(0, "Megrim")
	put_battlefield(0, "Bottomless Pit")
	give_hand(1, "Forest")
	_to_upkeep(1)
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 0)
	assert_eq(g.players[1].life, 18)


# ------------------------------------------------------------- Mogg Bombers --

func test_mogg_bombers_explode_when_another_creature_enters() -> void:
	var bombers := put_battlefield(0, "Mogg Bombers")
	cast("Grizzly Bears")
	assert_eq(bombers.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 17, "aimed at the opponent")


func test_mogg_bombers_do_not_hear_their_own_arrival() -> void:
	var bombers := cast("Mogg Bombers")
	assert_eq(bombers.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[1].life, 20)
	advance_to_next_turn()
	cast("Grizzly Bears", [], 1)
	assert_eq(bombers.zone, Mtg.Zone.GRAVEYARD, "an opponent's creature counts too")
	assert_eq(g.players[1].life, 17)


func test_mogg_bombers_gone_before_resolution_still_deal_their_three() -> void:
	var bombers := put_battlefield(0, "Mogg Bombers")
	cast_only("Grizzly Bears")
	resolve_stack_top_spell_only()
	assert_eq(g.stack.size(), 1, "the Bombers' trigger waits")
	cast_only("Lightning Bolt", [TargetRef.card(bombers)])
	resolve_stack()
	assert_eq(bombers.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 17, "the damage does not wait on the sacrifice (CR 608.2c/h)")


# -------------------------------------------------------------- Mogg Maniac --

func test_mogg_maniac_passes_on_the_damage_it_takes() -> void:
	var maniac := put_battlefield(0, "Mogg Maniac")
	cast("Lightning Bolt", [TargetRef.card(maniac)])
	assert_eq(maniac.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 17, "all three, from the Maniac as it last existed")
	assert_eq(g.players[0].life, 20)


# ----------------------------------------------------------------- Mortuary --

func test_mortuary_puts_your_dead_creature_on_top_of_your_library() -> void:
	put_battlefield(0, "Mortuary")
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	cast("Lightning Bolt", [TargetRef.card(bear)])
	assert_eq(bear.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[0].library.back(), bear, "on top")
	cast("Lightning Bolt", [TargetRef.card(giant)])
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "their graveyard, not ours")


# ------------------------------------------------------------ Sacred Ground --

func test_sacred_ground_returns_a_land_an_opponents_spell_destroyed() -> void:
	put_battlefield(0, "Sacred Ground")
	var forest := put_battlefield(0, "Forest")
	advance_to_next_turn()
	cast("Stone Rain", [TargetRef.card(forest)], 1)
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(forest.controller_id, 0)


func test_sacred_ground_ignores_your_own_spells() -> void:
	put_battlefield(0, "Sacred Ground")
	var forest := put_battlefield(0, "Forest")
	cast("Stone Rain", [TargetRef.card(forest)])
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)


# ---------------------------------------------------------- Spindrift Drake --

func test_spindrift_drake_upkeep_is_one_blue() -> void:
	var drake := put_battlefield(0, "Spindrift Drake")
	put_battlefield(0, "Island")
	_to_upkeep(0)
	resolve_stack()
	assert_eq(drake.zone, Mtg.Zone.BATTLEFIELD, "paid")
	var lonely := put_battlefield(1, "Spindrift Drake")
	_to_upkeep(1)
	resolve_stack()
	assert_eq(lonely.zone, Mtg.Zone.GRAVEYARD, "no blue: sacrificed")


# --------------------------------------------------------------------- Walls --

func test_wall_of_blossoms_draws_as_it_enters() -> void:
	var hand := g.players[0].hand.size()
	var wall := cast("Wall of Blossoms")
	assert_eq(g.players[0].hand.size(), hand + 1)
	assert_true(wall.has_keyword(Mtg.Keyword.DEFENDER))


func test_wall_of_essence_gains_what_combat_deals_it() -> void:
	var wall := put_battlefield(1, "Wall of Essence")
	var giant := put_battlefield(0, "Hill Giant")
	_fight(giant, {wall.id: giant.id})
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(g.players[1].life, 23)
	cast("Lightning Bolt", [TargetRef.card(wall)])
	assert_eq(g.players[1].life, 23, "noncombat damage gains nothing")


func test_wall_of_souls_returns_combat_damage_to_an_opponent() -> void:
	var wall := put_battlefield(1, "Wall of Souls")
	var giant := put_battlefield(0, "Hill Giant")
	_fight(giant, {wall.id: giant.id})
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(g.players[0].life, 17)
	cast("Lightning Bolt", [TargetRef.card(wall)])
	assert_eq(g.players[0].life, 17, "only combat damage")


func test_warrior_angel_gains_what_it_deals() -> void:
	var angel := put_battlefield(0, "Warrior Angel")
	_fight(angel, {})
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(g.players[1].life, 17)
	assert_eq(g.players[0].life, 23)
