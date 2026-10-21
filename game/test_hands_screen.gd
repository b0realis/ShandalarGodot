class_name TestHandsScreen
extends Control
## TEST HANDS — Magic Battle's bench for trying a combo (2026-10-19,
## `[QoL]`, ours: the 1997 game had nothing like it, and s30 has nothing
## either). The owner: *"design a tool to start a duel with two predefined
## hands besides decks so a player can instantly test a combo. Maybe add to
## the bottom of the duel menu - test hand(s) button ? - where you select
## the cards (from selected decks) in hand for you and opponent (it can be
## random hand), select cards on table (tapped or not for each) and then
## selects whose turn it is and upon "go test" button you are instant in
## the turn … If i forgot anything add, implemnt improve…"*
##
## WHAT IT SETS, per seat: the HAND (cards chosen from the seat's deck,
## plus any number of random cards off the rest of it), the TABLE (each
## permanent tapped or not, and — for a creature — summoning sick or not,
## not by default so the combo can be tried at once), the GRAVEYARD (Corpse
## Dance and Recurring Nightmare want a creature there; the last card added
## is on top), the TOP OF THE LIBRARY (next draw first) and the LIFE total;
## for the duel, whose turn it is and the step it begins in (the first main
## phase unless the player chooses otherwise). All of it is one
## [DuelPosition]; `Go test!` hands it to the duel screen inside a
## [DuelConfig] ([method DuelConfig.for_test]) and the engine builds the
## table ([method MtgGame.begin_from_position]).
##
## THE DECK IS THE DEFAULT, THE POOL IS ONE TICK AWAY. The card picker
## lists the seat's own deck with the copies it has left; `Any card in the
## pool` lists every card the enabled packs hold. A card the deck has no
## copy of left is an EXTRA: it is marked `(not in deck)` on the seat's
## list, and the engine adds it to that seat's cards for the test. The
## rest of the library is the rest of the deck.
##
## WHAT THE MAGIC BATTLE SCREEN CHOSE STANDS: who sits in each seat (you,
## the computer at its difficulty, or both — Hotseat and AI Demo work the
## same), the decks (`<random deck>` already drawn by the seed), the names
## and the format. This screen adds the position and nothing else, and
## `Back` returns there.
##
## REMEMBERED AT `Go test!` AND NOWHERE ELSE — the Magic Battle screen's own
## rule ([method SetupScreen._remember_choices]): the position and `Show
## both hands` under one [Settings] key, [constant LAST_KEY], read back the
## next time this screen opens. SAVED TESTS are named copies of the same
## thing under [constant SAVED_KEY], written by `Save` and `Delete` only. A
## test duel itself records NOTHING — see [method DuelConfig.for_test] and
## the duel screen's `_begin_test`.
##
## LOCAL ONLY. An SGManalink table builds its games on the host from the
## lobby's own messages ([SgDuelView] never runs the local duel's setup),
## and nothing on that path reads a position.

## Where the last test is remembered, and the named ones saved.
const LAST_KEY := "test_hands_last"
const SAVED_KEY := "test_hands_saved"
## The longest name a saved test takes.
const NAME_MAX := 40

## The steps a test may begin in, as the step picker words them, in
## [constant DuelPosition.STEPS] order.
const STEP_LABELS := {
	Mtg.Step.UPKEEP: "Upkeep",
	Mtg.Step.DRAW: "Draw step",
	Mtg.Step.MAIN1: "First main phase",
	Mtg.Step.COMBAT_BEGIN: "Beginning of combat",
	Mtg.Step.MAIN2: "Second main phase",
	Mtg.Step.END: "End step",
}

## Each place's heading on a seat's column, and the one line under it that
## says how it reads.
const ZONE_TITLES := {
	DuelPosition.HAND: "Hand",
	DuelPosition.TABLE: "On the table",
	DuelPosition.GRAVEYARD: "Graveyard",
	DuelPosition.LIBRARY_TOP: "Top of the library",
}
const ZONE_HINTS := {
	DuelPosition.HAND: "",
	DuelPosition.TABLE: "",
	DuelPosition.GRAVEYARD: "The last card added is on top.",
	DuelPosition.LIBRARY_TOP: "The first card is the next draw.",
}
## The mark on a seat's row for a card the deck has no copy of left.
const EXTRA_MARK := "(not in deck)"
## How many rows the picker lists at once from the whole pool: more is a
## list nobody reads, and a few thousand rows rebuilt on every letter typed
## is a pause a handheld feels.
const POOL_ROWS := 400
## The settings panel's floor and the breathing room around it — the
## Magic Battle screen's numbers, the two screens being one room apart.
const PANEL_WIDTH := 760.0
const PANEL_MARGIN := 12.0
## One seat column's floor.
const SEAT_WIDTH := 450.0

