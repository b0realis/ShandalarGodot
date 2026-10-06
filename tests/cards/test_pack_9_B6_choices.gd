extends GameTest
## Pack 9 (the Tempest block), batch B6: the Tempest choice cards in
## cards/sets/tmp/_choices.gd — Extinction, Intuition, Lobotomy, Mana
## Severance, Mirri's Guile, Oracle en-Vec, Phyrexian Grimoire,
## Precognition, Reap (engine package E7's target count), Sacred Guide,
## Scroll Rack and Wood Sage.
##
## Each choice goes to the seat the card names, through its agent; the
## default (heuristic) answers are pinned where they carry the hint.

const CLAIMED := ["Extinction", "Intuition", "Lobotomy", "Mana Severance", "Mirri's Guile",
	"Oracle en-Vec", "Phyrexian Grimoire", "Precognition", "Reap", "Sacred Guide", "Scroll Rack",
	"Wood Sage"]


## Scripted answers. Yes/no: true when the prompt names one of
## [member yes_names], else [member says]. A card: by name from
## [member picks], else the first candidate. An option: by label from
## [member labels], else the hint. Remembers prompts, offered cards and
## offered options.
class Seat extends DecisionAgent:
	var says := true
	var yes_names: Array[String] = []
	var picks: Array[String] = []
	var labels: Array[String] = []
	var asked: Array[String] = []
	var offered: Array[String] = []
	var options_seen: Array[String] = []
	func answer_yes_no(_g: MtgGame, _pid: int, prompt: String, _hint: bool) -> bool:
		asked.append(prompt)
		for n in yes_names:
			if prompt.contains(n): return true
		return says
	func answer_card(_g: MtgGame, _pid: int, candidates: Array[CardInstance], prompt: String) -> CardInstance:
		asked.append(prompt)
		for c in candidates: offered.append(c.data.card_name)
		while not picks.is_empty():
			var want: String = picks.pop_front()
			for c in candidates:
				if c.data.card_name == want: return c
		return null if candidates.is_empty() else candidates[0]
	func answer_option(_g: MtgGame, _pid: int, prompt: String, options: Array[String], hint: int) -> int:
		asked.append(prompt)
		options_seen.append_array(options)
		while not labels.is_empty():
			var at := options.find(labels.pop_front())
			if at >= 0: return at
		return hint


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)


func _seat(pid: int) -> Seat:
	var s := Seat.new()
	g.set_agent(pid, s)
	return s

func _pay(pid: int, card_name: String, x := 0) -> void:
	var cost := CardRegistry.get_card(card_name).cost
	for color in cost.colored:
		add_mana(pid, int(color), int(cost.colored[color]))
	var generic := cost.generic + x * cost.x_count
	if generic > 0:
		add_mana(pid, Mtg.ManaColor.C, generic)

func _try(pid: int, card_name: String, targets: Array = [], x := 0) -> String:
	var card := give_hand(pid, card_name)
	_pay(pid, card_name, x)
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	return g.cast_spell(pid, card, targets, x)

func _cast_resolve(pid: int, card_name: String, targets: Array = [], x := 0) -> void:
	assert_ok(_try(pid, card_name, targets, x))
	resolve_stack()

