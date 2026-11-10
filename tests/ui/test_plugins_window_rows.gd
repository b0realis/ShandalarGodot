extends GutTest
## THE EXPANDED ADVENTURE PLUGINS' WINDOW ON ITS OWN (adventure plugins,
## 2026-11-10; the owner: *"Plugins should get their own popup window for
## ticking them as not to clutter the main embark screen"*): a row for every
## plugin found — a tick, its name, version, authors, line, learning note and
## the card packs it needs ticked, not ticked or not installed; a refused one
## greyed with every problem; a plugin found twice saying which copy is
## used — ticking one ticks its packs and says so, Rescan, Open folder, OK,
## Escape and a pad's B, the ring of the keyboard, the fitting and the drag.
## The plugins are the loader's fixture, copied and changed under the test
## profile; the content stage is the loader tests' stand-in.

const ZIPS := preload("res://tests/support/plugin_zips.gd")
const ROOT := "user://plugins_window_rows"
const FIRST := ROOT + "/first"
const SECOND := ROOT + "/second"
const PACKED := {"id": "pack_isle", "name": "Pack Isle", "description": "An isle that needs Fallen Empires.",
	"learning_note": "A fixture of the plugins window.",
	"requires": {"card_packs": [{"id": "pack-2", "min_version": "1.0"}]}}

var window: PluginsWindow
var setup: AdventureSetup
var _ticked: Array = []
var _changed := 0
var _closed := 0
var _opened := 0


func before_each() -> void:
	_ticked.clear()
	_changed = 0
	_closed = 0
	_opened = 0
	DirAccess.make_dir_recursive_absolute(FIRST)
	DirAccess.make_dir_recursive_absolute(SECOND)
	AdventurePlugins.folders_override = [FIRST, SECOND] as Array[String]
	AdventurePlugins.content_reader = func(manifest: Dictionary, files: Dictionary) -> Dictionary:
		return ZIPS.reader(manifest, files)


func after_each() -> void:
	ZIPS.remove(ROOT)
	AdventurePlugins.folders_override = [] as Array[String]
	AdventurePlugins.content_reader = Callable()
	AdventurePlugins.scan()


## The fixture as [param id] in [param folder], its manifest's fields
## replaced by [param changes].
func _plugin(folder: String, id: String, changes := {}, extra := {}) -> void:
	var manifest := {"id": id}
	manifest.merge(changes, true)
	var files := {"plugin.json": ZIPS.manifest_bytes(manifest)}
	files.merge(extra, true)
	ZIPS.copy_fixture(folder.path_join(id), files)


## Every kind of row: a valid plugin needing no pack, one needing Pack 2, a
## refused one and a second copy of the first.
func _four_kinds() -> void:
	_plugin(FIRST, "tiny_isle")
	_plugin(FIRST, "pack_isle", PACKED)
	_plugin(FIRST, "broken_isle", {"name": "Broken Isle", "flavor": "salt", "speed": 3})
	_plugin(SECOND, "tiny_isle")


## The window over the test, on a fresh [AdventureSetup], the card packs
## installed [param installed] (the test run's own when null).
func _open(installed: Variant = null) -> void:
	AdventurePlugins.scan()
	setup = AdventureSetup.new()
	window = PluginsWindow.new()
	window.name = "AdventurePluginsWindow"
	window.setup = setup
	window.installed = installed if installed is Array else CardPacks.available_ids()
	window.folder_opener = func() -> void: _opened += 1
	window.packs_ticked.connect(func(ids: Array[String]) -> void: _ticked.append(ids))
	window.changed.connect(func() -> void: _changed += 1)
	window.closed.connect(func() -> void: _closed += 1)
	add_child_autofree(window)
	window.open()
	await get_tree().process_frame
	await get_tree().process_frame


func _find(node_name: String) -> Node:
	return window.find_child(node_name, true, false)


func _text(row: Node, node_name: String) -> String:
	var label := row.find_child(node_name, true, false) as Label
	return label.text if label != null else ""


