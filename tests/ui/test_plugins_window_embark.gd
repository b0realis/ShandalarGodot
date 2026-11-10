extends GutTest
## THE EMBARK'S ONE PLUGINS BUTTON AND ITS WINDOW (adventure plugins,
## 2026-11-10; the owner: *"Plugins should get their own popup window for
## ticking them as not to clutter the main embark screen. Only button to
## reach them at the bottom of pack selections."*): the button alone at the
## foot of the card packs (and of the no-packs words), the ticked count in
## its tooltip; its window ticks the Embark's pack boxes; a pack unticked
## takes the plugins needing it along and the words over the packs say so; Escape and a pad's B close the window before they leave the screen;
## the ticks are remembered with their packs.

const ZIPS := preload("res://tests/support/plugin_zips.gd")
const ROOT := "user://plugins_window_embark"
const PACKED := {"id": "pack_isle", "name": "Pack Isle", "description": "An isle that needs Fallen Empires.",
	"requires": {"card_packs": [{"id": "pack-2", "min_version": "1.0"}]}}

var screen: EmbarkScreen
## Pack reports taken out of [code]CardPacks._available[/code] by a test (a
## pack "not installed"), put back after it.
var _hidden := {}


func before_each() -> void:
	AdventureSetup.forget()
	DirAccess.make_dir_recursive_absolute(ROOT)
	ZIPS.copy_fixture(ROOT.path_join("pack_isle"), {"plugin.json": ZIPS.manifest_bytes(PACKED)})
	ZIPS.copy_fixture(ROOT.path_join("tiny_isle"))
	AdventurePlugins.folders_override = [ROOT] as Array[String]
	AdventurePlugins.content_reader = func(manifest: Dictionary, files: Dictionary) -> Dictionary:
		return ZIPS.reader(manifest, files)
	AdventurePlugins.scan()
	screen = await _embark()


func after_each() -> void:
	for id in _hidden:
		CardPacks._available[id] = _hidden[id]
	_hidden.clear()
	AdventureSetup.forget()
	ZIPS.remove(ROOT)
	AdventurePlugins.folders_override = [] as Array[String]
	AdventurePlugins.content_reader = Callable()
	AdventurePlugins.scan()


func _embark() -> EmbarkScreen:
	var made: EmbarkScreen = load("res://game/adventure/embark_screen.tscn").instantiate()
	add_child_autofree(made)
	await get_tree().process_frame
	return made


func _window() -> PluginsWindow:
	return screen.find_child("AdventurePluginsWindow", true, false) as PluginsWindow


func test_one_button_at_the_foot_of_the_packs_and_nothing_else_of_plugins() -> void:
	var button := screen.find_child("AdventurePlugins", true, false) as Button
	assert_not_null(button)
	assert_eq(button, screen.plugins_button)
	assert_eq(button.text, EmbarkScreen.PLUGINS_BUTTON)
	var journey := screen.find_child("JourneyPanel", true, false)
	assert_true(journey.is_ancestor_of(button), "in the card packs' window")
	var packs := screen.find_child("Packs", true, false) as Control
	if packs == null:
		packs = screen.find_child("NoPacks", true, false) as Control
	assert_eq(button.get_parent(), packs.get_parent(), "beside the list in its column")
	assert_gt(button.get_index(), packs.get_index(), "under the list")
	assert_eq(button.get_index(), button.get_parent().get_child_count() - 1, "at its foot")
	assert_null(_window(), "no window until it is asked for")
	assert_eq(screen.plugins_note(), "", "nothing said of plugins")
	assert_eq((screen.find_child("PacksAbout", true, false) as Label).text, EmbarkScreen.PACKS_ABOUT)
	for label: Label in screen.find_children("*", "Label", true, false):
		if label.is_visible_in_tree():
			assert_false(label.text.to_lower().contains("plugin"), "nothing else of plugins: " + label.text)
	assert_string_contains(button.tooltip_text, "0 ticked of 2 found.")


func test_the_no_packs_words_have_the_button_under_them_too() -> void:
	for id in CardPacks.available_ids():
		_hidden[id] = CardPacks._available[id]
		CardPacks._available.erase(id)
	var bare := await _embark()
	var none := bare.find_child("NoPacks", true, false) as Control
	assert_not_null(none, "no packs installed")
	var button := bare.find_child("AdventurePlugins", true, false) as Control
	assert_not_null(button)
	assert_eq(button.get_parent(), none.get_parent())
	assert_gt(button.get_index(), none.get_index(), "under the no-packs words")
	bare.open_plugins()
	var tick := bare.find_child("Tick_pack_isle", true, false) as CheckBox
	assert_true(tick.disabled, "its pack is not installed: no tick")
	bare.close_plugins()


func test_the_window_ticks_the_embarks_pack_box_and_the_tooltip_counts() -> void:
	screen.open_plugins()
	var window := _window()
	assert_not_null(window)
	assert_true(screen.plugins_shown())
	var box := screen._pack_checks["pack-2"] as CheckBox
	assert_false(box.button_pressed)
	(window.find_child("Tick_pack_isle", true, false) as CheckBox).button_pressed = true
	assert_true(box.button_pressed, "the Embark's Pack 2 box ticked with the plugin")
	assert_eq(screen.setup.packs, ["pack-2"] as Array[String])
	assert_eq(screen.setup.adventures, ["pack_isle"] as Array[String])
	assert_string_contains(screen.plugins_button.tooltip_text, "1 ticked of 2 found.")
	window.ok_button.pressed.emit()
	assert_false(screen.plugins_shown())
	await get_tree().process_frame
	assert_eq(get_viewport().gui_get_focus_owner(), screen.plugins_button, "the keyboard back on the button")
	screen.open_plugins()
	assert_eq(window, _window(), "the same window, shown again")
	assert_true((window.find_child("Tick_pack_isle", true, false) as CheckBox).button_pressed, "as ticked")
	var record := screen.setup.resolve({"pack-2": "1"})
	assert_eq((record["adventures"] as Array).map(func(row: Dictionary) -> String: return row["id"]), ["pack_isle"])


