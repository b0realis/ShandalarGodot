extends GutTest
## THE ADVENTURER (2026-10-22): [AdventurePlayer] keeps what the 1997 save
## keeps — the hero, what they carry, their record, the clocks and the
## world as it stands — starts a new hero as 1.3 does, and saves and loads
## it as readable JSON, by name and a hash of the moment it began.

const FOLDER := "user://adventure_tests"


func before_each() -> void:
	AdventurePlayer.saves_folder = FOLDER
	_clear()


func after_each() -> void:
	_clear()
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _clear() -> void:
	var dir := DirAccess.open(FOLDER)
	if dir == null:
		return
	for file_name in dir.get_files():
		dir.remove(file_name)


func _record(name := "Sable Ashwhisper", color := "red", difficulty := 1, seed_text := "12345") -> Dictionary:
	var setup := AdventureSetup.new()
	setup.player_name = name
	setup.color = color
	setup.difficulty = difficulty
	setup.walker = "female"
	setup.seed_text = seed_text
	return setup.resolve({})


func _begin(record: Dictionary) -> AdventurePlayer:
	return AdventurePlayer.begin(record, AdventureSetup.make_world(record))


func test_a_new_hero_starts_as_in_1997() -> void:
	var record := _record()
	var world := AdventureSetup.make_world(record)
	var fresh := world.fingerprint()
	var player := AdventurePlayer.begin(record, world)
	assert_eq(player.name, "Sable Ashwhisper")
	assert_eq([player.color, player.difficulty, player.walker], ["red", 1, "female"])
	assert_eq(player.gold, 200, "(5 − difficulty) × 50")
	assert_eq(player.food, 50)
	assert_eq(player.amulet_count(), 3, "one of the colour and (3 − difficulty) more")
	assert_gte(int(player.amulets["red"]), 1, "one of the hero's colour")
	assert_eq(player.world_magics, ["Staff of Thunder"] as Array[String], "the colour's first World Magic")
	assert_eq(player.position, world.start, "where the world puts the hero")
	assert_eq(player.made_fingerprint, fresh, "the world as it was made")
	assert_true(world.is_explored(world.start_tile().x, world.start_tile().y), "the hero sees around them")
	# The two extra amulets were drawn on the adventure's dice, after the world's.
	var dice := MsvcRandom.new(world.rand_state)
	dice.below(5)
	dice.below(5)
	assert_eq(player.dice, dice.state)
	assert_eq(player.cards, [], "the starting deck waits for the 1997 rarities")
	assert_eq(player.duel_record(), {"won": 0, "lost": 0})
	assert_eq(player.mana_links, [] as Array[int], "no mana linked yet")


func test_an_adventure_is_named_by_its_hero_and_a_hash_of_the_moment() -> void:
	var id := AdventurePlayer.make_id("Sable Ashwhisper", 1761143437000)
	assert_true(id.begins_with("Sable-Ashwhisper-"), id)
	assert_eq(id.length(), "Sable-Ashwhisper-".length() + 8, "eight hex digits")
	assert_eq(AdventurePlayer.make_id("Sable Ashwhisper", 1761143437000), id, "the same moment, the same name")
	assert_ne(AdventurePlayer.make_id("Sable Ashwhisper", 1761143437001), id, "another moment, another")
	assert_true(AdventurePlayer.make_id("Šime Ćuk", 1).begins_with("ime-uk-"), "only plain letters in a file name")
	assert_true(AdventurePlayer.make_id("", 1).begins_with("hero-"))


func test_the_autosave_round_trips_everything() -> void:
	var player := _begin(_record())
	player.figure_colors = {"hair": "blond", "pants": "navy"}
	player.gold = 123
	player.journal.append({"event": "duel", "won": true, "x": 3, "y": 4, "time": 77})
	player.quest = {"kind": "letter", "town": 12}
	player.position += Vector2i(5, -3)
	player.facing = 4
	player.monster_timer = 999
	var path := player.autosave()
	assert_eq(path, FOLDER.path_join(player.adventure_id + ".autosave.json"), "by name and hash")
	assert_true(FileAccess.file_exists(path))
	var back := AdventurePlayer.load_from(path)
	assert_not_null(back, "the save reads back")
	assert_eq(back.to_dict(), player.to_dict(), "every part as it was saved")
	assert_eq(back.world.fingerprint(), player.world.fingerprint(), "the world, explored land and all")
	assert_true(back.world_intact(), "and still the world its recipe makes")
	assert_eq(back.duel_record(), {"won": 1, "lost": 0})


func test_the_saves_are_listed_newest_first() -> void:
	var first := _begin(_record("Ysolde Umbrage", "blue", 0, "1"))
	first.autosave()
	var text := FileAccess.get_file_as_string(first.save_path())
	var data: Dictionary = JSON.parse_string(text)
	data["adventure"]["saved"] = "2000-01-01T00:00:00Z"
	var file := FileAccess.open(first.save_path(), FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var second := _begin(_record("Rufus Dragonsbreath", "green", 3, "2"))
	second.autosave()
	var saves := AdventurePlayer.list_saves()
	assert_eq(saves.size(), 2)
	assert_eq(saves[0]["name"], "Rufus Dragonsbreath", "the newest first")
	assert_eq([saves[0]["color"], saves[0]["difficulty"], saves[0]["seed_text"]], ["green", 3, "2"])
	assert_eq(saves[1]["name"], "Ysolde Umbrage")


func test_a_file_that_is_not_an_adventure_is_refused() -> void:
	assert_null(AdventurePlayer.from_dict({"format": "something else", "version": 1}))
	var data := _begin(_record()).to_dict()
	data["version"] = AdventurePlayer.FORMAT_VERSION + 1
	assert_null(AdventurePlayer.from_dict(data), "a newer save than this game reads")
	data = _begin(_record()).to_dict()
	(data["world"] as Dictionary)["grid"] = ["00"]
	assert_null(AdventurePlayer.from_dict(data), "a broken world")
	assert_null(AdventurePlayer.load_from(FOLDER.path_join("missing.json")))


func test_the_save_reads_as_text() -> void:
	var player := _begin(_record())
	var text := FileAccess.get_file_as_string(player.autosave())
	for part in ['"format": "shandalar-adventure"', '"name": "Sable Ashwhisper"', '"gold": 200',
			'"food": 50', '"world_magics"', '"Staff of Thunder"', '"grid"', '"monster_timer"',
			'"kind": "village"']:
		assert_string_contains(text, part)
	assert_true(text.contains("\n\t"), "set out over lines, indented")
	var data: Dictionary = JSON.parse_string(text)
	assert_eq((data["world"]["grid"] as Array).size(), 128, "the tiles and the roads, a row a line")
	assert_eq(String(data["world"]["grid"][0]).length(), 128, "64 bytes in hex")