## The duel the Magic Battle screen chose: seats, decks, pilots, names. A
## config that carries a position (back from a test duel's `Edit test`)
## opens this screen on that position.
var config: DuelConfig = null
## The position being built. (Not `position`: that is every Control's
## place on the screen.)
var test_position := DuelPosition.new()
## `Show both hands` ([member DuelConfig.open_hands]).
var open_hands := true

## Per seat: card name -> copies in the deck.
var _deck_counts: Array[Dictionary] = [{}, {}]
var _panel: Control
var _panel_content: Control
var _action_row: Control
## Per seat: the life and random-card spins, and the column the place
## lists are rebuilt into.
var _life_spins: Array[SpinBox] = []
var _random_spins: Array[SpinBox] = []
var _seat_lists: Array[VBoxContainer] = []
var _library_notes: Array[Label] = []
## Per seat: place -> its `+ Add` button (where the focus goes back to).
var _add_buttons: Array[Dictionary] = [{}, {}]
var _turn_buttons: Array[Button] = []
var _step_option: OptionButton
var _open_hands_check: CheckBox
var _saved_option: OptionButton
var _save_name: LineEdit
var _note: Label
var _go_button: Button
## `Go test!` or `Back` has been pressed: the screen is on its way out and
## presses do nothing (the setup screen's `_leaving`).
var _leaving := false

## The card picker while it is up, and what it adds to.
var _picker: OriginalDialog = null
var _picker_pid := 0
var _picker_zone := DuelPosition.HAND
var _picker_search: LineEdit
var _picker_any: CheckBox
var _picker_list: ItemList
var _picker_preview: CardPreview

## The test duel is up: this screen handed it the tree. For a host that is
## not the scene tree (a test), which then owns it.
signal test_started(duel: Control)


func _ready() -> void:
	if config == null:
		# A scene run on its own (F6): the computer at Wizard with the two
		# starter decks, so the screen has seats to show.
		config = DuelConfig.vs_ai_default(AiProfile.wizard())
	CardRegistry.ensure_loaded()
	for pid in 2:
		var counts := {}
		for card_name in config.decks[pid]:
			counts[String(card_name)] = int(counts.get(String(card_name), 0)) + 1
		_deck_counts[pid] = counts
	_open_on()
	_build_ui()
	_refresh_all()
	# The shell's bed carries into this room as it does into Magic Battle's
	# (and comes back on after a test duel stopped it); the duel stops it.
	var music := get_node_or_null(^"/root/ShellMusic")
	if music != null:
		music.call(&"play")
	_go_button.grab_focus()


## WHICH POSITION THE SCREEN OPENS ON: the test duel's own when it came
## back from one (`Edit test`, the end of a test); else the last one
## played ([constant LAST_KEY]); else a fresh one — the Magic Battle
## screen's starting lives, nothing chosen, and the computer's seat (or
## the second seat) holding a random hand of seven.
func _open_on() -> void:
	if config.position != null:
		test_position = config.position.duplicate_position()
		open_hands = config.open_hands
		return
	var remembered: Variant = Settings.get_value(LAST_KEY, {})
	if remembered is Dictionary and not (remembered as Dictionary).is_empty():
		_take(remembered)
		return
	test_position = _fresh()


## A fresh position for these seats ([method _open_on]).
func _fresh() -> DuelPosition:
	var out := DuelPosition.new()
	for pid in 2:
		out.lives[pid] = clampi(config.lives[pid], 1, DuelPosition.MAX_LIFE)
	out.random_cards[1] = 7
	return out


## Read a remembered or saved test — `{"position": …, "open_hands": …}`.
func _take(saved: Dictionary) -> void:
	test_position = DuelPosition.from_dict(saved.get("position", {}))
	var shown: Variant = saved.get("open_hands", true)
	open_hands = shown if shown is bool else true


## What [constant LAST_KEY] and a saved test hold.
func _as_saved() -> Dictionary:
	return {"position": test_position.to_dict(), "open_hands": open_hands}


