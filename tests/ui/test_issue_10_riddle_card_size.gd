extends GutTest
## GitHub issue #10: the dungeon scroll's riddle answered, "Correct!" and its
## card — 96 points wide (120 at most), its rules text a few pixels high,
## unreadable at 1280 × 800 and at 2560 × 1440 alike (the window's logical
## size is 1280 × 800 and 1422 × 800 there; the stretch only scales it up).
## The box's card is now the Showcase's own as tall as the page leaves room
## for ([method DungeonPane._fit_box_card]), the creature meeting's riddle
## card half again its old width beside the face ([constant
## EncounterPane.RIDDLE_CARD_WIDE]); a left click reads either, as a right
## click did and does.

const SAVES := "user://adventure_tests_issue_10"


class Probe extends WorldScreen:
	func _board_seed() -> int:
		return 4242

	func _go_to_title() -> void:
		_leaving = true


var viewport: SubViewport
var screen: Probe
## The dungeon's riddle as it was asked (the board forgets it once answered).
var asked_riddle := {}


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


func _open_world(room: Vector2i, color: String, seed_text: String) -> void:
	if viewport != null and is_instance_valid(viewport):
		viewport.queue_free()
		await _frames()
	var setup := AdventureSetup.new()
	setup.player_name = "Inniscor"
	setup.color = color
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = seed_text
	viewport = SubViewport.new()
	viewport.size = room
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	screen = Probe.new()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.set_process(false)
	screen.player.food = 50
	screen.player.gold = 1000
	screen.player.monsters = [] as Array
	screen.player.monster_timer = 4   # not a special meeting
	screen.player.cards = []
	for i in 20:
		screen.player.cards.append({"card": "Forest" if i < 10 else "Grizzly Bears", "decks": [0]})
	screen.player.current_deck = 0


