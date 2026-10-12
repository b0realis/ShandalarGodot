extends GutTest
## Robustness campaign 2026-10-12 — the Gauntlet.
##
##   * b2-5: the Gauntlet's bed stops when its duel starts and comes back
##     with the screen's next window (the duel's own tune is the only one
##     under a duel). The live check is the Xvfb probe; this pins the calls.
##   * b2-7: a gauntlet duel wears the portrait the player chose — the same
##     resolver the battle-setup screen hands its duels.

const DECK_A := "res://decks/big_green.deck"
const DECK_B := "res://decks/blue_skies.deck"


## A music player that only records what it was told.
class RecordingPlayer extends MusicPlayer:
	var calls: Array[String] = []

	func play_one(id: String) -> void:
		calls.append("play " + id)

	func stop_music() -> void:
		calls.append("stop")


func _make(decks: Array[String]) -> GauntletScreen:
	var screen: GauntletScreen = load("res://game/duel/gauntlet_screen.tscn").instantiate()
	var config := DuelConfig.hotseat_default()
	config.rng_seed = 4242
	screen.config = config
	screen.opponent_paths = decks
	screen.options.best_of = 1
	screen.options.ante = false
	screen.options.your_deck = DECK_A
	return screen


func test_a_gauntlet_duel_wears_the_chosen_portrait() -> void:
	var faces := PortraitLibrary.all()
	if faces.is_empty():
		pending("no portrait art in this checkout")
		return
	var had := Settings.has_value("Portrait0")
	var old: Variant = Settings.get_value("Portrait0", "")
	var pick := String(faces[faces.size() - 1]["id"])
	Settings.set_value("Portrait0", pick, false)
	var screen := _make([DECK_A, DECK_B])
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_not_null(screen._match)
	if screen._match != null:
		assert_eq(String(screen._match.config.portraits[0]), pick, "seat 1 wears the chosen face")
		assert_eq(String(screen._match.config.portraits[1]), "",
			"the opponent keeps its deck's duelist")
	if had: Settings.set_value("Portrait0", old, false)
	else: Settings.clear_value("Portrait0")


func test_with_nothing_chosen_the_seat_default_face_is_worn() -> void:
	var faces := PortraitLibrary.all()
	if faces.is_empty():
		pending("no portrait art in this checkout")
		return
	var had := Settings.has_value("Portrait0")
	var old: Variant = Settings.get_value("Portrait0", "")
	Settings.clear_value("Portrait0")
	assert_eq(PortraitLibrary.chosen_for(0), faces[0], "the library's face for seat 1")
	var screen := _make([DECK_A, DECK_B])
	add_child_autofree(screen)
	await get_tree().process_frame
	if screen._match != null:
		assert_eq(String(screen._match.config.portraits[0]), String(faces[0]["id"]))
	if had: Settings.set_value("Portrait0", old, false)


func test_the_setup_screen_and_the_gauntlet_share_one_resolver() -> void:
	var setup: SetupScreen = load("res://game/setup_screen.tscn").instantiate()
	add_child_autofree(setup)
	for pid in 2:
		assert_eq(setup._chosen_portrait(pid), PortraitLibrary.chosen_for(pid))
	assert_eq(SetupScreen.PORTRAIT_KEY, PortraitLibrary.SEAT_KEY)


func test_the_bed_stops_under_the_duel_and_returns_with_the_next_window() -> void:
	var had := Settings.has_value("music_enabled")
	var old: Variant = Settings.get_value("music_enabled", true)
	Settings.set_value("music_enabled", true, false)
	var screen := _make([DECK_B, DECK_B])
	add_child_autofree(screen)
	await get_tree().process_frame
	var bed := RecordingPlayer.new()
	screen.add_child(bed)
	screen._music = bed
	screen._play_match(screen._config_for_this_round())
	assert_eq(bed.calls, ["stop"] as Array[String], "the bed stops as the match starts")
	bed.calls.clear()
	screen._show_round_window(["Round over"] as Array[String])
	assert_eq(bed.calls, ["play " + MusicLibrary.single_for(GauntletScreen.GAUNTLET_BEDS)] as Array[String],
		"the bed is back over the round window")
	bed.calls.clear()
	screen._show_announcement(screen._config_for_this_round())
	assert_eq(bed.calls.size(), 1, "and over the next announcement")
	if had: Settings.set_value("music_enabled", old, false)
	else: Settings.clear_value("music_enabled")