func test_every_plugin_found_is_a_row_with_its_words() -> void:
	_four_kinds()
	await _open()
	assert_true(window.shown())
	assert_eq((_find("Title") as Label).text, PluginsWindow.TITLE)
	assert_string_contains((_find("Folder") as Label).text, "Folder: ")
	var rows := (_find("Rows") as Node).get_children()
	assert_eq(rows.size(), 3, "a row a plugin; the second copy is no row of its own")
	var tiny := _find("Plugin_tiny_isle") as Control
	assert_not_null(tiny)
	var tick := _find("Tick_tiny_isle") as CheckBox
	assert_eq(tick.text, "Tiny Isle (loader fixture)", "the tick carries the name")
	assert_false(tick.button_pressed)
	assert_eq(_text(tiny, "By"), "Version 0.1.0 · by Shandalar Godot tests")
	assert_string_contains(_text(tiny, "Description"), "loader's own test plugin")
	assert_string_contains(_text(tiny, "LearningNote"), "not a playable land")
	assert_eq(_text(tiny, "NeedsNone"), "Needs no card pack.")
	var copies := _text(tiny, "Copies")
	assert_string_contains(copies, "The copy used: %s" % GamePaths.shown(FIRST.path_join("tiny_isle")))
	assert_string_contains(copies, "Not used: %s" % GamePaths.shown(SECOND.path_join("tiny_isle")))
	var packed := _find("Plugin_pack_isle") as Control
	assert_eq(_text(packed, "Needs_pack-2"), "Needs %s — not ticked" % AdventurePacks.title("pack-2"))
	assert_string_contains(_text(packed, "LearningNote"), "A fixture of the plugins window")


func test_a_refused_plugin_is_greyed_with_every_problem_and_no_tick() -> void:
	_four_kinds()
	await _open()
	var refused: Control = null
	for row in (_find("Rows") as Node).get_children():
		if String(row.name).begins_with("Refused_"):
			refused = row
	assert_not_null(refused, "the refused row")
	if refused == null:
		return
	assert_eq(refused.find_children("*", "CheckBox", true, false).size(), 0, "no tick")
	assert_lt(refused.modulate.a, 1.0, "greyed")
	assert_eq(_text(refused, "Name"), "Broken Isle")
	assert_eq(_text(refused, "RefusedTag"), "Refused")
	var problems := _text(refused, "Problems")
	for problem: String in AdventurePlugins.row("broken_isle")["problems"]:
		assert_string_contains(problems, "• " + problem)
	assert_string_contains(problems, "\"flavor\"")
	assert_string_contains(problems, "\"speed\"", "every problem, not the first only")
	assert_string_contains(_text(refused, "Where"), "broken_isle")
	assert_null(_find("Tick_broken_isle"))


func test_ticking_a_plugin_ticks_its_packs_and_says_so() -> void:
	_four_kinds()
	await _open()
	var tick := _find("Tick_pack_isle") as CheckBox
	assert_false(tick.disabled)
	tick.button_pressed = true
	assert_eq(setup.adventures, ["pack_isle"] as Array[String])
	assert_eq(setup.packs, ["pack-2"] as Array[String], "its pack ticked with it")
	assert_eq(_ticked.size(), 1, "the Embark is told, to tick the box")
	assert_eq(_ticked[0], ["pack-2"] as Array[String])
	var message := _find("Message") as Label
	assert_true(message.visible)
	assert_eq(message.text, "%s is ticked too: Pack Isle needs it." % AdventurePacks.title("pack-2"))
	assert_eq(_text(_find("Plugin_pack_isle"), "Needs_pack-2"), "Needs %s — ticked" % AdventurePacks.title("pack-2"))
	assert_gt(_changed, 0)
	tick.button_pressed = false
	assert_eq(setup.adventures, [] as Array[String])
	assert_eq(setup.packs, ["pack-2"] as Array[String], "a pack is a card choice of its own: it stays")
	assert_false(message.visible)
	(_find("Tick_tiny_isle") as CheckBox).button_pressed = true
	assert_eq(setup.adventures, ["tiny_isle"] as Array[String])
	assert_false(message.visible, "nothing to say for a plugin needing no pack")
	assert_eq(_ticked.size(), 1)


func test_a_plugin_whose_pack_is_not_installed_cannot_be_ticked() -> void:
	_four_kinds()
	await _open([] as Array[String])
	var tick := _find("Tick_pack_isle") as CheckBox
	assert_true(tick.disabled)
	assert_eq(tick.focus_mode, Control.FOCUS_NONE)
	assert_string_contains(tick.tooltip_text, "Install %s in Options › Card Packs" % AdventurePacks.title("pack-2"))
	assert_eq(_text(_find("Plugin_pack_isle"), "Needs_pack-2"), "Needs %s — not installed" % AdventurePacks.title("pack-2"))
	window.choose("pack_isle", true)
	assert_eq(setup.adventures, [] as Array[String])
	assert_false(tick.button_pressed)
	assert_eq(setup.packs, [] as Array[String])


