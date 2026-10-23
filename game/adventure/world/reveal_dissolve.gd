class_name RevealDissolve
extends Control
## THE WORLD SHOWN BLOCK BY BLOCK — 1.3's `BlitRectByRandomTileOrder`
## (opt57_shandalar_ui_fx.c 223): after a new adventure begins, Leap of
## Fate or Sword of Resistance, the new view replaced the old in small
## squares in a random order, over a moment. Here the old view (a picture
## taken before the move, or black for a new adventure) is drawn in
## [constant BLOCK]-pixel squares that vanish at random over
## [constant SECONDS]; then the overlay is gone. It takes no input.

const BLOCK := 16.0
const SECONDS := 0.6

## What was on the screen before, or null for black.
var before: Texture2D
var _order: PackedInt32Array
var _columns := 0
var _shown := 0.0


## Cover [param host] with the old view [param picture] (null for black)
## and dissolve it; the overlay frees itself when done.
static func over(host: Control, picture: Texture2D) -> RevealDissolve:
	var cover := RevealDissolve.new()
	cover.name = "RevealDissolve"
	cover.before = picture
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return cover


## The screen as it now stands, for [method over]; null when it cannot be
## read (no renderer). The picture is in the window's pixels, which are the
## canvas's units only in a 1280 × 800 window ([method source_rect] maps
## them).
static func picture_of(host: Control) -> Texture2D:
	if not host.is_inside_tree() or DisplayServer.get_name() == "headless":
		return null
	var image := host.get_viewport().get_texture().get_image()
	return ImageTexture.create_from_image(image) if image != null else null


func _ready() -> void:
	var area := get_viewport_rect().size
	_columns = int(ceil(area.x / BLOCK))
	var rows := int(ceil(area.y / BLOCK))
	_order = PackedInt32Array()
	_order.resize(_columns * rows)
	for i in _order.size():
		_order[i] = i
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(_order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := _order[i]
		_order[i] = _order[j]
		_order[j] = swap


func _process(delta: float) -> void:
	_shown += delta
	if _shown >= SECONDS:
		queue_free()
		return
	queue_redraw()


## The part of the old picture under canvas square [param square]: the
## picture is the window's pixels (1920 × 1080, say) while the canvas the
## squares are laid on is the stretched base size (1422 × 800 there), so
## the square is scaled by the one over the other — else the old view
## would show zoomed and shifted.
func source_rect(square: Rect2) -> Rect2:
	var canvas := get_viewport_rect().size
	if before == null or canvas.x <= 0.0 or canvas.y <= 0.0:
		return square
	var pixels := before.get_size() / canvas
	return Rect2(square.position * pixels, square.size * pixels)


func _draw() -> void:
	var left := int(_order.size() * (1.0 - clampf(_shown / SECONDS, 0.0, 1.0)))
	for n in left:
		var cell := _order[_order.size() - 1 - n]
		var at := Vector2((cell % _columns) * BLOCK, (cell / _columns) * BLOCK)
		var square := Rect2(at, Vector2(BLOCK, BLOCK))
		if before != null:
			draw_texture_rect_region(before, square, source_rect(square))
		else:
			draw_rect(square, Color.BLACK)
