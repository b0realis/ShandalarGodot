class_name Controls
extends RefCounted
## THE INPUT MAP — `[QoL]`: the duel's keys as ACTIONS, declared once in
## `project.godot [input]` with a default key and a default controller
## button each, rebindable on the Options screen (`Controls:`) and
## remembered in `user://settings.cfg`.
##
## The 1997 game had a keyboard and a mouse and no way to change what a
## key did; the duel screen carried that over as a `match` on keycodes
## (Space, Return, Esc, Q, H, L, M, Ctrl+T/I/U, F12, 1-9). Godot's own
## way is the input map: an action is a name, the map holds what
## presses it, and a screen asks `event.is_action_pressed("duel_done")`
## without knowing whether that was Return or a pad's X. Declaring the
## actions is what makes three things possible that a keycode never
## could — REBINDING (this file and the Options rows), a CONTROLLER (a
## pad button is an event like any other, `DuelScreen._unhandled_input`
## routes it to the same table as the keys) and STEAM INPUT, which
## reads the declared actions off the project.
##
## ONE SOURCE OF DEFAULTS. The default events are the project's
## (`project.godot [input]`, loaded into [InputMap] before the first
## scene); this file never repeats them. [method apply], run at boot by
## [Lifecycle], lays the player's own bindings over them from the
## `controls` key — a Dictionary `action -> [encoded events]` that holds
## ONLY the actions that differ from the defaults, so a player who never
## rebinds has nothing in the file and a reset ([method reset]) is
## reading the project again. Encoding is [method encode]'s: `key:Ctrl+T`
## (the engine's own key names, [method OS.get_keycode_string]) and
## `pad:A` ([constant PAD_NAMES]), readable in the file and stable across
## keyboard layouts because a keycode is a key, not a position.
##
## TWO SLOTS PER ACTION, a key and a pad button ([method bind]): binding
## a key replaces the action's key and leaves its pad button, and the
## other way round, so the keyboard and the controller never crowd each
## other out of the list. A key or button already on another listed
## action moves — the other action loses it and the row shows the gap —
## since two actions on one key would answer at once.
##
## WHAT IS NOT HERE: the deck builder's Ctrl accelerators and its Q
## (`DeckBuilderScreen._unhandled_key_input`) are the 1997 menu's own
## letters (`@MENU_*`, §6.1) and stay where the original put them; the
## help screen's Left/Right/Home/End are a reader's, not a player's. The
## pad's POINTER is not here either: since 2026-09-27 the `PadControls`
## autoload types the mouse for the left stick, the D-pad, A and LB
## (`game/input/pad_controls.gd`), the way [TouchControls] types it for
## a finger, and those four are not bindable duel actions while that
## layer is on — the actions above answer on the other buttons beside
## it, RB being the one button that advances the game.

## The stored key: `action -> [encoded events]`, absent when nothing is
## rebound.
const SETTINGS_KEY := "controls"

## The duel's actions in the order the Options screen lists them: the
## action's name in the map, the word the player sees and what it does.
const ACTIONS: Array[Dictionary] = [
	{"name": "duel_space", "label": "The one button",
		"tip": "Presses the Situation Bar's only button — Done, until Cancel joins it. The 1997 Spacebar rule."},
	{"name": "duel_done", "label": "Done",
		"tip": "Done, whatever else is on the bar: pass priority, confirm the attack or the block, finish a choice."},
	{"name": "duel_cancel", "label": "Cancel",
		"tip": "Cancel, one layer at a time — and with nothing to cancel, the pause menu."},
	{"name": "duel_pause", "label": "Pause menu",
		"tip": "Opens and closes the pause menu whatever else is going on."},
	{"name": "duel_hand", "label": "Show or hide the hand",
		"tip": "Folds the hand out of the way of your own attackers, and back."},
	{"name": "duel_log", "label": "Duel log",
		"tip": "Opens and closes the log of the duel so far."},
	{"name": "duel_read", "label": "Read the card",
		"tip": "Brings the sidebar's card up full-size to read, in the duel and the Deck Builder; the same key closes it."},
	{"name": "duel_mute", "label": "Mute",
		"tip": "Silences the music and the effects for this session only; the Options switches are untouched."},
	{"name": "duel_id_tags", "label": "Show ID tags",
		"tip": "The Duel Options toggle, from the keyboard."},
	{"name": "duel_invisible", "label": "Show invisible effects",
		"tip": "The Duel Options toggle, from the keyboard."},
	{"name": "duel_sickness", "label": "Show summoning sickness",
		"tip": "The Duel Options toggle, from the keyboard."},
	{"name": "duel_screenshot", "label": "Screenshot",
		"tip": "Saves the table as a picture in the game's folder and names it on the Situation Bar."},
]
## The nine numbered answers of a choice list — actions too, so the
## table is one table, but not on the Options list: nobody rebinds 1
## to 9, and while a choice list is up the keys mean nothing else.
const CHOICES: Array[String] = ["duel_choice_1", "duel_choice_2", "duel_choice_3",
	"duel_choice_4", "duel_choice_5", "duel_choice_6", "duel_choice_7", "duel_choice_8",
	"duel_choice_9"]