# ================================================================ the build --

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var backdrop := GameSkin.texture("versus_background")
	if backdrop != null:
		var bg := TextureRect.new()
		bg.texture = backdrop
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
	else:
		var flat := ColorRect.new()
		flat.color = Color(0.09, 0.08, 0.07)
		flat.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(flat)

	# THE MAGIC BATTLE SCREEN'S PANEL: anchored at the centre, as big as
	# its content or the window allows, the settings scrolling and the
	# buttons that leave pinned under them ([method SetupScreen._fit_panel]).
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 10)
	inside.add_child(scroll)
	inside.add_child(_build_action_row())
	var panel := UiChrome.panel_around(inside, 16.0)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	_panel = panel
	_panel_content = content
	resized.connect(_fit_panel)
	content.minimum_size_changed.connect(_fit_panel)

	var title := UiChrome.body_label("Test hands", 26)
	var title_font := GameSkin.font("font_title")
	if title_font != null:
		title.add_theme_font_override("font", title_font)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	var seats := HBoxContainer.new()
	seats.add_theme_constant_override("separation", 14)
	for pid in 2:
		seats.add_child(UiChrome.panel_around(_build_seat(pid), 10.0))
	content.add_child(seats)
	content.add_child(_build_turn_row())
	_open_hands_check = CheckBox.new()
	_open_hands_check.text = "Show both hands"
	_open_hands_check.tooltip_text = "Both hands lie open on the table during the test, the computer's too. You built them, so there is nothing to hide; the computer still plays only on what it may see."
	UiChrome.shadowed_button(_open_hands_check)
	_open_hands_check.toggled.connect(func(on: bool) -> void: open_hands = on)
	content.add_child(_open_hands_check)
	content.add_child(_build_saved_row())
	_note = UiChrome.body_label("", 13)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size.x = 2.0 * SEAT_WIDTH
	content.add_child(_note)
	_fit_panel()


## One seat's column: who and with what, the life total, then the four
## places — each with its `+ Add` and `Clear`, its rows, and for the hand
## the random cards on top of the chosen ones.
func _build_seat(pid: int) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.custom_minimum_size.x = SEAT_WIDTH
	var who := UiChrome.body_label("Seat %d — %s" % [pid + 1, config.player_names[pid]], 17)
	who.clip_text = true
	column.add_child(who)
	var deck_name := String(config.deck_names[pid])
	var deck_line := UiChrome.body_label("%s · %d cards · %s" % [
		deck_name if deck_name != "" else "Deck", config.decks[pid].size(),
		_pilot_word(pid)], 13)
	deck_line.clip_text = true
	column.add_child(deck_line)
	var life_row := HBoxContainer.new()
	life_row.add_theme_constant_override("separation", 8)
	life_row.add_child(UiChrome.body_label("Life:"))
	var life := SpinBox.new()
	life.min_value = 1
	life.max_value = DuelPosition.MAX_LIFE
	life.value_changed.connect(func(value: float) -> void:
		test_position.lives[pid] = int(value))
	life_row.add_child(life)
	_life_spins.append(life)
	column.add_child(life_row)
	var lists := VBoxContainer.new()
	lists.add_theme_constant_override("separation", 4)
	column.add_child(lists)
	_seat_lists.append(lists)
	var random_row := HBoxContainer.new()
	random_row.add_theme_constant_override("separation", 8)
	random_row.add_child(UiChrome.body_label("Random cards in hand:"))
	var random := SpinBox.new()
	random.min_value = 0
	random.max_value = DuelPosition.MAX_RANDOM
	random.tooltip_text = "Cards dealt at random from the rest of the library, on top of the hand chosen above."
	random.value_changed.connect(func(value: float) -> void:
		test_position.random_cards[pid] = int(value)
		_refresh_library_note(pid))
	random_row.add_child(random)
	_random_spins.append(random)
	column.add_child(random_row)
	var library_note := UiChrome.body_label("", 13)
	_library_notes.append(library_note)
	column.add_child(library_note)
	return column


## Who pilots a seat, in the Magic Battle screen's words.
func _pilot_word(pid: int) -> String:
	if config.is_ai(pid):
		return "the computer (%s)" % String(config.pilots[pid].profile_name)
	return "you" if config.is_ai(1 - pid) else "a player at this screen"


