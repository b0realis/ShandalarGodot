class_name PoisonCounters
extends Control
## THE POISON COUNTERS ON THE LIFE REGISTER, laid out as the 1997 game laid
## them out (the polish pass, 2026-10-28; the ledger's *"Poison art:
## Manalink's `Poison.pic` vs the 1997-files-only rule"*).
##
## WHAT 1997 DID. The life window's paint (Shandalar 1.3 decompilation, the
## LifeClass window procedure; cited, not copied) draws the register's
## picture, then ONE `Poison.pic` sprite PER COUNTER on a grid a quarter of
## the window wide and a third of it tall — left to right, wrapping to the
## next row when the next cell would pass the right edge — and only then
## the life number with its drop shadow, so the number stays on top of
## the counters. Ten counters lose the game (CR 704.5c), so ten cells is
## what a duel usually shows: two rows and a half — and the grid's twelve
## the most, as the window clipped the rest ([method cells]).
##
## WHOSE PICTURE. The 1997 `Poison.pic` is the player's own copy, and its
## mask is dead in every conversion we hold (`tools/import_original.py`,
## "SURVEYED AND DELIBERATELY NOT IMPORTED — Poison.pic"); Manalink's
## working rescale is a third party's restyle and not ours to ship. So the
## sprite is OUR OWN DRAWING, `game/art/poison_counter.png` — a black widow
## with a red hourglass, drawn as geometry by `tools/draw_our_art.gd`
## (`_spider`, `_hourglass`) and listed with its hash in
## `game/art/README.md` — the same for every player, skin or no skin.
##
## HOW IT SITS. A child of the life register's button, filling it and
## letting every click through. Godot draws a child over its parent's own
## text, so to keep 1997's order (counters UNDER the number) this control
## draws the parent [Button]'s number again on top of the counters, through
## the same [TextLine] layout the button uses, with the 1997 drop shadow
## under it. With no counters it draws nothing at all.
##
## `[ours]` the picture, and each sprite keeping its shape inside its cell
## ([method fit]); the grid and the order are 1997's.

## The 1997 grid: four cells across, three down (`client.right / 4`,
## `client.bottom / 3`).
const COLUMNS := 4
const ROWS := 3

## The [method GameSkin.our_art] key of the sprite.
const ART := "poison_counter"

## The number's drop shadow — 1997 drew its shadow three units down and
## right of a 125x100 logical window, about two pixels on our register.
const SHADOW := Color(0, 0, 0, 0.85)
const SHADOW_OFFSET := Vector2(2, 2)

## How many counters to show. Never negative.
var count := 0:
	set(value):
		value = maxi(value, 0)
		if value == count:
			return
		count = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## The number drawn again follows the button's: whenever the button
## redraws (a new life total, a hover, a press, a new size), so does this.
func _ready() -> void:
	var host := get_parent() as CanvasItem
	if host != null and not host.draw.is_connected(queue_redraw):
		host.draw.connect(queue_redraw)


## The 1997 cells for [param n] counters on a register of [param area]:
## whole-pixel cells a quarter wide and a third tall, filled left to right
## and wrapped when the next cell would pass the right edge. Pure.
##
## NO CELL BELOW THE THIRD ROW (0.50.65 bug campaign, k3-6). Ten counters
## lose the game, but a duel's last damage can land more at once (nine and
## an unblocked pair), and the thirteenth sprite was drawn under the
## register — on the top seat's, over the library and graveyard row. 1997's
## window clipped its paint to its own client area, so what it showed was
## the twelve cells and no more; so do we, and the venom count on the life
## panel ("13/10") still says how many.
static func cells(area: Vector2, n: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var w := floorf(area.x / float(COLUMNS))
	var h := floorf(area.y / float(ROWS))
	if w <= 0.0 or h <= 0.0:
		return out
	var at := Vector2.ZERO
	for _i in maxi(n, 0):
		if at.y + h > area.y:
			break   # past the window's foot (k3-6)
		out.append(Rect2(at, Vector2(w, h)))
		at.x += w
		if area.x < at.x + w:
			at = Vector2(0.0, at.y + h)
	return out


## Where in [param cell] a sprite of [param picture]'s size goes: as large
## as fits with its shape kept, centred. 1997 stretched its sprite to the
## cell, which on its near-square life window kept the shape; our register
## is often twice as wide as it is tall, and a stretched spider is a
## flattened one. Pure.
static func fit(cell: Rect2, picture: Vector2) -> Rect2:
	if picture.x <= 0.0 or picture.y <= 0.0:
		return cell
	var scale := minf(cell.size.x / picture.x, cell.size.y / picture.y)
	var shown := (picture * scale).floor()
	return Rect2(cell.position + ((cell.size - shown) * 0.5).floor(), shown)


func _draw() -> void:
	if count <= 0:
		return
	var sprite := GameSkin.our_art(ART)
	if sprite != null:
		for cell in cells(size, count):
			draw_texture_rect(sprite, fit(cell, sprite.get_size()), false)
	_draw_number_over()


## The parent button's own number, again, over the counters — laid out the
## way [Button] lays it out (a centred [TextLine] inside its stylebox's
## content margins), in the colour of the button's present state, with
## the 1997 shadow under it.
func _draw_number_over() -> void:
	var button := get_parent() as Button
	if button == null or button.text == "":
		return
	var font := button.get_theme_font("font")
	if font == null:
		return
	var font_size := button.get_theme_font_size("font_size")
	var line := TextLine.new()
	line.add_string(button.text, font, font_size)
	var box := button.get_theme_stylebox("normal")
	var left := box.get_margin(SIDE_LEFT) if box != null else 0.0
	var top := box.get_margin(SIDE_TOP) if box != null else 0.0
	var inner := size - Vector2(left + (box.get_margin(SIDE_RIGHT) if box != null else 0.0),
		top + (box.get_margin(SIDE_BOTTOM) if box != null else 0.0))
	var at := Vector2(left, top) + ((inner - line.get_size()) * 0.5).floor()
	line.draw(get_canvas_item(), at + SHADOW_OFFSET, SHADOW)
	line.draw(get_canvas_item(), at, _number_color(button))


## The colour [Button] gives its text in the state it is in.
static func _number_color(button: Button) -> Color:
	match button.get_draw_mode():
		BaseButton.DRAW_HOVER:
			return button.get_theme_color("font_hover_color")
		BaseButton.DRAW_PRESSED:
			return button.get_theme_color("font_pressed_color")
		BaseButton.DRAW_HOVER_PRESSED:
			return button.get_theme_color("font_hover_pressed_color")
		BaseButton.DRAW_DISABLED:
			return button.get_theme_color("font_disabled_color")
	if button.has_focus():
		return button.get_theme_color("font_focus_color")
	return button.get_theme_color("font_color")
