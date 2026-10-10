class_name MenuBullet
extends TextureRect
## THE TITLE MENU'S BULLET — the 1997 Celtic-knot square with its pink gem
## that stood at the left of every title-menu choice (2026-10-08, the
## owner, from a photo of the original: *"can we put this icon on the left
## part of our main menu buttons. And have it hover and light on click and
## two disabled states for shandalar and save/load buttons?"*).
##
## The art is the imported skin's `begin_menu` sheet (`Begin.spr`, every
## frame in one column of 265x24 cells — `tools/import_original.py`); the
## bullet is its last four cells, at each cell's left:
##
##   [constant AT_REST] 14   [constant HOVERED] 15   [constant DIMMED] 17
##   (gem dull), all 24x24 — and 16, [constant PRESSED], NOT USED: the
##   1997 press is a 22x22 bullet that sinks into the top-left of its cell,
##   which beside a 24x24 one reads as the icon shrinking. THREE STATES,
##   the owner's call (2026-10-08): *"normal state, disabled and
##   highlighted/hover and click the same"*.
##
## WHICH STATE: a button held down is HOVERED whatever moved it — the
## stone button's own face darkens for the press; a disabled button, or
## one marked [member dimmed], is DIMMED; the rest are AT_REST. Shandalar
## and Save / Load are marked dimmed: they stay clickable — a placeholder
## still explains itself (the owner's ruling of 2026-09-03) — but their
## gem says the door is not open yet.
##
## AND THE GEM LIGHTS FOR WHAT THE PLAYER IS USING, never for both
## (2026-10-10 playtest: *"the icon on Magic Battle button in main menu is
## sometimes highlighted even if you do not hover over the button"*). The
## title gives Magic Battle the keyboard and pad focus when it opens
## (2026-09-27, for a machine with no mouse), and the bullet used to light
## for the focus as it does for the pointer — so a mouse player saw Magic
## Battle lit from the start and still lit while hovering Gauntlet. Now
## the last thing the player touched decides ([method input_kind]): a
## pointer that moved or clicked lights the button UNDER it and nothing
## else; an arrow, Tab or Enter from a keyboard or a pad lights the button
## HOLDING THE FOCUS and nothing else, a resting pointer's hover included.
## A launch starts on the pointer, so nothing is lit until the player does
## something — except under a handheld launcher, where the keys are what
## there is. The state is read off the button's own draw mode every time
## it redraws, and again every time the player switches, so no input path
## (mouse, touch, the pad pointer, the keyboard) can leave the bullet
## behind.
##
## WITHOUT THE IMPORTED SKIN there is no sheet and no bullet: [method
## attach] adds nothing, and the button is exactly what it was.

const SHEET := "begin_menu"
const CELL_HEIGHT := 24
const SIZE := 24
const AT_REST := 14
const HOVERED := 15
## The sheet's 22x22 sunken press — imported, not shown (see above).
const PRESSED := 16
const DIMMED := 17
## From the button's left edge, and centred on its height.
const INSET := 8.0
## Every bullet on the screen, so the one that sees the player switch can
## answer for all of them.
const GROUP := &"menu_bullets"
## What [method input_kind] makes of an event.
enum Kind { NONE, POINTER, KEYS }
## The actions that move the focus or press the focused button — the ones
## that say the player is on the keys.
const KEY_ACTIONS: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left",
	&"ui_right", &"ui_focus_next", &"ui_focus_prev", &"ui_accept"]

## Which the player is using now: the pointer (true) or the keys. Shared
## by every bullet — one player, one hand.
static var by_pointer := Settings.handheld() == ""

## Shown dimmed whatever the button does (a placeholder that is still
## clickable).
var dimmed := false
## The cell on show.
var frame := -1

var _button: BaseButton = null


## The bullet's [param state] cell of the imported sheet, or null when the
## skin has no `begin_menu` (or one too short to hold the bullet).
static func frame_texture(state: int) -> Texture2D:
	var sheet := GameSkin.texture(SHEET)
	if sheet == null or sheet.get_height() < (state + 1) * CELL_HEIGHT \
			or sheet.get_width() < SIZE:
		return null
	var cell := AtlasTexture.new()
	cell.atlas = sheet
	cell.region = Rect2(0, state * CELL_HEIGHT, SIZE, SIZE)
	return cell


## Which cell a button in [param mode] ([enum BaseButton.DrawMode]) shows,
## [param focused] or not, while the player is on the pointer
## ([param pointer]) or the keys.
static func state_for(mode: int, focused: bool, is_dimmed: bool, pointer := true) -> int:
	if is_dimmed or mode == BaseButton.DRAW_DISABLED:
		return DIMMED
	if mode in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED]:
		return HOVERED
	if pointer:
		return HOVERED if mode == BaseButton.DRAW_HOVER else AT_REST
	return HOVERED if focused else AT_REST


## Does [param event] say the player is on the pointer, on the keys, or
## neither? A key that moves nothing (a screenshot key, a modifier, a
## duel shortcut) is neither, so it cannot light the focus behind a mouse
## player's back; the pad pointer's own presses come back as pointer
## events, which is what they are.
static func input_kind(event: InputEvent) -> Kind:
	if event is InputEventMouseMotion or event is InputEventMouseButton \
			or event is InputEventScreenTouch:
		return Kind.POINTER
	if event is InputEventKey or event is InputEventJoypadButton \
			or event is InputEventJoypadMotion:
		for action in KEY_ACTIONS:
			if event.is_action_pressed(action):
				return Kind.KEYS
	return Kind.NONE


## A bullet at the left of [param button], or null — and nothing added —
## when the skin has no sheet.
static func attach(button: BaseButton, is_dimmed := false) -> MenuBullet:
	if frame_texture(AT_REST) == null:
		return null
	var bullet := MenuBullet.new()
	bullet.name = "MenuBullet"
	bullet.dimmed = is_dimmed
	bullet._button = button
	bullet.add_to_group(GROUP)
	bullet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bullet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bullet.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	bullet.size = Vector2(SIZE, SIZE)
	bullet.custom_minimum_size = Vector2(SIZE, SIZE)
	button.add_child(bullet)
	bullet._place()
	bullet.refresh()
	button.draw.connect(bullet.refresh)
	button.resized.connect(bullet._place)
	return bullet


## Show the cell the button's state asks for.
func refresh() -> void:
	if _button == null:
		return
	var wanted := state_for(_button.get_draw_mode(), _button.has_focus(), dimmed, by_pointer)
	if wanted == frame:
		return
	frame = wanted
	texture = frame_texture(wanted)


func _input(event: InputEvent) -> void:
	var kind := input_kind(event)
	if kind == Kind.NONE or (kind == Kind.POINTER) == by_pointer:
		return
	# A pad whose sticks and D-pad drive the pad pointer ([code]PadControls[/code])
	# is a pointer: its hop arrives as the pointer moving, a frame later.
	if kind == Kind.KEYS and not event is InputEventKey and _pad_drives_the_pointer():
		return
	by_pointer = kind == Kind.POINTER
	# The first bullet to see the switch answers for all of them: the rest
	# see a value that already agrees with the event.
	for bullet in get_tree().get_nodes_in_group(GROUP):
		(bullet as MenuBullet).refresh()


func _pad_drives_the_pointer() -> bool:
	var pad := get_node_or_null("/root/PadControls")
	return pad != null and pad.is_active()


func _place() -> void:
	if _button == null:
		return
	position = Vector2(INSET, round((_button.size.y - SIZE) / 2.0))
