extends GutTest
## THE GLIDE (the smoothness pass, 0.50.66; the owner: "One critique of og
## game was clunkiness. I really want our adventure to play silky butter
## smooth"). 1997's pace moves the hero two units every third tick on slow
## land, a unit and two by turns on a road, a creature ambling a unit every
## other tick; slid from tick to tick, the hero stood still two frames in
## three in a forest (the profiler: a camera speed's spread of 1.4, 56–61%
## of frames still). [WorldView] now draws each mover where it stood on
## average over the last ticks — three for the hero, two for a creature —
## so every land walks at an even speed, never past the place the clock
## holds and at most about 90 ms behind it; while the world waits under a
## pane they walk on into their places. Each test also runs the old slide
## over the same ticks, the red it replaces.

const TICK := HeroWalk.TICK
## Frames a tick in these tests (a 66 Hz screen, about).
const FRAMES := 4

var view: WorldView
var world: ShandalarWorld
var start := Vector2.ZERO


func before_each() -> void:
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


## The hero walked [param steps] (units along x, one a tick, repeated
## [param ticks] times) as the world screen walks them: each tick the place
## given, then [constant FRAMES] frames between ticks. Back: per frame the
## drawn x, the clock's x, and the old slide's x (from the tick before to
## this one).
func _walk(steps: Array, ticks: int) -> Dictionary:
	var drawn := PackedFloat64Array()
	var clock := PackedFloat64Array()
	var old := PackedFloat64Array()
	var before := view.hero.x
	for k in ticks:
		var now := view.hero + Vector2(float(steps[k % steps.size()]), 0)
		before = view.hero.x
		view.hero = now
		view.camera = now
		for f in FRAMES:
			# Frames in the middle of their stretch of the tick, so the
			# means below are the walk's own, not the sampling's.
			var blend := (f + 0.5) / FRAMES
			view.frame(blend, TICK / FRAMES)
			drawn.append(view._shown_hero().x)
			clock.append(view.hero.x)
			old.append(lerpf(before, now.x, blend))
	return {"drawn": drawn, "clock": clock, "old": old}


## Per frame steps of [param xs] from frame [param skip] on.
static func _steps(xs: PackedFloat64Array, skip: int) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for i in range(maxi(skip, 1), xs.size()):
		out.append(xs[i] - xs[i - 1])
	return out


static func _spread(steps: PackedFloat64Array) -> float:
	var mean := 0.0
	for s in steps:
		mean += s
	mean /= steps.size()
	var sq := 0.0
	for s in steps:
		sq += (s - mean) * (s - mean)
	return sqrt(sq / steps.size()) / mean if mean > 0.0 else 0.0


static func _still(steps: PackedFloat64Array) -> int:
	var n := 0
	for s in steps:
		if absf(s) < 0.0001:
			n += 1
	return n


func test_slow_land_walks_evenly_never_ahead_and_90_ms_behind() -> void:
	var walk := _walk([0, 0, 2], 36)
	var skip := FRAMES * 6
	var steps := _steps(walk["drawn"], skip)
	var old_steps := _steps(walk["old"], skip)
	assert_gt(_spread(old_steps), 1.0, "control: the old slide stopped and started (spread %.2f)" % _spread(old_steps))
	assert_gt(_still(old_steps), old_steps.size() / 2, "control: still in two frames of three")
	assert_almost_eq(_spread(steps), 0.0, 0.001, "the glide: every frame the same step")
	assert_eq(_still(steps), 0, "no frame still")
	assert_almost_eq(steps[0], 2.0 / 3.0 / FRAMES, 0.0001, "two thirds of a unit a tick")
	var behind := 0.0
	var ahead := false
	var drawn: PackedFloat64Array = walk["drawn"]
	var clock: PackedFloat64Array = walk["clock"]
	for i in range(skip, drawn.size()):
		behind += clock[i] - drawn[i]
		ahead = ahead or drawn[i] > clock[i] + 0.0001
	assert_false(ahead, "never drawn past the place the clock holds")
	var lag_ms := behind / (drawn.size() - skip) / (2.0 / 3.0) * TICK * 1000.0
	assert_almost_eq(lag_ms, 90.0, 1.0, "90 ms behind it (%.1f)" % lag_ms)


func test_a_road_s_one_and_two_flutter_a_third_as_much() -> void:
	var walk := _walk([1, 2], 40)
	var steps := _steps(walk["drawn"], FRAMES * 6)
	var old := _spread(_steps(walk["old"], FRAMES * 6))
	assert_gt(old, 0.25, "control: the old slide's two speeds (%.3f)" % old)
	assert_lt(_spread(steps), 0.12, "the glide's (%.3f)" % _spread(steps))
	assert_eq(_still(steps), 0)


