extends GameTest
## §1.3 of docs/duel-todo.md, the SECOND HALF — the engine holds a resolution
## OPEN for a question the player has not answered, the FIRST time a card
## asks it.
##
## The mechanism is a pre-flight, not an await: `MtgGame._preflight` resolves
## the top of the stack once over a [GameSnapshot], notes what it asked, and
## rewinds. Nothing of that run survives — no log line, no event, no state
## signal, no ledger entry, no rng draw. What survives is the QUESTION, which
## goes on `awaiting_choice` and holds the duel exactly as awaiting_attackers
## and awaiting_discard already do, until `answer_choice` arrives.
##
## Everything here is behind `interactive_choices`, which is OFF by default:
## `test_player_choices.gd` pins the unchanged behaviour of every other seat.


func _human_seat(pid := 0) -> HumanAgent:
	var human := HumanAgent.new()
	g.agents[pid] = human
	g.interactive_choices = true
	return human


func _junun(pid := 0) -> CardInstance:
	# "At the beginning of your upkeep, sacrifice Junún Efreet unless you
	# pay {B}{B}" — the shape most of the 81 questions share.
	var efreet := put_battlefield(pid, "Junún Efreet")
	put_battlefield(pid, "Swamp")
	put_battlefield(pid, "Swamp")
	return efreet


## Walk to the UPKEEP of [param turn], where that turn's trigger is already
## on the chain and the resolution has not started.
func _to_upkeep_of_turn(turn: int) -> void:
	var guard := 0
	while not (g.turn_number == turn and g.current_step() == Mtg.Step.UPKEEP) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400, "did not reach turn %d's upkeep" % turn)


# ------------------------------------------------- the rewind point itself --

func test_a_snapshot_rewinds_the_whole_game() -> void:
	var efreet := _junun(0)
	give_hand(0, "Lightning Bolt")
	var snap := GameSnapshot.take(g)
	var before := g.log_lines.size()
	# Mutate a lot of different state, then put it all back.
	g.adjust_life(0, -7)
	g.discard_cards(0, [g.players[0].hand[0]])
	g.sacrifice_permanent(efreet)
	g.players[0].mana_pool.add(Mtg.ManaColor.B, 3)
	g.rng.randi()
	snap.restore()
	assert_eq(g.players[0].life, 20, "life is back")
	assert_eq(g.players[0].hand.size(), 1, "the hand is back")
	assert_eq(efreet.zone, Mtg.Zone.BATTLEFIELD, "the Efreet is back on the field")
	assert_true(g.players[0].battlefield.has(efreet), "and in the zone array")
	assert_eq(g.players[0].mana_pool.total(), 0, "the pool is back")
	assert_eq(g.log_lines.size(), before, "the log is back")


func test_a_snapshot_puts_the_rng_back() -> void:
	var snap := GameSnapshot.take(g)
	var first := g.rng.randi()
	snap.restore()
	assert_eq(g.rng.randi(), first, "a rewound coin flip flips the same way")


func test_a_snapshot_keeps_object_identity() -> void:
	var efreet := _junun(0)
	var snap := GameSnapshot.take(g)
	g.sacrifice_permanent(efreet)
	snap.restore()
	assert_eq(g.find_instance(efreet.id), efreet,
		"the rewind writes onto the same objects, so held references survive")


# ------------------------------------------------------- holding the duel --

func test_the_first_ask_now_reaches_the_player() -> void:
	_human_seat(0)
	var efreet := _junun(0)
	_to_upkeep_of_turn(3)
	assert_eq(g.stack.size(), 1, "the upkeep trigger is on the chain")
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))
	assert_not_null(g.awaiting_choice, "the resolution is held open")
	var asked: PlayerChoice = g.awaiting_choice
	assert_eq(asked.kind, PlayerChoice.Kind.YES_NO)
	assert_eq(asked.pid, 0)
	assert_eq(asked.source, "Junún Efreet")
	assert_string_contains(asked.prompt, "Junún Efreet")
	assert_eq(efreet.zone, Mtg.Zone.BATTLEFIELD,
		"and nothing has happened yet — the probe was rewound")
	assert_eq(g.stack.size(), 1, "the trigger is still waiting")
	assert_eq(g.unanswered_choices.size(), 0,
		"nobody was overruled: the question is still open")


