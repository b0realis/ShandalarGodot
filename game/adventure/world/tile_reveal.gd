class_name TileReveal
extends Control
## THE TRANSITIONS — how a 1997 picture came onto the screen (the owner,
## 2026-10-27, H7: *"robust, fun, bug-less and modern smooth feeling"*):
## 1.3 never just showed a place's picture, it brought it in. Four ways,
## all here, one node each:
##  - THE ZOOM-IN (`AnimateVisitBackdropZoomIn`, visitLocation.c 437–466):
##    a town's, the wise man's, the news's 512 × 280 picture stretched about
##    its middle at 2/8, 3/8 … 8/8 of its size, seven blits with no wait
##    between them ([method zoom_in]). [QoL] Here one smooth ease-out over
##    [constant ZOOM_SECONDS] from [constant ZOOM_FROM], the picture fading
##    up from the frame's dark ground as it grows.
##  - THE STAGGERED TILES (`ShowWizardVisitBackdrop` 470–499 →
##    `BlitRectByStaggeredRandomTileOrder`, opt57_shandalar_ui_fx.c
##    317–475; a castle's picture): the picture cut into vertical strips 32
##    pixels wide of 8 × 8 tiles, each strip drawing its tiles in its own
##    random order, three neighbouring strips at once — the leading one a
##    tile a round, the next two, the trailing one three — and a strip
##    retiring when it is done, so a speckle sweeps from left to right
##    ([enum Order] STAGGERED, [member strip], [member active]).
##  - THE RANDOM TILES (`BlitRectByRandomTileOrderInPlace`, ui_fx 130–221;
##    a lair's picture in 5 × 5 tiles, `ShowLairBackdropTransition`,
##    world_lair_monster_encounter.c 150–176; a creature's face in 3 × 3
##    tiles and its name banner in 2 × 2, `DrawCreaturePortrait` modes 1
##    and 2, visitLocation.c 2540–2625): every tile once, in a random order
##    ([enum Order] RANDOM).
##  - The world after a new adventure, Leap of Fate or Sword of Resistance
##    (`BlitRectByRandomTileOrder`, ui_fx 223): [RevealDissolve], this node
##    over the whole screen.
## 1997 waited 45 ticks (`DelayUiTicks(0x2d)`, 0.73 s) after a castle's or a
## lair's tiles before its words; [QoL] here the words and the choices stand
## from the first frame and the picture comes in under them — nothing waits.
##
## HOW: a cover over the picture (its [member before] — the frame's ground
## [member ground], a picture's region [member source], or the screen as it
## stood) drawn through one small shader that drops each tile once its
## moment has come: every tile's moment is a byte of a little texture
## ([member grid] texels), the moment now one number — no per-tile work on
## the CPU after the first frame. The zoom draws nothing: it scales its
## [member zoom_target].
##
## [QoL] EVERY ONE IS SHORT (well under a second), TAKES NO INPUT (the mouse
## goes through it, the choices under it answer at once) and IS SKIPPED BY
## A CLICK OR A KEY (any press anywhere ends it — the press itself goes on
## to whatever it was for); then it frees itself. ON BY DEFAULT, the
## Options' "Transitions" switch turns them off ([method wanted]);
## headless (the tests, the tools) they never play — a picture is simply
## there, so nothing ever waits on one.

## Every tile's moment has come: the transition is over (once).
signal done

enum Order { RANDOM, STAGGERED }

## The [Settings] key of the Options' "Transitions" switch, on by default.
const SETTING := "transitions"
## The zoom-in: from a quarter of the size (1997's first blit, 2/8) to the
## whole, in this long.
const ZOOM_FROM := 0.25
const ZOOM_SECONDS := 0.2
## How far the zoomed picture fades up from, and in what share of the zoom.
const ZOOM_FADE_FROM := 0.35
const ZOOM_FADE_SHARE := 0.6
## A castle's staggered tiles, a lair's random ones, a face's and a banner's.
const CASTLE_SECONDS := 0.5
const LAIR_SECONDS := 0.4
const FACE_SECONDS := 0.3
## 1997's tiles on its 512 × 280 picture, as grids: a castle's 8 × 8 tiles
## (64 × 35, strips of four columns, three strips at once), a lair's 5 × 5
## (103 × 56); a face's 180 × 180 block in 3 × 3 tiles (60 × 60), the name
## banner's middle (its width less 22, 35 high) in 2 × 2 (79 × 18).
const CASTLE_GRID := Vector2i(64, 35)
const CASTLE_STRIP := 4
const CASTLE_ACTIVE := 3
const LAIR_GRID := Vector2i(103, 56)
const FACE_GRID := Vector2i(60, 60)
const BANNER_GRID := Vector2i(79, 18)
## The banner's ends left out of its reveal (1997: its width less 22).
const BANNER_TRIM := 11.0