func _grave(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	g.put_into_graveyard(inst)
	return inst

## A fresh card on TOP of [param pid]'s library (the top is the back).
func _on_top(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.LIBRARY
	g.players[pid].library.append(inst)
	return inst

func _top(pid: int, depth := 0) -> CardInstance:
	var library := g.players[pid].library
	return library[library.size() - 1 - depth]

## [param pid]'s next upkeep, its triggers on the stack.
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

func _count(cards: Array, card_name: String) -> int:
	var n := 0
	for c in cards:
		if c.data.card_name == card_name: n += 1
	return n


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


# --------------------------------------------------------------- Extinction --

func _goblin_board() -> Array:
	var r1 := put_battlefield(1, "Mons's Goblin Raiders")
	var r2 := put_battlefield(1, "Mons's Goblin Raiders")
	var their_bear := put_battlefield(1, "Grizzly Bears")
	var brigade := put_battlefield(0, "Goblin Balloon Brigade")
	var my_bear := put_battlefield(0, "Grizzly Bears")
	return [r1, r2, their_bear, brigade, my_bear]

func test_extinction_destroys_every_creature_of_the_chosen_type() -> void:
	var board := _goblin_board()
	var seat := _seat(0)
	seat.labels = ["Bear"]
	_cast_resolve(0, "Extinction")
	assert_eq(board[2].zone, Mtg.Zone.GRAVEYARD)
	assert_eq(board[4].zone, Mtg.Zone.GRAVEYARD, "its caster's too")
	for n in [0, 1, 3]:
		assert_eq(board[n].zone, Mtg.Zone.BATTLEFIELD)
	assert_true(seat.options_seen.has("Goblin") and seat.options_seen.has("Sliver"),
		"the whole creature-type catalogue is offered")

func test_extinction_hint_picks_the_type_that_hurts_the_other_seat_most_and_allows_regeneration() -> void:
	var board := _goblin_board()
	board[0].regeneration_shields = 1
	_cast_resolve(0, "Extinction")
	assert_eq(board[1].zone, Mtg.Zone.GRAVEYARD, "Goblin: two of theirs against one of ours")
	assert_eq(board[3].zone, Mtg.Zone.GRAVEYARD)
	assert_eq(board[0].zone, Mtg.Zone.BATTLEFIELD, "it can be regenerated")
	assert_true(board[0].tapped)
	assert_eq(board[2].zone, Mtg.Zone.BATTLEFIELD)


# ---------------------------------------------------------------- Intuition --

func test_intuition_reveals_three_and_the_opponent_picks_the_one_for_the_hand() -> void:
	var bolt := _on_top(0, "Lightning Bolt")
	var wurm := _on_top(0, "Craw Wurm")
	var angel := _on_top(0, "Serra Angel")
	_on_top(0, "Forest")
	var me := _seat(0)
	me.picks = ["Lightning Bolt", "Craw Wurm", "Serra Angel"]
	var them := _seat(1)
	them.picks = ["Lightning Bolt"]
	var library := g.players[0].library.size()
	_cast_resolve(0, "Intuition", [TargetRef.player(1)])
	assert_eq(bolt.zone, Mtg.Zone.HAND)
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].library.size(), library - 3)
	assert_eq(them.offered.size(), 3, "the opponent chose among the three revealed cards")

func test_intuition_takes_what_a_short_library_holds_and_targets_only_an_opponent() -> void:
	assert_refused(_try(0, "Intuition", [TargetRef.player(0)]))
	while not g.players[0].library.is_empty():
		g.exile_library_card(_top(0))
	var a := _on_top(0, "Lightning Bolt")
	var b := _on_top(0, "Craw Wurm")
	_cast_resolve(0, "Intuition", [TargetRef.player(1)])
	assert_eq(g.players[0].library.size(), 0)
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD, "the opponent's default gives the caster the weaker card")
	assert_eq(a.zone, Mtg.Zone.HAND)


# ----------------------------------------------------------------- Lobotomy --

func _lobotomy_setup() -> Array:
	var in_hand := give_hand(1, "Lightning Bolt")
	var forest := give_hand(1, "Forest")
	var bear := give_hand(1, "Grizzly Bears")
	var in_grave := _grave(1, "Lightning Bolt")
	var in_library := _on_top(1, "Lightning Bolt")
	return [in_hand, forest, bear, in_grave, in_library]

func test_lobotomy_exiles_every_copy_from_graveyard_hand_and_library() -> void:
	var cards := _lobotomy_setup()
	var seat := _seat(0)
	seat.picks = ["Lightning Bolt"]
	_cast_resolve(0, "Lobotomy", [TargetRef.player(1)])
	for n in [0, 3, 4]:
		assert_eq(cards[n].zone, Mtg.Zone.EXILE)
	assert_eq(cards[1].zone, Mtg.Zone.HAND)
	assert_eq(cards[2].zone, Mtg.Zone.HAND)
	assert_false(seat.offered.has("Forest"), "a basic land card can't be chosen")
	assert_eq(_count(g.players[1].library, "Lightning Bolt"), 0)

func test_lobotomy_may_fail_to_find_in_the_hidden_zones_but_not_the_graveyard() -> void:
	var cards := _lobotomy_setup()
	var seat := _seat(0)
	seat.picks = ["Lightning Bolt"]
	seat.says = false
	_cast_resolve(0, "Lobotomy", [TargetRef.player(1)])
	assert_eq(cards[3].zone, Mtg.Zone.EXILE, "the graveyard is public")
	assert_eq(cards[0].zone, Mtg.Zone.HAND)
	assert_eq(cards[4].zone, Mtg.Zone.LIBRARY)