## The pad's buttons by the names a player knows them by (the Xbox
## letters, which a Steam Deck and most pads print), for the file and
## the rows.
const PAD_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back", JOY_BUTTON_GUIDE: "Guide", JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
	JOY_BUTTON_MISC1: "Misc", JOY_BUTTON_PADDLE1: "Paddle 1", JOY_BUTTON_PADDLE2: "Paddle 2",
	JOY_BUTTON_PADDLE3: "Paddle 3", JOY_BUTTON_PADDLE4: "Paddle 4",
	JOY_BUTTON_TOUCHPAD: "Touchpad",
}
## What a row shows for an empty slot.
const UNBOUND := "—"
## The modifier keys on their own are never a binding: a press of Ctrl
## is the start of Ctrl+T, not a key.
const MODIFIERS: Array[Key] = [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]


# ---------------------------------------------------------------- boot --

## Lay the player's bindings over the project's defaults — at boot
## ([Lifecycle]) and after [method reset]. Unknown actions and events
## that no longer decode are skipped, not errors: an old file is not a
## reason to lose the keyboard.
static func apply() -> void:
	var stored: Dictionary = Settings.get_value(SETTINGS_KEY, {})
	for action in names():
		var events := defaults(action)
		if stored.get(action) is Array:
			events.clear()
			for text in stored[action]:
				var event := decode(String(text))
				if event != null:
					events.append(event)
		_set_events(action, events)


## Every action this file owns — the listed ones and the choices.
static func names() -> Array[String]:
	var out: Array[String] = []
	for entry in ACTIONS:
		out.append(String(entry["name"]))
	out.append_array(CHOICES)
	return out


## The project's own events for [param action] — what `project.godot`
## declares, fresh copies.
static func defaults(action: String) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	var setting: Variant = ProjectSettings.get_setting("input/" + action, null)
	if setting is Dictionary and setting.has("events"):
		for event in setting["events"]:
			if event is InputEvent:
				out.append(event.duplicate())
	return out


## The events that press [param action] now.
static func bindings(action: String) -> Array[InputEvent]:
	if not InputMap.has_action(action):
		return []
	return InputMap.action_get_events(action)


## The key slot of [param action], or null.
static func key_of(action: String) -> InputEventKey:
	for event in bindings(action):
		if event is InputEventKey:
			return event
	return null


## The pad slot of [param action], or null.
static func pad_of(action: String) -> InputEventJoypadButton:
	for event in bindings(action):
		if event is InputEventJoypadButton:
			return event
	return null


