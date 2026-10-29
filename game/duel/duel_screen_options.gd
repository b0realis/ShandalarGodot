class_name DuelScreenOptions
extends RefCounted
## THE DUEL SCREEN'S OWN OPTIONS — `[ours]`, the polish pass of 2026-10-28.
##
## The owner, round "open items": *"Duel screen: targets and X in the log;
## Spell Chain minimize; the accessibility set (colorblind-safe mana, UI
## scale, attack-all key) — and every new duel-screen option reached only
## through ONE dedicated button under the large card."* And again, for the
## pass itself: *"All new duel screen options should be only accessible via
## a dedicated button under a large card in the duel screen."*
##
## So this is one window behind one button — the reserve strip's fourth
## tenant ([member DuelScreen._qol_reserve], beside the log, Expand and
## Arrange) — and nowhere else: not the Options screen, not a mini-menu,
## not the Pause window. The 1997 panel ([DuelOptions], `@DIALOG_DUELOPTIONS`)
## stays the 1997 panel, its nineteen strings and nothing added; this
## window only carries a door onto it at its foot.
##
## WHAT IT HOLDS — four switches, each a [Settings] key of ours (so ours
## in spelling, as `bar_frame` is), each read where it acts:
##  - **Name targets and X in the duel log** ([constant LOG_TARGETS_KEY],
##    on) — [method DuelLogText.details], read by the log window, the
##    running `duel_log.txt` and the Spell Chain's tooltips.
##  - **Colorblind-safe mana colors** ([constant COLORBLIND_KEY], off) — the
##    small cards' mana stripes become symbols ([method MiniCard.pip]).
##  - **UI scale** ([constant UI_SCALE_KEY], 100%) — the Situation Bar,
##    the dialogs and the questions, the Pause window, the mini-menus and
##    the duel log larger ([method DuelScreen._apply_ui_scale]). NOT the
##    table: the 1997 duel has one card size (`set_smallcard_size`,
##    `windows.c:1088`), and a whole-window zoom has no room on the 800
##    logical rows the duel is laid out on — the sidebar alone is the
##    428-row card and two pool panels. Nor the coin toss and the opening
##    hand's window: [OpeningWindow] is built around two full-size cards
##    that never rescale, and at 150% it would be wider than the screen —
##    so the switch's words name them (0.50.65 bug campaign, k3-3).
##  - **Attack-all key** ([constant ATTACK_ALL_KEY], on) — the key
##    `duel_attack_all` (A unless moved here) puts every creature that may
##    attack into the attack while attackers are being chosen
##    ([method DuelScreen._attack_with_everything]); where attackers are
##    final (the 1997 rule) the first press asks on the bar and a second
##    commits (k3-2). The key is a [Controls] action like every other duel
##    key, rebindable — here, in this window, and not on the Options
##    screen's list ([constant Controls.PANEL_ACTIONS]).

## The window's title line.
const TITLE := "Duel Screen Options"

## The reserve strip button's word.
const BUTTON_TIP := "Duel screen options"

## Name targets and X in the duel log. ON: the owner asked for it, and a
## log *"that should be able to really help check the engine performance
## and dig out bugs"* (2026-09-07) is the reader it serves.
const LOG_TARGETS_KEY := "duel_log_targets"
const LOG_TARGETS_DEFAULT := true
const LOG_TARGETS_LABEL := "Name targets and X in the duel log"

## Symbols in place of the colour-only stripes. OFF: the stripes are the
## 1997 look.
const COLORBLIND_KEY := "duel_colorblind_mana"
const COLORBLIND_DEFAULT := false
const COLORBLIND_LABEL := "Colorblind-safe mana colors"

## The chrome's scale.
const UI_SCALE_KEY := "duel_ui_scale"
const UI_SCALE_DEFAULT := 1.0
const UI_SCALE_LABEL := "UI scale"
## The four offered, smallest first. 150% is the most a dialog made for
## 1280x800 still fits on 800 rows (a 470-row window is 705).
const UI_SCALES: Array[float] = [1.0, 1.15, 1.3, 1.5]

## The attack-all key's switch, and the action it gates.
const ATTACK_ALL_KEY := "duel_attack_all_key"
const ATTACK_ALL_DEFAULT := true
const ATTACK_ALL_LABEL := "Attack-all key"
const ATTACK_ALL_ACTION := "duel_attack_all"

## What the scale reaches, and what keeps its size (0.50.65 bug campaign,
## k3-3: the words promised "the dialogs" while the question window and the
## Pause window stayed at 100%; both grow now, and the two opening screens,
## built around full-size cards, are named as keeping theirs).
const UI_SCALE_TIP := "The Situation Bar, the dialogs and questions, the Pause window, the menus and the duel log, larger. The cards keep their size, and so do the coin toss and the opening hand's window."