func test_lobotomy_on_a_hand_of_basic_lands_chooses_nothing() -> void:
	var forest := give_hand(1, "Forest")
	var island := give_hand(1, "Island")
	var seat := _seat(0)
	_cast_resolve(0, "Lobotomy", [TargetRef.player(1)])
	assert_eq(forest.zone, Mtg.Zone.HAND)
	assert_eq(island.zone, Mtg.Zone.HAND)
	assert_true(seat.offered.is_empty())


# ----------------------------------------------------------- Mana Severance --

func test_mana_severance_exiles_the_chosen_land_cards_only() -> void:
	for n in 3: _on_top(0, "Island")
	var bolt := _on_top(0, "Lightning Bolt")
	var seat := _seat(0)
	seat.labels = ["30", "1"]   # every Forest, one Island
	_cast_resolve(0, "Mana Severance")
	assert_eq(g.players[0].library.size(), 3)
	assert_eq(_count(g.players[0].library, "Island"), 2)
	assert_eq(bolt.zone, Mtg.Zone.LIBRARY)
	assert_eq(_count(g.players[0].exile, "Forest"), 30)

func test_mana_severance_hint_keeps_six_lands_in_sight() -> void:
	for n in 3: _on_top(0, "Island")
	_on_top(0, "Lightning Bolt")
	_cast_resolve(0, "Mana Severance")
	assert_eq(g.players[0].library.size(), 7, "six lands and the Bolt")
	assert_eq(_count(g.players[0].library, "Lightning Bolt"), 1)


# ------------------------------------------------------------ Mirri's Guile --

func test_mirris_guile_reorders_the_top_three_at_your_upkeep() -> void:
	put_battlefield(0, "Mirri's Guile")
	advance_to_next_turn()   # P1's turn: nothing of P0's is drawn before its upkeep
	var bears := _on_top(0, "Grizzly Bears")
	var bolt := _on_top(0, "Lightning Bolt")
	var wurm := _on_top(0, "Craw Wurm")
	var seat := _seat(0)
	seat.picks = ["Lightning Bolt", "Grizzly Bears"]
	_to_upkeep_of(0)
	resolve_stack()
	assert_eq(_top(0, 0), bolt)
	assert_eq(_top(0, 1), bears)
	assert_eq(_top(0, 2), wurm)

func test_mirris_guile_may_be_declined_and_ignores_the_opponents_upkeep() -> void:
	put_battlefield(0, "Mirri's Guile")
	var seat := _seat(0)
	seat.says = false
	_to_upkeep_of(1)
	assert_true(g.stack.is_empty(), "only your upkeep")
	advance_to_step(Mtg.Step.MAIN1)
	var bears := _on_top(0, "Grizzly Bears")
	var bolt := _on_top(0, "Lightning Bolt")
	_to_upkeep_of(0)
	resolve_stack()
	assert_eq(_top(0, 0), bolt)
	assert_eq(_top(0, 1), bears)


# ------------------------------------------------------------ Oracle en-Vec --

func _oracle_board() -> Array:
	var oracle := put_battlefield(0, "Oracle en-Vec")
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Stone")
	return [oracle, bear, giant, wall]

## Advance to P1's declare-attackers decision.
func _to_their_attack() -> void:
	var guard := 0
	while not (g.active_player == 1 and g.awaiting_attackers) and guard < 400:
		_advance_once()
		guard += 1
	assert_true(g.awaiting_attackers)

func test_oracle_en_vec_forces_the_chosen_to_attack_and_grounds_the_rest() -> void:
	var b := _oracle_board()
	var seat := _seat(1)
	seat.yes_names = ["Grizzly Bears", "Wall of Stone"]
	seat.says = false
	assert_ok(g.activate_ability(0, b[0], 0, [TargetRef.player(1)]))
	resolve_stack()
	_to_their_attack()
	assert_refused(g.declare_attackers(1, []), "Grizzly Bears")
	assert_refused(g.declare_attackers(1, [b[1].id, b[2].id]))
	assert_ok(g.declare_attackers(1, [b[1].id]))
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(b[1].zone, Mtg.Zone.BATTLEFIELD, "it attacked")
	assert_eq(b[3].zone, Mtg.Zone.GRAVEYARD, "chosen, unable to attack, destroyed")
	assert_eq(b[2].zone, Mtg.Zone.BATTLEFIELD, "not chosen: only grounded")
	advance_to_next_turn()
	advance_to_next_turn()
	_to_their_attack()
	assert_eq(g.declare_attackers(1, [b[2].id]), "", "only that turn")

