class_name DungeonView
extends Control
## THE BOARD OF A CASTLE OR A DUNGEON, DRAWN AS 1.3 DREW IT —
## `DrawCastleDungeonBoard` (dungeonEncounter.c 1149–1401, "dE" below; the
## projection 1404–1418, the walk `SetDungeonPassageHighlight` 1463–1511;
## retail Palette.c 7194–7319 the same; the c4 research §2–§6) — on its
## 640 × 480 page, shown inside the board's pane ([DungeonPane]) at the
## pane's size ([member factor]). It only draws: the board itself and its
## rules are [DungeonBoard]'s, which it never changes.
##
## THE PAGE, IN 1997'S ORDER:
##  1. the cave's ground, `visit_dungeon` (CaveBkgd.pic), over the page;
##  2. the TITLE PLAQUE (`dungeon_plaques` = Dungbutt.spr frames 1, n × 2,
##     3, at the top, the least n with 29 + 24n at least the name's width)
##     and the castle's or the dungeon's name on it, centred at (320, 18),
##     white over a one-pixel shadow ([member title_text]);
##  3. under it, while the next duel brings something, 1997's line in green
##     #04bb34 at (320, 48): "+2 (14) Lives", the card, "First Move"
##     ([member gift_line], [method DungeonBoard.next_duel_line]);
##  4. THE CELLS, x from 14 down to 0 and for each y from 0 up to 12
##     ([method draw_order]), each tile frame 64 × 64 at its anchor less
##     (32, 48) — the anchor `(32 (x + y) − 96, 16 (y − x) + 272)`
##     ([method DungeonBoard.cell_to_page]):
##      - a cell NOT YET SEEN shows nothing — but a solid one with two or
##        more seen neighbours, the rock top (frame 20) [ours: 1997 slip — a
##        cull window a tile too narrow, dE:1217, never drew the rock of
##        (12, 10); here every cell's];
##      - a SEEN open cell: its BACK sprite — 1 for a wall up-right (x + 1),
##        2 up-left (y − 1), plus its look's first frame 0, 4, 24 or 28
##        ([method back_frame]) — then its FRONT sprite: 12, 1 for a wall
##        down-right (y + 1, or the last row), 2 down-left (x − 1), 4 more on
##        an odd row ([method front_frame]); a neighbour off the grid is a
##        wall. The front repaints the floor of a cell with no front wall
##        (frames 12 and 16 are the whole plain floor), so the back sprite's
##        floor marks only show where a front wall leaves the floor bare.
##        THE WHITE CASTLE AS 1997 SHOWED IT (the owner's ruling of
##        2026-10-28, from the shots of all its marks shown): its sheet alone
##        carries floor marks (the import's finding — frames 4 and 28, the
##        looks 1 and 3, and 16, the odd rows' front); the one 1997 showed,
##        frame 16's on the odd rows, shows; the looks' marks the front
##        painted over stay hidden — drawn the same way as every sheet;
##      - what stands in it, by its event: the dice (frame 10), the scroll
##        (9), the chest (8), the castle's wizard (49: a tile, the one of
##        his five poses 1997 drew), a room's creature — its world figure
##        and shadow at the anchor + (4, 4) less its own anchor, step 0 of
##        the way it faces: back down the corridor the hero must come up,
##        towards the neighbour nearer the entrance ([method facing],
##        dE:1333–1341); nothing for a cell passed;
##      - the entrance's word "Exit" over it;
##  5. on the first view only, the CARD IN EFFECT ([member effect_card]):
##     Dungbutt's frame 0 at (220, 52) resampled to 197 × 271, the card at
##     (244, 82) 150 × 224, "%s in effect." in brown #a8704a;
##  6. THE HERO LAST, over everything (1997 drew them on the front page):
##     the world's shadow and figure, the hero's own colours ([HeroColors]),
##     at the anchor less (77, 61), frame `facing · 5 + step`.
## [ours, the owner's board extras of 2026-10-27, on the page's foot, where
## 1997's cells never reach]: the life the next duel starts with and the
## rooms left ([member status_left], [member status_right]); a creature's
## name over its figure while the pointer rests on it ([member hover] —
## 1997 copied the name and drew it nowhere, dE:1332, DESIGNED NEVER USED
## D1; here on hover, the owner's pick); a short line that fades ([method
## say]).
##
## THE WALK (dE:1463–1511; [method walk]): 8 frames a cell, each 66 ms
## (`DelayUiTicks(5)`, two UI ticks of 33 ms), the figure 4 page pixels
## across and 2 up or down a frame and its walking step 2, 3, 4, 1, 2, 3,
## 4, 0; into an event's cell first a half walk of 4 frames, ending on step
## 1. [ours: 1997 slip — its last frame stood 4 pixels short of the cell
## until the next full redraw; here the walk ends on the cell.] [QoL] After
## an event the walk goes on from half way (1997 began it again from the
## cell before), and a hero pushed back walks the half back (1997 put them
## back at once). What the step newly saw shows as the walk ends (1997's
## redraw after it, [method hold_cells]) — [QoL] fading in over a fifth of
## a second ([constant FRESH_SECONDS]) with the Options' "Transitions" on
## ([method TileReveal.wanted]; 1997 showed it at once).
##
## HOW IT IS DRAWN [ours]: the page is composed at twice 1997's pixels
## ([constant SCALE]) in a [SubViewport] of its own — tiles pixel for pixel
## (a 2× skin's at its own pixels), words sharp — and that one picture is
## shown at the pane's size, smoothly scaled. The pages over the board (the
## treasure, a card lost) are an [EncounterStage] in front of it ([method
## show_page]).
##
## WITHOUT THE 1997 SKIN [ours, as the world's plain drawing]: a dark
## ground; the floors dark stone diamonds with a pale edge where a wall
## stands; the rock tops darker diamonds; the dice, the scroll and the chest
## small marks; the creatures and the wizard discs of the board's colour,
## the hero the world's plain figure; the plaque a dark gold-rimmed bar; the
## words as with the skin.

