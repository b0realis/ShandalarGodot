extends GutTest
## PART C, W3 — THE HALL OF FAME ([HallOfFame]): a won adventure's line
## (name, face, colour, difficulty, score, days, wins, date …), the file
## written whole and read field by field, best first (score, then the
## harder difficulty, the fewer days, the earlier win), one line an
## adventure keeping its better, at most a hundred lines, and a file that
## cannot be read set aside, never written over. The tests' own file — never
## the player's.

const FOLDER := "user://hall_tests_pc_w3"
const AT := FOLDER + "/hall_of_fame.json"


func before_each() -> void:
	HallOfFame.file = AT
	_clear()


func after_each() -> void:
	_clear()
	HallOfFame.file = HallOfFame.FILE


func _clear() -> void:
	var dir := DirAccess.open(FOLDER)
	if dir == null:
		return
	for file_name in dir.get_files():
		dir.remove(file_name)


## A hero who has won, as [FinalBattle.settle] leaves them.
func _won(id: String, score: int, difficulty := 1, days := 30, date := "2026-10-27T20:00:00Z") -> AdventurePlayer:
	var player := AdventurePlayer.new()
	player.adventure_id = id
	player.name = "Hero " + id
	player.portrait = "keleena"
	player.color = "blue"
	player.difficulty = difficulty
	player.world_seed_text = "2468"
	player.ended = AdventurePlayer.ENDED_WON
	player.final = {"result": "won", "score": score, "days": days, "wins": 42, "date": date, "attempts": 1}
	return player


func test_a_won_adventures_line() -> void:
	assert_eq(HallOfFame.entry_of(AdventurePlayer.new()), {}, "an adventure not won has none")
	assert_eq(HallOfFame.entry_of(null), {})
	var line := HallOfFame.entry_of(_won("a-1", 4160, 3, 40))
	assert_eq(line, {"id": "a-1", "name": "Hero a-1", "portrait": "keleena", "color": "blue",
		"difficulty": 3, "score": 4160, "days": 40, "wins": 42, "date": "2026-10-27T20:00:00Z",
		"seed_text": "2468", "life_rule": AdventurePlayer.LIFE_RELOAD, "attempts": 1})


func test_the_hall_is_written_and_read_best_first() -> void:
	assert_eq(HallOfFame.entries(), [] as Array[Dictionary], "no file: an empty Hall")
	assert_eq(HallOfFame.add(_won("a", 500)), 1)
	assert_eq(HallOfFame.add(_won("b", 900)), 1, "a better one first")
	assert_eq(HallOfFame.add(_won("c", 700)), 2)
	assert_eq(HallOfFame.add(AdventurePlayer.new()), 0, "no win, no line")
	var ids := HallOfFame.entries().map(func(e: Dictionary) -> String: return e["id"])
	assert_eq(ids, ["b", "c", "a"])
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AT))
	assert_eq([data["format"], int(data["version"])], [HallOfFame.FORMAT, 1], "the file names itself")
	assert_false(FileAccess.file_exists(HallOfFame.FILE), "the tests' own file, never the Hall's")


func test_ties_go_to_the_harder_the_quicker_the_earlier() -> void:
	HallOfFame.add(_won("easy", 1000, 0, 10))
	HallOfFame.add(_won("hard", 1000, 3, 90))
	HallOfFame.add(_won("slow", 1000, 3, 95))
	HallOfFame.add(_won("late", 1000, 3, 90, "2026-11-01T00:00:00Z"))
	var ids := HallOfFame.entries().map(func(e: Dictionary) -> String: return e["id"])
	assert_eq(ids, ["hard", "late", "slow", "easy"])


func test_one_line_an_adventure_its_better_kept() -> void:
	HallOfFame.add(_won("same", 800))
	HallOfFame.add(_won("other", 600))
	assert_eq(HallOfFame.add(_won("same", 400)), 1, "a worse win of the same adventure: its line stands")
	assert_eq(HallOfFame.entries().size(), 2)
	assert_eq(int(HallOfFame.entries()[0]["score"]), 800)
	assert_eq(HallOfFame.add(_won("same", 1200)), 1, "a better one takes its place")
	assert_eq(HallOfFame.entries().size(), 2)
	assert_eq(int(HallOfFame.entries()[0]["score"]), 1200)


func test_at_most_a_hundred_lines() -> void:
	for i in HallOfFame.MOST:
		HallOfFame.add(_won("p%03d" % i, 1000 + i))
	assert_eq(HallOfFame.entries().size(), HallOfFame.MOST)
	assert_eq(HallOfFame.add(_won("low", 5)), 0, "below a full Hall: no place")
	assert_eq(HallOfFame.place_of(HallOfFame.entries(), "low"), 0)
	assert_eq(HallOfFame.add(_won("high", 5000)), 1)
	var entries := HallOfFame.entries()
	assert_eq(entries.size(), HallOfFame.MOST, "the lowest let go")
	assert_eq(HallOfFame.place_of(entries, "p000"), 0)


func test_lines_are_read_field_by_field() -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var file := FileAccess.open(AT, FileAccess.WRITE)
	file.store_string(JSON.stringify({"format": HallOfFame.FORMAT, "version": 1, "entries": [
		{"name": "Whole", "score": 300, "difficulty": 9, "days": -3, "color": "mauve", "life_rule": "x"},
		{"name": "", "score": 900}, {"name": "No score"}, "not a line", {"name": "Second", "score": 100.0}]}))
	file.close()
	var entries := HallOfFame.entries()
	assert_eq(entries.size(), 2, "no name or no score: not a line")
	assert_eq([entries[0]["name"], entries[0]["difficulty"], entries[0]["days"], entries[0]["color"],
		entries[0]["life_rule"], entries[0]["id"]], ["Whole", 3, 0, "", AdventurePlayer.LIFE_RELOAD, ""])
	assert_eq([entries[1]["name"], entries[1]["score"]], ["Second", 100])


func test_a_file_that_cannot_be_read_is_set_aside_not_written_over() -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var file := FileAccess.open(AT, FileAccess.WRITE)
	file.store_string("{ this is no hall")
	file.close()
	assert_eq(HallOfFame.entries(), [] as Array[Dictionary])
	assert_eq(HallOfFame.add(_won("a", 500)), 1)
	assert_eq(FileAccess.get_file_as_string(AT + ".bad"), "{ this is no hall", "kept aside")
	file = FileAccess.open(AT, FileAccess.WRITE)
	file.store_string(JSON.stringify({"format": "something else", "version": 1, "entries": []}))
	file.close()
	assert_eq(HallOfFame.add(_won("b", 600)), 1)
	assert_true(FileAccess.file_exists(AT + ".bad2"), "another format: aside too, beside the first")
	file = FileAccess.open(AT, FileAccess.WRITE)
	file.store_string(JSON.stringify({"format": HallOfFame.FORMAT, "version": 2, "entries": []}))
	file.close()
	assert_eq(HallOfFame.entries(), [] as Array[Dictionary], "a newer version is not read")


func test_a_hall_that_cannot_be_written_stays_as_it_was() -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var blocker := FileAccess.open(FOLDER + "/blocked", FileAccess.WRITE)
	blocker.store_string("a file where a folder should be")
	blocker.close()
	var at := FOLDER + "/blocked/hall_of_fame.json"
	assert_eq(HallOfFame.add(_won("a", 500), at), 0, "not written: no place")
	assert_eq(HallOfFame.entries(at), [] as Array[Dictionary])