func test_oracle_en_vec_only_during_your_turn_and_the_default_chooser() -> void:
	var b := _oracle_board()
	advance_to_next_turn()
	assert_ok(g.pass_priority(1))
	assert_refused(g.activate_ability(0, b[0], 0, [TargetRef.player(1)]))
	advance_to_next_turn()
	assert_refused(g.activate_ability(0, b[0], 0, [TargetRef.player(0)]))
	assert_ok(g.activate_ability(0, b[0], 0, [TargetRef.player(1)]))
	resolve_stack()
	_to_their_attack()
	# The heuristic chooser picks what can attack and outlasts the Oracle
	# controller's biggest striker (a 1/1): the Bears and the Giant; the
	# Wall can't attack and stays out of it.
	assert_refused(g.declare_attackers(1, [b[1].id]), "Hill Giant")
	assert_ok(g.declare_attackers(1, [b[1].id, b[2].id]))
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	for n in [1, 2, 3]:
		assert_eq(b[n].zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------------- Phyrexian Grimoire --

func _grimoire_setup() -> Array:
	var grimoire := put_battlefield(0, "Phyrexian Grimoire")
	var bears := _grave(0, "Grizzly Bears")
	var bolt := _grave(0, "Lightning Bolt")
	var wurm := _grave(0, "Craw Wurm")
	add_mana(0, Mtg.ManaColor.C, 4)
	return [grimoire, bears, bolt, wurm]

func test_phyrexian_grimoire_the_opponent_splits_the_top_two() -> void:
	var c := _grimoire_setup()
	var them := _seat(1)
	them.picks = ["Lightning Bolt"]
	assert_ok(g.activate_ability(0, c[0], 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(c[2].zone, Mtg.Zone.EXILE)
	assert_eq(c[3].zone, Mtg.Zone.HAND)
	assert_eq(c[1].zone, Mtg.Zone.GRAVEYARD, "only the top two")
	assert_eq(them.offered.size(), 2)

func test_phyrexian_grimoire_default_exiles_the_better_card_and_targets_an_opponent() -> void:
	var c := _grimoire_setup()
	assert_refused(g.activate_ability(0, c[0], 0, [TargetRef.player(0)]))
	assert_ok(g.activate_ability(0, c[0], 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(c[3].zone, Mtg.Zone.EXILE, "the opponent takes away the Craw Wurm")
	assert_eq(c[2].zone, Mtg.Zone.HAND)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_refused(g.activate_ability(0, c[0], 0, [TargetRef.player(1)]), "")

func test_phyrexian_grimoire_with_one_card_exiles_it() -> void:
	var grimoire := put_battlefield(0, "Phyrexian Grimoire")
	var only := _grave(0, "Craw Wurm")
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, grimoire, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(only.zone, Mtg.Zone.EXILE)


# ------------------------------------------------------------- Precognition --

func test_precognition_looks_at_the_opponents_top_card_and_may_bottom_it() -> void:
	put_battlefield(0, "Precognition")
	advance_to_next_turn()
	var angel := _on_top(1, "Serra Angel")
	_to_upkeep_of(0)
	resolve_stack()
	assert_eq(g.players[1].library[0], angel, "the hint bottoms a good card")

func test_precognition_declined_leaves_the_library() -> void:
	put_battlefield(0, "Precognition")
	var seat := _seat(0)
	seat.says = false
	advance_to_next_turn()
	var angel := _on_top(1, "Serra Angel")
	_to_upkeep_of(0)
	resolve_stack()
	assert_eq(_top(1), angel)
	for prompt in seat.asked:
		assert_false(prompt.contains("bottom"), "declining the look skips the second question")


# --------------------------------------------------------------------- Reap --

func test_reap_returns_up_to_x_where_x_counts_the_target_opponents_black_permanents() -> void:
	put_battlefield(1, "Black Knight")
	put_battlefield(1, "Scathe Zombies")
	put_battlefield(1, "Swamp")   # a land is colorless
	var a := _grave(0, "Grizzly Bears")
	var b := _grave(0, "Hill Giant")
	var c := _grave(0, "Llanowar Elves")
	assert_refused(_try(0, "Reap", [TargetRef.player(1), TargetRef.card(a), TargetRef.card(b), TargetRef.card(c)]))
	_cast_resolve(0, "Reap", [TargetRef.player(1), TargetRef.card(a), TargetRef.card(b)])
	assert_eq(a.zone, Mtg.Zone.HAND)
	assert_eq(b.zone, Mtg.Zone.HAND)
	assert_eq(c.zone, Mtg.Zone.GRAVEYARD)

func test_reap_with_no_black_permanents_returns_nothing_and_counts_as_cast() -> void:
	var a := _grave(0, "Grizzly Bears")
	assert_refused(_try(0, "Reap", [TargetRef.player(1), TargetRef.card(a)]))
	_cast_resolve(0, "Reap", [TargetRef.player(1)])
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	var knight := put_battlefield(1, "Black Knight")
	var reap := give_hand(0, "Reap")
	_pay(0, "Reap")
	assert_ok(g.cast_spell(0, reap, [TargetRef.player(1), TargetRef.card(a)]))
	g.destroy(knight)
	resolve_stack()
	assert_eq(a.zone, Mtg.Zone.HAND, "X was fixed as Reap was cast")

func test_reap_is_an_instant_aimed_at_an_opponent() -> void:
	put_battlefield(0, "Black Knight")
	var a := _grave(0, "Grizzly Bears")
	assert_refused(_try(0, "Reap", [TargetRef.player(0), TargetRef.card(a)]))


# ------------------------------------------------------------- Sacred Guide --

func test_sacred_guide_digs_to_the_first_white_card_and_exiles_the_rest_revealed() -> void:
	var guide := put_battlefield(0, "Sacred Guide")
	var angel := _on_top(0, "Serra Angel")
	var knight := _on_top(0, "White Knight")
	var bolt := _on_top(0, "Lightning Bolt")
	var forest := _on_top(0, "Forest")
	var library := g.players[0].library.size()
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, guide, 0))
	assert_eq(guide.zone, Mtg.Zone.GRAVEYARD, "sacrificed as the cost")
	resolve_stack()
	assert_eq(knight.zone, Mtg.Zone.HAND)
	assert_eq(bolt.zone, Mtg.Zone.EXILE)
	assert_eq(forest.zone, Mtg.Zone.EXILE)
	assert_eq(angel.zone, Mtg.Zone.LIBRARY, "the reveal stopped at the first white card")
	assert_eq(g.players[0].library.size(), library - 3)

func test_sacred_guide_with_no_white_card_exiles_the_whole_library() -> void:
	var guide := put_battlefield(0, "Sacred Guide")
	assert_refused(g.activate_ability(0, guide, 0), "")
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, guide, 0))
	resolve_stack()
	assert_eq(g.players[0].library.size(), 0)
	assert_false(g.game_over, "an empty library is no loss until a draw")


# -------------------------------------------------------------- Scroll Rack --

func test_scroll_rack_swaps_hand_cards_for_the_top_ones_without_drawing() -> void:
	var rack := put_battlefield(0, "Scroll Rack")
	var bolt := give_hand(0, "Lightning Bolt")
	var bears := give_hand(0, "Grizzly Bears")
	var wurm := give_hand(0, "Craw Wurm")
	var giant := _on_top(0, "Hill Giant")
	var angel := _on_top(0, "Serra Angel")
	var seat := _seat(0)
	seat.yes_names = ["Lightning Bolt", "Grizzly Bears"]
	seat.says = false
	seat.picks = ["Grizzly Bears"]
	var drawn := g.players[0].drawn_this_turn.size()
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, rack, 0))
	resolve_stack()
	for c in [wurm, giant, angel]:
		assert_eq(c.zone, Mtg.Zone.HAND, c.data.card_name)
	assert_eq(_top(0, 0), bears, "the first answer ends on top")
	assert_eq(_top(0, 1), bolt)
	assert_false(bears.face_down)
	assert_false(bolt.face_down)
	assert_eq(g.players[0].drawn_this_turn.size(), drawn, "putting cards into a hand is not drawing")
	assert_eq(g.players[0].exile.size(), 0)

