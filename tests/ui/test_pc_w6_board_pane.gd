extends GutTest
## INSIDE A CASTLE OR A DUNGEON, THROUGH THE WORLD SCREEN (part C, stage C2,
## W6): the doors open ([constant DungeonDoors.BOARD_READY]), the adventure
## saved at the door (the owner's D2), the board's pane ([DungeonPane]) over
## the world holding it, the moves (keys, clicks, a corridor), "Leave?", the
## events — the dice, the riddle, a card found and the full bag's swap, gold
## —, a room's duel held over the world and settled once (won, drawn, lost
## with "Lost this card" and the booted words once), the castle's wizard
## beaten ([method CastleWin.beat] before any save, [CastleWinPane], the
## fifth handed to the finale), nothing to stake, the pane's size, and
## "Return to main menu" mid-duel saving nothing.

const SAVES := "user://adventure_tests_pc_w6_board"


## A world screen whose board is drawn on a known seed, which counts its
## saves, its leaving and the finale's hand-off.
class Probe extends WorldScreen:
	var saves := 0
	var titles := 0
	var finales := 0
	var wins_at_save: Array = []

	func _board_seed() -> int:
		return 4242

	func _write_autosave() -> String:
		saves += 1
		wins_at_save.append(player.defeated_wizards.duplicate())
		return super()

	func _go_to_title() -> void:
		titles += 1
		_leaving = true

	func _after_fifth_wizard() -> void:
		finales += 1


var viewport: SubViewport
var screen: Probe
var results: Array = []


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	DungeonView.frame_seconds = 0.0
	TileReveal.forced = 0
	await _open_world(Vector2i(1280, 800))


func after_each() -> void:
	# What the last step put away is freed with the frame.
	await _frames()
	DungeonView.frame_seconds = DungeonView.FRAME_SECONDS
	TileReveal.forced = -1
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _open_world(room: Vector2i, difficulty := 1) -> void:
	if viewport != null and is_instance_valid(viewport):
		viewport.queue_free()
		await _frames()
	var setup := AdventureSetup.new()
	setup.player_name = "Inniscor"
	setup.color = "green"
	setup.difficulty = difficulty
	setup.walker = "male"
	setup.seed_text = "12345"
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
	screen.player.monsters = [] as Array
	_deck()
	screen.saves = 0
	results = []


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


## A deck in use of 10 Forests, 6 Giant Growth and 4 Grizzly Bears.
func _deck() -> void:
	var cards: Array = []
	for i in 10:
		cards.append("Forest")
	for i in 6:
		cards.append("Giant Growth")
	for i in 4:
		cards.append("Grizzly Bears")
	screen.player.cards = []
	for card_name in cards:
		screen.player.cards.append({"card": String(card_name), "decks": [0]})
	screen.player.current_deck = 0


## The castle site of colour [param castle] (0 black … 4 white).
func _castle_site(castle: int) -> int:
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == ShandalarWorld.CASTLE \
				and DungeonDoors.castle_of(screen.world, slot) == castle:
			return slot
	return -1


## Castle or dungeon [param index] entered by its door: the board's pane.
func _enter(index: int) -> DungeonPane:
	var place := {}
	if index < DungeonDoors.CASTLES:
		place = {"kind": "castle", "slot": _castle_site(index)}
	else:
		screen.world.encounters[index]["clues"] = WorldClues.RULES | WorldClues.CREATURES
		place = {"kind": "dungeon", "slot": index}
	screen._enter_board(place)
	await _frames(3)
	var pane := screen._board as DungeonPane
	assert_not_null(pane, "the board's pane")
	if pane != null:
		pane.finished.connect(func(result: Dictionary) -> void: results.append(result))
		if pane.step == "first":
			pane.choose("go")
			await _frames()
	return pane


