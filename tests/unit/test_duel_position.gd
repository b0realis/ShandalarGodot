extends GutTest
## THE TEST POSITION — Magic Battle's `Test hands` in the engine
## (2026-10-19): [DuelPosition], the model, and
## [method MtgGame.begin_from_position], the one door it goes through.
##
## What these pin:
##   1. every card lands exactly where the position put it — hand, table
##      (tapped or not, sick or not), graveyard in its order, the library's
##      top in its order — with the life totals, the turn and the step set,
##      and no card lost or made but the extras;
##   2. no opening deal, no mulligan, no untap step before the chosen step:
##      a tapped permanent is still tapped when the test begins;
##   3. nothing on the table ARRIVES — no enters-the-battlefield trigger,
##      no stack — but its printed "enters with counters" are there;
##   4. a card the deck has no copy left of is MADE and joins the seat's
##      decklist;
##   5. the same seed and position give the same game — `Restart test`;
##   6. a refusal moves nothing;
##   7. the combo can go off at once: a creature placed not sick taps for
##      mana in the first main phase (and a sick one cannot) — the
##      mutation check of the `sick` flag;
##   8. the model round-trips through plain values and reads a damaged
##      settings value safely;
##   9. the owner's Corpse Dance case (Pack 9): Workhorse in the graveyard,
##      Corpse Dance cast off the lands on the table, Workhorse back with
##      its four counters — and Sliver Queen, Heartstone and Ashnod's Altar
##      standing on the table against a random seven.

const SPELLS := ["Grizzly Bears", "Hill Giant", "Lightning Bolt",
	"Giant Growth", "Llanowar Elves", "Dark Ritual"]


func _deck(lands := 20, spells := 20) -> Array:
	var out: Array = []
	for i in lands:
		out.append("Forest")
	for i in spells:
		out.append(SPELLS[i % SPELLS.size()])
	return out


func _game(seed_value := 424242) -> MtgGame:
	var game := MtgGame.new()
	game.setup(_deck(), _deck(), "P0", "P1", 20, 20, seed_value)
	return game


func _names(cards: Array) -> Array[String]:
	var out: Array[String] = []
	for inst in cards:
		out.append((inst as CardInstance).data.card_name)
	return out


func _count_all(game: MtgGame, pid: int) -> int:
	var p := game.players[pid]
	return p.library.size() + p.hand.size() + p.battlefield.size() + p.graveyard.size()


## The position most of these use: Seat 1 (index 0) holds a Bolt and a
## Bear, has a tapped Forest, untapped Elves and a SICK Bear on the table,
## a Hill Giant under a Bear in the graveyard, Giant Growth then Dark
## Ritual on top of the library, and 13 life; Seat 2 a random four and 7
## life; Seat 2's first main phase.
func _position() -> DuelPosition:
	var position := DuelPosition.new()
	position.add(0, DuelPosition.HAND, "Lightning Bolt")
	position.add(0, DuelPosition.HAND, "Grizzly Bears")
	position.add(0, DuelPosition.TABLE, "Forest")
	position.set_tapped(0, 0, true)
	position.add(0, DuelPosition.TABLE, "Llanowar Elves")
	position.add(0, DuelPosition.TABLE, "Grizzly Bears")
	position.set_sick(0, 2, true)
	position.add(0, DuelPosition.GRAVEYARD, "Hill Giant")
	position.add(0, DuelPosition.GRAVEYARD, "Grizzly Bears")
	position.add(0, DuelPosition.LIBRARY_TOP, "Giant Growth")
	position.add(0, DuelPosition.LIBRARY_TOP, "Dark Ritual")
	position.random_cards[1] = 4
	position.lives[0] = 13
	position.lives[1] = 7
	position.active_player = 1
	position.step = Mtg.Step.MAIN1
	return position


# ============================================= 1. everything where it was put --