func test_scroll_rack_choosing_nothing_does_nothing_and_needs_its_tap() -> void:
	var rack := put_battlefield(0, "Scroll Rack")
	var bolt := give_hand(0, "Lightning Bolt")
	var top := _top(0)
	var seat := _seat(0)
	seat.says = false
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, rack, 0))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.HAND)
	assert_eq(_top(0), top)
	assert_refused(g.activate_ability(0, rack, 0), "")


# ---------------------------------------------------------------- Wood Sage --

func test_wood_sage_names_a_creature_from_its_decklist_and_keeps_every_copy_revealed() -> void:
	var names: Array[String] = ["Grizzly Bears", "Grizzly Bears", "Hill Giant", "Forest", "Lightning Bolt"]
	g.players[0].deck_names = names
	var sage := put_battlefield(0, "Wood Sage")
	var giant := _on_top(0, "Hill Giant")
	var bear_a := _on_top(0, "Grizzly Bears")
	var forest := _on_top(0, "Forest")
	var bear_b := _on_top(0, "Grizzly Bears")
	var seat := _seat(0)
	seat.labels = ["Grizzly Bears"]
	assert_ok(g.activate_ability(0, sage, 0))
	resolve_stack()
	assert_eq(bear_a.zone, Mtg.Zone.HAND)
	assert_eq(bear_b.zone, Mtg.Zone.HAND)
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_true(seat.options_seen.has("Hill Giant"))
	assert_false(seat.options_seen.has("Forest"), "creature card names only")
	assert_false(seat.options_seen.has("Lightning Bolt"))

