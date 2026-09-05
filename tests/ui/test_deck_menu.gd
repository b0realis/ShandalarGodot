extends GutTest
## THE DECK BUILDER'S Q/Esc MENU — its ground, its five entries, its two
## checkboxes, and the key contract around it.
##
## THE GROUND MOVED ON 2026-09-04, one playtest after the window shipped:
## *"Deck builder — window upon Q or Esc key-press: texture makes the text
## unreadable. Change to sand from the main menu!"* It was the blue knot
## the owner had named, lettered pale-with-an-outline because the era's tan
## list colour vanished on the pattern; it is now the sandstone every other
## menu in this game wears, lettered in [constant UiChrome.INK]. Two tests
## below hold the pair together — the ground AND the ink — because moving
## one without the other is how it was unreadable in the first place.
##
## The owner's playtest, 2026-09-04: *"Upon press of Q or Esc you should be
## presented with a blue slab styled menu with: return to main menu, save
## current deck, open existing deck, exit game"*, and then *"Deck builder
## menu on Q or Esc should turn off if you press Q or Esc again. The menu
## should contain also deck builder SFX and music checkboxes, as a user may
## be annoyed by SFX or music while deck building."*
##
## THE TWO THINGS MOST LIKELY TO ROT are pinned hardest, exactly as
## `tests/ui/test_duel_pause.gd` pins them for the duel's own Pause window:
## the Esc PRECEDENCE (Esc is *"just like Cancel"* first and a menu key only
## when there is nothing to cancel), and the promise that no way out of this
## screen throws away a deck without asking.

var screen: DeckBuilderScreen
var _saved: Dictionary = {}


func before_each() -> void:
	CardRegistry.ensure_loaded()
	_saved = {}
	screen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	for key in _saved:
		if _saved[key] == null:
			Settings.clear_value(key)
		else:
			Settings.set_value(key, _saved[key])


func _touch(key: String) -> void:
	if _saved.has(key):
		return
	_saved[key] = Settings.get_value(key, null) if Settings.has_value(key) else null


func _send_key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	screen._unhandled_key_input(ev)