func test_rescan_reads_the_folders_again_and_unticks_a_plugin_gone() -> void:
	_plugin(FIRST, "tiny_isle")
	await _open()
	window.choose("tiny_isle", true)
	assert_eq(setup.adventures, ["tiny_isle"] as Array[String])
	_plugin(FIRST, "pack_isle", PACKED)
	ZIPS.remove(FIRST.path_join("tiny_isle"))
	var before := _changed
	window.rescan()
	assert_eq(setup.adventures, [] as Array[String], "a plugin no longer found is unticked")
	var message := (_find("Message") as Label).text
	assert_string_contains(message, "Rescanned: 1 plugin found.")
	assert_string_contains(message, "Tiny Isle (loader fixture) is no longer found or cannot be read, so it is unticked.")
	assert_null(_find("Tick_tiny_isle"))
	assert_not_null(_find("Tick_pack_isle"), "the plugin added is listed")
	assert_gt(_changed, before)
	await get_tree().process_frame
	assert_eq(get_viewport().gui_get_focus_owner(), _find("Tick_pack_isle"), "the keyboard on its tick")


func test_with_none_found_the_window_says_where_to_put_one() -> void:
	await _open()
	assert_eq((_find("NoneFound") as Label).text, PluginsWindow.NONE_FOUND)
	await get_tree().process_frame
	assert_eq(get_viewport().gui_get_focus_owner(), window.ok_button, "nothing to tick: the keyboard on OK")
	assert_eq(PluginsWindow.button_tip(0, AdventurePlugins.all()).get_slice("\n", 1), "No adventure plugins found.")


func test_open_folder_ok_escape_and_a_pads_b() -> void:
	_plugin(FIRST, "tiny_isle")
	await _open()
	if not OS.has_feature("web") and not OS.has_feature("android"):
		window.open_button.pressed.emit()
		assert_eq(_opened, 1, "Open folder opens the plugins folder")
	window.ok_button.pressed.emit()
	assert_false(window.shown())
	assert_eq(_closed, 1)
	window.open()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	window._unhandled_input(escape)
	assert_false(window.shown(), "Escape closes")
	window.open()
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_B
	b.pressed = true
	window._unhandled_input(b)
	assert_false(window.shown(), "a pad's B closes")
	assert_eq(_closed, 3)


func test_the_keyboard_walks_the_ticks_and_buttons_and_stays_in_the_window() -> void:
	_four_kinds()
	await _open([] as Array[String])
	var tiny := _find("Tick_tiny_isle") as CheckBox
	assert_eq(get_viewport().gui_get_focus_owner(), tiny, "the first tick that can be ticked")
	assert_eq(tiny.get_node(tiny.focus_neighbor_bottom), window.rescan_button,
		"the greyed tick is passed over, on to the buttons")
	assert_eq(tiny.get_node(tiny.focus_neighbor_top), window.ok_button, "and round")
	assert_eq(tiny.get_node(tiny.focus_neighbor_left), tiny, "Left and Right keep a tick")
	assert_eq(window.ok_button.get_node(window.ok_button.focus_neighbor_bottom), tiny)
	assert_eq(window.ok_button.get_node(window.ok_button.focus_neighbor_right), window.rescan_button)
	assert_eq(window.rescan_button.get_node(window.rescan_button.focus_neighbor_left), window.ok_button)
	assert_eq(tiny.get_node(tiny.focus_next), window.rescan_button, "Tab too")


