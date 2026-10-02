extends GutTest
## LAN knockout contracts: host results, locked decks and bounded progress.


func test_tournament_commands_are_explicitly_versioned_and_validated() -> void:
	var message := {"v": SgProtocol.VERSION, "type": "command", "seq": 1,
		"room": "", "revision": 0, "action": {"op": "t_join", "event": "a".repeat(64)}}
	assert_true(SgProtocol.valid(message), "LAN tournament registration is a supported command")
	message.action["winner"] = 1
	assert_false(SgProtocol.valid(message), "clients cannot submit results")
	message.action = {"op": "t_recover", "event": "a".repeat(64), "code": "bad"}
	assert_false(SgProtocol.valid(message), "recovery requires a private capability")


func test_forty_entrants_fit_and_forty_one_is_refused() -> void:
	# FORTY ENTRANTS (2026-10-02): the owner's word doubled the cap from
	# twenty. A 64-bracket needs six rounds; a full first draw is
	# thirty-two rows (eight pairings and twenty-four byes).
	assert_eq(SgTournament.MAX_PLAYERS, 40)
	assert_eq(SgTournament.MAX_ROUNDS, 6)
	assert_eq(SgTournament.MAX_PAIRINGS, 32)
	var options := _options("fixed")
	options.limit = 40
	var event := SgTournament.new()
	var error := event.configure(options, 42)
	assert_eq(error, "", "a LAN event supports forty entrants")
	if not error.is_empty(): return
	for i in 40:
		assert_ne(event.register("Entrant %d" % i, str(i).sha256_text()), 0)
	assert_eq(event.register("Overflow", "overflow".sha256_text()), 0)
	options.limit = 41
	assert_false(SgTournament.valid_config(options))
	assert_string_contains(SgTournament.new().configure(options, 42), "2–40 players")
	# The full first draw: every row has a protocol-valid id, the byes
	# are the bracket's slack, and the bracket closes in six rounds.
	for i in 40: assert_eq(event.set_ready(i + 1, true), "")
	assert_eq(event.draw_round(), "")
	assert_eq(event.rounds[0].size(), SgTournament.MAX_PAIRINGS, "forty entrants fill the first draw's row cap")
	var byes := 0
	for pair: Dictionary in event.rounds[0]:
		if pair.status == "bye": byes += 1
	assert_eq(byes, 24)
	assert_true(SgTournamentProtocol.checkpoint(event.checkpoint()), "the forty-entrant draw passes the wire check")
	var rounds := 1
	while event.phase != "complete":
		for pair: Dictionary in event.rounds.back():
			if pair.status == "bye": continue
			for pid: int in pair.players: assert_eq(event.set_ready(pid, true), "")
			assert_eq(event.begin_game(pair.id), "")
			assert_true(event.record_game(pair.id, pair.game, 0))
		if event.phase != "complete":
			assert_eq(event.draw_round(), "")
			rounds += 1
	assert_eq(rounds, SgTournament.MAX_ROUNDS, "forty entrants need every round the cap allows")
	assert_gt(event.champion, 0)
	assert_lte(SgLocalServer.MAX_ROOMS, SgTournament.MAX_PLAYERS / 2, "every pairing of a round can have a table")
	assert_gte(SgLocalServer.MAX_CONNECTIONS, SgTournament.MAX_PLAYERS + 1, "every entrant and the organiser connect at once")
	assert_gte(SgLocalServer.MAX_CONNECTIONS, (SgTournament.MAX_PLAYERS + 1) * 2,
		"and again after a network blip, while every half-open socket still holds its slot (2026-10-02)")


func test_welcome_message_is_bounded_plain_text_and_survives_a_checkpoint() -> void:
	var options := _options()
	options.welcome = "Welcome, duelists! Good luck — have fun. [b]Plain text[/b]"
	assert_true(SgTournament.valid_config(options))
	var event := SgTournament.new()
	var error := event.configure(options, 42)
	assert_eq(error, "")
	if not error.is_empty(): return
	var restored := SgTournament.new()
	assert_eq(restored.restore(JSON.parse_string(SgProtocol.encode(event.checkpoint()))), "")
	assert_eq(restored.config.welcome, options.welcome)
	for bad in ["a".repeat(281), "bad\u0001message", "hidden\u202etext", "\n".repeat(4), 42]:
		options.welcome = bad
		assert_false(SgTournament.valid_config(options))
	options.welcome = ""
	assert_true(SgTournament.valid_config(options))