func _click(node: Control, button: MouseButton) -> void:
	var at := node.get_global_rect().get_center()
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = button
		click.pressed = pressed
		click.button_mask = (MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT \
			else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
		click.position = at
		click.global_position = at
		viewport.push_input(click, true)
	await _frames()


## The dungeon's riddle, answered right: the board's pane with its box up.
func _dungeon_riddle_answered() -> DungeonPane:
	screen.world.encounters[8]["clues"] = WorldClues.RULES | WorldClues.CREATURES
	screen._enter_board({"kind": "dungeon", "slot": 8})
	await _frames(3)
	var pane := screen._board as DungeonPane
	assert_not_null(pane, "the board's pane")
	if pane == null:
		return null
	if pane.step == "first":
		pane.choose("go")
		await _frames()
	var board := pane.board
	for way in [1, 3, 7, 5]:
		var to: Vector2i = board.hero + DungeonBoard.STEPS[way]
		if board.is_open(to) and to != DungeonBoard.ENTRANCE:
			board.cells[to.x * DungeonBoard.HEIGHT + to.y] = DungeonBoard.OPEN | DungeonBoard.SEEN \
				| (DungeonBoard.SCROLL << DungeonBoard.EVENT_SHIFT)
			pane.move(way)
			break
	assert_eq(pane.step, "riddle")
	var asked := pane.board.asked.duplicate()
	asked_riddle = asked
	for i in pane.answer_ids().size():
		if CardRiddle.correct(asked, i):
			pane.answer(i)
			break
	await _frames(3)
	return pane


func test_the_dungeon_riddle_s_card_is_the_showcase_s_size() -> void:
	# 1280 × 800, and 2560 × 1440's logical 1422 × 800.
	for room in [Vector2i(1280, 800), Vector2i(1422, 800)]:
		await _open_world(room, "green", "12345")
		var pane := await _dungeon_riddle_answered()
		if pane == null:
			return
		assert_string_contains(pane.box_words(), "Correct", "control: the right answer's verdict")
		var card := pane.find_child("BoxCard", true, false) as Control
		assert_not_null(card, "%s: the riddle's card in the box" % room)
		if card == null:
			return
		# Was 0.40 (120 of 300 points): two and a half times that at least.
		assert_gte(card.scale.x, 0.99, "%s: the Showcase's own size (%s)" % [room, card.scale])
		var page := pane.view.get_global_rect()
		assert_true(page.grow(0.5).encloses(card.get_global_rect()),
			"%s: the card on the page (%s in %s)" % [room, card.get_global_rect(), page])
		var box := pane.find_child("Box", true, false) as Control
		assert_true(page.grow(0.5).encloses(box.get_global_rect()), "%s: the box on the page" % room)


func test_a_small_window_shrinks_the_card_to_the_page_but_not_below_1997_s() -> void:
	await _open_world(Vector2i(800, 600), "green", "12345")
	var pane := await _dungeon_riddle_answered()
	if pane == null:
		return
	var card := pane.find_child("BoxCard", true, false) as Control
	assert_not_null(card)
	if card == null:
		return
	var page := pane.view.get_global_rect()
	assert_true(page.grow(0.5).encloses(card.get_global_rect()),
		"the card on the page (%s in %s)" % [card.get_global_rect(), page])
	assert_gt(card.scale.x, 96.0 * clampf(pane.page_factor(), 0.8, 1.25) / CardPreview.SIZE.x,
		"larger than the 96-point card it was")


func test_a_left_or_right_click_reads_the_box_s_card() -> void:
	await _open_world(Vector2i(1280, 800), "green", "12345")
	var pane := await _dungeon_riddle_answered()
	if pane == null:
		return
	var read: Array = []
	pane.card_read.connect(func(card_name: String) -> void: read.append(card_name))
	var card := pane.find_child("BoxCard", true, false) as Control
	var named := String(asked_riddle.get("card", ""))
	assert_ne(named, "", "control: the riddle names its card")
	# The answer's own click must not read the card that took its place.
	await _click(card, MOUSE_BUTTON_LEFT)
	assert_eq(read, [], "not within the read guard")
	pane._guard_until = 0
	await _click(card, MOUSE_BUTTON_LEFT)
	assert_eq(read, [named], "a left click reads it")
	assert_true(screen.reader.is_open(), "full screen")
	screen.reader.dismiss()
	await _frames()
	await _click(card, MOUSE_BUTTON_RIGHT)
	assert_eq(read, [named, named], "a right click still does")
	screen.reader.dismiss()
	await _frames()
	assert_eq(pane.step, "box", "and the box waits for Continue")


func _meeting_riddle_answered() -> EncounterPane:
	screen.player.log_victory(1, 1)
	screen.player.log_victory(1, 1)
	var at := screen.player.position + Vector2i(6, 0)
	screen.player.monsters.append({"slot": 0, "kind": "creature", "creature": 1, "x": at.x, "y": at.y,
		"color": 1, "heading": 0, "frame": 0})
	var pane := screen.meet_creature(0) as EncounterPane
	assert_not_null(pane, "the meeting's pane")
	if pane == null:
		return null
	await _frames()
	pane.choose("riddle")
	await _frames()
	assert_eq(pane.step, "riddle")
	var asked: Dictionary = pane.meeting.get("riddle", {})
	for i in (asked.get("answers", []) as Array).size():
		if CardRiddle.correct(asked, i):
			pane.answer(i)
			break
	await _frames(3)
	return pane


func test_the_meeting_riddle_s_card_is_larger_beside_the_face() -> void:
	await _open_world(Vector2i(1280, 800), "red", "2468")
	var pane := await _meeting_riddle_answered()
	if pane == null:
		return
	var card := pane.stage.part("RiddleCard") as Control
	assert_not_null(card, "the riddle's card on the page")
	if card == null:
		return
	var factor := pane.stage.factor
	# Was 150 of 1997's points wide.
	assert_gte(card.get_global_rect().size.x, 150.0 * factor * 1.35, "larger than it was")
	var page := pane.stage.get_global_rect()
	assert_true(page.grow(0.5).encloses(card.get_global_rect()), "on the page")
	var face := Rect2(pane.stage.get_global_rect().position + EncounterStage.FACE_AT.position * factor,
		EncounterStage.FACE_AT.size * factor)
	assert_false(face.intersects(card.get_global_rect()), "clear of the creature's face")
	var read: Array = []
	pane.card_read.connect(func(card_name: String) -> void: read.append(card_name))
	await _click(card, MOUSE_BUTTON_LEFT)
	var named := String((pane.meeting.get("riddle", {}) as Dictionary).get("card", ""))
	assert_eq(read, [named], "a left click reads it")
	screen.reader.dismiss()
	await _frames()
	await _click(card, MOUSE_BUTTON_RIGHT)
	assert_eq(read, [named, named], "a right click still does")
	screen.reader.dismiss()
	await _frames()
