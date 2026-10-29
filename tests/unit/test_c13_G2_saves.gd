extends GutTest
## PART C STAGE C3, G2 — THE END'S SAVES: a save says version 2, so an older
## build that reads only 1 keeps it as "saved by a newer version" rather than
## writing it back without part C's end (h5-5); the end's marks that
## contradict one another in a damaged save are made to agree — a won
## adventure's portal petrified, any other's open, the door only with all
## five wizards beaten — and walking on after the win always petrifies the
## portal (h5-6); the load list's line carries the door mark, and a save of
## "One life" whose final battle the Hall's file marks begun or lost — or
## which stands at the door — reads as a failed quest (h3-2); and a Hall's
## file that cannot be read is told apart from an empty Hall (h3-4).

const FOLDER := "user://adventure_tests_c13_g2_saves"
const HALL := "user://adventure_tests_c13_g2_saves_hall"


func before_each() -> void:
	AdventurePlayer.saves_folder = FOLDER
	HallOfFame.file = HALL + "/hall_of_fame.json"
	_clear()
	AdventurePlayer.forget_saves()


func after_each() -> void:
	_clear()
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	HallOfFame.file = HallOfFame.FILE
	AdventurePlayer.forget_saves()


func _clear() -> void:
	for folder in [FOLDER, HALL]:
		var dir := DirAccess.open(folder)
		if dir != null:
			for file_name in dir.get_files():
				dir.remove(file_name)
			DirAccess.remove_absolute(folder)


## A hero of seed 4242, [param beaten] of the five wizards beaten.
func _player(beaten := 5, rule := AdventurePlayer.LIFE_RELOAD) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.player_name = "Ysolde Starfall"
	setup.color = "blue"
	setup.difficulty = 1
	setup.walker = "female"
	setup.seed_text = "4242"
	var record := setup.resolve({})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	player.life_rule = rule
	player.defeated_wizards.assign(AdventurePlayer.COLORS.slice(0, beaten))
	return player


## [param player]'s save with its end's marks [param end], read back.
func _read_back(player: AdventurePlayer, end: Dictionary) -> AdventurePlayer:
	var data: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	data["end"] = end
	return AdventurePlayer.from_dict(data)


# ---------------------------------------------------------------- h5-5 --

func test_a_save_says_version_2_and_a_version_1_save_still_reads() -> void:
	var player := _player()
	var data: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	# Version 3 since the 0.50.65 bug campaign (k6-3): still past 1.
	assert_gte(int(data["version"]), 2, "part C's saves are version 2: an older build refuses them")
	data["version"] = 1
	assert_not_null(AdventurePlayer.from_dict(data), "a save from before still reads")
	data["version"] = AdventurePlayer.FORMAT_VERSION + 1
	assert_null(AdventurePlayer.from_dict(data), "a newer one does not")


# ---------------------------------------------------------------- h5-6 --

func test_contradicting_end_marks_are_made_to_agree() -> void:
	var player := _player()
	var tile := FinalBattle.portal_tile(player.world)
	var at := {"x": tile.x, "y": tile.y}
	var won := _read_back(player, {"ended": "won", "portal": at.merged({"state": "open"})})
	assert_eq(String(won.portal["state"]), FinalBattle.PORTAL_PETRIFIED, "won: the monument, never an open portal")
	var going := _read_back(player, {"ended": "", "portal": at.merged({"state": "petrified"})})
	assert_eq(String(going.portal["state"]), FinalBattle.PORTAL_OPEN,
		"not won, all five beaten: a petrified portal could never be entered — open")
	assert_true(FinalBattle.portal_open(going), "the end within reach")
	var door := _read_back(player, {"ended": "", "at_door": true, "portal": at.merged({"state": "open"})})
	assert_true(door.at_door, "all five beaten: at the door")
	var four := _read_back(_player(4), {"ended": "", "at_door": true})
	assert_false(four.at_door, "four beaten: no door to stand at")
	var lone := _read_back(_player(5), {"ended": "won", "at_door": true})
	assert_false(lone.at_door, "won: no door")


func test_one_life_with_a_false_door_is_no_lost_battle() -> void:
	var player := _player(3, AdventurePlayer.LIFE_ONE)
	var back := _read_back(player, {"ended": "", "at_door": true})
	assert_false(FinalBattle.on_load(back, HALL + "/none.json"), "the load does not settle it as lost")
	assert_eq(back.ended, "", "the adventure goes on")