func test_plain_land_walks_evenly_too() -> void:
	var walk := _walk([1], 24)
	var steps := _steps(walk["drawn"], FRAMES * 6)
	assert_almost_eq(_spread(steps), 0.0, 0.001, "one unit a tick, evenly")


## A creature ambling a unit every other tick glides at half a unit a tick.
func test_an_ambling_creature_glides_evenly() -> void:
	var at := Vector2i(start) + Vector2i(60, 0)
	var xs := PackedFloat64Array()
	var olds := PackedFloat64Array()
	var x := at.x
	for k in 30:
		var before := x
		x -= 1 if k % 2 == 0 else 0
		var seen: Array[Dictionary] = [{"slot": 3, "creature": 1, "x": x, "y": at.y, "heading": 7, "frame": 1, "color": 2}]
		view.creatures = seen
		for f in FRAMES:
			view.frame(float(f) / FRAMES, TICK / FRAMES)
			xs.append(view._shown_creature(seen[0]).x)
			olds.append(lerpf(before, x, float(f) / FRAMES))
	var steps := _steps(xs, FRAMES * 4)
	assert_gt(_still(_steps(olds, FRAMES * 4)), 20, "control: the old slide stood every other tick")
	assert_almost_eq(_spread(steps), 0.0, 0.001, "the glide: even")
	assert_almost_eq(steps[0], -0.5 / FRAMES, 0.0001, "half a unit a tick")


## THE MEETING'S MOMENT: the tick that meets a creature opens a pane and the
## world waits ([method WorldView.frame] at 1). The movers walk on into the
## places the clock left them — at twice their pace — and stop there.
func test_while_the_world_waits_they_walk_into_their_places() -> void:
	_walk([1], 12)
	var meet := view.hero + Vector2(1, 0)
	view.hero = meet
	view.camera = meet
	var gap := meet.x - view._shown_hero().x
	view.frame(1.0, TICK / FRAMES)
	assert_almost_eq(view.hero, meet, Vector2(0.001, 0.001), "the tick that opened the pane is kept")
	var frames := 0
	var ahead := false
	var last := view._shown_hero().x
	var even := true
	while view._shown_hero().distance_to(meet) > 0.0001 and frames < 40:
		view.frame(1.0, TICK / FRAMES)
		frames += 1
		var now := view._shown_hero().x
		ahead = ahead or now > meet.x + 0.0001
		even = even and now >= last - 0.0001
		last = now
	assert_gt(gap, 1.5, "control: they were drawn behind as the meeting came (%.2f units)" % gap)
	assert_false(ahead, "never past it")
	assert_true(even, "walking on, not back")
	var ms := frames * TICK / FRAMES * 1000.0
	assert_lte(ms, HeroWalk.TICK * 1000.0 * WorldView.HERO_GLIDE / WorldView.SETTLE + 1.0,
		"there within a glide at twice the pace (%.0f ms)" % ms)
	view.frame(0.4, TICK / FRAMES)
	assert_almost_eq(view._shown_hero(), meet, Vector2(0.0001, 0.0001), "and they stand there as the clock runs on")


## A frame that ran several ticks (a slow frame, a quick pace) keeps a
## place for each, so the glide does not leap.
func test_a_long_frame_keeps_a_place_for_each_tick() -> void:
	_walk([1], 8)
	var before := view._shown_hero()
	view.hero = view.hero + Vector2(3, 0)
	view.camera = view.hero
	view.frame(0.75, TICK * 3.0)
	var kept := view._hero_ticks
	assert_eq(kept[kept.size() - 1].x - kept[kept.size() - 2].x, 1.0, "three ticks in one frame: a unit each")
	assert_lt(view._shown_hero().x - before.x, 3.01, "no leap")


func test_the_game_reads_the_clock_s_places() -> void:
	_walk([0, 0, 2], 7)
	assert_ne(view._shown_hero(), view.hero, "control: drawn behind")
	assert_eq(view.camera, view.hero, "the camera the game reads is the clock's")
	assert_eq(view.project(view.hero), Vector2.ZERO)
	assert_almost_eq(view.unproject(view.feet()), view.hero, Vector2(0.001, 0.001))
	assert_eq(view.drawn_at(view._shown_hero()), view.feet(), "the picture follows the hero as drawn")


## Standing, the hero is drawn on their very place at every moment of the
## tick — not an average of it a rounding away, which would shift the whole
## picture by a hair and change the odd pixel of a sharp sheet.
func test_standing_the_hero_is_drawn_exactly_on_their_place() -> void:
	view.hero = start + Vector2(0.3, 0.7)
	view.camera = view.hero
	view.frame(0.0, TICK)
	var exact := true
	for k in 6:
		view.hero = view.hero
		for f in 7:
			view.frame((f + 0.37) / 7.0, TICK / 7.0)
			exact = exact and view._shown_hero() == view.hero and view._shown_camera() == view.camera
	assert_true(exact, "the place itself, every frame")

