extends GutTest
## THE DOORS ON THE WORLD SCREEN (the quick world package, 2026-10-27,
## step 3): the board's seam in [WorldScreen] — a castle's "Yes, enter the
## castle." and a dungeon's "Enter the dungeon" go in ([method
## WorldScreen._enter_board]: the adventure saved at the door — the
## owner's D2, part C —, [method DungeonDoors.enter], the board over the
## world holding it, no save while it is up) and come out ([method
## WorldScreen._board_done]: [method DungeonDoors.leave], the game saved,
## the retaliation's news after the save). A stub board stands in through
## the seam ([DungeonPane]'s own flow: tests/ui/test_pc_w6_board_pane.gd),
## and the doors' panes are answered as their buttons answer. Also: a
## castle visited is marked so (the city list's castles, ruling H5), and
## its tune comes to full voice (1997).

const SAVES := "user://adventure_tests_q1_world_doors"


## A board as part C will make it: `finished(result)`.
class FakeBoard extends Control:
	signal finished(result: Dictionary)


## A world screen whose board is the test's own, and which counts its
## saves (and what the save held of the siege) and its leaving.
class Probe extends WorldScreen:
	var board: Control = null
	var given := {}
	var opened := 0
	var ready_board := true
	var saves := 0
	var siege_at_save := false
	var titles := 0

	func _board_ready() -> bool:
		return ready_board

	func _open_board(setup: Dictionary) -> Control:
		opened += 1
		given = setup
		if board != null:
			add_child(board)
		return board

	func _write_autosave() -> String:
		saves += 1
		siege_at_save = player.siege_active
		return super()

	func _go_to_title() -> void:
		titles += 1
		_leaving = true


var viewport: SubViewport
var screen: Probe


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	await _open_world(1)


func after_each() -> void:
	_drop_unused_board()
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


## The stub board never opened (not in the tree) freed.
func _drop_unused_board() -> void:
	if screen != null and is_instance_valid(screen) and is_instance_valid(screen.board) \
			and not screen.board.is_inside_tree():
		screen.board.free()


func _open_world(difficulty: int) -> void:
	if viewport != null and is_instance_valid(viewport):
		_drop_unused_board()
		viewport.queue_free()
		await _frames()
	var setup := AdventureSetup.new()
	setup.player_name = "Inniscor"
	setup.color = "green"
	setup.difficulty = difficulty
	setup.walker = "male"
	setup.seed_text = "12345"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	screen = Probe.new()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.set_process(false)
	screen.player.food = 50
	screen.player.monsters = [] as Array
	screen.board = FakeBoard.new()
	screen.saves = 0


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


## The castle site of colour [param castle] (0 black … 4 white).
func _castle_site(castle: int) -> int:
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == ShandalarWorld.CASTLE \
				and DungeonDoors.castle_of(screen.world, slot) == castle:
			return slot
	return -1


func _site_tile(slot: int) -> Vector2i:
	var site: Dictionary = screen.world.sites[slot]
	return Vector2i(int(site["x"]), int(site["y"]))


func _dungeon_tile(index: int) -> Vector2i:
	var slot: Dictionary = screen.world.encounters[index]
	return Vector2i(int(slot["x"]), int(slot["y"]))


## The hero set on [param tile]'s middle and its pane opened.
func _visit(tile: Vector2i) -> VisitPane:
	screen.player.position = Vector2i(tile.x * 32 + 16, tile.y * 32 + 16)
	screen.show_player(screen.player)
	var pane := screen.visit(tile)
	await _frames()
	return pane


## The pane's choice [param then] taken, as its button signals it.
func _answer(pane: VisitPane, then: String) -> void:
	pane.left.emit(then)
	await _frames(3)


func test_yes_enter_the_castle_opens_the_board_and_out_again_saves() -> void:
	var site := _castle_site(3)
	assert_gt(site, -1, "control: the red castle")
	var pane := await _visit(_site_tile(site))
	assert_not_null(pane, "the castle's pane")
	assert_eq(String(pane.place["kind"]), "castle")
	assert_true(TownStatus.visited(screen.world, site), "the castle marked visited (the city list's castles)")
	var journal := screen.player.journal.size()
	await _answer(pane, "enter")
	assert_eq(screen.opened, 1, "the board opened")
	assert_true(screen.on_board(), "the board holds the world")
	assert_true(screen.modal())
	assert_eq(int(screen.given["index"]), 3, "red's castle")
	assert_true(bool(screen.given["castle"]))
	assert_eq(int(screen.given["tries"]), 0, "the first attempt")
	assert_eq(screen.player.journal.size(), journal + 1)
	assert_eq(String(screen.player.journal[journal]["text"]), "Entered Dragon Mount (Red Castle)")
	assert_false(is_instance_valid(pane) and not pane.is_queued_for_deletion(), "the castle's pane gone")
	assert_eq(screen.saves, 1, "saved at the door going in (the owner's D2, part C)")
	var ticked := screen.player.monster_timer
	screen._process(1.0)
	assert_eq(screen.player.monster_timer, ticked, "the world waits under the board")
	screen._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(screen.saves, 1, "the window closed on the board saves nothing more: the door's save stands")
	(screen.board as FakeBoard).finished.emit({"beaten": false, "booted": false})
	await _frames(3)
	assert_false(screen.on_board(), "out again")
	assert_false(screen.modal(), "the world again")
	assert_eq(screen.saves, 2, "saved coming out, as 1997's walk did")
	assert_eq(screen.player.monster_timer & 0x1F, 0x1F, "the clock on to the next 32")
	assert_false(screen.news_shown(), "no news on Magician")
	assert_eq(DungeonDoors.entered(screen.world, 3), 1, "the attempt kept")


