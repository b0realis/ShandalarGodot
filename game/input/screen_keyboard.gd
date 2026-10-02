extends Node
## THE ON-SCREEN KEYBOARD — autoload `ScreenKeyboard`: a board of keys
## for a handheld that has none.
##
## `[QoL]`, 2026-10-02, the R36 Ultra tester on ArkOS: *"I also don't
## have a USB keyboard, so it'd be nice to have a virtual keyboard
## option."* An ArkOS handheld and a Steam Deck on its desktop have a
## pointer — a stick through gptokeyb, a trackpad — and no keys to name
## a deck, a table or a seed with, or to type into the Deck Builder's
## search. An Android build has the system's own keyboard and needs
## none of this ([constant DisplayServer.FEATURE_VIRTUAL_KEYBOARD]).
##
## HOW IT WORKS. When a [LineEdit] or a [TextEdit] takes the focus
## ([signal Viewport.gui_focus_changed]), the board appears across the
## bottom of the window — across the top when the field is down there —
## and each key pressed sends the field ONE KEY EVENT down the engine's
## own input path ([method Input.parse_input_event]), as a keyboard
## would: the field inserts the letter and says `text_changed`, Enter is
## `text_submitted` on a [LineEdit] and a new line in a [TextEdit],
## Backspace is Backspace. No field is edited from here, so every
## screen's reaction to typing stands, and a physical keyboard beside
## the board works as it always did. The keys take no focus of their own
## ([constant Control.FOCUS_NONE]) — the field keeps its caret, and a
## pointer (the mouse, a finger, the pad's arrow) is what presses them.
## `Shift` holds for one key. The board goes when the focus leaves the
## field, when the field leaves the screen, on Enter in a one-line field
## and on its own `Done`; a click on the field brings it back.
##
## WHEN IT IS ACTIVE — one stored value, `screen_keyboard`, three states,
## on the Options screen's `Display:` rows and in [Settings]:
##
##   - `auto` (the default): on a handheld the launcher named
##     ([method Settings.handheld]) whose system has no on-screen
##     keyboard of its own; a desk never sees it;
##   - `on`: wherever a field takes the focus;
##   - `off`: never.
##
## INERT MEANS INERT: not active, the focus is not watched and nothing
## is built. The board is built on its first showing.

## The [Settings] key and its three values.
const KEY := "screen_keyboard"
const AUTO := "auto"
const ON := "on"
const OFF := "off"
## Over every screen and the card reader (100), under the pad's arrow
## ([constant PadControls.LAYER], 900), which must be able to press a key.
const LAYER := 850
## The `device` on every key event the board sends: THE KEYBOARD'S OWN,
## a fresh [InputEventKey]'s default. The engine's own text actions
## (`ui_text_backspace`, `ui_text_submit`, `ui_text_newline`...) are
## bound to events made the same way, and an action matches an event
## from ITS device only — a key stamped with an id of the board's own,
## as the touch and pad layers stamp their mouse events, types letters
## (a field inserts those by their unicode) but no Backspace and no
## Enter.
var SYNTH_DEVICE: int = InputEventKey.new().device

## The special keys, by the word on them.
const BACKSPACE := "Backspace"
const SHIFT := "Shift"
const ENTER := "Enter"
const SPACE := "Space"
const DONE := "Done"
## The rows: a character key is `[plain, shifted]`, the words are the
## special keys. Twelve key-widths across at the widest; a word key is
## two of them, the Space eight.
const ROWS: Array = [
	[["1", "!"], ["2", "@"], ["3", "#"], ["4", "$"], ["5", "%"], ["6", "^"], ["7", "&"],
		["8", "*"], ["9", "("], ["0", ")"], BACKSPACE],
	[["q", "Q"], ["w", "W"], ["e", "E"], ["r", "R"], ["t", "T"], ["y", "Y"], ["u", "U"],
		["i", "I"], ["o", "O"], ["p", "P"], ["-", "_"]],
	[["a", "A"], ["s", "S"], ["d", "D"], ["f", "F"], ["g", "G"], ["h", "H"], ["j", "J"],
		["k", "K"], ["l", "L"], ["'", "\""], ENTER],
	[SHIFT, ["z", "Z"], ["x", "X"], ["c", "C"], ["v", "V"], ["b", "B"], ["n", "N"],
		["m", "M"], [",", ";"], [".", ":"], ["/", "?"]],
	[DONE, SPACE],
]
const COLUMNS := 12
const WIDE := {BACKSPACE: 2, SHIFT: 2, ENTER: 2, DONE: 2, SPACE: 8}
## A key's side comes from the window's width, between these — and the
## five rows never take more than [constant HEIGHT_SHARE] of the window.
const KEY_MAX := 64.0
const KEY_MIN := 28.0
const HEIGHT_SHARE := 0.4
const GAP := 4.0
const MARGIN := 8.0

