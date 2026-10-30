extends GutTest
## THE GLIDE AFTER A WAIT (the 0.50.66 bug campaign, h2-1). While the world
## waits under a pane the movers walk on into the places the clock left
## them ([WorldView], "THE GLIDE"); at the first tick after it they were
## drawn from the places kept before it again — the hero and the view
## stepped back along the walk (2 units, 6 pixels at zoom 2) and slid
## forward over the next frames, after every town, castle, lair, meeting,
## news flash, map and Load the walk ran into. Now the first tick after a
## wait glides on from where they stand drawn ([method
## WorldView._settle_ticks]). Pinned on the view alone, a tick at a time,
## and through the world screen's own frames: a town walked into and left,
## the map opened and closed mid-walk.

const TICK := HeroWalk.TICK
const FRAMES := 4
const SAVES := "user://adventure_tests_c21_x1_glide"
const LAIRS := [Vector2i(3, 0), Vector2i(0, 3), Vector2i(-3, 0), Vector2i(0, -3), Vector2i(3, -3),
	Vector2i(-3, 3)]

var view: WorldView
var world: ShandalarWorld
var start := Vector2.ZERO
var viewport: SubViewport
var screen: WorldScreen


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	Settings.clear_value(WorldHud.PACE_SETTING)
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.seed_text = "145729"
	var record := setup.resolve({})
	world = AdventureSetup.make_world(record)
	var player := AdventurePlayer.begin(record, world)
	start = Vector2(player.position)
	view = WorldView.new()
	add_child_autofree(view)
	view.size = Vector2(1280, 800)
	view.world = world
	view.hero = start
	view.camera = start
	view.frame(0.0, TICK)
	await wait_process_frames(2)


func after_each() -> void:
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


# ------------------------------------------------------------- the view --

## [param ticks] ticks of a walk along x, [param step] units a tick (0: the
## hero stands), [constant FRAMES] frames a tick, as the world screen runs
## them; per frame the drawn x.
func _ticks(ticks: int, step: float) -> PackedFloat64Array:
	var drawn := PackedFloat64Array()
	for k in ticks:
		view.hero = view.hero + Vector2(step, 0)
		view.camera = view.hero
		for f in FRAMES:
			view.frame((f + 0.5) / FRAMES, TICK / FRAMES)
			drawn.append(view._shown_hero().x)
	return drawn


## The world waits [param frames] frames ([method WorldView.frame] at 1);
## [param opening_step]: the tick that opened the pane moved the hero so
## far first (a walk's last step into a town), 0 for a pane opened between
## ticks (the map).
func _wait(frames: int, opening_step: float) -> void:
	if opening_step != 0.0:
		view.hero = view.hero + Vector2(opening_step, 0)
		view.camera = view.hero
	for f in frames:
		view.frame(1.0, TICK / FRAMES)


func test_standing_after_a_town_the_hero_is_drawn_on_their_place_every_frame() -> void:
	_ticks(12, 1.0)
	# The step into the town opens its pane; the world waits a second.
	_wait(66, 1.0)
	assert_eq(view._shown_hero(), view.hero, "control: under the pane they reached their place")
	var place := view.hero
	var drawn := _ticks(8, 0.0)
	var worst := 0.0
	for x in drawn:
		worst = maxf(worst, absf(x - place.x))
	assert_almost_eq(worst, 0.0, 0.0001, "standing: drawn on the place itself every frame (worst %.3f units off)" % worst)
	assert_eq(view._shown_camera(), view.camera, "and the view with them")


func test_a_wait_mid_walk_never_draws_the_hero_back_along_it() -> void:
	var before := _ticks(12, 1.0)
	# The map opened between two ticks, a second; then the walk goes on.
	_wait(66, 0.0)
	var waited := view._shown_hero().x
	var after := _ticks(10, 1.0)
	var xs := before.duplicate()
	xs.append(waited)
	xs.append_array(after)
	var worst := 0.0
	var at := -1
	for i in range(1, xs.size()):
		if xs[i - 1] - xs[i] > worst:
			worst = xs[i - 1] - xs[i]
			at = i
	assert_lt(worst, 0.0001, "no frame steps back (worst %.3f units, frame %d of %d: %s)" % [worst, at, xs.size(),
		xs.slice(maxi(at - 3, 0), at + 3)])
	assert_gt(after[after.size() - 1] - after[0], 6.0, "control: the walk went on")
	var ahead := false
	for x in after:
		ahead = ahead or x > view.hero.x + 0.0001
	assert_false(ahead, "never past the place the clock holds")