## `Whose turn:` — two toggles, gold on the chosen one (the Magic Battle
## screen's mode row) — and `Begins in:`, the step.
func _build_turn_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UiChrome.body_label("Whose turn:"))
	var group := ButtonGroup.new()
	for pid in 2:
		var button := Button.new()
		button.text = "Seat %d · %s" % [pid + 1, config.player_names[pid]]
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(170, 34)
		button.clip_text = true
		UiChrome.gold_when_chosen(button)
		button.toggled.connect(func(on: bool) -> void:
			if on:
				test_position.active_player = pid
				_refresh_note())
		row.add_child(button)
		_turn_buttons.append(button)
	row.add_child(UiChrome.body_label("  Begins in:"))
	_step_option = OptionButton.new()
	for step in DuelPosition.STEPS:
		_step_option.add_item(String(STEP_LABELS[step]))
		_step_option.set_item_metadata(_step_option.item_count - 1, step)
	_step_option.tooltip_text = "The step of that player's turn the test begins in. Nothing before it happens: no untap, no draw."
	_step_option.item_selected.connect(func(index: int) -> void:
		test_position.step = int(_step_option.get_item_metadata(index))
		_refresh_note())
	row.add_child(_step_option)
	return row


## `Saved tests:` — the named tests, `Load` and `Delete`, and a name to
## `Save` this one under.
func _build_saved_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UiChrome.body_label("Saved tests:"))
	_saved_option = OptionButton.new()
	_saved_option.custom_minimum_size.x = 200
	_saved_option.fit_to_longest_item = false
	_saved_option.clip_text = true
	row.add_child(_saved_option)
	var load_button := UiChrome.menu_button("Load", Vector2(80, 32), 16)
	load_button.name = "LoadTest"
	load_button.pressed.connect(_load_saved)
	row.add_child(load_button)
	var delete := UiChrome.menu_button("Delete", Vector2(86, 32), 16)
	delete.name = "DeleteTest"
	delete.pressed.connect(_delete_saved)
	row.add_child(delete)
	_save_name = LineEdit.new()
	_save_name.placeholder_text = "name this test"
	_save_name.max_length = NAME_MAX
	_save_name.custom_minimum_size.x = 170
	_save_name.text_submitted.connect(func(_text: String) -> void: _save_current())
	row.add_child(_save_name)
	var save := UiChrome.menu_button("Save", Vector2(80, 32), 16)
	save.name = "SaveTest"
	save.pressed.connect(_save_current)
	row.add_child(save)
	return row


## `Back` / `Clear all` / `Go test!`, pinned under the scroller.
func _build_action_row() -> Control:
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	var back := UiChrome.menu_button("Back", Vector2(180, 42))
	back.name = "Back"
	back.pressed.connect(_go_back)
	buttons.add_child(back)
	var clear := UiChrome.menu_button("Clear all", Vector2(180, 42))
	clear.name = "ClearAll"
	clear.tooltip_text = "Start this test again from nothing: no cards chosen, the starting lives, a random hand of seven for the second seat."
	clear.pressed.connect(_clear_all)
	buttons.add_child(clear)
	_go_button = UiChrome.menu_button("Go test!", Vector2(180, 42))
	_go_button.name = "GoTest"
	_go_button.tooltip_text = "Start the duel in the chosen turn and step: no coin toss, no mulligan."
	_go_button.pressed.connect(go_test)
	buttons.add_child(_go_button)
	_action_row = buttons
	return buttons


## The Magic Battle screen's own fit ([method SetupScreen._fit_panel]).
func _fit_panel() -> void:
	if _panel == null or _panel_content == null:
		return
	var wanted := _panel_content.get_combined_minimum_size() + Vector2(32.0, 32.0)
	if _action_row != null:
		wanted.y += _action_row.get_combined_minimum_size().y + 10.0
	var room := size - Vector2(2.0 * PANEL_MARGIN, 2.0 * PANEL_MARGIN)
	var width: float = clampf(wanted.x, minf(PANEL_WIDTH, room.x), room.x)
	var height: float = minf(wanted.y, room.y)
	_panel.offset_left = -width * 0.5
	_panel.offset_right = width * 0.5
	_panel.offset_top = -height * 0.5
	_panel.offset_bottom = height * 0.5


# ============================================================ the refreshes --

## Every control from [member test_position] — after a load, a clear, an open.
func _refresh_all() -> void:
	for pid in 2:
		_life_spins[pid].set_value_no_signal(test_position.lives[pid])
		_random_spins[pid].set_value_no_signal(test_position.random_cards[pid])
		_refresh_seat(pid)
		_turn_buttons[pid].set_pressed_no_signal(test_position.active_player == pid)
	for i in _step_option.item_count:
		if int(_step_option.get_item_metadata(i)) == test_position.step:
			_step_option.select(i)
	_open_hands_check.set_pressed_no_signal(open_hands)
	_refresh_saved()
	_refresh_note()


