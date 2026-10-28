extends GutTest
## PART C, W3 — "ONE LIFE" IS TRUE IRONMAN (the owner's ruling of
## 2026-10-27: *"True ironman: closing mid-battle ends the adventure as a
## lost final battle; no way to retry."*): the door saves the battle begun
## and marks it in the Hall of Fame's file, outside every save
## ([HallOfFame.one_life_state]); a game closed in the battle, or an older
## save of the adventure taken up after its battle began, is a lost final
## battle on the load ([FinalBattle.on_load]); a won adventure's older save
## is untouched; "Reload allowed" never changes on a load; and the marks
## live through a damaged file as the Hall's lines do.

const FOLDER := "user://adventure_tests_pc_w3_one_life"
const HALL := "user://hall_tests_pc_w3_one_life"
const AT := HALL + "/hall_of_fame.json"
const WHEN := "2026-10-27T21:00:00Z"


func before_each() -> void:
	AdventurePlayer.saves_folder = FOLDER
	HallOfFame.file = AT
	_clear()


func after_each() -> void:
	_clear()
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	HallOfFame.file = HallOfFame.FILE
	AdventurePlayer.forget_saves()


func _clear() -> void:
	for folder in [FOLDER, HALL]:
		var dir := DirAccess.open(folder)
		if dir == null:
			continue
		for file_name in dir.get_files():
			dir.remove(file_name)


## A hero of a small world who has beaten all five wizards, the green one
## last, under [param rule].
func _player(rule := AdventurePlayer.LIFE_ONE, id := "Ironman-0000a1a1") -> AdventurePlayer:
	var world := ShandalarWorld.new()
	world.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			world.page[y * ShandalarWorld.PAGE_WIDTH + x] = 6
	for i in 3:
		world.sites.append({"x": 20 + i * 3, "y": 20, "type": ShandalarWorld.TOWN, "trade": 0,
			"status": TownStatus.LINKED})
	for i in 5:
		world.encounters.append({"x": 10 + i * 8, "y": 40, "color": i + 1, "clues": 0, "cards": []})
	world.lair_respawn = [0, 0, 0, 0, 0, 0, 0, 0] as Array[int]
	var player := AdventurePlayer.new()
	player.world = world
	player.adventure_id = id
	player.name = "Iron Hero"
	player.difficulty = 2
	player.life_rule = rule
	player.position = Vector2i(26 * 32 + 16, 40 * 32 + 16)
	player.dice = 31
	for hue in ["black", "blue", "red", "white", "green"]:
		player.defeated_wizards.append(hue)
	return player


## [param player] as a save holds it, read back.
func _saved(player: AdventurePlayer) -> AdventurePlayer:
	return AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))


func _report(result: int) -> DuelReport:
	var report := DuelReport.new()
	report.finished = true
	report.result = result
	report.lives_start = [12, 300] as Array[int]
	report.lives_end = [0, 40] as Array[int]
	if result == DuelReport.WIN:
		report.lives_end = [5, 0] as Array[int]
	return report


# --------------------------------------------------------------- the quit --

func test_a_game_closed_in_the_battle_is_a_lost_battle() -> void:
	var player := _player()
	player.final_attempts = 0
	assert_true(FinalBattle.door(player), "saved at the door")
	var path := player.autosave()
	assert_ne(path, "")
	# The window closes in the battle: nothing more is written.
	var back := AdventurePlayer.load_from(path)
	assert_true(back.at_door, "the save stands at the door: the battle begun")
	assert_true(FinalBattle.on_load(back, "", WHEN), "taken up again: settled as lost")
	assert_eq(back.ended, AdventurePlayer.ENDED_FAILED, "the adventure closed")
	assert_false(back.at_door)
	assert_eq([back.final["result"], back.final["left"], back.final["attempts"], back.final["date"]],
		["failed", true, 0, WHEN])
	assert_false(back.final.has("score"))
	assert_eq(String(back.journal.back()["text"]), "Lost to an Arzakon")
	assert_eq(HallOfFame.one_life_state(back.adventure_id), HallOfFame.FAILED)
	assert_false(FinalBattle.on_load(back), "an ended adventure is left as it is")
	var reread := _saved(back)
	assert_true(bool(reread.final["left"]), "the record keeps how it was lost")


func test_an_older_save_cannot_fight_the_battle_again() -> void:
	var player := _player()
	var before := player.to_dict()
	FinalBattle.door(player)
	assert_eq(HallOfFame.one_life_state(player.adventure_id), HallOfFame.BEGUN)
	var older := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(before)))
	assert_false(older.at_door, "a slot saved before the door")
	assert_true(FinalBattle.on_load(older), "its battle began: lost")
	assert_eq(older.ended, AdventurePlayer.ENDED_FAILED)
	var other := _player(AdventurePlayer.LIFE_ONE, "Ironman-0000b2b2")
	var earlier := other.to_dict()
	FinalBattle.door(other)
	FinalBattle.settle(other, _report(DuelReport.LOSS))
	assert_eq(HallOfFame.one_life_state(other.adventure_id), HallOfFame.FAILED)
	var retry := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(earlier)))
	assert_true(FinalBattle.on_load(retry), "lost, and an older save cannot try again")
	assert_eq(retry.ended, AdventurePlayer.ENDED_FAILED)
	var never := _player(AdventurePlayer.LIFE_ONE, "Ironman-0000c3c3")
	assert_false(FinalBattle.on_load(_saved(never)), "a battle never begun: the adventure goes on")
	assert_eq(never.ended, "")