func _walk(node: Node) -> Array:
	var out := [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out


func _menu_texts() -> Array:
	var out := []
	if not screen.is_menu_open():
		return out
	for node in _walk(screen._menu):
		if node is Button and node.text != "":
			out.append(node.text)
	return out


func _press(label: String) -> bool:
	for node in _walk(screen._menu):
		if node is Button and node.text == label:
			(node as Button).pressed.emit()
			return true
	return false


## One switch, by its label — the tick lives in `button_pressed` now.
func _switch(label: String) -> CheckBox:
	for node in _walk(screen._menu):
		if node is CheckBox and (node as CheckBox).text == label:
			return node
	return null


func _dirty_deck() -> void:
	screen.deck.deck_name = "Work In Progress"
	screen._add_one("Mountain")
	assert_true(screen._dirty, "there is unsaved work on the surface")


# ================================================== the window itself --

func test_it_carries_the_owners_four_entries_and_a_way_back() -> void:
	assert_eq(DeckBuilderScreen.MENU_ENTRIES, [
		"Return to deck builder",
		"Save current deck",
		"Open existing deck",
		"Return to main menu",
		"Exit game",
	] as Array[String])
	# The safe one is FIRST, so the reflex Return on an unexpected window
	# goes back to the cards — [DuelPause]'s own rule, and the reason its
	# `RESUME` is action 0.
	assert_eq(DeckBuilderScreen.MENU_ENTRIES[0], DeckBuilderScreen.MENU_BACK)


func test_the_entries_and_the_boxes_are_really_drawn() -> void:
	_send_key(KEY_Q)
	var texts := _menu_texts()
	for label in DeckBuilderScreen.MENU_ENTRIES:
		assert_true(texts.has(label), "the window really shows %s" % label)
	for label in DeckBuilderScreen.MENU_SWITCHES:
		assert_true(texts.has(String(label)),
			"…and the %s box" % label)
		assert_true(_switch(String(label)).button_pressed,
			"…ticked, and the tick is a STATE now and not a prefix")


func test_it_is_the_main_menus_sandstone_and_not_the_blue_knot() -> void:
	# THE PLAYTEST THAT MOVED IT, 2026-09-04: *"Deck builder — window upon
	# Q or Esc key-press: texture makes the text unreadable. Change to sand
	# from the main menu!"* The window shipped on `panel_knot`
	# (`Winbk_Changetext.pic`, the blue celtic knot the owner had named)
	# and the pale-with-an-outline lettering that ground forced was still
	# unreadable — so the GROUND moved to the one the main menu, the
	# Options screen, the Help screen and `UiChrome.explain_popup` share:
	# `Winbk_Options` sandstone, [method UiChrome.stone_panel]'s own art.
	assert_eq(DeckBuilderScreen.MENU_PANEL, "panel_stone")
	assert_true(OriginalDialog.PANELS.has(DeckBuilderScreen.MENU_PANEL))
	_send_key(KEY_Q)
	assert_true(screen.is_menu_open())
	var art := GameSkin.texture(DeckBuilderScreen.MENU_PANEL)
	if art == null:
		# No original art: the fallback must still be LIGHT, or the dark
		# ink below would sit on a dark face. That is what
		# `_seat_on_sandstone` is for.
		var faces := 0
		for node in screen._menu.get_children():
			if node is Panel:
				faces += 1
				var box: StyleBox = (node as Panel).get_theme_stylebox("panel")
				assert_true(box is StyleBoxFlat, "the flat fallback")
				assert_eq((box as StyleBoxFlat).bg_color, UiChrome.FACE,
					"and it is UiChrome's sandstone, not the dark box")
		assert_eq(faces, 1)
		return
	var grounds := 0
	for node in screen._menu.get_children():
		if node is NinePatchRect and (node as NinePatchRect).texture == art:
			grounds += 1
	assert_eq(grounds, 1, "the window wears the main menu's sandstone itself")
	assert_ne(art, GameSkin.texture("panel_knot"),
		"and the knot is really gone")
	# It is the very texture the main menu's own panels are cut from.
	var chrome := UiChrome.stone_panel()
	assert_true(chrome is StyleBoxTexture, "the skin is up")
	assert_eq((chrome as StyleBoxTexture).texture, art,
		"one ground for every sandstone window in the game")


func test_every_line_is_dark_ink_and_nothing_is_pale() -> void:
	# THE HALF THE MOVE WOULD BE WORTHLESS WITHOUT. A pale letter on
	# sandstone is the exact bug the first exported build was playtested
	# for — *"all white text is unreadable on sand-colored menu boxes"* —
	# and this window carried the pale voice BECAUSE the knot forced it.
	# It had to go with the knot.
	_send_key(KEY_Q)
	for node in _walk(screen._menu):
		if node is Button and (node as Button).text != "":
			var line := node as Button
			assert_eq(line.get_theme_color("font_color"), UiChrome.INK,
				"'%s' is dark ink" % line.text)
			assert_eq(line.get_theme_color("font_shadow_color"), UiChrome.SEAT,
				"…on the pale seat, not a hard black shadow")
			assert_eq(line.get_theme_constant("outline_size"), 0,
				"…and the knot's outline is gone")
			assert_eq(line.get_theme_color("font_hover_color"),
				UiChrome.ACCENT, "the pointer emphasises rather than lightens")
		if node is Label:
			var head := node as Label
			assert_eq(head.get_theme_color("font_color"), UiChrome.ACCENT,
				"the heading is the emphasis colour")
			assert_ne(head.get_theme_color("font_color"),
				OriginalDialog.HIGHLIGHT, "and never the pale voice")


func test_the_window_still_names_itself() -> void:
	# The title moved from [method OriginalDialog.create]'s own title line
	# (which letters itself pale, for the dark grounds) into the body. It
	# is still there, and a player who reached this window by accident can
	# still see which screen they are on.
	_send_key(KEY_Q)
	var headings := 0
	for node in _walk(screen._menu):
		if node is Label and (node as Label).text == DeckBuilderScreen.MENU_TITLE:
			headings += 1
	assert_eq(headings, 1, "'%s', once" % DeckBuilderScreen.MENU_TITLE)


func test_every_line_fits_inside_the_slab() -> void:
	# The mini-menu shipped at a fixed height once and put its last two
	# entries under the Cancel button. Seven lines is what this one holds.
	_send_key(KEY_Q)
	var panel := screen._menu.get_global_rect()
	var lines := 0
	for node in _walk(screen._menu):
		if node is Button and node.text != "":
			lines += 1
			assert_true(panel.encloses((node as Button).get_global_rect()),
				"'%s' is inside the panel" % (node as Button).text)
	assert_eq(lines, DeckBuilderScreen.MENU_ENTRIES.size()
		+ DeckBuilderScreen.MENU_SWITCHES.size(),
		"five entries and two boxes, and nothing else")


func test_it_is_modal_against_the_screen_behind_it() -> void:
	# [OriginalDialog] draws no blocker of its own, so a click that MISSED
	# the panel used to land on the cards underneath — with the menu up you
	# could still right-click a column out of the deck.
	_send_key(KEY_Q)
	var scrims := 0
	for node in screen.get_children():
		if node is Control and node.name == "DialogScrim":
			scrims += 1
			assert_eq((node as Control).mouse_filter, Control.MOUSE_FILTER_STOP)
			assert_lt((node as Control).z_index, screen._menu.z_index,
				"under the window and over everything else")
	assert_eq(scrims, 1)


func test_no_shortcut_reaches_the_screen_behind_it() -> void:
	# Modal in spirit as well as against the mouse: the scrim stops a
	# click, and nothing must let a Ctrl-key shortcut walk under the
	# window and act on the deck it is asking about. (This is the hole
	# `_confirm_discard` found the hard way in the third audit pass — a
	# button that still held focus answered the space bar under a prompt.)
	screen._add_one("Mountain")
	_send_key(KEY_Q)
	assert_true(screen.is_menu_open())
	for code in [KEY_N, KEY_S, KEY_O, KEY_Z, KEY_L, KEY_E]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.pressed = true
		ev.ctrl_pressed = true
		screen._unhandled_key_input(ev)
	assert_true(screen.is_menu_open(), "still the only thing up")
	assert_eq(screen.deck.count_of("Mountain"), 1,
		"New deck did not empty the surface under the menu")


func test_the_first_entry_holds_the_focus() -> void:
	_send_key(KEY_Q)
	var focused := screen.get_viewport().gui_get_focus_owner()
	assert_not_null(focused, "something has the keyboard")
	if focused is Button:
		assert_eq((focused as Button).text, DeckBuilderScreen.MENU_BACK,
			"and it is the harmless one")


# ====================================================== the two keys --

func test_q_opens_it() -> void:
	assert_false(screen.is_menu_open())
	_send_key(KEY_Q)
	assert_true(screen.is_menu_open())
	assert_not_null(screen._menu)


func test_q_closes_it_again() -> void:
	# *"Deck builder menu on Q or Esc should turn off if you press Q or Esc
	# again."*
	_send_key(KEY_Q)
	assert_true(screen.is_menu_open())
	_send_key(KEY_Q)
	assert_false(screen.is_menu_open(), "the same key toggles it shut")


func test_escape_opens_it_when_there_is_nothing_to_cancel() -> void:
	assert_eq(screen.open_dialogs().size(), 0, "nothing pending")
	assert_eq(screen.filter.text, "", "and nothing typed")
	_send_key(KEY_ESCAPE)
	assert_true(screen.is_menu_open())


func test_escape_closes_what_q_opened() -> void:
	_send_key(KEY_Q)
	_send_key(KEY_ESCAPE)
	assert_false(screen.is_menu_open())


func test_escape_cancels_a_dialog_first_and_never_opens_the_menu() -> void:
	# THE PRECEDENCE. *"Esc is just like clicking the Cancel button"*
	# (manual p.116), and a player who opened Stats and pressed Esc wants
	# Stats gone, not a menu on top of it.
	screen._run_command("Stats")
	assert_eq(screen.open_dialogs().size(), 1, "the window is up")
	_send_key(KEY_ESCAPE)
	await get_tree().process_frame
	assert_false(screen.is_menu_open(),
		"Esc spent itself on the dialog, not on the menu")
	assert_eq(screen.open_dialogs().size(), 0, "and the dialog came down")
	# ...and only NOW does the same key reach the menu.
	_send_key(KEY_ESCAPE)
	assert_true(screen.is_menu_open())


func test_escape_clears_the_type_ahead_first_and_never_opens_the_menu() -> void:
	# The other pending thing on this screen is a field holding the
	# keyboard — the [QoL] middle step of the ladder, which Esc must not
	# walk past any more than it walks past a dialog.
	screen.filter.text = "bolt"
	screen._filter_bar.search_field.text = "bolt"
	screen._refresh_inventory()
	_send_key(KEY_ESCAPE)
	assert_false(screen.is_menu_open(), "the box was in the way")
	assert_eq(screen.filter.text, "", "and it emptied")
	_send_key(KEY_ESCAPE)
	assert_true(screen.is_menu_open(), "now there is nothing in the way")


func test_q_is_unconditional_and_hands_back_what_it_covered() -> void:
	# Q carries no 1997 duty on this screen at all, so unlike Esc it does
	# not queue behind a dialog — it opens OVER one, on its own layer, and
	# closing it gives the dialog back untouched.
	screen._run_command("Stats")
	assert_eq(screen.open_dialogs().size(), 1)
	_send_key(KEY_Q)
	assert_true(screen.is_menu_open(), "Q opened anyway")
	assert_gt(screen._menu.z_index, 200,
		"on a layer above the dialog it covered")
	_send_key(KEY_Q)
	await get_tree().process_frame
	assert_false(screen.is_menu_open())
	assert_eq(screen.open_dialogs().size(), 1, "Stats is still there")


func test_a_held_key_does_not_flicker_the_menu() -> void:
	# An auto-repeat would toggle it sixty times a second.
	_send_key(KEY_Q)
	var echo := InputEventKey.new()
	echo.keycode = KEY_Q
	echo.pressed = true
	echo.echo = true
	for _i in 5:
		screen._unhandled_key_input(echo)
	assert_true(screen.is_menu_open(), "still open, and open once")


# ================================================= nothing is lost ==

func test_return_to_main_menu_asks_before_it_throws_work_away() -> void:
	# *"the entry that leaves without saving must not lose work silently."*
	_dirty_deck()
	_send_key(KEY_Q)
	assert_true(_press("Return to main menu"))
	assert_false(screen.is_menu_open(), "the menu came down")
	assert_eq(screen.open_dialogs().size(), 1, "…and @SAVE went up")
	var asked := false
	for node in _walk(screen.open_dialogs()[0]):
		if node is Label and String((node as Label).text).contains("save"):
			asked = true
	assert_true(asked, "'Do you wish to save %s?'")


func test_exit_game_asks_too() -> void:
	# Quitting is the one action with no undo at all.
	_dirty_deck()
	_send_key(KEY_Q)
	assert_true(_press("Exit game"))
	assert_eq(screen.open_dialogs().size(), 1,
		"@SAVE stands between the deck and the process ending")


func test_leaving_asks_about_every_slot_and_not_just_this_one() -> void:
	# The slots let a player keep three decks in hand; a way out that only
	# looked at the one on the surface would drop the other two.
	screen._add_one("Mountain")
	screen.deck.deck_name = "Slot One"
	screen._switch_slot(1)
	screen._add_one("Forest")
	screen.deck.deck_name = "Slot Two"
	assert_eq(screen._unsaved_slots().size(), 2, "two slots hold work")
	_send_key(KEY_Q)
	assert_true(_press("Return to main menu"))
	assert_eq(screen.open_dialogs().size(), 1, "it asks about the first")


func test_an_untouched_deck_leaves_without_a_word() -> void:
	assert_false(screen._dirty)
	assert_eq(screen._unsaved_slots().size(), 0)
	_send_key(KEY_Q)
	assert_true(_press("Return to main menu"))
	assert_eq(screen.open_dialogs().size(), 0,
		"nothing to save, nothing to ask")


func test_save_current_deck_runs_the_save() -> void:
	# An unnamed deck cannot be saved, and the 1997 answer is to send the
	# player to Deck Info for a name rather than to drop the command.
	screen._add_one("Mountain")
	_send_key(KEY_Q)
	assert_true(_press("Save current deck"))
	assert_false(screen.is_menu_open())
	assert_eq(screen.open_dialogs().size(), 1, "Deck Info opened for a name")
	assert_string_contains(screen._status_label.text, "name")


func test_open_existing_deck_opens_the_load_list() -> void:
	_send_key(KEY_Q)
	assert_true(_press("Open existing deck"))
	assert_false(screen.is_menu_open())
	assert_eq(screen.open_dialogs().size(), 1)
	var listed := 0
	for node in _walk(screen.open_dialogs()[0]):
		if node is Button and String((node as Button).text).contains(" cards · "):
			listed += 1
	assert_gt(listed, 0, "and it is the deck list, not something else")


func test_return_to_deck_builder_just_closes_it() -> void:
	_dirty_deck()
	_send_key(KEY_Q)
	assert_true(_press(DeckBuilderScreen.MENU_BACK))
	assert_false(screen.is_menu_open())
	assert_eq(screen.open_dialogs().size(), 0, "nothing was asked")
	assert_true(screen._dirty, "and nothing was thrown away")


# ============================================ the two checkboxes ==

func test_the_boxes_are_this_screens_own_and_not_the_global_pair() -> void:
	# The mini-menu's `Music` / `Sound Effects` are the 1997 GAME-WIDE
	# switches. These two are the Deck Builder's, and confusing them would
	# silence a duel from a deck-builder menu.
	assert_eq(DeckBuilderScreen.MENU_SWITCHES.values(),
		[DeckAudio.MUSIC_SETTING, DeckAudio.SFX_SETTING])
	for key in DeckBuilderScreen.MENU_SWITCHES.values():
		assert_false(DeckBuilderScreen.CHECKED_COMMANDS.values().has(key),
			"%s is not one of the global keys" % key)


func test_a_box_ticks_and_unticks_in_place() -> void:
	_touch(DeckAudio.SFX_SETTING)
	_send_key(KEY_Q)
	var label := "Deck builder sound effects"
	assert_true(_switch(label).button_pressed, "on to begin with")
	assert_true(_press(label))
	assert_true(screen.is_menu_open(), "the menu stays up — it is a setting")
	assert_false(_switch(label).button_pressed, "and the tick came off")
	assert_false(DeckAudio.sfx_on())
	assert_true(_press(label))
	assert_true(DeckAudio.sfx_on(), "…and back on")


func test_unticking_sfx_silences_the_next_filter_press() -> void:
	# *"They must take effect immediately, not at the next screen."*
	_touch(DeckAudio.SFX_SETTING)
	_touch("sound_enabled")
	Settings.clear_value("sound_enabled")
	_send_key(KEY_Q)
	assert_true(_press("Deck builder sound effects"))
	_send_key(KEY_Q)          # close it again
	screen._audio.recent.clear()
	screen._filter_bar.group_buttons("Type Filters")[0].pressed.emit()
	assert_eq(screen._audio.recent.size(), 0, "the grind is gone at once")


func test_unticking_music_stops_the_bed_at_once() -> void:
	_touch(DeckAudio.MUSIC_SETTING)
	_send_key(KEY_Q)
	assert_true(_press("Deck builder music"))
	assert_false(DeckAudio.music_on())
	assert_eq(screen._music.tracks.size(), 0, "the player is holding nothing")
	assert_false(screen._music.playing)


# ------------------------------------- buttons and switches, not text --
#
# The window shipped as a list of clickable LINES: dark ink on the bare
# panel, and the two settings spelled their state into their own label as
# "[x] " / "[  ] ". The owner drove it and said what it was:
#
#   *"In the deck editor, Q or Esc menu only has clickable text. Make that
#   GUI composed of buttons and of switches — more beautiful, and centered
#   in the GUI window."* (2026-09-04)
#
# So an entry is now [method OriginalDialog.button] — the era's OWN dialog
# button art, `button_normal/pressed/disabled`, the face every 1997 dialog
# wears — and a switch is a real [CheckBox] whose tick is drawn by
# [method UiChrome.check_icon], because the original shipped no checkbox
# sprite at all (it expressed a switch as a line of text in a list that
# redrew, which is exactly what this window was doing).


func _entries() -> Array[Button]:
	var out: Array[Button] = []
	for node in _walk(screen._menu):
		if node is Button and not node is CheckBox and node.text != "":
			out.append(node)
	return out


func test_every_entry_is_a_real_button_and_not_a_bare_line() -> void:
	_send_key(KEY_Q)
	var entries := _entries()
	assert_eq(entries.size(), DeckBuilderScreen.MENU_ENTRIES.size(),
		"five entries")
	for entry in entries:
		var box := entry.get_theme_stylebox("normal")
		assert_false(box is StyleBoxEmpty,
			"'%s' is drawn as a button, not as text" % entry.text)
		if GameSkin.texture("button_normal") != null:
			assert_true(box is StyleBoxTexture,
				"'%s' wears the era's own button art" % entry.text)
		else:
			assert_true(box is StyleBoxFlat,
				"'%s' keeps the button SHAPE with no skin" % entry.text)


func test_a_switch_is_a_checkbox_with_a_drawn_tick() -> void:
	_send_key(KEY_Q)
	for label in DeckBuilderScreen.MENU_SWITCHES:
		var box := _switch(String(label))
		assert_not_null(box, "%s is a CheckBox" % label)
		var on := box.get_theme_icon("checked")
		var off := box.get_theme_icon("unchecked")
		assert_not_null(on, "…with a tick of our own")
		assert_ne(on, off, "…and the two states are different pictures")
		assert_eq(on.get_size(), off.get_size(),
			"…the same size, so the label cannot shift as it ticks")


func test_the_tick_is_drawn_in_the_panels_own_colours() -> void:
	# The box is ours, so it can only be checked against the palette it
	# was drawn from — otherwise a future palette change leaves a switch
	# in last year's colours on this year's panel.
	var image := UiChrome.check_icon(true).get_image()
	var found := false
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).is_equal_approx(UiChrome.ACCENT):
				found = true
	assert_true(found, "the tick is ACCENT")
	assert_true(image.get_pixel(0, 0).is_equal_approx(UiChrome.INK),
		"the rule around it is INK")
	assert_true(image.get_pixel(4, 2).is_equal_approx(UiChrome.CHECK_WELL),
		"and the well is the sandstone's own light")