## The way to an open neighbour of the hero, made into event [param event]
## (seen); 0 for none.
func _plant(pane: DungeonPane, event: int) -> int:
	var board := pane.board
	for way in [1, 3, 7, 5]:
		var to: Vector2i = board.hero + DungeonBoard.STEPS[way]
		if board.is_open(to) and to != DungeonBoard.ENTRANCE:
			board.cells[to.x * DungeonBoard.HEIGHT + to.y] = DungeonBoard.OPEN | DungeonBoard.SEEN \
				| (event << DungeonBoard.EVENT_SHIFT)
			return way
	return 0


## An open neighbour's way, no event in it; 0 for none.
func _free_way(pane: DungeonPane) -> int:
	for way in [1, 3, 7, 5]:
		var to: Vector2i = pane.board.hero + DungeonBoard.STEPS[way]
		if pane.board.is_open(to) and pane.board.event_at(to) == 0 and to != DungeonBoard.ENTRANCE:
			return way
	return 0


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = keycode
		key.physical_keycode = keycode
		key.pressed = pressed
		viewport.push_input(key, true)
	await _frames()


## A duel's report: the hero [param result] (1 won, 0 lost, −1 drawn).
func _report(result: int) -> DuelReport:
	var report := DuelReport.new()
	report.finished = result != DuelReport.DRAW
	report.result = result
	report.winner = 0 if result == DuelReport.WIN else (1 if result == DuelReport.LOSS else -1)
	var start: Array[int] = [12, 20]
	var end: Array[int] = [9, 0]
	if result != DuelReport.WIN:
		end = [0, 7] as Array[int]
	report.lives_start = start
	report.lives_end = end
	return report


## A room's duel: the room's pane's Duel, then the duel ended with
## [param result].
func _duel(pane: DungeonPane, result: int) -> void:
	var over := pane.over_pane()
	assert_true(over is RoomDuelPane, "what is at stake, before the duel")
	if over == null:
		return
	assert_false(pane.visible, "the board waits hidden")
	over.emit_signal("chosen", RoomDuelPane.DUEL)
	await _frames(3)
	var host := pane.duel_host()
	assert_not_null(host, "the duel over the world")
	if host == null:
		return
	assert_eq(pane.step, "duel")
	assert_false(pane.sound.bed_playing(), "the bed paused for the duel")
	host._finish(_report(result))
	await _frames(3)


# ------------------------------------------------------------- the doors --

func test_the_doors_open_onto_the_board() -> void:
	assert_true(DungeonDoors.BOARD_READY, "part C's board is made")
	var castle := VisitPane.describe(screen.player, Vector2i(int(screen.world.sites[_castle_site(2)]["x"]),
		int(screen.world.sites[_castle_site(2)]["y"])))
	var enter: Array = (castle["actions"] as Array).filter(func(a: Array) -> bool: return a[0] == "enter")
	assert_true(bool(enter[0][2]), "Yes, enter the castle. is alive")


func test_going_in_saves_at_the_door_and_the_board_holds_the_world() -> void:
	var pane := await _enter(8)
	assert_eq(screen.saves, 1, "saved at the door (the owner's D2)")
	assert_true(screen.on_board())
	assert_true(screen.modal())
	assert_eq(pane.step, "idle")
	assert_eq(pane.choice_ids(), ["leave"] as Array[String], "Leave always there")
	var ticked := screen.player.monster_timer
	screen._process(1.0)
	assert_eq(screen.player.monster_timer, ticked, "the world waits under the board")
	screen._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(screen.saves, 1, "the window closed inside saves nothing: the door's save stands")
	assert_eq(pane.board.title(), WorldNames.dungeon_name(8))
	assert_eq(pane.view.board, pane.board)
	assert_string_contains(pane.view.status_left, "Life in the next duel: ")
	assert_string_contains(pane.view.status_right, "Rooms left: ")