## A press on the page ([param page_point] in 1997's page pixels) — never a
## double click's second press.
signal clicked(page_point: Vector2, button: int)
## The pointer over the page.
signal pointed(page_point: Vector2)
## A card on the page right-clicked, to be read full screen.
signal card_read(card_name: String)

## The 1997 page, and how many times its pixels the page is composed at.
const PAGE := Vector2(640, 480)
const SCALE := 2
## A tile frame, and where it stands from its cell's anchor.
const TILE := Vector2(64, 64)
const TILE_ANCHOR := Vector2(32, 48)
## The tile sheets' frames (c4 §2): the chest, the scroll, the dice, the
## rock top, the front sprites' first, the castle's wizard.
const CHEST := 8
const SCROLL := 9
const DICE := 10
const ROCK := 20
const FRONT := 12
const ODD_ROW := 4
const WIZARD := 49
## The floor's four looks: their back sprites' first frames.
const LOOKS: Array[int] = [0, 4, 24, 28]
## The white castle's sheet, whose floor carries marks (the class's notes).
const WHITE := "dungeon_tiles_white"
## Dungbutt.spr (`dungeon_plaques`): the card's frame, the plaque's left
## end, its middle, its right end — each frame its own size (the sheet's
## `sizes`, these without it).
const PLAQUES := "dungeon_plaques"
const PLAQUE_SIZES: Array[Vector2] = [Vector2(201, 281), Vector2(40, 62), Vector2(24, 62), Vector2(39, 62)]
const PLAQUE_TOP := 1.0
## The name's place and the next duel's line's; the line's green.
const TITLE_AT := Vector2(320, 18)
const GIFT_AT := Vector2(320, 48)
const GIFT_INK := Color8(4, 187, 52)
## The card in effect (dE:1373–1381): the frame, the card, its words.
const EFFECT_FRAME := Rect2(220, 52, 197, 271)
const EFFECT_CARD := Rect2(244, 82, 150, 224)
const EFFECT_WORDS := Vector2(318, 67)
const BROWN := Color8(168, 112, 74)
## The words' sizes, in page points: the name (1997's font slot 4), the
## next duel's line and the foot's (slot 1), "Exit" and a name on hover.
const TITLE_POINTS := 20
const LINE_POINTS := 14
const EXIT_POINTS := 15
## Where a room's figure stands from its cell's anchor (dE:1344–1350), and
## the hero's figure's anchor in its frame (the world's).
const FIGURE_OFFSET := Vector2(4, 4)
const HERO_ANCHOR := Vector2(77, 61)
## The walk (the class's notes): its frames, the half, a frame's length.
const STEPS := 8
const HALF := 4
const FRAME_SECONDS := 0.066
## A frame's way across the page, by the board's way (1 −y … 7 −x).
const WALK: Dictionary = {1: Vector2(-4, -2), 3: Vector2(4, -2), 5: Vector2(4, 2), 7: Vector2(-4, 2)}
## The page's foot [ours]: the status line's height, the said line's.
const STATUS_Y := 458.0
const SAID_Y := 432.0
const SAID_SECONDS := 2.6
## What a step newly saw fades in over this long [QoL].
const FRESH_SECONDS := 0.2
## The plain look's colours.
const PLAIN_GROUND := Color8(16, 12, 12)
const PLAIN_FLOOR := Color8(62, 54, 50)
const PLAIN_FLOOR_EDGE := Color8(88, 78, 70)
const PLAIN_WALL := Color8(176, 156, 128)
const PLAIN_ROCK := Color8(30, 24, 24)
const PLAIN_ROCK_EDGE := Color8(70, 52, 44)
const NOWHERE := Vector2i(-1, -1)

## How long a walk's frame is, in seconds — 1997's 66 ms; 0 walks at once
## (the tests).
static var frame_seconds := FRAME_SECONDS

## The board drawn.
var board: DungeonBoard:
	set(value):
		board = value
		redraw()
## The page's size on the screen, times 1997's.
var factor := 1.0
## The hero's figure in their colours ([method HeroColors.dressed]), null
## for the 1997 one; `male` or `female`.
var hero_sheet: Texture2D
var walker := "male"
## The words on the page: the name on the plaque, the next duel's line, the
## foot's two ([ours]).
var title_text := ""
var gift_line := ""
var status_left := ""
var status_right := ""
## The card in effect shown on the first view ("" none).
var effect_card := ""
## The cell whose creature is named, and its name ([constant NOWHERE]: none).
var hover := NOWHERE
var hover_text := ""
## The sheets ([WorldArt]: the tiles' grid, the figures').
var art := WorldArt.new()