func test_every_card_lands_where_the_position_put_it() -> void:
	var game := _game()
	assert_eq(game.begin_from_position(_position()), "")
	var me := game.players[0]
	assert_eq(_names(me.hand), ["Lightning Bolt", "Grizzly Bears"] as Array[String],
		"the chosen hand, and nothing dealt on top of it")
	assert_eq(_names(me.battlefield), ["Forest", "Llanowar Elves", "Grizzly Bears"] as Array[String])
	assert_true(me.battlefield[0].tapped, "the Forest was put there tapped")
	assert_false(me.battlefield[1].tapped)
	assert_false(me.battlefield[1].summoning_sick, "not sick unless the player said so")
	assert_true(me.battlefield[2].summoning_sick, "the Bear was marked sick")
	for inst in me.battlefield:
		assert_eq(inst.zone, Mtg.Zone.BATTLEFIELD)
		assert_eq(inst.controller_id, 0)
	assert_eq(_names(me.graveyard), ["Hill Giant", "Grizzly Bears"] as Array[String],
		"bottom first: the last card added is the top one")
	assert_eq(me.library[-1].data.card_name, "Giant Growth", "the first chosen top is the next draw")
	assert_eq(me.library[-2].data.card_name, "Dark Ritual")
	assert_eq(me.life, 13)
	assert_eq(game.players[1].life, 7)
	assert_eq(game.players[1].hand.size(), 4, "Seat 2's random four")
	for pid in 2:
		assert_eq(_count_all(game, pid), 40, "no card lost, none made: the deck held them all")


func test_the_chosen_turn_and_step_begin_at_once() -> void:
	var game := _game()
	assert_eq(game.begin_from_position(_position()), "")
	assert_eq(game.turn_number, 1)
	assert_eq(game.active_player, 1, "Seat 2's turn, as chosen")
	assert_eq(game.current_step(), Mtg.Step.MAIN1, "its first main phase, as chosen")
	assert_eq(game.priority_player, 1, "the active player holds priority")
	assert_false(game.mulligan_open, "no opening hand, no mulligan")
	assert_eq(game.mulligans_taken, [0, 0] as Array[int])
	assert_true(game.stack.is_empty())


func test_every_step_a_test_offers_is_the_step_it_begins_in() -> void:
	for step in DuelPosition.STEPS:
		var game := _game()
		var position := DuelPosition.new()
		position.active_player = 0
		position.step = step
		assert_eq(game.begin_from_position(position), "", Mtg.step_name(step))
		assert_eq(game.current_step(), step, "begins in %s" % Mtg.step_name(step))
		assert_eq(game.active_player, 0)


# ================================== 2. no untap step: tapped stays tapped --

func test_a_tapped_permanent_of_the_active_player_is_still_tapped() -> void:
	var game := _game()
	var position := DuelPosition.new()
	position.add(0, DuelPosition.TABLE, "Forest")
	position.set_tapped(0, 0, true)
	position.active_player = 0
	position.step = Mtg.Step.UPKEEP
	assert_eq(game.begin_from_position(position), "")
	assert_true(game.players[0].battlefield[0].tapped,
		"the test began after the untap step, so nothing untapped")


func test_a_test_that_begins_in_the_upkeep_draws_in_its_draw_step() -> void:
	var game := _game()
	var position := DuelPosition.new()
	position.add(0, DuelPosition.LIBRARY_TOP, "Lightning Bolt")
	position.active_player = 0
	position.step = Mtg.Step.UPKEEP
	assert_eq(game.begin_from_position(position), "")
	var guard := 0
	while game.current_step() != Mtg.Step.MAIN1 and guard < 20:
		assert_eq(game.pass_priority(game.priority_player), "")
		guard += 1
	assert_eq(_names(game.players[0].hand), ["Lightning Bolt"] as Array[String],
		"turn 1's draw is not skipped in a test: the chosen top card was drawn")


# =============================== 3. nothing arrives; printed counters stay --

