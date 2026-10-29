extends GutTest
## THE WORLD'S PICTURES KEPT UP WITHOUT A HITCH (the smoothness pass,
## 0.50.66): the ground and the uprights were drawn again in one frame
## whenever the screen left their margin — at the furthest zoom 22–29 ms —
## and a zoom easing out (the zoom eased since 0.50.66, [method
## WorldScreen.set_zoom]) would have drawn them again on every frame it
## passed their edge. Now the next pictures are drawn ahead once half the
## margin is walked, and an ease covers the zoom it goes to ([member
## WorldView.zoom_goal]). With or without the 1997 sheets (the plain world
## is kept the same way); test_c20_M2_world_pictures_skin holds the 1997
## drawing's own shares.

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
	await wait_process_frames(3)


## The zoom eased from [param from] to [param to] as `1 − exp(−k·delta)`
## over about 0.3 s at 60 frames a second, the goal told when [param goal]:
## back `[frames the screen showed land not drawn, drawings]`.
func _ease(from: float, to: float, goal: bool) -> Array:
	view.zoom_goal = to if goal else 0.0
	var drawings := view._drawing
	var uncovered := 0
	var z := from
	for i in 18:
		z = to + (z - to) * exp(-20.0 / 60.0)
		view.zoom = z
		await get_tree().process_frame
		var needed := view._screen_round(view._anchor, view._shown_camera(), view.zoom)
		if not view._covered.encloses(needed):
			uncovered += 1
	return [uncovered, view._drawing - drawings]


## Frames run until the pictures fit the zoom: none being drawn ahead, and
## not too big for it (the zoom back in draws smaller ones ahead).
func _settle() -> void:
	for i in 60:
		view.finish_drawing()
		await get_tree().process_frame
		var needed := view._screen_round(view._anchor, view._shown_camera(), view.zoom)
		if view._next == null and view._covered.get_area() <= needed.get_area() * WorldView.SHED:
			return


func test_an_ease_out_is_covered_by_one_drawing() -> void:
	var control: Array = await _ease(2.0, 0.5, false)
	assert_gt(int(control[1]), 2, "control: without the goal, drawn again each time the ease passed the edge (%d)" % control[1])
	view.zoom = 2.0
	view.zoom_goal = 0.0
	await _settle()
	var eased: Array = await _ease(2.0, 0.5, true)
	assert_eq(int(eased[0]), 0, "never land left undrawn on the way")
	assert_eq(int(eased[1]), 1, "one drawing, as the old jump made")


func test_an_ease_in_draws_nothing_until_the_pictures_are_far_too_big() -> void:
	var eased: Array = await _ease(2.0, 2.5, true)
	assert_eq(int(eased[0]), 0)
	assert_eq(int(eased[1]), 0, "closer: only scaled")


## Walking on past half the margin, the next pictures are drawn before the
## screen leaves the old ones: never one drawn in one go.
func test_the_next_pictures_are_drawn_ahead_of_the_walk() -> void:
	var at_once := view._at_once
	var drawings := view._drawing
	var uncovered := 0
	for i in 80:
		view.hero = view.hero + Vector2(1, 1)
		view.camera = view.hero
		view.queue_redraw()
		view.frame(0.0, HeroWalk.TICK)
		await get_tree().process_frame
		if not view._covered.encloses(view._screen_round(view._anchor, view._shown_camera())):
			uncovered += 1
	assert_gt(view._drawing, drawings + 1, "drawn anew as the walk went on")
	assert_eq(view._at_once, at_once, "each ahead of it, none in one go")
	assert_eq(uncovered, 0)


## A leap (a World Magic, the camera sent far) cannot be drawn ahead: in
## one go, as before.
func test_a_leap_is_drawn_in_one_go() -> void:
	var at_once := view._at_once
	view.camera = start + Vector2(400, 0)
	await wait_process_frames(2)
	assert_eq(view._at_once, at_once + 1)
	assert_eq(view._anchor, Vector2i(start + Vector2(400, 0)))
