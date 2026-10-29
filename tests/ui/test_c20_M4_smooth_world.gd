extends GutTest
## THE WORLD SCREEN'S OWN WORK, SMOOTHER (the smoothness pass, 0.50.66; the
## owner, 2026-10-29: *"I really want our adventure to play silky butter
## smooth"*) — through the real world screen:
##  - THE ZOOM EASED: a wheel's notch, + and − set where the zoom goes and
##    each frame moves it there (1 − e^(−k·delta)), landing exactly on the
##    jump's zoom; quick notches compound; [method WorldScreen.set_zoom] and
##    a pinch stay at once; an eased notch draws the land no more often than
##    the jump did;
##  - THE BOARD WALK at the screen's rate: the figure slides between 1997's
##    66 ms frames, the poses and the walk's length 1997's;
##  - THE PER-TICK BOOKKEEPING: the small map looks once a tick, not three
##    times; the panel's World Magics are looked at again only when what
##    decides them changed; its numbers stay exact;
##  - THE PATH ARROWS HIDE IN THE DARK (the owner's ruling of 2026-10-29):
##    a mark only on explored land, each dark tile marked once the walk
##    lights it.

const SAVES := "user://adventure_tests_c20_m4_smooth"
const LAIRS := [Vector2i(3, 0), Vector2i(0, 3), Vector2i(-3, 0), Vector2i(0, -3), Vector2i(3, -3),
	Vector2i(-3, 3)]

var viewport: SubViewport
var screen: WorldScreen


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	Settings.clear_value(WorldHud.PATHS_SETTING)
	Settings.clear_value(WorldHud.PACE_SETTING)
	var setup := AdventureSetup.new()
	setup.player_name = "Inniscor"
	setup.color = "green"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	viewport.notification(Viewport.NOTIFICATION_VP_MOUSE_ENTER)
	screen = WorldScreen.new()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.set_process(false)
	screen.player.food = 50
	screen.player.sieges = AdventurePlayer.SIEGES_NONE
	screen._tick_left = 0.0
	_quiet_slots()


func after_each() -> void:
	Settings.clear_value(WorldHud.PATHS_SETTING)
	Settings.clear_value(WorldHud.PACE_SETTING)
	DungeonView.frame_seconds = DungeonView.FRAME_SECONDS
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


## Every roaming slot held by a lair three tiles from the hero: nothing
## refills, nothing comes (test_c20_W1_world_key_walk's).
func _quiet_slots() -> void:
	var player := screen.player
	player.monsters = [] as Array
	for slot in WorldLairs.SLOTS:
		var tile: Vector2i = player.tile() + LAIRS[slot]
		player.monsters.append({"slot": slot, "kind": "lair", "x": tile.x * 32 + 16, "y": tile.y * 32 + 16,
			"color": 1})
	for i in player.world.lair_respawn.size():
		player.world.lair_respawn[i] = -1000000
	player.siege_active = false


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


## [param count] of the screen's frames of [param delta] seconds each.
func _run_frames(count: int, delta: float) -> void:
	for i in count:
		_quiet_slots()
		screen._process(delta)


static func _middle(tile: Vector2i) -> Vector2i:
	return tile * 32 + Vector2i(16, 16)


func _wheel(button: MouseButton) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = button
	click.pressed = true
	click.position = Vector2(640, 400)
	screen._gui_input(click)


## How many new pictures of the land the view showed while [param run]
## ran (its drawings' count).
func _ground_drawings(run: Callable) -> int:
	var before := int(screen.view.get("_drawing"))
	await run.call()
	return int(screen.view.get("_drawing")) - before


# ------------------------------------------------------------- the zoom --

