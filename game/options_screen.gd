extends Control
## The Options screen — `[QoL]`, because the 1997 game had none.
##
## Every control here is a VIEW of one stored [Settings] key, and where the
## original had a home for a setting, that home keeps its own control over
## the same key: the two sound switches are also on the deck builder's
## mini-menu (`@DECKSURFACE_STANDALONE`), the territory background is also
## in the Duel Options panel. One value, one storage, many views — never a
## parallel copy.
##
## Full screen, the skin (which zips dress the game, and a file box to
## choose one), sound on/off (music and effects separately, as the
## original separated them), music & effects volume, hand display, the
## rules forks, AI pace, the adventure's transitions — persisted
## immediately through Settings
## (user://settings.cfg), so every one of them is the default of the next
## run. The shell's bed plays on through this screen (`ShellMusic`), and
## the three music controls act on it as they are moved. Grows as options do (phase stops, UI scale and colorblind palette
## are on the QoL wishlist in docs/duel-screen-design.md).

## The stone panel's width, and the window it leaves clear top and bottom.
## The panel is anchored to those margins rather than sized to its
## contents, because this list only ever grows.
const PANEL_WIDTH := 460.0
const PANEL_MARGIN := 24.0
## The `Touch controls` row's items, in the order they are listed: the
## index the OptionButton reports IS the index into this.
const TOUCH_MODES: Array[String] = ["auto", "on", "off"]
## The `Pad pointer` row's items, the same way.
const PAD_MODES: Array[String] = ["auto", "on", "off"]
## The `On-screen keyboard` row's items, the same way.
const KEYBOARD_MODES: Array[String] = ["auto", "on", "off"]
## The `Card back:` row's picture: a fifth of the 1997 back, 228x323.
const CARD_BACK_THUMB := Vector2(46, 65)
## What the game wants of a card back picture — the row's greyed line
## and its `Choose...` tooltip ([CardBack]).
const CARD_BACK_NOTE := "A PNG, JPG or WEBP, upright: 456 x 646 pixels is best, " \
	+ "a card's shape. Another shape is trimmed from the middle to fit; the " \
	+ "game keeps its own copy."
## The `Controls:` rows' two slots, by action: `action -> [key button,
## pad button]`, so a rebind can redraw every row (a key that moved off
## another action changes two of them).
var _control_slots: Dictionary = {}
## The `Press a key` popup while one is up, and the listener under it.
var _listening: Control = null
## The browser's file box being watched ([method _choose_card_back]).
var _card_back_poll: Timer = null


func _ready() -> void:
	# The screen and the mixer must agree before a control is drawn: the
	# sliders read Settings, so the buses had better be carrying the same
	# numbers or the readout is a lie. `ShellMusic.play` dresses the buses
	# first for exactly that reason — and keeps the shell's bed playing
	# through this room, which is the one room where a player is LISTENING
	# for it: the Music switch, the volume slider and the track picker
	# below all sound at once against it (2026-09-07 playtest: *"Help and
	# options in main menu should have same music as main menu"*).
	ShellMusic.play()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.08, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title_bg := GameSkin.texture("title_background")
	if title_bg != null:
		var art := TextureRect.new()
		art.texture = title_bg
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.modulate = Color(0.5, 0.5, 0.5)
		add_child(art)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	# THE PANEL SCROLLS, because the list grows. Options is a screen whose
	# whole job is to accumulate — the sound section alone added four rows
	# on 2026-09-02 — and a centred panel taller than the window loses BOTH
	# ends: a screenshot caught the title clipped at the top and `Back`
	# clipped off the bottom. The scroller is sized to the window with a
	# margin, so the panel is exactly as tall as it can be and no taller.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# THE LIST WALKS (2026-09-27): a focus that moves down the rows on
	# the arrows or a D-pad brings the panel along, so a row below the
	# fold is reached without a wheel.
	scroll.follow_focus = true
	scroll.add_child(content)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel := UiChrome.panel_around(scroll, 18.0)
	# Anchored rather than centred-on-its-own-size: the panel is as tall as
	# the window allows and the list scrolls inside it. Anchors do the
	# re-fit on a resize, so there is no layout pass to wait for.
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -PANEL_WIDTH * 0.5
	panel.offset_right = PANEL_WIDTH * 0.5
	panel.offset_top = PANEL_MARGIN
	panel.offset_bottom = -PANEL_MARGIN
	add_child(panel)

	var title := UiChrome.body_label("Options", 26)
	var title_font := GameSkin.font("font_title")
	if title_font != null:
		title.add_theme_font_override("font", title_font)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	# --- campaign 2026-10-12 f-settings: settings.cfg trouble, said here ---
	content.add_child(_c2_fsettings_problem_line())
	# --- end campaign 2026-10-12 f-settings ---

	_add_display_section(content)

	_add_controls_section(content)

	_add_skin_section(content)

	_add_card_back_section(content)

	_add_card_packs_section(content)

	_add_sound_section(content)

	content.add_child(UiChrome.body_label("Booster Draft:"))
	var draft := UiChrome.menu_button("Card pool / Launch draft", Vector2(320, 36))
	draft.name = "LaunchDraftSetup"
	draft.pressed.connect(func() -> void: DraftSetup.open_on(self))
	content.add_child(draft)

	var demo := UiChrome.menu_button("Demo screen", Vector2(320, 36))
	demo.name = "DemoScreen"
	demo.pressed.connect(func() -> void: DemoSetup.open_on(self))
	content.add_child(demo)

	var past := UiChrome.menu_button("View past-played games", Vector2(320, 36))
	past.name = "ViewPastGames"
	past.pressed.connect(func() -> void: MpnFiles.choose(self, func(path: String) -> void:
		var viewer := PastGamesScreen.new()
		viewer.overlay = true
		add_child(viewer)
		viewer.open_record(path)))
	content.add_child(past)

	var draw := UiChrome.menu_button(DrawSetup.DRAW_TITLE, Vector2(320, 36))
	draw.name = "DrawCards"
	draw.pressed.connect(func() -> void: DrawSetup.draw_on(self))
	content.add_child(draw)

	content.add_child(UiChrome.body_label("Hand display:"))
	var hand_style := OptionButton.new()
	hand_style.add_item("Fan of cards", 0)
	hand_style.add_item("Stacked list — original style", 1)
	hand_style.selected = 1 if Settings.hand_style() == "stack" else 0
	hand_style.item_selected.connect(func(index: int) -> void:
		Settings.set_value("hand_style", "stack" if index == 1 else "fan"))
	UiChrome.shadowed_button(hand_style)
	content.add_child(hand_style)

	_add_bar_frame_section(content)

	_add_coin_toss_section(content)

	_add_rules_section(content)

	content.add_child(UiChrome.body_label("AI pace in duels (seconds/action):"))
	var pace := HSlider.new()
	pace.min_value = 0.1
	pace.max_value = 1.5
	pace.step = 0.05
	pace.value = Settings.ai_pace()
	pace.value_changed.connect(func(value: float) -> void:
		Settings.set_value("ai_pace", value, false))
	_flush_when_the_drag_ends(pace)
	content.add_child(pace)

	var back := UiChrome.menu_button("Back", Vector2(200, 42))
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://game/main.tscn"))
	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	back_row.add_child(back)
	content.add_child(back_row)
	# The keyboard and the D-pad start on the first row (2026-09-27, the
	# Steam Deck release): a screen with nothing focused has nothing for
	# an arrow to move from. The mouse and the pad pointer are untouched.
	_focus_first(content)


## The first thing on the panel that takes the keyboard.
static func _focus_first(root: Node) -> void:
	for node in _focusables(root):
		(node as Control).grab_focus()
		return


static func _focusables(node: Node) -> Array[Control]:
	var out: Array[Control] = []
	if node is Control and (node as Control).focus_mode == Control.FOCUS_ALL \
			and (node as Control).is_visible_in_tree():
		out.append(node as Control)
	for child in node.get_children():
		out.append_array(_focusables(child))
	return out


## DISPLAY — ONE SWITCH, and it is `[QoL]` outright. See [GameDisplay]
## for what the 1997 game had instead (a `M&inimize` entry and a
## frameless-window config key with no menu entry); this row exists
## because the owner asked for it on 2026-09-07: *"options menu in the
## main menu lacks full screen / windowed option."* Off is the window the
## game has always opened into; on is borderless full screen at the
## desktop's own resolution. Applied the moment it is ticked, so the
## player sees what they chose while this screen is still up — and
## remembered, so the next run opens into it ([Lifecycle]).
func _add_display_section(content: VBoxContainer) -> void:
	content.add_child(UiChrome.body_label("Display:"))
	var fullscreen := CheckButton.new()
	fullscreen.text = "Full screen"
	fullscreen.tooltip_text = "On: borderless full screen at your " \
		+ "desktop's resolution. Off: the 1280x800 window. Takes effect " \
		+ "at once and is remembered for the next run."
	fullscreen.button_pressed = Settings.fullscreen()
	fullscreen.toggled.connect(func(on: bool) -> void:
		GameDisplay.set_fullscreen(on))
	UiChrome.shadowed_button(fullscreen)
	content.add_child(fullscreen)

	var cards := CheckButton.new()
	cards.name = "FullscreenCards"
	cards.text = "Full-screen card on click"
	cards.button_pressed = Settings.fullscreen_cards()
	cards.toggled.connect(func(on: bool) -> void:
		Settings.set_value("fullscreen_cards", on))
	UiChrome.shadowed_button(cards)
	content.add_child(cards)
	var card_hint := UiChrome.body_label(
		"Click or tap the large card in a duel or the Deck Builder to "
		+ "read it full screen. Click again or press Esc to close.", 14)
	card_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(card_hint)

	# `[QoL]` POWER SAVER (2026-09-27, the Steam Deck release) — the
	# engine's `low_processor_usage_mode`, see [GameDisplay]. A view of
	# the stored key like the switches above; the default it opens on is
	# the desk's (off) or the handheld launcher's (on), and ticking it
	# writes the player's word over either.
	var power := CheckButton.new()
	power.name = "PowerSaver"
	power.text = "Power saver"
	power.tooltip_text = "Redraw only when something on the screen " \
		+ "changes and rest between frames - for a handheld's battery. " \
		+ "Takes effect at once and is remembered for the next run."
	power.button_pressed = Settings.power_saver()
	power.toggled.connect(func(on: bool) -> void:
		GameDisplay.set_power_saver(on))
	UiChrome.shadowed_button(power)
	content.add_child(power)

	# `[QoL]` TRANSITIONS (the owner, 2026-10-27, H7: "Add, with a switch")
	# — 1997's picture effects in the adventure ([TileReveal]): on by
	# default, short, skipped by a click or a key. A view of the stored key
	# like the switches above; the next picture shown reads it.
	var transitions := CheckButton.new()
	transitions.name = "Transitions"
	transitions.text = "Transitions"
	transitions.tooltip_text = "In the adventure, pictures come in as they " \
		+ "did in 1997: a town's zooms in, a castle's and a lair's appear " \
		+ "tile by tile. Short, and any click or key skips one. Off: every " \
		+ "picture is simply there."
	transitions.button_pressed = Settings.transitions()
	transitions.toggled.connect(func(on: bool) -> void:
		Settings.set_value(TileReveal.SETTING, on))
	UiChrome.shadowed_button(transitions)
	content.add_child(transitions)

	# `[QoL]` TOUCH CONTROLS — the finger-as-mouse layer (`TouchControls`,
	# `game/input/touch_controls.gd`) for the web export on a tablet or a
	# phone and for touch laptops. Three states, one stored key, and the
	# row is a VIEW of it like the switch above: it opens on what is
	# stored and writes what is picked, at once, through the autoload so
	# the file and the layer cannot disagree. `Auto` is the default and
	# what nearly everyone should leave it on: it turns the layer on only
	# where there is a touchscreen to serve.
	var touch_row := HBoxContainer.new()
	touch_row.add_theme_constant_override("separation", 12)
	touch_row.add_child(UiChrome.body_label("Touch controls:"))
	var touch := OptionButton.new()
	touch.name = "TouchControls"
	touch.add_item("Auto", 0)
	touch.add_item("On", 1)
	touch.add_item("Off", 2)
	touch.tooltip_text = "Play by finger: tap to click, hold and lift " \
		+ "for the right-click menu, drag to move. Auto turns it on " \
		+ "only where there is a touchscreen; On forces it; Off never."
	touch.selected = TOUCH_MODES.find(Settings.touch_controls())
	touch.item_selected.connect(func(index: int) -> void:
		TouchControls.choose(TOUCH_MODES[index]))
	UiChrome.shadowed_button(touch)
	touch_row.add_child(touch)
	content.add_child(touch_row)

	# `[QoL]` PAD POINTER (2026-09-27) — the controller-as-mouse layer
	# (`PadControls`, `game/input/pad_controls.gd`), the touch layer's
	# twin for a Steam Deck in its gamepad layout or a pad on a desk.
	# Three states, one stored key, the row a VIEW of it.
	var pad_row := HBoxContainer.new()
	pad_row.add_theme_constant_override("separation", 12)
	pad_row.add_child(UiChrome.body_label("Pad pointer:"))
	var pad := OptionButton.new()
	pad.name = "PadPointer"
	pad.add_item("Auto", 0)
	pad.add_item("On", 1)
	pad.add_item("Off", 2)
	pad.tooltip_text = "Play with a controller: the left stick moves a " \
		+ "pointer, the D-pad hops it between cards and buttons, A " \
		+ "clicks, LB opens the right-click menu, the right stick " \
		+ "scrolls. Auto turns it on when a controller is present; On " \
		+ "forces it; Off leaves the pad to the duel's own buttons."
	pad.selected = PAD_MODES.find(Settings.pad_pointer())
	pad.item_selected.connect(func(index: int) -> void:
		PadControls.choose(PAD_MODES[index]))
	UiChrome.shadowed_button(pad)
	pad_row.add_child(pad)
	content.add_child(pad_row)

	# `[QoL]` ON-SCREEN KEYBOARD (2026-10-02, the ArkOS tester with no
	# USB keyboard) — the board of keys (`ScreenKeyboard`,
	# `game/input/screen_keyboard.gd`) a text field brings up on a
	# handheld without keys. Three states, one stored key, the row a
	# VIEW of it.
	var keyboard_row := HBoxContainer.new()
	keyboard_row.add_theme_constant_override("separation", 12)
	keyboard_row.add_child(UiChrome.body_label("On-screen keyboard:"))
	var keyboard := OptionButton.new()
	keyboard.name = "ScreenKeyboard"
	keyboard.add_item("Auto", 0)
	keyboard.add_item("On", 1)
	keyboard.add_item("Off", 2)
	keyboard.tooltip_text = "A board of keys across the window whenever " \
		+ "a text field takes the focus, for a handheld with no " \
		+ "keyboard: point and click to type. Auto shows it on a " \
		+ "handheld whose system has no keyboard of its own; On always; " \
		+ "Off never."
	keyboard.selected = KEYBOARD_MODES.find(Settings.screen_keyboard())
	keyboard.item_selected.connect(func(index: int) -> void:
		ScreenKeyboard.choose(KEYBOARD_MODES[index]))
	UiChrome.shadowed_button(keyboard)
	keyboard_row.add_child(keyboard)
	content.add_child(keyboard_row)