## Tests: 1 plays the transitions headless too, 0 never, -1 by the rule
## ([method wanted]).
static var forced := -1
static var _shader: Shader

## The tiles across and down.
var grid := Vector2i.ONE
## How long the tiles take, after [member delay].
var seconds := 0.3
var delay := 0.0
var order := Order.RANDOM
## STAGGERED: a strip's width in tile columns, and how many strips draw at
## once.
var strip := CASTLE_STRIP
var active := CASTLE_ACTIVE
## What the tiles not yet come hide: [member before] (its [member source]
## region, an empty one the whole picture — or the screen as it stood,
## [method take_screen]), else [member ground]. The screen as it stood
## ([method picture_of], a [TileReveal.Snapshot]) is held while this cover
## lasts.
var before: Texture2D:
	set(value):
		if value == before:
			return
		_release()
		before = value
		_held = Snapshot.of(value)
		if _held != null:
			_held.take()
var source := Rect2()
var ground := Color(0.02, 0.015, 0.015, 1.0)
## The zoom-in's picture ([method zoom_in]); null for a cover.
var zoom_target: Control
## The dice of the order; -1 a fresh roll (1997 seeded from the clock).
var seed_value := -1

var _elapsed := 0.0
var _over := false
## The process frame it was made in ([method _process]).
var _born := -1
## Each tile's moment, 1–255 (its share of [member seconds] × 255), by
## `y * grid.x + x`.
var _moments := PackedByteArray()
var _material: ShaderMaterial
var _target_alpha := 1.0
## The snapshot [member before] is, held until this cover goes.
var _held: Snapshot


## THE SCREEN AS IT STOOD, KEPT ON THE GPU (the smoothness pass, 0.50.66).
## [method picture_of] read the whole window back off the graphics card
## and sent it up again as a new texture: 3-6 ms of the frame a meeting's
## summoned face, a dungeon's treasure or Leap of Fate came in on the
## desk's RTX 4060 at 1920 × 1080 — a stall of the whole pipeline, and far
## longer on a handheld's GPU. This copies it there instead: a viewport of
## the window's pixels that draws the window's own last picture once, 1:1,
## the next time the screen is drawn — before the window draws again, so it
## is the picture as it stood, the same pixels the read gave. Nothing goes
## through the processor. One window-sized texture (8 MB at 1920 × 1080,
## as the read's texture was), held while a cover shows it ([method take],
## [method drop]) and let go when the last one goes, or after
## [constant UNUSED_SECONDS] when none took it.
class Snapshot extends SubViewport:
	const META := &"tile_reveal_snapshot"
	const UNUSED_SECONDS := 2.0
	var _users := 0
	var _taken := false

	## The snapshot [param picture] is the texture of, or null.
	static func of(picture: Texture2D) -> Snapshot:
		if picture == null or not picture.has_meta(META):
			return null
		var shot: Variant = picture.get_meta(META)
		return shot as Snapshot if is_instance_valid(shot) else null

	## The window's last picture [param source], [param pixels] in size,
	## copied once — in [param host]'s viewport, beside the screens rather
	## than among a pane's own children.
	static func make(host: Node, source: Texture2D, pixels: Vector2i) -> Snapshot:
		var shot := Snapshot.new()
		shot.name = "ScreenSnapshot"
		shot.size = pixels
		shot.disable_3d = true
		shot.transparent_bg = false
		shot.render_target_update_mode = SubViewport.UPDATE_ONCE
		shot.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		var shown := SnapshotCopy.new()
		shown.source = source
		shown.pixels = pixels
		shown.size = Vector2(pixels)
		shown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		shot.add_child(shown)
		host.get_viewport().add_child(shot)
		shot.get_texture().set_meta(META, shot)
		host.get_tree().create_timer(UNUSED_SECONDS, true, false, true).timeout.connect(shot._unused)
		return shot

	func take() -> void:
		_users += 1
		_taken = true

	func drop() -> void:
		_users -= 1
		if _users <= 0 and not is_queued_for_deletion():
			queue_free()

	func _unused() -> void:
		if not _taken and not is_queued_for_deletion():
			queue_free()


