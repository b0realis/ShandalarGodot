extends GutTest
## THE WINDOW CLOSED OVER A DUEL THAT IS OVER (the review of 2026-11-21,
## round 2): a ruled town's, a lair's and a castle's or dungeon's room duel.
## Its result stands and is saved before the process ends — a loss is not
## undone by the reload — and nothing is saved that could be had twice; a
## duel still played saves nothing, as ever.

const SAVES := "user://adventure_tests_review_adv_duels"


## A ruled town's pane with its duel settled, as [RuledTownPane] answers.
class OverTown extends Control:
	signal finished(result: int)
	var result := 0
	var closes := true

	func duel_host() -> WorldDuels:
		return null

	func close_out() -> bool:
		if not closes:
			return false
		finished.emit(result)
		queue_free()
		return true


class Probe extends WorldScreen:
	var saves := 0
	var pane: Control = null
	var gold_at_save: Array = []
	var cards_at_save: Array = []

	func _board_seed() -> int:
		return 4242

	func _open_ruled_pane(_slot: int) -> Control:
		if pane != null:
			add_child(pane)
		return pane

	func _write_autosave() -> String:
		saves += 1
		cards_at_save.append(player.cards.size())
		return super()

	func _go_to_title() -> void:
		_leaving = true


var viewport: SubViewport
var screen: Probe
var results: Array = []


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
	screen.cards_at_save = []
	results = []


func after_each() -> void:
	await _frames()
	AdventurePlayer.finish_saves()
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


func _close_the_window() -> void:
	screen.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)


## The duel of [param host] over — seat [param loser] conceded — with its
## End of Duel window still up: headless the duel closes itself as it ends,
## so its closing is unhooked first, as the window holds it in the game.
func _end_of_duel(host: WorldDuels, loser: int) -> void:
	if host.duel.duel_closed.is_connected(host._closed):
		host.duel.duel_closed.disconnect(host._closed)
	host.duel.game.concede(loser)
	assert_true(host.duel.game.game_over, "control: the duel is over")


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


# ----------------------------------------------------------- a ruled town --

func test_a_ruled_town_s_settled_duel_is_closed_out_by_its_pane() -> void:
	var pane := RuledTownPane.new()
	assert_false(pane.close_out(), "no duel settled: nothing to close out")
	var heard: Array = []
	pane.finished.connect(func(result: int) -> void: heard.append(result))
	pane.outcome = {"result": RuledTownPane.LOST, "lost": ["Forest"]}
	pane.result = RuledTownPane.LOST
	assert_true(pane.close_out(), "a loss settled: its pages left unread, the pane over")
	assert_eq(heard, [RuledTownPane.LOST])
	assert_false(pane.close_out(), "once")
	if is_instance_valid(pane):
		pane.free()


func test_the_window_closed_over_a_ruled_town_s_lost_duel_saves_the_loss() -> void:
	var slot := -1
	for i in screen.world.sites.size():
		if int(screen.world.sites[i]["type"]) == ShandalarWorld.VILLAGE:
			slot = i
			break
	var town := OverTown.new()
	town.result = WorldEncounters.LOST
	screen.pane = town
	screen._open_ruled_duel({"kind": "ruled", "slot": slot})
	assert_true(screen.meeting())
	screen.player.cards.pop_back()
	_close_the_window()
	assert_false(screen.meeting(), "the town's duel over before the process ends")
	assert_gt(screen.saves, 0, "and the world saved")
	assert_eq(screen.cards_at_save[-1], 19, "with the loss in it")
	assert_false(AdventurePlayer.saves_pending())
	await _frames(2)


func test_the_window_closed_over_a_ruled_town_s_duel_still_played_saves_nothing() -> void:
	var town := OverTown.new()
	town.closes = false
	screen.pane = town
	screen._open_ruled_duel({"kind": "ruled", "slot": 0})
	_close_the_window()
	assert_true(screen.meeting())
	assert_eq(screen.saves, 0, "ruling 4: nothing saved mid-duel")
	town.finished.emit(WorldEncounters.NO_DUEL)
	await _frames(2)


# ------------------------------------------------------------------ a lair --

func _lair() -> LairPane:
	var event := {"slot": 1, "color": 1, "event": LairEvent.SULTAN, "name": LairEvent.NAMES[LairEvent.SULTAN],
		"reward": "", "lair_rare": "", "oasis": -1}
	var pane := LairPane.new()
	pane.player = screen.player
	pane.event = event
	pane.place = LairPane.place_of(event)
	screen._visit = pane
	screen.add_child(pane)
	PaneStyle.centre(pane)
	screen._lair_done = screen._left_lair.bind(1)
	pane.left.connect(screen._lair_done, WorldScreen.CLOSING)
	screen._hold()
	await _frames(2)
	return pane