func test_the_pane_fits_the_screen_and_moves_by_its_glass() -> void:
	for i in 14:
		_plugin(FIRST, "isle_%02d" % i, {"name": "Isle %d" % i})
	await _open()
	var pane := _find("Pane") as Control
	var room := window.get_viewport_rect().size
	assert_true(Rect2(Vector2.ZERO, room).encloses(pane.get_global_rect()), "on the screen")
	assert_lte(pane.size.y, room.y - 2 * PluginsWindow.SCREEN_MARGIN + 1.0, "fourteen rows: the list scrolls")
	var scroll := _find("List") as ScrollContainer
	assert_lt(scroll.size.y, (_find("Rows") as Control).get_combined_minimum_size().y)
	assert_lte(pane.size.x, PluginsWindow.WIDTH + 1.0)
	var from := pane.position
	var grip := (_find("Title") as Control).get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.global_position = grip
	window._on_pane_input(press)
	var motion := InputEventMouseMotion.new()
	motion.global_position = grip + Vector2(-40, 0)
	window._on_pane_input(motion)
	assert_eq(pane.position, from + Vector2(-40, 0), "dragged by its title")
	motion.global_position = grip + Vector2(-5000, -5000)
	window._on_pane_input(motion)
	assert_eq(pane.position, Vector2.ZERO, "kept on the screen")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.global_position = grip
	window._on_pane_input(release)
	window.say("A line said under the list.")
	assert_eq(pane.position, Vector2.ZERO, "a line said never moves it")


func test_the_words_for_packs_and_plugins() -> void:
	_four_kinds()
	AdventurePlugins.scan()
	var two: Array[String] = ["pack-2", "pack-3"]
	assert_eq(PluginsWindow.pack_state("pack-2", two, CardPacks.available_ids()), "ticked")
	assert_eq(PluginsWindow.pack_state("pack-4", two, CardPacks.available_ids()), "not ticked")
	assert_eq(PluginsWindow.pack_state("pack-2", two, [] as Array[String]), "not installed")
	assert_eq(PluginsWindow.pack_state("pack-1", ["pack-1"] as Array[String], ["pack-1"] as Array[String]), "not installed",
		"Pack 1 is never part of an adventure")
	assert_eq(PluginsWindow.ticked_words("pack_isle", two), "%s and %s are ticked too: Pack Isle needs them." % [
		AdventurePacks.title("pack-2"), AdventurePacks.title("pack-3")])
	assert_eq(PluginsWindow.unticked_words(["pack_isle"] as Array[String], "pack-2"),
		"Pack Isle is unticked too: it needs %s." % AdventurePacks.title("pack-2"))
	assert_eq(PluginsWindow.unticked_words(["pack_isle", "tiny_isle"] as Array[String], "pack-2"),
		"Pack Isle and Tiny Isle (loader fixture) are unticked too: they need %s." % AdventurePacks.title("pack-2"))
	var tip := PluginsWindow.button_tip(1, AdventurePlugins.all())
	assert_eq(tip.get_slice("\n", 1), "1 ticked of 3 found (1 refused).")
	assert_eq(PluginsWindow.by_line({"version": "2.1", "authors": ["Ann", "Bo", "Cy"]}), "Version 2.1 · by Ann, Bo and Cy")
	assert_eq(PluginsWindow.copies_line({"path": "user://a", "shadowed": []}), "")


## Every path the window shows is shortened as Options shortens one
## ([method GamePaths.shown], "~/…"), and the game's own development copy
## (`res://expanded_adventure/`) is named, never an absolute path into the
## checkout: here the Refuge prototype there, shadowed by a copy of its id.
func test_every_path_is_shown_short_and_the_games_own_copy_by_name() -> void:
	AdventurePlugins.folders_override = [FIRST, "res://" + AdventurePlugins.FOLDER_NAME] as Array[String]
	_plugin(FIRST, "refuge", {"name": "Refuge Stand-in"})
	await _open()
	var row := AdventurePlugins.row("refuge")
	assert_eq(row["shadowed"], ["res://expanded_adventure/Fallen_Empires_Refuge_prototype"], "the prototype passed over")
	var copies := _text(_find("Plugin_refuge"), "Copies")
	assert_eq(copies, "Found more than once. The copy used: %s. Not used: Fallen_Empires_Refuge_prototype in the game's own expanded_adventure folder." \
		% GamePaths.shown(FIRST.path_join("refuge")))
	var checkout := ProjectSettings.globalize_path("res://").path_join("")
	# The profile's own folder in full, where Options shows it short (under
	# the home folder; a runner whose profile is elsewhere shows it whole).
	var profile := ProjectSettings.globalize_path("user://").path_join("")
	var shortened := GamePaths.shown("user://") != ProjectSettings.globalize_path("user://")
	var words: Array[String] = [(_find("Plugin_refuge") as Control).tooltip_text]
	for label: Label in window.find_children("*", "Label", true, false):
		words.append(label.text)
	for text in words:
		assert_false(text.contains(checkout), "no absolute path into the checkout: " + text)
		assert_false(text.contains("res://"), text)
		assert_false(shortened and text.contains(profile), "shortened as Options shortens it: " + text)
	assert_eq((_find("Folder") as Label).text, "Folder: %s" % GamePaths.shown(GamePaths.expanded_adventure_folder()))
	assert_eq(PluginsWindow.where("res://expanded_adventure"), "the game's own expanded_adventure folder")
	assert_eq(PluginsWindow.where("res://expanded_adventure/Some.zip"), "Some.zip in the game's own expanded_adventure folder")
	assert_eq(PluginsWindow.where("user://expanded_adventure/a.zip"), GamePaths.shown("user://expanded_adventure/a.zip"))