func test_a_wheel_notch_eases_to_the_jump_s_zoom() -> void:
	var view := screen.view
	assert_eq(view.zoom, WorldView.DEFAULT_ZOOM, "control: the default zoom")
	_wheel(MOUSE_BUTTON_WHEEL_UP)
	assert_true(screen.zooming(), "a notch sets where the zoom goes")
	assert_eq(screen.zoom_goal(), WorldView.DEFAULT_ZOOM * WorldScreen.ZOOM_STEP, "the jump's zoom, 1.25 times")
	assert_eq(view.zoom, WorldView.DEFAULT_ZOOM, "not there at once")
	var seen: Array[float] = []
	for i in 60:
		_run_frames(1, 1.0 / 60.0)
		seen.append(view.zoom)
		if not screen.zooming():
			break
	assert_false(screen.zooming(), "there within a second at 60 frames a second")
	assert_eq(view.zoom, WorldView.DEFAULT_ZOOM * WorldScreen.ZOOM_STEP, "landed exactly on the jump's zoom")
	assert_between(seen.size(), 6, 20, "eased over about a fifth of a second: %d frames" % seen.size())
	for i in range(1, seen.size()):
		assert_true(seen[i] >= seen[i - 1], "never back")
	# Even to the eye: each frame's step (in log) no bigger than the one before.
	var steps: Array[float] = []
	var last := WorldView.DEFAULT_ZOOM
	for z in seen:
		steps.append(log(z / last))
		last = z
	for i in range(1, steps.size() - 1):
		assert_true(steps[i] <= steps[i - 1] + 0.0001, "slowing as it nears: %s" % [steps])


func test_the_ease_takes_the_same_time_at_any_frame_rate() -> void:
	var view := screen.view
	var took := {}
	for rate in [60, 144, 240]:
		screen.set_zoom(WorldView.DEFAULT_ZOOM)
		screen.zoom_step(true)
		var frames := 0
		while screen.zooming() and frames < 1000:
			_run_frames(1, 1.0 / float(rate))
			frames += 1
		took[rate] = float(frames) / float(rate)
		assert_eq(view.zoom, WorldView.DEFAULT_ZOOM / WorldScreen.ZOOM_STEP, "landed at %d Hz" % rate)
	assert_almost_eq(float(took[144]), float(took[60]), 0.04, "the same time at 60 and 144 Hz: %s" % [took])
	assert_almost_eq(float(took[240]), float(took[60]), 0.04, "and at 240 Hz")


func test_quick_notches_compound_and_the_keys_ease_too() -> void:
	var view := screen.view
	screen.set_zoom(1.0)
	for i in 3:
		_wheel(MOUSE_BUTTON_WHEEL_UP)
		_run_frames(1, 1.0 / 144.0)
	var jumps := 1.0 * WorldScreen.ZOOM_STEP * WorldScreen.ZOOM_STEP * WorldScreen.ZOOM_STEP
	assert_eq(screen.zoom_goal(), jumps, "three quick notches go as far as three jumps")
	_run_frames(200, 1.0 / 144.0)
	assert_eq(view.zoom, jumps, "and land exactly there")
	# The edges hold the goal.
	for i in 10:
		_wheel(MOUSE_BUTTON_WHEEL_UP)
	assert_eq(screen.zoom_goal(), WorldView.ZOOM_MAX, "never past the closest zoom")
	_run_frames(200, 1.0 / 144.0)
	assert_eq(view.zoom, WorldView.ZOOM_MAX)
	# − eases as the wheel does.
	var minus := InputEventKey.new()
	minus.keycode = KEY_MINUS
	minus.pressed = true
	screen._unhandled_input(minus)
	assert_true(screen.zooming(), "− eases")
	assert_eq(screen.zoom_goal(), WorldView.ZOOM_MAX / WorldScreen.ZOOM_STEP, "the jump's own zoom")


func test_set_zoom_and_a_pinch_are_at_once() -> void:
	var view := screen.view
	_wheel(MOUSE_BUTTON_WHEEL_UP)
	assert_true(screen.zooming(), "control: easing")
	screen.set_zoom(1.0)
	assert_false(screen.zooming(), "set_zoom gives the ease up")
	assert_eq(view.zoom, 1.0, "at once")
	_run_frames(30, 1.0 / 60.0)
	assert_eq(view.zoom, 1.0, "and stays")
	var pinch := InputEventMagnifyGesture.new()
	pinch.factor = 1.5
	pinch.position = Vector2(640, 400)
	screen._gui_input(pinch)
	assert_eq(view.zoom, 1.5, "a pinch zooms at once, as the fingers move")
	assert_false(screen.zooming())


func test_the_ease_goes_on_under_a_pane() -> void:
	var view := screen.view
	_wheel(MOUSE_BUTTON_WHEEL_DOWN)
	var load_screen := screen.open_load()
	assert_not_null(load_screen, "control: a pane over the world")
	_run_frames(120, 1.0 / 60.0)
	assert_eq(view.zoom, WorldView.DEFAULT_ZOOM / WorldScreen.ZOOM_STEP, "the zoom still lands")
	load_screen.free()


