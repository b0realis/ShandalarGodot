extends GameTest
## Fidelity pass 2026-09-02 — TIME VAULT's skip-your-turn clause, lifted
## from docs/simplified-cards.md. "If you would begin your turn while this
## artifact is tapped, you may skip that turn instead. If you do, untap
## this artifact." is a replacement effect on the BEGINNING of the turn
## (CR 614.10): the question is put as the turn begins, before the untap
## step, and a skipped turn is proceeded past as though it did not exist
## (CR 500.9) — no untap step, no upkeep, no draw, no cleanup. Duel.hlp
## carries the same ruling in 1997 words ("As your turn begins (and before
## your untap phase begins), you decide whether or not to skip that turn"),
## and `@TIME_VAULT` is the prompt: "Play this turn." / "Skip this turn to
## untap." The ask goes through the turn-based hold (MtgGame._begin_turn),
## so a human seat is held on it like any untap-step question.


## Answers the Vault's question with a fixed index and records where it
## was asked from.
class VaultSeat extends DecisionAgent:
	var index := 0
	var asks: Array = []   # [step, forest_was_tapped] per ask

	func answer_option(game: MtgGame, _pid: int, prompt: String,
			options: Array[String], _hint: int) -> int:
		var forest_tapped := false
		for inst in game.players[0].battlefield:
			if inst.data.card_name == "Forest":
				forest_tapped = inst.tapped
		asks.append({"step": game.current_step(), "prompt": prompt,
			"options": options.duplicate(), "forest_tapped": forest_tapped})
		return index


func _human_seat(pid := 0) -> HumanAgent:
	var human := HumanAgent.new()
	g.agents[pid] = human
	g.interactive_choices = true
	return human


func _advance_until_held() -> void:
	var guard := 0
	while g.awaiting_choice == null and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_not_null(g.awaiting_choice, "the turn held on a question")


## A tapped Vault and a tapped Forest for P0; the seat answers [param index].
func _setup(index: int) -> Dictionary:
	var vault := put_battlefield(0, "Time Vault")
	var forest := put_battlefield(0, "Forest")
	forest.tapped = true
	var seat := VaultSeat.new()
	seat.index = index
	g.set_agent(0, seat)
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_next_turn()   # P1's turn 2
	return {"vault": vault, "forest": forest, "seat": seat}


func test_the_question_comes_as_the_turn_begins_before_the_untap_step() -> void:
	var s := _setup(1)
	var hand_before := g.players[0].hand.size()
	advance_to_next_turn()   # P0's turn 3 — skipped — lands on P1's turn 4
	var seat: VaultSeat = s["seat"]
	assert_eq(seat.asks.size(), 1, "asked once, as turn 3 began")
	assert_eq(int(seat.asks[0]["step"]), Mtg.Step.UNTAP,
		"asked as the turn begins, in its first step")
	assert_true(bool(seat.asks[0]["forest_tapped"]),
		"before the untap step has untapped anything")
	assert_eq(seat.asks[0]["options"], ["Play this turn.", "Skip this turn to untap."],
		"`@TIME_VAULT`'s two lines")
	assert_false(s["vault"].tapped, "skipping the turn untapped the Vault")
	assert_true(s["forest"].tapped, "the skipped turn had no untap step")
	assert_eq(g.players[0].hand.size(), hand_before, "and no draw step")
	assert_eq(g.active_player, 1, "the opponent's turn follows the skipped one")
	assert_eq(g.turn_number, 4)
	assert_string_contains("\n".join(g.log_lines), "P0 skips the turn")


func test_playing_the_turn_keeps_it_whole() -> void:
	var s := _setup(0)
	var hand_before := g.players[0].hand.size()
	advance_to_next_turn()   # P0's turn 3, played
	assert_eq(g.active_player, 0)
	assert_eq(g.turn_number, 3)
	assert_true(s["vault"].tapped, "the Vault never untaps on its own")
	assert_false(s["forest"].tapped, "the untap step ran")
	assert_eq(g.players[0].hand.size(), hand_before + 1, "and the draw step")
	assert_eq((s["seat"] as VaultSeat).asks.size(), 1)


func test_an_untapped_vault_asks_nothing() -> void:
	var s := _setup(1)
	s["vault"].tapped = false
	advance_to_next_turn()   # P0's turn 3
	assert_eq(g.active_player, 0)
	assert_eq((s["seat"] as VaultSeat).asks.size(), 0,
		"the clause only applies while the Vault is tapped")


