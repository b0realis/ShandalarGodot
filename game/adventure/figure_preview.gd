class_name FigurePreview
extends Control
## THE HERO AS THEY WILL WALK THE MAP: the 1997 figure (`EGO_M`, `EGO_F`)
## dressed in the colours chosen ([HeroColors]), walking on the spot and
## turning round, twice its size — the Embark screen's preview [QoL]. For
## "other" the man and the woman take turns. Without the 1997 sheets there
## is nothing to show, and it hides.

## Seconds a step, and steps before the figure turns to the next way.
const STEP := 0.13
const TURN := 8
const SCALE := 1.75
## The world's anchor of a figure frame: where the feet stand.
const FEET := Vector2(77, 61)

var walker := "male"
var colors := {}
var art := WorldArt.new()
var _sheets := {}
var _time := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(64, 84)


## Show [param figure] (`male`, `female` or `other`) in [param dressed].
func show_figure(figure: String, dressed: Dictionary) -> void:
	walker = figure
	colors = HeroColors.cleaned(dressed)
	_sheets.clear()
	visible = art.texture("world_ego_m") != null
	queue_redraw()


## The figure shown now: for `other` the man and the woman in turn.
func figure_now() -> String:
	if walker == "other":
		return "male" if int(_time / (STEP * TURN * 4.0)) % 2 == 0 else "female"
	return walker


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	queue_redraw()


func _sheet(figure: String) -> Texture2D:
	if not _sheets.has(figure):
		var dressed := HeroColors.dressed(art, figure, colors)
		_sheets[figure] = dressed if dressed != null else art.texture(_key(figure))
	return _sheets[figure]


static func _key(figure: String) -> String:
	return "world_ego_f" if figure == "female" else "world_ego_m"


func _draw() -> void:
	var figure := figure_now()
	var sheet := _sheet(figure)
	if sheet == null:
		return
	var steps := int(_time / STEP)
	var way := (steps / TURN) % 8 + 1
	var frame := ((way + 2) & 7) * 5 + steps % 4 + 1
	var feet := Vector2(size.x * 0.5, size.y - 5.0)
	# Its own small stage, so the figure reads on any face.
	var stage := StyleBoxFlat.new()
	stage.bg_color = Color(0.05, 0.03, 0.025, 0.78)
	stage.border_color = Color8(232, 190, 110, 150)
	stage.set_border_width_all(1)
	stage.set_corner_radius_all(6)
	draw_style_box(stage, Rect2(Vector2.ZERO, size))
	draw_circle(feet + Vector2(0, -1), 8.0, Color(0, 0, 0, 0.45))
	var rect := art.frame_rect(_key(figure), frame)
	draw_texture_rect_region(sheet, Rect2(feet - FEET * SCALE, rect.size * SCALE), rect)