func test_unticking_a_pack_unticks_the_plugins_that_need_it_and_says_so() -> void:
	screen.open_plugins()
	_window().choose("pack_isle", true)
	_window().choose("tiny_isle", true)
	screen.close_plugins()
	(screen._pack_checks["pack-2"] as CheckBox).button_pressed = false
	assert_eq(screen.setup.adventures, ["tiny_isle"] as Array[String], "the plugin needing Pack 2 goes with it")
	var words := "Pack Isle is unticked too: it needs %s." % AdventurePacks.title("pack-2")
	var about := screen.find_child("PacksAbout", true, false) as Label
	assert_eq(screen.plugins_note(), words)
	assert_eq(about.text, words, "said over the packs, in the packs' words' place")
	assert_eq(about.get_theme_color("font_color"), EmbarkScreen.GOLD)
	assert_string_contains(screen.plugins_button.tooltip_text, "1 ticked of 2 found.")
	screen.open_plugins()
	assert_eq(about.text, EmbarkScreen.PACKS_ABOUT, "the window says how they stand now")
	_window().choose("pack_isle", true)
	screen.close_plugins()
	await get_tree().process_frame
	screen.choose_all_packs(false)
	assert_eq(screen.setup.adventures, ["tiny_isle"] as Array[String], "None too")
	assert_eq(about.text, words, "said once for the many boxes unticked at once")
	screen.choose_all_packs(true)
	assert_eq(screen.setup.adventures, ["tiny_isle"] as Array[String], "a pack ticked never ticks a plugin")
	assert_eq(about.text, words, "the words stay through the frame they were said in")
	await get_tree().process_frame
	(screen._pack_checks["pack-3"] as CheckBox).button_pressed = false
	(screen._pack_checks["pack-3"] as CheckBox).button_pressed = true
	assert_eq(about.text, EmbarkScreen.PACKS_ABOUT, "a pack ticked later puts the packs' words back")
	_window().choose("pack_isle", true)
	screen.randomize_all(RandomNumberGenerator.new())
	if not "pack-2" in screen.setup.packs:
		assert_false("pack_isle" in screen.setup.adventures, "Randomize unticking Pack 2 unticks it")
		assert_string_contains(about.text, "Pack Isle is unticked too")
	else:
		assert_true("pack_isle" in screen.setup.adventures)


func test_escape_and_a_pads_b_close_the_window_before_they_leave() -> void:
	screen.open_plugins()
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	screen._unhandled_input(escape)
	assert_false(screen.plugins_shown(), "Escape closes the window")
	assert_false(screen._leaving, "and does not leave the screen")
	screen.open_plugins()
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_B
	b.pressed = true
	get_viewport().push_input(b)
	await get_tree().process_frame
	assert_false(screen.plugins_shown(), "a pad's B closes it")
	assert_false(screen._leaving)
	screen._unhandled_input(escape)
	assert_true(screen._leaving, "with the window shut, Escape is Leave")


func test_the_ticks_are_remembered_with_their_packs() -> void:
	screen.open_plugins()
	_window().choose("pack_isle", true)
	screen.setup.remember()
	var again := await _embark()
	assert_eq(again.setup.adventures, ["pack_isle"] as Array[String])
	assert_true((again._pack_checks["pack-2"] as CheckBox).button_pressed)
	# A plugin remembered without its pack (the pack gone since) is not ticked.
	Settings.set_value(AdventureSetup.KEY_PREFIX + "packs", "", false)
	var bare := AdventureSetup.restore(CardPacks.available_ids())
	assert_eq(bare.adventures, [] as Array[String], "a plugin goes with its packs")
	Settings.set_value(AdventureSetup.KEY_PREFIX + "plugins", "pack_isle,tiny_isle", false)
	assert_eq(AdventureSetup.restore(CardPacks.available_ids()).adventures, ["tiny_isle"] as Array[String])


func test_the_setup_ticks_and_unticks_by_the_packs() -> void:
	var setup := AdventureSetup.new()
	var installed := CardPacks.available_ids()
	assert_true(AdventureSetup.can_tick("pack_isle", installed))
	assert_false(AdventureSetup.can_tick("pack_isle", [] as Array[String]), "its pack not installed")
	assert_false(AdventureSetup.can_tick("no_such_isle", installed), "never found")
	assert_eq(setup.tick_adventure("pack_isle", installed), ["pack-2"] as Array[String])
	assert_eq(setup.tick_adventure("pack_isle", installed), [] as Array[String], "ticked once")
	assert_eq(setup.adventures, ["pack_isle"] as Array[String])
	assert_eq(setup.tick_adventure("no_such_isle", installed), [] as Array[String])
	assert_eq(setup.adventures, ["pack_isle"] as Array[String])
	assert_true(setup.packs_ticked_for("pack_isle"))
	assert_eq(setup.untick_pack("pack-3"), [] as Array[String])
	assert_eq(setup.untick_pack("pack-2"), ["pack_isle"] as Array[String])
	assert_eq(setup.adventures, [] as Array[String])
	assert_eq(setup.packs, [] as Array[String])