func test_the_skipped_turn_has_no_upkeep() -> void:
	var s := _setup(1)
	var upkeeps: Array = []
	g.event_occurred.connect(func(ev: GameEvent) -> void:
		if ev.type == Mtg.EventType.UPKEEP_START:
			upkeeps.append(int(ev.data["player"])))
	advance_to_next_turn()   # turn 3 skipped, turn 4 is P1's
	assert_eq(upkeeps, [1], "P0's skipped turn had no upkeep; P1's turn 4 did")
	assert_false(s["vault"].tapped)


func test_only_one_vault_untaps_per_skipped_turn() -> void:
	var s := _setup(1)
	var second := put_battlefield(0, "Time Vault")
	assert_true(second.tapped)
	advance_to_next_turn()   # turn 3 skipped
	var untapped := 0
	for vault in [s["vault"], second]:
		if not vault.tapped:
			untapped += 1
	assert_eq(untapped, 1, "once the turn is skipped it is no longer beginning (CR 616.1)")
	assert_eq((s["seat"] as VaultSeat).asks.size(), 1, "the second Vault is not asked about")
	advance_to_next_turn()   # turn 5: the other Vault asks again
	assert_eq((s["seat"] as VaultSeat).asks.size(), 2)
	assert_eq(untapped, 1)
	for vault in [s["vault"], second]:
		assert_false(vault.tapped, "both untapped over two skipped turns")
	assert_eq(g.active_player, 1)
	assert_eq(g.turn_number, 6)


func test_the_opponents_turn_is_untouched() -> void:
	var s := _setup(1)
	var theirs := put_battlefield(1, "Forest")
	theirs.tapped = true
	var their_hand := g.players[1].hand.size()
	advance_to_next_turn()   # turn 3 skipped, turn 4 is P1's
	assert_eq(g.active_player, 1)
	assert_false(theirs.tapped, "P1's untap step ran")
	assert_eq(g.players[1].hand.size(), their_hand + 1, "and their draw")
	assert_false(s["vault"].tapped)


func test_a_human_seat_is_held_on_the_question_and_may_skip() -> void:
	var vault := put_battlefield(0, "Time Vault")
	var forest := put_battlefield(0, "Forest")
	forest.tapped = true
	_human_seat(0)
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_next_turn()   # P1's turn 2
	_advance_until_held()
	var q: PlayerChoice = g.awaiting_choice
	assert_eq(q.kind, PlayerChoice.Kind.OPTION)
	assert_eq(q.pid, 0)
	assert_eq(q.source, "Time Vault")
	assert_eq(q.step, Mtg.Step.UNTAP)
	assert_eq(q.options, ["Play this turn.", "Skip this turn to untap."])
	assert_true(forest.tapped, "held before anything untapped")
	assert_eq(g.turn_number, 3)
	assert_ok(g.answer_choice(1))
	assert_null(g.awaiting_choice)
	assert_false(vault.tapped, "the answer untapped the Vault")
	assert_true(forest.tapped, "and the turn was skipped whole")
	assert_eq(g.active_player, 1)
	assert_eq(g.turn_number, 4)


func test_a_human_seat_may_play_the_turn() -> void:
	var vault := put_battlefield(0, "Time Vault")
	var forest := put_battlefield(0, "Forest")
	forest.tapped = true
	_human_seat(0)
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_next_turn()   # P1's turn 2
	_advance_until_held()
	assert_ok(g.answer_choice(0))
	assert_null(g.awaiting_choice)
	assert_true(vault.tapped)
	assert_false(forest.tapped, "the untap step followed the answer")
	assert_eq(g.active_player, 0)
	assert_eq(g.turn_number, 3)
	assert_eq(g.current_step(), Mtg.Step.UPKEEP, "and the turn goes on")


func test_the_extra_turn_can_be_the_one_skipped() -> void:
	var vault := put_battlefield(0, "Time Vault")
	vault.tapped = false
	var seat := VaultSeat.new()
	seat.index = 1
	g.set_agent(0, seat)
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, vault, 0, []))
	resolve_stack()
	assert_true(vault.tapped)
	advance_to_next_turn()   # the extra turn (turn 2, P0) is skipped: turn 3 is P1's
	assert_eq(seat.asks.size(), 1)
	assert_false(vault.tapped, "the extra turn was traded back to untap the Vault")
	assert_eq(g.active_player, 1)
	assert_eq(g.turn_number, 3)
	assert_string_contains("\n".join(g.log_lines), "takes an extra turn")
