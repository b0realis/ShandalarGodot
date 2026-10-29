extends GutTest
## SAVED BETWEEN DUELS, THE FILES — [MatchSaves] (the polish pass c18, P4;
## the owner, 2026-10-28: *"Saving: between duels (Gauntlet runs and
## matches save after each duel and resume); no mid-duel save"*).
##
## What a save holds and gives back (a match, a run with and without a
## match in play), that it is written whole or not at all, that a file
## that cannot be taken up is set aside rather than written over or
## trusted, that a finished match drops only its own file, and that a save
## holding a card of a pack switched off says which pack.

const DIR := "user://p4_saves_test"
const MATCH := DIR + "/saved_match.json"
const RUN := DIR + "/saved_gauntlet.json"


func before_each() -> void:
	_wipe()
	DirAccess.make_dir_recursive_absolute(DIR)
	MatchSaves.match_file = MATCH
	MatchSaves.gauntlet_file = RUN


func after_each() -> void:
	MatchSaves.match_file = MatchSaves.MATCH_FILE
	MatchSaves.gauntlet_file = MatchSaves.GAUNTLET_FILE
	_wipe()


func _wipe() -> void:
	var dir := DirAccess.open(DIR)
	if dir == null:
		return
	for name in dir.get_files():
		dir.remove(name)
	for name in dir.get_directories():
		DirAccess.remove_absolute(DIR.path_join(name))
	DirAccess.remove_absolute(DIR)


## A best of three against the computer, one duel played (won), the
## computer's memory holding what it saw.
func _match_snapshot(record_id := "match-a") -> Dictionary:
	var config := DuelConfig.vs_ai_default(AiProfile.sorcerer())
	var deck := DeckList.load_file("res://decks/white_knights.deck", true)
	config.decks[0] = deck.cards.duplicate()
	config.sideboards[0] = deck.sideboard.duplicate()
	config.best_of = 3
	config.sideboard_between_duels = true
	config.rng_seed = 9007199254740993          # past a double's 2^53
	config.record_match = record_id
	config.player_names = ["Hero", "Computer"] as Array[String]
	config.deck_names = ["White Knights", "Black Knights"] as Array[String]
	config.lives = [20, 17] as Array[int]
	config.ante = 1
	var state := MatchState.new()
	state.best_of = 3
	state.record(0)
	var memory := AiMatchMemory.new(1)
	memory.seen["Savannah Lions"] = 3
	memory.damage_by_color[Mtg.ManaColor.W] = 7
	memory.duels = 1
	return MatchSaves.match_json(config, state, -4611686018427387905, 2, [null, memory])


# ================================================================ a match ==

func test_a_saved_match_comes_back_as_it_was_written() -> void:
	assert_true(MatchSaves.write_match(_match_snapshot()))
	var found := MatchSaves.read_match()
	assert_eq(found["status"], MatchSaves.READY)
	var taken: Dictionary = found["match"]
	var config: DuelConfig = taken["config"]
	var state: MatchState = taken["state"]
	assert_eq(config.best_of, 3)
	assert_true(config.sideboard_between_duels)
	assert_eq(config.rng_seed, 9007199254740993, "a 64-bit seed survives the file")
	assert_eq(int(taken["seeder_state"]), -4611686018427387905, "and so does the stream")
	assert_eq(int(taken["resumes"]), 2)
	assert_eq(config.player_names, ["Hero", "Computer"] as Array[String])
	assert_eq(config.lives, [20, 17] as Array[int])
	assert_eq(config.ante, 1)
	assert_eq(config.record_match, "match-a")
	assert_null(config.pilots[0], "seat 1 is a person")
	assert_eq((config.pilots[1] as AiProfile).profile_name, "Sorcerer")
	var deck := DeckList.load_file("res://decks/white_knights.deck", true)
	assert_eq(config.decks[0], deck.cards, "the deck as it stands")
	assert_eq(config.sideboards[0], deck.sideboard)
	assert_eq(state.wins, [1, 0] as Array[int])
	assert_eq(state.last_winner, 0)
	assert_eq(state.duels_played(), 1)
	assert_null(taken["memories"][0])
	var memory: AiMatchMemory = taken["memories"][1]
	assert_eq(memory.copies_seen("Savannah Lions"), 3, "what the computer saw")
	assert_eq(memory.damage_from(Mtg.ManaColor.W), 7)
	assert_eq(memory.duels, 1)


func test_the_summary_speaks_the_originals_record_sentence() -> void:
	MatchSaves.write_match(_match_snapshot())
	var lines: Array = MatchSaves.read_match()["summary"]
	assert_eq(lines[0], "After 1 duel(s) in this best of 3 match, your record is 1/0/0")
	assert_eq(lines[1], "Next: Duel 2 of 3")
	assert_eq(lines[2], "Hero (White Knights) against Computer (Black Knights)")