func test_the_window_closed_over_a_lair_s_finished_duel_keeps_its_result() -> void:
	for hero_wins in [false, true]:
		var pane: LairPane = await _lair()
		screen.player.next_duel_life = 3
		var owned := screen.player.cards.size()
		var rares: Array = pane.duel_setup.get("rares", [])
		pane.choose("lair_duel")
		await _frames(3)
		var host := pane.duel_host()
		assert_not_null(host, "the duel over the world")
		if host == null:
			return
		var saved := screen.saves
		_close_the_window()
		assert_true(screen.visiting(), "a duel still played: the lair stands")
		assert_eq(screen.saves, saved, "and nothing is saved (ruling 4)")
		_end_of_duel(host, 1 if hero_wins else 0)
		_close_the_window()
		assert_false(screen.visiting(), "the duel over: the lair left before the process ends")
		assert_gt(screen.saves, saved, "and the world saved")
		assert_eq(screen.player.next_duel_life, 0, "the next duel's gift spent, in the save")
		assert_eq(screen.cards_at_save[-1], owned + (rares.size() if hero_wins else 0),
			"a win's hoard the hero's, a loss as it is — once")
		assert_false(AdventurePlayer.saves_pending())
		await _frames(3)
		assert_false(screen.modal(), "nothing left holding the world")


# ---------------------------------------------------- a castle or a dungeon --

func _enter(index: int) -> DungeonPane:
	screen.world.encounters[index]["clues"] = WorldClues.RULES | WorldClues.CREATURES
	screen._enter_board({"kind": "dungeon", "slot": index})
	await _frames(3)
	var pane := screen._board as DungeonPane
	assert_not_null(pane, "the board's pane")
	if pane != null:
		pane.finished.connect(func(result: Dictionary) -> void: results.append(result))
		if pane.step == "first":
			pane.choose("go")
			await _frames()
	return pane


func _plant(pane: DungeonPane, event: int) -> int:
	var board := pane.board
	for way in [1, 3, 7, 5]:
		var to: Vector2i = board.hero + DungeonBoard.STEPS[way]
		if board.is_open(to) and to != DungeonBoard.ENTRANCE:
			board.cells[to.x * DungeonBoard.HEIGHT + to.y] = DungeonBoard.OPEN | DungeonBoard.SEEN \
				| (event << DungeonBoard.EVENT_SHIFT)
			return way
	return 0


func _to_the_duel(pane: DungeonPane) -> WorldDuels:
	pane.move(_plant(pane, 3))
	await _frames(3)
	pane.over_pane().emit_signal("chosen", RoomDuelPane.DUEL)
	await _frames(3)
	return pane.duel_host()


func test_the_window_closed_on_the_board_saves_nothing_but_over_a_lost_room_it_saves_the_loss() -> void:
	var pane := await _enter(8)
	assert_eq(screen.saves, 1, "saved at the door")
	_close_the_window()
	assert_true(screen.on_board(), "walking the maze: the visit stands")
	assert_eq(screen.saves, 1, "and the door's save too, as 1997 saved nothing inside")
	var host: WorldDuels = await _to_the_duel(pane)
	assert_not_null(host)
	if host == null:
		return
	_close_the_window()
	assert_true(screen.on_board())
	assert_eq(screen.saves, 1, "a duel still played: nothing saved (ruling 4)")
	var owned := screen.player.cards.size()
	_end_of_duel(host, 0)
	_close_the_window()
	assert_false(screen.on_board(), "the room lost: the visit over before the process ends")
	assert_eq(results.size(), 1, "the board left once")
	assert_eq(screen.player.cards.size(), owned - 1, "the card staked is lost")
	assert_gt(screen.saves, 1, "and the world saved on the way out")
	assert_eq(screen.cards_at_save[-1], owned - 1, "with the loss in it: the reload does not undo it")
	assert_false(AdventurePlayer.saves_pending())
	await _frames(3)
	assert_eq(results.size(), 1, "not heard a second time after the frame")


func test_the_window_closed_on_the_lost_card_s_page_saves_the_loss_too() -> void:
	var pane := await _enter(8)
	var host: WorldDuels = await _to_the_duel(pane)
	if host == null:
		fail_test("no duel")
		return
	var owned := screen.player.cards.size()
	host._finish(_report(DuelReport.LOSS))
	await _frames(3)
	assert_eq(pane.step, "lost", "control: \"Lost this card\"")
	_close_the_window()
	assert_false(screen.on_board())
	assert_eq(screen.cards_at_save[-1], owned - 1)
	assert_eq(results.size(), 1)
	await _frames(3)


func test_a_room_won_and_the_window_closed_at_its_end_of_duel_keeps_the_win_once() -> void:
	var pane := await _enter(8)
	var host: WorldDuels = await _to_the_duel(pane)
	if host == null:
		fail_test("no duel")
		return
	_end_of_duel(host, 1)
	_close_the_window()
	assert_false(screen.on_board(), "the visit ended as by the exit")
	assert_eq(results.size(), 1)
	assert_gt(screen.saves, 1, "saved on the way out")
	await _frames(3)


func test_a_wizard_beaten_is_not_closed_out_while_his_picks_wait() -> void:
	var pane := await _enter(8)
	pane._settled = DungeonBoard.BEATEN
	pane.step = "lost"
	assert_false(pane.close_out(), "that win is never saved with half of it")
	pane.step = "idle"
	pane._settled = ""
	assert_false(pane.close_out(), "nor the board at any other moment")
	assert_eq(screen.saves, 1)
