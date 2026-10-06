extends GameTest
## Pack 9 (the Tempest block), batch B12: the Exodus choice cards in
## cards/sets/exo/_choices.gd — Mogg Assassin and the five Oaths (Druids,
## Ghouls, Lieges, Mages, Scholars).
##
## The Oaths trigger at EVERY player's upkeep; the player whose upkeep it
## is chooses the target and answers the "may", whoever controls the Oath.

const CLAIMED := ["Mogg Assassin", "Oath of Druids", "Oath of Ghouls", "Oath of Lieges",
	"Oath of Mages", "Oath of Scholars"]

## Answers every yes/no with [member yes] and remembers the prompts.
class Seat extends DecisionAgent:
	var yes := true
	var asked: Array[String] = []
	func answer_yes_no(_g: MtgGame, _pid: int, prompt: String, _hint: bool) -> bool:
		asked.append(prompt)
		return yes

func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)

func _seat(pid: int) -> Seat:
	var s := Seat.new()
	g.set_agent(pid, s)
	return s

## [param pid]'s next upkeep, with its triggers on the stack.
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

## Make the game's next coin flip come out [param win] for the flipper
## (MtgGame.flip_coin: `rng.randi() % 2 == 0` wins) by spending throwaway
## draws of the seeded RNG — setup only.
func _rig_next_flip(win: bool) -> void:
	for n in 64:
		var probe := RandomNumberGenerator.new()
		probe.seed = g.rng.seed
		probe.state = g.rng.state
		if ((probe.randi() % 2) == 0) == win: return
		g.rng.randi()
	fail_test("could not rig the flip")

func _stack_top_item() -> StackItem:
	return g.stack.back() if not g.stack.is_empty() else null

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


# ------------------------------------------------------------ Mogg Assassin --

func _assassin_setup() -> Array:
	advance_to_step(Mtg.Step.MAIN1)
	var assassin := put_battlefield(0, "Mogg Assassin")
	var mine := put_battlefield(0, "Hill Giant")
	var theirs := put_battlefield(1, "Craw Wurm")
	return [assassin, mine, theirs]

func test_mogg_assassin_destroys_your_choice_on_a_won_flip() -> void:
	var cards := _assassin_setup()
	var assassin: CardInstance = cards[0]
	var mine: CardInstance = cards[1]
	var theirs: CardInstance = cards[2]
	assert_ok(g.activate_ability(0, assassin, 0, [TargetRef.card(theirs)]))
	var item := _stack_top_item()
	assert_eq(item.targets.size(), 2, "the opponent's slot is filled at activation")
	assert_eq(item.targets[1].instance_id, mine.id, "the opponent names our best creature")
	_rig_next_flip(true)
	resolve_stack()
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD)