func test_nothing_on_the_table_arrives_so_no_arrival_trigger_fires() -> void:
	var game := _game()
	var position := DuelPosition.new()
	# Ankh of Mishra stings the controller of every land that enters;
	# Electric Eel stings its own controller as it enters.
	for card_name in ["Ankh of Mishra", "Forest", "Forest", "Electric Eel"]:
		position.add(0, DuelPosition.TABLE, card_name)
	position.add(1, DuelPosition.TABLE, "Forest")
	position.active_player = 0
	assert_eq(game.begin_from_position(position), "")
	assert_true(game.stack.is_empty(), "no trigger went on the stack")
	assert_eq(game.players[0].life, 20, "the Ankh and the Eel stung nobody")
	assert_eq(game.players[1].life, 20)
	assert_eq(game.players[0].battlefield.size(), 4)


func test_the_counters_a_card_enters_with_are_on_it() -> void:
	var game := _game()
	var position := DuelPosition.new()
	position.add(0, DuelPosition.TABLE, "Triskelion")
	assert_eq(game.begin_from_position(position), "")
	var trisk := game.find_on_battlefield(0, "Triskelion")
	assert_not_null(trisk)
	if trisk != null:
		assert_eq(int(trisk.counters.get("+1/+1", 0)), 3, "its three +1/+1 counters")
		assert_eq(trisk.cur_power, 4, "and the board was recalculated with them")
		assert_eq(trisk.cur_toughness, 4)


# ================================================= 4. a card from outside --

func test_a_card_the_deck_lacks_is_made_and_joins_its_decklist() -> void:
	var game := _game()
	var position := DuelPosition.new()
	position.add(0, DuelPosition.TABLE, "Ashnod's Altar")
	# The deck holds Lightning Bolts: these two come out of it and are not
	# extras (the control — only the Altar is made).
	position.add(0, DuelPosition.HAND, "Lightning Bolt")
	position.add(0, DuelPosition.HAND, "Lightning Bolt")
	assert_eq(game.begin_from_position(position), "")
	var altar := game.find_on_battlefield(0, "Ashnod's Altar")
	assert_not_null(altar, "the Altar is on the table though the deck has none")
	assert_true(game.players[0].deck_names.has("Ashnod's Altar"),
		"and it is part of the seat's decklist for this test")
	assert_eq(_count_all(game, 0), 41, "one card made, the deck's forty all there")
	assert_eq(game.find_instance(altar.id), altar, "registered like any card")
	var said := false
	for line in game.log_lines:
		if String(line).begins_with("Test hands: P0") and String(line).contains("1 not from the deck"):
			said = true
	assert_true(said, "the log says one card was not from the deck")


# ======================================================= 5. Restart test --

func test_the_same_seed_and_position_give_the_same_game() -> void:
	var position := _position()
	var first := _game(77)
	var again := _game(77)
	assert_eq(first.begin_from_position(position), "")
	assert_eq(again.begin_from_position(position), "")
	for pid in 2:
		assert_eq(_names(first.players[pid].hand), _names(again.players[pid].hand),
			"seat %d's hand, random cards included" % (pid + 1))
		assert_eq(_names(first.players[pid].library), _names(again.players[pid].library),
			"seat %d's library, card for card" % (pid + 1))
	# The control: another seed deals Seat 2 another random four, or the
	# library under them in another order.
	var other := _game(78)
	assert_eq(other.begin_from_position(position), "")
	assert_ne(_names(other.players[1].hand) + _names(other.players[1].library),
		_names(first.players[1].hand) + _names(first.players[1].library),
		"the random cards are the seed's")


func test_the_random_cards_come_from_the_rest_of_the_library() -> void:
	var game := _game()
	var position := DuelPosition.new()
	position.add(1, DuelPosition.LIBRARY_TOP, "Hill Giant")
	position.random_cards[1] = 7
	assert_eq(game.begin_from_position(position), "")
	assert_eq(game.players[1].hand.size(), 7)
	assert_eq(game.players[1].library[-1].data.card_name, "Hill Giant",
		"the chosen top card is not dealt away by the random hand")
	assert_eq(game.players[1].library.size(), 33)