func test_the_keys_walk_and_never_reach_the_world() -> void:
	var pane := await _enter(8)
	var way := _free_way(pane)
	assert_ne(way, 0, "control: a free neighbour")
	var keys := {1: KEY_HOME, 3: KEY_PAGEUP, 5: KEY_PAGEDOWN, 7: KEY_END}
	var from := pane.board.hero
	await _key(keys[way])
	assert_eq(pane.board.hero, from + DungeonBoard.STEPS[way], "1997's key moved the hero")
	assert_eq(pane.step, "idle", "the walk over (no frame time)")
	var camera: Vector2 = screen.view.camera
	await _key(KEY_M)
	assert_false(screen._map.visible, "the world's keys are not heard under the board")
	assert_eq(screen.view.camera, camera)


func test_a_click_steps_and_a_corridor_click_walks() -> void:
	var pane := await _enter(8)
	var board := pane.board
	# The farthest seen open cell in a straight line from the hero, no event.
	var target := board.hero
	var steps := 0
	for way in [1, 3, 7]:
		var at: Vector2i = board.hero
		var count := 0
		while true:
			var next: Vector2i = at + DungeonBoard.STEPS[way]
			if not board.is_open(next) or not board.seen(next) or board.event_at(next) != 0:
				break
			at = next
			count += 1
		if count > steps:
			steps = count
			target = at
	assert_gt(steps, 0, "control: a corridor seen from the start")
	pane._clicked(Vector2(DungeonBoard.cell_to_page(target)), MOUSE_BUTTON_LEFT)
	await _frames()
	assert_eq(board.hero, target, "walked along the corridor")
	assert_eq(pane.step, "idle")


func test_leaving_asks_first_and_stay_stays() -> void:
	var pane := await _enter(8)
	await _key(KEY_ESCAPE)
	assert_eq(pane.step, "leave", "Escape asks")
	assert_string_contains(pane.box_words(), "Leave %s?" % WorldNames.dungeon_name(8))
	assert_string_contains(pane.box_words(), DungeonPane.LEAVE_MOVES)
	assert_eq(pane.choice_ids(), ["stay", "leave"] as Array[String])
	await _key(KEY_ESCAPE)
	assert_eq(pane.step, "idle", "Escape again stays")
	assert_true(screen.on_board())
	pane._clicked(Vector2(DungeonBoard.cell_to_page(DungeonBoard.ENTRANCE)), MOUSE_BUTTON_LEFT)
	assert_eq(pane.step, "leave", "a click on the exit asks too")
	pane.choose("leave")
	await _frames(3)
	assert_eq(results.size(), 1, "finished once")
	assert_false(screen.on_board(), "the world again")
	assert_eq(screen.saves, 2, "saved at the door and coming out")


func test_stepping_onto_the_exit_asks() -> void:
	var pane := await _enter(8)
	pane.move(DungeonBoard.DOWN_RIGHT)
	assert_eq(pane.step, "leave", "the entrance below the start: Leave?")
	assert_eq(pane.board.hero, DungeonBoard.START, "the hero still inside")


func test_the_dice() -> void:
	var pane := await _enter(8)
	var way := _plant(pane, DungeonBoard.DICE)
	var cell: Vector2i = pane.board.hero + DungeonBoard.STEPS[way]
	pane.move(way)
	assert_eq(pane.step, "box")
	assert_string_contains(pane.box_words(), "You get ")
	assert_string_contains(pane.box_words(), "in the next duel!")
	assert_eq(pane.board.hero, cell, "the dice passed: the hero's cell")
	pane.choose("go")
	await _frames()
	assert_eq(pane.step, "idle", "walked in")
	assert_eq(pane.board.value(cell), DungeonBoard.PASSED)
	assert_eq(pane.view.gift_line, pane.board.next_duel_line(screen.player), "1997's line under the title")