func test_wood_sage_with_nothing_to_name_mills_the_four() -> void:
	var sage := put_battlefield(0, "Wood Sage")
	var library := g.players[0].library.size()
	var grave := g.players[0].graveyard.size()
	assert_ok(g.activate_ability(0, sage, 0))
	resolve_stack()
	assert_eq(g.players[0].library.size(), library - 4)
	assert_eq(g.players[0].graveyard.size(), grave + 4)
	assert_refused(g.activate_ability(0, sage, 0), "")


# ------------------------------------------------------------------ timing --

func test_sorceries_wait_for_the_main_phase_and_instants_do_not() -> void:
	_grave(0, "Grizzly Bears")
	advance_to_next_turn()   # P1's turn
	assert_ne(_try(0, "Extinction"), "", "Extinction is a sorcery")
	assert_ne(_try(0, "Lobotomy", [TargetRef.player(1)]), "", "Lobotomy is a sorcery")
	assert_ne(_try(0, "Mana Severance"), "", "Mana Severance is a sorcery")
	var top := _on_top(0, "Lightning Bolt")
	var me := _seat(0)
	me.picks = ["Lightning Bolt"]
	_cast_resolve(0, "Intuition", [TargetRef.player(1)])
	assert_ne(top.zone, Mtg.Zone.LIBRARY, "Intuition is an instant")
	_cast_resolve(0, "Reap", [TargetRef.player(1)])
	assert_true(g.stack.is_empty(), "Reap is an instant")


# ------------------------------------------------------ both rules presets --

## Nothing here reads a rules fork, the 1997 artifact rule included: a
## tapped artifact's ACTIVATED ability is no continuous effect.
func test_choices_behave_the_same_under_both_rules_presets() -> void:
	for preset in ["modern_mana_burn", "fifth"]:
		before_each()
		g.rules.set_preset(preset)
		var c := _grimoire_setup()
		assert_ok(g.activate_ability(0, c[0], 0, [TargetRef.player(1)]))
		resolve_stack()
		assert_eq(c[3].zone, Mtg.Zone.EXILE, preset)
		assert_eq(c[2].zone, Mtg.Zone.HAND, preset)
		put_battlefield(1, "Black Knight")
		var a := _grave(0, "Hill Giant")
		_cast_resolve(0, "Reap", [TargetRef.player(1), TargetRef.card(a)])
		assert_eq(a.zone, Mtg.Zone.HAND, preset)
		assert_false(g.game_over, preset)