var _active := false
var _layer: CanvasLayer = null
var _panel: PanelContainer = null
var _keys: Array[Button] = []
var _shift_key: Button = null
var _shift := false
## The field the board types into, while it is shown.
var _target: WeakRef = null
var _key_side := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	apply_settings()


# ------------------------------------------------------------ the switch --

## What the file asks for: `auto`, `on` or `off`.
static func wanted() -> String:
	return Settings.screen_keyboard()


## The stored setting, resolved against the device: `auto` is a named
## handheld whose system keeps no on-screen keyboard of its own.
static func should_be_active() -> bool:
	match wanted():
		ON:
			return true
		OFF:
			return false
		_:
			return Settings.handheld() != "" \
				and not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD)


## Put the stored setting into effect. Idempotent.
func apply_settings() -> void:
	set_active(should_be_active())


## The Options row's own setter: store, then apply — the file and the
## board cannot disagree.
func choose(mode: String) -> void:
	Settings.set_value(KEY, mode)
	apply_settings()


func is_active() -> bool:
	return _active


func set_active(on: bool) -> void:
	if on == _active:
		return
	_active = on
	var viewport := get_viewport()
	if viewport == null:
		return
	if on:
		if not viewport.gui_focus_changed.is_connected(_on_focus_changed):
			viewport.gui_focus_changed.connect(_on_focus_changed)
		var focus := viewport.gui_get_focus_owner()
		if focus != null:
			_on_focus_changed(focus)
	else:
		if viewport.gui_focus_changed.is_connected(_on_focus_changed):
			viewport.gui_focus_changed.disconnect(_on_focus_changed)
		_release()


# ------------------------------------------------------------- the board --

func is_shown() -> bool:
	return _panel != null and _panel.visible


## The field the board is typing into, or null.
func target() -> Control:
	if _target == null:
		return null
	var control := _target.get_ref() as Control
	return control if is_instance_valid(control) else null


## Show the board for [param field] — a [LineEdit] or a [TextEdit] that
## can be typed into. Anything else hides it.
func show_for(field: Control) -> void:
	if not _active or not _typable(field):
		_release()
		return
	var current := target()
	if current != field:
		_unwatch(current)
		_target = weakref(field)
		field.focus_exited.connect(_on_target_focus_exited)
		field.tree_exiting.connect(_release)
		field.visibility_changed.connect(_on_target_visibility)
		field.gui_input.connect(_on_target_input)
	if _panel == null:
		_build()
	_set_shift(false)
	_panel.show()
	_fit()


## Put the board away. The field keeps the focus and stays watched —
## a click on it brings the board back.
func hide_board() -> void:
	if _panel != null:
		_panel.hide()


## Let the field go: no field to type into, so no board and no watch.
func _release() -> void:
	_unwatch(target())
	_target = null
	hide_board()


static func _typable(control: Control) -> bool:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return false
	if control is LineEdit:
		return control.editable
	if control is TextEdit:
		return control.editable
	return false


func _unwatch(field: Control) -> void:
	if field == null or not is_instance_valid(field):
		return
	if field.focus_exited.is_connected(_on_target_focus_exited):
		field.focus_exited.disconnect(_on_target_focus_exited)
	if field.tree_exiting.is_connected(_release):
		field.tree_exiting.disconnect(_release)
	if field.visibility_changed.is_connected(_on_target_visibility):
		field.visibility_changed.disconnect(_on_target_visibility)
	if field.gui_input.is_connected(_on_target_input):
		field.gui_input.disconnect(_on_target_input)


func _on_focus_changed(control: Control) -> void:
	if _typable(control):
		show_for(control)
	else:
		_release()


## The field let the focus go. Where it went is known a moment later —
## a field that took it shows the board for itself, anything else
## closes the board.
func _on_target_focus_exited() -> void:
	_check_focus.call_deferred()


func _check_focus() -> void:
	var field := target()
	if field == null or not field.has_focus():
		var viewport := get_viewport()
		var focus := viewport.gui_get_focus_owner() if viewport != null else null
		if _typable(focus):
			show_for(focus)
		else:
			_release()


func _on_target_visibility() -> void:
	var field := target()
	if field == null or not field.is_visible_in_tree():
		_release()


## A click on the field brings the board back after Enter or Done put
## it away — the field kept the focus, so nothing else would.
func _on_target_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and not is_shown():
		var field := target()
		if field != null:
			show_for(field)


