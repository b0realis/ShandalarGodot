extends GutTest
## PART C, W3 — THE FINAL BATTLE SETTLED AND THE END'S MARKS
## ([FinalBattle.settle], [FinalBattle.door], [AdventurePlayer]): a win, a
## loss, a draw, a concession and an unfinished or missing report under the
## owner's rules ("loss ends") and as played (the win whatever came), under
## each Embark rule ("Reload allowed", "One life"); the journal, the victory
## log untouched, the gifts spent; Arzakon's door and portal; and the marks
## saved, read back safely, and shown in the load list.

const FOLDER := "user://adventure_tests_pc_w3"
## The Hall's file the One-life marks go to — the tests' own.
const HALL := "user://hall_tests_pc_w3_settle"
const WHEN := "2026-10-27T20:00:00Z"


func before_each() -> void:
	AdventurePlayer.saves_folder = FOLDER
	HallOfFame.file = HALL + "/hall_of_fame.json"
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


## A hero of a small world (white plains, three linked towns, the five
## castles as encounter slots 0–4) who has beaten all five wizards, the
## green one last.
func _player(difficulty := 3) -> AdventurePlayer:
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
	player.adventure_id = "Ysolde-Starfall-0000c3c3"
	player.name = "Ysolde Starfall"
	player.difficulty = difficulty
	player.position = Vector2i(26 * 32 + 16, 40 * 32 + 16)
	player.quest_timer = 40 * WorldStatus.DAY
	player.dice = 777
	for hue in ["black", "blue", "red", "white", "green"]:
		player.defeated_wizards.append(hue)
	player.siege_count = 4
	for kind in [1, 1, 4, 4, 4, 7, 7, 9, 9, 11]:
		player.duel_victories.append({"color": 1, "kind": kind, "creature": ""})
	return player


func _report(result: int, lives_start: Array[int], lives_end: Array[int], finished := true) -> DuelReport:
	var report := DuelReport.new()
	report.finished = finished
	report.result = result if finished else DuelReport.DRAW
	report.lives_start = lives_start
	report.lives_end = lives_end
	report.hero_life = lives_end[0]
	return report


func _last_line(player: AdventurePlayer) -> Dictionary:
	return player.journal.back() if not player.journal.is_empty() else {}


# ------------------------------------------------------------- the win --

func test_a_win_ends_the_adventure_won_with_its_score() -> void:
	var player := _player(3)
	player.next_duel_life = 3
	player.next_duel_first_move = true
	var victories := player.duel_victories.duplicate(true)
	var settled := FinalBattle.settle(player, _report(DuelReport.WIN, [13, 400], [2, -3]), false, {}, WHEN)
	assert_true(settled["won"])
	assert_eq(String(settled["outcome"]), FinalBattle.WON)
	assert_eq([settled["base"], settled["shown"]], [130, 130])
	assert_eq(settled["years"], 4030, "403 lives lost, below 0 too")
	assert_eq(settled["score"], 4160)
	assert_eq(String(settled["journal"]), "Defeated an Arzakon")
	var line := _last_line(player)
	assert_eq([line["event"], line["text"], line["won"], line["row"], line["creature"]],
		["duel", "Defeated an Arzakon", true, 55, "Arzakon"])
	assert_eq(player.duel_victories, victories, "never the victory log (1997: world meetings only)")
	assert_false(player.duel_gift_waiting() or player.next_duel_lives() != 0, "the gifts spent")
	assert_eq(player.ended, AdventurePlayer.ENDED_WON)
	assert_true(player.at_peace(), "the world at peace")
	assert_false(player.at_door)
	assert_eq(player.final, {"result": "won", "score": 4160, "base": 130, "years": 4030,
		"lives_start": [13, 400], "lives_end": [2, -3], "difficulty": 3, "days": 40,
		"wins": 1, "attempts": 0, "date": WHEN, "life_rule": AdventurePlayer.LIFE_RELOAD})
	assert_eq(player.portal, {"x": 31, "y": 31, "state": FinalBattle.PORTAL_PETRIFIED},
		"faced at once: the monument stands near the map's middle all the same")