## One seat's four places, rebuilt from [member test_position]. A row is a
## card's name — marked when it is an extra — and its × ; a table row has
## `Tapped`, and a creature's `Sick` too.
func _refresh_seat(pid: int) -> void:
	var lists := _seat_lists[pid]
	for child in lists.get_children():
		lists.remove_child(child)
		child.queue_free()
	_add_buttons[pid] = {}
	# Extras are the copies past the deck's count, IN THE ENGINE'S ORDER:
	# it takes the deck's copies for the places in [constant
	# DuelPosition.ZONES] order and makes the rest.
	var used := {}
	for zone in DuelPosition.ZONES:
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 6)
		var heading := UiChrome.body_label(String(ZONE_TITLES[zone]), 15)
		heading.add_theme_color_override("font_color", UiChrome.ACCENT)
		heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(heading)
		var add := UiChrome.menu_button("+ Add", Vector2(72, 26), 14)
		add.name = "Add_%d_%s" % [pid, zone]
		add.tooltip_text = "Choose a card for Seat %d: %s." % [pid + 1,
			String(ZONE_TITLES[zone]).to_lower()]
		add.pressed.connect(open_picker.bind(pid, zone))
		head.add_child(add)
		_add_buttons[pid][zone] = add
		var clear := UiChrome.menu_button("Clear", Vector2(64, 26), 14)
		clear.name = "Clear_%d_%s" % [pid, zone]
		clear.pressed.connect(func() -> void:
			test_position.clear_zone(pid, zone)
			_changed(pid, zone))
		head.add_child(clear)
		lists.add_child(head)
		if String(ZONE_HINTS[zone]) != "":
			lists.add_child(UiChrome.body_label(String(ZONE_HINTS[zone]), 12))
		var names := test_position.names_in(pid, zone)
		if names.is_empty():
			var none := UiChrome.body_label("    (none)", 13)
			none.add_theme_color_override("font_color", Color8(74, 66, 60))
			lists.add_child(none)
		for i in names.size():
			used[names[i]] = int(used.get(names[i], 0)) + 1
			var extra: bool = int(used[names[i]]) > int(_deck_counts[pid].get(names[i], 0))
			lists.add_child(_row(pid, zone, i, names[i], extra))
	_refresh_library_note(pid)
	_refresh_note()