var _port: SubViewport
var _board_layer: Node2D
var _hero_layer: Node2D
var _picture: TextureRect
var _effect: CardPreview
var _stage: EncounterStage
## The cells as drawn while a walk is under way ([method hold_cells]); empty
## for the board's own.
var _held := PackedInt32Array()
## The walk under way: `{from, way, frame, end, done}`; `{}` for none.
var _walk := {}
var _walk_time := 0.0
## The walk paused half way into an event's cell: `{from, way, frame}`.
var _pose := {}
var _said := ""
var _said_left := 0.0
## The cells a step newly showed, fading in ([constant FRESH_SECONDS]).
var _fresh := {}
var _fresh_left := 0.0


func _init() -> void:
	name = "DungeonView"
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_port = SubViewport.new()
	_port.name = "Page"
	_port.size = Vector2i(PAGE) * SCALE
	_port.transparent_bg = false
	_port.disable_3d = true
	_port.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_port)
	_board_layer = Node2D.new()
	_board_layer.name = "Board"
	_board_layer.scale = Vector2(SCALE, SCALE)
	_board_layer.draw.connect(_paint_board)
	_port.add_child(_board_layer)
	_hero_layer = Node2D.new()
	_hero_layer.name = "Hero"
	_hero_layer.scale = Vector2(SCALE, SCALE)
	_hero_layer.draw.connect(_paint_hero)
	_port.add_child(_hero_layer)
	_picture = TextureRect.new()
	_picture.name = "Picture"
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_picture)
	_stage = EncounterStage.new()
	_stage.visible = false
	_stage.card_read.connect(func(card_name: String) -> void: card_read.emit(card_name))
	add_child(_stage)
	visibility_changed.connect(func() -> void:
		_port.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() \
			else SubViewport.UPDATE_DISABLED)


func _ready() -> void:
	_picture.texture = _port.get_texture()
	set_factor(factor)


## The page at [param value] times 1997's size.
func set_factor(value: float) -> void:
	factor = value
	custom_minimum_size = PAGE * factor
	size = custom_minimum_size
	_picture.size = custom_minimum_size
	_stage.set_factor(factor)
	_place_effect()


## Everything drawn again (the board changed: a step, an event, a word).
func redraw() -> void:
	if _board_layer != null:
		_board_layer.queue_redraw()
		_hero_layer.queue_redraw()


# ------------------------------------------------------------ the rules --

## THE CELLS IN 1997'S ORDER: x from 14 down to 0, for each y from 0 up to
## 12 — back to front.
static func draw_order() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in range(DungeonBoard.WIDTH - 1, -1, -1):
		for y in DungeonBoard.HEIGHT:
			out.append(Vector2i(x, y))
	return out


## A seen cell's BACK sprite (dE:1240–1262): 1 for a wall up-right (x + 1),
## 2 for one up-left (y − 1), on the first frame of look [param look].
static func back_frame(wall_up_right: bool, wall_up_left: bool, look: int) -> int:
	return int(wall_up_right) + 2 * int(wall_up_left) + LOOKS[clampi(look, 0, 3)]


## A seen cell's FRONT sprite (dE:1264–1286): 12, 1 for a wall down-right
## (y + 1, or the last row), 2 for one down-left (x − 1), 4 more on an odd
## row [param row].
static func front_frame(wall_down_right: bool, wall_down_left: bool, row: int) -> int:
	return FRONT + int(wall_down_right) + 2 * int(wall_down_left) + (ODD_ROW if row % 2 == 1 else 0)


## The way a room's creature at [param cell] faces (dE:1333–1341): 5 (down
## the screen to the right), unless a neighbour's depth from the entrance
## ([param depth_of] of a cell, 0 none) is smaller than its own — the last
## such of 1, 3, 5, 7. 1997's world heading: the frame is `((d + 2) & 7) · 5`.
static func facing(depth_of: Callable, cell: Vector2i) -> int:
	var own := int(depth_of.call(cell))
	var out := 5
	for way in [1, 3, 5, 7]:
		var near := int(depth_of.call(cell + DungeonBoard.STEPS[way]))
		if near != 0 and near < own:
			out = way
	return out


