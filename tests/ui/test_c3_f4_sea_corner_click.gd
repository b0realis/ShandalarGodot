extends GutTest
## CLICKED ON A SEA CORNER, THE HERO WALKS (the adventure campaign of
## 2026-10-23, h2-1), through the live world screen: the hero crossing the
## corner of a sea tile on a diagonal step, a click on the world through
## the viewport walks them on — and so does the same after the autosave is
## taken up again. Before, the way began on the sea tile, its first step
## was taken back, and every later click the same: stuck for good, in the
## autosave too.

const SAVES := "user://adventure_tests_c3_f4_corner"

var viewport: SubViewport
var screen: WorldScreen


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "145729"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	screen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	# The world's own clock stands still: the walk is ticked here, so no
	# lair the dice put by the way ends it.
	screen.set_process(false)


func after_each() -> void:
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


## A land tile whose north-east neighbour is land and whose east one is the
## sea, with no road or place on either land tile.
func _corner(world: ShandalarWorld) -> Vector2i:
	for y in range(2, ShandalarWorld.TILES - 2):
		for x in range(2, ShandalarWorld.TILES - 2):
			if world.is_land(x, y) and world.is_land(x + 1, y - 1) and not world.is_land(x + 1, y) \
					and world.road_bits(x, y) == 0 and world.tile_flags(x, y) & ShandalarWorld.SITE == 0 \
					and world.tile_flags(x + 1, y - 1) & ShandalarWorld.SITE == 0:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## A land tile with no place on it, two to four steps from [param from],
## that the hero can walk to.
func _land_near(from: Vector2i) -> Vector2i:
	var world := screen.world
	for reach in range(2, 5):
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var tile := from + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) != reach or not world.is_land(tile.x, tile.y) \
						or world.tile_flags(tile.x, tile.y) & ShandalarWorld.SITE != 0:
					continue
				var way := screen.walk.plan(tile)
				if not way.is_empty() and way.back() == tile:
					return tile
	return from


## A left click on [param tile]'s middle, through the viewport.
func _click(tile: Vector2i) -> void:
	var view := screen.view
	var at := view.feet() + view.project(Vector2(tile * 32 + Vector2i(16, 16))) * view.zoom
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.position = at
		click.global_position = at
		viewport.push_input(click, true)


## The hero walked north-east from [param from] until they stand on the
## sea tile's corner, shown there as a tick shows them.
func _onto_the_corner(from: Vector2i) -> void:
	var player := screen.player
	player.position = from * 32 + Vector2i(16, 16)
	screen.walk.stop()
	screen.walk.walk_to(from + Vector2i(1, -1))
	for i in 60:
		var here := player.tile()
		if not screen.world.is_land(here.x, here.y):
			break
		screen.walk.tick()
	screen._show_hero()


## The walk ticked until it ends; true when the hero stands on [param
## target].
func _walked_to(target: Vector2i) -> bool:
	for i in 20000:
		if not screen.walk.is_walking():
			break
		screen.walk.tick()
	return screen.player.tile() == target


func test_a_click_through_the_screen_walks_the_hero_off_a_sea_corner() -> void:
	var from := _corner(screen.world)
	assert_ne(from, Vector2i(-1, -1), "a coast corner to cross")
	_onto_the_corner(from)
	var here := screen.player.tile()
	assert_false(screen.world.is_land(here.x, here.y), "on the sea tile's corner")
	screen.set_zoom(1.0)
	screen.back_to_hero()
	await _frames()
	var target := _land_near(from)
	assert_ne(target, from, "somewhere to walk")
	_click(target)
	await _frames()
	assert_true(screen.walk.is_walking(), "the click is where to go")
	assert_eq(screen.walk.destination, target, "the click's tile")
	assert_true(_walked_to(target), "and the hero walks there (stands on %s)" % str(screen.player.tile()))


func test_the_autosave_made_on_a_sea_corner_walks_again() -> void:
	var from := _corner(screen.world)
	_onto_the_corner(from)
	var path := screen.autosave()
	assert_ne(path, "", "saved on the corner")
	var loaded := AdventurePlayer.load_from(path)
	assert_not_null(loaded)
	screen.show_player(loaded)
	await _frames()
	var here := screen.player.tile()
	assert_true(screen.world.is_land(here.x, here.y), "taken up again on land")
	screen.set_zoom(1.0)
	screen.back_to_hero()
	await _frames()
	var target := _land_near(here)
	_click(target)
	await _frames()
	assert_true(screen.walk.is_walking(), "the click is where to go")
	assert_eq(screen.walk.destination, target, "the click's tile")
	assert_true(_walked_to(target), "and the hero walks there")