func test_the_riddle_waits_and_a_wrong_answer_summons() -> void:
	var pane := await _enter(8)
	var start := pane.board.hero
	var way := _plant(pane, DungeonBoard.SCROLL)
	var cell: Vector2i = start + DungeonBoard.STEPS[way]
	pane.move(way)
	assert_eq(pane.step, "riddle")
	var answers := pane.answer_ids()
	assert_gt(answers.size(), 1, "the answers in the box")
	await _key(KEY_ESCAPE)
	assert_eq(pane.step, "riddle", "Escape waits for an answer [ours]")
	var asked := pane.board.asked.duplicate()
	var wrong := -1
	for i in answers.size():
		if not CardRiddle.correct(asked, i):
			wrong = i
			break
	pane.answer(wrong)
	assert_eq(pane.step, "box")
	assert_string_contains(pane.box_words(), "WRONG")
	pane.choose("go")
	await _frames()
	assert_eq(pane.board.hero, start, "the hero stepped back")
	assert_eq(pane.board.event_at(cell), DungeonBoard.SUMMONED >> DungeonBoard.EVENT_SHIFT, "the creature summoned")
	assert_eq(String(pane.view.cell_look(cell).get("stands", "")), "creature", "and seen at once")


func test_a_card_found() -> void:
	var pane := await _enter(8)
	var slot: Dictionary = screen.world.encounters[8]
	var held := (slot.get("cards", []) as Array).size()
	assert_gt(held, 0, "control: the dungeon holds cards")
	var owned := screen.player.cards.size()
	pane.move(_plant(pane, DungeonBoard.TREASURE))
	var page := pane.view.page()
	assert_not_null(page, "the treasure's page over the board")
	assert_eq(page.ground_key(), "dungeon_treasure")
	assert_eq(page.cards_shown().size(), 1, "the card found")
	assert_eq(screen.player.cards.size(), owned + 1, "in the bag")
	assert_eq((slot.get("cards", []) as Array).size(), held - 1, "out of the dungeon")
	pane.choose("go")
	await _frames()
	assert_null(pane.view.page(), "the board again")
	assert_eq(pane.step, "idle")


func test_a_full_bag_swaps_through_the_builder() -> void:
	var pane := await _enter(8)
	while screen.player.cards.size() < AdventurePlayer.BAG_MOST:
		screen.player.cards.append({"card": "Swamp", "decks": []})
	var slot: Dictionary = screen.world.encounters[8]
	var held := (slot.get("cards", []) as Array).size()
	pane.move(_plant(pane, DungeonBoard.TREASURE))
	assert_eq(pane.step, "swap_ask", "the full bag asks")
	assert_eq(pane.choice_ids(), ["swap", "keep"] as Array[String])
	var found := pane._found
	pane.choose("swap")
	await _frames(3)
	var builder := pane._builder as TreasureSwapBuilder
	assert_not_null(builder, "the deck builder over the world")
	assert_false(pane.visible)
	assert_false(builder.leave("Swamp"), "asked once")
	assert_true(builder.leave("Swamp"), "left the second time")
	await _frames(3)
	assert_true(pane.visible)
	assert_string_contains(pane.box_words(), "Swamp stays here in its place.")
	var names: Array = screen.player.cards.map(func(c: Dictionary) -> String: return String(c["card"]))
	assert_true(found in names, "the card found is the hero's")
	assert_eq(screen.player.cards.size(), AdventurePlayer.BAG_MOST, "one for one")
	assert_eq((slot.get("cards", []) as Array).size(), held - 1)
	assert_true(WorldClues.left_cards(slot).has("Swamp"), "the card left stays as the dungeon's treasure")


func test_a_full_bag_declined_leaves_the_card_in_the_dungeon() -> void:
	var pane := await _enter(8)
	while screen.player.cards.size() < AdventurePlayer.BAG_MOST:
		screen.player.cards.append({"card": "Swamp", "decks": []})
	var slot: Dictionary = screen.world.encounters[8]
	var held := (slot.get("cards", []) as Array).size()
	pane.move(_plant(pane, DungeonBoard.TREASURE))
	pane.choose("keep")
	assert_string_contains(pane.box_words(), "stays in the dungeon")
	assert_eq((slot.get("cards", []) as Array).size(), held, "still the dungeon's")
	pane.choose("go")
	await _frames()
	assert_eq(pane.step, "idle")


func test_gold_in_a_castle() -> void:
	var pane := await _enter(3)
	var gold := screen.player.gold
	pane.move(_plant(pane, DungeonBoard.TREASURE))
	assert_string_contains(pane.box_words(), "Found ")
	assert_string_contains(pane.box_words(), " Gold")
	assert_gt(screen.player.gold, gold)


