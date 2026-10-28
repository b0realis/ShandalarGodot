extends GutTest
## THE BOARD'S FIXES OF PART C STAGE C3 (G1), through the world screen:
## a double click's second press on the page is no click, and a click puts a
## box away only once it has been up a moment (h1-1); "Return to main menu"
## after a room duel that is over shows its result, ends the visit, saves
## and goes to the title — the question saying so, and the fifth wizard's
## win not handed to the finale on the way (h1-2 = h2-1); a second held
## direction turns the hero after the step, and the first, still held,
## walks on when it is let go (h1-3); "Leave?" for a dungeon with no card
## left says it will be gone (h1-4); a double click on the swap's "Leave it
## here" never skips "Press again" (h5-1).

const SAVES := "user://adventure_tests_c13_G1_board"


## A world screen whose board is drawn on a known seed, which counts its
## saves, its leaving and the finale's hand-off.
class Probe extends WorldScreen:
	var saves := 0
	var titles := 0
	var finales := 0

	func _board_seed() -> int:
		return 4242

	func _write_autosave() -> String:
		saves += 1
		return super()

	func _go_to_title() -> void:
		titles += 1
		_leaving = true

	func _after_fifth_wizard() -> void:
		finales += 1


var viewport: SubViewport
var screen: Probe
var results: Array = []
var _keys_down: Array[Key] = []


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	DungeonView.frame_seconds = 0.0
	TileReveal.forced = 0
	var setup := AdventureSetup.new()
	setup.player_name = "Inniscor"
	setup.color = "green"
	setup.difficulty = 1
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
	screen.saves = 0
	results = []


func after_each() -> void:
	for code in _keys_down.duplicate():
		await _hold(code, false)
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


func _castle_site(castle: int) -> int:
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == ShandalarWorld.CASTLE \
				and DungeonDoors.castle_of(screen.world, slot) == castle:
			return slot
	return -1


## Castle or dungeon [param index] entered by its door: the board's pane;
## the first view put away when [param go_first].
func _enter(index: int, go_first := true) -> DungeonPane:
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
		if go_first and pane.step == "first":
			pane.choose("go")
			await _frames()
	return pane


func _cell(at: Vector2i) -> int:
	return at.x * DungeonBoard.HEIGHT + at.y


## Cell [param at] open and seen, with [param event] in it.
func _open_cell(pane: DungeonPane, at: Vector2i, event := 0) -> void:
	pane.board.cells[_cell(at)] = DungeonBoard.OPEN | DungeonBoard.SEEN | (event << DungeonBoard.EVENT_SHIFT)
	pane.view.redraw()


## The way to an open neighbour of the hero, made into [param event]; 0 none.
func _plant(pane: DungeonPane, event: int) -> int:
	for way in [1, 3, 7, 5]:
		var to: Vector2i = pane.board.hero + DungeonBoard.STEPS[way]
		if pane.board.is_open(to) and to != DungeonBoard.ENTRANCE:
			_open_cell(pane, to, event)
			return way
	return 0


## A press (and its release) of the left button at the page point
## [param page_point] of [param pane]'s page; [param double] marks the press
## as a double click's second.
func _click_page(pane: DungeonPane, page_point: Vector2, double := false) -> void:
	var at := pane.view.get_global_transform_with_canvas() * (page_point * pane.page_factor())
	await _click_at(at, double)


func _click_at(at: Vector2, double := false) -> void:
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.double_click = double and pressed
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.position = at
		click.global_position = at
		viewport.push_input(click, true)
	await _frames()