func test_mogg_assassin_destroys_the_opponents_choice_on_a_lost_flip() -> void:
	var cards := _assassin_setup()
	assert_ok(g.activate_ability(0, cards[0], 0, [TargetRef.card(cards[2])]))
	_rig_next_flip(false)
	resolve_stack()
	assert_eq(cards[2].zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(cards[1].zone, Mtg.Zone.GRAVEYARD, "the creature the opponent chose")

func test_mogg_assassin_does_what_it_can_when_one_target_has_gone() -> void:
	var cards := _assassin_setup()
	assert_ok(g.activate_ability(0, cards[0], 0, [TargetRef.card(cards[2])]))
	g.return_to_hand(cards[2])
	_rig_next_flip(true)
	resolve_stack()
	assert_eq(cards[1].zone, Mtg.Zone.BATTLEFIELD, "a won flip names the gone creature: nothing")
	before_each()
	cards = _assassin_setup()
	assert_ok(g.activate_ability(0, cards[0], 0, [TargetRef.card(cards[2])]))
	g.return_to_hand(cards[2])
	_rig_next_flip(false)
	resolve_stack()
	assert_eq(cards[1].zone, Mtg.Zone.GRAVEYARD, "a lost flip still destroys the opponent's choice")

func test_mogg_assassin_needs_an_opposing_creature_and_its_tap() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var assassin := put_battlefield(0, "Mogg Assassin")
	var mine := put_battlefield(0, "Grizzly Bears")
	assert_refused(g.activate_ability(0, assassin, 0, [TargetRef.card(mine)]), "")
	var sick := put_battlefield(0, "Mogg Assassin", true)
	var theirs := put_battlefield(1, "Grizzly Bears")
	assert_refused(g.activate_ability(0, sick, 0, [TargetRef.card(theirs)]), "")


# ----------------------------------------------------------- Oath of Druids --

func test_oath_of_druids_digs_a_creature_for_the_player_with_fewer_creatures() -> void:
	put_battlefield(0, "Oath of Druids")
	put_battlefield(0, "Grizzly Bears")
	var bear := give_hand(1, "Grizzly Bears")
	g.put_from_hand_on_top_of_library(bear)
	var forests: Array[CardInstance] = []
	for _k in 2:
		var f := give_hand(1, "Forest")
		g.put_from_hand_on_top_of_library(f)
		forests.append(f)
	var seat := _seat(1)
	_to_upkeep_of(1)
	var item := _stack_top_item()
	assert_not_null(item, "the Oath triggers at its opponent's upkeep")
	assert_eq(g.trigger_chooser(item), 1, "that player chooses the target")
	assert_true(item.targets[0].is_player and item.targets[0].player_id == 0)
	resolve_stack()
	assert_eq(seat.asked.size(), 1, "the first player answers the may")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.controller_id, 1)
	for f in forests: assert_eq(f.zone, Mtg.Zone.GRAVEYARD, "the other revealed cards")

func test_oath_of_druids_has_no_target_for_the_player_ahead_and_is_optional() -> void:
	put_battlefield(0, "Oath of Druids")
	put_battlefield(0, "Grizzly Bears")
	var seat := _seat(1)
	seat.yes = false
	var library := g.players[1].library.size()
	_to_upkeep_of(1)
	resolve_stack()
	assert_eq(seat.asked.size(), 1)
	assert_eq(g.players[1].library.size(), library, "declined: nothing revealed")
	_to_upkeep_of(0)
	assert_true(g.stack.is_empty(), "nobody controls more creatures than P0: no legal target")

func test_oath_of_druids_with_no_creature_card_mills_everything_revealed() -> void:
	put_battlefield(0, "Oath of Druids")
	put_battlefield(0, "Grizzly Bears")
	# A hidden creature card the decklist does not know of (put on top from
	# a hand the opponent never saw): the hint must not read the library.
	var hidden := give_hand(1, "Grizzly Bears")
	g.put_from_hand_on_top_of_library(hidden)
	_to_upkeep_of(1)
	# The heuristic declines: its decklist (thirty Forests) has no creature
	# card unaccounted for, whatever the hidden library holds...
	resolve_stack()
	assert_eq(g.players[1].library.size(), 31, "the hint: nothing to find, no reveal")
	assert_eq(hidden.zone, Mtg.Zone.LIBRARY)
	before_each()
	put_battlefield(0, "Oath of Druids")
	put_battlefield(0, "Grizzly Bears")
	_seat(1)
	_to_upkeep_of(1)
	# ...and a player who says yes anyway reveals the whole library.
	resolve_stack()
	assert_eq(g.players[1].library.size(), 0, "only Forests: all revealed, all into the graveyard")
	assert_true(g.players[1].graveyard.size() >= 28)


# ----------------------------------------------------------- Oath of Ghouls --

func test_oath_of_ghouls_returns_a_creature_card_to_the_player_with_more() -> void:
	put_battlefield(1, "Oath of Ghouls")
	var dead := _to_graveyard(0, "Grizzly Bears")
	_to_graveyard(0, "Forest")
	_to_upkeep_of(0)
	assert_false(g.stack.is_empty())
	resolve_stack()
	assert_eq(dead.zone, Mtg.Zone.HAND, "the first player's creature card")
	_to_upkeep_of(1)
	assert_true(g.stack.is_empty(), "P1's graveyard does not have more creature cards than P0's")