# -------------------------------------------------------------- the keys --

func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	add_child(_layer)
	_panel = PanelContainer.new()
	_panel.name = "ScreenKeyboard"
	_panel.add_theme_stylebox_override("panel", UiChrome.stone_panel(MARGIN))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.hide()
	_layer.add_child(_panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", int(GAP))
	_panel.add_child(rows)
	# The body face on the keys, not the title's: a key must READ at a
	# glance, and the title face's uncial E and D do not.
	var face: Font = GameSkin.font("font_body")
	for row in ROWS:
		var line := HBoxContainer.new()
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_theme_constant_override("separation", int(GAP))
		rows.add_child(line)
		for key in row:
			var button := UiChrome.menu_button(_label_of(key, false), Vector2.ZERO, 20)
			if face != null:
				button.add_theme_font_override("font", face)
			button.focus_mode = Control.FOCUS_NONE
			button.set_meta("key", key)
			if key is String and key == SHIFT:
				button.toggle_mode = true
				UiChrome.gold_when_chosen(button)
				button.toggled.connect(func(on: bool) -> void: _set_shift(on))
				_shift_key = button
			else:
				button.pressed.connect(_on_key.bind(button))
			line.add_child(button)
			_keys.append(button)
	get_viewport().size_changed.connect(_fit)


static func _label_of(key: Variant, shifted: bool) -> String:
	if key is String:
		return key
	return key[1] if shifted else key[0]


## The keys sized to the window, and the board put where the field is
## not: across the bottom, or across the top when the field is down
## there.
func _fit() -> void:
	if _panel == null or not _panel.visible:
		return
	var area := get_viewport().get_visible_rect().size
	var side := clampf((area.x - MARGIN * 2 - GAP * (COLUMNS - 1)) / COLUMNS, KEY_MIN, KEY_MAX)
	var tall := (area.y * HEIGHT_SHARE - MARGIN * 2 - GAP * (ROWS.size() - 1)) / ROWS.size()
	side = maxf(minf(side, tall), KEY_MIN)
	if not is_equal_approx(side, _key_side):
		_key_side = side
		var font_size := int(clampf(side * 0.4, 12.0, 22.0))
		for button in _keys:
			var key: Variant = button.get_meta("key")
			var units: int = WIDE.get(key, 1) if key is String else 1
			button.custom_minimum_size = Vector2(side * units + GAP * (units - 1), side)
			button.add_theme_font_size_override("font_size", font_size)
	_panel.size = _panel.get_combined_minimum_size()
	var x := (area.x - _panel.size.x) * 0.5
	var bottom := area.y - _panel.size.y
	var field := target()
	var y := bottom
	if field != null and field.is_inside_tree():
		var rect := field.get_global_rect()
		if rect.end.y > bottom and rect.position.y >= _panel.size.y:
			y = 0.0
	_panel.position = Vector2(x, y)


func _set_shift(on: bool) -> void:
	_shift = on
	if _shift_key != null and _shift_key.button_pressed != on:
		_shift_key.set_pressed_no_signal(on)
	for button in _keys:
		var key: Variant = button.get_meta("key")
		if not key is String:
			button.text = _label_of(key, on)


func _on_key(button: Button) -> void:
	var field := target()
	if field == null or not field.has_focus():
		_release()
		return
	var key: Variant = button.get_meta("key")
	if key is String:
		match key:
			BACKSPACE:
				_send(KEY_BACKSPACE, 0, false)
			SPACE:
				_send(KEY_SPACE, 32, false)
			ENTER:
				_send(KEY_ENTER, 0, false)
				if field is LineEdit:
					hide_board()
			DONE:
				hide_board()
		return
	var text: String = key[1] if _shift else key[0]
	_send(_keycode_of(text), text.unicode_at(0), _shift)
	if _shift:
		_set_shift(false)


static func _keycode_of(text: String) -> Key:
	var upper := text.to_upper().unicode_at(0)
	if upper >= 65 and upper <= 90:
		return (KEY_A + (upper - 65)) as Key
	if upper >= 48 and upper <= 57:
		return (KEY_0 + (upper - 48)) as Key
	return KEY_NONE


## One key, down and up, into the engine's input queue — the focused
## field takes it as it takes a keyboard's, which is what it looks like
## (see [member SYNTH_DEVICE]).
func _send(keycode: Key, unicode: int, shift: bool) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.key_label = keycode
		event.unicode = unicode
		event.shift_pressed = shift
		event.pressed = down
		Input.parse_input_event(event)