## The window's picture drawn 1:1 into a [TileReveal.Snapshot]: its region
## named in the window's own [member pixels] — the texture's reported size
## is the window's times the canvas stretch again (2593 × 1458 for a
## 1920 × 1080 window), and a region in those units drew it zoomed;
## measured identical, pixel for pixel, to the read back on the desk.
class SnapshotCopy extends Control:
	var source: Texture2D
	var pixels := Vector2i.ONE

	func _draw() -> void:
		draw_texture_rect_region(source, Rect2(Vector2.ZERO, Vector2(pixels)), Rect2(Vector2.ZERO, Vector2(pixels)))


## Whether the transitions play: the Options' switch, on by default, and a
## screen to play them on — headless, never ([member forced] for tests).
static func wanted() -> bool:
	if forced >= 0:
		return forced == 1
	return Settings.transitions() and DisplayServer.get_name() != "headless"


## THE ZOOM-IN of [param target] (a place's picture): from [constant
## ZOOM_FROM] of its size about its middle to the whole, fading up — null,
## and the picture simply there, when the transitions are off. The target
## must not be a container's child: a container sets its children's scale
## back to 1 as it lays them out.
static func zoom_in(target: Control, length := ZOOM_SECONDS) -> TileReveal:
	if not wanted() or target == null:
		return null
	var zoom := TileReveal.new()
	zoom.name = "ZoomIn"
	zoom.zoom_target = target
	zoom.seconds = length
	target.add_child(zoom)
	return zoom


## A COVER whose [param tiles] go in [param tile_order] over [param
## length] seconds, for the caller to set what it hides and to lay where it
## is wanted. Null when the transitions are off.
static func make(tiles: Vector2i, length: float, tile_order := Order.RANDOM) -> TileReveal:
	if not wanted():
		return null
	var made := TileReveal.new()
	made.name = "TileReveal"
	made.grid = tiles
	made.seconds = length
	made.order = tile_order
	return made


## A cover ([method make]) laid over [param at], in [param host]'s own units.
static func cover(host: Control, at: Rect2, tiles: Vector2i, length: float,
		tile_order := Order.RANDOM) -> TileReveal:
	var made := make(tiles, length, tile_order) if host != null else null
	if made == null:
		return null
	made.position = at.position
	made.size = at.size
	host.add_child(made)
	return made


## [QoL] THE TRANSITIONS' SHADER COMPILED BEFORE ITS FIRST USE (the
## smoothness pass, 0.50.66): the cover's little shader ([constant SHADER])
## was compiled the first time a cover was drawn — a lair's picture coming
## in, a face — inside that frame; on a handheld's or a headset's GL driver
## that is tens of milliseconds. As the world opens one pixel under
## [param host] is drawn through it with every tile's moment come, so every
## fragment is dropped (nothing is seen), and let go half a second later.
## Nothing with the transitions off, or headless.
static func warm_shader(host: Node) -> ColorRect:
	if not wanted() or host == null or not host.is_inside_tree():
		return null
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var warm := ShaderMaterial.new()
	warm.shader = _shader
	var moments := PackedByteArray([1])
	warm.set_shader_parameter("order", ImageTexture.create_from_image(
		Image.create_from_data(1, 1, false, Image.FORMAT_R8, moments)))
	warm.set_shader_parameter("grid", Vector2.ONE)
	warm.set_shader_parameter("area", Vector2.ONE)
	warm.set_shader_parameter("shown", 255.0)
	var dot := ColorRect.new()
	dot.name = "TransitionShaderWarm"
	dot.size = Vector2.ONE
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.material = warm
	host.add_child(dot)
	host.get_tree().create_timer(0.5, true, false, true).timeout.connect(dot.queue_free)
	return dot


## Every transition under [param root] over at once (a test, a pane that
## must show itself whole).
static func finish_all(root: Node) -> void:
	for node in root.find_children("*", "TileReveal", true, false):
		(node as TileReveal).finish()


## The screen as it now stands, or null when it cannot be read (headless,
## no renderer): what a cover over a part of it hides ([method
## take_screen]). In the window's pixels — kept on the GPU, not read back
## ([TileReveal.Snapshot]; the smoothness pass, 0.50.66). Tests that play
## the transitions headless ([member forced] 1) get a blank picture of the
## screen's size.
static func picture_of(host: Control) -> Texture2D:
	if host == null or not host.is_inside_tree():
		return null
	if DisplayServer.get_name() == "headless":
		if forced != 1:
			return null
		var area := host.get_viewport_rect().size
		return ImageTexture.create_from_image(Image.create(maxi(int(area.x), 1), maxi(int(area.y), 1),
			false, Image.FORMAT_RGB8))
	var viewport := host.get_viewport()
	var window := viewport.get_texture()
	if window == null:
		return null
	# The picture's own pixels: the window's size (what a read back gave),
	# not the texture's reported size, which under the canvas stretch is
	# the window's times the stretch again.
	var pixels := Vector2i(window.get_size())
	if viewport is Window:
		pixels = (viewport as Window).size
	elif viewport is SubViewport:
		pixels = (viewport as SubViewport).size
	if pixels.x <= 0 or pixels.y <= 0:
		return null
	return Snapshot.make(host, window, pixels).get_texture()


