class_name PackCheckScreen
extends RefCounted
## THE CARD PACK CHECK, ON THE SCREEN (2026-10-11, the owner's Meta Quest:
## *"the check took 6 mins for all 9 packs"* — on a splash screen that
## never moved, which read as a game stuck at its start).
##
## The first start after a card pack is added or changed reads every
## picture in it once and compares them with the pack's manifest
## ([PackSeal]); every later start skips that. The check runs in
## [method CardPacks.discover] at the start, before the title screen and
## before the engine's first frame — so this screen draws ITSELF, a few
## times a second: which pack, how many of how many, how far through its
## pictures, and that this happens once.
##
## IT DRAWS STRAIGHT ONTO THE RENDERING SERVER — its own canvas on the
## root viewport, a rectangle, a bar and the fallback font's strings into
## one canvas item, then [method RenderingServer.force_draw]. Controls
## were tried first and showed nothing (Xvfb screenshots of a real start,
## 2026-10-11: the engine's grey clear colour all through the check): a
## Control paints in a deferred call, and nothing deferred runs before the
## main loop's first frame, which is after this check.
##
## Only where there is a screen: a headless run (the tests, the Deck Lab,
## the referee, a packaged build's `--verify-pack-N`) gets none.

## The screen is drawn again after this many milliseconds, not per picture:
## a draw at the start costs a frame (under Xvfb's software renderer, a draw
## every 120 ms took the nine packs from 7.5 s to 12.7 s; a GPU pays far less).
const DRAW_EVERY_MS := 250
const INK := Color(0.93, 0.89, 0.79)
const DIM := Color(0.70, 0.66, 0.58)
const GROUND := Color(0.035, 0.03, 0.025)
const BAR := Color(0.78, 0.62, 0.30)
const BAR_GROUND := Color(0.18, 0.15, 0.11)
## Above every canvas the game makes.
const STACKING := 4096
const WIDTH := 620.0

const TITLE := "Checking the card packs"
const NOTE := "Every card picture is read once, the first time a pack is added or changed. Later starts skip this."

var _viewport: Viewport
var _canvas := RID()
var _item := RID()
var _pack := ""
var _fraction := 0.0
var _drawn_ms := -1000000
var _index := 0
var _total := 0
var _file := ""


## A screen over [param viewport], or null where there is nothing to draw on.
static func open(viewport: Viewport) -> PackCheckScreen:
	if DisplayServer.get_name() == "headless" or viewport == null:
		return null
	var screen := PackCheckScreen.new()
	screen._viewport = viewport
	screen._canvas = RenderingServer.canvas_create()
	RenderingServer.viewport_attach_canvas(viewport.get_viewport_rid(), screen._canvas)
	RenderingServer.viewport_set_canvas_stacking(viewport.get_viewport_rid(), screen._canvas, STACKING, 0)
	screen._item = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(screen._item, screen._canvas)
	return screen


## Pack [param index] of [param total] starts: its file name on the screen.
func begin_pack(index: int, total: int, file_name: String) -> void:
	_index = index
	_total = maxi(total, index)
	_file = file_name
	_fraction = 0.0
	_pack = "Pack %d of %d · %s" % [_index, _total, _file]
	_draw(true)


## [param done] of the pack's [param of] pictures are read.
func pictures(done: int, of: int) -> void:
	_fraction = clampf(float(done) / float(maxi(of, 1)), 0.0, 1.0)
	_pack = "Pack %d of %d · %s · %d%%" % [_index, _total, _file, int(_fraction * 100.0)]
	_draw(false)


## What the screen says now, for the tests.
func text() -> String:
	return "%s\n%s\n%s" % [TITLE, _pack, NOTE]


## Off the screen, and its canvas freed.
func close() -> void:
	if _item.is_valid():
		RenderingServer.free_rid(_item)
		_item = RID()
	if _canvas.is_valid():
		if is_instance_valid(_viewport):
			RenderingServer.viewport_remove_canvas(_viewport.get_viewport_rid(), _canvas)
		RenderingServer.free_rid(_canvas)
		_canvas = RID()


func _draw(now: bool) -> void:
	var at := Time.get_ticks_msec()
	if not now and at - _drawn_ms < DRAW_EVERY_MS:
		return
	_drawn_ms = at
	if not _item.is_valid() or not is_instance_valid(_viewport):
		return
	var area := _viewport.get_visible_rect().size
	var font: Font = ThemeDB.fallback_font
	var left := (area.x - WIDTH) * 0.5
	var top := area.y * 0.5 - 90.0
	RenderingServer.canvas_item_clear(_item)
	RenderingServer.canvas_item_add_rect(_item, Rect2(Vector2.ZERO, area), GROUND)
	font.draw_string(_item, Vector2(left, top), TITLE, HORIZONTAL_ALIGNMENT_CENTER, WIDTH, 30, INK)
	font.draw_string(_item, Vector2(left, top + 48), _pack, HORIZONTAL_ALIGNMENT_CENTER, WIDTH, 22, INK)
	RenderingServer.canvas_item_add_rect(_item, Rect2(left, top + 70, WIDTH, 24), BAR_GROUND)
	RenderingServer.canvas_item_add_rect(_item, Rect2(left, top + 70, WIDTH * _fraction, 24), BAR)
	font.draw_multiline_string(_item, Vector2(left, top + 126), NOTE, HORIZONTAL_ALIGNMENT_CENTER,
		WIDTH, 17, -1, DIM)
	RenderingServer.force_draw(true, 0.0)
