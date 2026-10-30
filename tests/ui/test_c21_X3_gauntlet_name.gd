extends GutTest
## THE GAUNTLET SEATS YOU BY YOUR MAGIC BATTLE NAME (0.50.66 bug campaign,
## the "You wins!" leftover). Magic Battle seats a person as the name typed
## for the seat, else "Player 1"; Test hands as "Player 1"; the adventure
## as the hero. The Gauntlet alone seated you as "You", and every line the
## engine writes in the third person read wrong there — "You wins!", "You
## gains 3 life". It takes the name Magic Battle remembers for its first
## seat now ([method SetupScreen.your_name]), as it takes the portrait
## chosen there, and a run saved before is taken up under it too.

const DIR := "user://c21_x3_gauntlet_name"
const RUN := DIR + "/saved_gauntlet.json"
const MATCH := DIR + "/saved_match.json"
const DECK_A := "res://decks/big_green.deck"
const DECK_B := "res://decks/blue_skies.deck"
const DECK_C := "res://decks/mountain_artillery.deck"
const NAME_KEY := SetupScreen.REMEMBER_PREFIX + "name_0"

var _saved_name: Variant = null
var _had_name := false


func before_each() -> void:
	_had_name = Settings.has_value(NAME_KEY)
	_saved_name = Settings.get_value(NAME_KEY, null)
	Settings.clear_value(NAME_KEY)
	_wipe()
	DirAccess.make_dir_recursive_absolute(DIR)
	MatchSaves.match_file = MATCH
	MatchSaves.gauntlet_file = RUN


func after_each() -> void:
	if _had_name:
		Settings.set_value(NAME_KEY, _saved_name)
	else:
		Settings.clear_value(NAME_KEY)
	MatchSaves.match_file = MatchSaves.MATCH_FILE
	MatchSaves.gauntlet_file = MatchSaves.GAUNTLET_FILE
	_wipe()


func _wipe() -> void:
	var dir := DirAccess.open(DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		dir.remove(file_name)
	DirAccess.remove_absolute(DIR)


func _gauntlet(decks: Array[String], size := 1, seed_value := 90210) -> GauntletScreen:
	var screen: GauntletScreen = load("res://game/duel/gauntlet_screen.tscn").instantiate()
	var config := DuelConfig.hotseat_default()
	config.rng_seed = seed_value
	screen.config = config
	screen.opponent_paths = decks
	screen.options.best_of = size
	screen.options.ante = false
	screen.options.your_deck = DECK_A
	return screen


func test_your_name_is_magic_battles() -> void:
	assert_eq(SetupScreen.your_name(), "Player 1", "nothing typed: Magic Battle's own name for you")
	Settings.set_value(NAME_KEY, "  Marko  ")
	assert_eq(SetupScreen.your_name(), "Marko", "the name typed there")
	Settings.set_value(NAME_KEY, "HAL 9000")
	assert_eq(SetupScreen.your_name(), "Player 1", "never a name the screen gave the computer")


func test_the_gauntlet_seats_you_by_that_name_and_the_log_agrees() -> void:
	Settings.set_value(NAME_KEY, "Marko")
	var screen := _gauntlet([DECK_A, DECK_B])
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_not_null(screen._match, "control: the run is up")
	assert_eq(screen.config.player_names[0], "Marko", "not \"You\"")
	var duel: DuelScreen = screen._match._duel
	assert_eq(duel.game.players[0].player_name, "Marko", "the engine's seat")
	assert_ok(duel.game.concede(1))
	var ending := ""
	for line in duel.game.log_lines:
		if String(line).contains("conceded"):
			ending = String(line)
	assert_string_ends_with(ending, ". Marko wins!", "a name in the third person")


func test_a_run_saved_as_you_is_taken_up_under_your_name() -> void:
	var first := _gauntlet([DECK_A, DECK_B, DECK_C], 1)
	add_child_autofree(first)
	await get_tree().process_frame
	first._match._duel.duel_finished.emit(0)          # round 1 won: saved
	await get_tree().process_frame
	var run: Dictionary = MatchSaves.read_gauntlet()["run"]
	(run["config"] as DuelConfig).player_names[0] = GauntletScreen.OLD_SEAT_NAME
	var again := _gauntlet([DECK_A], 1, 1)
	again.resume_from = run
	add_child_autofree(again)
	await get_tree().process_frame
	assert_eq(again.config.player_names[0], "Player 1", "a 0.50.66 save seated you as \"You\"")
	assert_not_null(again._match, "control: round 2 is up")
	if again._match != null:
		assert_eq(again._match.config.player_names[0], "Player 1", "and so does its duel")


func assert_ok(result: String) -> void:
	assert_eq(result, "", "refused: %s" % result)
