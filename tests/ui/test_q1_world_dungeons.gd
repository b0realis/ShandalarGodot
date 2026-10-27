extends GutTest
## THE DUNGEONS ON THE SCREEN (the quick world package, 2026-10-27, step 2
## — item A), without the 1997 sheets: the world drawn plain marks a known
## dungeon (a dark mouth ringed in gold) on land seen or not (the owner's
## ruling A-1), the small map too (A-2), both drawn again when a clue is
## learned or a dungeon moves; the world screen gives them what
## [method WorldClues.on_world] says, and the pointer names a known
## dungeon on land not yet seen.

const SAVES := "user://adventure_tests_q1_world_dungeons"


## A skin without the world's sheets: the world drawn plain.
class NoSheets extends WorldArt:
	func texture(_key: String) -> Texture2D:
		return null


var viewport: SubViewport
var screen: WorldScreen


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
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
	await _frames(3)
	screen.set_process(false)
	screen.player.monsters = [] as Array


func after_each() -> void:
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


func _draws(node: CanvasItem) -> Array[int]:
	var count: Array[int] = [0]
	node.draw.connect(func() -> void: count[0] += 1)
	return count


## The first dungeon slot (5–14) whose tile the hero has not seen.
func _unseen_dungeon() -> int:
	for index in range(5, 15):
		var slot: Dictionary = screen.world.encounters[index]
		if not screen.world.is_explored(int(slot["x"]), int(slot["y"])):
			return index
	return -1


func test_the_screen_gives_the_dungeons_known_to_the_world_and_the_small_map() -> void:
	assert_true(screen.view.dungeons.is_empty(), "nothing known: nothing drawn")
	assert_true(screen.hud.minimap.dungeons.is_empty())
	var index := _unseen_dungeon()
	assert_gt(index, -1, "control: a dungeon far off")
	WorldClues.reveal(screen.player, index)
	screen._show_hero()
	assert_eq(screen.view.dungeons.size(), 1, "a clue learned: drawn on the world")
	assert_eq(int(screen.view.dungeons[0]["index"]), index)
	assert_eq(screen.hud.minimap.dungeons.size(), 1, "and on the small map")


func test_the_pointer_names_a_known_dungeon_on_land_not_seen() -> void:
	var index := _unseen_dungeon()
	var slot: Dictionary = screen.world.encounters[index]
	var tile := Vector2i(int(slot["x"]), int(slot["y"]))
	assert_false(screen.world.is_explored(tile.x, tile.y), "control: unseen land")
	assert_true(screen.place_at(tile).is_empty(), "unknown: nothing there for the pointer")
	slot["clues"] = WorldClues.CREATURES
	var place := screen.place_at(tile)
	assert_eq(String(place.get("kind", "")), "dungeon", "known: the dungeon named [QoL]")
	assert_eq(String(place.get("name", "")), WorldNames.dungeon_name(index))
	assert_eq(screen.pointer_for(tile), WorldCursors.FOR_PLACE.get("dungeon", WorldCursors.Kind.WALK),
		"its pointer worn")
	var near := tile + Vector2i(1, 0)
	if not screen.world.is_explored(near.x, near.y):
		assert_true(screen.place_at(near).is_empty(), "beside it, unseen land names nothing")


func test_the_plain_world_marks_a_dungeon_seen_or_not() -> void:
	var view := WorldView.new()
	view.art = NoSheets.new()
	add_child_autofree(view)
	view.size = Vector2(1280, 800)
	view.world = screen.world
	var index := _unseen_dungeon()
	var slot: Dictionary = screen.world.encounters[index]
	view.hero = Vector2(int(slot["x"]) * 32 + 16, int(slot["y"]) * 32 + 16)
	view.camera = view.hero
	await _frames(3)
	var ground := view.find_child("Ground", true, false) as CanvasItem
	if ground == null:
		for child in view.get_children(true):
			if String(child.name) == "Ground":
				ground = child
	assert_not_null(ground, "control: the ground's picture")
	var drawn := _draws(ground)
	slot["clues"] = WorldClues.RULES
	view.dungeons = WorldClues.on_world(screen.world)
	await _frames(3)
	assert_eq(drawn[0], 1, "a dungeon learned: the ground drawn again, once")
	assert_true(view._plain, "control: drawn plain")
	view.dungeons = WorldClues.on_world(screen.world)
	await _frames(3)
	assert_eq(drawn[0], 1, "the same dungeons: not drawn again")


func test_the_small_map_draws_again_when_a_dungeon_is_learned_or_moves() -> void:
	var minimap := screen.hud.minimap
	var ground := minimap.find_child("Ground", true, false) as CanvasItem
	await _frames(2)
	var drawn := _draws(ground)
	var index := _unseen_dungeon()
	WorldClues.reveal(screen.player, index)
	screen._show_hero()
	await _frames(2)
	assert_eq(drawn[0], 1, "learned: drawn again once")
	screen._show_hero()
	await _frames(2)
	assert_eq(drawn[0], 1, "nothing new: not again")
	DungeonDoors.move(screen.player, index)
	screen._show_hero()
	await _frames(2)
	assert_eq(drawn[0], 2, "moved: drawn again")