func test_the_probe_leaves_no_trace_in_the_log() -> void:
	_human_seat(0)
	_junun(0)
	_to_upkeep_of_turn(3)
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))
	for line in g.log_lines:
		assert_false(line.begins_with("(decided for P0)"),
			"a held question is not a decided one")
	assert_eq(g.choice_log.size(), 0, "the probe files nothing")


func test_answering_no_resolves_the_players_way() -> void:
	_human_seat(0)
	var efreet := _junun(0)
	_to_upkeep_of_turn(3)
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.answer_choice(false))
	assert_null(g.awaiting_choice, "the question is closed")
	assert_eq(efreet.zone, Mtg.Zone.GRAVEYARD, "declined the rent")
	assert_eq(g.unanswered_choices.size(), 0,
		"the player answered, so nothing is owed to them")
	assert_eq(g.choice_log.size(), 1, "the REAL resolution filed one question")
	assert_true((g.choice_log[0] as PlayerChoice).answered_by_player)


func test_answering_yes_resolves_the_players_way() -> void:
	_human_seat(0)
	var efreet := _junun(0)
	_to_upkeep_of_turn(3)
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.answer_choice(true))
	assert_eq(efreet.zone, Mtg.Zone.BATTLEFIELD, "paid the rent")
	var swamps_tapped := 0
	for inst in g.players[0].battlefield:
		if inst.data.card_name == "Swamp" and inst.tapped:
			swamps_tapped += 1
	assert_eq(swamps_tapped, 2, "and really paid it")


func test_the_duel_is_frozen_while_a_question_is_open() -> void:
	_human_seat(0)
	_junun(0)
	_to_upkeep_of_turn(3)
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))
	assert_refused(g.pass_priority(g.priority_player), "choice")
	assert_ok(g.answer_choice(true))            # ...and then the duel runs on
	assert_null(g.awaiting_choice)
	assert_eq(g.answer_choice(true), "nothing is waiting on a choice",
		"and a second answer has nothing to answer")


func test_a_seat_that_answers_for_itself_is_never_held() -> void:
	g.interactive_choices = true
	_junun(1)                      # the default agent owns seat 1
	advance_to_next_turn()
	advance_to_next_turn()
	assert_null(g.awaiting_choice, "only a seat that wants to be asked holds")


func test_the_flag_is_opt_in() -> void:
	_human_seat(0)
	g.interactive_choices = false
	var efreet := _junun(0)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_null(g.awaiting_choice)
	assert_eq(efreet.zone, Mtg.Zone.BATTLEFIELD, "the heuristic paid, as before")
	assert_gt(g.unanswered_choices.size(), 0, "and said so, as before")


func test_a_card_choice_reaches_the_player_too() -> void:
	var human := _human_seat(0)
	g.players[0].library.append(_library_card(0, "Lightning Bolt"))
	var tutor := give_hand(0, "Demonic Tutor")
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, tutor))
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))
	assert_not_null(g.awaiting_choice, "the tutor's search is a question")
	var asked: PlayerChoice = g.awaiting_choice
	assert_eq(asked.kind, PlayerChoice.Kind.CARD)
	assert_true(asked.optional, "a search may fail to find (CR 701.19b)")
	var names := PackedStringArray()
	for inst in asked.candidates:
		names.append((inst as CardInstance).data.card_name)
	assert_true(names.has("Lightning Bolt"), "the real candidates come with it")
	assert_ok(g.answer_choice("Lightning Bolt"))
	assert_eq(human.has_parked(), false, "the answer was spent")
	var found := false
	for inst in g.players[0].hand:
		if inst.data.card_name == "Lightning Bolt":
			found = true
	assert_true(found, "the player's own pick came to hand")


