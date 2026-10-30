extends GutTest
## THE BOARD'S TITLE (the owner's report of 2026-10-30, with a photo: "The
## positioning of title is not ok, fix!"): the castle's or the dungeon's
## name on the page's plaque stood centred on 1997's y 18 — where 1997 set
## its TOP (dE:1200) — half over the plaque's top border. Now, the owner's
## rulings of the same day: the name in the middle of the plaque's green
## field ("Bottom title should be in the middle"), with the next duel's
## line the two as one block there; and the pane's header says only what
## the place is ("Top title should just say Dungeon"; "And correct for all
## similar so titles are not duplicated!") — "Dungeon", "Red Castle" — at
## every window size and with Big buttons.

## A world screen whose board is drawn on a known seed, which saves nowhere
## and never leaves for the title.
class Probe extends WorldScreen:
	func _board_seed() -> int:
		return 4242

	func _write_autosave() -> String:
		return ""

	func _go_to_title() -> void:
		_leaving = true


const SAVES := "user://adventure_tests_c22_t2_title"
## The next duel's longest usual line: lives, a card, the first move.
const LINE := "+2 (14) Lives, Lord of the Pit, First Move"

var viewport: SubViewport
var screen: Probe


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	DungeonView.frame_seconds = 0.0
	TileReveal.forced = 0


func after_each() -> void:
	await _frames()
	DungeonView.frame_seconds = DungeonView.FRAME_SECONDS
	TileReveal.forced = -1
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


## A world in a window of [param room], Big buttons [param big].
func _world(room: Vector2i, big := false) -> void:
	if viewport != null and is_instance_valid(viewport):
		viewport.queue_free()
		await _frames()
	viewport = SubViewport.new()
	viewport.size = room
	add_child_autofree(viewport)
	var setup := AdventureSetup.new()
	setup.player_name = "Inniscor"
	setup.color = "green"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	screen = Probe.new()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.set_process(false)
	screen.hud.big = big
	screen.player.food = 50
	screen.player.monsters = [] as Array


func _castle_site(castle: int) -> int:
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == ShandalarWorld.CASTLE \
				and DungeonDoors.castle_of(screen.world, slot) == castle:
			return slot
	return -1


## Castle or dungeon [param index] entered by its door: the board's pane.
func _enter(index: int) -> DungeonPane:
	var place := {"kind": "castle", "slot": _castle_site(index)}
	if index >= DungeonDoors.CASTLES:
		screen.world.encounters[index]["clues"] = WorldClues.RULES | WorldClues.CREATURES
		place = {"kind": "dungeon", "slot": index}
	screen._enter_board(place)
	await _frames(3)
	var pane := screen._board as DungeonPane
	assert_not_null(pane, "the board's pane")
	if pane != null and pane.step == "first":
		pane.choose("go")
		await _frames()
	return pane


## Out of the board by its Leave.
func _leave(pane: DungeonPane) -> void:
	pane.ask_leave()
	pane.choose("leave")
	await _frames(3)


## The words over the page: the pane's labels above the picture.
func _header(pane: DungeonPane) -> Array[String]:
	var out: Array[String] = []
	for child in pane.find_child("Column", false, false).get_children():
		if String(child.name) == "Picture":
			break
		if child is Label and (child as Label).visible:
			out.append((child as Label).text)
	return out


## The name's letters stand in the field, their body (from their top to the
## baseline) in its middle, within a pixel either way.
func _assert_in_the_middle(view: DungeonView, why: String) -> void:
	var field := view.title_field()
	var letters := view.title_rect()
	assert_true(field.encloses(letters), "%s: the letters %s inside the green field %s" % [why, letters, field])
	var body_middle := (letters.position.y + view.baselines().x) / 2.0
	assert_almost_eq(body_middle, field.get_center().y, 1.0, "%s: in the middle, top to bottom" % why)
	assert_almost_eq(letters.get_center().x, field.get_center().x, 1.0, "%s: in the middle, side to side" % why)


