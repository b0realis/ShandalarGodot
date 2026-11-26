extends GutTest
## 0.70.11 campaign, bugs2 #4: a place's pane with more words than the
## screen holds scrolls its words and keeps its buttons on the screen; a
## pane that fits shows its words whole, as before.

const SAVES := "user://c1126_adv_place_scroll_saves"

var viewport: SubViewport
var screen: WorldScreen


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


func _open(size: Vector2i, big: bool) -> void:
	AdventurePlayer.saves_folder = SAVES
	TileReveal.forced = 0
	var setup := AdventureSetup.new()
	setup.player_name = "Fit"
	setup.color = "green"
	setup.difficulty = 1
	setup.seed_text = "12345"
	viewport = SubViewport.new()
	viewport.size = size
	add_child_autofree(viewport)
	screen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.set_process(false)
	screen.player.monsters = [] as Array
	screen.hud.big = big


func after_each() -> void:
	TileReveal.forced = -1
	AdventurePlayer.finish_saves()
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	AdventurePlayer.forget_saves()


func _place(lines: int, buttons: int) -> Dictionary:
	var words: Array = []
	for n in lines:
		words.append("Line %d of a long tale an author wrote for this place, which goes on for a while and wraps." % (n + 1))
	var actions: Array = []
	for n in buttons:
		actions.append(["leave", "Choice number %d" % (n + 1), true])
	actions.append(["leave", "Leave", true])
	return {"kind": "place", "name": "A Long Place", "subtitle": "A test", "picture": "visit_city",
		"lines": words, "actions": actions}


func _on_screen(pane: VisitPane) -> void:
	var area := Vector2(viewport.size)
	var rect := pane.get_global_rect()
	assert_gte(rect.position.y, -0.5, "the pane's top on the screen (%s)" % rect)
	assert_lte(rect.end.y, area.y + 0.5, "the pane's foot on the screen (%s)" % rect)
	for button: Button in pane._choices.get_children():
		var at := button.get_global_rect()
		assert_true(at.position.y >= -0.5 and at.end.y <= area.y + 0.5, "%s on the screen (%s)" % [button.text, at])


func test_a_long_place_scrolls_its_words_and_keeps_leave_on_the_screen() -> void:
	for config: Array in [[Vector2i(1280, 800), true], [Vector2i(1280, 800), false], [Vector2i(1280, 720), true]]:
		await _open(config[0], config[1])
		var pane := screen.open_place(_place(30, 4))
		await _frames(8)
		_on_screen(pane)
		var scroll := pane._said_scroll
		assert_lt(scroll.size.y, pane._said.size.y - 1.0, "the words are taller than their window: they scroll")
		assert_gte(scroll.size.y, VisitPane.WORDS_LEAST - 0.5, "never less than a few lines")
		assert_eq(pane._grow, VisitPane.LEAST, "the picture gave what it could first")
		scroll.scroll_vertical = 100000
		await _frames(2)
		assert_gt(scroll.scroll_vertical, 0, "and the last line can be reached")
		assert_eq(pane.words(), "\n".join(pane.place["lines"]))
		viewport.queue_free()
		await _frames(2)


func test_a_pane_that_fits_shows_its_words_whole() -> void:
	await _open(Vector2i(1280, 800), false)
	var pane := screen.open_place(_place(2, 1))
	await _frames(8)
	_on_screen(pane)
	assert_almost_eq(pane._said_scroll.size.y, pane._said.get_combined_minimum_size().y, 1.5, "no scrolling")
	assert_false(pane._said_scroll.get_v_scroll_bar().visible)
	assert_eq(pane._grow, pane._most, "the picture at its size")
	# Words said anew, longer than the screen: the pane fits again.
	var many: Array = []
	for n in 40:
		many.append("Another line of the tale, number %d, and it is not a short one either." % n)
	pane.say(many)
	await _frames(8)
	_on_screen(pane)
	assert_true(pane._said_scroll.get_v_scroll_bar().visible, "now they scroll")
	pane.say([])
	await _frames(4)
	assert_eq(pane.words(), "")
	assert_false(pane._said_scroll.visible)
