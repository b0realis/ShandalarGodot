extends GutTest
## `[QoL]` FULL SCREEN — the Options screen's `Display:` row
## (`game/options_screen.gd`), the stored key behind it
## (`Settings.fullscreen`) and the one place it reaches the OS window
## (`game/display.gd`, applied at boot by the `Lifecycle` autoload).
##
## Asked for on 2026-09-07: *"options menu in the main menu lacks full
## screen / windowed option. And all selections you make should keep as
## default on your next run."* The 1997 game had no such switch (see
## [GameDisplay] for the nearest it came), so what these pin is ours:
##
##   1. Off by default — the shipped 1280x800 window is what the game has
##      always opened into, and the file is not written until the player
##      asks.
##   2. The switch is a VIEW of the key: it opens on what is stored and
##      writes what is ticked, to disk, at once.
##   3. Applying is silent headless — the suite, the soak and the Deck Lab
##      have no window to set — and idempotent where there is one.
##   4. Boot applies it: the autoload that leaves the tree last is the one
##      that enters it first, and it asks for the stored mode.


var screen: Control
var _saved: Variant = null


func before_each() -> void:
	# The suite runs against its own `user://` (run_tests.sh), but a test
	# still leaves the key exactly as it found it.
	_saved = Settings.get_value(GameDisplay.KEY, null) \
		if Settings.has_value(GameDisplay.KEY) else null
	Settings.clear_value(GameDisplay.KEY)
	screen = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	if _saved == null:
		Settings.clear_value(GameDisplay.KEY)
	else:
		Settings.set_value(GameDisplay.KEY, _saved)


func _walk(node: Node) -> Array:
	var out := [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out


## The one CheckButton that says so.
func _switch() -> CheckButton:
	for node in _walk(screen):
		if node is CheckButton and node.text == "Full screen":
			return node
	return null


## Every label's text in tree order, for "which row comes first".
func _label_texts() -> Array[String]:
	var out: Array[String] = []
	for node in _walk(screen):
		if node is Label:
			out.append(node.text)
	return out


## What the file on disk says, read fresh — not what Settings remembers.
static func _on_disk(key: String) -> Variant:
	var file := ConfigFile.new()
	file.load(Settings.PATH)
	if not file.has_section_key("options", key):
		return null
	return file.get_value("options", key)


# ================================================== off by default (1) ==

func test_the_window_is_windowed_until_asked_otherwise() -> void:
	assert_eq(GameDisplay.KEY, "fullscreen", "the key Settings.fullscreen reads")
	assert_false(Settings.fullscreen(), "the shipped window is the default")
	assert_eq(GameDisplay.wanted_mode(), DisplayServer.WINDOW_MODE_WINDOWED)
	assert_false(Settings.has_value(GameDisplay.KEY),
		"and opening the screen does not materialize the default into the file")


func test_the_switch_opens_off_with_nothing_stored() -> void:
	var switch := _switch()
	assert_not_null(switch, "the Display row carries a `Full screen` switch")
	assert_false(switch.button_pressed)


func test_the_display_row_is_the_first_on_the_screen() -> void:
	var texts := _label_texts()
	var display := texts.find("Display:")
	var sound := texts.find("Sound:")
	assert_gte(display, 0, "there is a Display row")
	assert_gte(sound, 0, "there is a Sound row")
	assert_lt(display, sound, "Display sits above Sound — the window before what plays in it")


# ================================================ the switch is a view (2) ==

func test_ticking_the_switch_stores_the_choice_at_once() -> void:
	var switch := _switch()
	switch.button_pressed = true
	assert_true(Settings.fullscreen(), "the key follows the switch")
	assert_eq(GameDisplay.wanted_mode(), DisplayServer.WINDOW_MODE_FULLSCREEN)
	assert_eq(_on_disk(GameDisplay.KEY), true,
		"written to disk immediately — a rare write, and the next run reads it")
	switch.button_pressed = false
	assert_false(Settings.fullscreen())
	assert_eq(_on_disk(GameDisplay.KEY), false)


func test_the_switch_opens_on_what_is_stored() -> void:
	Settings.set_value(GameDisplay.KEY, true)
	var fresh: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(fresh)
	await get_tree().process_frame
	var found: CheckButton = null
	for node in _walk(fresh):
		if node is CheckButton and node.text == "Full screen":
			found = node
	assert_not_null(found)
	assert_true(found.button_pressed, "a stored `true` opens the switch ticked")


func test_the_choice_survives_a_reload_of_the_file() -> void:
	# What "keep as default on your next run" means for this key: the
	# in-memory copy is forgotten and the file alone has to carry it.
	GameDisplay.set_fullscreen(true)
	Settings.reload()
	assert_true(Settings.fullscreen(), "the file carries the choice")


# ======================================== applying is silent headless (3) ==

func test_applying_headless_sets_nothing_and_fails_nothing() -> void:
	# The suite is headless; there is no window to put full screen on.
	var before := DisplayServer.window_get_mode()
	Settings.set_value(GameDisplay.KEY, true, false)
	GameDisplay.apply_settings()
	assert_eq(DisplayServer.window_get_mode(), before,
		"no window, no change — and no error above this line")
	Settings.set_value(GameDisplay.KEY, false, false)
	GameDisplay.apply_settings()
	assert_eq(DisplayServer.window_get_mode(), before)
	Settings.flush()


func test_a_borderless_full_screen_not_an_exclusive_one() -> void:
	# The compositor keeps running and the desktop keeps its resolution;
	# an exclusive mode would buy a 2D card game nothing (see GameDisplay).
	Settings.set_value(GameDisplay.KEY, true, false)
	assert_eq(GameDisplay.wanted_mode(), DisplayServer.WINDOW_MODE_FULLSCREEN)
	assert_ne(GameDisplay.wanted_mode(),
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	Settings.set_value(GameDisplay.KEY, false, false)
	Settings.flush()


# ============================================================ boot (4) ==

func test_the_autoload_that_leaves_last_enters_first_and_applies_it() -> void:
	var hook := get_tree().root.get_node_or_null("Lifecycle")
	assert_not_null(hook, "the Lifecycle autoload is in the tree")
	# It is a plain Node with a `_ready`; the source pins what that ready
	# does, and the headless test above pins that it is harmless here.
	assert_true(hook.has_method("_ready"),
		"boot is where the stored window mode goes onto the window")
	var source: String = (hook.get_script() as GDScript).source_code
	assert_true(source.contains("GameDisplay.apply_settings()"),
		"and it is GameDisplay that puts it there")
