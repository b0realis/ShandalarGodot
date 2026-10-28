extends GutTest
## PART C, W8 — THE OWNER'S RULINGS OF 2026-10-28 IN [FinalBattle]: the
## journal tells of Arzakon's portal only when the hero sees it — "Return
## to Shandalar first", or back from the door after a lost battle — once,
## never for "Face me now" (the portal then stands silently, for a reload
## at the door; [method FinalBattle.door], [method FinalBattle.tell_portal]);
## and "Fight or return": under "Reload allowed" the hero at the door may
## turn back, the portal staying open and pointed to ([method
## FinalBattle.leave_door]). Headless, a small world of its own; the Hall's
## file the tests' own.

const HALL := "user://hall_tests_pc_w8_door"


func before_each() -> void:
	HallOfFame.file = HALL + "/hall_of_fame.json"


func after_each() -> void:
	HallOfFame.file = HallOfFame.FILE
	var dir := DirAccess.open(HALL)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(HALL)


## A hero of a small world of plains (towns, the five castles as encounter
## slots 0–4) who has beaten all five wizards.
func _player() -> AdventurePlayer:
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
	player.adventure_id = "Door-Test-0000w8w8"
	player.name = "Ysolde"
	player.position = Vector2i(26 * 32 + 16, 40 * 32 + 16)
	for hue in AdventurePlayer.COLORS:
		player.defeated_wizards.append(hue)
	return player


func _opened_lines(player: AdventurePlayer) -> int:
	var count := 0
	for entry in player.journal:
		if String((entry as Dictionary).get("text", "")).begins_with("Arzakon's Portal opened"):
			count += 1
	return count


func _won() -> DuelReport:
	var report := DuelReport.new()
	report.finished = true
	report.result = DuelReport.WIN
	report.lives_start = [20, 200] as Array[int]
	report.lives_end = [5, 0] as Array[int]
	return report


func test_facing_him_at_once_tells_nothing_of_the_portal() -> void:
	var player := _player()
	assert_true(FinalBattle.door(player))
	assert_true(FinalBattle.portal_open(player), "the portal stands, for a reload at the door")
	assert_eq(_opened_lines(player), 0, "the journal says nothing of it")
	assert_false(FinalBattle.portal_told(player))
	FinalBattle.settle(player, _won())
	assert_eq(_opened_lines(player), 0, "nor the win")
	var said := FinalBattle.roam(player)
	assert_string_starts_with(said, "Arzakon's Portal turned to stone")
	assert_eq(_opened_lines(player), 0, "walking on: the stone's line alone")


func test_returning_first_tells_it_once() -> void:
	var player := _player()
	FinalBattle.open_portal(player)
	assert_eq(_opened_lines(player), 1)
	assert_true(FinalBattle.portal_told(player))
	assert_eq(FinalBattle.tell_portal(player), "", "once")
	FinalBattle.door(player)
	assert_eq(_opened_lines(player), 1)


func test_back_from_the_door_after_a_loss() -> void:
	var player := _player()
	FinalBattle.door(player)
	var lost := _won()
	lost.result = DuelReport.LOSS
	FinalBattle.settle(player, lost)
	assert_true(player.at_door, "Reload allowed: kept at the door")
	var said := FinalBattle.leave_door(player)
	assert_string_starts_with(said, "Arzakon's Portal opened in the middle of Shandalar")
	assert_false(player.at_door, "off the door: a reload opens on the world")
	assert_true(FinalBattle.portal_open(player), "the portal stays open")
	assert_eq(FinalBattle.portal_target(player)["kind"], FinalBattle.PORTAL_KIND, "pointed to")
	assert_ne(FinalBattle.portal_line(player), "", "the panel's line")
	var line: Dictionary = player.journal.back()
	assert_eq([line["x"], line["y"]], [FinalBattle.portal_tile_of(player).x * 32 + 16,
		FinalBattle.portal_tile_of(player).y * 32 + 16], "pinned to the portal on the journal's map")
	FinalBattle.door(player)
	assert_eq(FinalBattle.leave_door(player), "", "back again: told already")
	assert_eq(_opened_lines(player), 1)


func test_no_turning_back_where_there_is_no_door() -> void:
	var player := _player()
	assert_eq(FinalBattle.leave_door(player), "", "not at the door")
	var one := _player()
	one.life_rule = AdventurePlayer.LIFE_ONE
	FinalBattle.door(one)
	assert_eq(FinalBattle.leave_door(one), "", "One life: the door is the battle begun")
	assert_true(one.at_door)
	var won := _player()
	FinalBattle.door(won)
	FinalBattle.settle(won, _won())
	won.at_door = true
	assert_eq(FinalBattle.leave_door(won), "", "an adventure ended")