func test_elimination_cannot_be_rewritten_as_a_later_withdrawal() -> void:
	var event := _event(4)
	event.draw_round()
	var pair: Dictionary = event.rounds[0][0]
	for pid: int in pair.players: event.set_ready(pid, true)
	event.begin_game(pair.id)
	event.record_game(pair.id, pair.game, 0)
	assert_ne(event.withdraw(pair.players[1]), "", "an eliminated entrant has already finished")
	assert_false(event.entrant(pair.players[1]).withdrawn)
	assert_eq(pair.reason, "Series won")


func test_checkpoint_cannot_silently_omit_registered_players_from_the_draw() -> void:
	var event := _event(4)
	event.draw_round()
	var data := event.checkpoint()
	data.rounds[0].pop_back()
	assert_false(SgTournamentProtocol.checkpoint(data), "all registered entrants must be accounted for")


func _options(policy := "own", wins := 1) -> Dictionary:
	return {"name": "Evening knockout", "limit": 8, "wins": wins, "policy": policy,
		"decks": [] if policy == "own" else [_deck()]}


func _deck() -> Dictionary:
	return {"name": "White Knights", "cards": Array(StarterDecks.WHITE_KNIGHTS), "sideboard": []}


func _event(count: int, wins := 1, seed_value := 42) -> SgTournament:
	var event := SgTournament.new()
	var options := _options("fixed", wins)
	options.limit = maxi(8, count)
	assert_eq(event.configure(options, seed_value), "")
	for i in count:
		var pid := event.register("Player %d" % (i + 1), str(i).sha256_text())
		assert_ne(pid, 0)
		assert_eq(event.set_ready(pid, true), "")
	return event


func test_every_roster_size_has_fair_byes_and_exactly_one_champion() -> void:
	for count in range(2, SgTournament.MAX_PLAYERS + 1):
		for seed_value in [1, 7, 42, 100]:
			var event := _event(count, 1, seed_value)
			assert_eq(event.draw_round(), "")
			var played := 0
			for cycle in SgTournament.MAX_ROUNDS:
				if event.phase == "complete": break
				var seen: Array = []
				for pair: Dictionary in event.rounds.back():
					for pid: int in pair.players:
						if pid == 0: continue
						assert_false(seen.has(pid), "each entrant appears once in a round")
						seen.append(pid)
					if pair.status == "bye": continue
					for pid: int in pair.players: assert_eq(event.set_ready(pid, true), "")
					assert_eq(event.begin_game(pair.id), "")
					assert_true(event.record_game(pair.id, pair.game, 0))
					played += 1
					assert_true(SgTournamentProtocol.checkpoint(event.checkpoint()))
				if event.phase != "complete": assert_eq(event.draw_round(), "")
			assert_eq(event.phase, "complete")
			assert_gt(event.champion, 0)
			assert_eq(played, count - 1, "knockout needs one elimination per non-champion")


func test_series_targets_draws_and_duplicate_results() -> void:
	for wins in [1, 2, 3]:
		var event := _event(2, wins)
		assert_eq(event.draw_round(), "")
		var pair: Dictionary = event.rounds[0][0]
		for game_index in wins + 1:
			for pid: int in pair.players: assert_eq(event.set_ready(pid, true), "")
			assert_eq(event.begin_game(pair.id), "")
			assert_false(event.record_game(pair.id, pair.game + 1, 0), "wrong game cannot score")
			assert_true(event.record_game(pair.id, pair.game, -1 if game_index == 0 else 0))
			assert_false(event.record_game(pair.id, pair.game, 0), "result is consumed once")
			assert_true(SgTournamentProtocol.checkpoint(event.checkpoint()))
		assert_eq(pair.wins, [wins, 0])
		assert_eq(pair.draws, 1)
		assert_eq(event.phase, "complete")


func test_deck_policies_and_registration_lock() -> void:
	for policy in ["fixed", "selection", "own"]:
		var event := SgTournament.new()
		assert_eq(event.configure(_options(policy)), "")
		for i in 2:
			var pid := event.register("Player %d" % i, str(i).sha256_text())
			var other := {"name": "Raiders", "cards": Array(StarterDecks.BLACK_RED_RAIDERS), "sideboard": []}
			assert_eq(event.select_deck(pid, other).is_empty(), policy == "own")
			assert_eq(event.select_deck(pid, _deck()), "")
			assert_eq(event.set_ready(pid, true), "")
		assert_eq(event.draw_round(), "")
		assert_ne(event.select_deck(1, _deck()), "", "even a reordered identical deck cannot change mid-event")
		assert_eq(event.register("Late arrival", "c".repeat(64)), 0)
		assert_ne(event.draw_round(), "", "no reroll")
	var bad := _options("fixed")
	bad.decks[0].cards = bad.decks[0].cards.duplicate()
	bad.decks[0].cards[0] = "Unknown card"
	assert_false(SgTournament.valid_config(bad))