func _ready() -> void:
	_born = Engine.get_process_frames()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	# The pane's world may pause; a transition never stands still.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if seconds <= 0.0:
		finish()
		return
	if zoom_target != null:
		_target_alpha = zoom_target.modulate.a
		# Its middle kept as it is laid out — before it is first drawn.
		zoom_target.resized.connect(_centre_target)
		_zoom_at(0.0)
		return
	_moments = moments(grid, order, strip, active, seed_value)
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = _shader
	var data := Image.create_from_data(grid.x, grid.y, false, Image.FORMAT_R8, _moments)
	_material.set_shader_parameter("order", ImageTexture.create_from_image(data))
	_material.set_shader_parameter("grid", Vector2(grid))
	material = _material
	_show(0.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not _over:
		_show(progress())


func _process(delta: float) -> void:
	if _over:
		return
	# The first frame after it was made carries the time spent making the
	# pane and reading the screen back: it counts a thirtieth at most, so
	# a slow build (a first visit, a Quest) never eats the transition.
	if Engine.get_process_frames() == _born + 1:
		delta = minf(delta, 1.0 / 30.0)
	_elapsed += delta
	var now := progress()
	if zoom_target != null:
		_zoom_at(now)
	else:
		_show(now)
	if _elapsed >= delay + seconds:
		finish()


## A press anywhere — a click, a key, a pad's button, a touch — ends it;
## the press goes on to what it was for.
func _input(event: InputEvent) -> void:
	if _over:
		return
	var skips := false
	if event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventScreenTouch:
		skips = event.is_pressed()
	elif event is InputEventKey:
		skips = event.is_pressed() and not (event as InputEventKey).echo
	if skips:
		finish()


## THE TRANSITION OVER, at once: the zoomed picture whole, the cover gone,
## [signal done] (once).
func finish() -> void:
	if _over:
		return
	_over = true
	if is_instance_valid(zoom_target):
		zoom_target.scale = Vector2.ONE
		zoom_target.modulate.a = _target_alpha
	done.emit()
	queue_free()


func _exit_tree() -> void:
	_release()


## The snapshot held let go (see [member before]).
func _release() -> void:
	if _held != null and is_instance_valid(_held):
		_held.drop()
	_held = null


## THE COVER HIDES WHAT THE SCREEN SHOWED where it now lies: [param
## picture] ([method picture_of], taken before the new picture was drawn),
## its region under the cover's place now — the canvas's units scaled to
## the window's pixels, as [method RevealDissolve.source_rect] — kept, so
## the old picture goes with the cover if its pane moves. Laid out first.
func take_screen(picture: Texture2D) -> void:
	before = picture
	var canvas := get_viewport_rect().size if is_inside_tree() else Vector2.ZERO
	if picture == null or canvas.x <= 0.0 or canvas.y <= 0.0:
		return
	var pixels := picture.get_size() / canvas
	var placed := get_global_rect()
	source = Rect2(placed.position * pixels, placed.size * pixels)
	queue_redraw()


## Whether it is over.
func is_over() -> bool:
	return _over


## How far it has come, 0 (nothing shown yet, through [member delay]) to 1.
func progress() -> float:
	if seconds <= 0.0:
		return 1.0
	return clampf((_elapsed - delay) / seconds, 0.0, 1.0)


## Tests: [param at] seconds in (the delay counted), as if they had passed.
func seek(at: float) -> void:
	_elapsed = at
	_process(0.0)


## Whether tile [param cell] has come (its moment past, as the shader reads it).
func revealed(cell: Vector2i) -> bool:
	if _moments.is_empty() or cell.x < 0 or cell.y < 0 or cell.x >= grid.x or cell.y >= grid.y:
		return progress() >= 1.0
	return float(_moments[cell.y * grid.x + cell.x]) <= progress() * 255.0


## EACH TILE'S MOMENT for a [param tiles] grid in [param tile_order], as
## bytes 1–255 by `y * x + x` (see the class doc):
##  - RANDOM: a random order of every tile, the k-th of n at k/n;
##  - STAGGERED: the columns in strips of [param strip_width]; strip s
##    starts at phase s of `strips + active − 1` and takes [param
##    active_strips] phases, drawing a tile a round as the leading strip,
##    two as the next … [param active_strips] as the trailing one — 1997's
##    rounds, so its tiles are a sixth, a half and the whole done after its
##    first, second and third phase (three at once) — its own tiles in a
##    random order.
static func moments(tiles: Vector2i, tile_order: Order, strip_width := CASTLE_STRIP,
		active_strips := CASTLE_ACTIVE, dice_seed := -1) -> PackedByteArray:
	var rng := RandomNumberGenerator.new()
	if dice_seed >= 0:
		rng.seed = dice_seed
	else:
		rng.randomize()
	var count := maxi(tiles.x, 1) * maxi(tiles.y, 1)
	var out := PackedByteArray()
	out.resize(count)
	if tile_order == Order.RANDOM:
		var cells := _shuffled(count, rng)
		for k in count:
			out[cells[k]] = _byte(float(k + 1) / count)
		return out
	var width := maxi(strip_width, 1)
	var strips := ceili(float(tiles.x) / width)
	var at_once := maxi(active_strips, 1)
	var phases := float(strips + at_once - 1)
	var whole := float(at_once * (at_once + 1)) / 2.0
	for s in strips:
		var cells: Array[int] = []
		for y in tiles.y:
			for x in range(s * width, mini((s + 1) * width, tiles.x)):
				cells.append(y * tiles.x + x)
		var order_in := _shuffled(cells.size(), rng)
		for k in cells.size():
			# The share done when this tile comes, into its phases: after
			# phase j (1-based) the strip has drawn (1 + … + j) / whole.
			var share := float(k + 1) / cells.size()
			var phase := 0.0
			var done_before := 0.0
			for j in range(1, at_once + 1):
				var done_after := float(j * (j + 1)) / 2.0 / whole
				if share <= done_after + 0.000001:
					phase = (j - 1) + (share - done_before) / (done_after - done_before)
					break
				done_before = done_after
			out[cells[order_in[k]]] = _byte((s + phase) / phases)
	return out


static func _shuffled(count: int, rng: RandomNumberGenerator) -> PackedInt32Array:
	var cells := PackedInt32Array()
	cells.resize(count)
	for i in count:
		cells[i] = i
	for i in range(count - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := cells[i]
		cells[i] = cells[j]
		cells[j] = swap
	return cells


## A moment 0–1 as its byte, 1–255.
static func _byte(moment: float) -> int:
	return clampi(ceili(moment * 255.0 - 0.000001), 1, 255)


func _show(now: float) -> void:
	if _material == null:
		return
	_material.set_shader_parameter("shown", now * 255.0)
	_material.set_shader_parameter("area", Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0)))
	queue_redraw()


