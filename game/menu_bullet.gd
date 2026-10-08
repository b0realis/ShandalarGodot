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
## WHICH STATE: a button under the pointer, held down, or holding the
## keyboard and pad focus (the shell has no pointer on a pad without one)
## is HOVERED — the stone button's own face darkens for the press; a
## disabled button, or one marked [member dimmed], is DIMMED; the rest
## are AT_REST. Shandalar and Save / Load are
## marked dimmed: they stay clickable — a placeholder still explains
## itself (the owner's ruling of 2026-09-03) — but their gem says the door
## is not open yet. The state is read off the button's own draw mode
## every time it redraws, so no input path (mouse, touch, the pad
## pointer, the keyboard) can leave the bullet behind.
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


## Which cell a button in [param mode] ([enum BaseButton.DrawMode]) shows.
static func state_for(mode: int, focused: bool, is_dimmed: bool) -> int:
	if is_dimmed or mode == BaseButton.DRAW_DISABLED:
		return DIMMED
	if mode in [BaseButton.DRAW_HOVER, BaseButton.DRAW_PRESSED,
			BaseButton.DRAW_HOVER_PRESSED] or focused:
		return HOVERED
	return AT_REST


## A bullet at the left of [param button], or null — and nothing added —
## when the skin has no sheet.
static func attach(button: BaseButton, is_dimmed := false) -> MenuBullet:
	if frame_texture(AT_REST) == null:
		return null
	var bullet := MenuBullet.new()
	bullet.name = "MenuBullet"
	bullet.dimmed = is_dimmed
	bullet._button = button
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
	var wanted := state_for(_button.get_draw_mode(), _button.has_focus(), dimmed)
	if wanted == frame:
		return
	frame = wanted
	texture = frame_texture(wanted)


func _place() -> void:
	if _button == null:
		return
	position = Vector2(INSET, round((_button.size.y - SIZE) / 2.0))