static func _set_events(action: String, events: Array[InputEvent]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	for event in events:
		InputMap.action_add_event(action, event)


# ------------------------------------------------------------- binding --

## Put [param event] on [param action] in the slot of its kind — a key
## replaces the key, a pad button the pad button — take the same event
## off any other listed action, and remember it. Anything but a key or
## a pad button, a bare modifier, or an echo is refused (false).
static func bind(action: String, event: InputEvent) -> bool:
	if not bindable(event) or not names().has(action):
		return false
	var pressed := event.duplicate() as InputEvent
	pressed.set("pressed", false)   # the map holds the key, not a press of it
	pressed.set("device", -1)       # any keyboard, any pad
	for other in names():
		if other == action:
			continue
		var kept: Array[InputEvent] = []
		var changed := false
		for bound in bindings(other):
			if _same(bound, pressed):
				changed = true
			else:
				kept.append(bound)
		if changed:
			_set_events(other, kept)
	var events: Array[InputEvent] = []
	for bound in bindings(action):
		if not _same_kind(bound, pressed):
			events.append(bound)
	events.append(pressed)
	_set_events(action, events)
	_store()
	return true


## Whether [param event] can be a binding: a pressed key that is not a
## modifier on its own and not an echo, or a pressed pad button.
static func bindable(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and not MODIFIERS.has(event.keycode) \
			and event.keycode != KEY_NONE
	if event is InputEventJoypadButton:
		return event.pressed
	return false


## Every listed action back to the project's defaults, and the file
## forgets them.
static func reset() -> void:
	Settings.clear_value(SETTINGS_KEY)
	apply()


## Whether [param action] is bound the way the project declares it.
static func is_default(action: String) -> bool:
	var now := bindings(action)
	var wanted := defaults(action)
	if now.size() != wanted.size():
		return false
	for i in now.size():
		if not _same(now[i], wanted[i]):
			return false
	return true


## Write the actions that differ from the defaults; nothing when none do.
static func _store() -> void:
	var out := {}
	for action in names():
		if is_default(action):
			continue
		var texts: Array = []
		for event in bindings(action):
			texts.append(encode(event))
		out[action] = texts
	if out.is_empty():
		Settings.clear_value(SETTINGS_KEY)
	else:
		Settings.set_value(SETTINGS_KEY, out)


static func _same_kind(a: InputEvent, b: InputEvent) -> bool:
	return (a is InputEventKey and b is InputEventKey) \
		or (a is InputEventJoypadButton and b is InputEventJoypadButton)


## The same key with the same modifiers, or the same pad button.
static func _same(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return a.get_keycode_with_modifiers() == b.get_keycode_with_modifiers()
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return a.button_index == b.button_index
	return false


# ------------------------------------------------------------- reading --

## Whether [param event] presses [param action] — exactly: the action's
## modifiers and no others, so a Ctrl+T action ignores a bare T and a
## Q action ignores Ctrl+Q. A key event answers only when pressed and
## not an echo; a pad button when pressed.
static func pressed(event: InputEvent, action: String) -> bool:
	if not InputMap.has_action(action):
		return false
	if event is InputEventKey and event.echo:
		return false
	return event.is_action_pressed(action, false, true)


## Which numbered answer [param event] is, 0 to 8, or -1.
static func choice_index(event: InputEvent) -> int:
	for i in CHOICES.size():
		if pressed(event, CHOICES[i]):
			return i
	return -1


# --------------------------------------------------------------- words --

## The key of [param action] as the player reads it — "Space",
## "Ctrl+T", "Enter" — or [constant UNBOUND].
static func key_text(action: String) -> String:
	var key := key_of(action)
	return UNBOUND if key == null else describe(key)


## The pad button of [param action] — "A", "Start" — or [constant UNBOUND].
static func pad_text(action: String) -> String:
	var pad := pad_of(action)
	return UNBOUND if pad == null else describe(pad)


## Both slots for a sentence: "Space", "Space or A", "A".
static func text(action: String) -> String:
	var words: PackedStringArray = []
	var key := key_of(action)
	if key != null:
		words.append(describe(key))
	var pad := pad_of(action)
	if pad != null:
		words.append(describe(pad))
	return UNBOUND if words.is_empty() else " or ".join(words)


## The tooltip's hint: "[Space]", or "" when nothing is bound.
static func hint(action: String) -> String:
	var key := key_of(action)
	return "" if key == null else "  [%s]" % describe(key)


## One event in the player's words.
static func describe(event: InputEvent) -> String:
	if event is InputEventKey:
		var keycode: Key = event.get_keycode_with_modifiers()
		if event.keycode == KEY_NONE and event.physical_keycode != KEY_NONE:
			keycode = event.get_physical_keycode_with_modifiers()
		return OS.get_keycode_string(keycode)
	if event is InputEventJoypadButton:
		return String(PAD_NAMES.get(event.button_index, "Button %d" % event.button_index))
	return event.as_text()


## The file's word for an event: `key:Ctrl+T`, `pad:A`.
static func encode(event: InputEvent) -> String:
	if event is InputEventKey:
		return "key:" + describe(event)
	if event is InputEventJoypadButton:
		return "pad:" + describe(event)
	return ""


## The event a file's word means, or null for a word it cannot read.
static func decode(text: String) -> InputEvent:
	if text.begins_with("key:"):
		var keycode: Key = OS.find_keycode_from_string(text.substr(4))
		if keycode == KEY_NONE:
			return null
		var key := InputEventKey.new()
		key.device = -1
		key.keycode = keycode & KEY_CODE_MASK
		key.ctrl_pressed = (keycode & KEY_MASK_CTRL) != 0
		key.shift_pressed = (keycode & KEY_MASK_SHIFT) != 0
		key.alt_pressed = (keycode & KEY_MASK_ALT) != 0
		key.meta_pressed = (keycode & KEY_MASK_META) != 0
		return key
	if text.begins_with("pad:"):
		var name := text.substr(4)
		for index in PAD_NAMES:
			if String(PAD_NAMES[index]) == name:
				var pad := InputEventJoypadButton.new()
				pad.device = -1
				pad.button_index = index
				return pad
		if name.begins_with("Button "):
			var pad := InputEventJoypadButton.new()
			pad.device = -1
			pad.button_index = int(name.substr(7)) as JoyButton
			return pad
	return null