func _centre_target() -> void:
	if not _over and is_instance_valid(zoom_target):
		zoom_target.pivot_offset = zoom_target.size / 2.0


## The zoom at [param now] (0–1): eased out, about the picture's middle.
func _zoom_at(now: float) -> void:
	if not is_instance_valid(zoom_target):
		return
	var eased := 1.0 - pow(1.0 - now, 3.0)
	var grow := lerpf(ZOOM_FROM, 1.0, eased)
	zoom_target.pivot_offset = zoom_target.size / 2.0
	zoom_target.scale = Vector2(grow, grow)
	zoom_target.modulate.a = _target_alpha * lerpf(ZOOM_FADE_FROM, 1.0, clampf(now / ZOOM_FADE_SHARE, 0.0, 1.0))


func _draw() -> void:
	if zoom_target != null or _over:
		return
	var area := Rect2(Vector2.ZERO, size)
	if before == null:
		draw_rect(area, ground)
		return
	draw_texture_rect_region(before, area, _source_now())


## The part of [member before] under the cover: [member source], else the
## whole picture.
func _source_now() -> Rect2:
	if before == null:
		return Rect2()
	if source.has_area():
		return source
	return Rect2(Vector2.ZERO, before.get_size())


## The cover's shader: a tile whose moment has come is dropped.
const SHADER := """
shader_type canvas_item;
// THE TILES NOT YET COME (TileReveal): each tile's moment is a byte of
// `order`; `shown` is the moment now, both 0-255.
uniform sampler2D order : filter_nearest;
uniform vec2 grid = vec2(1.0);
uniform vec2 area = vec2(1.0);
uniform float shown = 0.0;
varying vec2 at;

void vertex() {
	at = VERTEX;
}

void fragment() {
	vec2 cell = clamp(floor(at / area * grid), vec2(0.0), grid - vec2(1.0));
	float moment = floor(texelFetch(order, ivec2(cell), 0).r * 255.0 + 0.5);
	if (moment <= shown) {
		discard;
	}
}
"""