## A CARD PACK OLDER THAN THE PLUGIN ASKS (P1's pack versions): installed, so
## not "not installed", but its ships would not sail — the line says what
## the plugin asks and what is installed, the tick is greyed with the
## mainland note's words and the way to mend it, and a plugin remembered
## ticked is not ticked again.
func test_a_plugin_whose_pack_is_too_old_cannot_be_ticked() -> void:
	_plugin(FIRST, "old_isle", {"name": "Old Isle", "requires": {"card_packs": [{"id": "pack-2", "min_version": "99.0"}]}})
	_plugin(FIRST, "pack_isle", PACKED)
	await _open()
	var have := String(CardPacks.info("pack-2").get("version", ""))
	assert_ne(have, "", "the test run's Pack 2 is installed, with a version")
	for row in AdventurePlugins.all():
		if row["id"] == "old_isle":
			assert_false(bool(row["pack_status"][0]["new_enough"]), "the registry says so too")
	assert_true(AdventurePlugins.valid("old_isle"), "a pack too old refuses nothing")
	var tick := _find("Tick_old_isle") as CheckBox
	assert_true(tick.disabled)
	assert_eq(tick.focus_mode, Control.FOCUS_NONE)
	var title := AdventurePacks.title("pack-2")
	assert_string_contains(tick.tooltip_text, "This plugin needs %s 99.0 or newer (installed %s)." % [title, have])
	assert_string_contains(tick.tooltip_text, "Update the pack in Options › Card Packs to tick it.")
	var line := (_find("Plugin_old_isle") as Node).find_child("Needs_pack-2", true, false) as Label
	assert_eq(line.text, "Needs %s 99.0 or newer — installed %s" % [title, have])
	assert_eq(line.get_theme_color("font_color"), PluginsWindow.MISSING)
	assert_eq(PluginsWindow.pack_state("pack-2", ["pack-2"] as Array[String], CardPacks.available_ids(),
		{"installed": true, "new_enough": false}), "too old", "too old whatever the tick")
	window.choose("old_isle", true)
	assert_eq(setup.adventures, [] as Array[String])
	assert_eq(setup.packs, [] as Array[String], "nor its pack ticked for it")
	assert_false(AdventureSetup.can_tick("old_isle", CardPacks.available_ids()))
	assert_false((_find("Tick_pack_isle") as CheckBox).disabled, "a plugin content with the same pack can be")
	assert_eq(_text(_find("Plugin_pack_isle"), "Needs_pack-2"), "Needs %s — not ticked" % title)
	# Remembered ticked from before the pack was older than it asks.
	Settings.set_value(AdventureSetup.KEY_PREFIX + "packs", "pack-2", false)
	Settings.set_value(AdventureSetup.KEY_PREFIX + "plugins", "old_isle,pack_isle", false)
	var kept := AdventureSetup.restore(CardPacks.available_ids())
	AdventureSetup.forget()
	assert_eq(kept.adventures, ["pack_isle"] as Array[String], "dropped on restore, as one whose pack is gone")
	assert_eq(kept.packs, ["pack-2"] as Array[String])


func test_a_greyed_tick_looks_greyed() -> void:
	var faded := PluginsWindow.greyed_check(false).get_image()
	var plain := UiChrome.check_icon(false).get_image()
	assert_eq(faded.get_size(), plain.get_size())
	assert_lt(faded.get_pixel(5, 5).a, plain.get_pixel(5, 5).a, "the box faded")
	assert_eq(PluginsWindow.greyed_check(true), PluginsWindow.greyed_check(true), "made once")