func test_everything_is_centred_in_the_window() -> void:
	# *"…and centered in the GUI window."* Measured against the PANEL's
	# centre, not the screen's: the window is the thing being composed.
	_send_key(KEY_Q)
	# A RECT IS A LIE UNTIL THE FRAME RUNS. The window is built and shown
	# inside the key handler, so every child still carries its pre-layout
	# position until the tree has sorted the containers once.
	await get_tree().process_frame
	await get_tree().process_frame
	var middle := screen._menu.get_global_rect().get_center().x
	for entry in _entries():
		assert_almost_eq(entry.get_global_rect().get_center().x, middle, 1.0,
			"'%s' is centred" % entry.text)
	# The two switches are centred AS A PAIR, which is why their boxes
	# share a left edge — centred one by one, each shrinks to its own
	# label and the shorter one's tick sits 30px right of the other's.
	var lefts := []
	for label in DeckBuilderScreen.MENU_SWITCHES:
		lefts.append(_switch(String(label)).get_global_rect().position.x)
	assert_almost_eq(float(lefts[0]), float(lefts[1]), 1.0,
		"the tick boxes line up with each other")


func test_the_entries_all_share_one_width() -> void:
	_send_key(KEY_Q)
	await get_tree().process_frame
	await get_tree().process_frame
	for entry in _entries():
		assert_almost_eq(entry.size.x, DeckBuilderScreen.SLAB_ENTRY.x, 1.0,
			"'%s' is the column's width, not its label's" % entry.text)
