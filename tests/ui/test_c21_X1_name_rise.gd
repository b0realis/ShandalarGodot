extends GutTest
## THE CREATURES' NAMES STAND OVER THEIR BODIES, MEASURED FROM THE FILE (the
## 0.50.66 bug campaign, the leftovers). How far above its feet a creature's
## body reaches — its sheet's first frame's opaque top under the anchor, on
## the 1997 pixels ([method WorldView._body_rise]) — was measured on the
## texture read back off the graphics card: a stall of the frame a name
## first stood in, once a sheet, with Creature names on. Now it is measured
## from the sheet's file ([method WorldView.rise_of]), on a worker where one
## may decode, and to the pixel what the read-back gave: a 1x sheet, a 2x
## one beside its 1x file, a 2x one alone (shrunk back). The fixtures are
## written into a scratch skin folder, so no 1997 file is needed.

const SCRATCH := "user://c21_x1_name_rise"
const SKIN := SCRATCH + "/skin"
const KEYS: Array[String] = [GamePaths.KEY_SKIN_FOLDER, GamePaths.KEY_USE_SKIN_FOLDER]
const CLERIC := 8
## The sheet's grid ([constant WorldArt.LAYOUT]: 154 x 108, five across,
## eight down) and where the fixture's body begins in the first frame.
const FRAME := Vector2i(154, 108)
const SHEET := Vector2i(770, 864)
const BODY_TOP := 30

var _saved: Dictionary = {}
var _was_worn := false
var body := ""
var shadow := ""


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SKIN))
	_saved = {}
	for key in KEYS:
		_saved[key] = Settings.get_value(key, null) if Settings.has_value(key) else null
		Settings.clear_value(key)
	Settings.set_value(GamePaths.KEY_SKIN_FOLDER, SKIN)
	_was_worn = GameSkin.zip_worn
	GameSkin.zip_worn = false
	GameSkin.clear_caches()
	SkinWarmer.forced = -1
	var keys := CreatureBook.sprite_keys(CLERIC)
	body = String(keys["body"])
	shadow = String(keys["shadow"])


func after_each() -> void:
	SkinWarmer.forced = -1
	for key in KEYS:
		if _saved[key] == null:
			Settings.clear_value(key)
		else:
			Settings.set_value(key, _saved[key])
	GameSkin.zip_worn = _was_worn
	_wipe(SCRATCH)
	GameSkin.clear_caches()


static func _wipe(folder: String) -> void:
	var absolute := ProjectSettings.globalize_path(folder)
	for sub in DirAccess.get_directories_at(absolute):
		_wipe(folder.path_join(sub))
	for file_name in DirAccess.get_files_at(absolute):
		DirAccess.remove_absolute(absolute.path_join(file_name))
	DirAccess.remove_absolute(absolute)


## A creature sheet [param scale] times the 1997 size, its first frame's
## body opaque from [param top] (the sheet's own pixels) down, the rest of
## the frame see-through, the other frames solid.
static func _sheet(scale: int, top: int) -> Image:
	var img := Image.create_empty(SHEET.x * scale, SHEET.y * scale, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.3, 0.5, 0.2))
	var first := Rect2i(Vector2i.ZERO, FRAME * scale)
	img.fill_rect(first, Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(Vector2i(40 * scale, top), Vector2i(60 * scale, first.size.y - top)),
		Color(0.8, 0.6, 0.4))
	return img


func _write(file_name: String, img: Image) -> void:
	img.save_png(ProjectSettings.globalize_path(SKIN.path_join(file_name)))


## A view drawing the 1997 sheets (not plain), a Cleric in slot 0 named, the
## dark off; out of any tree (nothing here draws).
func _view() -> WorldView:
	var view := WorldView.new()
	var world := ShandalarWorld.new()
	world.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	view.size = Vector2(800, 600)
	view.world = world
	view.fog = false
	view.camera = Vector2(640, 640)
	view.creatures = [_cleric()] as Array[Dictionary]
	view.creature_names = {0: "Cleric"}
	view._plain = false
	return view


static func _cleric() -> Dictionary:
	return {"slot": 0, "creature": CLERIC, "x": 660, "y": 640, "heading": 0, "frame": 0, "color": 5}


## The rise as it was measured before: on the texture read back.
static func _read_back_rise(art: WorldArt, key: String) -> float:
	var rise := float(art.creature_top(key))
	var img := GameSkin.original(art.texture(key))
	if img != null:
		var used := img.get_region(Rect2i(art.creature_rect(key, 0))).get_used_rect()
		if used.has_area():
			rise -= used.position.y
	return rise