func _library_card(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.LIBRARY
	return inst


# ------------------------------------------- the rewind changes NOTHING --
#
# The strongest thing that can be said about a probe is that a duel played
# WITH it and a duel played WITHOUT it are the same duel, line for line —
# because the probe is answered with exactly what the heuristic decided
# (PlayerChoice.answer is the heuristic's own answer) and then rewound. Any
# state the rewind misses, any rng draw it fails to put back and any log
# line that escapes it shows up here as a divergence.

## A seat that wants to be asked and serves back whatever the engine handed
## it — the minimum HumanAgent, without the UI's discard and damage holds.
class Asked extends DecisionAgent:
	var _parked: Array = []

	func wants_to_be_asked() -> bool:
		return true

	func accept_answer(choice: PlayerChoice, value: Variant) -> void:
		_parked.append({"kind": choice.kind, "value": value})

	func end_resolution(_source: String) -> void:
		_parked.clear()

	func _take(kind: int) -> Variant:
		if _parked.is_empty() or int(_parked[0]["kind"]) != kind:
			return null
		mark_answered_by_player()
		return _parked.pop_front()

	func answer_yes_no(game: MtgGame, pid: int, prompt: String, hint: bool) -> bool:
		var got: Variant = _take(PlayerChoice.Kind.YES_NO)
		return bool(got["value"]) if got != null \
			else super.answer_yes_no(game, pid, prompt, hint)

	func answer_color(game: MtgGame, pid: int, prompt: String, hint: int) -> int:
		var got: Variant = _take(PlayerChoice.Kind.COLOR)
		return int(got["value"]) if got != null \
			else super.answer_color(game, pid, prompt, hint)

	func answer_card(game: MtgGame, pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		var got: Variant = _take(PlayerChoice.Kind.CARD)
		return got["value"] if got != null \
			else super.answer_card(game, pid, candidates, prompt)

	func answer_discard(game: MtgGame, pid: int, count: int) -> Array[CardInstance]:
		var got: Variant = _take(PlayerChoice.Kind.DISCARD)
		if got == null:
			return super.answer_discard(game, pid, count)
		var out: Array[CardInstance] = []
		for inst in got["value"]:
			out.append(inst)
		return out


## Play [param turns] turns of a rent-heavy board and return the game log.
func _play_out(interactive: bool, turns: int) -> PackedStringArray:
	var game := MtgGame.new()
	var filler: Array = []
	for i in 30:
		filler.append("Forest")
	game.setup(filler, filler, "P0", "P1", 20, 20, 424242)
	game.start(0)
	game.interactive_choices = interactive
	if interactive:
		game.agents[0] = Asked.new()
		game.agents[1] = Asked.new()
	for pid in 2:
		for card_name in ["Junún Efreet", "Stasis", "Swamp", "Swamp", "Island"]:
			var data := CardRegistry.get_card(card_name)
			var inst := CardInstance.new(data, game._next_instance_id, pid)
			game._next_instance_id += 1
			game._instances[inst.id] = inst
			game._put_on_battlefield(inst, pid)
			inst.summoning_sick = false
	var guard := 0
	while game.turn_number <= turns and not game.game_over and guard < 900:
		guard += 1
		if game.awaiting_choice != null:
			game.answer_choice(game.awaiting_choice.answer)
		elif game.awaiting_attackers:
			game.declare_attackers(game.active_player, [])
		elif game.awaiting_blockers:
			game.declare_blockers(game.opponent_of(game.active_player), {})
		else:
			game.pass_priority(game.priority_player)
	assert_lt(guard, 900, "the duel converged")
	return game.log_lines


func test_a_probed_duel_is_the_same_duel() -> void:
	var plain := _play_out(false, 8)
	var probed := _play_out(true, 8)
	assert_gt(plain.size(), 40, "something actually happened")
	assert_eq(probed.size(), plain.size(), "same number of log lines")
	for i in mini(plain.size(), probed.size()):
		assert_eq(probed[i], plain[i], "log line %d" % i)