## One card's row on a seat's list.
func _row(pid: int, zone: String, index: int, card_name: String, extra: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var known := CardRegistry.has_card(card_name)
	var label := UiChrome.body_label("    " + card_name + ("  " + EXTRA_MARK if extra else ""), 14)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	if not known:
		label.add_theme_color_override("font_color", Color8(150, 30, 30))
		label.tooltip_text = "%s is not in the card pool: is its card pack on?" % card_name
	else:
		label.tooltip_text = _card_words(CardRegistry.get_card(card_name)) \
			+ ("\n\nNot from this seat's deck: it is added to it for the test." if extra else "")
	row.add_child(label)
	if zone == DuelPosition.TABLE:
		var entry := test_position.table_entry(pid, index)
		var tapped := CheckBox.new()
		tapped.text = "Tapped"
		tapped.button_pressed = bool(entry.get("tapped", false))
		UiChrome.shadowed_button(tapped)
		tapped.toggled.connect(func(on: bool) -> void: test_position.set_tapped(pid, index, on))
		row.add_child(tapped)
		var sick := CheckBox.new()
		sick.text = "Sick"
		sick.tooltip_text = "Summoning sick: came under its controller's control this turn, so it cannot attack or use {T} abilities yet."
		sick.button_pressed = bool(entry.get("sick", false))
		UiChrome.shadowed_button(sick)
		sick.toggled.connect(func(on: bool) -> void: test_position.set_sick(pid, index, on))
		# Sickness is a creature's business (CR 302.6); a land or an
		# artifact on the table shows no box for it.
		sick.visible = known and CardRegistry.get_card(card_name).is_creature()
		row.add_child(sick)
	var remove := UiChrome.menu_button("×", Vector2(28, 24), 14)
	remove.tooltip_text = "Take %s out of the test." % card_name
	remove.pressed.connect(func() -> void:
		test_position.remove_at(pid, zone, index)
		_changed(pid, zone))
	row.add_child(remove)
	return row


## What a card says, for a row's tooltip: name and cost, then the rules.
static func _card_words(data: CardData) -> String:
	var cost := str(data.cost) if data.cost != null else ""
	var head := data.card_name + ("  " + cost if cost != "" else "")
	return head + ("\n" + data.oracle_text if data.oracle_text != "" else "")


## How many cards the seat's library will hold when the test begins.
func _refresh_library_note(pid: int) -> void:
	if pid >= _library_notes.size():
		return
	var in_deck := 0
	var used := {}
	for card_name in test_position.names_of(pid):
		used[card_name] = int(used.get(card_name, 0)) + 1
		if int(used[card_name]) <= int(_deck_counts[pid].get(card_name, 0)):
			in_deck += 1
	var tops := test_position.names_in(pid, DuelPosition.LIBRARY_TOP).size()
	var rest := maxi(config.decks[pid].size() - in_deck, 0)
	var random := mini(test_position.random_cards[pid], rest)
	_library_notes[pid].text = "Library when the test begins: %d cards." % (rest - random + tops)


## A place changed: its seat redrawn, the focus back on its `+ Add`.
func _changed(pid: int, zone: String) -> void:
	_refresh_seat(pid)
	var add: Button = _add_buttons[pid].get(zone)
	if add != null and is_instance_valid(add) and is_inside_tree():
		add.grab_focus()


## The line under everything: what is wrong, if anything is, else how the
## test will begin.
func _refresh_note() -> void:
	if _note == null:
		return
	var refused := test_position.refusal()
	if refused != "":
		_note.text = refused
		return
	_note.text = "The test begins in %s's turn, %s: no coin toss, no mulligan. In the duel, Restart test (under the large card, and in the Pause window) runs it again." % [
		config.player_names[test_position.active_player],
		String(STEP_LABELS.get(test_position.step, "")).to_lower()]


# ============================================================== the picker --

## THE CARD PICKER for [param pid]'s [param zone]: a search line, the list
## (the seat's deck with the copies it has left, or with `Any card in the
## pool` every card the enabled packs hold), the large card the list's
## selection shows, `Add` and `Done`. Enter or a double click adds the row
## and leaves the picker up for the next; Done or Escape puts it away. The
## Deck Builder's own window ([OriginalDialog], [CardPreview] at 0.8, as
## its card variant window wears them).
func open_picker(pid: int, zone: String) -> void:
	close_picker()
	_picker_pid = pid
	_picker_zone = zone
	var dialog := OriginalDialog.create("Add to Seat %d — %s" % [pid + 1,
		String(ZONE_TITLES[zone]).to_lower()], Vector2(700, 560))
	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 10)
	_picker_search = LineEdit.new()
	_picker_search.placeholder_text = "Search by name"
	_picker_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker_search.text_changed.connect(func(_text: String) -> void: _fill_picker())
	_picker_search.text_submitted.connect(func(_text: String) -> void: _add_picked())
	_picker_search.gui_input.connect(_on_search_input)
	search_row.add_child(_picker_search)
	_picker_any = CheckBox.new()
	_picker_any.text = "Any card in the pool"
	_picker_any.tooltip_text = "List every card the enabled card packs hold, not only this seat's deck. A card the deck has no copy of left is added to it for the test."
	_picker_any.toggled.connect(func(_on: bool) -> void: _fill_picker())
	search_row.add_child(_picker_any)
	dialog.body().add_child(search_row)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_picker_list = ItemList.new()
	_picker_list.custom_minimum_size = Vector2(380, 342)
	_picker_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker_list.item_selected.connect(_show_picked)
	_picker_list.item_activated.connect(func(_index: int) -> void: _add_picked())
	row.add_child(_picker_list)
	var holder := Control.new()
	holder.custom_minimum_size = CardPreview.SIZE * 0.8
	row.add_child(holder)
	_picker_preview = CardPreview.new()
	_picker_preview.docked = true
	_picker_preview.scale = Vector2(0.8, 0.8)
	holder.add_child(_picker_preview)
	dialog.body().add_child(row)
	var add := dialog.add_button("Add")
	add.name = "PickerAdd"
	add.pressed.connect(_add_picked)
	var done := dialog.add_button("Done")
	done.name = "PickerDone"
	done.pressed.connect(close_picker)
	_picker = dialog
	add_child(dialog)
	_fill_picker()
	_picker_search.grab_focus()


