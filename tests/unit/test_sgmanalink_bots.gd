extends GameTest
## Genuine profile selection, fair-information invariants and bot ledger contracts.


func _deck() -> Dictionary:
	return {"name": "White Knights", "cards": Array(StarterDecks.WHITE_KNIGHTS), "sideboard": []}


func test_bot_commands_reject_unbounded_counts_and_unrecognised_options() -> void:
	var message := {"v": SgProtocol.VERSION, "type": "command", "seq": 1, "room": "", "revision": 1,
		"action": {"op": "t_bots", "event": "a".repeat(64), "count": 8, "bot": SgBotPlayer.defaults(), "deck": _deck()}}
	assert_true(SgProtocol.valid(message))
	for count in [0, SgTournament.MAX_PLAYERS + 1, 1.5, "8"]:
		message.action.count = count
		assert_false(SgProtocol.valid(message))
	message.action.count = 8
	message.action.bot["hidden_hand"] = ["Counterspell"]
	assert_false(SgProtocol.valid(message))
	message.action.bot.erase("hidden_hand")
	message.action.bot.pace_ms = 0
	assert_false(SgProtocol.valid(message), "zero-delay pacing is not a network option")


func test_network_computer_options_use_the_actual_four_profiles_and_separate_challenge() -> void:
	for level in 4:
		var options := SgBotPlayer.defaults()
		options.level = level
		var pilot := SgBotPlayer.create(1, options)
		assert_true(pilot is AiPlayer)
		assert_false(pilot is UnfairPlayer)
		assert_eq(pilot.pid, 1)
		assert_eq(pilot.profile.profile_name, SgBotPlayer.LEVELS[level])
	var unfair := SgBotPlayer.defaults()
	unfair.unfair = true
	assert_true(SgBotPlayer.create(0, unfair) is UnfairPlayer)
	unfair.level = 0
	assert_false(SgBotPlayer.valid(unfair), "Unfair cannot turn into an Apprentice profile override")
	unfair.level = 3
	unfair["opponent_hand"] = ["Lightning Bolt"]
	assert_false(SgBotPlayer.valid(unfair), "no client-supplied knowledge or arbitrary knobs")


func test_bot_batch_is_atomic_capacity_bounded_and_uses_the_tournament_deck_policy() -> void:
	var event := SgTournament.new()
	assert_eq(event.configure({"name": "Bot Cup", "limit": 8, "wins": 2, "policy": "fixed", "decks": [_deck()]}, 4250), "")
	var bad := _deck()
	bad.cards = bad.cards.duplicate()
	bad.cards[0] = "Forest"
	assert_ne(event.register_bots(2, SgBotPlayer.defaults(), bad), "")
	assert_eq(event.entrants.size(), 0)
	assert_ne(event.register_bots(9, SgBotPlayer.defaults(), _deck()), "")
	assert_eq(event.entrants.size(), 0)
	assert_eq(event.register_bots(8, SgBotPlayer.defaults(), _deck()), "")
	assert_eq(event.entrants.size(), 8)
	assert_true(event.entrants.all(func(p: Dictionary) -> bool: return p.ready and p.has("bot")))
	assert_true(SgTournamentProtocol.checkpoint(event.checkpoint()))
	assert_eq(event.draw_round(), "")
	assert_ne(event.register_bots(1, SgBotPlayer.defaults(), _deck()), "")
	var restored := SgTournament.new()
	assert_eq(restored.restore(JSON.parse_string(SgProtocol.encode(event.checkpoint()))), "")
	assert_eq(int(restored.entrants[0].bot.level), 3)
	assert_eq(int(restored.entrants[0].bot.pace_ms), 350)
	assert_false(restored.entrants[0].bot.unfair)
	assert_false(restored.entrants[0].ready)


func test_standard_network_bots_ignore_hidden_substitutions_but_see_public_changes() -> void:
	var hidden := give_hand(1, "Giant Growth")
	g.players[0].deck_names.assign(["Forest", "Grizzly Bears"])
	for level in 4:
		var options := SgBotPlayer.defaults()
		options.level = level
		var pilot := SgBotPlayer.create(0, options)
		g.set_agent(0, pilot)
		var key := pilot._planning_key(g)
		hidden.data = CardRegistry.get_card("Counterspell")
		g.players[1].deck_names.assign(["Counterspell"])
		g.players[0].library.reverse()
		g.players[1].library.reverse()
		assert_eq(pilot._planning_key(g), key)
		assert_false(pilot.deck_study.counts.has("Counterspell"))
		g.adjust_life(1, -1)
		assert_ne(pilot._planning_key(g), key)
		hidden.data = CardRegistry.get_card("Giant Growth")


func test_host_wizard_waits_out_manabarbs_without_repaying_and_preserves_remote_privacy() -> void:
	for i in 6: put_battlefield(0, "Mountain")
	put_battlefield(1, "Manabarbs")
	var giant := give_hand(0, "Hill Giant")
	g.interactive_choices = true
	g.set_agent(1, HumanAgent.new())
	var pilot := SgBotPlayer.create(0, SgBotPlayer.defaults())
	g.set_agent(0, pilot)
	advance_to_step(Mtg.Step.MAIN1)
	var referee := SgPracticeMatch.new(4250)
	referee.game = g
	for i in 24:
		if giant.zone == Mtg.Zone.BATTLEFIELD: break
		if referee.decision_state().actor == 0: SgBotPlayer.step(referee, pilot)
		else: assert_eq(g.pass_priority(1), "")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].life, 16)
	assert_eq(g.players[0].battlefield.filter(func(c: CardInstance) -> bool: return c.is_land() and c.tapped).size(), 4)
	var human := referee.view(1)
	assert_true(SgViewProtocol.game(human))
	assert_eq(human.players[0].revealed, [])


func test_real_wizards_complete_a_refereed_game_with_mulligans_and_private_views() -> void:
	var referee := SgPracticeMatch.new(4250, [_deck(), _deck()])
	for pid in 2:
		assert_true(referee.set_bot(pid, SgBotPlayer.defaults()))
		assert_not_null(referee.bots[pid].deck_study)
	var actions := 0
	for i in 2000:
		if referee.game.game_over: break
		var pid := int(referee.decision_state().actor)
		SgBotPlayer.step(referee, referee.bots[pid])
		actions += 1
	assert_true(referee.game.game_over, "Wizard game must complete within 2000 decisions")
	assert_gt(actions, 40)
	assert_true(referee.order_chosen)
	for pid in 2: assert_true(SgViewProtocol.game(referee.view(pid)))
	assert_false(referee.set_bot(0, SgBotPlayer.defaults()), "settings are locked after play begins")