func test_a_won_adventures_older_save_is_untouched() -> void:
	var player := _player()
	var before := player.to_dict()
	FinalBattle.door(player)
	FinalBattle.settle(player, _report(DuelReport.WIN), false, {}, WHEN)
	assert_eq(HallOfFame.one_life_state(player.adventure_id), "", "the win takes the mark away")
	assert_eq(HallOfFame.add(player), 1, "the Hall's line takes over")
	var older := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(before)))
	assert_false(FinalBattle.on_load(older), "nothing marks it")
	assert_eq(older.ended, "")
	assert_false(FinalBattle.on_load(_saved(player)), "the won save itself neither")
	assert_eq(_saved(player).ended, AdventurePlayer.ENDED_WON)


func test_reload_allowed_never_changes_on_a_load() -> void:
	var player := _player(AdventurePlayer.LIFE_RELOAD)
	assert_true(FinalBattle.door(player), "the checkpoint")
	assert_eq(HallOfFame.one_life_state(player.adventure_id), "", "no mark")
	var back := _saved(player)
	assert_false(FinalBattle.on_load(back))
	assert_true(back.at_door, "back at the door, to fight again")
	assert_eq(back.ended, "")
	HallOfFame.mark_one_life(player.adventure_id, HallOfFame.FAILED)
	assert_false(FinalBattle.on_load(back), "whatever the file says")
	assert_eq(back.ended, "")


func test_a_win_after_the_door_and_a_loss_mark_the_file() -> void:
	var won := _player(AdventurePlayer.LIFE_ONE, "Ironman-0000d4d4")
	var lost := _player(AdventurePlayer.LIFE_ONE, "Ironman-0000e5e5")
	FinalBattle.door(won)
	FinalBattle.door(lost)
	FinalBattle.settle(lost, null, true)
	assert_eq(HallOfFame.one_life_state(lost.adventure_id), HallOfFame.FAILED, "a concession: lost")
	assert_eq(HallOfFame.one_life_state(won.adventure_id), HallOfFame.BEGUN, "one mark an adventure")
	FinalBattle.settle(won, _report(DuelReport.WIN))
	assert_eq(HallOfFame.one_life_state(won.adventure_id), "")
	assert_eq(HallOfFame.one_life_state(lost.adventure_id), HallOfFame.FAILED, "the other kept")


# ------------------------------------------------------- the file's safety --

func test_the_marks_live_through_a_damaged_file_as_the_hall_does() -> void:
	DirAccess.make_dir_recursive_absolute(HALL)
	var file := FileAccess.open(AT, FileAccess.WRITE)
	file.store_string("not a hall at all")
	file.close()
	var player := _player()
	assert_eq(HallOfFame.one_life_state(player.adventure_id), "", "an unreadable file marks nothing")
	FinalBattle.door(player)
	assert_eq(FileAccess.get_file_as_string(AT + ".bad"), "not a hall at all", "set aside, not written over")
	assert_eq(HallOfFame.one_life_state(player.adventure_id), HallOfFame.BEGUN)
	var winner := _player(AdventurePlayer.LIFE_RELOAD, "Winner-0000f6f6")
	winner.ended = AdventurePlayer.ENDED_WON
	winner.final = {"result": "won", "score": 900, "days": 20, "wins": 9, "date": WHEN}
	assert_eq(HallOfFame.add(winner), 1)
	assert_eq(HallOfFame.one_life_state(player.adventure_id), HallOfFame.BEGUN, "a Hall line keeps the marks")
	assert_true(HallOfFame.mark_one_life(player.adventure_id, HallOfFame.FAILED))
	assert_eq(HallOfFame.entries().size(), 1, "a mark keeps the Hall's lines")
	assert_false(HallOfFame.mark_one_life("", HallOfFame.BEGUN), "no adventure")
	assert_false(HallOfFame.mark_one_life(player.adventure_id, "maybe"), "no such mark")


func test_the_marks_are_read_field_by_field() -> void:
	DirAccess.make_dir_recursive_absolute(HALL)
	var file := FileAccess.open(AT, FileAccess.WRITE)
	file.store_string(JSON.stringify({"format": HallOfFame.FORMAT, "version": 1, "entries": [],
		"one_life": {"a": "begun", "b": "failed", "c": "won", "d": 3, "": "begun"}}))
	file.close()
	assert_eq([HallOfFame.one_life_state("a"), HallOfFame.one_life_state("b"), HallOfFame.one_life_state("c"),
		HallOfFame.one_life_state("d"), HallOfFame.one_life_state("")], ["begun", "failed", "", "", ""])
	file = FileAccess.open(AT, FileAccess.WRITE)
	file.store_string(JSON.stringify({"format": HallOfFame.FORMAT, "version": 1, "entries": [],
		"one_life": ["a list"]}))
	file.close()
	assert_eq(HallOfFame.one_life_state("a"), "", "marks that are no record: none")


func test_a_mark_that_cannot_be_written_leaves_the_save_to_decide() -> void:
	DirAccess.make_dir_recursive_absolute(HALL)
	var blocker := FileAccess.open(HALL + "/blocked", FileAccess.WRITE)
	blocker.store_string("a file where a folder should be")
	blocker.close()
	var hall := HALL + "/blocked/hall_of_fame.json"
	var player := _player()
	assert_true(FinalBattle.door(player, hall), "still saved at the door")
	assert_eq(HallOfFame.one_life_state(player.adventure_id, hall), "")
	var back := _saved(player)
	assert_true(FinalBattle.on_load(back, hall), "the save at the door is enough")
	assert_eq(back.ended, AdventurePlayer.ENDED_FAILED)