## A creature waits with the hero: drawn on its place, then on — one
## walking a unit every tick (closing in), whose glide reaches back a tick.
func test_a_creature_too_goes_on_from_where_it_stands_drawn() -> void:
	var at := Vector2i(start) + Vector2i(60, 0)
	var xs := PackedFloat64Array()
	var x := at.x
	for k in 30:
		if k == 12:
			# The world waits between two ticks.
			for f in 40:
				view.frame(1.0, TICK / FRAMES)
				xs.append(view._shown_creature({"slot": 3, "x": x, "y": at.y}).x)
			assert_eq(xs[xs.size() - 1], float(x), "control: under the pane it reached its place")
		x -= 1
		var seen: Array[Dictionary] = [{"slot": 3, "creature": 1, "x": x, "y": at.y, "heading": 7, "frame": 1, "color": 2}]
		view.creatures = seen
		for f in FRAMES:
			view.frame((f + 0.5) / FRAMES, TICK / FRAMES)
			xs.append(view._shown_creature(seen[0]).x)
	var worst := 0.0
	for i in range(1, xs.size()):
		worst = maxf(worst, xs[i] - xs[i - 1])
	assert_lt(worst, 0.0001, "walking west: no frame steps back east (worst %.3f units)" % worst)
	assert_lt(xs[xs.size() - 1], float(at.x - 25), "control: it walked on")


# ------------------------------------------------- through the screen --

func _open_screen() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Inniscor"
	setup.color = "green"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	screen = WorldScreen.new()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await wait_process_frames(3)
	screen.set_process(false)
	screen.player.food = 200
	screen.player.sieges = AdventurePlayer.SIEGES_NONE
	screen._tick_left = 0.0
	_quiet_slots()


## Every roaming slot held by a lair three tiles from the hero, so none is
## met on the way (test_c20_W1_world_key_walk's way).
func _quiet_slots() -> void:
	var player := screen.player
	player.monsters = [] as Array
	for slot in WorldLairs.SLOTS:
		var tile: Vector2i = player.tile() + LAIRS[slot]
		player.monsters.append({"slot": slot, "kind": "lair", "x": tile.x * 32 + 16, "y": tile.y * 32 + 16,
			"color": 1})
	for i in player.world.lair_respawn.size():
		player.world.lair_respawn[i] = -1000000


func test_a_town_walked_into_and_left_the_hero_stands_drawn_still() -> void:
	await _open_screen()
	var player := screen.player
	var town := Vector2i(-1, -1)
	var best := 1 << 30
	for i in screen.world.sites.size():
		var site: Dictionary = screen.world.sites[i]
		var t := Vector2i(int(site["x"]), int(site["y"]))
		var place := VisitPane.describe(player, t)
		if place.is_empty() or not String(place.get("kind", "")) in ["village", "town", "city"]:
			continue
		var way := screen.walk.plan(t)
		if way.size() >= 5 and way.size() < best:
			best = way.size()
			town = t
	assert_gt(town.x, -1, "control: a town to walk to")
	for t in screen.walk.plan(town):
		screen.world.explore_around(t)
	screen.walk_to_tile(town)
	var dt := 1.0 / 60.0
	for n in 3600:
		if screen.visiting():
			break
		_quiet_slots()
		screen._process(dt)
	assert_true(screen.visiting(), "control: the town's pane")
	for f in 60:
		screen._process(dt)
	screen._left_place("")
	if screen._magic_seller != null and is_instance_valid(screen._magic_seller):
		screen._magic_seller.free()
		screen._magic_seller = null
	screen._shield_until = 0
	assert_false(screen.modal(), "control: the town left")
	var worst := 0.0
	for f in 60:
		_quiet_slots()
		screen._process(dt)
		worst = maxf(worst, screen.view._shown_hero().distance_to(Vector2(player.position)))
	assert_lt(worst, 0.01, "standing after the town: drawn on their place (worst %.3f units off)" % worst)


func test_the_map_opened_and_closed_mid_walk_draws_no_step_back() -> void:
	await _open_screen()
	var player := screen.player
	var way := 4
	var step := Vector2i(ShandalarWorld.DX[way], ShandalarWorld.DY[way])
	var line := Vector2i(-1, -1)
	var home := player.tile()
	for radius in 25:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if line.x >= 0 or maxi(absi(dx), absi(dy)) != radius:
					continue
				var from := home + Vector2i(dx, dy)
				var ok := true
				for k in 7:
					var tile := from + step * k
					if not screen.world.is_land(tile.x, tile.y) or not screen.place_at(tile).is_empty() \
							or not VisitPane.describe(player, tile).is_empty() \
							or screen.world.terrain(tile.x, tile.y) in [2, 3, 4, 5]:
						ok = false
						break
				if ok:
					line = from
	assert_gt(line.x, -1, "control: a line of land")
	player.position = line * 32 + Vector2i(16, 16)
	screen.walk = HeroWalk.new(player)
	screen.paths.walk = screen.walk
	screen._show_hero()
	screen.view.camera = screen.view.hero
	screen.walk_to_tile(line + step * 6)
	var along := Vector2(step).normalized()
	var dt := 1.0 / 60.0
	var last := -INF
	var worst := 0.0
	for phase in ["walk", "wait", "after"]:
		if phase == "wait":
			screen.toggle_map()
		elif phase == "after":
			screen.toggle_map()
		for f in 48:
			_quiet_slots()
			screen._process(dt)
			var drawn := screen.view._shown_hero().dot(along)
			if last > -INF:
				worst = maxf(worst, last - drawn)
			last = drawn
	assert_ne(player.position, line * 32 + Vector2i(16, 16), "control: the walk went on")
	assert_lt(worst, 0.01, "no frame steps back after the map (worst %.3f units)" % worst)
