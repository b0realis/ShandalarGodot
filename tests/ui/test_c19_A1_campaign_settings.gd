extends GutTest
## THE CAMPAIGN SETTINGS (the owner, 2026-10-29: *"we just make a button
## called 'campaign settings' with a popup and all modern settings with
## short explanations there"*; builder A1 of 0.50.65): the Embark keeps
## 1997's own choices, and one button "Campaign Settings..." under the
## playmat opens a window of the 1997 dark stone with a row a setting —
## Final battle, Card rule, Ban list (greyed unless Classic), Card hold,
## Sieges, Creatures, Starting life, Ascetic hero — each with its plain line
## under it; "As 1997" and "Done"; Escape is Done; the keys walk the rows
## and stay in the window; a line under the button says what is chosen.
## The three new rows (Creatures: Hunt / Notice, default Notice; Starting
## life: Links only / Base 10 + links, default Links only; Ascetic hero,
## off) reach the record, the next visit and the arrival. And the screen
## and the window stay whole at 1280 × 800 and 1280 × 960.

var screen: EmbarkScreen


func before_each() -> void:
	AdventureSetup.forget()
	screen = load("res://game/adventure/embark_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	AdventureSetup.forget()
	GameSkin.clear_caches()


func _find(node_name: String, under: Node = null) -> Node:
	return (under if under != null else screen).find_child(node_name, true, false)


func _frames(count := 3) -> void:
	for i in count:
		await get_tree().process_frame


func _names(option: OptionButton) -> Array[String]:
	var out: Array[String] = []
	for i in option.item_count:
		out.append(option.get_item_text(i))
	return out


func _key(port: Viewport, code: Key, shift := false) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.shift_pressed = shift
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


# ------------------------------------------------------------ the screen --

func test_the_rules_left_the_screen_for_one_button() -> void:
	var button := _find("CampaignSettings") as Button
	assert_not_null(button)
	assert_eq(button.text, "Campaign Settings...")
	assert_true(_find("MagicPanel").is_ancestor_of(button), "under the playmat")
	assert_lt((_find("PlaymatPreview") as Control).get_global_rect().end.y, button.global_position.y)
	assert_eq((_find("PlaymatPreview") as Control).custom_minimum_size, Vector2(320, 140),
		"the playmat at its size again")
	assert_null(_find("RulesBox"), "no Your rules box")
	var window := _find("CampaignSettingsWindow") as Control
	for base in EmbarkScreen.SETTING_ROWS:
		assert_true(window.is_ancestor_of(_find(base)), "%s only in the window" % base)
	assert_false(screen.settings_shown(), "closed to begin with")
	var line := _find("CampaignSummary") as Label
	assert_eq(line.text, "Steady sieges · Creatures notice · Reload allowed", "the defaults in a line")
	for words in ["Final battle: Reload allowed", "Sieges: Steady", "Creatures: Notice",
			"Starting life: Links only", "Ascetic hero: off", "Card hold: 1997 card hold limit"]:
		assert_string_contains(line.tooltip_text, words)
	assert_eq(button.tooltip_text, line.tooltip_text)
	screen.choose_life_start(AdventurePlayer.START_BASE)
	screen.choose_ascetic(true)
	screen.choose_card_rule(AdventurePlayer.RULE_CLASSIC)
	assert_eq(line.text, "Steady sieges · Creatures notice · Reload allowed · Classic MTG rules · Base 10 life · Ascetic hero",
		"what is not the default, after")


func test_the_window_holds_every_row_in_the_owners_order() -> void:
	screen.open_settings()
	await _frames()
	assert_true(screen.settings_shown())
	var window := _find("CampaignSettingsWindow") as OriginalDialog
	assert_string_contains(_texts(window), "Campaign Settings")
	var last := -1.0
	var names := {"LifeRule": "Final battle", "CardRule": "Card rule", "BanList": "Ban list",
		"CardHold": "Card hold", "Sieges": "Sieges", "Creatures": "Creatures", "LifeStart": "Starting life",
		"Ascetic": "Ascetic hero"}
	for base in EmbarkScreen.SETTING_ROWS:
		var row := _find(base + "Row") as Control
		assert_gt(row.global_position.y, last, "%s below the one before" % base)
		last = row.global_position.y
		assert_eq((_find(base + "Words") as Label).text, String(names[base]))
		var said := _find(base + "Line") as Label
		assert_ne(said.text, "", "%s: its line" % base)
		assert_true(said.is_visible_in_tree(), "%s: always shown" % base)
		assert_true(window.get_global_rect().encloses(row.get_global_rect()), "%s in the window" % base)
	assert_eq((_find("BanListLine") as Label).text, EmbarkScreen.BAN_GREYED_LINE, "greyed: why")
	assert_true((_find("BanList") as OptionButton).disabled)
	assert_not_null(_find("As1997"))
	assert_not_null(_find("Done"))
	(_find("Done") as Button).pressed.emit()
	assert_false(screen.settings_shown(), "Done closes it")


func _texts(node: Node) -> String:
	var out := ""
	for child in node.find_children("*", "Label", true, false):
		out += (child as Label).text + "\n"
	return out


# ------------------------------------------------------------ the new rows --

func test_the_creatures_row() -> void:
	var creatures := _find("Creatures") as OptionButton
	assert_eq(_names(creatures), ["Hunt", "Notice"] as Array[String])
	assert_eq(creatures.selected, 1, "Notice by default")
	assert_eq(screen.setup.creatures, AdventurePlayer.CREATURES_NOTICE)
	assert_string_contains(creatures.tooltip_text, "wanders its own lands")
	assert_string_contains((_find("CreaturesLine") as Label).text, "wander until you come near")
	creatures.select(0)
	creatures.item_selected.emit(0)
	assert_eq(screen.setup.creatures, AdventurePlayer.CREATURES_HUNT)
	assert_string_contains((_find("CreaturesLine") as Label).text, "as in 1997")
	screen.choose_creatures("prowl")
	assert_eq(screen.setup.creatures, AdventurePlayer.CREATURES_HUNT, "an odd one changes nothing")
	watch_signals(screen)
	(_find("HeroName") as LineEdit).text = "Ysolde Starfall"
	screen.embark()
	var record: Dictionary = get_signal_parameters(screen, "embarked")[0]
	assert_eq(String(record["creatures"]), AdventurePlayer.CREATURES_HUNT, "the record carries it")
	assert_eq(AdventureSetup.restore([] as Array[String]).creatures, AdventurePlayer.CREATURES_HUNT, "the next visit")
	assert_string_contains(screen.summary(record), EmbarkScreen.CREATURE_SUMMARY[AdventurePlayer.CREATURES_HUNT])
	assert_eq(AdventurePlayer.begin(record, AdventureSetup.make_world(record)).creatures, AdventurePlayer.CREATURES_HUNT)


func test_the_starting_life_row() -> void:
	var start := _find("LifeStart") as OptionButton
	assert_eq(_names(start), ["Links only", "Base 10 + links"] as Array[String])
	assert_eq(start.selected, 0, "Links only by default")
	start.select(1)
	start.item_selected.emit(1)
	assert_eq(screen.setup.life_start, AdventurePlayer.START_BASE)
	assert_string_contains(start.tooltip_text, "Ring of the Guardian")
	assert_string_contains((_find("LifeStartLine") as Label).text, "starts at 10")
	watch_signals(screen)
	(_find("HeroName") as LineEdit).text = "Ysolde Starfall"
	screen.embark()
	var record: Dictionary = get_signal_parameters(screen, "embarked")[0]
	assert_eq(String(record["life_start"]), AdventurePlayer.START_BASE)
	assert_string_contains(screen.summary(record), EmbarkScreen.START_SUMMARY[AdventurePlayer.START_BASE])
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	assert_eq(hero.duel_start_life(), 10 + hero.mana_links(), "a new hero's duels at 20")


func test_the_ascetic_hero_box() -> void:
	var box := _find("Ascetic") as CheckBox
	assert_false(box.button_pressed, "off by default")
	assert_string_contains((_find("AsceticLine") as Label).text, "as in 1997")
	assert_string_contains(box.tooltip_text, "food lasts twice as long")
	box.button_pressed = true
	assert_true(screen.setup.ascetic)
	assert_eq((_find("AsceticLine") as Label).text, "Your hero eats half as much: food lasts twice as long.")
	watch_signals(screen)
	(_find("HeroName") as LineEdit).text = "Ysolde Starfall"
	screen.embark()
	var record: Dictionary = get_signal_parameters(screen, "embarked")[0]
	assert_true(bool(record["ascetic"]))
	assert_true(AdventureSetup.restore([] as Array[String]).ascetic, "the next visit")
	assert_string_contains(screen.summary(record), EmbarkScreen.ASCETIC_SUMMARY, "the arrival")
	var plain := AdventureSetup.new()
	plain.player_name = "Ysolde Starfall"
	assert_false(screen.summary(plain.resolve({})).contains(EmbarkScreen.ASCETIC_SUMMARY), "off says nothing")


func test_as_1997_sets_every_row_to_the_1997_game() -> void:
	screen.choose_life_rule(AdventurePlayer.LIFE_ONE)
	screen.choose_card_rule(AdventurePlayer.RULE_CLASSIC)
	screen.choose_ban_list(ClassicBans.MODERN)
	screen.choose_card_hold(AdventurePlayer.HOLD_UNLIMITED)
	screen.choose_life_start(AdventurePlayer.START_BASE)
	screen.choose_ascetic(true)
	(_find("As1997") as Button).pressed.emit()
	var s := screen.setup
	assert_eq([s.life_rule, s.card_rule, s.ban_list, s.card_hold, s.sieges, s.creatures, s.life_start, s.ascetic],
		[AdventurePlayer.LIFE_RELOAD, AdventurePlayer.RULE_SHIPPED, ClassicBans.OLD, AdventurePlayer.HOLD_1997,
		AdventurePlayer.SIEGES_1997, AdventurePlayer.CREATURES_HUNT, AdventurePlayer.START_LINKS, false])
	assert_eq((_find("Sieges") as OptionButton).selected, 0, "the rows show it")
	assert_eq((_find("Creatures") as OptionButton).selected, 0)
	assert_eq((_find("CardRule") as OptionButton).selected, 1)
	assert_false((_find("Ascetic") as CheckBox).button_pressed)
	assert_true((_find("BanList") as OptionButton).disabled, "no Classic rule: the list greyed")
	assert_eq((_find("CampaignSummary") as Label).text, "Sieges as 1997 · Creatures hunt · Reload allowed · No card limit")


# ------------------------------------------------------- mouse and keys --

func test_by_the_mouse_and_the_keys() -> void:
	var port := SubViewport.new()
	port.size = Vector2i(1280, 800)
	port.gui_disable_input = false
	port.gui_embed_subwindows = true
	add_child_autofree(port)
	var shown: EmbarkScreen = load("res://game/adventure/embark_screen.tscn").instantiate()
	port.add_child(shown)
	await _frames()
	var button := _find("CampaignSettings", shown) as Button
	await _click(port, button.get_global_rect().get_center())
	assert_true(shown.settings_shown(), "a click opens the window")
	# Clicks under the veil reach nothing: Leave stays.
	await _click(port, (_find("Leave", shown) as Control).get_global_rect().get_center())
	assert_false(shown._leaving, "the screen under it is out of reach: Leave not pressed")
	assert_true(shown.settings_shown())
	var creatures := _find("Creatures", shown) as OptionButton
	var popup := creatures.get_popup()
	await _click(port, creatures.get_global_rect().get_center())
	assert_true(popup.visible, "the list opens")
	var rect := Rect2(Vector2(popup.position), Vector2(popup.size))
	await _click(port, Vector2(rect.get_center().x, rect.position.y + rect.size.y / 4.0))
	assert_eq(shown.setup.creatures, AdventurePlayer.CREATURES_HUNT, "the mouse chose Hunt")
	await _click(port, (_find("Ascetic", shown) as Control).get_global_rect().get_center())
	assert_true(shown.setup.ascetic, "the box ticked")
	# The keys: the first row has the ring; Down walks the rows, the greyed
	# ban list passed over; round from Done to the first row.
	var life_rule := _find("LifeRule", shown) as Control
	life_rule.grab_focus()
	await _frames()
	var walked: Array[String] = []
	for i in 9:
		walked.append(String(port.gui_get_focus_owner().name))
		await _key(port, KEY_DOWN)
	assert_eq(walked, ["LifeRule", "CardRule", "CardHold", "Sieges", "Creatures", "LifeStart", "Ascetic",
		"As1997", "Done"] as Array[String], "the rows, then the buttons")
	assert_eq(String(port.gui_get_focus_owner().name), "LifeRule", "and round again: the ring stays in")
	await _key(port, KEY_UP)
	assert_eq(String(port.gui_get_focus_owner().name), "Done")
	await _key(port, KEY_LEFT)
	assert_eq(String(port.gui_get_focus_owner().name), "As1997")
	shown.choose_card_rule(AdventurePlayer.RULE_CLASSIC)
	(_find("CardRule", shown) as Control).grab_focus()
	await _key(port, KEY_DOWN)
	assert_eq(String(port.gui_get_focus_owner().name), "BanList", "with Classic the ban list is a stop")
	# Enter on a row opens its list; Escape closes the list, then the window.
	(_find("Sieges", shown) as Control).grab_focus()
	await _key(port, KEY_ENTER)
	assert_true((_find("Sieges", shown) as OptionButton).get_popup().visible, "Enter opens the list")
	await _key(port, KEY_ESCAPE)
	assert_false((_find("Sieges", shown) as OptionButton).get_popup().visible, "Escape closes the list")
	assert_true(shown.settings_shown(), "and leaves the window")
	await _key(port, KEY_ESCAPE)
	assert_false(shown.settings_shown(), "Escape is Done")
	assert_eq(port.gui_get_focus_owner(), button, "the ring back on the button")
	assert_true(shown.is_inside_tree(), "Escape did not leave the screen")


# -------------------------------------------------------------- the fit --

func test_the_screen_and_the_window_stay_whole() -> void:
	await _whole(screen, Vector2(1280, 800), "1280 × 800 with the skin as it is", true)
	await _whole(screen, Vector2(1280, 960), "1280 × 960 with the skin as it is", true)
	GameSkin._texture_cache[EmbarkScreen.BACKGROUND_KEY] = null
	GameSkin._texture_cache["stat_buttons"] = null
	GameSkin._font_cache["font_title"] = null
	var bare: EmbarkScreen = load("res://game/adventure/embark_screen.tscn").instantiate()
	add_child_autofree(bare)
	await get_tree().process_frame
	bare.choose_card_rule(AdventurePlayer.RULE_CLASSIC)
	await _whole(bare, Vector2(1280, 800), "1280 × 800 without the art", false)
	await _whole(bare, Vector2(1280, 960), "1280 × 960 without the art", false)


func _whole(on: EmbarkScreen, size: Vector2, how: String, every_column: bool) -> void:
	on.size = size
	await _frames()
	var columns := _find("Columns", on) as Control
	var scroll := columns.get_parent() as ScrollContainer
	if every_column:
		assert_false(scroll.get_v_scroll_bar().visible, "%s: the columns do not scroll" % how)
		assert_lte(columns.get_combined_minimum_size().y, scroll.size.y, "%s: they fit" % how)
	assert_false(scroll.get_h_scroll_bar().visible, "%s: nothing scrolls sideways" % how)
	var magic := _find("MagicPanel", on) as Control
	assert_lte(magic.get_combined_minimum_size().y, scroll.size.y, "%s: the button's column fits" % how)
	var summary := _find("CampaignSummary", on) as Control
	assert_true(magic.get_global_rect().encloses(summary.get_global_rect()), "%s: the line in its window" % how)
	on.open_settings()
	await _frames()
	var window := _find("CampaignSettingsWindow", on) as Control
	assert_true(Rect2(Vector2.ZERO, size).encloses(window.get_global_rect()), "%s: the window on the screen" % how)
	assert_null(_find("BodyScroll", window), "%s: the window does not scroll" % how)
	var done := _find("Done", on) as Control
	assert_true(window.get_global_rect().encloses(done.get_global_rect()), "%s: Done on the stone" % how)
	for base in EmbarkScreen.SETTING_ROWS:
		var row := _find(base + "Row", on) as Control
		assert_true(window.get_global_rect().encloses(row.get_global_rect()), "%s: %s in the window" % [how, base])
		var said := _find(base + "Line", on) as Label
		assert_lte(_width(said), said.size.x + 0.5, "%s: %s's line whole, on one line" % [how, base])
	on.close_settings()
	if on.setup.card_rule == AdventurePlayer.RULE_MEANT:
		assert_lte(_width(summary as Label), summary.size.x + 0.5, "%s: the defaults' line whole" % how)
	else:
		# More than the defaults: cut short with "…" inside its column, the
		# whole in its tooltip.
		assert_eq((summary as Label).text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS, how)


## The width [param label]'s text takes in its own face.
func _width(label: Label) -> float:
	return label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		label.get_theme_font_size("font_size")).x