func test_no_file_is_nothing_to_resume() -> void:
	assert_eq(MatchSaves.read_match()["status"], MatchSaves.NONE)
	assert_eq(MatchSaves.read_gauntlet()["status"], MatchSaves.NONE)


func test_a_failed_write_leaves_the_saved_match_as_it_was() -> void:
	assert_true(MatchSaves.write_match(_match_snapshot()))
	var before := FileAccess.get_file_as_bytes(MATCH)
	# A folder where the pending file must go: the write cannot land.
	DirAccess.make_dir_recursive_absolute(Settings.pending_path(MATCH))
	var other := _match_snapshot()
	other["record"]["wins"] = [2, 0]
	assert_false(MatchSaves.write_match(other), "the write says it failed")
	DirAccess.remove_absolute(Settings.pending_path(MATCH))
	assert_eq(FileAccess.get_file_as_bytes(MATCH), before, "and the old save is whole")


func test_a_file_that_is_not_a_save_is_set_aside_not_trusted() -> void:
	_put(MATCH, "{ this is not json")
	var found := MatchSaves.read_match()
	assert_eq(found["status"], MatchSaves.SET_ASIDE)
	assert_eq(found["aside"], MATCH + ".bad")
	assert_false(FileAccess.file_exists(MATCH), "nothing is left to be offered")
	assert_eq(FileAccess.get_file_as_string(MATCH + ".bad"), "{ this is not json",
		"and the bytes are kept")
	# A second damaged file takes the next name, the first is never lost.
	_put(MATCH, "[]")
	assert_eq(MatchSaves.read_match()["aside"], MATCH + ".bad2")
	assert_eq(FileAccess.get_file_as_string(MATCH + ".bad"), "{ this is not json")
	assert_string_contains(MatchSaves.set_aside_note(MATCH + ".bad2", "match"),
		"saved_match.json.bad2")


func test_a_save_from_a_newer_version_or_another_format_is_set_aside() -> void:
	var data := {"format": MatchSaves.MATCH_FORMAT, "version": MatchSaves.FORMAT_VERSION + 1,
		"match": _match_snapshot()}
	_put(MATCH, JSON.stringify(data))
	assert_eq(MatchSaves.read_match()["status"], MatchSaves.SET_ASIDE)
	data["version"] = 1
	data["format"] = "shandalar-hall-of-fame"
	_put(MATCH, JSON.stringify(data))
	assert_eq(MatchSaves.read_match()["status"], MatchSaves.SET_ASIDE)


func test_a_decided_match_or_a_deck_with_no_cards_is_not_taken_up() -> void:
	var decided := _match_snapshot()
	decided["record"]["wins"] = [2, 0]
	assert_true(MatchSaves.write_match(decided))
	assert_eq(MatchSaves.read_match()["status"], MatchSaves.SET_ASIDE,
		"a best of three at 2-0 has no next duel")
	var empty := _match_snapshot()
	empty["config"]["decks"][1] = []
	assert_true(MatchSaves.write_match(empty))
	assert_eq(MatchSaves.read_match()["status"], MatchSaves.SET_ASIDE)


func test_a_damaged_file_is_set_aside_before_a_new_save_lands() -> void:
	_put(MATCH, "garbage")
	assert_true(MatchSaves.write_match(_match_snapshot()))
	assert_eq(FileAccess.get_file_as_string(MATCH + ".bad"), "garbage",
		"never written over")
	assert_eq(MatchSaves.read_match()["status"], MatchSaves.READY)


func test_a_match_drops_only_its_own_file() -> void:
	assert_true(MatchSaves.write_match(_match_snapshot("match-a")))
	MatchSaves.clear_match("match-b")
	assert_true(FileAccess.file_exists(MATCH), "another match's end leaves it")
	MatchSaves.clear_match("")
	assert_true(FileAccess.file_exists(MATCH))
	MatchSaves.clear_match("match-a")
	assert_false(FileAccess.file_exists(MATCH), "its own end drops it")


func test_field_by_field_a_bad_field_costs_only_that_field() -> void:
	var snapshot := _match_snapshot()
	snapshot["config"]["lives"] = ["lots", 17]
	snapshot["config"]["pilots"][1] = "Archmage"
	snapshot["config"]["deck_format"] = "Vintage"
	snapshot["config"]["player_names"] = [3, "Computer"]
	assert_true(MatchSaves.write_match(snapshot))
	var config: DuelConfig = MatchSaves.read_match()["match"]["config"]
	assert_eq(config.lives, [20, 17] as Array[int])
	assert_eq((config.pilots[1] as AiProfile).profile_name, "Wizard",
		"an unknown pilot is the strongest, as Magic Battle's default")
	assert_eq(config.deck_format, DeckFormat.UNRESTRICTED)
	assert_eq(config.player_names[0], DuelConfig.seat_label(0))