func test_walking_on_after_the_win_always_petrifies_the_portal() -> void:
	var player := _player()
	var tile := FinalBattle.portal_tile(player.world)
	player.ended = AdventurePlayer.ENDED_WON
	player.portal = {"x": tile.x, "y": tile.y, "state": FinalBattle.PORTAL_OPEN}
	assert_ne(FinalBattle.roam(player), "", "the journal's line")
	assert_eq(String(player.portal["state"]), FinalBattle.PORTAL_PETRIFIED, "an open portal turned to stone")
	player.portal["state"] = FinalBattle.PORTAL_OPEN
	assert_eq(FinalBattle.roam(player), "", "the line written once")
	assert_eq(String(player.portal["state"]), FinalBattle.PORTAL_PETRIFIED, "and the monument all the same")
	var going := _player()
	going.portal = {"x": tile.x, "y": tile.y, "state": FinalBattle.PORTAL_OPEN}
	FinalBattle.roam(going)
	assert_eq(String(going.portal["state"]), FinalBattle.PORTAL_OPEN, "not won: nothing changes")


# ---------------------------------------------------------------- h3-2 --

func test_the_list_s_line_carries_the_door_and_a_one_life_battle_begun_reads_failed() -> void:
	var player := _player(5, AdventurePlayer.LIFE_ONE)
	player.adventure_id = "Ysolde-Starfall-0000c13a"
	var slot := SaveSlots.save_into(player, 1, "at the portal")
	assert_ne(slot, "", "a slot saved before the door")
	var line := AdventurePlayer.save_at(slot)
	assert_eq([line["ended"], line["at_door"]], ["", false])
	assert_eq(LoadAdventureScreen.end_words(line, {}), "", "a quest going on")
	FinalBattle.door(player)
	assert_ne(player.autosave(), "")
	var door := AdventurePlayer.save_at(player.save_path(AdventurePlayer.AUTOSAVE))
	assert_true(bool(door["at_door"]), "the autosave stands at the door")
	assert_eq(LoadAdventureScreen.end_words(door, {}), LoadAdventureScreen.FAILED_ROW,
		"One life at the door: the load settles it lost")
	assert_eq(HallOfFame.one_life_state(player.adventure_id), HallOfFame.BEGUN)
	assert_eq(LoadAdventureScreen.end_words(line), LoadAdventureScreen.FAILED_ROW,
		"the slot from before the door: the Hall's mark says begun")
	assert_eq(LoadAdventureScreen.end_words(line, HallOfFame.one_life_marks()), LoadAdventureScreen.FAILED_ROW,
		"the marks read once say the same")
	var reload := line.duplicate()
	reload["life_rule"] = AdventurePlayer.LIFE_RELOAD
	reload["at_door"] = true
	assert_eq(LoadAdventureScreen.end_words(reload, HallOfFame.one_life_marks()), "",
		"Reload allowed: the door is a door, not a loss")
	var loaded := AdventurePlayer.load_from(slot)
	assert_true(FinalBattle.on_load(loaded), "and the load does settle it as a lost battle")


# ---------------------------------------------------------------- h3-4 --

func test_a_hall_file_that_cannot_be_read_is_told_apart() -> void:
	assert_false(HallOfFame.damaged(), "no file: an empty Hall")
	DirAccess.make_dir_recursive_absolute(HALL)
	var file := FileAccess.open(HallOfFame.file, FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	assert_true(HallOfFame.damaged(), "garbage")
	file = FileAccess.open(HallOfFame.file, FileAccess.WRITE)
	file.store_string(JSON.stringify({"format": HallOfFame.FORMAT, "version": HallOfFame.FORMAT_VERSION + 1,
		"entries": []}))
	file.close()
	assert_true(HallOfFame.damaged(), "a newer Hall")
	file = FileAccess.open(HallOfFame.file, FileAccess.WRITE)
	file.store_string(JSON.stringify({"format": HallOfFame.FORMAT, "version": HallOfFame.FORMAT_VERSION,
		"entries": [], "one_life": {"a": "begun"}}))
	file.close()
	assert_false(HallOfFame.damaged(), "a Hall of its own")
	assert_eq(HallOfFame.one_life_marks(), {"a": "begun"}, "its marks read in one")