func _check(label: String, expected: float) -> void:
	var view := _view()
	var reference := _read_back_rise(WorldArt.new(), body)
	GameSkin.clear_caches()
	var rise := view._body_rise(_cleric())
	assert_eq(rise, expected, "%s: the body's top (%.0f)" % [label, rise])
	assert_eq(rise, reference, "%s: to the pixel what the read-back gave" % label)
	view.free()


func test_a_1x_sheet() -> void:
	_write(body + ".png", _sheet(1, BODY_TOP))
	_check("1x", WorldArt.CREATURE_TOP - BODY_TOP)


func test_a_2x_sheet_beside_its_1x_reads_the_1x() -> void:
	_write(body + ".png", _sheet(1, BODY_TOP))
	# The 2x one's body a little lower: what the 1997 pixels say wins.
	_write(body + "@2x.png", _sheet(2, BODY_TOP * 2 + 10))
	_check("2x beside its 1x", WorldArt.CREATURE_TOP - BODY_TOP)


func test_a_2x_sheet_alone_is_shrunk_back() -> void:
	# An odd row: shrunk back, half a block see-through still shows.
	_write(body + "@2x.png", _sheet(2, BODY_TOP * 2 + 1))
	_check("2x alone", WorldArt.CREATURE_TOP - BODY_TOP)


## The texture is not what is measured: one whose pixels differ from its
## file (nothing on it at all) gives the file's rise.
func test_measured_from_the_file_not_the_texture() -> void:
	_write(body + ".png", _sheet(1, BODY_TOP))
	var view := _view()
	var blank := Image.create_empty(SHEET.x, SHEET.y, false, Image.FORMAT_RGBA8)
	view.art._textures[body] = ImageTexture.create_from_image(blank)
	assert_eq(_read_back_rise(view.art, body), float(WorldArt.CREATURE_TOP), "control: read back, no body at all")
	assert_eq(view._body_rise(_cleric()), float(WorldArt.CREATURE_TOP - BODY_TOP), "the file's body")
	view.free()


## Where a worker may decode, the name waits for its measure — never a
## stall — and stands over the body once it is in.
func test_on_a_worker_the_name_stands_once_measured() -> void:
	_write(body + ".png", _sheet(1, BODY_TOP))
	var view := _view()
	view.art.texture(body)
	view.art.texture(shadow)
	SkinWarmer.forced = 1
	assert_eq(view._body_rise(_cleric()), -1.0, "being measured")
	assert_eq(view.names_shown(), [], "the name waits for it")
	var rise := -1.0
	var until := Time.get_ticks_msec() + 5000
	while rise < 0.0 and Time.get_ticks_msec() < until:
		OS.delay_msec(2)
		rise = view._body_rise(_cleric())
	assert_eq(rise, float(WorldArt.CREATURE_TOP - BODY_TOP), "measured on the worker")
	assert_true(view._measuring.is_empty(), "its task reaped")
	var shown := view.names_shown()
	assert_eq(shown.size(), 1, "the name stands")
	if shown.size() == 1:
		var feet := view.drawn_at(Vector2(660, 640))
		assert_almost_eq((shown[0][1] as Vector2).y, roundf(feet.y - rise * view.zoom - WorldView.NAME_GAP), 0.5,
			"over the body's top")
	view.free()


## A view let go with a measure in flight neither hangs nor leaves the task
## unreaped once it ends.
func test_a_view_let_go_mid_measure() -> void:
	_write(body + "@2x.png", _sheet(2, BODY_TOP * 2))
	var view := _view()
	view.art.texture(body)
	view.art.texture(shadow)
	SkinWarmer.forced = 1
	assert_eq(view._body_rise(_cleric()), -1.0, "control: in flight")
	var began := Time.get_ticks_msec()
	view.free()
	assert_lt(Time.get_ticks_msec() - began, 2000, "let go at once (at most the file in hand)")
	var until := Time.get_ticks_msec() + 5000
	while not WorldView._unreaped.is_empty() and Time.get_ticks_msec() < until:
		OS.delay_msec(2)
		WorldView._reap()
	assert_true(WorldView._unreaped.is_empty(), "every task reaped")


## The measure told to stop before it began does nothing.
func test_a_measure_stopped_before_it_began_does_nothing() -> void:
	_write(body + ".png", _sheet(1, BODY_TOP))
	var measure := {"job": GameSkin.picture_job(body, true), "frame": Rect2i(Vector2i.ZERO, FRAME),
		"top": WorldArt.CREATURE_TOP, "lock": Mutex.new(), "stop": true, "started": false, "rise": -1.0,
		"task": -1}
	WorldView.rise_of(measure)
	assert_false(measure["started"], "never began")
	assert_eq(measure["rise"], -1.0, "measured nothing")
	assert_false((measure["job"] as Dictionary).has("img"), "decoded nothing")