# ------------------------------------------------------------- the duels --

func test_a_room_won_is_settled_once_and_the_hero_walks_in() -> void:
	var pane := await _enter(8)
	var way := _plant(pane, 3)
	var cell: Vector2i = pane.board.hero + DungeonBoard.STEPS[way]
	pane.move(way)
	assert_eq(pane.step, "room")
	await _duel(pane, DuelReport.WIN)
	assert_true(pane.visible, "the board again")
	assert_eq(pane.board.hero, cell, "walked into the room cleared")
	assert_eq(pane.board.value(cell), DungeonBoard.PASSED)
	assert_eq(pane.board.life_pool, -3, "the dungeon carries the duel's change (12 → 9), once")
	assert_true(pane._duel_setup.has("settled"), "settled")
	assert_string_contains(pane.view.said(), "Defeated ")
	assert_true(String(screen.player.journal[-1]["text"]).begins_with("Defeated "))
	assert_eq(pane.step, "idle")


func test_a_room_drawn_changes_nothing() -> void:
	var pane := await _enter(8)
	var start := pane.board.hero
	var way := _plant(pane, 3)
	var cell: Vector2i = start + DungeonBoard.STEPS[way]
	var journal := screen.player.journal.size()
	pane.move(way)
	await _duel(pane, DuelReport.DRAW)
	assert_eq(pane.board.hero, start, "pushed back")
	assert_true(DungeonBoard.is_room(pane.board.event_at(cell)), "the creature still waits")
	assert_eq(pane.board.life_pool, 0, "the pool untouched")
	assert_eq(screen.player.journal.size(), journal, "nothing written")
	assert_string_contains(pane.view.said(), "A draw")


func test_a_castle_room_lost_shows_the_card_and_the_booted_words_once() -> void:
	var pane := await _enter(1)
	var owned := screen.player.cards.size()
	pane.move(_plant(pane, 3))
	await _duel(pane, DuelReport.LOSS)
	assert_eq(pane.step, "lost")
	assert_eq(pane.view.page().ground_key(), "lose_card")
	assert_eq(pane.view.page().cards_shown().size(), 1, "the card staked")
	assert_eq(screen.player.cards.size(), owned - 1, "lost")
	pane.choose("go")
	await _frames()
	assert_eq(pane.step, "booted")
	assert_string_contains(pane.box_words(), "You are unceremoniously booted from")
	assert_string_contains(pane.box_words(), "Blue Wizardess")
	pane.choose("go")
	await _frames(3)
	assert_eq(results.size(), 1)
	assert_true(bool(results[0]["booted"]))
	assert_false(screen.on_board())


func test_the_castle_s_fifth_wizard_beaten_hands_over_after_the_save() -> void:
	screen.player.defeated_wizards = ["blue", "green", "red", "white"] as Array[String]
	var pane := await _enter(0)
	pane.move(_plant(pane, DungeonBoard.WIZARD))
	await _duel(pane, DuelReport.WIN)
	assert_true(pane.over_pane() is CastleWinPane, "his pane over the world")
	assert_true("black" in screen.player.defeated_wizards, "CastleWin.beat at once")
	assert_eq(screen.saves, 1, "and before any save but the door's")
	assert_eq(screen.wins_at_save[0].size(), 4, "the door's save before the win")
	assert_eq(pane._record.get("all_five"), true)
	pane.over_pane().emit_signal("finished", [] as Array[String])
	await _frames(4)
	assert_eq(results.size(), 1)
	assert_true(bool(results[0]["beaten"]))
	assert_true(bool(results[0]["all_five"]))
	assert_eq(screen.saves, 2, "saved coming out, the win in it")
	assert_true("black" in screen.wins_at_save[1])
	assert_eq(screen.finales, 1, "the finale after the save")