## Key [param code] down or up — for the OS ([method Input.is_key_pressed],
## which the held walk reads) and for the board's pane.
func _hold(code: Key, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = pressed
	Input.parse_input_event(key)
	viewport.push_input(key.duplicate(), true)
	if pressed and not _keys_down.has(code):
		_keys_down.append(code)
	elif not pressed:
		_keys_down.erase(code)
	await _frames()


## A room's duel begun over the world: its host.
func _duel_begun(pane: DungeonPane) -> WorldDuels:
	var over := pane.over_pane()
	assert_true(over is RoomDuelPane, "what is at stake")
	if over == null:
		return null
	over.emit_signal("chosen", RoomDuelPane.DUEL)
	await _frames(3)
	var host := pane.duel_host()
	assert_not_null(host, "the duel over the world")
	return host


# ------------------------------------------------- h1-1: the double click --

func test_a_double_click_s_second_press_on_the_page_is_no_click() -> void:
	var pane := await _enter(8)
	var way := _plant(pane, DungeonBoard.DICE)
	var cell: Vector2i = pane.board.hero + DungeonBoard.STEPS[way]
	var at := Vector2(DungeonBoard.cell_to_page(cell))
	await _click_page(pane, at)
	assert_eq(pane.step, "box", "the first press stepped onto the dice: its box")
	await _click_page(pane, at, true)
	assert_eq(pane.step, "box", "the second press of the double click put nothing away")
	assert_string_contains(pane.box_words(), "You get ")


func test_a_double_click_s_second_press_steps_no_one() -> void:
	var pane := await _enter(8)
	var from := pane.board.hero
	var to := from + DungeonBoard.STEPS[DungeonBoard.UP_LEFT]
	_open_cell(pane, to)
	await _click_page(pane, Vector2(DungeonBoard.cell_to_page(to)), true)
	assert_eq(pane.board.hero, from, "a double click's second press alone is no step")
	await _click_page(pane, Vector2(DungeonBoard.cell_to_page(to)))
	assert_eq(pane.board.hero, to, "control: a click of its own steps")


func test_a_double_click_s_second_press_keeps_the_card_in_effect() -> void:
	screen.world.encounters[3]["card_in_effect"] = WorldClues.EFFECT_CARDS.keys()[0]
	var pane := await _enter(3, false)
	assert_eq(pane.step, "first", "control: the first view with its card")
	await _frames(3)
	var card := pane.view.find_child("EffectCard", true, false) as Control
	assert_not_null(card, "the card in effect on the page")
	if card == null:
		return
	await _click_at(card.get_global_rect().get_center(), true)
	assert_eq(pane.step, "first", "the second press of the Enter's double click leaves it up")
	await get_tree().create_timer(0.45).timeout
	await _click_at(card.get_global_rect().get_center())
	assert_eq(pane.step, "idle", "control: a click of its own goes on")


func test_a_click_in_the_moment_a_box_came_puts_nothing_away() -> void:
	var pane := await _enter(8)
	pane.move(_plant(pane, DungeonBoard.DICE))
	assert_eq(pane.step, "box")
	pane._clicked(Vector2(320, 240), MOUSE_BUTTON_LEFT)
	assert_eq(pane.step, "box", "a quick second click the desktop did not call double")
	await get_tree().create_timer(0.45).timeout
	pane._clicked(Vector2(320, 240), MOUSE_BUTTON_LEFT)
	await _frames()
	assert_eq(pane.step, "idle", "a moment later the click goes on")


func test_the_card_found_s_page_stays_while_it_comes_in() -> void:
	TileReveal.forced = 1
	var pane := await _enter(8)
	pane.move(_plant(pane, DungeonBoard.TREASURE))
	assert_not_null(pane.view.page(), "the card found's page")
	await get_tree().create_timer(0.4).timeout
	pane._clicked(Vector2(320, 240), MOUSE_BUTTON_LEFT)
	assert_not_null(pane.view.page(), "still coming in: a click puts it not away")
	await get_tree().create_timer(0.4).timeout
	pane._clicked(Vector2(320, 240), MOUSE_BUTTON_LEFT)
	await _frames()
	assert_null(pane.view.page(), "come in, a click goes on")


# ------------------------------- h1-2: Return to main menu once it is over --

func test_the_menu_after_a_won_room_shows_it_then_saves_and_leaves() -> void:
	var pane := await _enter(8)
	var way := _plant(pane, 3)
	var cell: Vector2i = pane.board.hero + DungeonBoard.STEPS[way]
	pane.move(way)
	var host := await _duel_begun(pane)
	if host == null:
		return
	var title := pane.board.title()
	assert_string_contains(host.duel.menu_question, "unfinished", "mid-duel: nothing saved")
	# Over, the hero the winner, the End of Duel window not yet closed (a
	# headless duel closes at once as it ends: the verdict's signal by hand).
	host.duel.game.winner = 0
	host.duel.game.game_over = true
	host.duel.duel_finished.emit(0)
	assert_eq(host.duel.menu_question, "Return to the main menu? The duel is over and its result stands: it is shown, then you leave %s as by its exit, and the adventure is saved and left." % title,
		"over: the board's own question")
	host.duel.menu_confirmed.emit()
	await _frames(3)
	assert_true(screen.leaving_after_panes(), "the world waits to leave")
	assert_eq(pane.step, "box", "the result shown first")
	assert_string_contains(pane.box_words(), "Defeated ")
	assert_eq(pane.board.value(cell), DungeonBoard.PASSED, "the room cleared, settled")
	screen._process(0.016)
	await _frames()
	assert_eq(screen.titles, 0, "not before it is read")
	assert_true(screen.on_board())
	pane.choose("go")
	await _frames(3)
	assert_eq(results.size(), 1, "the visit over")
	assert_false(screen.on_board())
	var saved := screen.saves
	assert_eq(saved, 2, "saved at the door and on the way out")
	screen._process(0.016)
	await _frames(2)
	assert_eq(screen.titles, 1, "then the title, without leaving by hand")
	assert_false(screen.leaving_after_panes())
	var reloaded := AdventurePlayer.load_from(screen.player.save_path())
	assert_true(reloaded.journal.any(func(line: Dictionary) -> bool: return String(line["text"]).begins_with("Defeated ")),
		"the save holds the room won")


func test_the_menu_after_a_drawn_room_shows_it_then_leaves() -> void:
	var pane := await _enter(8)
	pane.move(_plant(pane, 3))
	var host := await _duel_begun(pane)
	if host == null:
		return
	host.duel.game.winner = -1
	host.duel.game.game_over = true
	host.duel.menu_confirmed.emit()
	await _frames(3)
	assert_eq(pane.step, "box")
	assert_string_contains(pane.box_words(), "A draw")
	await _key(KEY_ENTER)
	await _frames(3)
	assert_eq(results.size(), 1, "the visit over")
	screen._process(0.016)
	await _frames(2)
	assert_eq(screen.titles, 1)


func test_the_menu_after_the_fifth_wizard_saves_his_win_and_leaves() -> void:
	screen.player.defeated_wizards = ["blue", "green", "red", "white"] as Array[String]
	var pane := await _enter(0)
	pane.move(_plant(pane, DungeonBoard.WIZARD))
	var host := await _duel_begun(pane)
	if host == null:
		return
	host.duel.game.winner = 0
	host.duel.game.game_over = true
	host.duel.menu_confirmed.emit()
	await _frames(3)
	assert_true(pane.over_pane() is CastleWinPane, "his pane: what the win brought, first")
	pane.over_pane().emit_signal("finished", [] as Array[String])
	await _frames(4)
	assert_eq(results.size(), 1)
	assert_true(bool(results[0]["all_five"]))
	assert_eq(screen.finales, 0, "not into the finale on the way to the title")
	screen._process(0.016)
	await _frames(2)
	assert_eq(screen.titles, 1, "the title")
	var reloaded := AdventurePlayer.load_from(screen.player.save_path())
	assert_eq(reloaded.defeated_wizards.size(), 5, "saved with the fifth: Arzakon's question on loading")


func test_the_menu_mid_duel_still_saves_nothing() -> void:
	var pane := await _enter(8)
	pane.move(_plant(pane, 3))
	var host := await _duel_begun(pane)
	if host == null:
		return
	host.duel.menu_confirmed.emit()
	await _frames(2)
	assert_eq(screen.titles, 1, "to the title")
	assert_eq(screen.saves, 1, "the door's save only")
	assert_true(results.is_empty())


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = keycode
		key.physical_keycode = keycode
		key.pressed = pressed
		viewport.push_input(key, true)
	await _frames()


# ------------------------------------------- h1-3: two directions held --

func test_a_second_held_direction_turns_the_hero_after_the_step() -> void:
	var pane := await _enter(8)
	DungeonView.frame_seconds = 30.0
	var start := pane.board.hero
	var first := start + DungeonBoard.STEPS[DungeonBoard.UP_LEFT]
	# Open both ways from the first cell, and on up-left once more.
	_open_cell(pane, first)
	_open_cell(pane, first + DungeonBoard.STEPS[DungeonBoard.UP_LEFT])
	var turned := first + DungeonBoard.STEPS[DungeonBoard.UP_RIGHT]
	_open_cell(pane, turned)
	_open_cell(pane, turned + DungeonBoard.STEPS[DungeonBoard.UP_LEFT])
	await _hold(KEY_HOME, true)
	assert_eq(pane.step, "walking", "Home held: walking up-left")
	assert_eq(pane.board.hero, first)
	await _hold(KEY_PAGEUP, true)
	assert_eq(pane.board.hero, first, "the step under way is not cut short")
	pane.view.finish_walk()
	assert_eq(pane.board.hero, turned, "the newer key held turns the hero after the step")
	await _hold(KEY_PAGEUP, false)
	pane.view.finish_walk()
	assert_eq(pane.board.hero, turned + DungeonBoard.STEPS[DungeonBoard.UP_LEFT],
		"the newer let go: the older, still held, walks on")
	await _hold(KEY_HOME, false)
	pane.view.finish_walk()
	assert_eq(pane.step, "idle", "no key held: the hero stands")


func test_a_tap_during_a_step_is_still_dropped() -> void:
	var pane := await _enter(8)
	DungeonView.frame_seconds = 30.0
	var start := pane.board.hero
	var first := start + DungeonBoard.STEPS[DungeonBoard.UP_LEFT]
	_open_cell(pane, first)
	_open_cell(pane, first + DungeonBoard.STEPS[DungeonBoard.UP_RIGHT])
	await _hold(KEY_HOME, true)
	await _hold(KEY_HOME, false)
	await _hold(KEY_PAGEUP, true)
	await _hold(KEY_PAGEUP, false)
	pane.view.finish_walk()
	assert_eq(pane.board.hero, first, "a key let go before the step ended is no step, as 1997's")
	assert_eq(pane.step, "idle")


# ---------------------------------------- h1-4: a dungeon with no card left --

func test_leave_says_a_dungeon_with_no_card_left_will_be_gone() -> void:
	var pane := await _enter(8)
	var slot: Dictionary = screen.world.encounters[8]
	pane.ask_leave()
	assert_string_contains(pane.box_words(), DungeonPane.LEAVE_MOVES, "control: with cards it moves")
	pane.choose("stay")
	slot["cards"] = []
	slot.erase(WorldClues.LEFT_CARDS)
	assert_false(WorldClues.holds_cards(slot), "control: no card left")
	pane.ask_leave()
	assert_false(DungeonPane.LEAVE_MOVES in pane.box_words(), "it does not move: it is gone")
	assert_string_contains(pane.box_words(), "the dungeon will be gone")
	pane.choose("leave")
	await _frames(3)
	assert_false(WorldClues.known(screen.world).has(8), "and gone it is")


# ------------------------------------------ h5-1: the swap's double click --

func test_a_double_click_on_leave_it_here_asks_first() -> void:
	var pane := await _enter(8)
	while screen.player.cards.size() < AdventurePlayer.BAG_MOST:
		screen.player.cards.append({"card": "Swamp", "decks": []})
	pane.move(_plant(pane, DungeonBoard.TREASURE))
	assert_eq(pane.step, "swap_ask")
	pane.choose("swap")
	await _frames(4)
	var builder := pane._builder as TreasureSwapBuilder
	assert_not_null(builder, "the deck builder over the world")
	if builder == null:
		return
	builder._show_in_showcase(CardRegistry.get_card("Swamp"))
	await _frames(2)
	var button := builder._leave_button
	assert_false(button.disabled, "control: a card the hero owns, on show")
	var swapped: Array = []
	builder.swapped.connect(func(at: int) -> void: swapped.append(at))
	var at := button.get_global_rect().get_center()
	await _click_at(at)
	assert_eq(button.text, TreasureSwapBuilder.SURE, "the first press asks")
	assert_string_contains(builder._status_label.text, "Press again.")
	await _click_at(at, true)
	assert_eq(swapped, [], "the second press of the double click leaves nothing")
	assert_false(builder._left)
	await _click_at(at)
	assert_eq(swapped.size(), 1, "control: a press of its own leaves the card")
