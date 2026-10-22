class_name WorldMap
extends Control
## THE MAP OF THE WORLD — the overview the original opened from its
## frame's map scroll (`ShowWorldMapScreen`, 0054eb6a): the world as small
## diamonds of its terrain's colour, the roads, a mark per site and the
## hero blinking. Drawn plain for now [QoL] (the original's `Mapback.pic`
## and `Ttsprite.spr` tiles are for later). Only what the hero has
## explored is shown, as in 1997 (the owner, 2026-10-22, with the world
## view's fog).

var world: ShandalarWorld
var hero_tile := Vector2i.ZERO
## Whether unexplored land is left off, as the original's map did.
var explored_only := true
var _blink := 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_blink += delta
	queue_redraw()


## Whether tile ([param x], [param y]) is on the map.
func shows(x: int, y: int) -> bool:
	return not explored_only or world.is_explored(x, y)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.04, 0.04, 0.92))
	if world == null:
		return
	# The original's map places a tile at ((x + y) · 6, (y − x) · 6): the
	# same diamonds, 12 × 12 a step. Land can only lie inside the
	# generator's frame, x + y 12–115 and y − x −32–31, so that is what is
	# fitted to the screen.
	var step := minf(size.x * 0.92 / 104.0, size.y * 0.84 / 64.0)
	var origin := Vector2(size.x * 0.5 - 65 * step, size.y * 0.5)
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			if not shows(x, y):
				continue
			var code := world.terrain(x, y)
			if code == ShandalarWorld.OCEAN:
				continue
			var middle := origin + Vector2((x + y + 1) * step, (y - x) * step)
			var points := PackedVector2Array([middle + Vector2(-step, 0), middle + Vector2(0, -step),
				middle + Vector2(step, 0), middle + Vector2(0, step)])
			draw_colored_polygon(points, WorldView.PLAIN.get(code, WorldView.PLAIN[0]))
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			var roads := world.road_bits(x, y)
			if roads == 0 or not shows(x, y):
				continue
			var middle := origin + Vector2((x + y + 1) * step, (y - x) * step)
			for d in range(1, 9):
				if roads & (1 << (d - 1)) != 0:
					var dx: int = ShandalarWorld.DX[d]
					var dy: int = ShandalarWorld.DY[d]
					draw_line(middle, middle + Vector2((dx + dy) * step, (dy - dx) * step) * 0.5,
						Color8(123, 63, 7), maxf(1.0, step * 0.25))
	for site in world.sites:
		if not shows(int(site["x"]), int(site["y"])):
			continue
		var middle := origin + Vector2((int(site["x"]) + int(site["y"]) + 1) * step,
			(int(site["y"]) - int(site["x"])) * step)
		var kind: int = site["type"]
		var radius: float = step * float([0.0, 0.45, 0.7, 0.85, 1.1, 1.1][clampi(kind, 0, 5)])
		draw_circle(middle, radius + 1.0, Color(0, 0, 0, 0.8))
		draw_circle(middle, radius, Color8(236, 222, 196) if kind < 4 else Color8(232, 190, 110))
	if fmod(_blink, 0.66) < 0.33:
		var hero := origin + Vector2((hero_tile.x + hero_tile.y + 1) * step, (hero_tile.y - hero_tile.x) * step)
		draw_rect(Rect2(hero - Vector2(step, step) * 0.6, Vector2(step, step) * 1.2), Color.WHITE)
	var font := get_theme_default_font()
	draw_string(font, Vector2(16, size.y - 16), "The map of the world · M or Escape: back",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color8(236, 222, 196))