# ========================================================= 6. refusals --

func test_a_card_the_pool_does_not_hold_is_refused_and_nothing_moves() -> void:
	var game := _game()
	var position := _position()
	position.add(1, DuelPosition.HAND, "Not A Real Card")
	var refusal := game.begin_from_position(position)
	assert_string_contains(refusal, "Not A Real Card")
	assert_eq(game.turn_number, 0, "no turn began")
	for pid in 2:
		assert_eq(game.players[pid].library.size(), 40, "no card left a library")
		assert_true(game.players[pid].hand.is_empty())
		assert_true(game.players[pid].battlefield.is_empty())


func test_a_position_comes_before_the_opening_hands_not_after() -> void:
	var game := _game()
	game.deal_opening_hands(7)
	assert_ne(game.begin_from_position(DuelPosition.new()), "")
	assert_eq(game.players[0].hand.size(), 7, "the dealt hand is untouched")
	var started := _game()
	started.start(7, 0)
	assert_ne(started.begin_from_position(DuelPosition.new()), "")


func test_bad_values_are_refused_by_the_model() -> void:
	var position := DuelPosition.new()
	assert_eq(position.refusal(), "")
	position.lives[0] = 0
	assert_ne(position.refusal(), "", "a life of 0")
	position.lives[0] = 20
	position.step = Mtg.Step.CLEANUP
	assert_ne(position.refusal(), "", "a step a test does not begin in")
	position.step = Mtg.Step.MAIN1
	position.active_player = 2
	assert_ne(position.refusal(), "", "a seat that does not exist")


# ============================================ 7. the combo goes off at once --

func test_a_creature_placed_not_sick_taps_for_mana_at_once() -> void:
	var game := _game()
	var position := DuelPosition.new()
	position.add(0, DuelPosition.TABLE, "Llanowar Elves")
	position.add(0, DuelPosition.TABLE, "Llanowar Elves")
	position.set_sick(0, 1, true)
	position.active_player = 0
	assert_eq(game.begin_from_position(position), "")
	var ready_elves: CardInstance = game.players[0].battlefield[0]
	var sick_elves: CardInstance = game.players[0].battlefield[1]
	assert_eq(game.tap_for_mana(0, ready_elves), "",
		"there before the turn began: its {T} ability works now")
	assert_ne(game.tap_for_mana(0, sick_elves), "",
		"the one marked sick cannot tap yet (the control)")


# ===================================================== 8. the plain values --

func test_the_position_round_trips_through_plain_values() -> void:
	var position := _position()
	var back := DuelPosition.from_dict(position.to_dict())
	assert_eq(back.to_dict(), position.to_dict())
	assert_eq(back.names_in(0, DuelPosition.TABLE),
		["Forest", "Llanowar Elves", "Grizzly Bears"] as Array[String])
	assert_true(bool(back.table_entry(0, 0)["tapped"]))
	assert_true(bool(back.table_entry(0, 2)["sick"]))
	var copy := position.duplicate_position()
	copy.add(0, DuelPosition.HAND, "Hill Giant")
	assert_eq(position.names_in(0, DuelPosition.HAND).size(), 2, "a copy shares nothing")