func test_an_eased_notch_draws_the_land_no_more_than_the_jump() -> void:
	var view := screen.view
	screen.set_zoom(1.0)
	await _frames(2)
	# The jump (set_zoom), going out: what one notch drew before.
	var jumped := await _ground_drawings(func() -> void:
		screen.set_zoom(1.0 / WorldScreen.ZOOM_STEP)
		for i in 60:
			_run_frames(1, 1.0 / 144.0)
			await get_tree().process_frame)
	screen.set_zoom(1.0)
	await _frames(3)
	var eased := await _ground_drawings(func() -> void:
		screen.zoom_step(true)
		for i in 60:
			_run_frames(1, 1.0 / 144.0)
			await get_tree().process_frame)
	assert_eq(view.zoom, 1.0 / WorldScreen.ZOOM_STEP, "control: landed")
	assert_gt(jumped, 0, "control: the jump out drew the land")
	assert_true(eased <= jumped, "the eased notch out drew the land %d times, the jump %d" % [eased, jumped])


# ------------------------------------------------------ the bookkeeping --

func test_the_small_map_looks_once_a_tick() -> void:
	var minimap := screen.hud.minimap
	var looked := minimap.looks
	screen._show_hero()
	assert_eq(minimap.looks, looked + 1, "the world, the hero, the marks and the dungeons in one look")
	# What it shows still follows: the hero onto another tile.
	var drawn := minimap.drawn_tile()
	screen.player.position += Vector2i(32, 0)
	screen._show_hero()
	assert_ne(minimap.drawn_tile(), drawn, "drawn round the hero's new tile")
	# Set one by one, it still looks at each.
	looked = minimap.looks
	minimap.hero = Vector2(screen.player.position)
	assert_eq(minimap.looks, looked + 1)


func test_the_panel_s_numbers_stay_exact() -> void:
	var hud := screen.hud
	var player := screen.player
	hud.refresh_numbers()
	assert_eq(int(hud._numbers["ankh"].text), player.mana_links(), "control: the links counted")
	# A town linked (its status word changed in place): counted at once.
	var town := -1
	for slot in screen.world.sites.size():
		if TownStatus.is_town(screen.world, slot) and not TownStatus.linked(screen.world, slot) \
				and not TownStatus.ruled(screen.world, slot):
			town = slot
			break
	assert_gt(town, -1, "control: an unlinked town")
	var links := player.mana_links()
	TownStatus.put(screen.world, town, TownStatus.LINKED)
	hud.refresh_numbers()
	assert_eq(player.mana_links(), links + 1, "control: one more link")
	assert_eq(int(hud._numbers["ankh"].text), links + 1, "the ankh's number follows a town linked")
	# A card moved into the deck in use, the bag's size the same: the book's.
	var outside := -1
	for i in player.cards.size():
		if not (player.cards[i].get("decks", []) as Array).has(player.current_deck):
			outside = i
			break
	if outside < 0:
		player.cards.append({"card": "Forest", "decks": []})
		outside = player.cards.size() - 1
	hud.refresh_numbers()
	var before := hud.cards_in_deck()
	(player.cards[outside]["decks"] as Array).append(player.current_deck)
	hud.refresh_numbers()
	assert_eq(hud.cards_in_deck(), before + 1, "control: one more in the deck")
	assert_eq(hud._numbers["book"].text, "%d/%d" % [before + 1, player.cards.size()], "the book's number follows")


func test_a_free_tick_does_not_walk_the_bag() -> void:
	var hud := screen.hud
	var player := screen.player
	screen._show_hero()
	var walked := hud.bag_walks
	var target := Vector2i(-1, -1)
	for d in [Vector2i(3, 0), Vector2i(0, 3), Vector2i(-3, 0), Vector2i(0, -3)]:
		var tile: Vector2i = player.tile() + d
		if screen.world.is_land(tile.x, tile.y) and screen.place_at(tile).is_empty():
			target = tile
	screen.walk_to_tile(target)
	_run_frames(10, HeroWalk.TICK)
	assert_eq(hud.bag_walks, walked, "ten ticks of a walk: the deck's count kept")
	# A card won: the bag's size changed, counted on the next tick.
	player.cards.append({"card": "Forest", "decks": [player.current_deck]})
	_run_frames(1, HeroWalk.TICK)
	assert_eq(hud.bag_walks, walked + 1, "a card more: counted")
	assert_eq(hud._numbers["book"].text, "%d/%d" % [hud.cards_in_deck(), player.cards.size()])
	# A pane held the panel (the deck builder, a shop, a trade): counted again.
	var load_screen := screen.open_load()
	_run_frames(3, 1.0 / 60.0)
	walked = hud.bag_walks
	load_screen.free()
	_run_frames(31, 1.0 / 60.0)
	assert_eq(hud.bag_walks, walked + 1, "after a pane: counted once, then kept")
	# Asked outright, always counted.
	hud.refresh_numbers()
	assert_eq(hud.bag_walks, walked + 2)