# ----------------------------------------------------------- the header --

func test_the_header_says_only_what_the_place_is_and_the_plaque_names_it() -> void:
	await _world(Vector2i(1280, 800))
	for index in [5, 7, 0, 1, 2, 3, 4]:
		var pane := await _enter(index)
		if pane == null:
			return
		var kind: String = WorldNames.CASTLES[index] if index < DungeonDoors.CASTLES else "Dungeon"
		var place_name := WorldNames.dungeon_name(index)
		assert_eq(_header(pane), [kind] as Array[String], "%s: the header says what it is, once" % place_name)
		assert_eq(pane.view.title_text, place_name, "the plaque names it")
		assert_false(place_name in _header(pane), "%s is not named twice" % place_name)
		await _leave(pane)


# ------------------------------------------------------------ the plaque --

func test_the_name_stands_in_the_middle_of_the_green_field_at_every_size() -> void:
	for room in [Vector2i(800, 600), Vector2i(1280, 800), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		for big in [false, true]:
			await _world(room, big)
			var pane := await _enter(5)
			if pane == null:
				return
			var why := "%s, Big buttons %s, the page at %.2f" % [room, big, pane.page_factor()]
			assert_eq(_header(pane), ["Dungeon"] as Array[String], why)
			_assert_in_the_middle(pane.view, why)
			# The page shown at the pane's size: the field on the screen too.
			var shown := Rect2(pane.view.title_rect().position * pane.page_factor(),
				pane.view.title_rect().size * pane.page_factor())
			var field := Rect2(pane.view.title_field().position * pane.page_factor(),
				pane.view.title_field().size * pane.page_factor())
			assert_true(field.encloses(shown), "%s: on the screen too" % why)
			pane.board.dice_lives = 2
			pane.board.dice_card = "Lord of the Pit"
			pane._refresh()
			assert_ne(pane.view.gift_line, "", "the next duel's line shows")
			assert_true(field.encloses(Rect2(pane.view.title_rect().position * pane.page_factor(),
				pane.view.title_rect().size * pane.page_factor())), "%s: with the line too" % why)
			await _leave(pane)


func test_every_name_and_the_next_duel_s_line_fit_the_field() -> void:
	var view := DungeonView.new()
	add_child_autofree(view)
	for place_name in WorldNames.DUNGEONS:
		view.title_text = place_name
		view.gift_line = ""
		_assert_in_the_middle(view, place_name)
		view.gift_line = LINE
		var field := view.title_field()
		var letters := view.title_rect()
		var line := view.gift_rect()
		assert_true(field.encloses(letters), "%s: the name in the field above the line" % place_name)
		assert_true(line.position.y >= field.position.y and line.end.y <= field.end.y,
			"%s: the line %s in the field %s, top to bottom" % [place_name, line, field])
		assert_true(letters.end.y < line.position.y, "%s: the name and the line apart" % place_name)
		var block_middle := (letters.position.y + line.end.y) / 2.0
		assert_almost_eq(block_middle, field.get_center().y, 1.0,
			"%s: the two as one block in the middle" % place_name)


func test_the_plaque_grows_round_the_longest_name() -> void:
	var view := DungeonView.new()
	add_child_autofree(view)
	var longest := ""
	var widest := 0.0
	for place_name in WorldNames.DUNGEONS:
		view.title_text = place_name
		if view.title_rect().size.x > widest:
			widest = view.title_rect().size.x
			longest = place_name
	assert_eq(longest, "Mound of the Warrior Kings", "the widest name on a plaque")
	view.title_text = longest
	var field := view.title_field()
	assert_true(field.size.x - widest >= 24.0, "1997's rule: 29 + 24n at least the name's width leaves 12 a side")
	assert_true(field.position.x > 0.0 and field.end.x < DungeonView.PAGE.x, "on the page, one line")