func test_a_floored_base_and_the_years_after_it() -> void:
	var player := _player(0)
	player.siege_count = 30
	player.duel_victories.clear()
	for i in 5:
		player.duel_victories.append({"color": 1, "kind": 8, "creature": ""})
	var settled := FinalBattle.settle(player, _report(DuelReport.WIN, [10, 100], [1, 0]))
	assert_eq([settled["base"], settled["shown"], settled["score"]], [-80, 0, 1000],
		"told 0 years, given 0 + 1000 (C3-3)")


# ------------------------------------------------------------- the losses --

func test_a_loss_under_reload_allowed_waits_at_the_door() -> void:
	var player := _player()
	assert_true(FinalBattle.door(player), "the checkpoint is written at the door")
	var settled := FinalBattle.settle(player, _report(DuelReport.LOSS, [10, 400], [0, 250]))
	assert_false(settled["won"])
	assert_eq(String(settled["outcome"]), FinalBattle.FAILED_END)
	assert_true(settled["reload"], "the adventure waits at the door")
	assert_eq(settled["score"], 0, "no score for a battle lost")
	assert_eq(String(settled["journal"]), "Lost to an Arzakon")
	assert_eq([_last_line(player)["won"], _last_line(player)["final"]], [false, true])
	assert_eq(player.ended, "", "the adventure goes on")
	assert_true(player.at_door)
	assert_eq(player.final_attempts, 1, "the attempt written in the record")
	assert_eq(player.final, {})
	assert_eq(String(player.portal["state"]), FinalBattle.PORTAL_OPEN, "the portal still open")
	FinalBattle.settle(player, _report(DuelReport.LOSS, [10, 400], [0, 10]))
	assert_eq(player.final_attempts, 2)
	var won := FinalBattle.settle(player, _report(DuelReport.WIN, [10, 400], [4, 0]), false, {}, WHEN)
	assert_eq(int(player.final["attempts"]), 2, "the win remembers the battles lost before it")
	assert_eq(won["score"], 130 + 4000)


func test_a_loss_under_one_life_closes_the_adventure() -> void:
	var player := _player()
	player.life_rule = AdventurePlayer.LIFE_ONE
	assert_true(FinalBattle.door(player), "saved at the door: the battle begun")
	assert_true(player.at_door)
	assert_eq(HallOfFame.one_life_state(player.adventure_id), HallOfFame.BEGUN, "marked outside the save")
	var settled := FinalBattle.settle(player, _report(DuelReport.LOSS, [10, 400], [0, 250]), false, {}, WHEN)
	assert_false(settled["reload"])
	assert_eq(player.ended, AdventurePlayer.ENDED_FAILED)
	assert_false(player.at_peace())
	assert_false(player.at_door)
	assert_eq(player.final_attempts, 0)
	assert_eq(String(player.final["result"]), "failed")
	assert_false(player.final.has("score"), "a failed adventure has no score")
	assert_eq(String(player.final["life_rule"]), AdventurePlayer.LIFE_ONE)
	assert_eq(HallOfFame.one_life_state(player.adventure_id), HallOfFame.FAILED, "the mark: failed")
	assert_false(FinalBattle.door(player), "an ended adventure has no door")


func test_a_draw_a_concession_or_no_result_is_no_win() -> void:
	var drawn := _player()
	var settled := FinalBattle.settle(drawn, _report(DuelReport.DRAW, [10, 400], [3, 3]))
	assert_eq([settled["result"], settled["won"]], [DuelReport.DRAW, false], "a draw is not a win")
	assert_true(bool(_last_line(drawn)["draw"]))
	assert_eq(String(_last_line(drawn)["text"]), "Lost to an Arzakon")
	var conceded := _player()
	settled = FinalBattle.settle(conceded, _report(DuelReport.WIN, [10, 400], [3, 0]), true)
	assert_eq([settled["result"], settled["won"]], [DuelReport.LOSS, false], "a concession is a loss")
	var unfinished := _player()
	settled = FinalBattle.settle(unfinished, _report(DuelReport.WIN, [10, 400], [3, 0], false))
	assert_eq([settled["result"], settled["won"]], [DuelReport.DRAW, false], "an unfinished duel: no result")
	var none := _player()
	settled = FinalBattle.settle(none, null)
	assert_eq([settled["result"], settled["won"], settled["lives_end"]], [DuelReport.LOSS, false, [0, 0]])
	assert_eq(none.final_attempts, 1)