func test_the_world_magics_are_looked_at_only_when_they_change() -> void:
	var hud := screen.hud
	var player := screen.player
	hud.refresh_numbers()
	var looked := hud.magic_looks
	for i in 5:
		hud.refresh_numbers()
	assert_eq(hud.magic_looks, looked, "nothing changed: the icons not looked at again")
	player.world_magics.append("Leap of Fate")
	hud.refresh_numbers()
	assert_eq(hud.magic_looks, looked + 1, "a World Magic won: looked at")
	var names := String(hud._magic_names.text) if hud._magic_names != null else "World Magics: Leap of Fate"
	assert_string_contains(names, "Leap of Fate", "and named")
	player.amulets["blue"] = int(player.amulets.get("blue", 0)) + 1
	hud.refresh_numbers()
	assert_eq(hud.magic_looks, looked + 2, "an amulet: looked at (it lights an active magic)")
	player.quickening = 3
	hud.refresh_numbers()
	assert_eq(hud.magic_looks, looked + 3, "Quickening running: looked at")


func test_the_quest_pane_s_kept_lines_are_the_lines_made_afresh() -> void:
	var player := screen.player
	var world := screen.world
	var towns: Array[int] = []
	for slot in world.sites.size():
		if TownStatus.is_town(world, slot) and not TownStatus.ruled(world, slot):
			towns.append(slot)
	assert_gt(towns.size(), 3, "control: towns")
	# A letter quest to a town far off, due in a little over a day.
	var far := towns[0]
	for slot in towns:
		var site: Dictionary = world.sites[slot]
		var at := Vector2i(int(site["x"]), int(site["y"]))
		if (at - player.tile()).length_squared() > 400:
			far = slot
			break
	player.quest = {"type": Quests.LETTER_LINK, "destination": far, "color": 2, "data": 1,
		"deadline": player.quest_timer + WorldStatus.DAY + 3, "giver": towns[1]}
	var target := Vector2i(-1, -1)
	for d in [Vector2i(6, 0), Vector2i(0, 6), Vector2i(-6, 0), Vector2i(0, -6), Vector2i(4, 4), Vector2i(-4, -4)]:
		var tile: Vector2i = player.tile() + d
		if world.is_land(tile.x, tile.y) and screen.place_at(tile).is_empty() and screen.walk.plan(tile).size() > 4:
			target = tile
			break
	assert_gt(target.x, -1, "control: somewhere to walk")
	screen.walk_to_tile(target)
	var seen := {}
	var quest_failed := false
	for i in 400:
		match i:
			40:
				TownStatus.take(world, towns[2], 3)
			80:
				player.next_duel_life = 2
				player.next_duel_first_move = true
			120:
				player.quest["data"] = -1
			160:
				player.quest_timer = int(player.quest["deadline"]) - 1
			200:
				player.quest_timer = int(player.quest.get("deadline", player.quest_timer)) + 1
			240:
				player.world_magics.append("Ring of the Guardian")
			280:
				TownStatus.put(world, towns[2], TownStatus.RULER_MASK, false)
		if i == 120 and not screen.walk.is_walking():
			screen.walk_to_tile(player.tile() + Vector2i(1, 0) if world.is_land(player.tile().x + 1, player.tile().y) \
				else player.tile() - Vector2i(1, 0))
		_run_frames(1, HeroWalk.TICK)
		var fresh := WorldStatus.lines_fresh(player)
		assert_eq(WorldStatus.lines(player), fresh, "tick %d: the kept lines are the fresh ones" % i)
		if screen.hud.quest_pane_shown():
			assert_eq(String(screen.hud._quest_lines.text), "\n".join(fresh), "tick %d: the pane shows them" % i)
		seen["\n".join(fresh)] = true
		quest_failed = quest_failed or player.quest.is_empty()
	assert_true(quest_failed, "control: the quest's deadline passed")
	assert_gt(seen.size(), 5, "control: the lines changed along the way (%d sets)" % seen.size())
	# A siege begun, moved to another town, lifted.
	player.monsters.append({"slot": WorldMagic.SIEGE_SLOT, "kind": "creature", "creature": 12,
		"town": towns[3], "x": player.position.x + 64, "y": player.position.y})
	assert_eq(WorldStatus.lines(player), WorldStatus.lines_fresh(player), "a siege begun")
	assert_string_contains(WorldStatus.lines(player)[0], "attacking", "control: its line")
	player.monsters.back()["town"] = towns[1]
	assert_eq(WorldStatus.lines(player), WorldStatus.lines_fresh(player), "the besieger's town changed")
	player.monsters.pop_back()
	assert_eq(WorldStatus.lines(player), WorldStatus.lines_fresh(player), "the siege lifted")


