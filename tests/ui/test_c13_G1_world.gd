extends GutTest
## THE WORLD SCREEN'S FIXES OF PART C STAGE C3 (G1): the arrival's words lie
## under the panel and are put away as it opens a pane of its own over them
## (h4-2); the pending leave once the panes are done can be read and
## cancelled — the contract the finale's win at the Hall calls (h1-2, h3-1).

const ARRIVAL := "Hunter Four sets out as a black mage, at Magician level: an easy game.\nWorld seed 4242."


## A world screen that counts its leaving instead of going.
class Probe extends WorldScreen:
	var titles := 0

	func _go_to_title() -> void:
		titles += 1
		_leaving = true


var viewport: SubViewport
var screen: Probe


func before_each() -> void:
	AdventurePlayer.saves_folder = "user://adventure_tests_c13_G1_world"
	var setup := AdventureSetup.new()
	setup.player_name = "Hunter Four"
	setup.color = "black"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "4242"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	screen = Probe.new()
	screen.record = setup.resolve({})
	screen.arrival = ARRIVAL
	viewport.add_child(screen)
	await _frames(3)
	screen.set_process(false)


func after_each() -> void:
	await _frames()
	var folder := "user://adventure_tests_c13_G1_world"
	var dir := DirAccess.open(folder)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(folder)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


func _arrival() -> Label:
	return screen.get_node("Arrival") as Label


# ---------------------------------------------------- h4-2: the arrival --

func test_the_arrival_lies_under_the_panel() -> void:
	var words := _arrival()
	assert_not_null(words)
	assert_true(words.visible, "control: the arrival's words shown")
	assert_lt(words.get_index(), screen.hud.get_index(), "under the panel and its panes")
	screen.rebuild_hud()
	await _frames()
	assert_lt(words.get_index(), screen.hud.get_index(), "and under the panel made again (Big buttons)")


func test_the_hero_s_pane_puts_the_arrival_away() -> void:
	var words := _arrival()
	screen._process(0.016)
	await get_tree().create_timer(0.35).timeout
	assert_eq(words.modulate.a, 1.0, "control: still up within its seconds")
	screen.toggle_hero()
	assert_true(screen.hud.hero_shown(), "control: the hero's pane open")
	screen._process(0.016)
	await get_tree().create_timer(0.35).timeout
	assert_almost_eq(words.modulate.a, 0.0, 0.01, "put away as the pane opens over it")
	screen.toggle_hero()
	screen._process(0.016)
	await _frames()
	assert_almost_eq(words.modulate.a, 0.0, 0.01, "and gone for good")


func test_the_keys_pane_puts_the_arrival_away_too() -> void:
	screen.toggle_help()
	assert_true(screen.hud.help_shown())
	screen._process(0.016)
	await get_tree().create_timer(0.35).timeout
	assert_almost_eq(_arrival().modulate.a, 0.0, 0.01)


# ------------------------------------------- the leave after the panes --

func test_the_pending_leave_is_read_and_can_be_cancelled() -> void:
	assert_false(screen.leaving_after_panes(), "none to begin with")
	screen.leave_after_panes()
	assert_true(screen.leaving_after_panes(), "a held duel's Return to main menu once it was over")
	screen.stay_after_panes()
	assert_false(screen.leaving_after_panes(), "cancelled: the hero walks on")
	screen._process(0.016)
	await _frames()
	assert_eq(screen.titles, 0, "no title")
	screen.leave_after_panes()
	screen._process(0.016)
	await _frames()
	assert_eq(screen.titles, 1, "control: left once nothing holds the world")