## Put the picker away and give the focus back to the place's `+ Add`.
func close_picker() -> void:
	if _picker == null:
		return
	if is_instance_valid(_picker):
		_picker.dismiss()
	# Its controls go with it: nothing may reach for them once it is freed.
	_picker = null
	_picker_search = null
	_picker_any = null
	_picker_list = null
	_picker_preview = null
	var add: Button = _add_buttons[_picker_pid].get(_picker_zone)
	if add != null and is_instance_valid(add) and is_inside_tree():
		add.grab_focus()


func picker_open() -> bool:
	return _picker != null and is_instance_valid(_picker)


## The rows for the search and the switch: card name in the metadata, the
## copies left after it, a deck's card greyed when none is left.
func _fill_picker() -> void:
	if _picker_list == null:
		return
	_picker_list.clear()
	var wanted := _picker_search.text.strip_edges().to_lower()
	var any := _picker_any.button_pressed
	var counts: Dictionary = _deck_counts[_picker_pid]
	var names: Array = CardRegistry.all_names() if any else counts.keys()
	if not any:
		names.sort()
	var shown := 0
	for value in names:
		var card_name := String(value)
		if wanted != "" and not card_name.to_lower().contains(wanted):
			continue
		# ONLY A PERMANENT GOES ON THE TABLE (review 2026-10-21, engine-5):
		# a Lightning Bolt put there stayed on the battlefield as a
		# permanent for the whole duel, a state no game can reach. The
		# hand, the graveyard and the library still take any card.
		if _picker_zone == DuelPosition.TABLE and CardRegistry.has_card(card_name) \
				and not CardRegistry.get_card(card_name).is_permanent_type():
			continue
		if shown >= POOL_ROWS:
			_picker_list.add_item("… more: type more of the name")
			_picker_list.set_item_disabled(_picker_list.item_count - 1, true)
			_picker_list.set_item_selectable(_picker_list.item_count - 1, false)
			break
		shown += 1
		var left := int(counts.get(card_name, 0)) - test_position.count_of(_picker_pid, card_name)
		var text := card_name
		if counts.has(card_name):
			text += "   ×%d left" % maxi(left, 0)
		_picker_list.add_item(text)
		var index := _picker_list.item_count - 1
		_picker_list.set_item_metadata(index, card_name)
		if CardRegistry.has_card(card_name):
			_picker_list.set_item_tooltip(index, _card_words(CardRegistry.get_card(card_name)))
		# From the deck alone, a card with no copy left cannot be added —
		# with `Any card` it can, as an extra.
		if not any and left <= 0:
			_picker_list.set_item_disabled(index, true)
	if _picker_list.item_count > 0 and _picker_list.is_item_selectable(0) \
			and not _picker_list.is_item_disabled(0):
		_picker_list.select(0)
		_show_picked(0)


## The selected row on the large card.
func _show_picked(index: int) -> void:
	if _picker_preview == null or index < 0 or index >= _picker_list.item_count:
		return
	var meta: Variant = _picker_list.get_item_metadata(index)
	if meta == null or not CardRegistry.has_card(String(meta)):
		return
	_picker_preview.show_card(CardInstance.new(CardRegistry.get_card(String(meta)), -1, 0))


## Add the selected row to the place the picker is for; the picker stays
## up, its counts brought up to date, the same row still selected.
func _add_picked() -> void:
	if not picker_open():
		return
	var picked := _picker_list.get_selected_items()
	if picked.is_empty():
		return
	var index := picked[0]
	if _picker_list.is_item_disabled(index):
		return
	var meta: Variant = _picker_list.get_item_metadata(index)
	if meta == null:
		return
	add_card(_picker_pid, _picker_zone, String(meta))
	_fill_picker()
	if index < _picker_list.item_count:
		_picker_list.select(index)
		_show_picked(index)


## Name [param card_name] into [param pid]'s [param zone] — the picker's
## add, and the door a test uses.
func add_card(pid: int, zone: String, card_name: String) -> void:
	test_position.add(pid, zone, card_name)
	_refresh_seat(pid)


## Down from the search line walks into the list (the keys and the pad).
func _on_search_input(event: InputEvent) -> void:
	if _picker_list == null:
		return
	if event.is_action_pressed("ui_down") and _picker_list.item_count > 0:
		_picker_list.grab_focus()
		if _picker_list.get_selected_items().is_empty():
			_picker_list.select(0)
			_show_picked(0)
		get_viewport().set_input_as_handled()


# =========================================================== saved tests --