func test_well_no_saves_as_before_and_opens_no_board() -> void:
	var site := _castle_site(1)
	var pane := await _visit(_site_tile(site))
	await _answer(pane, "")
	assert_eq(screen.opened, 0, "no board")
	assert_eq(screen.saves, 1, "the place left: saved")
	assert_eq(DungeonDoors.entered(screen.world, 1), 0, "no attempt")


func test_the_doors_wait_without_the_board() -> void:
	screen.ready_board = false
	var site := _castle_site(2)
	var pane := await _visit(_site_tile(site))
	var journal := screen.player.journal.size()
	await _answer(pane, "enter")
	assert_eq(screen.opened, 0, "no board to open")
	assert_false(screen.on_board())
	assert_eq(screen.player.journal.size(), journal, "nothing written")
	assert_eq(DungeonDoors.entered(screen.world, 2), 0, "no attempt counted")
	assert_eq(screen.saves, 1, "the castle only left")
	assert_true(DungeonDoors.BOARD_READY, "part C's board is made: the seam's own refusal is what waits here")


func test_the_dungeon_s_enter_opens_the_board_and_it_moves() -> void:
	screen.world.encounters[8]["clues"] = WorldClues.RULES
	var old := _dungeon_tile(8)
	var pane := await _visit(old)
	assert_not_null(pane, "the dungeon's pane")
	assert_eq(String(pane.place["kind"]), "dungeon")
	await _answer(pane, "enter")
	assert_true(screen.on_board(), "the board")
	assert_false(bool(screen.given["castle"]))
	assert_eq(String(screen.player.journal[screen.player.journal.size() - 1]["text"]), "Explored Azar's Crypt")
	(screen.board as FakeBoard).finished.emit({})
	await _frames(3)
	assert_false(screen.on_board())
	assert_eq(screen.saves, 2, "the door, and coming out of a dungeon saves [ours, ruling D-3]")
	var now := _dungeon_tile(8)
	assert_ne(now, old, "the dungeon moved")
	assert_eq(screen.view.dungeons.size(), 1, "still drawn")
	assert_eq(Vector2i(int(screen.view.dungeons[0]["x"]), int(screen.view.dungeons[0]["y"])), now,
		"at its new tile, on the world")
	assert_eq(Vector2i(int(screen.hud.minimap.dungeons[0]["x"]), int(screen.hud.minimap.dungeons[0]["y"])), now,
		"and on the small map")


func test_on_wizard_the_retaliation_is_shown_after_the_save() -> void:
	await _open_world(3)
	var site := _castle_site(0)
	var pane := await _visit(_site_tile(site))
	await _answer(pane, "enter")
	assert_true(screen.on_board())
	(screen.board as FakeBoard).finished.emit({"beaten": false})
	await _frames(3)
	assert_eq(screen.saves, 2, "saved at the door and coming out")
	assert_true(screen.siege_at_save, "the save holds the siege")
	assert_true(screen.news_shown(), "the news flash over the world")
	var said := " ".join(screen._news.news["lines"]) if screen.news_shown() else ""
	assert_string_contains(said, "In retaliation for your effrontery the Great Black Wizard sends")


func test_a_game_over_on_the_board_is_the_end() -> void:
	var pane := await _visit(_site_tile(_castle_site(4)))
	await _answer(pane, "enter")
	(screen.board as FakeBoard).finished.emit({"game_over": true})
	await _frames(3)
	assert_true(screen.ended(), "the adventure's end")
	assert_eq(screen.saves, 1, "nothing saved after the door's")


func test_a_castle_s_tune_comes_to_full_voice() -> void:
	var site := _castle_site(0)
	var tile := _site_tile(site)
	screen.player.position = Vector2i(tile.x * 32 + 16, tile.y * 32 + 16)
	screen.show_player(screen.player)
	screen.soundscape.site = site
	screen.soundscape.level = 40
	screen.visit(tile)
	assert_eq(screen.soundscape.level, 100, "entered: its tune at full voice, as 1997's")
