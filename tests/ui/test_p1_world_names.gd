extends GutTest
## THE CREATURES' NAMES ON THE MAP — on the screen (the polish pass,
## 2026-10-28; the owner's ruling on the unused 1997 features: *"only §5,
## the creature names on the map — small, with their own on/off setting in
## the adventure's options menu"*). Off until switched on in the world's
## options ("Creature names"), remembered; on, a small name stands over
## each creature drawn, in its eight ticks of every 32 as 1997 copied it
## ([method WorldCreatures.map_name]), never over one on land not seen.

const SAVES := "user://adventure_tests_p1_names"
const CLERIC := 8

var viewport: SubViewport
var screen: WorldScreen


func before_each() -> void:
	Settings.clear_value(WorldHud.NAMES_SETTING)
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	screen = WorldScreen.new()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	# The clock held: the creature put here stays where it is put.
	screen.set_process(false)
	screen.player.monsters = [] as Array


func after_each() -> void:
	Settings.clear_value(WorldHud.NAMES_SETTING)
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _option(entry: String) -> Button:
	return screen.hud.find_child("Option_" + entry, true, false) as Button


## A Cleric in roaming slot [param slot], a tile and a half east of the hero.
func _cleric(slot := 0) -> Dictionary:
	var at := screen.player.position + Vector2i(48, 0)
	var held := {"slot": slot, "kind": "creature", "creature": CLERIC, "x": at.x, "y": at.y,
		"color": 5, "heading": 0, "frame": 0}
	screen.player.monsters.append(held)
	return held


func test_the_names_are_off_until_switched_on() -> void:
	assert_false(WorldHud.creature_names_wanted(), "off to begin with")
	_cleric()
	screen.player.monster_timer = 0
	screen._show_hero()
	assert_eq(screen.view.creature_names, {}, "no name over the creature")
	assert_eq(screen.view.names_shown(), [], "nothing drawn")
	screen.hud.toggle_options()
	assert_eq(_option("Names").text, "Creature names: off")


func test_switched_on_a_name_stands_over_the_creature_in_its_ticks() -> void:
	var held := _cleric()
	screen.player.monster_timer = 0
	screen._show_hero()
	screen.hud.toggle_options()
	_option("Names").pressed.emit()
	assert_true(WorldHud.creature_names_wanted(), "on, remembered")
	assert_true(screen.hud.options_shown(), "a switch leaves the options open")
	assert_eq(_option("Names").text, "Creature names: on")
	assert_eq(screen.view.creature_names, {0: "Cleric"}, "at once, in slot 0's ticks")
	var shown := screen.view.names_shown()
	assert_eq(shown.size(), 1, "one name drawn")
	if shown.size() == 1:
		var feet := screen.view.drawn_at(Vector2(int(held["x"]), int(held["y"])))
		assert_eq(shown[0][0], "Cleric")
		assert_almost_eq((shown[0][1] as Vector2).x, feet.x, 0.5, "centred over the creature")
		assert_lt((shown[0][1] as Vector2).y, feet.y - 20.0 * screen.view.zoom, "over its body, not its feet")
	screen.player.monster_timer = 8
	screen._show_hero()
	assert_eq(screen.view.creature_names, {}, "out of its eight ticks: gone (slot 1's turn)")
	screen.player.monster_timer = 32
	screen._show_hero()
	assert_eq(screen.view.creature_names, {0: "Cleric"}, "back in the next round")
	_option("Names").pressed.emit()
	assert_false(WorldHud.creature_names_wanted())
	assert_eq(screen.view.creature_names, {}, "switched off: gone at once")


func test_no_name_over_a_creature_on_land_not_seen() -> void:
	var view := WorldView.new()
	view.size = Vector2(800, 600)
	add_child_autofree(view)
	var world := ShandalarWorld.new()
	world.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	view.world = world
	view.camera = Vector2(640, 640)
	view.creatures = [{"slot": 2, "creature": CLERIC, "x": 660, "y": 640, "heading": 0, "frame": 0,
		"color": 5}] as Array[Dictionary]
	view.creature_names = {2: "Cleric"}
	assert_eq(view.names_shown(), [], "the land is dark: the creature is not drawn, nor its name")
	view.fog = false
	assert_eq(view.names_shown().size(), 1, "the dark off: drawn and named")
	view.creature_names = {}
	assert_eq(view.names_shown(), [], "no names: none drawn")