## The saved tests, by name — read defensively: the file is the player's.
##
## EVERY NAME IS TEXT (review 2026-10-21, ui-3). A hand edit can give a
## saved test a number for a name (`{1: {...}}`), and `String(1)` is a
## script error in this engine: the Saved tests list stopped at it and
## every test after it could not be reached. A number reads as its digits —
## the name the player meant — and a name of any other kind is left out; a
## text name wins over a number that reads the same. The next `Save` or
## `Delete` writes the names back as text.
static func saved_tests() -> Dictionary:
	var saved: Variant = Settings.get_value(SAVED_KEY, {})
	if not (saved is Dictionary):
		return {}
	var out := {}
	for key in saved:
		var text := key is String or key is StringName
		if text or key is int or key is float:
			var test_name := String(key) if text else str(key)
			if text or not out.has(test_name):
				out[test_name] = saved[key]
	return out


func _refresh_saved() -> void:
	_saved_option.clear()
	var names := saved_tests().keys()
	names.sort()
	for value in names:
		_saved_option.add_item(String(value))
	if names.is_empty():
		_saved_option.add_item("(none yet)")
		_saved_option.set_item_disabled(0, true)
	_saved_option.disabled = names.is_empty()


## `Save`: this test under the typed name — a name already there is
## replaced, which is how a saved test is brought up to date.
func _save_current() -> void:
	var test_name := _save_name.text.strip_edges().left(NAME_MAX).strip_edges()
	if test_name == "":
		_explain("Save", "Type a name for this test first.")
		return
	var saved := saved_tests()
	saved[test_name] = _as_saved()
	Settings.set_value(SAVED_KEY, saved)
	_save_name.text = ""
	_refresh_saved()
	for i in _saved_option.item_count:
		if _saved_option.get_item_text(i) == test_name:
			_saved_option.select(i)


## `Load`: the chosen saved test replaces this one.
func _load_saved() -> void:
	if _saved_option.disabled or _saved_option.selected < 0:
		return
	var test_name := _saved_option.get_item_text(_saved_option.selected)
	var saved: Variant = saved_tests().get(test_name)
	if not (saved is Dictionary):
		return
	_take(saved)
	_refresh_all()
	_select_saved(test_name)


## `Delete`: the chosen saved test is gone.
func _delete_saved() -> void:
	if _saved_option.disabled or _saved_option.selected < 0:
		return
	var saved := saved_tests()
	saved.erase(_saved_option.get_item_text(_saved_option.selected))
	Settings.set_value(SAVED_KEY, saved)
	_refresh_saved()


func _select_saved(test_name: String) -> void:
	for i in _saved_option.item_count:
		if _saved_option.get_item_text(i) == test_name:
			_saved_option.select(i)


# ============================================================== the leaving --

## `Clear all`: a fresh position ([method _fresh]); `Show both hands` stays.
func _clear_all() -> void:
	test_position = _fresh()
	_refresh_all()


## The test duel's config, or null with the refusal said — its own
## function so it can be read without a duel starting. A FRESH SEED every
## press: `Go test!` again is a new shuffle under the same position, and
## the duel's `Restart test` is the same one again.
func build_test_config() -> DuelConfig:
	var refused := test_position.refusal()
	if refused != "":
		_explain("This test cannot begin", refused)
		return null
	return config.for_test(test_position, randi() | 1, open_hands)


## `Go test!`: the duel, straight into the chosen turn. The test is
## remembered first ([constant LAST_KEY]) — every gate has passed.
func go_test() -> void:
	if _leaving:
		return
	var test_config := build_test_config()
	if test_config == null:
		return
	Settings.set_value(LAST_KEY, _as_saved())
	var duel: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	duel.config = test_config
	_leaving = true
	close_picker()
	var tree := get_tree()
	if tree.current_scene == self:
		tree.root.add_child(duel)
		tree.current_scene = duel
	else:
		get_parent().add_child(duel)
	test_started.emit(duel)
	queue_free()


## `Back`: the Magic Battle screen, which opens on the choices this test
## was made with (remembered when `Test hands` was pressed).
func _go_back() -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().change_scene_to_file("res://game/setup_screen.tscn")


## Every explanation and refusal through one door, so Escape knows what is
## up ([method _unhandled_input]).
func _explain(title: String, body: String) -> void:
	UiChrome.explain_popup(self, title, body, 520.0)


## ESCAPE: the picker first, then a popup, then `Back` — the Magic Battle
## screen's ladder.
func _unhandled_input(event: InputEvent) -> void:
	if _leaving or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if picker_open():
		close_picker()
		return
	var popup := UiChrome.open_popup(self)
	if popup != null:
		UiChrome.dismiss_popup(popup)
		return
	_go_back()