## The key's switch, in the player's words — and the 1997 rule's second
## press (k3-2: attackers that are final cannot be taken back, so one stray
## press there may not commit them all).
const ATTACK_ALL_TIP := "While you choose attackers, the key puts every creature that can attack into the attack, and Done sends it. Where attackers are final (the 1997 rule), the first press asks on the Situation Bar and a second press commits them."

## The door onto the 1997 panel at the window's foot.
const DUEL_OPTIONS_DOOR := "Duel Options..."


# ------------------------------------------------------------- the values --

static func log_targets() -> bool:
	return bool(Settings.get_value(LOG_TARGETS_KEY, LOG_TARGETS_DEFAULT))


static func set_log_targets(on: bool) -> void:
	Settings.set_value(LOG_TARGETS_KEY, on)


static func colorblind_mana() -> bool:
	return bool(Settings.get_value(COLORBLIND_KEY, COLORBLIND_DEFAULT))


static func set_colorblind_mana(on: bool) -> void:
	Settings.set_value(COLORBLIND_KEY, on)


## The scale the chrome wears: one of [constant UI_SCALES]. Anything else
## stored — a hand-edited file — reads as the nearest offered, never as a
## size nobody chose.
static func ui_scale() -> float:
	var raw: Variant = Settings.get_value(UI_SCALE_KEY, UI_SCALE_DEFAULT)
	var want := float(raw) if (raw is float or raw is int) else UI_SCALE_DEFAULT
	return nearest_scale(want)


static func set_ui_scale(value: float) -> void:
	Settings.set_value(UI_SCALE_KEY, nearest_scale(value))


static func nearest_scale(value: float) -> float:
	var best := UI_SCALES[0]
	for offered in UI_SCALES:
		if absf(offered - value) < absf(best - value):
			best = offered
	return best


static func attack_all_key() -> bool:
	return bool(Settings.get_value(ATTACK_ALL_KEY, ATTACK_ALL_DEFAULT))


static func set_attack_all_key(on: bool) -> void:
	Settings.set_value(ATTACK_ALL_KEY, on)


## "115%" for 1.15.
static func scale_words(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)


# ------------------------------------------------------------- the button --

## The strip button's face — [constant ArrangeButton.FACE], so the four
## under the large card read as one row.
const FACE := Vector2(38, 30)
const GLYPH := Vector2i(24, 18)
const GLYPH_INK := Color8(28, 24, 26)
const GLYPH_LIT := Color8(250, 244, 214)

static var _glyph: ImageTexture = null


## The reserve strip's button. [param on_pressed] opens the window.
static func button(on_pressed: Callable) -> Button:
	var btn := Button.new()
	btn.name = "DuelScreenOptionsButton"
	btn.custom_minimum_size = FACE
	btn.focus_mode = Control.FOCUS_NONE
	OriginalDialog.dress_bar_button(btn)
	btn.icon = glyph()
	btn.tooltip_text = BUTTON_TIP
	btn.pressed.connect(on_pressed)
	return btn


