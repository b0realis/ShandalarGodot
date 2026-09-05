extends GameTest
## AI tests: micro-decisions (land, cast, target, attack, block), the
## difficulty knobs, determinism, and — most importantly — full AI-vs-AI
## soak games that exercise the ENTIRE engine end to end. The soak is the
## project's best regression net: every card in the starter decks, every
## combat rule, every trigger, played by two tireless opponents.


func _wizard() -> AiPlayer:
	return AiPlayer.new(0, AiProfile.wizard())


## A flawless pilot that plays everything at sorcery speed — the Wizard
## holds its instants for the opponent's turn (tests/ai/test_ai_capabilities.gd),
## and these tests are about WHERE a spell is aimed, not WHEN.
func _sorcery_speed() -> AiPlayer:
	return AiPlayer.new(0, AiProfile.new("sorcery-speed", 0.0, 0.5, 6, false, 5.0, 0))


func test_ai_plays_a_land_and_casts_a_creature() -> void:
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	give_hand(0, "Mountain")
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")   # 2 on board + 1 in hand = {2}{R} covered
	give_hand(0, "Gray Ogre")   # {2}{R} 2/2
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "played a land")
	var second := ai.act(g)
	assert_string_contains(second, "cast Gray Ogre")
	resolve_stack()
	assert_not_null(g.find_on_battlefield(0, "Gray Ogre"))


func test_ai_aims_removal_at_the_biggest_threat() -> void:
	var ai := _sorcery_speed()
	put_battlefield(1, "Savannah Lions")
	var serra := put_battlefield(1, "Serra Angel")
	give_hand(0, "Terror")
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "cast Terror")
	resolve_stack()
	assert_eq(serra.zone, Mtg.Zone.GRAVEYARD, "the 4/4 died, not the 2/1")


func test_ai_burns_face_when_no_creature_is_worth_it() -> void:
	var ai := _sorcery_speed()
	give_hand(0, "Lightning Bolt")
	put_battlefield(0, "Mountain")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "cast Lightning Bolt")
	resolve_stack()
	assert_eq(g.players[1].life, 17)


func test_ai_attacks_an_empty_board() -> void:
	var ai := _wizard()
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_string_contains(ai.act(g), "1 attacker")
	assert_true(g.combat.attackers.has(bear.id))


func test_ai_keeps_a_creature_home_against_a_bad_block() -> void:
	# A 1/1 swinging into an untapped 4/4 is a pure loss — Wizard stays home.
	var ai := _wizard()
	put_battlefield(0, "Savannah Lions")
	put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	ai.act(g)
	assert_eq(g.combat.attackers.size(), 0, "no suicide attacks on Wizard")


func test_ai_blocks_to_kill_and_survive() -> void:
	var ai := AiPlayer.new(1, AiProfile.wizard())
	g.set_agent(1, ai)
	var lions := put_battlefield(0, "Savannah Lions")   # 2/1 attacker
	var wall := put_battlefield(1, "Wall of Stone")      # 0/8 blocker
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [lions.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	ai.act(g)
	assert_true(g.combat.blocks.has(wall.id), "the wall eats the lions")


func test_ai_gang_blocks_a_monster() -> void:
	var ai := AiPlayer.new(1, AiProfile.wizard())
	g.set_agent(1, ai)
	var wurm := put_battlefield(0, "Craw Wurm")          # 6/4
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	ai.act(g)
	assert_eq(g.combat.blocks.size(), 2, "two bears gang the wurm")


func test_apprentice_fumbles_where_wizard_acts() -> void:
	# mistake_chance 1.0 = the cast step always fumbles; the land still
	# gets played (development mistakes are casts, not land drops).
	var fumbler := AiPlayer.new(0, AiProfile.new("AllThumbs", 1.0, 0.5))
	give_hand(0, "Grizzly Bears")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	var did := fumbler.act(g)
	assert_eq(did, "pass", "full mistake rate: never develops")
	assert_eq(g.players[0].hand.size(), 1, "bears stayed in hand")


func test_ai_auto_taps_across_colors() -> void:
	var ai := _wizard()
	give_hand(0, "Hypnotic Specter")   # {1}{B}{B}
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Mountain")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "cast Hypnotic Specter")
	resolve_stack()
	assert_not_null(g.find_on_battlefield(0, "Hypnotic Specter"))


# ------------------------------------------------------------------- soaks --

func _soak(seed_value: int) -> Dictionary:
	var game := MtgGame.new()
	game.setup(StarterDecks.WHITE_KNIGHTS, StarterDecks.BLACK_RED_RAIDERS,
		"AI-White", "AI-Black", 20, 20, seed_value)
	var ai0 := AiPlayer.new(0, AiProfile.wizard())
	var ai1 := AiPlayer.new(1, AiProfile.wizard())
	game.set_agent(0, ai0)
	game.set_agent(1, ai1)
	game.start()
	var finished := AiPlayer.play_out(game, ai0, ai1)
	return {"finished": finished, "winner": game.winner,
		"turns": game.turn_number, "log_size": game.log_lines.size()}


func test_full_ai_vs_ai_game_completes() -> void:
	var result := _soak(1337)
	assert_true(result.finished, "the game ran to a real conclusion")
	assert_true(result.winner in [0, 1])
	assert_lt(result.turns, 200, "no infinite grind")


func test_three_more_seeds_complete() -> void:
	# Breadth over depth: several seeds shake different card interactions
	# through the full engine.
	for seed_value in [7, 42, 90125]:
		var result := _soak(seed_value)
		assert_true(result.finished, "seed %d completed" % seed_value)
		assert_true(result.winner in [0, 1], "seed %d has a winner" % seed_value)


func test_ai_games_are_deterministic_under_a_seed() -> void:
	var a := _soak(2024)
	var b := _soak(2024)
	assert_eq(a.winner, b.winner, "same seed, same winner")
	assert_eq(a.turns, b.turns, "same seed, same length")
	assert_eq(a.log_size, b.log_size, "same seed, same game, line for line")
