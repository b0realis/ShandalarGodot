extends GutTest
## 0.70.11 campaign, bugs4 #1: an adventure duel given up through Concede
## ends the game in the engine, so its recording closes 0-1 as one lost on
## the table — and the adventure counts the loss and the stake once.

const SAVES := "user://c1126_adv_concede_saves"
const REC := "user://c1126_adv_concede_rec"

var viewport: SubViewport
var screen: WorldScreen


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Probe"
	setup.color = "white"
	setup.difficulty = 1
	setup.seed_text = "12345"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	screen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.set_process(false)
	screen.player.monsters = [] as Array


func after_each() -> void:
	AdventurePlayer.finish_saves()
	for folder in [SAVES, REC]:
		var dir := DirAccess.open(folder)
		if dir != null:
			for file_name in dir.get_files():
				dir.remove(file_name)
			DirAccess.remove_absolute(folder)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	AdventurePlayer.forget_saves()


## A creature met and dueled, ended [param how]: the recording as read back,
## and what the hero's bag lost.
func _duel(how: String) -> Dictionary:
	var hero := screen.player
	var at := hero.position + Vector2i(8, 0)
	hero.monsters = [{"slot": 1, "kind": "creature", "creature": 15, "x": at.x, "y": at.y, "color": 1,
		"heading": 7, "frame": 0}]
	var cards := hero.cards.size()
	var pane: Variant = screen.meet_creature(1)
	await _frames(3)
	var stake: Array = (pane.meeting["hero_ante"] as Array).duplicate()
	pane.choose("duel")
	await _frames(3)
	if pane.step == "special":
		pane.choose("fight")
		await _frames(3)
	var host: WorldDuels = pane.duel_host()
	assert_not_null(host, "the duel over the world")
	var game: MtgGame = host.duel.game
	var archive := MpnArchive.new()
	DirAccess.make_dir_recursive_absolute(REC)
	archive.start(game, MpnArchive.metadata(game, "local"), ProjectSettings.globalize_path(REC))
	var heard: Array = []
	host.ended.connect(func(report: DuelReport) -> void: heard.append(report))
	if how == "concede":
		host.concede()
	else:
		game.concede(0)
	await _frames(4)
	archive.close()
	var read := MpnArchive.read(archive.path)
	return {"read": read, "last": (read.get("records", []) as Array).back(), "stake": stake,
		"lost": cards - hero.cards.size(), "heard": heard, "conceded": host.conceded if is_instance_valid(host) else how == "concede",
		"game_over": game.game_over, "winner": game.winner}


func test_a_conceded_adventure_duel_is_recorded_0_1_like_one_lost_on_the_table() -> void:
	var lost := await _duel("lose")
	assert_true(bool(lost["read"].get("finished")), "lost on the table: finished")
	assert_eq(String(lost["last"]["kind"]), "result")
	await _frames(4)
	# A fresh world for the conceded one.
	screen.queue_free()
	await before_each()
	var given_up := await _duel("concede")
	assert_true(bool(given_up["game_over"]), "the game ended in the engine")
	assert_eq(int(given_up["winner"]), 1)
	assert_true(bool(given_up["read"].get("finished")), "conceded: finished, not Incomplete")
	assert_eq(String(given_up["last"]["kind"]), "result", "a result record, as on the table")
	assert_eq(String((lost["last"]["data"] as Dictionary)["result"]), "0-1")
	assert_eq(String((given_up["last"]["data"] as Dictionary)["result"]), "0-1")
	assert_eq((given_up["heard"] as Array).size(), 1, "the adventure hears the duel's end once")
	var report: DuelReport = given_up["heard"][0]
	assert_eq(report.result, DuelReport.LOSS)
	assert_eq(report.winner, 1)
	assert_eq(int(given_up["lost"]), (given_up["stake"] as Array).size(), "the stake lost once")
	assert_eq(int(given_up["lost"]), int(lost["lost"]), "as a duel lost on the table")