## `[QoL]` CONTROLS — the duel's keys as actions ([Controls],
## `project.godot [input]`), one row an action: the word, its key and
## its controller button, each a button that listens for the next press
## ([method _listen]). The rows are VIEWS of the input map the way the
## rows above are views of a stored key: they read what is bound and
## write what is pressed, at once, through [method Controls.bind], which
## also remembers it. `Reset controls` is the project's defaults again.
func _add_controls_section(content: VBoxContainer) -> void:
	var head := UiChrome.body_label("Controls:")
	head.tooltip_text = "The duel's keys and controller buttons. Click a " \
		+ "slot and press the key or button you want there; a key already " \
		+ "on another action moves. The deck builder's Ctrl accelerators " \
		+ "are the 1997 menu's own and stay as they are."
	content.add_child(head)
	_control_slots.clear()
	for entry in Controls.ACTIONS:
		var action := String(entry["name"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var word := UiChrome.body_label(String(entry["label"]))
		word.custom_minimum_size.x = 210
		word.tooltip_text = String(entry["tip"])
		row.add_child(word)
		var key := UiChrome.menu_button("", Vector2(118, 28), 13)
		key.name = "Key_" + action
		key.tooltip_text = "The key for %s. Click, then press a key." % String(entry["label"]).to_lower()
		key.pressed.connect(_listen.bind(action, "key"))
		row.add_child(key)
		var pad := UiChrome.menu_button("", Vector2(84, 28), 13)
		pad.name = "Pad_" + action
		pad.tooltip_text = "The controller button for %s. Click, then press a button." % String(entry["label"]).to_lower()
		pad.pressed.connect(_listen.bind(action, "pad"))
		row.add_child(pad)
		# A row whose command is still dark is listed, greyed and says why
		# (campaign 2026-10-12 f-shell, b6-5) — the rules forks' habit.
		if not Controls.available(action):
			for slot in [key, pad]:
				slot.disabled = true
				slot.tooltip_text = "Not available yet."
		_control_slots[action] = [key, pad]
		content.add_child(row)
	var reset := UiChrome.menu_button("Reset controls", Vector2(180, 32), 14)
	reset.name = "ResetControls"
	reset.tooltip_text = "Every key and button back to the defaults."
	reset.pressed.connect(func() -> void:
		Controls.reset()
		_refresh_control_rows())
	content.add_child(reset)
	_refresh_control_rows()


## Every row says what the map says.
func _refresh_control_rows() -> void:
	for action in _control_slots:
		var slots: Array = _control_slots[action]
		slots[0].text = Controls.key_text(action)
		slots[1].text = Controls.pad_text(action)


## The `Press a key` popup: the next key (or pad button, for the pad
## slot) goes on [param action] and the popup closes; Cancel leaves the
## binding alone. Esc is a key like any other here — it is bindable —
## so the only way out of the KEY popup without binding is the button
## (under the pad popup Esc is no button, and cancels it).
##
## WITH THE PAD POINTER ON (bug campaign 2026-10-12, r2-3) the layer's
## own buttons — A, LB, the D-pad — are the pointer's: the pad popup does
## not take them, so the pointer can still reach Cancel and A clicks it.
## They used to be bound: A meant for Cancel became the one button, which
## the layer eats, and the pad could no longer advance the game.
func _listen(action: String, kind: String) -> void:
	if _listening != null:
		return
	var label := ""
	for entry in Controls.ACTIONS:
		if String(entry["name"]) == action:
			label = String(entry["label"])
	var now := Controls.key_text(action) if kind == "key" else Controls.pad_text(action)
	var ask := "Press the key for %s (now %s)." % [label.to_lower(), now] if kind == "key" \
		else "Press the controller button for %s (now %s)." % [label.to_lower(), now]
	var layer := get_node_or_null(^"/root/PadControls")
	if kind == "pad" and layer != null and layer.is_active():
		ask += " A, LB and the D-pad move and click the pad pointer and are not offered."
	var veil := UiChrome.action_popup(self, label, ask, [
		{"label": "Cancel", "name": "Cancel", "cancel": true,
			"callable": func() -> void: _listening = null}])
	veil.name = "ControlsListener"
	var listener := ControlsListener.new()
	listener.kind = kind
	listener.bound.connect(func(event: InputEvent) -> void:
		Controls.bind(action, event)
		_refresh_control_rows()
		_listening = null
		veil.queue_free())
	veil.add_child(listener)
	_listening = veil


## Under the popup: the first bindable press of the kind asked for.
class ControlsListener:
	extends Node
	signal bound(event: InputEvent)
	var kind := "key"

	func _input(event: InputEvent) -> void:
		var wanted := (event is InputEventKey) if kind == "key" else (event is InputEventJoypadButton)
		if not wanted or not Controls.bindable(event):
			return
		# The pad pointer's own buttons are its to spend (see [method _listen]).
		var layer := get_node_or_null(^"/root/PadControls")
		if layer != null and layer.owns(event):
			return
		get_viewport().set_input_as_handled()
		bound.emit(event)


## Numbered gameplay packs get their own compact management page. Keeping
## validation details there leaves this already-long Options list readable.
func _add_card_packs_section(content: VBoxContainer) -> void:
	content.add_child(UiChrome.body_label("Card packs:"))
	var manage := UiChrome.menu_button("Card Packs...", Vector2(180, 32), 14)
	manage.name = "CardPacks"
	manage.tooltip_text = "See installed numbered card packs, validation " \
		+ "errors, versions, and enabled state."
	manage.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://game/card_packs_screen.tscn"))
	content.add_child(manage)


## THE SKIN AND THE PLAYER'S FOLDERS — `[QoL]`, and the owner's asks of
## 2026-09-08: *"we should have a menu options to select asset art skin
## by file choosing"*, then: *"it should just say 'skin', point to skin
## zip in skins folder. Then it should be a checkbox — 'use art folder
## instead of zip' (the default folder location should be shown in
## settings but can also be changed in cfg) … additional music folder …
## Additional Portraits folder … Card folder (therein cardpacks as zip
## are placed; support for future card packs). Write in settings also
## that these folder locations can be changed in the cfg file!"* — and,
## on seeing the first draft: *"Buttons too big! Too much text under
## forget my zips! (Do we need forget my zips button? All this info
## document in text files not here in the gui)"*. So: small buttons,
## one line per place, the long form in the tooltips, and the tools and
## the keys explained in setup.txt, not here.
##
## The rows, top to bottom, every one a VIEW of a place ([GamePaths]):
##   * `Skin:` — the skin zip worn, by its path ([method SkinPack.describe]),
##     with `Choose...`: a file box for a zip, kept in the skins folder
##     and mounted the way a zip dropped on the window is; the
##     `skin_zip` key names it from then on.
##   * `Use the skin folder instead of the zip` — the `use_skin_folder`
##     key, and under it the skin folder's path and what is in it. On,
##     the zip stays closed from the next start; the loose folder
##     `import_original.py` fills is the skin (the owner: *"the user
##     wants to use this and not zip!"*).
##   * NO 2x ROW. 0.50.29 had one (2026-10-17) — a
##     `2x pictures:` line and a `Wear the 2x pictures` switch — and the
##     owner took it out: *"A skin is a skin and gets applied after game
##     reset. No switches."* The 2x skin is chosen on the Skin row like
##     any other ([GameSkin], THE 2x PICTURES).
##   * `Card folder:` — the folder every card pack is mounted from, and
##     the packs found; `Choose...` copies a zip in.
##   * `Additional portraits folder:` and `Additional music folder:` —
##     the player's own, joining the 1997 faces and tunes.
##   * One greyed line: the places can be moved in settings.cfg, and
##     setup.txt says how.
## In a browser only the two zip rows show — there is no folder a
## player could open, and no file to edit — and `Forget my zips` is
## the way back to what shipped, because there is no file to delete by
## hand either. On the desktop the row names the folder; deleting the
## zip there is the same thing, so the button is not built.
##
## The rows re-read themselves when a pack arrives ([signal
## SkinPack.changed]), because the box's answer comes back through the
## pack, not through this screen — and in a browser the chosen file is
## read in over a few frames, which the line under the rows reports
## ([method SkinPack.transfer_line]).
func _add_skin_section(content: VBoxContainer) -> void:
	content.add_child(UiChrome.body_label("Skin:"))
	var web := OS.has_feature("web")
	content.add_child(_zip_row("skin", "Pick a skin zip: a skin/ folder inside it "
		+ "with the 1997 art, the 2x skin upscale_skin.py makes of it, or your own "
		+ "drawn to the same names. It is kept in the skins folder and worn from "
		+ "the next start. SKIN.txt beside the game lists every file."))
	# --- campaign 2026-10-12 f-packs: the skin refusal reason line ---
	content.add_child(_c2_fpacks_refused_line())
	# --- end campaign 2026-10-12 f-packs ---
	if not web:
		var use_folder := CheckButton.new()
		use_folder.name = "UseSkinFolder"
		use_folder.text = "Use the skin folder instead of the zip"
		use_folder.tooltip_text = "On: the folder below alone dresses the game and " \
			+ "the zip stays closed — a file missing from the folder is drawn by " \
			+ "the game, not taken from the zip. Off: the zip alone is worn, and " \
			+ "the folder only when there is no zip. Takes effect at the next start."
		use_folder.button_pressed = GamePaths.use_skin_folder()
		use_folder.toggled.connect(func(on: bool) -> void:
			GamePaths.set_use_skin_folder(on)
			var hint := find_child("SkinHint", true, false) as Label
			if hint != null:
				hint.text = ("The folder is worn from the next start; the zip stays closed."
					if on else "The zip is worn from the next start.")
				hint.visible = true
			_on_skin_changed("skin"))
		UiChrome.shadowed_button(use_folder)
		content.add_child(use_folder)
		content.add_child(_place_label("SkinFolder", "Loose skin files, the way "
			+ "import_original.py beside the game lays them out from your copy of "
			+ "the 1997 game. Worn when the switch above is on, or when there is "
			+ "no skin zip."))
		var hint := UiChrome.body_label("", 12)
		hint.name = "SkinHint"
		hint.visible = false
		content.add_child(hint)
	content.add_child(_zip_row("cardart", "Pick a card art zip: "
		+ "skin/cardart/<card_name>.jpg inside it. It is copied into the card "
		+ "folder, where every zip is worn."))
	if not web:
		# The card folder exists from the first look at this screen, README
		# and all, so the path the row names can be opened — the same
		# gesture as the music and portrait folders.
		SkinPack.ensure_card_folder()
		content.add_child(_place_label("PortraitsFolder", "A PNG, JPG or WEBP "
			+ "placed here joins the 1997 faces in the portrait chooser; the file "
			+ "name is the name."))
		content.add_child(_place_label("MusicFolder", "A WAV, OGG or MP3 placed "
			+ "here plays among the 1997 tunes; the file name is the name."))
	else:
		var forget := UiChrome.menu_button("Forget my zips", Vector2(150, 28), 14)
		forget.name = "ForgetSkins"
		forget.tooltip_text = "Delete the zips you chose or dropped; the game " \
			+ "wears what came with the page from the next start."
		forget.visible = SkinPack.has_own()
		forget.pressed.connect(SkinPack.forget)
		var forget_row := HBoxContainer.new()
		forget_row.alignment = BoxContainer.ALIGNMENT_END
		forget_row.add_child(forget)
		content.add_child(forget_row)
	var transfer := UiChrome.body_label("", 12)
	transfer.name = "SkinTransfer"
	transfer.visible = false
	content.add_child(transfer)
	var note := UiChrome.body_label(places_note(web), 12)
	note.name = "SkinNote"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.modulate.a = 0.65
	content.add_child(note)
	_on_skin_changed("")
	# Bound methods, not lambdas: a bound method leaves the autoload's
	# signals with the screen, a lambda would outlive it and write to a
	# freed label.
	SkinPack.changed.connect(_on_skin_changed)
	SkinPack.fetch_progressed.connect(_on_skin_transfer)


## One zip row: what dresses the game for [param kind], and `Choose...`.
func _zip_row(kind: String, tip: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var status := UiChrome.body_label("", 13)
	status.name = "SkinStatus_" + kind
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(status)
	# Three dots, as `Sideboard...` and `Help...`: the menu font has no
	# ellipsis glyph, and `Choose…` drew bare (checked by looking). Row
	# height, not menu height — *"Buttons too big!"*
	var choose := UiChrome.menu_button("Choose...", Vector2(84, 26), 13)
	choose.name = "Choose_" + kind
	choose.tooltip_text = tip
	choose.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	choose.pressed.connect(func() -> void:
		SkinPack.pick(kind))
	row.add_child(choose)
	return row


## One folder row, filled by [method _on_skin_changed]; the long form
## of what goes there is the tooltip, so the row itself stays a line.
static func _place_label(node_name: String, tip: String) -> Label:
	var label := UiChrome.body_label("", 13)
	label.name = node_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.tooltip_text = tip
	label.mouse_filter = Control.MOUSE_FILTER_PASS   # a label ignores the mouse by default: no tooltip
	return label


## The `Skin folder:` row's words.
static func skin_folder_line(shown: String, there: bool, files: int) -> String:
	if not there:
		return "Skin folder: %s — not there yet" % shown
	return "Skin folder: %s — %d file%s" % [shown, files, "" if files == 1 else "s"]


## The `Additional portraits folder:` row's words. The owner: *"portraits
## by the user are added to originals and displayed on portrait
## selection"* — the how is the tooltip.
static func portraits_line(shown: String, count: int) -> String:
	if count == 0:
		return "Additional portraits folder: %s — none yet" % shown
	return "Additional portraits folder: %s — %d of yours" % [shown, count]


## The `Additional music folder:` row's words. The owner: *"Music by
## user is added to original scores and played"*.
static func music_line(shown: String, count: int) -> String:
	if count == 0:
		return "Additional music folder: %s — none yet" % shown
	return "Additional music folder: %s — %d track%s of yours" \
		% [shown, count, "" if count == 1 else "s"]


## The one greyed line under the rows. The keys, the tools and what a
## zip holds are setup.txt's and SKIN.txt's to explain, not this
## screen's; a browser has no file to edit, so its line keeps to the drop.
static func places_note(web: bool) -> String:
	if web:
		return "A zip dropped on the page works too."
	return "Every place above can be moved in settings.cfg — setup.txt beside " \
		+ "the game says how. A zip dropped on the window works too."


## A pack arrived, the player's zips were forgotten, or the folder switch
## moved: every row re-reads its place.
func _on_skin_changed(_kind: String) -> void:
	for kind in SkinPack.KINDS:
		var status := find_child("SkinStatus_" + kind, true, false) as Label
		if status != null:
			status.text = SkinPack.status_line(kind, SkinPack.describe(kind))
	var folder := find_child("SkinFolder", true, false) as Label
	if folder != null:
		var place := GamePaths.skin_folder()
		var there := DirAccess.dir_exists_absolute(GameSkin.locate(place))
		folder.text = skin_folder_line(GamePaths.shown(place), there,
			SkinPack.files_at(place) if there else 0)
	var portraits := find_child("PortraitsFolder", true, false) as Label
	if portraits != null:
		portraits.text = portraits_line(GamePaths.shown(PortraitLibrary.ensure_folder()),
			PortraitLibrary.own_count())
	var music := find_child("MusicFolder", true, false) as Label
	if music != null:
		music.text = music_line(GamePaths.shown(MusicLibrary.ensure_folder()),
			MusicLibrary.own_count())
	var forget := find_child("ForgetSkins", true, false) as Button
	if forget != null:
		forget.visible = SkinPack.has_own()
	# --- campaign 2026-10-12 f-packs: the skin refusal reason line ---
	_c2_fpacks_on_skin_changed("")
	# --- end campaign 2026-10-12 f-packs ---


func _on_skin_transfer(fraction: float) -> void:
	var line := find_child("SkinTransfer", true, false) as Label
	if line == null:
		return
	line.text = SkinPack.transfer_line(fraction)
	line.visible = SkinPack.busy()


## THE CARD BACK — `[QoL]`, the owner's two asks of 2026-10-19: *"for
## seasonal card backs lets implement an on/off in options (as some users
## may not like this)"* and *"an option in settings so user can use his
## own photo as card back (lets also document and tell the user what
## format and pixel*pixel the game expects the file to be!)"*.
##
## The rows, top to bottom:
##   * the back the cards wear now, small, beside whose it is — your
##     picture by its path, the season's, the skin's or the game's plain
##     one ([method card_back_line]) — with `Choose...`, a file box for a
##     picture ([method _choose_card_back], [CardBack]), and `Remove`
##     while you have one;
##   * a line saying why a picture was not taken, while one was not;
##   * `Seasonal card backs`, the [constant GameSkin.KEY_SEASONS] key —
##     written `false` when switched off and cleared when switched back
##     on, so the default is never written;
##   * one greyed line, [constant CARD_BACK_NOTE]: the kind and the size
##     of picture the game wants.
## Both act at once: the next card back drawn is the new one.
func _add_card_back_section(content: VBoxContainer) -> void:
	content.add_child(UiChrome.body_label("Card back:"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var thumb := Panel.new()
	thumb.name = "CardBackThumb"
	thumb.custom_minimum_size = CARD_BACK_THUMB
	thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(thumb)
	var status := UiChrome.body_label("", 13)
	status.name = "CardBackStatus"
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(status)
	var buttons := VBoxContainer.new()
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var choose := UiChrome.menu_button("Choose...", Vector2(84, 26), 13)
	choose.name = "ChooseCardBack"
	choose.tooltip_text = "Pick a picture for the back of every card. " + CARD_BACK_NOTE
	choose.pressed.connect(_choose_card_back)
	buttons.add_child(choose)
	var remove := UiChrome.menu_button("Remove", Vector2(84, 26), 13)
	remove.name = "RemoveCardBack"
	remove.tooltip_text = "Delete the game's copy of your picture; the cards " \
		+ "wear the skin's back again. The picture you chose is not touched."
	remove.pressed.connect(func() -> void:
		CardBack.forget()
		_show_card_back_problem("")
		_refresh_card_back())
	buttons.add_child(remove)
	row.add_child(buttons)
	content.add_child(row)
	var problem := UiChrome.body_label("", 12)
	problem.name = "CardBackProblem"
	problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# The skin's refusal line's amber ([method _c2_fpacks_refused_line]).
	problem.add_theme_color_override("font_color", Color8(232, 176, 96))
	problem.visible = false
	content.add_child(problem)
	var seasons := CheckButton.new()
	seasons.name = "SeasonalBacks"
	seasons.text = "Seasonal card backs"
	seasons.tooltip_text = "On a few days of the year every card wears a back " \
		+ "of its own. Off: never. A picture of your own is worn whatever this says."
	seasons.button_pressed = GameSkin.seasons_on()
	seasons.toggled.connect(func(on: bool) -> void:
		if on:
			Settings.clear_value(GameSkin.KEY_SEASONS)
		else:
			Settings.set_value(GameSkin.KEY_SEASONS, false)
		_refresh_card_back())
	UiChrome.shadowed_button(seasons)
	content.add_child(seasons)
	var note := UiChrome.body_label(CARD_BACK_NOTE, 12)
	note.name = "CardBackNote"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.modulate.a = 0.65
	content.add_child(note)
	_refresh_card_back()


## The `Card back:` row's words: whose back the cards wear. [param own]
## is the player's picture as shown, or "".
static func card_back_line(own: String, seasonal: bool, skinned: bool) -> String:
	if own != "":
		return "Your picture: %s" % own
	if seasonal:
		return "The season's back"
	return "The skin's back" if skinned else "The game's plain back"


## The row's small card: [param back], or the plain back a face-down
## card wears without one ([MiniCard]).
static func card_back_box(back: Texture2D) -> StyleBox:
	if back != null:
		var tex := StyleBoxTexture.new()
		tex.texture = back
		return tex
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0.16, 0.10, 0.22)
	flat.border_color = Color(0.35, 0.28, 0.15)
	flat.set_border_width_all(2)
	flat.set_corner_radius_all(4)
	return flat


## Every card back row re-read: after a pick, a removal or the switch.
func _refresh_card_back() -> void:
	var own := CardBack.texture() != null
	var status := find_child("CardBackStatus", true, false) as Label
	if status != null:
		status.text = card_back_line(GamePaths.shown(CardBack.found()) if own else "",
			GameSkin.season_back() != null, GameSkin.skin_texture("card_back") != null)
	var thumb := find_child("CardBackThumb", true, false) as Panel
	if thumb != null:
		thumb.add_theme_stylebox_override("panel", card_back_box(GameSkin.texture("card_back")))
	var remove := find_child("RemoveCardBack", true, false) as Control
	if remove != null:
		remove.visible = CardBack.has_own()


func _show_card_back_problem(text: String) -> void:
	var line := find_child("CardBackProblem", true, false) as Label
	if line != null:
		line.text = text
		line.visible = text != ""


## `Choose...`: the platform's file box for a picture, as the skin's
## `Choose...` opens one for a zip ([method SkinPack.pick]); in a browser
## the page's own ([method CardBack.web_open]), watched a tenth of a
## second at a time until the player is done with it.
func _choose_card_back() -> void:
	_show_card_back_problem("")
	if OS.has_feature("web"):
		if _card_back_poll != null:
			return
		CardBack.web_open()
		_card_back_poll = Timer.new()
		_card_back_poll.wait_time = 0.1
		_card_back_poll.timeout.connect(_poll_card_back)
		add_child(_card_back_poll)
		_card_back_poll.start()
		return
	var box := FileDialog.new()
	box.name = "CardBackChooser"
	box.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	# After the mode: setting the mode retitles the box ("Open a File").
	box.title = "Choose a picture for the card back"
	box.access = FileDialog.ACCESS_FILESYSTEM
	# Both cases: a camera names its files IMG_0001.JPG, and a desktop's
	# box may match the pattern as written.
	box.filters = PackedStringArray(["*.png, *.PNG, *.jpg, *.JPG, *.jpeg, *.JPEG, "
		+ "*.webp, *.WEBP ; Pictures"])
	box.use_native_dialog = true
	box.size = Vector2i(760, 520)
	box.current_dir = card_back_start_dir()
	box.file_selected.connect(func(path: String) -> void:
		_show_card_back_problem(CardBack.adopt(path))
		_refresh_card_back()
		box.queue_free())
	box.canceled.connect(box.queue_free)
	add_child(box)
	box.popup_centered()


func _poll_card_back() -> void:
	if not CardBack.web_poll():
		return
	_card_back_poll.queue_free()
	_card_back_poll = null
	_show_card_back_problem(CardBack.web_refusal)
	_refresh_card_back()


## Where the desktop's box opens: the player's pictures, else where the
## skin's box opens ([method SkinPack.pick_start_dir]).
static func card_back_start_dir() -> String:
	var pictures := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if pictures != "" and DirAccess.dir_exists_absolute(pictures):
		return pictures
	return SkinPack.pick_start_dir()


## SOUND — TWO SWITCHES AND TWO SLIDERS, and only the switches are 1997's.
##
## The original had **no global options screen**. Its two audio switches
## are entries 8 and 9 of `@DECKSURFACE_STANDALONE`
## (`s30/assets/text/Menus.txt:169-179`) and of `@MAINMENU_STANDALONE`
## (`:218-228`) — `&Music` and `Sound &Effects`, on the deck builder's own
## right-click menu — and the deck builder persists them by name
## (`cfg_write_int(global_cfg_music ? 1 : 0, "Music")`,
## `shandalar-src/src/deck/deckdll.cpp:1296`).
##
## So this whole screen is `[QoL]`, and these two rows are an AGGREGATOR:
## [DeckBuilderScreen]'s mini-menu carries the same two switches, in the
## place 1997 put them, and both views read and write the same
## [Settings] keys. There is one stored value per setting and no parallel
## copy anywhere — the same contract [DuelOptions] states for the
## territory background.
##
## The two SLIDERS are ours outright: `&Music` and `Sound &Effects` are
## on/off in the original and there is no volume anywhere in its string
## tables. They set bus volumes through [GameAudio], which is why dragging
## one is audible in a duel that is already running — the value is not
## copied onto a player at build time any more.
func _add_sound_section(content: VBoxContainer) -> void:
	content.add_child(UiChrome.body_label("Sound:"))

	var effects := CheckButton.new()
	effects.text = "Sound effects"
	effects.tooltip_text = "@DECKSURFACE_STANDALONE — \"Sound Effects\", " \
		+ "the same switch the deck builder's menu carries"
	effects.button_pressed = Settings.sound_enabled()
	effects.toggled.connect(func(on: bool) -> void:
		Settings.set_value("sound_enabled", on)
		GameAudio.apply_settings())
	UiChrome.shadowed_button(effects)
	content.add_child(effects)

	content.add_child(UiChrome.body_label("Effects volume:"))
	content.add_child(_volume_slider("sfx_volume_db", Settings.sfx_volume_db()))

	var music := CheckButton.new()
	music.text = "Music"
	music.tooltip_text = "@DECKSURFACE_STANDALONE — \"Music\", the same " \
		+ "switch the deck builder's menu carries"
	music.button_pressed = Settings.music_enabled()
	music.toggled.connect(func(on: bool) -> void:
		Settings.set_value("music_enabled", on)
		# The shell's bed answers the switch here and now — off stops it
		# and drops the PCM, on starts it — rather than at the next room.
		ShellMusic.play())
	UiChrome.shadowed_button(music)
	content.add_child(music)

	content.add_child(UiChrome.body_label("Music volume:"))
	content.add_child(_volume_slider("music_volume_db", Settings.music_volume_db()))

	_add_music_choice(content)


## WHICH TUNE — `[QoL]`, and the answer to a complaint rather than a
## wishlist item.
##
## The 1997 duel plays ONE bed, `Dueltune.wav`, looped
## (`MAGIC.EXE` entry `004ebfef`). It is TEN seconds long (22 050 Hz
## 16-bit stereo, 10.08 s). The owner's
## playtest, 2026-09-03: *"Music in the duel is wrong — now it is
## repeating a short sample — unacceptable. Check music songs available
## (expose this also in music and user can add their own)."*
##
## All three halves of that sentence are this row. **What is available**:
## the original has twenty-seven loopable beds, not one, and
## [MusicLibrary] lists every one it can find. **Expose it**: the picker
## below. **Their own**: `user://music/`, created here with a README in
## it, exactly the way the battle-setup screen creates `user://portraits/`.
##
## ONE STORED VALUE, MANY VIEWS — the contract the two sound switches
## above already keep. The key is `music_choice` and [MusicLibrary] owns
## its meaning; this screen is a view of it and never a second copy.
func _add_music_choice(content: VBoxContainer) -> void:
	# Creating the folder is what makes the README appear, and the README
	# is how a player learns the format without opening a manual. Same
	# gesture, same reason, as [method PortraitLibrary.ensure_folder] on
	# the setup screen.
	var folder := MusicLibrary.ensure_folder()
	MusicLibrary.refresh()
	var tracks := MusicLibrary.all()

	content.add_child(UiChrome.body_label("Music:"))
	var picker := OptionButton.new()
	picker.add_item("Shuffle all tracks", 0)
	picker.set_item_tooltip(0, "Whole tracks, one after another, "
		+ "crossfaded — %d of them" % tracks.size())
	picker.add_item("1997 — one tune per screen, looped", 1)
	picker.set_item_tooltip(1, "What the original did: Dueltune.wav in a "
		+ "duel, one LocMus track in the deck builder")
	var chosen := MusicLibrary.choice()
	var selected := 1 if chosen == MusicLibrary.CHOICE_ORIGINAL else 0
	for i in tracks.size():
		var entry: Dictionary = tracks[i]
		var id := 2 + i
		picker.add_item(String(entry["name"]), id)
		picker.set_item_tooltip(id, "Just this one, on repeat"
			+ ("  (yours)" if bool(entry["mine"]) else ""))
		if entry["id"] == chosen:
			selected = picker.item_count - 1
	picker.selected = selected
	picker.item_selected.connect(func(index: int) -> void:
		var id := picker.get_item_id(index)
		if id == 0:
			MusicLibrary.set_choice(MusicLibrary.CHOICE_SHUFFLE)
		elif id == 1:
			MusicLibrary.set_choice(MusicLibrary.CHOICE_ORIGINAL)
		else:
			MusicLibrary.set_choice(String(tracks[id - 2]["id"]))
		# The next screen that starts music takes the new order; a session
		# that has already shuffled should not keep the old one.
		MusicPlayer.reset_order()
		# And the shell's bed, which is playing behind this row, changes to
		# the new choice at once — `play_one` keys on the track id, so a
		# choice that names the bed already up leaves it alone.
		ShellMusic.play())
	UiChrome.shadowed_button(picker)
	content.add_child(picker)

	# SAY WHERE THE FOLDER IS, in the screen rather than in a tooltip
	# nobody hovers — the same habit the coin-toss row keeps for a reason
	# it cannot offer something.
	var line := "No tracks yet. " if tracks.is_empty() else \
		"%d track%s. " % [tracks.size(), "" if tracks.size() == 1 else "s"]
	if tracks.is_empty():
		line += "Import your copy of the 1997 game, or drop "
		line += "WAV/OGG/MP3 files in:\n%s" % folder
	elif OS.has_feature("web"):
		# No folder row under Skin in a browser (nothing to open there).
		line += "Your own — WAV, OGG or MP3 — go in %s." % folder
	else:
		line += "Add your own — WAV, OGG or MP3 — in the music folder " \
			+ "named under Skin, above."
	var why := UiChrome.body_label(line, 12)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.custom_minimum_size.x = PANEL_WIDTH - 64.0
	why.modulate = Color(1, 1, 1, 0.65)
	content.add_child(why)


## THE OPENING COIN TOSS — `[QoL]`, and the FULL view of a value whose
## 1997 view is a checkbox.
##
## `Show coin flip animations` (`@DIALOG_DUELOPTIONS`,
## `s30/assets/text/Uistrings.txt:604`) is a BOOL in the original, and it
## gated one thing: whether the pre-rendered movie played. The Duel
## Options panel still carries that checkbox, over the same
## `ShowCoinFlips` key; this list is the same value with its third
## position exposed. One stored value, two views — the contract
## [DuelOptions] states for the territory background and the deck
## builder's two sound switches.
##
## THE FIRST ENTRY IS USUALLY UNAVAILABLE, and says so rather than
## disappearing — the original's own habit (*"greys what it cannot
## offer"*, `Duel.hlp`, **Territory**), the same one [TerritoryMenu] and
## the rules forks above follow. `COINTOSS_Heads.AVI` /
## `COINTOSS_Tails.AVI` ship only with the 1997 game, so a player who has
## not imported it sees the entry, learns what it needs, and gets our
## animation instead — [method CoinToss.effective_style] does the
## substitution, and it falls back to the RECREATION rather than to
## instant: someone who asked to watch the toss should still watch it.
## THE SITUATION BAR'S FRAME (2026-10-19, `[QoL]`) — the four frames of
## [constant DuelOptions.BAR_FRAMES], ShandalarGodot first and the default,
## with a piece of the bar under the list wearing the one chosen, so the
## choice is seen rather than described (under, not beside: the panel is
## [constant PANEL_WIDTH] wide). The duel reads it as it builds its bars,
## so it holds from the next duel.
func _add_bar_frame_section(content: VBoxContainer) -> void:
	content.add_child(UiChrome.body_label("Situation Bar frame:"))
	var picker := OptionButton.new()
	picker.name = "BarFrame"
	var chosen := DuelOptions.bar_frame()
	for i in DuelOptions.BAR_FRAMES.size():
		var frame: Dictionary = DuelOptions.BAR_FRAMES[i]
		picker.add_item(String(frame["label"]), i)
		picker.set_item_tooltip(i, String(frame["blurb"]))
		if frame["key"] == chosen:
			picker.selected = i
	UiChrome.shadowed_button(picker)
	content.add_child(picker)
	var preview := PanelContainer.new()
	preview.name = "BarFramePreview"
	preview.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	preview.add_theme_stylebox_override("panel", OriginalDialog.bar_style(5.0))
	preview.add_child(OriginalDialog.label("Main phase: cast spells, play land", 16))
	content.add_child(preview)
	picker.item_selected.connect(func(index: int) -> void:
		DuelOptions.set_bar_frame(String(DuelOptions.BAR_FRAMES[index]["key"]))
		preview.add_theme_stylebox_override("panel", OriginalDialog.bar_style(5.0)))


func _add_coin_toss_section(content: VBoxContainer) -> void:
	content.add_child(UiChrome.body_label("Opening coin toss:"))

	var have_video := CoinToss.video_available()
	var picker := OptionButton.new()
	# THE PICKER SHOWS WHAT WILL ACTUALLY HAPPEN, not what is stored. A
	# player who chose the movie on a machine that has it, and then opens
	# this screen on one that does not, is shown `Our coin animation` —
	# which is what the next duel will do — while the stored value stays
	# `video`, so importing the original later gives them the movie back
	# without their having to ask twice.
	var chosen := CoinToss.current_style()
	for i in DuelOptions.COIN_FLIP_STYLES.size():
		var row: Dictionary = DuelOptions.COIN_FLIP_STYLES[i]
		picker.add_item(String(row["label"]), i)
		picker.set_item_tooltip(i, String(row["blurb"]))
		if row["key"] == DuelOptions.COIN_VIDEO and not have_video:
			picker.set_item_disabled(i, true)
			picker.set_item_tooltip(i, CoinToss.VIDEO_MISSING)
		if row["key"] == chosen:
			picker.selected = i
	picker.item_selected.connect(func(index: int) -> void:
		DuelOptions.set_coin_flip_style(
			String(DuelOptions.COIN_FLIP_STYLES[index]["key"])))
	UiChrome.shadowed_button(picker)
	content.add_child(picker)

	# SAY WHY, in the screen rather than in a tooltip nobody hovers: a
	# greyed line that gives no reason is just a broken option.
	if not have_video:
		var why := UiChrome.body_label(CoinToss.VIDEO_MISSING, 12)
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		why.custom_minimum_size.x = PANEL_WIDTH - 64.0
		why.modulate = Color(1, 1, 1, 0.65)
		content.add_child(why)


## THE RULES FORKS. The original enforced the FIFTH EDITION rules (manual
## p.108) where our engine cites the modern Comprehensive Rules, and the
## two genuinely disagree in a handful of places. Each is a switch here,
## with the presets that set them all (RulesOptions.PRESETS, in that
## order, then the "Custom" readout for any other mix) — and a fork that
## is not implemented yet is shown DISABLED rather than offered as a
## switch that does nothing. RulesOptions.FORKS is the single source for
## this list.
func _add_rules_section(content: VBoxContainer) -> void:
	var heading := UiChrome.body_label("Rules — 1997 (Fifth Edition) or modern:")
	content.add_child(heading)

	var boxes: Dictionary = {}
	var preset := OptionButton.new()
	for entry in RulesOptions.PRESETS:
		preset.add_item(entry["label"])
	preset.add_item(RulesOptions.CUSTOM_LABEL)
	UiChrome.shadowed_button(preset)
	content.add_child(preset)

	var live := RulesOptions.new()
	for fork in RulesOptions.FORKS:
		var key: String = fork["key"]
		live.set_fork(key, Settings.rule(key))
		var row := CheckButton.new()
		row.text = fork["label"]
		var ready_yet: bool = RulesOptions.IMPLEMENTED.has(key)
		row.disabled = not ready_yet
		row.tooltip_text = "1997: %s\nModern: %s%s" % [
			fork["fifth"], fork["modern"],
			"" if ready_yet else "\n\nThis option is not available yet."]
		# Clicking the NAME explains the rule; clicking the switch flips
		# it. A disabled row still explains itself — that is the whole
		# point of showing an unbuilt fork rather than hiding it.
		var explain := Button.new()
		explain.text = "?"
		explain.custom_minimum_size = Vector2(26, 0)
		explain.tooltip_text = "What this rule means"
		UiChrome.shadowed_button(explain)
		explain.pressed.connect(_explain_rule.bind(fork))
		row.button_pressed = Settings.rule(key)
		row.toggled.connect(func(on: bool) -> void:
			Settings.set_rule(key, on)
			live.set_fork(key, on)
			preset.selected = _preset_index(live.preset()))
		UiChrome.shadowed_button(row)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 4)
		line.add_child(row)
		line.add_child(explain)
		content.add_child(line)
		boxes[key] = row

	preset.selected = _preset_index(live.preset())
	preset.item_selected.connect(func(index: int) -> void:
		if index >= RulesOptions.PRESETS.size():
			return       # "Custom" is a readout, not a command
		live.set_preset(RulesOptions.PRESETS[index]["id"])
		for key in boxes:
			var on: bool = live.get_fork(key)
			# In memory per fork and ONE write for the gesture — the
			# sliders' rule; this loop used to write the file seven times.
			Settings.set_rule(key, on, false)
			boxes[key].set_pressed_no_signal(on)
		Settings.flush())


## The rule's own explanation, on the era's stone panel with an OK button
## — both editions' behaviour. Source references stay in RulesOptions,
## not in player-facing menus (2026-09-13 playtest).
func _explain_rule(fork: Dictionary) -> void:
	var built: bool = RulesOptions.IMPLEMENTED.has(fork["key"])
	var body := "1997 (Fifth Edition):\n%s\n\nModern rules:\n%s" % [
		fork["fifth"], fork["modern"]]
	if not built:
		body += "\n\nThis option is not available yet."
	UiChrome.explain_popup(self, fork["label"], body)


## The preset box's row for a RulesOptions.preset() id: its place in
## PRESETS, or the "Custom" row after them.
static func _preset_index(id: String) -> int:
	for index in RulesOptions.PRESETS.size():
		if RulesOptions.PRESETS[index]["id"] == id:
			return index
	return RulesOptions.PRESETS.size()


func _volume_slider(key: String, current: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = -40.0
	slider.max_value = 0.0
	slider.step = 1.0
	slider.value = current
	slider.value_changed.connect(func(value: float) -> void:
		# In memory only: a drag fires this on every pixel, and the file
		# is written once when the handle is let go (below).
		Settings.set_value(key, value, false)
		# Straight onto the bus, so a duel behind this screen changes
		# while the handle is moving. That is the whole point of mixing on
		# buses rather than copying the number onto a player.
		GameAudio.apply_settings())
	_flush_when_the_drag_ends(slider)
	return slider


## Every slider on this screen applies each tick and SAVES once: when the
## mouse drag ends, when keyboard focus leaves it (arrow keys change the
## value with no drag to end), and — in [method _exit_tree] — when the
## screen itself goes, whichever way it goes.
static func _flush_when_the_drag_ends(slider: HSlider) -> void:
	slider.drag_ended.connect(func(_changed: bool) -> void:
		Settings.flush())
	slider.focus_exited.connect(func() -> void:
		Settings.flush())


func _exit_tree() -> void:
	Settings.flush()
	if SkinPack.changed.is_connected(_on_skin_changed):
		SkinPack.changed.disconnect(_on_skin_changed)
	if SkinPack.fetch_progressed.is_connected(_on_skin_transfer):
		SkinPack.fetch_progressed.disconnect(_on_skin_transfer)


# --- campaign 2026-10-12 f-shell: Escape is Back ---
## ESCAPE IS BACK (bug campaign 2026-10-12, r2-9): Escape, a pad's B with
## the pointer off or on, the Quest's back gesture and the R36's Start all
## arrive as `ui_cancel`, and every other room of the shell answers it.
## With a popup up it is that popup's Cancel (or its only button) instead
## ([method UiChrome.dismiss_popup]); the `Press a key` popup takes Esc as
## a key before it gets here.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel", false, true):
		return
	accept_event()
	var popup := UiChrome.open_popup(self)
	if popup != null:
		UiChrome.dismiss_popup(popup)
	else:
		get_tree().change_scene_to_file("res://game/main.tscn")
# --- end campaign 2026-10-12 f-shell ---


# --- campaign 2026-10-12 f-packs: the skin refusal reason line ---
## A zip of the player's that the game would not wear, and why — one line
## per zip, in warning ink, under the skin row ([method
## SkinPack.refusal_lines]). The zip itself stays where it is (it used to
## be deleted at the start, with nothing said). Hidden when there is
## nothing to say; re-read with the other rows when a pack arrives
## ([method _on_skin_changed] calls [method _c2_fpacks_on_skin_changed]),
## so the screen holds no second connection to the autoload's signal.
func _c2_fpacks_refused_line() -> Label:
	var line := UiChrome.body_label("", 12)
	line.name = "SkinRefused"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_color_override("font_color", Color8(232, 176, 96))
	line.tooltip_text = "The game will not wear this zip; it is left where it is. " \
		+ "A skin zip has every file under one skin/ folder."
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	_c2_fpacks_fill_refused(line)
	return line


func _c2_fpacks_on_skin_changed(_kind: String) -> void:
	var line := find_child("SkinRefused", true, false) as Label
	if line != null:
		_c2_fpacks_fill_refused(line)


static func _c2_fpacks_fill_refused(line: Label) -> void:
	line.text = "\n".join(SkinPack.refusal_lines())
	line.visible = line.text != ""
# --- end campaign 2026-10-12 f-packs ---


# --- campaign 2026-10-12 f-settings: settings.cfg trouble, said here ---
## WHAT WENT WRONG WITH settings.cfg, under the screen's title, for as long
## as it holds ([method Settings.problem]): a save that failed (a full or
## read-only card, a read-only file — the switch looked saved and was gone
## at the next start), a file that could not be read, a hand edit kept
## aside. Hidden when there is nothing to say. Every control here saves
## through [Settings], so the line reads the class each frame rather than
## each control telling it.
func _c2_fsettings_problem_line() -> Label:
	var line := _C2FSettingsProblemLine.new()
	line.name = "SettingsProblem"
	var font := GameSkin.font("font_body")
	if font != null:
		line.add_theme_font_override("font", font)
	line.add_theme_font_size_override("font_size", 13)
	UiChrome.shadowed(line)
	line.add_theme_color_override("font_color", UiChrome.ACCENT)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = PANEL_WIDTH - 60.0
	line.refresh()
	return line


class _C2FSettingsProblemLine extends Label:
	func _process(_delta: float) -> void:
		refresh()

	func refresh() -> void:
		var now := Settings.problem()
		if text != now:
			text = now
		visible = now != ""
# --- end campaign 2026-10-12 f-settings ---


# ------------------------------------------------------------ demo screen --

class DemoSetup extends Control:
	## The `Demo screen` window, opened from Options: which cards (a set, every
	## set, or a list typed or pasted in), which show, fronts or backs, and Go.
	## The window stays up under the show and comes back when the show is left,
	## so a second show is one click away.
	##
	## The choices last for the session ([member _last]) and are written
	## nowhere: nothing here touches `settings.cfg`.

	const TITLE := "Demo screen"
	const CARDS_FROM := "Cards from:"
	const ALL_SETS := "All sets"
	const CARD_LIST := "Card list (below)"
	const LIST_HINT := "One card name per line. A deck list works too."
	const SHOW := "Show:"
	const SIDE := "Cards:"
	const FOIL := "Foil on rare cards"
	const GO := "Go"
	const BACK := "Back"
	## The ids [member _last] keeps for the source: "" for every set, a set
	## code, or this.
	const LIST := "list"
	## A list longer than this is cut, so a pasted file cannot stall the window.
	const MAX_LIST_LINES := 2000

	## The session's last choices, so the window reopens as it was left.
	static var _last := {"source": "", "list": "", "mode": DemoScreen.Mode.SOLITAIRE,
		"faces": DemoScreen.Faces.FRONT, "foil": true}

	## This window's own copy of the session's choices: [member _last] here,
	## the draw window's in [DrawSetup].
	var memory: Dictionary
	## The Options button that opened the window, by name, and the prefix of
	## the window's own nodes.
	var opener := "DemoScreen"
	var prefix := "Demo"
	var window: OriginalDialog
	var go_button: Button
	var source_list: OptionButton
	var list_box: TextEdit
	var check_label: Label
	var mode_list: OptionButton
	var faces_list: OptionButton
	var foil_check: CheckBox
	## The running show, while there is one.
	var demo: DemoScreen
	var _previous: Control
	var _show_layer: CanvasLayer


	func _init() -> void:
		memory = _last


	## Open the window over [param previous] (the Options screen).
	static func open_on(previous: Control) -> DemoSetup:
		var setup := DemoSetup.new()
		setup._previous = previous
		previous.add_child(setup)
		return setup


	## Each source the window offers, in the order its list shows them:
	## every set, then each set the game has cards for, then the typed list.
	static func sources() -> Array[Dictionary]:
		var out: Array[Dictionary] = [{"id": "", "label": ALL_SETS}]
		for code in CardRegistry.active_set_order():
			if CardRegistry.names_in_set(code).is_empty():
				continue
			out.append({"id": code,
				"label": String(DeckFilter.SET_LABELS.get(code, code.to_upper()))})
		out.append({"id": LIST, "label": CARD_LIST})
		return out


	## THE LIST CHECK. Each line is a card name, matched without regard to
	## case or to curly apostrophes; a deck list's counts (`4 Lightning Bolt`,
	## `4x Lightning Bolt`, `Lightning Bolt x4`, `SB: 2 Disenchant`) are read
	## past, and a line that is no card name is tried again split at its
	## commas, so `Lightning Bolt, Forest` works while `Ertai, Wizard Adept`
	## stays one card. Returns `found` (each card once, in the order typed)
	## and `unknown` (as typed).
	static func check_list(text: String) -> Dictionary:
		var lookup := {}
		for card_name in CardRegistry.all_names():
			lookup[_folded(String(card_name))] = String(card_name)
		var found: Array[String] = []
		var unknown: Array[String] = []
		var lines := text.replace(";", "\n").split("\n")
		for i in mini(lines.size(), MAX_LIST_LINES):
			var line := _bare(lines[i])
			if line == "":
				continue
			var pieces: Array[String] = [line]
			if not lookup.has(_folded(line)) and line.contains(","):
				pieces.clear()
				for piece in line.split(","):
					if _bare(piece) != "":
						pieces.append(_bare(piece))
			for piece in pieces:
				var known: String = lookup.get(_folded(piece), "")
				if known == "":
					if not unknown.has(piece):
						unknown.append(piece)
				elif not found.has(known):
					found.append(known)
		return {"found": found, "unknown": unknown}


	## A line without its deck-list furniture: comments, `SB:`, counts.
	static func _bare(line: String) -> String:
		var s := line.strip_edges()
		if s.begins_with("#") or s.begins_with("//"):
			return ""
		if s.to_lower().begins_with("sb:"):
			s = s.substr(3).strip_edges()
		var lead := RegEx.create_from_string("^\\d+\\s*[x×]?\\s+")
		s = lead.sub(s, "")
		var tail := RegEx.create_from_string("\\s+[x×]\\s*\\d+$")
		s = tail.sub(s, "")
		return s.strip_edges()


	static func _folded(card_name: String) -> String:
		return card_name.replace("’", "'").replace("‘", "'").strip_edges().to_lower()


	## The cards a source deals from: a set's own, every card the game has,
	## or the list's found cards.
	static func pool_for(source_id: String, list_text: String) -> Array[String]:
		var out: Array[String] = []
		if source_id == LIST:
			out.assign(check_list(list_text).found)
		elif source_id == "":
			out.assign(CardRegistry.all_names())
		else:
			out.assign(CardRegistry.names_in_set(source_id))
		return out


	## What the window's foot says about the keys, in the player's own
	## bindings where the game has one. One key a line: the window's lettering
	## has no middle dot to run them together with.
	static func keys_text(again := "new cards", pad_again := "deals new cards") -> String:
		var lines: Array[String] = ["Click or Esc: back to this window",
			"R: %s" % again, "Space: pause"]
		var shot := Controls.key_text("duel_screenshot")
		if shot != Controls.UNBOUND:
			lines.append("%s: save the screen as a picture" % shot)
		lines.append("On a pad: A or B goes back, Y %s, Start pauses." % pad_again)
		return "\n".join(lines)


	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		z_index = 150
		var shade := ColorRect.new()
		shade.color = Color(0, 0, 0, 0.55)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(shade)
		window = _build_window()
		add_child(window)
		window.fit_height()
		go_button.grab_focus()


	func _build_window() -> OriginalDialog:
		var dialog := OriginalDialog.create(_title(), Vector2(500, 560))
		var box := dialog.body()
		_add_source_rows(box)
		_add_show_rows(box)

		box.add_child(HSeparator.new())
		var keys := OriginalDialog.wrapped(_keys_text(), 13)
		keys.name = prefix + "Keys"
		box.add_child(keys)

		go_button = GauntletOptions.fit(dialog.add_button(GO))
		go_button.name = prefix + "Go"
		go_button.pressed.connect(start)
		GauntletOptions.fit(dialog.add_button(BACK)).pressed.connect(close)
		_refresh()
		return dialog


	func _title() -> String:
		return TITLE


	func _keys_text() -> String:
		return keys_text()


	## Which cards: the source list, the list box under it and its check.
	func _add_source_rows(box: VBoxContainer) -> void:
		box.add_child(OriginalDialog.label(CARDS_FROM, 14, true))
		source_list = OptionButton.new()
		source_list.name = prefix + "Source"
		source_list.fit_to_longest_item = false
		source_list.clip_text = true
		source_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for entry in sources():
			source_list.add_item(String(entry.label))
			source_list.set_item_metadata(source_list.item_count - 1, String(entry.id))
		_select_source(String(memory.source))
		source_list.item_selected.connect(func(_index: int) -> void:
			memory.source = _source_id()
			_refresh())
		box.add_child(source_list)

		list_box = TextEdit.new()
		list_box.name = prefix + "List"
		list_box.placeholder_text = LIST_HINT
		list_box.custom_minimum_size = Vector2(0, 110)
		list_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		for state in ["normal", "focus"]:
			list_box.add_theme_stylebox_override(state,
				OriginalDialog.panel_style("panel_dark_stone", 5.0))
		list_box.add_theme_color_override("font_color", OriginalDialog.CHOICE_LIT)
		list_box.add_theme_color_override("caret_color", OriginalDialog.CHOICE_LIT)
		list_box.add_theme_color_override("font_placeholder_color",
			OriginalDialog.PLACEHOLDER)
		var body_font := GameSkin.font("font_body")
		if body_font != null:
			list_box.add_theme_font_override("font", body_font)
		list_box.text = String(memory.list)
		list_box.text_changed.connect(func() -> void:
			memory.list = list_box.text
			# Typing a list means dealing from it.
			if list_box.text.strip_edges() != "" and _source_id() != LIST:
				_select_source(LIST)
				memory.source = LIST
			_refresh())
		box.add_child(list_box)

		check_label = OriginalDialog.wrapped("", 13)
		check_label.name = prefix + "Check"
		box.add_child(check_label)


	## The show's own choices: which show, which side, the foil.
	func _add_show_rows(box: VBoxContainer) -> void:
		box.add_child(OriginalDialog.label(SHOW, 14, true))
		mode_list = OptionButton.new()
		mode_list.name = "DemoMode"
		for title in DemoScreen.MODE_TITLES:
			mode_list.add_item(title)
		mode_list.select(int(_last.mode))
		mode_list.item_selected.connect(func(index: int) -> void:
			_last.mode = index)
		box.add_child(mode_list)

		box.add_child(OriginalDialog.label(SIDE, 14, true))
		faces_list = OptionButton.new()
		faces_list.name = "DemoFaces"
		for title in DemoScreen.FACES_TITLES:
			faces_list.add_item(title)
		faces_list.select(int(_last.faces))
		faces_list.item_selected.connect(func(index: int) -> void:
			_last.faces = index)
		box.add_child(faces_list)
		_add_foil_row(box)


	func _add_foil_row(box: VBoxContainer) -> void:
		foil_check = CheckBox.new()
		foil_check.name = prefix + "Foil"
		foil_check.text = FOIL
		foil_check.button_pressed = bool(memory.get("foil", true))
		foil_check.add_theme_color_override("font_color", OriginalDialog.CHOICE)
		foil_check.toggled.connect(func(on: bool) -> void:
			memory.foil = on)
		box.add_child(foil_check)


	func _source_id() -> String:
		var index := source_list.selected
		return "" if index < 0 else String(source_list.get_item_metadata(index))


	func _select_source(id: String) -> void:
		for i in source_list.item_count:
			if String(source_list.get_item_metadata(i)) == id:
				source_list.select(i)
				return
		source_list.select(0)


	## The check line and Go, after any change to the source or the list.
	func _refresh() -> void:
		var id := _source_id()
		if id == LIST:
			var checked := check_list(list_box.text)
			var found: Array = checked.found
			var unknown: Array = checked.unknown
			var words := "No cards yet." if found.is_empty() \
				else "%d card%s found." % [found.size(), "" if found.size() == 1 else "s"]
			if not unknown.is_empty():
				var shown := unknown.slice(0, 6)
				words += " Not in the game: %s%s" % [", ".join(shown),
					", ..." if unknown.size() > shown.size() else "."]
			check_label.text = words
			go_button.disabled = found.is_empty()
		else:
			var count := pool_for(id, "").size()
			check_label.text = "%d cards." % count
			go_button.disabled = count == 0


	## The cards Go deals from.
	func _pool() -> Array[String]:
		return pool_for(_source_id(), list_box.text)


	## The set whose printings the show draws, or "" for each card's own.
	func _printing() -> String:
		var id := _source_id()
		return id if id != "" and id != LIST else ""


	## The show Go starts, not yet in the tree.
	func _make_show(pool: Array[String]) -> DemoScreen:
		var show_now := DemoScreen.new()
		show_now.pool = pool
		show_now.printing = _printing()
		show_now.mode = mode_list.selected
		show_now.faces = faces_list.selected
		show_now.foil = foil_check.button_pressed
		return show_now


	## Go: the show over everything, this window hidden under it.
	func start() -> void:
		var pool := _pool()
		if pool.is_empty():
			return
		demo = _make_show(pool)
		demo.left.connect(_show_left)
		# Its own layer, over the shell's own layers too.
		_show_layer = CanvasLayer.new()
		_show_layer.layer = 90
		_show_layer.add_child(demo)
		get_viewport().gui_release_focus()
		visible = false
		if is_instance_valid(_previous):
			_previous.visible = false
		get_tree().root.add_child(_show_layer)


	func _show_left() -> void:
		if is_instance_valid(_show_layer):
			_show_layer.queue_free()
		_show_layer = null
		demo = null
		if is_instance_valid(_previous):
			_previous.visible = true
		visible = true
		if is_inside_tree():
			go_button.grab_focus()


	## Back: the window goes, Options is as it was, the keyboard and the pad
	## on the button that opened it.
	func close() -> void:
		if is_instance_valid(_show_layer):
			_show_layer.queue_free()
		if is_instance_valid(_previous):
			var button := _previous.find_child(opener, true, false) as Control
			if button != null and button.is_visible_in_tree():
				button.grab_focus()
		queue_free()


	func _unhandled_input(event: InputEvent) -> void:
		if not visible or demo != null:
			return
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			close()


	func _exit_tree() -> void:
		if is_instance_valid(_show_layer):
			_show_layer.queue_free()


class DemoScreen extends Control:
	## The demo screen: cards from [member pool] laid out for looking at, in
	## one of its shows ([enum Mode]). Opened by [DemoSetup]; a click, Esc,
	## a pad's A or B goes back to it, R (a pad's Y) deals new cards, Space (a
	## pad's Start) pauses, and the screenshot key saves the screen as a
	## picture at the window's full resolution.
	##
	## Every card is the game's own renderer — [CardPreview] for a whole card,
	## [MiniCard] for the table's small one — so the art is whatever the
	## player's packs carry and the backs are the skin's, as in a duel.
	##
	## MORE CARDS ON A BIGGER SCREEN. The game lays out on 1280x800 and
	## stretches that to the window, which alone would show a 4K screen the
	## same twenty cards, only larger. [method density_scale] shrinks the
	## cards by the square root of the stretch instead, so a screen with
	## twice the pixels each way shows twice as many cards, each still bigger
	## on the glass than at 1280x800.

	signal left

	enum Mode { SOLITAIRE, MESS, COLLECTOR_BIG, COLLECTOR_SMALL, FLIP_WALL, CARD_RAIN }
	enum Faces { FRONT, BACK, BOTH }
	const MODE_TITLES: Array[String] = ["Solitaire end", "Mess table",
		"Collector table big", "Collector table small", "Flip wall", "Card rain"]
	const FACES_TITLES: Array[String] = ["Card fronts", "Card backs",
		"Fronts and backs"]

	## A click or key this soon after Go is the one that pressed Go.
	const SETTLE_MS := 300
	## The deal builds cards for at most this long per frame, so a big table
	## comes down card by card instead of freezing the screen.
	const BUILD_BUDGET_MS := 6
	## How long a note ("Saved: ...") stays up.
	const NOTE_SECONDS := 3.0

	## The collector tables: the whole card at half size, or the table's small
	## card at its own; the pocket gap between them and the edge around them.
	const BIG_SCALE := 0.5
	const SMALL_SCALE := 1.0
	const BIG_GAP := 14.0
	const SMALL_GAP := 10.0
	const EDGE := 22.0
	## A rare card's glint passes once in this many seconds.
	const FOIL_PERIOD := 9.0

	## The mess: cards a little under half size, enough of them to cover the
	## table this many times over.
	const MESS_SCALE := 0.42
	const MESS_COVER := 2.4
	const MESS_MIN := 12
	const MESS_MAX := 240

	## Solitaire's end: four foundations of thirteen at the top right, one
	## card in flight at a time, stepped sixty times a second whatever the
	## frame rate. Speeds are per step in units of a 480-row screen, the
	## height the 1990s original played on, so the arcs keep their shape on
	## any window.
	const SOL_SCALE := 0.36
	const SOL_PILES := 4
	const SOL_PILE_CARDS := 13
	const STEP := 1.0 / 60.0
	const GRAVITY := 1.0
	const BOUNCE := 0.75
	const SPEED_X := Vector2(2.5, 8.0)
	const LIFT := 10.0
	## Most cards leave to the left, across the whole table.
	const LEFTWARD := 0.75
	## Copies of the flying card, so a frame that runs two or three steps
	## still leaves every one of them in the trail.
	const STAMPS := 3
	## After the last card has gone, the finished screen stays this long
	## before a new deal.
	const SOL_REST := 2.5

	## The flip wall: the big collector table, one card turning over every
	## so often, each turn this long a half.
	const FLIP_EVERY := 0.6
	const FLIP_HALF := 0.18
	## A wall of fronts: how long a card lies face down before it comes up
	## as another card.
	const FLIP_HOLD := 1.2

	## The card rain: enough cards to cover this much of the screen at once,
	## at depths from far (small, slow, dim) to near; a fall from top to
	## bottom takes [constant RAIN_FALL] seconds for the nearest.
	const RAIN_COVER := 0.9
	const RAIN_MIN := 8
	const RAIN_MAX := 90
	const RAIN_DEPTH := Vector2(0.45, 1.0)
	const RAIN_FALL := 9.0
	## How fast a falling card turns over (radians a second, either way) and
	## spins flat on the glass.
	const RAIN_TURN := Vector2(0.6, 2.2)
	const RAIN_SPIN := 0.5

	const SOLITAIRE_GREEN := Color8(0, 128, 0)
	const FELT := [Color(0.13, 0.45, 0.20), Color(0.03, 0.15, 0.07)]
	const VELVET := [Color(0.17, 0.14, 0.22), Color(0.04, 0.03, 0.06)]

	var pool: Array[String] = []
	## The set whose printings to show, or "" for each card's own.
	var printing := ""
	var mode: int = Mode.SOLITAIRE
	var faces: int = Faces.FRONT
	## Rare cards wear a passing glint of foil on the collector tables and
	## the flip wall.
	var foil := true
	var rng := RandomNumberGenerator.new()
	var paused := false

	## Everything one deal put down; a new deal frees it whole.
	var _table: Control
	var _note: Label
	var _note_left := 0.0
	var _jobs: Array[Callable] = []
	var _phys := 1.0
	var _opened_ms := 0
	var _leaving := false
	var _resize_due := -1.0
	## The screen the deal was laid out for.
	var _view := Vector2.ZERO
	## Set while a show changes the viewport's text sharpness.
	var _sharpening := false

	var _sol_card := Vector2.ZERO
	var _unit := 1.0
	var _piles: Array = []
	var _pile_spots: Array[Vector2] = []
	var _pile_faces: Array[CardPreview] = []
	var _trail: SubViewport
	var _stamps: Array[CardPreview] = []
	var _flying := false
	var _pos := Vector2.ZERO
	var _vel := Vector2.ZERO
	var _next_pile := 0
	var _acc := 0.0
	var _rest := 0.0

	## The flip wall's cards (each the turning part of its pocket).
	var _flippers: Array[Control] = []
	var _flip_left := 0.0
	## The rain: one entry per falling card.
	var _drops: Array[Dictionary] = []

	static var _foil_shader: Shader


	func _ready() -> void:
		rng.randomize()
		_opened_ms = Time.get_ticks_msec()
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_note = Label.new()
		_note.name = "DemoNote"
		_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_note.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_note.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_note.position.y -= 40.0
		_note.add_theme_font_size_override("font_size", 16)
		_note.add_theme_constant_override("outline_size", 6)
		_note.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_note.visible = false
		_note.z_index = 10
		add_child(_note)
		get_viewport().size_changed.connect(_on_resized)
		regenerate()


	# ------------------------------------------------------------ the maths --

	## How much smaller than at 1280x800 a card is drawn on a window stretched
	## [param phys] times: the square root, so the count grows with the screen
	## and each card still grows a little too. Never larger than the layout's
	## own size.
	static func density_scale(phys: float) -> float:
		return 1.0 / sqrt(maxf(phys, 1.0))


	## Columns and rows of [param card]-sized pockets, [param gap] apart, that
	## fit [param view] inside an [param edge]; at least one of each.
	static func grid_fit(view: Vector2, card: Vector2, gap: float, edge: float) -> Vector2i:
		var cols := int(floor((view.x - 2.0 * edge + gap) / (card.x + gap)))
		var rows := int(floor((view.y - 2.0 * edge + gap) / (card.y + gap)))
		return Vector2i(maxi(cols, 1), maxi(rows, 1))


	## How many cards cover [param view] [constant MESS_COVER] times over.
	static func mess_count(view: Vector2, card: Vector2) -> int:
		var area := maxf(card.x * card.y, 1.0)
		return clampi(ceili(MESS_COVER * view.x * view.y / area), MESS_MIN, MESS_MAX)


	## A binder's order: white, blue, black, red, green, gold, artifacts,
	## lands.
	static func colour_rank(d: CardData) -> int:
		if d.is_land():
			return 7
		var mask := d.color_mask()
		if mask == 0:
			return 6
		return int({Mtg.ManaColor.W: 0, Mtg.ManaColor.U: 1, Mtg.ManaColor.B: 2,
			Mtg.ManaColor.R: 3, Mtg.ManaColor.G: 4}.get(mask, 5))


	static func _binder_order(a: String, b: String) -> bool:
		var ra := colour_rank(CardRegistry.get_card(a))
		var rb := colour_rank(CardRegistry.get_card(b))
		return ra < rb if ra != rb else a < b


	## One step of a flying card: it moves, falls, and bounces off
	## [param floor_y] losing a quarter of its speed. Returns the new
	## position and velocity.
	static func fly(pos: Vector2, vel: Vector2, unit: float, floor_y: float) -> Array[Vector2]:
		pos += vel
		vel.y += GRAVITY * unit
		if pos.y > floor_y:
			pos.y = floor_y
			vel.y = -vel.y * BOUNCE
		return [pos, vel]


	# ------------------------------------------------------------- the deal --

	## A new deal of the same show: new cards, new places.
	func regenerate() -> void:
		_jobs.clear()
		_trail = null
		_stamps.clear()
		_pile_faces.clear()
		_piles.clear()
		_flying = false
		_acc = 0.0
		_rest = 0.0
		_flippers.clear()
		_flip_left = FLIP_EVERY
		_drops.clear()
		if _table != null:
			remove_child(_table)
			_table.queue_free()
		var view := get_viewport_rect().size
		_view = view
		_phys = _phys_scale()
		_table = Control.new()
		_table.name = "DemoTable"
		_table.size = view
		_table.clip_contents = true
		_table.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_table.process_mode = Node.PROCESS_MODE_DISABLED if paused \
			else Node.PROCESS_MODE_INHERIT
		add_child(_table)
		move_child(_table, 0)
		_table.add_child(_ground())
		if pool.is_empty():
			return
		_deal_show(view)


	## This show's cards on the new table.
	func _deal_show(view: Vector2) -> void:
		if mode == Mode.SOLITAIRE:
			_deal_solitaire(view)
		elif mode == Mode.MESS:
			_deal_mess(view)
		elif mode == Mode.CARD_RAIN:
			_deal_rain(view)
		else:
			_deal_collector(view, mode != Mode.COLLECTOR_SMALL)


	## How many window pixels one layout pixel is.
	func _phys_scale() -> float:
		var view := get_viewport_rect().size
		var window := get_window()
		if window == null or view.y <= 0.0 or window.size.y <= 0:
			return 1.0
		return maxf(float(window.size.y) / view.y, 0.25)


	func _ground() -> Control:
		if mode == Mode.SOLITAIRE:
			var flat := ColorRect.new()
			flat.color = SOLITAIRE_GREEN
			flat.size = _view
			flat.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return flat
		var colours: Array = VELVET if mode != Mode.MESS else FELT
		var gradient := Gradient.new()
		gradient.set_color(0, colours[0])
		gradient.set_color(1, colours[1])
		var fill := GradientTexture2D.new()
		fill.gradient = gradient
		fill.fill = GradientTexture2D.FILL_RADIAL
		fill.fill_from = Vector2(0.5, 0.5)
		fill.fill_to = Vector2(1.1, 1.1)
		fill.width = 256
		fill.height = 256
		var ground := TextureRect.new()
		ground.texture = fill
		ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ground.stretch_mode = TextureRect.STRETCH_SCALE
		ground.size = _view
		ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return ground


	## [param count] names from the pool, each once while the pool lasts.
	func _pick(count: int) -> Array[String]:
		var out: Array[String] = []
		while out.size() < count:
			var round_of := pool.duplicate()
			for i in range(round_of.size() - 1, 0, -1):
				var j := rng.randi_range(0, i)
				var keep: String = round_of[i]
				round_of[i] = round_of[j]
				round_of[j] = keep
			for card_name in round_of:
				if out.size() >= count:
					break
				out.append(String(card_name))
		return out


	func _wants_back() -> bool:
		if faces == Faces.BOTH:
			return rng.randf() < 0.5
		return faces == Faces.BACK


	## One card as the game draws it: whole ([param big]) or the table's
	## small card; face up, or its back.
	func _face(card_name: String, big: bool, back: bool) -> Control:
		if big:
			var preview := CardPreview.new()
			preview.docked = true
			_dress(preview, card_name, back)
			return preview
		var mini := MiniCard.new(CardInstance.new(CardRegistry.get_card(card_name), -1, 0))
		# The widget's own switch, as the duel turns a card down; the
		# instance's flag alone leaves the face showing.
		mini.face_down = back
		if not back and printing != "":
			var art := CardPrintings.texture(card_name, printing)
			if art != null:
				mini.art_override = art
				mini.refresh()
		mini.disabled = true
		mini.focus_mode = Control.FOCUS_NONE
		return mini


	func _dress(preview: CardPreview, card_name: String, back: bool) -> void:
		if back:
			preview.show_back()
		else:
			preview.show_card(CardInstance.new(CardRegistry.get_card(card_name), -1, 0),
				printing)


	func _is_rare(card_name: String) -> bool:
		return CardRegistry.rarity_of(card_name, printing) == "rare"


	## Nothing on the table takes the mouse: a click anywhere is "back".
	static func _quiet(node: Node) -> void:
		if node is Control:
			(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			(node as Control).tooltip_text = ""
		for child in node.get_children():
			_quiet(child)


	# ------------------------------------------------------- collector table --

	func _deal_collector(view: Vector2, big: bool) -> void:
		var f := density_scale(_phys)
		var native := CardPreview.SIZE if big else MiniCard.SIZE
		var card := native * (BIG_SCALE if big else SMALL_SCALE) * f
		var gap := (BIG_GAP if big else SMALL_GAP) * f
		var grid := grid_fit(view, card, gap, EDGE * f)
		var names := _pick(grid.x * grid.y)
		if mode != Mode.FLIP_WALL:
			names.sort_custom(_binder_order)
		var pitch := card + Vector2.ONE * gap
		var used := Vector2(grid) * pitch - Vector2.ONE * gap
		var origin := ((view - used) * 0.5).floor()
		var pocket := _pocket_style(f)
		for i in names.size():
			var at := origin + Vector2(i % grid.x, floori(float(i) / grid.x)) * pitch
			var card_name := names[i]
			_jobs.append(func() -> void:
				_put_collector_card(card_name, at, card, native, big, gap * 0.3, pocket))


	func _put_collector_card(card_name: String, at: Vector2, card: Vector2,
			native: Vector2, big: bool, pad: float, pocket: StyleBox) -> void:
		var holder := Control.new()
		holder.position = at
		holder.size = card
		holder.pivot_offset = card * 0.5
		var sleeve := Panel.new()
		sleeve.add_theme_stylebox_override("panel", pocket)
		sleeve.position = -Vector2.ONE * pad
		sleeve.size = card + Vector2.ONE * pad * 2.0
		holder.add_child(sleeve)
		# The card itself, apart from its pocket, so the flip wall can turn
		# it over in place.
		var turn := Control.new()
		turn.name = "Card"
		turn.size = card
		turn.pivot_offset = card * 0.5
		holder.add_child(turn)
		_lay_card(turn, card_name, _wants_back(), big, native)
		_quiet(holder)
		_table.add_child(holder)
		if mode == Mode.FLIP_WALL:
			_flippers.append(turn)
		holder.modulate.a = 0.0
		holder.scale = Vector2.ONE * 0.9
		var tween := holder.create_tween().set_parallel()
		tween.tween_property(holder, "modulate:a", 1.0, 0.25)
		tween.tween_property(holder, "scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


	## [param turn]'s card: [param card_name] (or its back) at the pocket's
	## size, with the foil if it is a rare face.
	func _lay_card(turn: Control, card_name: String, back: bool, big: bool,
			native: Vector2) -> void:
		for old in turn.get_children():
			turn.remove_child(old)
			old.queue_free()
		var face := _face(card_name, big, back)
		face.size = native
		face.scale = turn.size / native
		turn.add_child(face)
		if foil and not back and _is_rare(card_name):
			turn.add_child(_foil(turn.size))
		turn.set_meta("card_name", card_name)
		turn.set_meta("back", back)


	# -------------------------------------------------------------- flip wall --

	func _flip_tick(delta: float) -> void:
		if _flippers.is_empty() or not _jobs.is_empty():
			return
		_flip_left -= delta
		if _flip_left > 0.0:
			return
		_flip_left = FLIP_EVERY
		flip_one()


	## Turn one card that is not already turning over, as a card turns: it
	## narrows to an edge and opens again showing its other side. On a wall
	## of fronts the card lies face down a moment and comes back up as
	## another card; otherwise it stays as it landed, a back turned up, a
	## card turned down. Returns the turn's tween.
	func flip_one() -> Tween:
		var still := _flippers.filter(func(turn: Control) -> bool:
			return is_instance_valid(turn) and not turn.get_meta("turning", false))
		if still.is_empty():
			return null
		var turn: Control = still[rng.randi_range(0, still.size() - 1)]
		turn.set_meta("turning", true)
		var tween := turn.create_tween()
		_half_turns(tween, turn)
		if faces == Faces.FRONT:
			tween.tween_interval(FLIP_HOLD)
			_half_turns(tween, turn)
		tween.tween_callback(func() -> void: turn.set_meta("turning", false))
		return tween


	## One turn over: to the edge, the other side, open again.
	func _half_turns(tween: Tween, turn: Control) -> void:
		tween.tween_property(turn, "scale:x", 0.0, FLIP_HALF) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(_turn_over.bind(turn))
		tween.tween_property(turn, "scale:x", 1.0, FLIP_HALF) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


	## The other side of a card: a face turns down to its back, a back turns
	## up as a card.
	func _turn_over(turn: Control) -> void:
		var back := not bool(turn.get_meta("back", false))
		var card_name: String = turn.get_meta("card_name", pool[0])
		if not back:
			card_name = _pick(1)[0]
		_lay_card(turn, card_name, back, true, CardPreview.SIZE)
		_quiet(turn)


	# -------------------------------------------------------------- card rain --

	## Cards falling straight down, far ones small, slow and dim behind near
	## ones, each turning over as it falls — its back is the card back — and
	## spinning slowly flat on the glass. The screen starts full, and a card
	## that falls out of the bottom comes back in at the top as another
	## card.
	func _deal_rain(view: Vector2) -> void:
		var f := density_scale(_phys)
		var near := CardPreview.SIZE * MESS_SCALE * f
		var count := clampi(ceili(RAIN_COVER * view.x * view.y / (near.x * near.y * 0.55)),
			RAIN_MIN, RAIN_MAX)
		var depths: Array[float] = []
		for i in count:
			depths.append(rng.randf_range(RAIN_DEPTH.x, RAIN_DEPTH.y))
		depths.sort()
		for depth in depths:
			var y := rng.randf_range(-near.y, view.y)
			_jobs.append(func() -> void: _put_drop(depth, y, near, view))


	func _put_drop(depth: float, y: float, near: Vector2, view: Vector2) -> void:
		var holder := Control.new()
		holder.size = CardPreview.SIZE
		holder.pivot_offset = CardPreview.SIZE * 0.5
		holder.scale = Vector2.ONE * (near.x / CardPreview.SIZE.x) * depth
		var shade := lerpf(0.45, 1.0, inverse_lerp(RAIN_DEPTH.x, RAIN_DEPTH.y, depth))
		holder.modulate = Color(shade, shade, shade, 0.0)
		# The turning part, and the card's two sides in it.
		var turn := Control.new()
		turn.size = CardPreview.SIZE
		turn.pivot_offset = CardPreview.SIZE * 0.5
		holder.add_child(turn)
		var face := CardPreview.new()
		face.docked = true
		turn.add_child(face)
		var back := CardPreview.new()
		back.docked = true
		back.show_back()
		turn.add_child(back)
		_quiet(holder)
		_table.add_child(holder)
		var drop := {"node": holder, "turn": turn, "face": face, "back": back,
			"depth": depth, "y": y}
		_respawn(drop, view, false)
		drop.y = y
		_drops.append(drop)
		holder.create_tween().tween_property(holder, "modulate:a", 1.0, 0.4)
		_place_drop(drop)


	## A drop back at the top as another card, on a new path.
	func _respawn(drop: Dictionary, view: Vector2, at_top: bool) -> void:
		var height: float = CardPreview.SIZE.y * (drop.node as Control).scale.y
		drop.x = rng.randf_range(-0.05, 1.05) * view.x
		if at_top:
			drop.y = -height
		drop.speed = view.y / RAIN_FALL * float(drop.depth) * rng.randf_range(0.85, 1.15)
		drop.spin = rng.randf() * TAU
		drop.spin_rate = rng.randf_range(-RAIN_SPIN, RAIN_SPIN)
		# Which side it starts on is the window's Cards choice; the turning
		# shows the other one soon enough.
		drop.flip = (PI if _wants_back() else 0.0) + rng.randf_range(-0.6, 0.6)
		drop.flip_rate = rng.randf_range(RAIN_TURN.x, RAIN_TURN.y) \
			* (1.0 if rng.randf() < 0.5 else -1.0)
		_dress(drop.face, _pick(1)[0], false)


	func _rain_tick(delta: float) -> void:
		for drop in _drops:
			drop.y = float(drop.y) + float(drop.speed) * delta
			drop.spin = float(drop.spin) + float(drop.spin_rate) * delta
			drop.flip = fmod(float(drop.flip) + float(drop.flip_rate) * delta, TAU)
			var size_now: Vector2 = CardPreview.SIZE * (drop.node as Control).scale
			if float(drop.y) - size_now.y > _view.y:
				_respawn(drop, _view, true)
			_place_drop(drop)


	## Where a falling card is and which way it faces: straight down its
	## column, turned flat by its spin, and narrowed by its turn — the face
	## while the face is towards the glass, the back while the back is,
	## both a little darker edge-on.
	func _place_drop(drop: Dictionary) -> void:
		var holder: Control = drop.node
		holder.position = Vector2(float(drop.x), float(drop.y)) - CardPreview.SIZE * 0.5
		holder.rotation = float(drop.spin)
		var facing := cos(float(drop.flip))
		var turn: Control = drop.turn
		turn.scale = Vector2(maxf(absf(facing), 0.02), 1.0)
		var light := 0.7 + 0.3 * absf(facing)
		turn.modulate = Color(light, light, light)
		(drop.face as Control).visible = facing >= 0.0
		(drop.back as Control).visible = facing < 0.0


	static func _pocket_style(f: float) -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(1, 1, 1, 0.05)
		box.border_color = Color(1, 1, 1, 0.10)
		box.set_border_width_all(1)
		box.set_corner_radius_all(int(round(6.0 * f)))
		box.shadow_color = Color(0, 0, 0, 0.35)
		box.shadow_size = int(round(4.0 * f))
		return box


	## A rare card's foil: a band of rainbow light that sweeps across it now
	## and then, each card on its own clock.
	func _foil(card: Vector2) -> ColorRect:
		if _foil_shader == null:
			_foil_shader = Shader.new()
			_foil_shader.code = """
	shader_type canvas_item;
	render_mode blend_add;
	uniform float period = 9.0;
	uniform float offset = 0.0;
	void fragment() {
		float t = mod(TIME + offset, period) / period * 4.0 - 1.0;
		float d = UV.x * 0.6 + UV.y * 0.4 - t;
		float band = smoothstep(0.12, 0.0, abs(d));
		vec3 hue = 0.6 + 0.4 * cos(6.2831 * (UV.y * 1.2 + t + vec3(0.0, 0.33, 0.67)));
		COLOR = vec4(hue, band * 0.45);
	}
	"""
		var glint := ColorRect.new()
		glint.name = "Foil"
		glint.size = card
		var shading := ShaderMaterial.new()
		shading.shader = _foil_shader
		shading.set_shader_parameter("period", FOIL_PERIOD)
		shading.set_shader_parameter("offset", rng.randf() * FOIL_PERIOD)
		glint.material = shading
		return glint


	# ------------------------------------------------------------ mess table --

	## Cards dropped all over the table at every angle. The places are a
	## shuffled, jittered grid over a little more than the screen, so the
	## table is covered without holes and without a pattern.
	func _deal_mess(view: Vector2) -> void:
		var card := CardPreview.SIZE * MESS_SCALE * density_scale(_phys)
		var count := mess_count(view, card)
		var span := view * 1.1
		var cols := maxi(1, int(ceil(sqrt(count * span.x / span.y))))
		var rows := maxi(1, int(ceil(float(count) / cols)))
		var cell := span / Vector2(cols, rows)
		var cells: Array[int] = []
		for i in cols * rows:
			cells.append(i)
		for i in range(cells.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var keep := cells[i]
			cells[i] = cells[j]
			cells[j] = keep
		var names := _pick(cells.size())
		var shadow := _shadow_style(density_scale(_phys))
		for i in cells.size():
			var at := Vector2(cells[i] % cols, floori(float(cells[i]) / cols)) * cell \
				+ Vector2(rng.randf(), rng.randf()) * cell - view * 0.05
			var turn := rng.randf() * TAU
			var card_name := names[i]
			_jobs.append(func() -> void:
				_put_mess_card(card_name, at, turn, card, shadow))


	func _put_mess_card(card_name: String, centre: Vector2, turn: float,
			card: Vector2, shadow: StyleBox) -> void:
		var holder := Control.new()
		holder.size = card
		holder.pivot_offset = card * 0.5
		holder.position = centre - card * 0.5
		holder.rotation = turn
		var shade := Panel.new()
		shade.add_theme_stylebox_override("panel", shadow)
		shade.size = card
		shade.position = Vector2(4, 6) * card.x / 126.0
		holder.add_child(shade)
		var face := _face(card_name, true, _wants_back())
		face.scale = card / CardPreview.SIZE
		holder.add_child(face)
		_quiet(holder)
		_table.add_child(holder)
		holder.modulate.a = 0.0
		holder.scale = Vector2.ONE * 1.3
		var tween := holder.create_tween().set_parallel()
		tween.tween_property(holder, "modulate:a", 1.0, 0.18)
		tween.tween_property(holder, "scale", Vector2.ONE, 0.22) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


	static func _shadow_style(f: float) -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0, 0, 0, 0.4)
		box.set_corner_radius_all(int(round(8.0 * f)))
		return box


	# ------------------------------------------------------- solitaire's end --

	## THE TRAIL is a picture that is never wiped: a [SubViewport] that clears
	## once and then keeps every frame's drawing, so the flying card only has
	## to be drawn where it is now and the whole history stays on the glass.
	## It renders at the window's own resolution, so the trail is as sharp as
	## the cards over it.
	func _deal_solitaire(view: Vector2) -> void:
		var f := density_scale(_phys)
		_sol_card = CardPreview.SIZE * SOL_SCALE * f
		_unit = view.y / 480.0
		var gap := 12.0 * f
		var margin := 16.0 * f
		_pile_spots.clear()
		for i in SOL_PILES:
			_pile_spots.append(Vector2(
				view.x - margin - (SOL_PILES - i) * (_sol_card.x + gap) + gap, margin))
		var names := _pick(SOL_PILES * SOL_PILE_CARDS)
		for i in SOL_PILES:
			var pile: Array = []
			for k in SOL_PILE_CARDS:
				pile.append({"name": names[i * SOL_PILE_CARDS + k], "back": _wants_back()})
			_piles.append(pile)

		var sharp := maxf(_phys, 1.0)
		_trail = SubViewport.new()
		_trail.name = "Trail"
		_trail.transparent_bg = true
		_trail.disable_3d = true
		_trail.gui_disable_input = true
		_trail.size = Vector2i((view * sharp).round())
		_trail.size_2d_override = Vector2i(view.round())
		_trail.size_2d_override_stretch = true
		# Letters drawn at the size they end up on the glass: the stamps are
		# whole cards at a third of their size, and a glyph cut at full size
		# and shrunk that far breaks up.
		_trail.oversampling_override = sharp * SOL_SCALE * f
		_trail.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_trail.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
		_table.add_child(_trail)
		# The empty foundations are drawn on the table, so the trails pass
		# over them.
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color(0, 0, 0, 0)
		slot_style.border_color = Color(0.0, 0.32, 0.0)
		slot_style.set_border_width_all(maxi(1, int(round(2.0 * f))))
		slot_style.set_corner_radius_all(int(round(6.0 * f)))
		for i in SOL_PILES:
			var slot := Panel.new()
			slot.add_theme_stylebox_override("panel", slot_style)
			slot.position = _pile_spots[i]
			slot.size = _sol_card
			_table.add_child(slot)
		for i in STAMPS:
			var stamp := CardPreview.new()
			stamp.docked = true
			stamp.scale = Vector2.ONE * SOL_SCALE * f
			stamp.visible = false
			_trail.add_child(stamp)
			_stamps.append(stamp)
		var shown := TextureRect.new()
		shown.name = "TrailView"
		shown.texture = _trail.get_texture()
		shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shown.stretch_mode = TextureRect.STRETCH_SCALE
		shown.size = view
		shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_table.add_child(shown)

		for i in SOL_PILES:
			var face := CardPreview.new()
			face.docked = true
			face.position = _pile_spots[i]
			face.scale = Vector2.ONE * SOL_SCALE * f
			_table.add_child(face)
			_pile_faces.append(face)
			_show_pile(i)
		_quiet(_table)


	func _show_pile(i: int) -> void:
		var face := _pile_faces[i]
		if _piles[i].is_empty():
			face.visible = false
			return
		var top: Dictionary = _piles[i].back()
		_dress(face, String(top.name), bool(top.back))


	func _solitaire_tick(delta: float) -> void:
		# Never more than a few steps to catch up after a stall: a long frame
		# would otherwise fire a burst of steps and leave a gap in the trail.
		_acc = minf(_acc + delta, STEP * (STAMPS + 0.5))
		var spots: Array[Vector2] = []
		while _acc >= STEP:
			_acc -= STEP
			if not _flying and not _launch():
				_rest += STEP
				if _rest >= SOL_REST:
					regenerate.call_deferred()
					return
				continue
			var next := fly(_pos, _vel, _unit, _view.y - _sol_card.y)
			_pos = next[0]
			_vel = next[1]
			spots.append(_pos)
			if _pos.x + _sol_card.x < 0.0 or _pos.x > _view.x:
				# Gone. The next card waits for the next frame, so the stamps
				# drawn this frame are all of this one.
				_flying = false
				break
		_place_stamps(spots)


	## The next card off the foundations, taking them in turn.
	func _launch() -> bool:
		for k in SOL_PILES:
			var i := (_next_pile + k) % SOL_PILES
			if _piles[i].is_empty():
				continue
			var card: Dictionary = _piles[i].pop_back()
			_next_pile = (i + 1) % SOL_PILES
			_pos = _pile_spots[i]
			var direction := -1.0 if rng.randf() < LEFTWARD else 1.0
			_vel = Vector2(direction * rng.randf_range(SPEED_X.x, SPEED_X.y),
				-rng.randf() * LIFT) * _unit
			for stamp in _stamps:
				_dress(stamp, String(card.name), bool(card.back))
				stamp.visible = false
			_show_pile(i)
			_flying = true
			return true
		return false


	func _place_stamps(spots: Array[Vector2]) -> void:
		var first := maxi(0, spots.size() - STAMPS)
		for k in _stamps.size():
			var index := first + k
			_stamps[k].visible = index < spots.size()
			if _stamps[k].visible:
				_stamps[k].position = spots[index]


	## How many cards are still on the foundations (tests).
	func cards_left() -> int:
		var total := 0
		for pile in _piles:
			total += pile.size()
		return total


	# ------------------------------------------------------------- per frame --

	func _process(delta: float) -> void:
		if _note.visible:
			_note_left -= delta
			_note.modulate.a = clampf(_note_left, 0.0, 1.0)
			_note.visible = _note_left > 0.0
		if _resize_due >= 0.0:
			_resize_due -= delta
			if _resize_due < 0.0 and (get_viewport_rect().size != _view
					or not is_equal_approx(_phys_scale(), _phys)):
				regenerate()
		if paused:
			return
		_run_jobs()
		_tick(delta)


	## This show's moving part, once a frame while it is not paused.
	func _tick(delta: float) -> void:
		if _trail != null:
			_solitaire_tick(delta)
		elif mode == Mode.FLIP_WALL:
			_flip_tick(delta)
		elif mode == Mode.CARD_RAIN:
			_rain_tick(delta)


	func _run_jobs() -> void:
		var until := Time.get_ticks_msec() + BUILD_BUDGET_MS
		while not _jobs.is_empty():
			var job: Callable = _jobs.pop_front()
			job.call()
			if Time.get_ticks_msec() >= until:
				break


	## Cards still to be put down (tests).
	func cards_to_deal() -> int:
		return _jobs.size()


	func _on_resized() -> void:
		# The viewport says the same for a change of its text sharpness,
		# which is no new screen.
		if _sharpening:
			return
		# A drag of the window edge sends a stream of these; deal once it stops.
		_resize_due = 0.3


	func set_paused(on: bool) -> void:
		paused = on
		if _table != null:
			_table.process_mode = Node.PROCESS_MODE_DISABLED if on \
				else Node.PROCESS_MODE_INHERIT
		if on:
			say("Paused")
		elif _note.text == "Paused":
			_note.visible = false


	# ----------------------------------------------------------------- input --

	## Every key and button is the show's while it is up: nothing reaches the
	## screens under it.
	func _input(event: InputEvent) -> void:
		if not is_visible_in_tree() or _leaving:
			return
		var key := event as InputEventKey
		var mouse := event as InputEventMouseButton
		var pad := event as InputEventJoypadButton
		var touch := event as InputEventScreenTouch
		if key == null and mouse == null and pad == null and touch == null:
			return
		get_viewport().set_input_as_handled()
		if not event.is_pressed() or event.is_echo():
			return
		if Time.get_ticks_msec() - _opened_ms < SETTLE_MS:
			return
		if key != null:
			if Controls.pressed(event, "duel_screenshot"):
				save_picture()
			elif key.keycode == KEY_R:
				regenerate()
			elif key.keycode == KEY_SPACE or key.keycode == KEY_P:
				set_paused(not paused)
			elif key.keycode == KEY_ESCAPE or event.is_action("ui_cancel"):
				leave()
		elif mouse != null:
			if mouse.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT,
					MOUSE_BUTTON_MIDDLE]:
				leave()
		elif pad != null:
			if pad.button_index in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_BACK]:
				leave()
			elif pad.button_index in [JOY_BUTTON_Y, JOY_BUTTON_X]:
				regenerate()
			elif pad.button_index == JOY_BUTTON_START:
				set_paused(not paused)
		else:
			leave()


	## The screen as it is now, at the window's resolution, into the game's
	## folder beside the duel's screenshots.
	func save_picture() -> void:
		var shot := get_viewport().get_texture().get_image()
		var path := "user://screenshot_%d.png" % Time.get_ticks_msec()
		var err := ERR_INVALID_DATA
		if shot != null and not shot.is_empty():
			err = shot.save_png(path)
		say("Saved: %s" % ProjectSettings.globalize_path(path) if err == OK
			else "The picture could not be saved (%s)." % error_string(err))


	func say(text: String) -> void:
		_note.text = text
		_note.reset_size()
		_note.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM,
			Control.PRESET_MODE_KEEP_SIZE, 30)
		_note_left = NOTE_SECONDS
		_note.modulate.a = 1.0
		_note.visible = true


	func leave() -> void:
		if _leaving:
			return
		_leaving = true
		left.emit()
		queue_free()


# ----------------------------------------------------- draw random cards --

class DrawSetup extends DemoSetup:
	## The `Draw random card(s)` window, opened from Options: which cards (a
	## set, every set or a list, as the demo window has them), the Deck
	## Builder's colour medallions, how many (one to seven), and Go. A list
	## shorter than the number asked for is drawn whole.

	const DRAW_TITLE := "Draw random card(s)"
	const COLOURS := "Colours:"
	const COLOUR_NOTE := "As in the Deck Builder: lands and colourless cards are always in."
	const HOW_MANY := "How many:"

	static var _kept := {"source": "", "list": "", "colours": [true, true, true, true, true],
		"gold": true, "count": 1, "foil": true}

	var count_list: OptionButton
	## The five colour medallions, then Gold.
	var colour_buttons: Array[Button] = []


	func _init() -> void:
		memory = _kept
		opener = "DrawCards"
		prefix = "Draw"


	## Open the window over [param previous] (the Options screen).
	static func draw_on(previous: Control) -> DrawSetup:
		var setup := DrawSetup.new()
		setup._previous = previous
		previous.add_child(setup)
		return setup


	## [param names] as the Deck Builder's Color Filters would show them:
	## [param colours] lit in [constant DeckFilter.COLOR_ORDER], and the Gold
	## button for multicoloured cards.
	static func colour_pool(names: Array[String], colours: Array, gold: bool) -> Array[String]:
		var filter := DeckFilter.new()
		for i in DeckFilter.COLOR_ORDER.size():
			if not bool(colours[i]):
				filter.toggle_color(DeckFilter.COLOR_ORDER[i])
		filter.gold = gold
		var out: Array[String] = []
		for card_name in names:
			var d := CardRegistry.get_card(card_name)
			if d != null and filter.matches_color(d):
				out.append(card_name)
		return out


	func _title() -> String:
		return DRAW_TITLE


	func _keys_text() -> String:
		return keys_text("draw again", "draws again")


	func _add_show_rows(box: VBoxContainer) -> void:
		box.add_child(OriginalDialog.label(COLOURS, 14, true))
		var row := HBoxContainer.new()
		row.name = "DrawColours"
		row.add_theme_constant_override("separation", 6)
		colour_buttons.clear()
		for i in DeckFilter.COLOR_ORDER.size():
			var color := DeckFilter.COLOR_ORDER[i]
			row.add_child(_medallion(String(DeckFilter.COLOR_LABELS[color]),
				FilterBar.COLOR_CELL[color], bool(memory.colours[i]),
				func(on: bool) -> void: memory.colours[i] = on))
		row.add_child(_medallion("Gold", FilterBar.GOLD_CELL, bool(memory.gold),
			func(on: bool) -> void: memory.gold = on))
		box.add_child(row)
		box.add_child(OriginalDialog.wrapped(COLOUR_NOTE, 12))

		box.add_child(OriginalDialog.label(HOW_MANY, 14, true))
		count_list = OptionButton.new()
		count_list.name = "DrawCount"
		for n in range(1, DrawScreen.MOST + 1):
			count_list.add_item("%d card%s" % [n, "" if n == 1 else "s"])
		count_list.select(clampi(int(memory.count), 1, DrawScreen.MOST) - 1)
		count_list.item_selected.connect(func(index: int) -> void:
			memory.count = index + 1
			_refresh())
		box.add_child(count_list)
		_add_foil_row(box)


	## One of the Deck Builder's colour medallions, lit while it is on.
	func _medallion(label: String, cell: Array, on: bool, keep: Callable) -> Button:
		var button := Button.new()
		button.name = "Draw" + label
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_ALL
		FilterBar.dress_medallion(button, cell, label)
		button.set_pressed_no_signal(on)
		button.tooltip_text = DeckFilter.cue_card(label, on)
		button.toggled.connect(func(lit: bool) -> void:
			keep.call(lit)
			button.tooltip_text = DeckFilter.cue_card(label, lit)
			_refresh())
		colour_buttons.append(button)
		return button


	func _all_colours() -> bool:
		return bool(memory.gold) and not (memory.colours as Array).has(false)


	func _pool() -> Array[String]:
		return colour_pool(super(), memory.colours, bool(memory.gold))


	## The demo window's check, then what the colours leave and whether the
	## number asked for is more than there are.
	func _refresh() -> void:
		super()
		if check_label == null or go_button == null:
			return
		var usable := _pool().size()
		var words := check_label.text
		if not _all_colours() and not go_button.disabled:
			words += " %d in the chosen colours." % usable
		var wanted := int(memory.count)
		if usable > 0 and usable < wanted:
			words += " Fewer than %d, so all %d are drawn." % [wanted, usable]
		check_label.text = words
		go_button.disabled = usable == 0


	func _make_show(pool: Array[String]) -> DemoScreen:
		var draw := DrawScreen.new()
		draw.pool = pool
		draw.printing = _printing()
		draw.count = int(memory.count)
		draw.foil = foil_check.button_pressed
		return draw


class DrawScreen extends DemoScreen:
	## Random cards drawn from [member pool]: each comes out of the middle
	## of the table small and face down, turning over and over and spinning
	## flat as it grows, a different card on each turn, slowing until it
	## lands face up in its place as the card drawn — one in the middle, or
	## up to [constant MOST] in one row or two. The same keys as the demo
	## screen; R draws again.
	##
	## Big cards keep sharp letters: while the draw is up the viewport's
	## text is cut at the cards' size ([method _sharpen]), as the full-screen
	## card does it.

	const MOST := 7
	## How long one card's spin takes, how far into it the card is in its
	## place, and how long after the one before it each card starts.
	const SPIN_SECONDS := 2.4
	const ARRIVE := 0.7
	const STAGGER := 0.4
	## Whole turns over in a spin; each turn shows another card.
	const TURNS := 6
	## A card starts this small, and lands no bigger than [constant
	## MOST_SCALE], the cards together at most [constant FILL] of the
	## screen's height.
	const FROM_SCALE := 0.08
	const MOST_SCALE := 1.5
	const FILL := 0.84
	const GAP := 18.0
	const SIDE_EDGE := 24.0
	## A landed card's light: how bright it flashes, then rests.
	const GLOW_FLASH := 0.95
	const GLOW_REST := 0.4

	var count := 1
	## The cards this draw lands, in their places' order.
	var drawn: Array[String] = []
	var _spinners: Array[Dictionary] = []

	static var _glow_texture: GradientTexture2D


	func _init() -> void:
		mode = Mode.COLLECTOR_BIG


	## Where [param n] drawn cards land on [param view]: one row, or two
	## when two give bigger cards (the top row the fuller). Returns the
	## cards' `scale` and each card's centre (`spots`).
	static func layout(view: Vector2, n: int) -> Dictionary:
		var best := {"scale": 0.0, "spots": [] as Array[Vector2]}
		for rows in range(1, 3):
			if rows > n:
				continue
			var cols := ceili(float(n) / rows)
			var by_width := (view.x - 2.0 * SIDE_EDGE - (cols - 1) * GAP) / cols \
				/ CardPreview.SIZE.x
			var by_height := (view.y * FILL - (rows - 1) * GAP) / rows / CardPreview.SIZE.y
			var s := minf(minf(by_width, by_height), MOST_SCALE)
			if s <= float(best.scale):
				continue
			var card := CardPreview.SIZE * s
			var top := (view.y - (rows * card.y + (rows - 1) * GAP)) * 0.5
			var spots: Array[Vector2] = []
			var left := n
			for r in rows:
				var here := mini(cols, left)
				left -= here
				var x0 := (view.x - (here * card.x + (here - 1) * GAP)) * 0.5
				for c in here:
					spots.append(Vector2(x0 + c * (card.x + GAP) + card.x * 0.5,
						top + r * (card.y + GAP) + card.y * 0.5))
			best = {"scale": s, "spots": spots}
		return best


	func _deal_show(view: Vector2) -> void:
		_spinners.clear()
		drawn = _pick(mini(count, pool.size()))
		var where := layout(view, drawn.size())
		_sharpen(float(where.scale))
		for i in drawn.size():
			_spinners.append(_spinner(drawn[i], where.spots[i], float(where.scale),
				i * STAGGER))


	func _spinner(card_name: String, spot: Vector2, s: float, delay: float) -> Dictionary:
		var holder := Control.new()
		holder.size = CardPreview.SIZE
		holder.pivot_offset = CardPreview.SIZE * 0.5
		holder.visible = false
		var glow := TextureRect.new()
		glow.name = "Glow"
		glow.texture = _glow()
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.stretch_mode = TextureRect.STRETCH_SCALE
		glow.size = CardPreview.SIZE * 1.6
		glow.position = -CardPreview.SIZE * 0.3
		glow.modulate.a = 0.0
		holder.add_child(glow)
		var turn := Control.new()
		turn.name = "Card"
		turn.size = CardPreview.SIZE
		turn.pivot_offset = CardPreview.SIZE * 0.5
		holder.add_child(turn)
		var face := CardPreview.new()
		face.docked = true
		turn.add_child(face)
		var back := CardPreview.new()
		back.docked = true
		back.show_back()
		turn.add_child(back)
		_quiet(holder)
		_table.add_child(holder)
		# A card for each turn over, the last the one drawn.
		var faces: Array[String] = []
		for k in TURNS:
			faces.append(pool[rng.randi_range(0, pool.size() - 1)])
		faces.append(card_name)
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		return {"node": holder, "turn": turn, "face": face, "back": back, "glow": glow,
			"name": card_name, "faces": faces, "shown": -1, "spot": spot, "scale": s,
			"from": _view * Vector2(0.5, 0.56) + Vector2(rng.randf_range(-0.04, 0.04), 0.0) * _view.x,
			"roll": TAU * rng.randf_range(0.6, 1.2) * side,
			"swirl": rng.randf_range(0.8, 1.6) * side,
			"tilt": 0.0 if drawn.size() == 1 else rng.randf_range(-0.03, 0.03),
			"delay": delay, "t": 0.0, "landed": false}


	func _tick(delta: float) -> void:
		for spinner in _spinners:
			if spinner.landed or not is_instance_valid(spinner.node):
				continue
			spinner.t = float(spinner.t) + delta
			_place_spinner(spinner)


	## Where a spinning card is: on a curve out of the middle to its place,
	## growing, spinning flat and turning over, all slowing to a stop — the
	## turns slowest, so the last card comes up slowly in its place.
	func _place_spinner(spinner: Dictionary) -> void:
		var holder: Control = spinner.node
		var local := float(spinner.t) - float(spinner.delay)
		holder.visible = local >= 0.0
		if local < 0.0:
			return
		var p := clampf(local / SPIN_SECONDS, 0.0, 1.0)
		var arrive := clampf(local / (SPIN_SECONDS * ARRIVE), 0.0, 1.0)
		var e := 1.0 - pow(1.0 - p, 3.0)
		var ea := 1.0 - pow(1.0 - arrive, 3.0)
		var spot: Vector2 = spinner.spot
		var away: Vector2 = (spinner.from - spot) * (1.0 - ea)
		var centre := spot + away.rotated(float(spinner.swirl) * (1.0 - ea))
		holder.scale = Vector2.ONE * float(spinner.scale) * lerpf(FROM_SCALE, 1.0, ea)
		holder.position = centre - CardPreview.SIZE * 0.5
		holder.rotation = float(spinner.tilt) + float(spinner.roll) * (1.0 - ea)
		# Face down to start with; each time the face comes round it is
		# another card, and the last time the one drawn.
		var flip := PI + (TAU * TURNS - PI) * e
		var window := clampi(roundi(flip / TAU), 1, TURNS)
		if window != int(spinner.shown):
			spinner.shown = window
			_dress(spinner.face, String(spinner.faces[window]), false)
		var facing := cos(flip)
		var turn: Control = spinner.turn
		turn.scale = Vector2(maxf(absf(facing), 0.02), 1.0)
		var light := 0.7 + 0.3 * absf(facing)
		turn.modulate = Color(light, light, light)
		(spinner.face as Control).visible = facing >= 0.0
		(spinner.back as Control).visible = facing < 0.0
		if p >= 1.0:
			_land(spinner)


	## Down: the card face up and still, a light behind it, a little bump,
	## the foil if it is rare, and the draw's sound.
	func _land(spinner: Dictionary) -> void:
		spinner.landed = true
		var holder: Control = spinner.node
		var s := float(spinner.scale)
		holder.rotation = float(spinner.tilt)
		var turn: Control = spinner.turn
		turn.scale = Vector2.ONE
		turn.modulate = Color.WHITE
		(spinner.face as Control).visible = true
		(spinner.back as Control).visible = false
		if foil and _is_rare(String(spinner.name)):
			turn.add_child(_foil(CardPreview.SIZE))
		var glow: Control = spinner.glow
		var light := holder.create_tween()
		light.tween_property(glow, "modulate:a", GLOW_FLASH, 0.12)
		light.tween_property(glow, "modulate:a", GLOW_REST, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		var bump := holder.create_tween()
		bump.tween_property(holder, "scale", Vector2.ONE * s * 1.05, 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		bump.tween_property(holder, "scale", Vector2.ONE * s, 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_sound()


	## How many have landed (tests).
	func landed() -> int:
		return _spinners.filter(func(spinner: Dictionary) -> bool: return spinner.landed).size()


	## The duel's own draw sound, from the player's imported 1997 files.
	func _sound() -> void:
		if DisplayServer.get_name() == "headless" or not Settings.sound_enabled():
			return
		var stream := GameSkin.sound("sfx_draw")
		if stream == null:
			return
		var voice := AudioStreamPlayer.new()
		voice.bus = GameAudio.SFX_BUS
		voice.stream = stream
		add_child(voice)
		voice.finished.connect(voice.queue_free)
		voice.play()


	static func _glow() -> GradientTexture2D:
		if _glow_texture == null:
			var gradient := Gradient.new()
			gradient.set_color(0, Color(1.0, 0.86, 0.55, 0.7))
			gradient.set_color(1, Color(1.0, 0.75, 0.35, 0.0))
			_glow_texture = GradientTexture2D.new()
			_glow_texture.gradient = gradient
			_glow_texture.fill = GradientTexture2D.FILL_RADIAL
			_glow_texture.fill_from = Vector2(0.5, 0.5)
			_glow_texture.fill_to = Vector2(0.5, 0.0)
			_glow_texture.width = 128
			_glow_texture.height = 128
		return _glow_texture


	## Letters cut at the size the cards land at, so a card drawn bigger
	## than the sidebar's reads as sharp; the viewport's own value again
	## when the draw goes ([method _exit_tree]).
	func _sharpen(s: float) -> void:
		var viewport := get_viewport()
		if viewport == null:
			return
		_sharpening = true
		viewport.oversampling_override = 0.0
		if s > 1.0:
			viewport.oversampling_override = viewport.get_oversampling() * s
		_sharpening = false


	func _exit_tree() -> void:
		var viewport := get_viewport()
		if viewport != null:
			_sharpening = true
			viewport.oversampling_override = 0.0
			_sharpening = false
