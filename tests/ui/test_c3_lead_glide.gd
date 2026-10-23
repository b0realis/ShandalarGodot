extends GutTest
## THE GLIDE (2026-10-23 campaign): the world's clock ticks every
## [constant HeroWalk.TICK]; [method WorldScreen._process] hands the view
## how far it is between two ticks, and the hero, the camera following them
## and the guide arrows slide there ([method WorldView.frame],
## [method WorldView.drawn_at]). A place's pane, the map or the deck builder
## holds the world, and the hero stands where the last tick left them.

var screen: WorldScreen
const SAVES := "user://adventure_tests_glide"


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	# The 1997 pace (×1), whatever an earlier test left in the options.
	Settings.clear_value(WorldHud.PACE_SETTING)
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	screen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.record = setup.resolve({})
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


## A land tile some steps from the hero, to walk to.
func _somewhere() -> Vector2i:
	var at := screen.player.tile()
	for reach in range(3, 12):
		for step in [Vector2i(reach, 0), Vector2i(0, reach), Vector2i(-reach, 0), Vector2i(0, -reach)]:
			var tile: Vector2i = at + step
			var inside := tile.x >= 0 and tile.y >= 0 \
					and tile.x < ShandalarWorld.TILES and tile.y < ShandalarWorld.TILES
			if inside and screen.world.is_land(tile.x, tile.y) \
					and screen.world.site_at(tile.x, tile.y).is_empty():
				return tile
	return at


func test_the_frame_slides_the_hero_between_ticks() -> void:
	screen.walk.walk_to(_somewhere())
	assert_true(screen.walk.is_walking(), "the hero sets off")
	# The frames before the test left time over on the clock: start it
	# clean, so a tick and a half is exactly one tick and half of the next.
	screen._tick_left = 0.0
	screen._process(HeroWalk.TICK * 1.5)
	var blend: float = screen.view._blend
	assert_almost_eq(blend, 0.5, 0.01, "half a tick left over: half way between the ticks")
	var middle := Vector2(16, 16) + Vector2(screen.player.tile() * 32)
	assert_eq(screen.guides.on_screen(screen.player.tile()), screen.view.drawn_at(middle),
		"the guide arrows stand where the view draws the land this frame")


func test_a_pane_holds_the_hero_where_the_tick_left_them() -> void:
	screen.walk.walk_to(_somewhere())
	screen._process(HeroWalk.TICK * 1.5)
	screen.save_now()
	assert_true(screen.modal(), "the saves' pane holds the world")
	screen._process(HeroWalk.TICK * 0.25)
	assert_eq(screen.view._blend, 1.0, "drawn where the last tick left them, not a step short")


## The bug pass after the campaign (r4-3): the pointer reads the land where
## this frame draws it, so mid-glide a point drawn inside a tile is that
## tile, not the one the clock's camera puts there.
func test_the_pointer_reads_the_land_as_it_is_drawn() -> void:
	screen.walk.walk_to(_somewhere())
	screen._tick_left = 0.0
	screen._process(HeroWalk.TICK * 1.5)
	assert_almost_eq(float(screen.view._blend), 0.5, 0.01, "control: mid-glide")
	var at := screen.player.tile() + Vector2i(2, 1)
	# How far the clock's camera reads a drawn point off: half a step.
	var middle := Vector2(at * 32) + Vector2(16, 16)
	var off := screen.view.unproject(screen.view.drawn_at(middle)) - middle
	assert_true(off.length() > 0.1, "control: the drawn view lags the clock's camera")
	# A point just inside the edge the lag would carry it over.
	var near_edge := Vector2(at * 32) + Vector2(
		32.0 - absf(off.x) * 0.5 if off.x > 0 else absf(off.x) * 0.5,
		32.0 - absf(off.y) * 0.5 if off.y > 0 else absf(off.y) * 0.5)
	var drawn := screen.view.drawn_at(near_edge)
	assert_eq(screen.tile_at(drawn), at, "the tile drawn under the point")
	assert_almost_eq(screen.view.unproject_drawn(drawn).distance_to(near_edge), 0.0, 0.001,
		"unproject_drawn undoes drawn_at")

