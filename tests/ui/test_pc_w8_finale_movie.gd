extends GutTest
## Needs the imported 1997 skin (the win's movie, `win_movie.ogv`, converted
## from `Mtgend.avi` by the importer; the win's pictures).
## PART C, W8 — THE WIN'S MOVIE ([AdventureFinale], step MOVIE): with the
## skin's `win_movie.ogv` the battle won plays it centred over black at the
## 1997 page's scale; a click (after the step's moment) ends it, the
## Wingame page next, the movie gone; the movie's file is the skin's
## ([method GameSkin.movie], a Theora stream set to the skin's file).

const SAVES := "user://adventure_tests_pc_w8_movie"
const HALL := "user://adventure_tests_pc_w8_movie_hall"

var viewport: SubViewport
var screen: WorldScreen


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	HallOfFame.file = HALL + "/hall_of_fame.json"
	AdventureFinale.movie_forced = 1
	_clear()
	var setup := AdventureSetup.new()
	setup.player_name = "Ysolde Starfall"
	setup.color = "blue"
	setup.difficulty = 1
	setup.walker = "female"
	setup.seed_text = "12345"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	screen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.set_process(false)
	screen.player.monsters = [] as Array
	screen.player.defeated_wizards.assign(AdventurePlayer.COLORS)


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


func test_the_movie_is_the_skins_and_a_click_ends_it() -> void:
	var stream := GameSkin.movie(AdventureFinale.MOVIE_KEY) as VideoStreamTheora
	assert_not_null(stream, "the skin's converted movie, a Theora stream")
	assert_string_ends_with(stream.file, "win_movie.ogv")
	assert_null(GameSkin.movie("no_such_movie"), "none: null")
	AdventureFinale.after_fifth_wizard(screen, screen.player)
	await _frames()
	var finale := AdventureFinale.showing(screen)
	finale._shown_at -= 100000
	finale.choose("face")
	finale._shown_at -= 100000
	finale.go_on()
	await _frames()
	finale.builder.closed.emit()
	await _frames(2)
	var report := DuelReport.new()
	report.finished = true
	report.result = DuelReport.WIN
	report.winner = 0
	report.lives_start = [20, 200] as Array[int]
	report.lives_end = [9, 0] as Array[int]
	finale.duel._finish(report)
	await _frames()
	assert_eq(finale.step, AdventureFinale.MOVIE)
	var movie := finale.find_child("Movie", true, false) as VideoStreamPlayer
	assert_not_null(movie, "the movie up")
	assert_eq(movie.size, AdventureFinale.MOVIE_FRAME * finale._scale, "at the page's scale")
	assert_eq(movie.position, ((finale.size - movie.size) / 2.0).round(), "centred")
	finale.go_on()
	assert_eq(finale.step, AdventureFinale.MOVIE, "not in its first moment")
	finale._shown_at -= 100000
	finale.go_on()
	await _frames()
	assert_eq(finale.step, AdventureFinale.WIN, "a click: the picture")
	assert_false(is_instance_valid(movie) and movie.is_inside_tree() and not movie.is_queued_for_deletion(),
		"the movie gone")
	assert_not_null((finale.find_child("Art", true, false) as TextureRect).texture, "Wingame")