# ----------------------------------------------------------- Oath of Lieges --

func test_oath_of_lieges_fetches_a_basic_land_onto_the_battlefield() -> void:
	put_battlefield(0, "Oath of Lieges")
	for _k in 2: put_battlefield(1, "Forest")
	_to_upkeep_of(0)
	var library := g.players[0].library.size()
	resolve_stack()
	var lands := g.players[0].battlefield.filter(func(i: CardInstance) -> bool: return i.is_land())
	assert_eq(lands.size(), 1)
	assert_eq(g.players[0].library.size(), library - 1)
	_to_upkeep_of(1)
	assert_true(g.stack.is_empty(), "P0 controls fewer lands than P1: no target at P1's upkeep")

func test_oath_of_lieges_is_optional() -> void:
	put_battlefield(0, "Oath of Lieges")
	put_battlefield(1, "Forest")
	var seat := _seat(0)
	seat.yes = false
	_to_upkeep_of(0)
	resolve_stack()
	assert_eq(seat.asked.size(), 1)
	assert_eq(g.players[0].battlefield.filter(func(i: CardInstance) -> bool: return i.is_land()).size(), 0)


# ------------------------------------------------------------ Oath of Mages --

func test_oath_of_mages_pings_the_player_with_more_life() -> void:
	put_battlefield(1, "Oath of Mages")
	g.adjust_life(0, -5)
	_to_upkeep_of(0)
	resolve_stack()
	assert_eq(g.players[1].life, 19, "the Oath deals 1 damage to the second player")
	_to_upkeep_of(1)
	assert_true(g.stack.is_empty())

func test_oath_of_mages_fizzles_when_the_lead_is_gone_on_resolution() -> void:
	put_battlefield(1, "Oath of Mages")
	g.adjust_life(0, -5)
	_to_upkeep_of(0)
	assert_false(g.stack.is_empty())
	g.adjust_life(0, 10)
	resolve_stack()
	assert_eq(g.players[1].life, 20, "an illegal target: the ability does nothing (CR 608.2b)")


# --------------------------------------------------------- Oath of Scholars --

func test_oath_of_scholars_trades_the_smaller_hand_for_three_cards() -> void:
	put_battlefield(0, "Oath of Scholars")
	var kept := give_hand(0, "Lightning Bolt")
	for _k in 3: give_hand(1, "Forest")
	_to_upkeep_of(0)
	var seat := _seat(0)
	resolve_stack()
	assert_eq(seat.asked.size(), 1)
	assert_eq(kept.zone, Mtg.Zone.GRAVEYARD, "discard the hand")
	assert_eq(g.players[0].hand.size(), 3, "and draw three")

func test_oath_of_scholars_declined_keeps_the_hand() -> void:
	put_battlefield(0, "Oath of Scholars")
	var kept := give_hand(0, "Lightning Bolt")
	for _k in 3: give_hand(1, "Forest")
	_to_upkeep_of(0)
	var seat := _seat(0)
	seat.yes = false
	resolve_stack()
	assert_eq(kept.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].hand.size(), 1)

func test_oath_of_druids_hint_reads_the_decklist_not_the_library() -> void:
	# A decklist with creatures: the heuristic seat accepts and digs one up.
	var deck: Array = []
	for _k in 10: deck.append("Grizzly Bears")
	for _k in 20: deck.append("Forest")
	g = MtgGame.new()
	g.setup(deck, deck, "P0", "P1", 20, 20, 424242)
	g.start(0)
	put_battlefield(0, "Oath of Druids")
	put_battlefield(0, "Hill Giant")
	var library := g.players[1].library.size()
	_to_upkeep_of(1)
	resolve_stack()
	var bears := g.players[1].battlefield.filter(func(i: CardInstance) -> bool: return i.data.card_name == "Grizzly Bears")
	assert_eq(bears.size(), 1, "revealed until a creature card, onto the battlefield")
	assert_eq(g.players[1].library.size() + g.players[1].graveyard.size() + 1, library)
	for i in g.players[1].graveyard: assert_eq(i.data.card_name, "Forest")
