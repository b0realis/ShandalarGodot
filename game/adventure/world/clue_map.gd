class_name ClueMap
extends WorldMap
## A CLUE'S PLACE SHOWN ON THE MAP (part C, stage C2; the owner's ruling
## c4-3 of 2026-10-27, the clue pane's "Show on map" [ours]). 1.3's clue
## page drew the world itself in a small frame, centred on the place
## (`ShowDungeonClueDetailScreen`, dungeonCluesScreen.c 1184–1212); here the
## whole map the hero knows (F2's — [WorldMap], its three looks, its keys)
## opens over the screen with the place marked on it:
##  - a gold ring pulsing round the place's tile (a node of its own, so the
##    pulse never paints the whole map again — the map's own rule for the
##    hero's blinking square), the hero's square blinking where they stand;
##  - a dungeon's dark mouth ringed in gold at its tile, even on land the
##    hero has not seen (the owner's A-1/A-2: a dungeon known is drawn
##    there on the world and the small map; F2's own map never draws one);
##  - its name boxed under the ring, and along the foot of the map where it
##    lies ("Location: -East of Kraag Forge." in the clue's words).
## City Info has no place here (the clues are open under it): its button is
## put away. Done, Escape, Space, Enter, D, M or F2 close it ([signal
## WorldMap.closed]); the clue pane comes back.

## How long one pulse of the ring takes, and its size round the tile's
## point (1997 screen pixels).
const PULSE := 1.2
const RING := 9.0
const RING_INK := Color8(255, 214, 120)

## The place marked: its tile, its name, a dungeon or not, and the line
## along the foot ("" none).
var mark_tile := Vector2i(-1, -1)
var mark_name := ""
var mark_dungeon := false
var mark_line := ""
var _ring: Control
var _time := 0.0


func _ready() -> void:
	super._ready()
	name = "ClueMap"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ring = Control.new()
	_ring.name = "Ring"
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	_place_ring()


func _process(delta: float) -> void:
	super._process(delta)
	if not visible:
		return
	_time += delta
	if _ring != null:
		_ring.queue_redraw()


func _layout() -> void:
	super._layout()
	_place_ring()


## The ring's node over the place's tile, a ring's breadth round it.
func _place_ring() -> void:
	if _ring == null or mark_tile.x < 0:
		return
	var at := stage()
	var middle := at * tile_point(mark_tile)
	var reach := RING * 2.0 * at.get_scale().x
	_ring.position = middle - Vector2(reach, reach)
	_ring.size = Vector2(reach, reach) * 2.0


func _draw_ring() -> void:
	if mark_tile.x < 0:
		return
	var reach := _ring.size.x / 2.0
	var middle := Vector2(reach, reach)
	var phase := fmod(_time, PULSE) / PULSE
	var radius := reach * (0.45 + 0.5 * phase)
	_ring.draw_arc(middle, radius, 0.0, TAU, 32, Color(RING_INK, 1.0 - phase), maxf(2.0, reach * 0.12))
	_ring.draw_arc(middle, reach * 0.45, 0.0, TAU, 32, RING_INK, maxf(1.5, reach * 0.08))


## The ring's phase now (0 just begun … 1), for the tests.
func pulse() -> float:
	return fmod(_time, PULSE) / PULSE


## The City Info button put away: the clues are under the map.
func _place_buttons() -> void:
	super._place_buttons()
	var city := _buttons.get("City Info") as Control
	if city != null:
		city.visible = false


## City Info's key does nothing here.
func key(code: int) -> bool:
	if code == KEY_C:
		return true
	return super.key(code)


func _draw() -> void:
	super._draw()
	if world == null or mark_tile.x < 0:
		return
	draw_set_transform_matrix(stage())
	var at := tile_point(mark_tile)
	if mark_dungeon:
		# The world's plain dungeon, small: a dark mouth ringed in gold.
		draw_circle(at, 4.5, Color(0, 0, 0, 0.6))
		draw_circle(at, 3.5, Color8(14, 10, 12))
		draw_arc(at, 3.8, 0.0, TAU, 16, PaneStyle.GOLD, 1.2)
	if mark_name != "":
		_boxed(mark_name, at + Vector2(0, 10), RING_INK, 9)
	if mark_line != "":
		_boxed(mark_line, Vector2(320, 450), PaneStyle.GOLD, 11)
	draw_set_transform_matrix(Transform2D.IDENTITY)