func test_a_damaged_settings_value_reads_as_a_safe_position() -> void:
	assert_true(DuelPosition.from_dict("nonsense").is_empty())
	var read := DuelPosition.from_dict({
		"hands": [["Lightning Bolt", 42, ""], "not a list"],
		"table": [[{"name": "Forest", "tapped": "yes"}, "Hill Giant", {"tapped": true}], []],
		"lives": [-5, "17"],
		"random_cards": [999, 3.0],
		"active_player": 7,
		"step": Mtg.Step.CLEANUP,
	})
	assert_eq(read.names_in(0, DuelPosition.HAND), ["Lightning Bolt"] as Array[String],
		"only text is a name")
	assert_eq(read.names_in(0, DuelPosition.TABLE), ["Forest", "Hill Giant"] as Array[String])
	assert_false(bool(read.table_entry(0, 0)["tapped"]), "a switch that is not a switch is off")
	assert_eq(read.lives, [1, 17] as Array[int], "clamped, and text that is a number read")
	assert_eq(read.random_cards, [DuelPosition.MAX_RANDOM, 3] as Array[int])
	assert_eq(read.active_player, 1)
	assert_eq(read.step, Mtg.Step.MAIN1, "a step a test does not begin in reads as the default")
	assert_eq(read.refusal(), "")


func test_the_log_names_the_table_and_counts_the_hand() -> void:
	var game := _game()
	assert_eq(game.begin_from_position(_position()), "")
	var lines: Array[String] = []
	for line in game.log_lines:
		if String(line).begins_with("Test hands:"):
			lines.append(String(line))
	assert_eq(lines.size(), 3, "a line per seat and one for the turn")
	assert_string_contains(lines[0], "Llanowar Elves")
	assert_string_contains(lines[0], "Forest (tapped)")
	assert_string_contains(lines[0], "2 cards in hand")
	assert_false(lines[0].contains("Lightning Bolt"),
		"the hand is counted, not named: it is the seat's secret")
	assert_string_contains(lines[1], "4 cards in hand")


# ===================================================== 9. the owner's combos --

func test_corpse_dance_brings_back_a_workhorse_put_in_the_graveyard() -> void:
	CardPacks.set_enabled("pack-9", true)
	var game := _game()
	var position := DuelPosition.new()
	position.add(0, DuelPosition.HAND, "Corpse Dance")
	position.add(0, DuelPosition.GRAVEYARD, "Workhorse")
	for i in 3:
		position.add(0, DuelPosition.TABLE, "Swamp")
	position.active_player = 0
	assert_eq(game.begin_from_position(position), "")
	for swamp in game.players[0].battlefield:
		assert_eq(game.tap_for_mana(0, swamp), "")
	var dance := game.find_in_hand(0, "Corpse Dance")
	assert_not_null(dance)
	if dance != null:
		assert_eq(game.cast_spell(0, dance, [], 0, 0), "")
		var guard := 0
		while not game.stack.is_empty() and guard < 10:
			assert_eq(game.pass_priority(game.priority_player), "")
			guard += 1
	var horse := game.find_on_battlefield(0, "Workhorse")
	assert_not_null(horse, "Workhorse came back from the top of the graveyard")
	if horse != null:
		assert_eq(int(horse.counters.get("+1/+1", 0)), 4, "with the four counters it enters with")
		assert_true(horse.has_keyword(Mtg.Keyword.HASTE))
	CardPacks.set_enabled("pack-9", false)


func test_sliver_queen_heartstone_and_the_altar_stand_against_a_random_seven() -> void:
	CardPacks.set_enabled("pack-9", true)
	var game := _game()
	var position := DuelPosition.new()
	for card_name in ["Sliver Queen", "Heartstone", "Ashnod's Altar"]:
		position.add(0, DuelPosition.TABLE, card_name)
	position.random_cards[1] = 7
	position.active_player = 0
	assert_eq(game.begin_from_position(position), "")
	assert_eq(_names(game.players[0].battlefield),
		["Sliver Queen", "Heartstone", "Ashnod's Altar"] as Array[String])
	for inst in game.players[0].battlefield:
		assert_false(inst.tapped)
		assert_false(inst.summoning_sick)
	assert_eq(game.players[1].hand.size(), 7)
	assert_eq(game.current_step(), Mtg.Step.MAIN1)
	assert_eq(game.active_player, 0)
	assert_eq(game.players[0].deck_names.count("Sliver Queen"), 1,
		"the three extras joined Seat 1's decklist")
	CardPacks.set_enabled("pack-9", false)