## Three sliders — the common mark for "settings" — drawn here for the
## reason Arrange's cards and the log's page are: `Program/DuelArt/` has no
## icon for a window 1997 did not have. Ink rails, pale knobs at three
## different places, so the mark reads as set and not as a grid.
static func glyph() -> ImageTexture:
	if _glyph != null:
		return _glyph
	var image := Image.create_empty(GLYPH.x, GLYPH.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for rail in SLIDERS:
		var y: int = rail.x
		var knob: int = rail.y
		for x in range(2, GLYPH.x - 2):
			image.set_pixel(x, y, GLYPH_INK)
			image.set_pixel(x, y + 1, GLYPH_INK)
		for yy in range(y - 2, y + 4):
			for xx in range(knob - 2, knob + 3):
				var edge := yy == y - 2 or yy == y + 3 or xx == knob - 2 or xx == knob + 2
				image.set_pixel(xx, yy, GLYPH_INK if edge else GLYPH_LIT)
	_glyph = ImageTexture.create_from_image(image)
	return _glyph


## The three rails: (row, knob's centre column).
const SLIDERS: Array[Vector2i] = [Vector2i(3, 15), Vector2i(8, 6), Vector2i(13, 11)]


# ------------------------------------------------------------- the window --

## BUILD THE WINDOW — every control writes its key the moment it is
## touched, as the 1997 panel does (*"These settings are retained for
## future duels"*, and there is no Apply there either); [signal
## OriginalDialog.closed] tells the screen to redress. [param on_door]
## opens the 1997 panel (the screen closes this one first).
static func window(on_door: Callable = Callable()) -> OriginalDialog:
	var dialog := OriginalDialog.create(TITLE, Vector2(460, 330),
		"panel_dark_stone")
	var box := dialog.body()

	box.add_child(OriginalDialog.label("Duel log:", 14, true))
	box.add_child(_check(LOG_TARGETS_LABEL, log_targets(), set_log_targets,
		"Each cast and activation in the log names what it aims at and the X it was cast for — "
		+ "in the window, in duel_log.txt and on the Spell Chain's cards.", "LogTargets"))

	box.add_child(OriginalDialog.label("Seeing and playing:", 14, true))
	box.add_child(_check(COLORBLIND_LABEL, colorblind_mana(), set_colorblind_mana,
		"The small cards show a mana symbol for each color a card makes, in place of the colored stripes.",
		"Colorblind"))

	var scale_row := HBoxContainer.new()
	scale_row.add_theme_constant_override("separation", 10)
	var scale_label := OriginalDialog.label(UI_SCALE_LABEL + ":", 14)
	scale_label.tooltip_text = UI_SCALE_TIP
	scale_label.mouse_filter = Control.MOUSE_FILTER_PASS
	scale_row.add_child(scale_label)
	var scales := OptionButton.new()
	scales.name = "UiScale"
	for i in UI_SCALES.size():
		scales.add_item(scale_words(UI_SCALES[i]), i)
	scales.selected = maxi(0, UI_SCALES.find(ui_scale()))
	scales.tooltip_text = scale_label.tooltip_text
	scales.item_selected.connect(func(index: int) -> void:
		set_ui_scale(UI_SCALES[index]))
	scale_row.add_child(scales)
	box.add_child(scale_row)

	var attack_row := HBoxContainer.new()
	attack_row.add_theme_constant_override("separation", 10)
	attack_row.add_child(_check(ATTACK_ALL_LABEL, attack_all_key(), set_attack_all_key,
		ATTACK_ALL_TIP, "AttackAll"))
	attack_row.add_child(KeyCapture.create(ATTACK_ALL_ACTION))
	box.add_child(attack_row)

	if on_door.is_valid():
		dialog.add_button(DUEL_OPTIONS_DOOR).pressed.connect(on_door)
	dialog.add_button("OK").pressed.connect(dialog.dismiss)
	return dialog


static func _check(text: String, on: bool, write: Callable, tip: String,
		node_name: String) -> CheckBox:
	var check := CheckBox.new()
	check.name = node_name
	check.text = text
	check.button_pressed = on
	check.tooltip_text = tip
	check.add_theme_color_override("font_color", OriginalDialog.CHOICE)
	check.toggled.connect(func(pressed: bool) -> void: write.call(pressed))
	return check


## THE KEY'S OWN ROW: the bound key on a button; a press of the button
## waits for the next key (or pad button) and binds it through
## [method Controls.bind], which also takes it off any other duel action —
## the Options screen's rule, in the one place this key is offered.
## Escape gives up the wait.
##
## ONE CAPTURE PER CLICK (0.50.65 bug campaign, k3-1). The button kept the
## keyboard after a bind, so the next Enter or Space — the player closing
## the window, or pressing the one button — was the button's own accept
## press and started a second capture, and the press after that was bound:
## Return came off Done, Space off the one button, and the file kept it. A
## bind and Escape now let go of the keyboard, the wait ends when the
## focus goes elsewhere, and while not waiting the accept keys are no
## press of this button: listening starts on a click.
class KeyCapture:
	extends Button

	var action := ""
	var waiting := false

	static func create(for_action: String) -> KeyCapture:
		var capture := KeyCapture.new()
		capture.name = "AttackAllBinding"
		capture.action = for_action
		capture.custom_minimum_size = Vector2(96, 26)
		capture.focus_mode = Control.FOCUS_ALL
		capture.tooltip_text = "The key — click here, then press the key you want. Escape keeps the one there is."
		capture.pressed.connect(capture._start)
		capture.focus_exited.connect(capture._give_up)
		capture._show()
		return capture

	func _show() -> void:
		text = "Press a key..." if waiting else Controls.text(action)

	func _start() -> void:
		waiting = true
		grab_focus()
		_show()

	## The wait is over — bound, given up, or the focus gone elsewhere —
	## and the keyboard goes back to the window (k3-1).
	func _give_up() -> void:
		waiting = false
		_show()
		if has_focus():
			release_focus()

	func _gui_input(event: InputEvent) -> void:
		if not waiting:
			# Enter and Space are no press of this button (k3-1): a click
			# starts the wait.
			if event is InputEventKey and event.is_action("ui_accept"):
				accept_event()
			return
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			accept_event()
			_give_up()
			return
		if (event is InputEventKey or event is InputEventJoypadButton) \
				and Controls.bindable(event):
			accept_event()
			Controls.bind(action, event)
			_give_up()
