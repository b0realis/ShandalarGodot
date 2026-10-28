extends GutTest
## PART C, W8 — THE FINALE'S HOOKS IN THE WORLD SCREEN ([WorldScreen]):
## Arzakon's portal drawn from the hero's save ([member WorldView.portal]),
## walked onto — its own pane over the world, holding it ([method
## AdventureFinale.at_portal]) — and named under the pointer ([method
## WorldScreen.place_at]); and an adventure TAKEN UP AGAIN from its save
## ([LoadAdventureScreen.open_save]) opening at its end, at Arzakon's door,
## at his question or — won — at the last choice again ([method
## AdventureFinale.after_load], from the screen's own start), a new
## adventure left as it was.

const SAVES := "user://adventure_tests_pc_w8_world_hooks"
const HALL := "user://adventure_tests_pc_w8_world_hooks_hall"

var viewport: SubViewport


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	HallOfFame.file = HALL + "/hall_of_fame.json"
	AdventureFinale.movie_forced = 0
	_clear()
	AdventurePlayer.forget_saves()
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)


func after_each() -> void:
	AdventureFinale.movie_forced = -1
	_clear()
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	HallOfFame.file = HallOfFame.FILE
	AdventurePlayer.forget_saves()


func _clear() -> void:
	for folder in [SAVES, HALL]:
		var dir := DirAccess.open(folder)
		if dir != null:
			for file_name in dir.get_files():
				dir.remove(file_name)
			DirAccess.remove_absolute(folder)


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


## A saved hero who has beaten all five; [param shape] sets the end's marks
## before the save.
func _saved(shape: Callable, rule := AdventurePlayer.LIFE_RELOAD) -> String:
	var setup := AdventureSetup.new()
	setup.player_name = "Ysolde Starfall"
	setup.color = "blue"
	setup.difficulty = 1
	setup.walker = "female"
	setup.seed_text = "12345"
	var record := setup.resolve({})
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	hero.life_rule = rule
	hero.monster_timer = 1
	hero.defeated_wizards.assign(AdventurePlayer.COLORS)
	shape.call(hero)
	return hero.autosave()


## The world screen taken up from [param path], in the tree.
func _taken_up(path: String) -> WorldScreen:
	var screen := LoadAdventureScreen.open_save(path)
	viewport.add_child(screen)
	await _frames(3)
	screen.set_process(false)
	return screen


func test_the_portal_is_drawn_walked_onto_and_named() -> void:
	var path := _saved(func(hero: AdventurePlayer) -> void: FinalBattle.open_portal(hero))
	var screen := await _taken_up(path)
	assert_null(AdventureFinale.showing(screen), "the portal waits on the world")
	assert_eq(screen.view.portal, screen.player.portal, "drawn from the save")
	var at := FinalBattle.portal_tile_of(screen.player)
	assert_eq(screen.place_at(at)["name"], FinalBattle.PORTAL_NAME, "named under the pointer")
	var pane := screen.visit(at)
	assert_true(pane is AdventureFinale.PortalPane, "its own pane")
	assert_true(screen.modal(), "holding the world")
	assert_eq(screen.visit(at), pane, "once")
	pane.choose("leave")
	await _frames()
	assert_false(screen.modal(), "Not yet: the world again")
	pane = screen.visit(at)
	pane.choose("enter")
	await _frames()
	assert_eq(AdventureFinale.showing(screen).step, AdventureFinale.BANISH, "in: the battle's way")
	assert_true(screen.modal())


func test_the_monument_after_the_win() -> void:
	var path := _saved(func(hero: AdventurePlayer) -> void:
		FinalBattle.open_portal(hero)
		hero.portal["state"] = FinalBattle.PORTAL_PETRIFIED
		hero.ended = AdventurePlayer.ENDED_WON
		hero.final = {"score": 640, "roamed": true})
	var screen := await _taken_up(path)
	var finale := AdventureFinale.showing(screen)
	assert_eq(finale.step, AdventureFinale.HALL, "a won adventure asks End or Return again (the owner)")
	finale.last_choice(AdventureFinale.ROAMING)
	await _frames()
	assert_null(AdventureFinale.showing(screen), "walking on")
	assert_true(screen.player.at_peace())
	var at := FinalBattle.portal_tile_of(screen.player)
	assert_eq(screen.place_at(at)["name"], FinalBattle.MONUMENT_NAME)
	var pane := screen.visit(at)
	assert_eq(pane.place["name"], FinalBattle.MONUMENT_NAME)
	pane.choose("leave")
	await _frames()


func test_taken_up_at_the_door_it_opens_at_the_door() -> void:
	var path := _saved(func(hero: AdventurePlayer) -> void:
		FinalBattle.door(hero)
		hero.final_attempts = 1)
	var screen := await _taken_up(path)
	var finale := AdventureFinale.showing(screen)
	assert_not_null(finale, "at the door")
	assert_eq(finale.step, AdventureFinale.DOOR, "fight or return")
	assert_true(screen.modal(), "the world held")


func test_taken_up_at_the_question_it_asks_again() -> void:
	var path := _saved(func(_hero: AdventurePlayer) -> void: pass)
	var screen := await _taken_up(path)
	assert_eq(AdventureFinale.showing(screen).step, AdventureFinale.FIFTH)


func test_a_failed_adventure_opens_on_its_end() -> void:
	var path := _saved(func(hero: AdventurePlayer) -> void:
		hero.ended = AdventurePlayer.ENDED_FAILED
		hero.final = {"result": "failed"}, AdventurePlayer.LIFE_ONE)
	var screen := await _taken_up(path)
	assert_true(screen.ended(), "the end, not the world")
	assert_true(screen.lost())
	assert_null(AdventureFinale.showing(screen))


func test_one_life_closed_mid_battle_is_the_quest_failed() -> void:
	var path := _saved(func(hero: AdventurePlayer) -> void: FinalBattle.door(hero), AdventurePlayer.LIFE_ONE)
	var screen := await _taken_up(path)
	assert_eq(screen.player.ended, AdventurePlayer.ENDED_FAILED)
	assert_true(screen.ended())
	var saved := AdventurePlayer.load_from(path)
	assert_eq(saved.ended, AdventurePlayer.ENDED_FAILED, "saved so")


func test_an_adventure_going_on_opens_on_its_world() -> void:
	var path := _saved(func(hero: AdventurePlayer) -> void: hero.defeated_wizards.clear())
	var screen := await _taken_up(path)
	assert_null(AdventureFinale.showing(screen))
	assert_false(screen.modal())
	assert_false(screen.ended())
