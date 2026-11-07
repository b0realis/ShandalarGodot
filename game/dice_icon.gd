class_name DiceIcon
extends Control
## A DIE'S FIVE, drawn: the face of a die for a "draw it at random" button
## (the Magic Battle screen's per-seat dice, the owner's ask of 2026-11-07:
## *"the button should have the dice icon"*). Drawn rather than shipped as a
## picture, so it needs no art and wears no skin: an ivory face with a
## dark edge and five pips, sized to whatever it is given. Mouse input goes
## through to the button underneath.

const FACE := Color(0.93, 0.89, 0.78)
const EDGE := Color(0.22, 0.17, 0.12)
const PIP := Color(0.16, 0.12, 0.09)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## A die on its own, filling [param button] with a small margin.
static func on(button: Button) -> DiceIcon:
	var icon := DiceIcon.new()
	button.add_child(icon)
	return icon


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var side := minf(size.x, size.y) * 0.72
	if side <= 4.0:
		return
	var square := Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))
	var face := StyleBoxFlat.new()
	face.bg_color = FACE
	face.border_color = EDGE
	face.set_border_width_all(maxi(1, int(side / 14.0)))
	face.set_corner_radius_all(int(side / 5.0))
	draw_style_box(face, square)
	var r := side / 11.0
	var c := square.get_center()
	var q := side * 0.27
	for at in [Vector2(-q, -q), Vector2(q, -q), Vector2.ZERO, Vector2(-q, q), Vector2(q, q)]:
		draw_circle(c + at, r, PIP)