func test_a_client_walks_the_views_config_once_and_still_refuses_a_changed_one() -> void:
	# A state message carries the whole config, sixteen approved decks and
	# all, and a client checks every message: an equal config is remembered,
	# a config that differs by one card is walked again and refused
	# (2026-10-02). The memo is a copy — the message it came in is not it.
	# Every config here came off the wire: a decoded number is a float, and
	# a float is not the int it was to a dictionary comparison, so the memo
	# only ever meets what the client decodes.
	SgTournamentProtocol._valid_config = {}
	var good: Dictionary = JSON.parse_string(SgProtocol.encode(_options("fixed")))
	assert_true(SgTournamentProtocol.valid_view_config(good))
	assert_eq(SgTournamentProtocol._valid_config, good, "remembered")
	var again: Dictionary = JSON.parse_string(SgProtocol.encode(good))
	assert_true(SgTournamentProtocol.valid_view_config(again), "the same config off the wire")
	var bad: Dictionary = JSON.parse_string(SgProtocol.encode(good))
	bad.decks[0].cards[0] = "Unknown card"
	assert_false(SgTournamentProtocol.valid_view_config(bad), "one card off is walked and refused")
	assert_eq(SgTournamentProtocol._valid_config, good, "and not remembered")
	good.decks[0].cards[0] = "Unknown card"
	assert_false(SgTournamentProtocol.valid_view_config(good), "the remembered config was a copy: changing the original does not pass")
	assert_false(SgTournamentProtocol.valid_view_config("config"))
	SgTournamentProtocol._valid_config = {}


func test_withdrawal_is_a_series_forfeit_not_fabricated_game_wins() -> void:
	var event := _event(2, 3)
	event.draw_round()
	var pair: Dictionary = event.rounds[0][0]
	assert_eq(event.withdraw(pair.players[0]), "")
	assert_eq(pair.wins, [0, 0])
	assert_eq(pair.reason, "Withdrawal")
	assert_eq(event.champion, pair.players[1])
	assert_true(SgTournamentProtocol.checkpoint(event.checkpoint()))


func test_restore_preserves_draw_and_scores_but_restarts_interrupted_game() -> void:
	var event := _event(2, 2)
	event.draw_round()
	var pair: Dictionary = event.rounds[0][0]
	for pid: int in pair.players: event.set_ready(pid, true)
	event.begin_game(pair.id)
	event.record_game(pair.id, pair.game, 0)
	for pid: int in pair.players: event.set_ready(pid, true)
	event.begin_game(pair.id)
	var saved := event.checkpoint()
	var restored := SgTournament.new()
	assert_eq(restored.restore(SgProtocol.decode_payload(SgProtocol.encode(saved).to_ascii_buffer())), "")
	assert_eq(restored.rounds[0][0].wins, [1, 0])
	assert_eq(restored.rounds[0][0].players, pair.players)
	assert_eq(restored.rounds[0][0].status, "waiting")
	assert_false(restored.entrant(pair.players[0]).ready)
	assert_eq(restored.set_ready(pair.players[0], true), "", "serialized entrant IDs can find their pairing")
	assert_false(SgProtocol.encode(saved).contains("seed"))
	assert_false(SgProtocol.encode(saved).contains("hand"))
	for key in saved.keys():
		var broken := saved.duplicate(true)
		broken.erase(key)
		assert_ne(SgTournament.new().restore(broken), "", "required checkpoint field " + key)
	saved.rounds[0][0].players[1] = pair.players[0]
	assert_ne(SgTournament.new().restore(saved), "", "self-pairing is invalid")


