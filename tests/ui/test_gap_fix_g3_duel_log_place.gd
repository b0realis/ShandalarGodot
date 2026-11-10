extends GutTest
## THE DUEL LOG KEEPS CLEAR OF THE SITUATION BAR (gap review 2026-11-10,
## r3-5). The log opens at the upper right of the table and grows with the
## UI scale from its corner; at 130% and 150% on a 1280x800 table it grew
## down under the Situation Bar, which is drawn over it (z 90 over the
## log's 50) — and the bar covered the log's NEWEST lines, the ones it
## follows. A log that starts above the bar now stops above it, whatever
## the scale, the window size or the place the player last left it.

var view: SubViewport
var screen: DuelScreen


func after_each() -> void:
	Settings.clear_value(DuelScreenOptions.UI_SCALE_KEY)
	Settings.clear_value(DuelLog.POS_SETTING)
	await get_tree().process_frame
	await get_tree().process_frame


func _open(at: Vector2i, ui_scale: float) -> void:
	Settings.set_value(DuelScreenOptions.UI_SCALE_KEY, ui_scale)
	Settings.clear_value(DuelLog.POS_SETTING)
	view = SubViewport.new()
	view.size = at
	add_child_autofree(view)
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 1000.0
	config.rng_seed = 93830
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	view.add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	screen._apply_ui_scale()
	await get_tree().process_frame


func _settle() -> void:
	for _i in 3:
		await get_tree().process_frame


## The log's drawn rectangle lies wholly above the bar's top edge.
func _assert_clear(what: String) -> void:
	var log_rect: Rect2 = screen._duel_log.get_global_rect()
	var bar_rect: Rect2 = screen._situation_bar.get_global_rect()
	assert_lt(log_rect.position.y, bar_rect.position.y, "control: the log starts above the bar")
	assert_true(log_rect.end.y <= bar_rect.position.y + 0.5,
		"%s: the log (%s) must end above the Situation Bar (%s)" % [what, log_rect, bar_rect])


func test_the_default_place_clears_the_bar_at_every_scale(s = use_parameters([1.0, 1.15, 1.3, 1.5])) -> void:
	await _open(Vector2i(1280, 800), float(s))
	screen._open_duel_log()
	await _settle()
	_assert_clear("scale %.2f" % float(s))
	assert_almost_eq(screen._duel_log.scale.x, float(s), 0.001, "control: the log wears the UI scale")


func test_with_room_to_spare_the_log_keeps_its_full_height() -> void:
	await _open(Vector2i(1280, 800), 1.0)
	screen._open_duel_log()
	await _settle()
	assert_eq(screen._duel_log.size, DuelLog.SIZE, "nothing taken off a log that fits")


func test_a_scale_changed_with_the_log_open_keeps_it_clear() -> void:
	await _open(Vector2i(1280, 800), 1.0)
	screen._open_duel_log()
	await _settle()
	Settings.set_value(DuelScreenOptions.UI_SCALE_KEY, 1.5)
	screen._apply_ui_scale()
	await _settle()
	_assert_clear("1.0 -> 1.5 with the log open")


func test_a_smaller_window_keeps_it_clear() -> void:
	await _open(Vector2i(1920, 1080), 1.5)
	screen._open_duel_log()
	await _settle()
	_assert_clear("1920x1080 at 150%")
	view.size = Vector2i(1280, 800)
	await _settle()
	_assert_clear("shrunk to 1280x800 at 150%")


func test_a_place_the_player_chose_above_the_bar_keeps_it_clear() -> void:
	await _open(Vector2i(1280, 800), 1.5)
	Settings.set_value(DuelLog.POS_SETTING, Vector2(500.0, 60.0))
	screen._open_duel_log()
	await _settle()
	assert_eq(screen._duel_log.position, Vector2(500.0, 60.0), "control: where the player left it")
	_assert_clear("a saved place at 150%")


func test_a_log_below_the_bar_is_left_alone() -> void:
	await _open(Vector2i(1280, 800), 1.0)
	Settings.set_value(DuelLog.POS_SETTING, Vector2(500.0, 430.0))
	screen._open_duel_log()
	await _settle()
	assert_eq(screen._duel_log.size, DuelLog.SIZE, "a log the player put below the bar keeps its size")