# -------------------------------------------------- the arrows in the dark --

## A land tile on no place, its way from the hero [param least]–[param most]
## tiles long, with dark (unexplored) tiles on it, the last one dark.
func _target_into_the_dark(least: int, most: int) -> Vector2i:
	var player := screen.player
	player.position = _middle(player.tile())
	var home := player.tile()
	for radius in range(4, 24):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var tile := home + Vector2i(dx, dy)
				if not screen.world.is_land(tile.x, tile.y) or screen.world.is_explored(tile.x, tile.y) \
						or not screen.place_at(tile).is_empty() or not VisitPane.describe(player, tile).is_empty():
					continue
				var way := screen.walk.plan(tile)
				if way.size() - 1 >= least and way.size() - 1 <= most and way.back() == tile:
					return tile
	return Vector2i(-1, -1)


func test_the_arrows_hide_in_the_dark() -> void:
	var paths := screen.paths
	var world := screen.world
	var target := _target_into_the_dark(6, 20)
	assert_gt(target.x, -1, "control: a tile out in the dark")
	assert_true(screen.walk_to_tile(target), "control: the click walks")
	_run_frames(1, HeroWalk.TICK)
	var marked := paths.marked()
	assert_true(paths.shown(), "the lit part of the way is marked")
	var lit: Array[Vector2i] = []
	var dark := 0
	for tile in marked:
		if world.is_explored(tile.x, tile.y):
			lit.append(tile)
		else:
			dark += 1
	assert_gt(lit.size(), 0, "control: lit tiles on the way")
	assert_gt(dark, 0, "control: dark tiles on the way")
	assert_eq(paths.drawn(), lit, "a mark only on the explored tiles of the way")
	assert_false(target in paths.drawn(), "the X on a dark last tile: not drawn")
	assert_eq(marked.back(), target, "the way itself still goes there")
	# Walking lights the dark: each tile takes its mark as it is explored.
	var drawn := paths.redraws
	var newly_lit := false
	for i in 2000:
		_run_frames(1, HeroWalk.TICK)
		if not screen.walk.is_walking():
			break
		for tile in paths.marked():
			if world.is_explored(tile.x, tile.y) and not tile in lit:
				newly_lit = true
		if newly_lit:
			break
	assert_true(newly_lit, "control: the walk lit a tile of the way")
	var now_lit: Array[Vector2i] = []
	for tile in paths.marked():
		if world.is_explored(tile.x, tile.y):
			now_lit.append(tile)
	assert_eq(paths.drawn(), now_lit, "the newly lit tiles are marked")
	assert_gt(paths.redraws, drawn, "drawn again for them")


func test_the_hover_preview_hides_in_the_dark_too() -> void:
	var paths := screen.paths
	var world := screen.world
	var target := _target_into_the_dark(4, 14)
	assert_gt(target.x, -1, "control: a tile out in the dark")
	paths._hover = target
	paths._hover_since = Time.get_ticks_msec() - WorldPath.REST_MS - 10
	paths.frame(false)
	assert_true(paths.previewing(), "control: the preview of a way into the dark")
	for tile in paths.drawn():
		assert_true(world.is_explored(tile.x, tile.y), "previewed only on explored land: %s" % tile)
	assert_lt(paths.drawn().size(), paths.marked().size(), "the dark part not drawn")