func test_nothing_to_stake_is_the_game_over() -> void:
	var pane := await _enter(8)
	for entry in screen.player.cards:
		entry["card"] = "Forest"
	pane.move(_plant(pane, 3))
	await _frames(3)
	assert_eq(results.size(), 1)
	assert_true(bool(results[0]["game_over"]))
	assert_true(screen.ended(), "the adventure's end")
	assert_eq(screen.saves, 1, "the door's save only")


func test_return_to_main_menu_mid_duel_saves_nothing() -> void:
	var pane := await _enter(8)
	pane.move(_plant(pane, 3))
	pane.over_pane().emit_signal("chosen", RoomDuelPane.DUEL)
	await _frames(3)
	pane.duel_host()._to_menu()
	await _frames(2)
	assert_eq(screen.titles, 1, "to the title")
	assert_eq(screen.saves, 1, "nothing saved after the door's")
	assert_true(results.is_empty(), "the board not finished")


# --------------------------------------------------------------- the size --

func test_the_pane_fits_and_never_swells() -> void:
	for room in [Vector2i(1280, 800), Vector2i(800, 600)]:
		for big in [false, true]:
			await _open_world(room)
			screen.hud.big = big
			var pane := await _enter(8)
			await _frames(4)
			var area := Rect2(Vector2.ZERO, Vector2(room))
			assert_true(area.encloses(pane.get_rect()), "%s big %s: the pane on the screen (%s)" % [room, big, pane.get_rect()])
			assert_lte(pane.page_factor(), DungeonPane.MOST)
			var size := pane.size
			for i in 20:
				var way := _free_way(pane)
				if way == 0:
					break
				pane.move(way)
			await _frames(3)
			assert_eq(pane.size, size, "%s big %s: the same size after walking" % [room, big])
			pane.move(_plant(pane, DungeonBoard.DICE))
			await _frames(3)
			assert_eq(pane.size, size, "%s big %s: a box stands over the page" % [room, big])


# --------------------------------------------------------- the mouse --

func test_a_real_click_is_read_through_the_page_s_size() -> void:
	var pane := await _enter(8)
	await _frames(3)
	var way := _free_way(pane)
	var target: Vector2i = pane.board.hero + DungeonBoard.STEPS[way]
	var at := pane.view.get_global_transform_with_canvas() \
		* (Vector2(DungeonBoard.cell_to_page(target)) * pane.page_factor())
	assert_ne(pane.page_factor(), 1.0, "control: the page is not at 1997's size")
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.position = at
		click.global_position = at
		viewport.push_input(click, true)
	await _frames()
	assert_eq(pane.board.hero, target, "the neighbour clicked: one step")


func test_a_creature_s_name_on_hover() -> void:
	var pane := await _enter(8)
	var way := _plant(pane, 3)
	var cell: Vector2i = pane.board.hero + DungeonBoard.STEPS[way]
	pane._pointed(pane.view.figure_rect(cell).get_center())
	assert_eq(pane.view.hover, cell)
	assert_eq(pane.view.hover_text, CreatureBook.name_of(pane.board.room_creature(3)))
	pane._pointed(Vector2(-1000, -1000))
	assert_eq(pane.view.hover, DungeonView.NOWHERE, "gone as the pointer leaves")


func test_the_first_view_shows_the_card_in_effect_and_any_key_goes_on() -> void:
	screen.world.encounters[3]["card_in_effect"] = WorldClues.EFFECT_CARDS.keys()[0]
	screen._enter_board({"kind": "castle", "slot": _castle_site(3)})
	await _frames(3)
	var pane := screen._board as DungeonPane
	assert_eq(pane.step, "first")
	assert_eq(pane.view.effect_card, String(WorldClues.EFFECT_CARDS.values()[0]))
	assert_eq(pane.choice_ids(), ["go"] as Array[String])
	var from := pane.board.hero
	await _key(KEY_UP)
	assert_eq(pane.step, "idle", "a key goes on, as 1997's")
	assert_eq(pane.board.hero, from, "and is no step")
	assert_eq(pane.view.effect_card, "")