# ============================================================ a gauntlet ==

func _run_snapshot(in_play: Dictionary, id := "run-a") -> Dictionary:
	var state := GauntletState.new()
	state.order = ["res://decks/big_green.deck", "res://decks/blue_skies.deck",
		"res://decks/mountain_artillery.deck"] as Array[String]
	state.names = {"res://decks/blue_skies.deck": "Blue Skies"}
	state.start = 1
	state.round_number = 2
	state.wins = 2
	state.losses = 1
	var config := DuelConfig.hotseat_default()
	config.best_of = 3
	config.pilots[1] = AiProfile.magician()
	config.rng_seed = 90210
	var options := GauntletOptions.new()
	options.enemy_level = 1
	options.num_opponents = 3
	options.your_deck = "res://decks/big_green.deck"
	return MatchSaves.gauntlet_json(id, state, config, options, 123456789, 0, in_play)


func test_a_saved_run_between_matches_comes_back_as_it_was_written() -> void:
	assert_true(MatchSaves.write_gauntlet(_run_snapshot({})))
	var found := MatchSaves.read_gauntlet()
	assert_eq(found["status"], MatchSaves.READY)
	var run: Dictionary = found["run"]
	var state: GauntletState = run["state"]
	assert_eq(run["id"], "run-a")
	assert_eq(state.order.size(), 3)
	assert_eq(state.start, 1)
	assert_eq(state.round_number, 2)
	assert_eq([state.wins, state.losses, state.ties], [2, 1, 0])
	assert_eq(state.opponent_name(), "big_green", "(1 + 2) % 3 = 0 — the original's walk")
	assert_eq(int(run["rng_state"]), 123456789)
	assert_true((run["match"] as Dictionary).is_empty(), "no match in play")
	var options: GauntletOptions = run["options"]
	assert_eq(options.enemy_level, 1)
	assert_eq(options.num_opponents, 3)
	assert_eq(options.best_of, 3)
	var lines: Array = found["summary"]
	assert_eq(lines[0], "Round 2 of 3")
	assert_eq(lines[1], "Your record is 2/1/0")
	assert_eq(lines[2], "Your next duel is against big_green.")


func test_a_saved_run_carries_the_match_in_play() -> void:
	assert_true(MatchSaves.write_gauntlet(_run_snapshot(_match_snapshot())))
	var found := MatchSaves.read_gauntlet()
	assert_eq(found["status"], MatchSaves.READY)
	var in_play: Dictionary = found["run"]["match"]
	assert_eq((in_play["state"] as MatchState).duels_played(), 1)
	assert_string_contains(String(found["summary"][2]), "Duel 2 of 3")


func test_a_run_past_its_last_round_is_set_aside() -> void:
	var snapshot := _run_snapshot({})
	snapshot["run"]["round"] = 4
	assert_true(MatchSaves.write_gauntlet(snapshot))
	assert_eq(MatchSaves.read_gauntlet()["status"], MatchSaves.SET_ASIDE)
	assert_true(FileAccess.file_exists(RUN + ".bad"))


func test_a_run_drops_only_its_own_file() -> void:
	assert_true(MatchSaves.write_gauntlet(_run_snapshot({}, "run-a")))
	MatchSaves.clear_gauntlet("run-b")
	assert_true(FileAccess.file_exists(RUN))
	MatchSaves.clear_gauntlet("run-a")
	assert_false(FileAccess.file_exists(RUN))


# ============================================================ the packs ==

func test_a_card_the_pool_does_not_have_refuses_by_name() -> void:
	var names: Array[String] = ["Plains", "Zzyx the Unprinted"]
	assert_eq(MatchSaves.cards_refusal(names, "This match"),
		"This match holds cards this game does not have: Zzyx the Unprinted.")
	assert_eq(MatchSaves.cards_refusal(["Plains", "Savannah Lions"] as Array[String],
		"This match"), "", "every card in the pool: nothing to say")


func test_a_card_of_a_pack_switched_off_names_the_pack() -> void:
	# Pack 9 off — the suite's own state; a Tempest card is then not in the
	# pool, and the refusal sends the player to switch the pack on.
	CardPacks.set_enabled("pack-9", false)
	assert_false(CardRegistry.has_card("Mogg Fanatic"), "a Tempest card, its pack off")
	var refusal := MatchSaves.cards_refusal(["Mountain", "Mogg Fanatic"] as Array[String],
		"This run")
	assert_string_contains(refusal, "This run needs Pack 9")
	assert_string_contains(refusal, "Options, Card packs")


func _put(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