func test_a_way_all_in_the_dark_shows_nothing() -> void:
	var paths := screen.paths
	var target := _target_into_the_dark(6, 20)
	assert_gt(target.x, -1, "control: a tile out in the dark")
	screen.walk_to_tile(target)
	_run_frames(1, HeroWalk.TICK)
	assert_true(paths.shown(), "control: marked")
	# Every tile of the way made dark (a test's surgery on the page).
	for tile in paths.marked():
		var at := tile.y * ShandalarWorld.PAGE_WIDTH + tile.x
		screen.world.page[at] = screen.world.page[at] & ~ShandalarWorld.EXPLORED & 0xFF
	paths._waited = true
	paths.frame(false)
	assert_false(paths.shown(), "no lit tile: nothing shows")
	assert_eq(paths.drawn(), [] as Array[Vector2i])


func test_with_the_dark_off_every_mark_is_drawn() -> void:
	var paths := screen.paths
	screen.view.fog = false
	var target := _target_into_the_dark(6, 20)
	screen.walk_to_tile(target)
	_run_frames(1, HeroWalk.TICK)
	assert_eq(paths.drawn(), paths.marked(), "no dark drawn: every tile marked")


# ------------------------------------------------------------ the board --

func _hand_board(open: Array, hero := DungeonBoard.START) -> DungeonBoard:
	var board := DungeonBoard.new()
	board.cells.resize(DungeonBoard.CELLS)
	board.cells.fill(0)
	board.depth.resize(DungeonBoard.CELLS)
	board.depth.fill(0)
	board.looks.resize(DungeonBoard.CELLS)
	board.looks.fill(0)
	for at in open:
		board.cells[at.x * DungeonBoard.HEIGHT + at.y] = DungeonBoard.OPEN
	board.dice = MsvcRandom.new(1)
	board.monsters = [1, 2, 3, 4, 5] as Array[int]
	board.sheet = "dungeon_tiles_1"
	board.hero = hero
	board.reveal(board.hero)
	return board


func test_the_board_walk_slides_at_the_screen_s_rate() -> void:
	DungeonView.frame_seconds = DungeonView.FRAME_SECONDS
	var board := _hand_board([Vector2i(7, 11), Vector2i(8, 11)], Vector2i(7, 11))
	var view := DungeonView.new()
	view.board = board
	add_child_autofree(view)
	view.set_process(false)
	var from := Vector2(DungeonBoard.cell_to_page(Vector2i(7, 11)))
	view.walk(Vector2i(7, 11), 3, 0, 8)
	assert_eq(view.call("shown_hero_point"), from, "the walk's first moment: on the cell")
	# Half a 66 ms frame: half of the frame's four pixels across and two up.
	view._process(DungeonView.FRAME_SECONDS * 0.5)
	assert_eq(view.hero_point(), from, "1997's frame not yet taken")
	assert_eq(view.call("shown_hero_point"), from + Vector2(2, -1), "drawn half way to the next frame's point")
	assert_eq(view.hero_step(), 0, "the pose is the frame's, 1997's")
	# At 60 Hz the figure moves every frame (1997's moved one frame in four).
	var points: Array[Vector2] = [view.call("shown_hero_point")]
	for i in 30:
		view._process(1.0 / 60.0)
		if not view.walking():
			break
		points.append(view.call("shown_hero_point"))
	var still := 0
	for i in range(1, points.size()):
		if points[i] == points[i - 1]:
			still += 1
	assert_eq(still, 0, "never standing still mid-walk: %s" % [points])
	# The walk's length and its end: 1997's.
	view._process(DungeonView.FRAME_SECONDS * 8.0)
	assert_false(view.walking(), "over after 8 frames of 66 ms")
	assert_eq(view.call("shown_hero_point"), view.hero_point(), "standing: drawn where 1997 stands the hero")


func test_the_board_walk_keeps_1997_s_frames() -> void:
	DungeonView.frame_seconds = DungeonView.FRAME_SECONDS
	var board := _hand_board([Vector2i(7, 11), Vector2i(8, 11)], Vector2i(7, 11))
	var view := DungeonView.new()
	view.board = board
	add_child_autofree(view)
	view.set_process(false)
	view.walk(Vector2i(7, 11), 3, 0, 8)
	var from := Vector2(DungeonBoard.cell_to_page(Vector2i(7, 11)))
	for frame in range(1, 8):
		view._process(DungeonView.FRAME_SECONDS)
		assert_eq(view.hero_point(), from + Vector2(4, -2) * frame, "frame %d: 1997's point" % frame)
		assert_eq(view.hero_step(), DungeonView.walk_step(frame), "frame %d: 1997's pose" % frame)
		assert_eq(view.call("shown_hero_point"), view.hero_point(), "on a frame's start, drawn on its point")