func test_the_organisers_ruling_and_correction_are_flagged_on_the_ledger() -> void:
	var event := _event(4, 2)
	assert_eq(event.draw_round(), "")
	var pair: Dictionary = event.rounds[0][0]
	var other: Dictionary = event.rounds[0][1]
	for pid: int in pair.players: assert_eq(event.set_ready(pid, true), "")
	assert_eq(event.begin_game(pair.id), "")
	assert_ne(event.rule(pair.id, 999), "", "a stranger cannot be ruled the winner")
	assert_ne(event.rule(other.id + 40, other.players[0]), "", "an unknown pairing cannot be ruled on")
	assert_eq(event.rule(pair.id, pair.players[1]), "", "the organiser declares a winner over a live game")
	assert_eq(pair.status, "finished")
	assert_eq(pair.winner, pair.players[1])
	assert_eq(pair.reason, "Organiser's ruling", "a declared winner is flagged, never a played win")
	assert_eq(pair.wins, [0, 0], "played scores stay as they were played")
	for pid: int in pair.players: assert_false(event.entrant(pid).ready)
	assert_ne(event.rule(pair.id, pair.players[1]), "", "the recorded winner is already the recorded winner")
	assert_false(event.record_game(pair.id, pair.game, 0), "the referee cannot score a ruled pairing")
	assert_true(SgTournamentProtocol.checkpoint(event.checkpoint()), "a ruling is a legal checkpoint")
	assert_eq(event.rule(pair.id, pair.players[0]), "", "the organiser overturns their own ruling")
	assert_eq(pair.winner, pair.players[0])
	assert_eq(pair.reason, "Corrected by organiser", "a correction is flagged as one")
	assert_ne(event.withdraw(pair.players[1]), "", "a ruled pairing has finished")
	var saved := SgProtocol.decode_payload(SgProtocol.encode(event.checkpoint()).to_ascii_buffer())
	var restored := SgTournament.new()
	assert_eq(restored.restore(saved), "")
	assert_eq(restored.rounds[0][0].reason, "Corrected by organiser", "the flag survives a restart")
	var forged := event.checkpoint()
	forged.rounds[0][0].winner = 0
	assert_false(SgTournamentProtocol.checkpoint(forged), "a ruling always names its winner")
	# The other pairing plays out; a drawn next round closes the first one.
	for pid: int in other.players: assert_eq(event.set_ready(pid, true), "")
	assert_eq(event.begin_game(other.id), "")
	assert_true(event.record_game(other.id, other.game, 0))
	for pid: int in other.players: assert_eq(event.set_ready(pid, true), "")
	assert_eq(event.begin_game(other.id), "")
	assert_true(event.record_game(other.id, other.game, 0))
	assert_eq(event.draw_round(), "")
	assert_ne(event.rule(pair.id, pair.players[1]), "", "a published draw closes the round before it")
	var bye_free: Dictionary = event.rounds[1][0]
	assert_ne(event.rule(bye_free.id, 0), "", "nobody is not a winner")


func test_a_correction_of_the_final_moves_the_championship() -> void:
	var event := _event(2)
	assert_eq(event.draw_round(), "")
	var pair: Dictionary = event.rounds[0][0]
	for pid: int in pair.players: assert_eq(event.set_ready(pid, true), "")
	assert_eq(event.begin_game(pair.id), "")
	assert_true(event.record_game(pair.id, pair.game, 0))
	assert_eq(event.phase, "complete")
	assert_eq(event.champion, pair.players[0])
	assert_eq(event.rule(pair.id, pair.players[1]), "", "a finished event can still have its final corrected")
	assert_eq(event.phase, "complete")
	assert_eq(event.champion, pair.players[1], "the champion follows the corrected final")
	assert_eq(pair.wins, [1, 0], "the played game is not rewritten")
	assert_true(SgTournamentProtocol.checkpoint(event.checkpoint()))
	assert_ne(event.withdraw(pair.players[1]), "", "a finished event has nobody left to withdraw")
	var withdrawn := _event(2)
	assert_eq(withdrawn.draw_round(), "")
	var final: Dictionary = withdrawn.rounds[0][0]
	assert_eq(withdrawn.withdraw(final.players[1]), "")
	assert_ne(withdrawn.rule(final.id, final.players[1]), "", "a withdrawn player cannot be ruled the winner")


func test_pause_and_ruling_commands_are_organiser_words_on_the_wire() -> void:
	var message := {"v": SgProtocol.VERSION, "type": "command", "seq": 1,
		"room": "", "revision": 0, "action": {"op": "t_pause", "event": "a".repeat(64)}}
	assert_true(SgProtocol.valid(message), "the organiser can pause the event")
	message.action.op = "t_resume"
	assert_true(SgProtocol.valid(message), "and resume it")
	message.action = {"op": "t_rule", "event": "a".repeat(64), "pair": 1, "winner": 2}
	assert_true(SgProtocol.valid(message), "a ruling names its pairing and winner")
	message.action.winner = 0
	assert_false(SgProtocol.valid(message), "a ruling always names a winner")
	message.action = {"op": "t_rule", "event": "a".repeat(64), "pair": 0, "winner": 2}
	assert_false(SgProtocol.valid(message), "a ruling names a real pairing")
	message.action = {"op": "t_rule", "event": "a".repeat(64), "pair": 1, "winner": 2, "wins": [2, 0]}
	assert_false(SgProtocol.valid(message), "a ruling never carries a score")