func test_as_played_every_result_plays_the_win() -> void:
	var player := _player(3)
	var played := {"result": FinalBattle.AS_PLAYED, "years": FinalBattle.AS_PLAYED, "base": FinalBattle.AS_PLAYED}
	var settled := FinalBattle.settle(player, _report(DuelReport.LOSS, [10, 400], [0, 400]), false, played)
	assert_true(settled["won"], "1997 never read the result (dE:1063)")
	assert_eq(String(settled["journal"]), "Defeated an Arzakon")
	assert_eq(settled["score"], 130 - 3000, "(100 − 400) · 10 on the unfloored base")
	assert_eq(player.ended, AdventurePlayer.ENDED_WON)


# ------------------------------------------------------- the door, the portal --

func test_the_door_and_the_portal() -> void:
	var player := _player()
	assert_eq(FinalBattle.fifth_castle(player), 2, "green's castle, the wizard beaten last")
	var portal := FinalBattle.open_portal(player)
	assert_eq(portal, {"x": 31, "y": 31, "state": FinalBattle.PORTAL_OPEN}, "the free land nearest the middle")
	assert_true(FinalBattle.portal_at(player, Vector2i(31, 31)))
	assert_false(FinalBattle.portal_at(player, Vector2i(31, 32)))
	assert_true(FinalBattle.portal_open(player))
	assert_eq(FinalBattle.portal_name(player), "Arzakon's Portal")
	player.portal["x"] = 30
	FinalBattle.door(player)
	assert_eq(int(player.portal["x"]), 30, "a portal standing is kept")
	FinalBattle.settle(player, _report(DuelReport.WIN, [10, 400], [4, 0]))
	assert_false(FinalBattle.portal_open(player), "petrified")
	assert_eq(FinalBattle.portal_name(player), "Arzakon's Petrified Portal")
	var nobody := AdventurePlayer.new()
	assert_eq(FinalBattle.fifth_castle(nobody), -1)
	assert_eq(FinalBattle.portal_name(nobody), "")


# ------------------------------------------------------------- the save --

func test_the_end_is_saved_and_read_back() -> void:
	var player := _player()
	player.life_rule = AdventurePlayer.LIFE_ONE
	FinalBattle.door(player)
	FinalBattle.settle(player, _report(DuelReport.WIN, [13, 400], [2, 0]), false, {}, WHEN)
	var data := player.to_dict()
	assert_eq(String(data["hero"]["life_rule"]), AdventurePlayer.LIFE_ONE)
	assert_eq(int(data["end"]["score_so_far"]), 130, "for a reader of the file")
	var back := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(data)))
	assert_eq(back.life_rule, AdventurePlayer.LIFE_ONE)
	assert_eq(back.ended, AdventurePlayer.ENDED_WON)
	assert_eq(back.final, player.final)
	assert_eq(back.portal, player.portal)
	assert_eq([back.final_attempts, back.at_door], [0, false])


func test_the_door_is_saved_while_the_adventure_goes_on() -> void:
	var player := _player()
	FinalBattle.door(player)
	FinalBattle.settle(player, _report(DuelReport.LOSS, [10, 400], [0, 99]))
	var back := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	assert_true(back.at_door, "loading it puts the hero back at the door")
	assert_eq(back.final_attempts, 1)
	assert_eq(back.ended, "")
	assert_eq(String(back.portal["state"]), FinalBattle.PORTAL_OPEN)


