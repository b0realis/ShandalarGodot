class_name RedArrow
extends Button
## A RED ARROW for the Embark screen's choosers — the owner's memory of the
## 1997 character screen (2026-10-22: *"use this darker graphic and red
## arrows"*). No arrow survives in the files we can read: 1.3's face
## designer kept its buttons in `FaceArt/facebut1.pcx`, which our copy of
## the game does not have, and no sheet of the adventure carries one. So
## it is drawn [QoL]: a garnet triangle with a gold rim, lit on hover,
## sunk on a press, the focus ring every button here wears.

## Which way it points: -1 left, 1 right.
var direction := 1

const BODY := Color8(150, 22, 18)
const LIT := Color8(206, 44, 30)
const SUNK := Color8(98, 14, 12)
const RIM := Color8(228, 176, 92)
const SHADE := Color(0, 0, 0, 0.55)


func _init(points := 1, side := 34.0) -> void:
	direction = -1 if points < 0 else 1
	custom_minimum_size = Vector2(side, side)
	focus_mode = Control.FOCUS_ALL
	var none := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		add_theme_stylebox_override(state, none)
	add_theme_stylebox_override("focus", OriginalDialog.focus_ring())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)


func _draw() -> void:
	var inset := size.y * 0.16
	var h := size.y - inset * 2.0
	var w := minf(size.x - inset * 2.0, h * 0.9)
	var mid := size * 0.5
	var tip := Vector2(mid.x + direction * w * 0.5, mid.y)
	var back_top := Vector2(mid.x - direction * w * 0.5, mid.y - h * 0.5)
	var back_bottom := Vector2(mid.x - direction * w * 0.5, mid.y + h * 0.5)
	var sunk := get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED
	var shift := Vector2(1, 1) if sunk else Vector2.ZERO
	var points := PackedVector2Array([tip + shift, back_top + shift, back_bottom + shift])
	if not sunk:
		draw_colored_polygon(PackedVector2Array([tip + Vector2(2, 2),
			back_top + Vector2(2, 2), back_bottom + Vector2(2, 2)]), SHADE)
	var fill := BODY
	if disabled:
		fill = BODY.darkened(0.5)
	elif sunk:
		fill = SUNK
	elif is_hovered():
		fill = LIT
	draw_colored_polygon(points, fill)
	var rim := RIM.darkened(0.45) if disabled else RIM
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]),
		rim, 2.0, true)