## THE WALK'S FRAMES one way [param way] (the class's notes): `{offset,
## step}` for frames 1–8 — or 1–4 when [param half] — the offset from the
## cell's anchor in page pixels.
static func walk_frames(way: int, half := false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for frame in range(1, (HALF if half else STEPS) + 1):
		out.append({"offset": WALK.get(way, Vector2.ZERO) * frame, "step": walk_step(frame)})
	return out


## The walking step of frame [param frame] (0–8): `(f mod 4) + 1` under 8,
## 0 standing (frame 0 or 8).
static func walk_step(frame: int) -> int:
	if frame <= 0 or frame >= STEPS:
		return 0
	return frame % 4 + 1


## THE PLAQUE'S MIDDLE PIECES for a name [param width] page pixels wide: the
## least n with 29 + 24n at least the width (dE:1180–1190).
static func plaque_middles(width: float) -> int:
	return maxi(0, ceili((width - 29.0) / 24.0))


## The plaque's left end for [param middles] pieces: 320 − 12n − 40.
static func plaque_left(middles: int) -> float:
	return 320.0 - 12.0 * middles - 40.0


## The tile frame's top-left for cell [param cell].
static func tile_at(cell: Vector2i) -> Vector2:
	return Vector2(DungeonBoard.cell_to_page(cell)) - TILE_ANCHOR


# -------------------------------------------------------------- reading --

## The cell's 1997 value as drawn ([method hold_cells]); 0 off the grid.
func value(at: Vector2i) -> int:
	if board == null or not DungeonBoard.inside(at):
		return 0
	var cells := _held if not _held.is_empty() else board.cells
	var i := at.x * DungeonBoard.HEIGHT + at.y
	return cells[i] if i < cells.size() else 0


func _seen(at: Vector2i) -> bool:
	return value(at) & DungeonBoard.SEEN != 0


func _solid(at: Vector2i) -> bool:
	return value(at) == 0


## Whether an unseen cell shows its rock top: solid, two or more of its four
## neighbours seen (dE:1214–1236).
func shows_rock(at: Vector2i) -> bool:
	if not _solid(at) or not DungeonBoard.inside(at):
		return false
	var seen := 0
	for way in DungeonBoard.STEPS:
		if _seen(at + DungeonBoard.STEPS[way]):
			seen += 1
	return seen >= 2


## What a cell shows (tests read it): `{rock}`, or `{back, front, stands,
## exit}` — `stands` "" or "dice", "scroll", "chest", "wizard", "creature"
## with `row` and `facing` — or `{}` for nothing.
func cell_look(at: Vector2i) -> Dictionary:
	if not _seen(at):
		return {"rock": true} if shows_rock(at) else {}
	if _solid(at):
		return {}
	var out := {"back": back_frame(_solid(at + Vector2i(1, 0)), _solid(at + Vector2i(0, -1)), board.look(at)),
		"front": front_frame(_solid(at + Vector2i(0, 1)) or at.y == DungeonBoard.HEIGHT - 1,
			_solid(at + Vector2i(-1, 0)), at.y),
		"stands": "", "exit": at == DungeonBoard.ENTRANCE}
	var event := (value(at) & DungeonBoard.EVENT_MASK) >> DungeonBoard.EVENT_SHIFT
	match event:
		DungeonBoard.DICE:
			out["stands"] = "dice"
		DungeonBoard.SCROLL:
			out["stands"] = "scroll"
		DungeonBoard.TREASURE:
			out["stands"] = "chest"
		DungeonBoard.WIZARD:
			out["stands"] = "wizard"
			out["row"] = board.room_creature(event)
		_:
			if DungeonBoard.is_room(event):
				out["stands"] = "creature"
				out["row"] = board.room_creature(event)
				out["facing"] = facing(board.distance, at)
	return out


## The figure a room's creature at [param cell] shows: its rectangle on the
## page (the body's frame), or an empty one for none.
func figure_rect(at: Vector2i) -> Rect2:
	var look := cell_look(at)
	var anchor := Vector2(DungeonBoard.cell_to_page(at))
	var stands := String(look.get("stands", ""))
	if stands in ["creature", "wizard"] and not skinned():
		# The plain disc ([method WorldView.draw_creature_plain]).
		var disc := anchor + (FIGURE_OFFSET if stands == "creature" else Vector2.ZERO) + Vector2(0, -12)
		return Rect2(disc - Vector2(12, 12), Vector2(24, 24))
	match stands:
		"creature":
			var key := String(CreatureBook.sprite_keys(int(look["row"]))["body"])
			var top := Vector2(77, WorldArt.CREATURE_TOP)
			if art.texture(key) != null:
				top = art.creature_anchor(key)
			else:
				# The disc a skin without this creature's sheet draws.
				return Rect2(anchor + FIGURE_OFFSET + Vector2(-12, -24), Vector2(24, 24))
			# The body's middle two thirds, from its head to its feet.
			return Rect2(anchor + FIGURE_OFFSET + Vector2(-top.x * 0.4, -top.y), Vector2(top.x * 0.8, top.y + 6))
		"wizard":
			return Rect2(anchor + Vector2(-20, -50), Vector2(40, 56))
	return Rect2()


## THE CELL UNDER page point [param point]: a seen room's figure first (it
## stands above its floor, so a click on it is a click on its room), else
## the floor's diamond ([method DungeonBoard.page_to_cell]).
func cell_at(point: Vector2) -> Vector2i:
	if board != null:
		var order := draw_order()
		order.reverse()
		for at in order:
			var rect := figure_rect(at)
			if rect.has_area() and rect.has_point(point):
				return at
	return DungeonBoard.page_to_cell(point)


## Where the hero's figure stands now on the page (the cell's anchor, or
## the walk's point).
func hero_point() -> Vector2:
	var shown := _walk if not _walk.is_empty() else _pose
	if not shown.is_empty():
		return Vector2(DungeonBoard.cell_to_page(shown["from"])) + WALK.get(int(shown["way"]), Vector2.ZERO) \
			* int(shown["frame"])
	return Vector2(DungeonBoard.cell_to_page(board.hero)) if board != null else Vector2.ZERO


## WHERE THE HERO IS DRAWN NOW [QoL] (the smoothness pass, 0.50.66): the
## walk's point ([method hero_point]) carried on toward the next frame's by
## the time since its frame began — the figure slides at the screen's own
## rate, not in 1997's 66 ms hops of four page pixels — on the composed
## page's own pixels ([constant SCALE] to a page pixel). The pose, the
## walk's frames and its length stay 1997's ([method hero_step]); standing,
## it is [method hero_point].
func shown_hero_point() -> Vector2:
	var at := hero_point()
	if _walk.is_empty() or frame_seconds <= 0.0:
		return at
	var step := 1 if int(_walk["end"]) > int(_walk["frame"]) else -1
	var part := clampf(_walk_time / frame_seconds, 0.0, 1.0)
	var way: Vector2 = WALK.get(int(_walk["way"]), Vector2.ZERO)
	at += way * float(step) * part
	return (at * SCALE).round() / SCALE


## The hero's walking step now (0 standing).
func hero_step() -> int:
	var shown := _walk if not _walk.is_empty() else _pose
	return walk_step(int(shown["frame"])) if not shown.is_empty() else 0


# ------------------------------------------------------------ the walk --

## THE CELLS SHOWN AS [param cells] (the board's before its step) while a
## walk is under way: what the step saw is shown as it ends (1997's redraw
## after the walk). The walk's end lets go.
func hold_cells(cells: PackedInt32Array) -> void:
	_held = cells.duplicate()


## A WALK: from cell [param from] the way [param way], frames
## [param start] to [param end] (0–8: a whole step 0 → 8, the half into an
## event 0 → 4, on from half way 4 → 8, pushed back 4 → 0), a frame each
## [member frame_seconds]; [param done] called at its end. At once when the
## frames take no time (the tests).
func walk(from: Vector2i, way: int, start: int, end: int, done := Callable()) -> void:
	_pose = {}
	_walk = {"from": from, "way": way, "frame": start, "end": end, "done": done}
	_walk_time = 0.0
	if frame_seconds <= 0.0 or start == end:
		_walk_over()
		return
	_hero_layer.queue_redraw()


## The hero standing on their cell again (a walk paused half way put by).
func stand() -> void:
	_pose = {}
	redraw()


## Whether a walk is under way.
func walking() -> bool:
	return not _walk.is_empty()


## The walk at its end at once (a test, a pane closing).
func finish_walk() -> void:
	if not _walk.is_empty():
		_walk_over()


func _walk_over() -> void:
	var done: Callable = _walk.get("done", Callable())
	var stops := int(_walk["end"]) % STEPS != 0
	if stops:
		# Half way into an event's cell: the hero waits there.
		_pose = {"from": _walk["from"], "way": _walk["way"], "frame": _walk["end"]}
	_walk = {}
	_fade_in_what_was_held()
	_held = PackedInt32Array()
	redraw()
	if done.is_valid():
		done.call()


func _process(delta: float) -> void:
	# The fade of what the last step saw first: a walk ending in this frame
	# starts a fade of its own.
	if _fresh_left > 0.0:
		_fresh_left -= delta
		if _fresh_left <= 0.0:
			_fresh.clear()
		_board_layer.queue_redraw()
	if not _walk.is_empty():
		_walk_time += delta
		while not _walk.is_empty() and _walk_time >= frame_seconds:
			_walk_time -= frame_seconds
			var step := 1 if int(_walk["end"]) > int(_walk["frame"]) else -1
			_walk["frame"] = int(_walk["frame"]) + step
			if int(_walk["frame"]) == int(_walk["end"]):
				_walk_over()
		_hero_layer.queue_redraw()
	if _said_left > 0.0:
		_said_left -= delta
		if _said_left <= 0.0:
			_said = ""
		_board_layer.queue_redraw()


## The cells drawn now that the held cells did not draw: they fade in.
func _fade_in_what_was_held() -> void:
	if _held.is_empty() or board == null or not TileReveal.wanted():
		return
	var before := {}
	for at in draw_order():
		if not cell_look(at).is_empty():
			before[at] = true
	var held := _held
	_held = PackedInt32Array()
	_fresh.clear()
	for at in draw_order():
		if not before.has(at) and not cell_look(at).is_empty():
			_fresh[at] = true
	_held = held
	_fresh_left = FRESH_SECONDS if not _fresh.is_empty() else 0.0


## How opaque cell [param at] is drawn: 1, or fading in ([member _fresh]).
func _alpha(at: Vector2i) -> float:
	if _fresh.has(at) and _fresh_left > 0.0:
		return clampf(1.0 - _fresh_left / FRESH_SECONDS, 0.0, 1.0)
	return 1.0


# ------------------------------------------------------------ the words --

## A short line on the page's foot that fades [ours] ("" puts it away).
func say(text: String) -> void:
	_said = text
	_said_left = SAID_SECONDS if text != "" else 0.0
	redraw()


## The line said now ("" none).
func said() -> String:
	return _said


# ------------------------------------------------- the card in effect --

## THE CARD IN EFFECT on the first view ([param card_name]; "" puts it
## away): its frame and its words on the page, the card over it (a right
## click reads it).
func show_effect(card_name: String) -> void:
	effect_card = card_name
	if is_instance_valid(_effect):
		PaneStyle.drop(_effect)
	_effect = null
	if card_name != "" and CardRegistry.has_card(card_name):
		var shown := CardPreview.new()
		shown.name = "EffectCard"
		shown.docked = true
		shown.mouse_filter = Control.MOUSE_FILTER_STOP
		shown.show_card(CardInstance.new(CardRegistry.get_card(card_name), -1, 0))
		shown.gui_input.connect(func(input: InputEvent) -> void:
			if PaneStyle.right_click(input):
				card_read.emit(card_name)
			elif input is InputEventMouseButton and (input as InputEventMouseButton).pressed \
					and not (input as InputEventMouseButton).double_click:
				# A double click's second press is no click (h1-1).
				clicked.emit(EFFECT_CARD.get_center(), (input as InputEventMouseButton).button_index))
		add_child(shown)
		move_child(shown, _stage.get_index())
		_effect = shown
		_place_effect()
	redraw()


func _place_effect() -> void:
	if not is_instance_valid(_effect):
		return
	_effect.position = EFFECT_CARD.position * factor
	var fit := EFFECT_CARD.size.x / CardPreview.SIZE.x * factor
	_effect.scale = Vector2(fit, fit)


## The card shown in effect ("" none).
func effect_shown() -> String:
	return effect_card if is_instance_valid(_effect) or effect_card != "" else ""


# ------------------------------------------------------------ the pages --

## A PAGE OVER THE BOARD (the treasure found, a card lost): the stage, its
## parts cleared, ground [param key] — the caller lays its parts.
func show_page(key: String) -> EncounterStage:
	_stage.clear()
	_stage.ground(key)
	_stage.visible = true
	return _stage


## The board again.
func hide_page() -> void:
	_stage.clear()
	_stage.visible = false


## The page over the board, or null.
func page() -> EncounterStage:
	return _stage if _stage.visible else null


# ------------------------------------------------------------ the mouse --

func _gui_input(input: InputEvent) -> void:
	var press := input as InputEventMouseButton
	if press != null and press.pressed and press.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		accept_event()
		# A double click's second press is no click (part C stage C3, h1-1:
		# it stepped the hero nobody moved, or put away the box or the card
		# found the first press had just brought, unread), as on every
		# pane's buttons (part B's q2-2).
		if not press.double_click:
			clicked.emit(press.position / factor, press.button_index)
		return
	var motion := input as InputEventMouseMotion
	if motion != null:
		pointed.emit(motion.position / factor)


# ----------------------------------------------------------- the drawing --

## Whether the 1997 sheets are there to draw the board with.
func skinned() -> bool:
	return board != null and art.texture(board.sheet) != null


func _paint_board() -> void:
	var canvas := _board_layer
	if board == null:
		return
	var sheet := art.texture(board.sheet)
	var ground := GameSkin.texture("visit_dungeon") if sheet != null else null
	if ground != null:
		canvas.draw_texture_rect(ground, Rect2(Vector2.ZERO, PAGE), false)
	else:
		canvas.draw_rect(Rect2(Vector2.ZERO, PAGE), PLAIN_GROUND)
	_paint_plaque(canvas)
	for at in draw_order():
		var look := cell_look(at)
		if look.is_empty():
			continue
		var tile := tile_at(at)
		var ink := Color(1, 1, 1, _alpha(at))
		if sheet == null:
			_paint_plain_cell(canvas, at, look, ink.a)
			continue
		if look.has("rock"):
			_blit(canvas, sheet, ROCK, tile, ink)
			continue
		_blit(canvas, sheet, int(look["back"]), tile, ink)
		_paint_front(canvas, sheet, int(look["front"]), tile, ink)
		_paint_stander(canvas, sheet, at, look, ink)
	for at in draw_order():
		if at == DungeonBoard.ENTRANCE and _seen(at):
			var anchor := Vector2(DungeonBoard.cell_to_page(at))
			_words(canvas, DungeonBoard.EXIT, anchor + Vector2(0, -4), EXIT_POINTS, Color.WHITE)
	if effect_card != "":
		_paint_effect(canvas)
	if hover != NOWHERE and hover_text != "":
		var rect := figure_rect(hover)
		var over := Vector2(rect.get_center().x, rect.position.y - 8) if rect.has_area() \
			else Vector2(DungeonBoard.cell_to_page(hover)) + Vector2(0, -52)
		_words(canvas, hover_text, over, EXIT_POINTS, Color.WHITE)
	if gift_line != "":
		_words(canvas, gift_line, GIFT_AT, LINE_POINTS, GIFT_INK, true)
	if status_left != "":
		_words(canvas, status_left, Vector2(14, STATUS_Y), LINE_POINTS, PaneStyle.GOLD, true,
			HORIZONTAL_ALIGNMENT_LEFT)
	if status_right != "":
		_words(canvas, status_right, Vector2(PAGE.x - 14, STATUS_Y), LINE_POINTS, PaneStyle.INK, true,
			HORIZONTAL_ALIGNMENT_RIGHT)
	if _said != "":
		var fade := clampf(_said_left / 0.6, 0.0, 1.0)
		_words(canvas, _said, Vector2(PAGE.x / 2.0, SAID_Y), LINE_POINTS + 1, Color(PaneStyle.LIT, fade), true)


## The plaque and the name on it (dE:1178–1200).
func _paint_plaque(canvas: CanvasItem) -> void:
	if title_text == "":
		return
	var font := _title_font()
	var width := words_width(font, title_text, TITLE_POINTS)
	var middles := plaque_middles(width)
	var left := plaque_left(middles)
	var sheet := art.texture(PLAQUES)
	var sizes := _plaque_sizes()
	if sheet != null and skinned():
		var x := left
		var pieces: Array[int] = [1]
		for i in middles:
			pieces.append(2)
		pieces.append(3)
		for piece in pieces:
			var own: Vector2 = sizes[piece]
			var region := Rect2(art.frame_rect(PLAQUES, piece).position, own)
			canvas.draw_texture_rect_region(sheet, Rect2(Vector2(x, PLAQUE_TOP), own), region)
			x += own.x
	else:
		var box := Rect2(left + 6, PLAQUE_TOP + 4, sizes[1].x + sizes[2].x * middles + sizes[3].x - 12, 30)
		var face := StyleBoxFlat.new()
		face.bg_color = Color(0.06, 0.04, 0.03, 0.92)
		face.border_color = Color(PaneStyle.GOLD, 0.8)
		face.set_border_width_all(1)
		face.set_corner_radius_all(6)
		canvas.draw_style_box(face, box)
	_words(canvas, title_text, TITLE_AT, TITLE_POINTS, Color.WHITE, false, HORIZONTAL_ALIGNMENT_CENTER, font)


## Dungbutt's frames' own sizes: the sheet's `sizes`, else 1997's.
func _plaque_sizes() -> Array[Vector2]:
	var out: Array[Vector2] = PLAQUE_SIZES.duplicate()
	var sizes: Array = GameSkin.metadata(PLAQUES).get("sizes", [])
	for i in mini(sizes.size(), out.size()):
		var pair: Array = sizes[i]
		if pair.size() == 2:
			out[i] = Vector2(int(pair[0]), int(pair[1]))
	return out


## The front sprite (dE:1264–1286), every sheet alike — the white castle's
## too (the class's notes).
func _paint_front(canvas: CanvasItem, sheet: Texture2D, frame: int, tile: Vector2, ink := Color.WHITE) -> void:
	_blit(canvas, sheet, frame, tile, ink)


## What stands in a seen cell: a prop, the wizard, a creature.
func _paint_stander(canvas: CanvasItem, sheet: Texture2D, at: Vector2i, look: Dictionary,
		ink := Color.WHITE) -> void:
	var tile := tile_at(at)
	match String(look.get("stands", "")):
		"dice":
			_blit(canvas, sheet, DICE, tile, ink)
		"scroll":
			_blit(canvas, sheet, SCROLL, tile, ink)
		"chest":
			_blit(canvas, sheet, CHEST, tile, ink)
		"wizard":
			if not board.castle or art.frame_rect(board.sheet, WIZARD).end.y > sheet.get_size().y:
				WorldView.draw_creature_plain(canvas, Vector2(DungeonBoard.cell_to_page(at)), board.color)
			else:
				_blit(canvas, sheet, WIZARD, tile, ink)
		"creature":
			_paint_creature(canvas, at, int(look["row"]), int(look["facing"]), ink)


## A room's creature: its world shadow, then its body, step 0 of its facing
## (dE:1344–1350); a disc of the board's colour without its sheet.
func _paint_creature(canvas: CanvasItem, at: Vector2i, row: int, way: int, ink := Color.WHITE) -> void:
	var feet := Vector2(DungeonBoard.cell_to_page(at)) + FIGURE_OFFSET
	var keys := CreatureBook.sprite_keys(row)
	var body := art.texture(String(keys["body"]))
	if body == null:
		WorldView.draw_creature_plain(canvas, feet, board.color)
		return
	var anchor := art.creature_anchor(String(keys["body"]))
	var frame := WorldArt.creature_frame(way, 0)
	var shadow := art.texture(String(keys["shadow"]))
	if shadow != null:
		var cut := art.creature_rect(String(keys["shadow"]), frame)
		canvas.draw_texture_rect_region(shadow, Rect2(feet - anchor, cut.size), cut, ink)
	var rect := art.creature_rect(String(keys["body"]), frame)
	canvas.draw_texture_rect_region(body, Rect2(feet - anchor, rect.size), rect, ink)


## The card in effect's frame and words (the card is a control over them).
func _paint_effect(canvas: CanvasItem) -> void:
	var sheet := art.texture(PLAQUES)
	if sheet != null and skinned():
		var own: Vector2 = _plaque_sizes()[0]
		canvas.draw_texture_rect_region(sheet, EFFECT_FRAME, Rect2(art.frame_rect(PLAQUES, 0).position, own))
	else:
		var face := StyleBoxFlat.new()
		face.bg_color = Color(0.08, 0.06, 0.04, 0.95)
		face.border_color = Color(PaneStyle.GOLD, 0.8)
		face.set_border_width_all(2)
		face.set_corner_radius_all(6)
		canvas.draw_style_box(face, EFFECT_FRAME)
	var line := DungeonBoard.IN_EFFECT % effect_card
	var points := LINE_POINTS
	var font := _body_font()
	while points > 9 and words_width(font, line, points) > EFFECT_FRAME.size.x - 16:
		points -= 1
	_words(canvas, line, EFFECT_WORDS, points, BROWN if skinned() else PaneStyle.GOLD, false)


## THE PLAIN CELL [ours] (the class's notes).
func _paint_plain_cell(canvas: CanvasItem, at: Vector2i, look: Dictionary, alpha := 1.0) -> void:
	var p := Vector2(DungeonBoard.cell_to_page(at))
	var top := p + Vector2(0, -16)
	var right := p + Vector2(32, 0)
	var bottom := p + Vector2(0, 16)
	var left := p + Vector2(-32, 0)
	var diamond := PackedVector2Array([top, right, bottom, left])
	if look.has("rock"):
		canvas.draw_colored_polygon(diamond, Color(PLAIN_ROCK, alpha))
		canvas.draw_polyline(PackedVector2Array([top, right, bottom, left, top]), Color(PLAIN_ROCK_EDGE, alpha), 1.0)
		return
	canvas.draw_colored_polygon(diamond, Color(PLAIN_FLOOR, alpha))
	canvas.draw_polyline(PackedVector2Array([top, right, bottom, left, top]), Color(PLAIN_FLOOR_EDGE, alpha), 1.0)
	var walls := [[at + Vector2i(1, 0), top, right], [at + Vector2i(0, -1), left, top],
		[at + Vector2i(0, 1), right, bottom], [at + Vector2i(-1, 0), bottom, left]]
	for wall in walls:
		var beyond: Vector2i = wall[0]
		if _solid(beyond) or (beyond.y >= DungeonBoard.HEIGHT):
			canvas.draw_line(wall[1], wall[2], Color(PLAIN_WALL, alpha), 2.5)
	match String(look.get("stands", "")):
		"dice":
			canvas.draw_rect(Rect2(p + Vector2(-6, -12), Vector2(12, 12)), Color8(236, 230, 214))
			for dot in [Vector2(-3, -9), Vector2(0, -6), Vector2(3, -3)]:
				canvas.draw_circle(p + dot, 1.3, Color8(30, 20, 20))
		"scroll":
			canvas.draw_rect(Rect2(p + Vector2(-7, -14), Vector2(14, 12)), Color8(214, 190, 130))
			canvas.draw_rect(Rect2(p + Vector2(-7, -14), Vector2(14, 12)), Color8(120, 80, 40), false, 1.0)
		"chest":
			canvas.draw_rect(Rect2(p + Vector2(-9, -12), Vector2(18, 11)), Color8(120, 70, 30))
			canvas.draw_rect(Rect2(p + Vector2(-9, -12), Vector2(18, 11)), PaneStyle.GOLD, false, 1.5)
		"wizard":
			WorldView.draw_creature_plain(canvas, p, board.color)
			canvas.draw_arc(p + Vector2(0, -12), 13, 0, TAU, 24, PaneStyle.GOLD, 1.5)
		"creature":
			WorldView.draw_creature_plain(canvas, p + FIGURE_OFFSET, board.color)


## THE HERO, over everything: the world's shadow and figure (dE:1383–1400).
func _paint_hero() -> void:
	if board == null:
		return
	var canvas := _hero_layer
	var feet := shown_hero_point()
	var key := "world_ego_f" if walker == "female" else "world_ego_m"
	var sheet := hero_sheet if hero_sheet != null else art.texture(key)
	if sheet == null or not skinned():
		WorldView.draw_hero_plain(canvas, feet)
		return
	var frame := clampi(board.facing, 0, 7) * 5 + hero_step()
	var shadow := art.texture("world_sego_f")
	if shadow != null:
		var cut := art.frame_rect("world_sego_f", frame)
		canvas.draw_texture_rect_region(shadow, Rect2(feet - HERO_ANCHOR, cut.size), cut)
	var rect := art.frame_rect(key, frame)
	canvas.draw_texture_rect_region(sheet, Rect2(feet - HERO_ANCHOR, rect.size), rect)


func _blit(canvas: CanvasItem, sheet: Texture2D, frame: int, at: Vector2, ink := Color.WHITE) -> void:
	canvas.draw_texture_rect_region(sheet, Rect2(at, TILE), art.frame_rect(board.sheet, frame), ink)


## Words [param text] on the page at [param at] (centred, or as [param
## align] says from there), [param points] page points, a one-pixel black
## shadow under them (1997's); [param body] the body face, else the title's.
func _words(canvas: CanvasItem, text: String, at: Vector2, points: int, ink: Color, body := false,
		align := HORIZONTAL_ALIGNMENT_CENTER, face: Font = null) -> void:
	var font := face if face != null else (_body_font() if body else _title_font())
	# Set at the composed page's own pixels (the layer's scale undone), so
	# the letters are drawn sharp, not a small drawing enlarged.
	var s := float(SCALE)
	var size := int(round(points * s))
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var left := at.x * s - width / 2.0
	if align == HORIZONTAL_ALIGNMENT_LEFT:
		left = at.x * s
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		left = at.x * s - width
	var base := at.y * s + (font.get_ascent(size) - font.get_descent(size)) / 2.0
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 / s, 1.0 / s))
	canvas.draw_string(font, Vector2(left + s, base + s), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Color(0, 0, 0, 0.9 * ink.a))
	canvas.draw_string(font, Vector2(left, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## How wide [param text] is on the page at [param points] in [param font].
static func words_width(font: Font, text: String, points: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(points * SCALE))).x / SCALE


func _title_font() -> Font:
	var face := GameSkin.font("font_title")
	return face if face != null else ThemeDB.fallback_font


func _body_font() -> Font:
	var face := GameSkin.font("font_body")
	return face if face != null else ThemeDB.fallback_font