func test_a_save_from_before_part_c_or_a_damaged_end_reads_its_defaults() -> void:
	var player := _player()
	var data := player.to_dict()
	data.erase("end")
	(data["hero"] as Dictionary).erase("life_rule")
	var old := AdventurePlayer.from_dict(data)
	assert_eq([old.ended, old.final, old.final_attempts, old.at_door, old.portal, old.life_rule],
		["", {}, 0, false, {}, AdventurePlayer.LIFE_RELOAD])
	data["end"] = {"ended": "maybe", "final": {"score": "lots", "result": 3, "days": 12.0,
		"lives_end": [1, "x"]}, "final_attempts": -4, "at_door": "yes",
		"portal": {"x": 99, "y": 2, "state": "open"}}
	data["hero"]["life_rule"] = "nine lives"
	var odd := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(data)))
	assert_eq([odd.ended, odd.final, odd.final_attempts, odd.at_door, odd.portal, odd.life_rule],
		["", {"days": 12}, 0, false, {}, AdventurePlayer.LIFE_RELOAD], "each field of its kind, or its default")
	data["end"] = {"ended": "won", "at_door": true, "portal": {"x": 5, "y": 6, "state": "melted"}}
	var won := AdventurePlayer.from_dict(data)
	assert_eq([won.ended, won.at_door, won.portal], ["won", false, {}], "an ended adventure has no door")


func test_the_load_list_shows_the_end() -> void:
	var player := _player()
	assert_ne(player.autosave(), "")
	var line := AdventurePlayer.save_at(player.save_path())
	assert_eq([line["ended"], line["score"], line["life_rule"]], ["", 0, AdventurePlayer.LIFE_RELOAD])
	FinalBattle.settle(player, _report(DuelReport.WIN, [13, 400], [2, 0]), false, {}, WHEN)
	assert_ne(player.autosave(), "")
	line = AdventurePlayer.save_at(player.save_path())
	assert_eq([line["ended"], line["score"]], ["won", 4130], "won, with its score")
	var failed := _player()
	failed.adventure_id = "Ysolde-Starfall-0000f00f"
	failed.life_rule = AdventurePlayer.LIFE_ONE
	FinalBattle.settle(failed, _report(DuelReport.LOSS, [13, 400], [0, 3]))
	assert_ne(failed.autosave(), "")
	line = AdventurePlayer.save_at(failed.save_path())
	assert_eq([line["ended"], line["score"], line["life_rule"]], ["failed", 0, AdventurePlayer.LIFE_ONE])
	assert_eq(AdventurePlayer.list_saves().size(), 2)


# ------------------------------------------------------ the Embark's rule --

func test_the_final_battles_rule_goes_from_the_embark_to_the_adventure() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Ysolde Starfall"
	setup.seed_text = "2468"
	assert_eq(setup.life_rule, AdventurePlayer.LIFE_RELOAD, "reload allowed by default")
	assert_eq(String(setup.resolve({})["life_rule"]), AdventurePlayer.LIFE_RELOAD)
	setup.life_rule = AdventurePlayer.LIFE_ONE
	var record := setup.resolve({})
	assert_eq(String(record["life_rule"]), AdventurePlayer.LIFE_ONE, "the record carries it")
	setup.life_rule = "nine lives"
	assert_eq(String(setup.resolve({})["life_rule"]), AdventurePlayer.LIFE_RELOAD, "an odd one: the default")
	record.erase("life_rule")
	assert_eq(AdventurePlayer.life_rule_of(record.get("life_rule")), AdventurePlayer.LIFE_RELOAD,
		"a record from before the choice")
	assert_eq(AdventurePlayer.life_rule_of(AdventurePlayer.LIFE_ONE), AdventurePlayer.LIFE_ONE)


func test_the_final_battles_rule_is_remembered_for_the_next_embark() -> void:
	AdventureSetup.forget()
	var setup := AdventureSetup.new()
	setup.life_rule = AdventurePlayer.LIFE_ONE
	setup.remember()
	assert_eq(AdventureSetup.restore([] as Array[String]).life_rule, AdventurePlayer.LIFE_ONE)
	AdventureSetup.forget()
	assert_eq(AdventureSetup.restore([] as Array[String]).life_rule, AdventurePlayer.LIFE_RELOAD,
		"forgotten: the default")
