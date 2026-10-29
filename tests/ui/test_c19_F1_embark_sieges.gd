extends GutTest
## THE SIEGES' PACE ON THE EMBARK SCREEN (the owner's ruling of 2026-10-28):
## a row "Sieges" in the Campaign Settings (under the difficulty until
## 2026-10-29) — "As 1997", "Steady" (the default), "Rare", "None" —
## chosen by the mouse or the keys, its tooltip in plain
## words; the record, the next visit and the adventure carry it, Randomize
## leaves it, the arrival says it; and the screen stays whole at 1280 × 800
## and at 800 × 600 (1280 × 960 inside the window), with the skin as the
## machine has it and without the art, with the Big buttons on.

var screen: EmbarkScreen
var _big: Variant


func before_each() -> void:
	AdventureSetup.forget()
	_big = Settings.get_value(WorldHud.BIG_SETTING, null)
	Settings.set_value(WorldHud.BIG_SETTING, true, false)
	screen = load("res://game/adventure/embark_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	AdventureSetup.forget()
	if _big == null:
		Settings.clear_value(WorldHud.BIG_SETTING)
	else:
		Settings.set_value(WorldHud.BIG_SETTING, _big, false)
	GameSkin.clear_caches()


func _find(node_name: String, under: Node = null) -> Node:
	return (under if under != null else screen).find_child(node_name, true, false)


func _frames(count := 3) -> void:
	for i in count:
		await get_tree().process_frame


func _key(port: Viewport, code: Key) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.pressed = pressed
		port.push_input(key, true)
	await _frames(2)


func _click(port: Viewport, at: Vector2) -> void:
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.position = at
		click.global_position = at
		click.pressed = pressed
		port.push_input(click, true)
	await _frames(2)


func test_the_sieges_line_under_the_difficulty() -> void:
	var sieges := _find("Sieges") as OptionButton
	assert_not_null(sieges)
	var names: Array[String] = []
	for i in sieges.item_count:
		names.append(sieges.get_item_text(i))
	assert_eq(names, ["As 1997", "Steady", "Rare", "None"] as Array[String])
	assert_eq(sieges.selected, 1, "Steady by default")
	assert_eq(screen.setup.sieges, AdventurePlayer.SIEGES_STEADY)
	assert_eq((_find("SiegesWords") as Label).text, "Sieges")
	assert_string_contains(sieges.tooltip_text, "every two minutes of walking, never faster")
	# [0.50.65, the owner's ruling of 2026-10-29] In the Campaign Settings,
	# under the card hold (it stood under the difficulty before).
	assert_true(_find("CampaignSettingsWindow").is_ancestor_of(sieges), "in the Campaign Settings")
	screen.open_settings()
	await _frames()
	assert_lt(_find("CardHold").get_global_rect().end.y, sieges.get_global_rect().position.y + 1.0,
		"under the card hold")
	screen.close_settings()


func test_chosen_by_the_mouse_and_by_the_keys() -> void:
	# The screen in a window of its own at 1280 × 800, its lists drawn in it,
	# so the clicks and keys go where a player's would.
	var port := SubViewport.new()
	port.size = Vector2i(1280, 800)
	port.gui_disable_input = false
	port.gui_embed_subwindows = true
	add_child_autofree(port)
	var shown: EmbarkScreen = load("res://game/adventure/embark_screen.tscn").instantiate()
	port.add_child(shown)
	await _frames()
	var sieges := _find("Sieges", shown) as OptionButton
	shown.open_settings()
	await _frames()
	var popup := sieges.get_popup()
	await _click(port, sieges.get_global_rect().get_center())
	assert_true(popup.visible, "a click opens the list")
	# The list's last line, None: a click in its lowest eighth.
	var rect := Rect2(Vector2(popup.position), Vector2(popup.size))
	await _click(port, Vector2(rect.get_center().x, rect.end.y - rect.size.y / 8.0))
	assert_false(popup.visible, "a choice closes it")
	assert_eq(shown.setup.sieges, AdventurePlayer.SIEGES_NONE, "the mouse chose None")
	assert_string_contains(sieges.tooltip_text, "never besiege")
	sieges.grab_focus()
	await _frames()
	await _key(port, KEY_ENTER)
	assert_true(popup.visible, "Enter opens the list")
	# From None, three lines up: As 1997.
	for i in 3:
		await _key(port, KEY_UP)
	await _key(port, KEY_ENTER)
	assert_false(popup.visible)
	assert_eq(shown.setup.sieges, AdventurePlayer.SIEGES_1997, "the keys chose As 1997")
	assert_string_contains(sieges.tooltip_text, "each comes sooner than the last")
	shown.choose_sieges("every week")
	assert_eq(shown.setup.sieges, AdventurePlayer.SIEGES_1997, "an odd one changes nothing")


func test_the_record_the_next_visit_and_the_arrival_carry_it() -> void:
	screen.choose_sieges(AdventurePlayer.SIEGES_RARE)
	watch_signals(screen)
	(_find("HeroName") as LineEdit).text = "Ysolde Starfall"
	screen.embark()
	var record: Dictionary = get_signal_parameters(screen, "embarked")[0]
	assert_eq(String(record["sieges"]), AdventurePlayer.SIEGES_RARE)
	assert_string_contains(screen.summary(record), EmbarkScreen.SIEGE_SUMMARY[AdventurePlayer.SIEGES_RARE])
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	assert_eq(hero.sieges, AdventurePlayer.SIEGES_RARE)
	var again: EmbarkScreen = load("res://game/adventure/embark_screen.tscn").instantiate()
	add_child_autofree(again)
	await get_tree().process_frame
	assert_eq((_find("Sieges", again) as OptionButton).selected, 2, "Rare, as chosen before")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 6:
		again.randomize_all(rng)
		assert_eq(again.setup.sieges, AdventurePlayer.SIEGES_RARE, "not drawn")


## THE SCREEN STAYS WHOLE with the sieges' line ([method
## test_p0a_embark_rules]'s measure).
func test_the_screen_stays_whole() -> void:
	await _whole(screen, Vector2(1280, 800), "1280 × 800 with the skin as it is", true)
	await _whole(screen, Vector2(1280, 960), "800 × 600 with the skin as it is", true)
	GameSkin._texture_cache[EmbarkScreen.BACKGROUND_KEY] = null
	GameSkin._texture_cache["stat_buttons"] = null
	GameSkin._font_cache["font_title"] = null
	var bare: EmbarkScreen = load("res://game/adventure/embark_screen.tscn").instantiate()
	add_child_autofree(bare)
	await get_tree().process_frame
	await _whole(bare, Vector2(1280, 800), "1280 × 800 without the art", false)
	await _whole(bare, Vector2(1280, 960), "800 × 600 without the art", false)


func _whole(on: EmbarkScreen, size: Vector2, how: String, every_column: bool) -> void:
	on.size = size
	await _frames()
	var columns := _find("Columns", on) as Control
	var scroll := columns.get_parent() as ScrollContainer
	var journey := _find("JourneyPanel", on) as Control
	if every_column:
		assert_false(scroll.get_v_scroll_bar().visible, "%s: the columns do not scroll" % how)
	assert_false(scroll.get_h_scroll_bar().visible, "%s: nothing scrolls sideways" % how)
	assert_lte(journey.get_combined_minimum_size().y, scroll.size.y, "%s: the difficulty's column fits" % how)
	# [0.50.65] The row in the Campaign Settings' window, on the screen.
	on.open_settings()
	await _frames()
	var window := _find("CampaignSettingsWindow", on) as Control
	var row := _find("SiegesRow", on) as Control
	assert_true(window.get_global_rect().encloses(row.get_global_rect()), "%s: in its window" % how)
	assert_true(Rect2(Vector2.ZERO, on.size).encloses(window.get_global_rect()), "%s: the window on the screen" % how)
	var option := _find("Sieges", on) as OptionButton
	assert_lte(option.get_combined_minimum_size().x, option.size.x + 0.5, "%s: whole" % how)
	on.close_settings()
