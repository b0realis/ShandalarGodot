extends GutTest
## THE SAVE FILES ON DISK (campaign of 2026-10-23, fixer f6): a save is
## written whole or not at all and the last good one kept beside it
## ([method AdventurePlayer.save]); one odd file hides nothing else
## ([method AdventurePlayer.scan_saves]); the lists read a file again only
## when its bytes changed, and a slot list reads only its own adventure's
## slots ([method SaveSlots.slots_of]); an older save is moved into a free
## slot and deleted only once it is safely there ([method
## SaveSlots.migrate]); the canonical file wins a slot two files claim;
## the autosave carries no slot's name; the journal stops at 1997's 2,000
## lines; and the times are shown on the player's clock.

const FOLDER := "user://adventure_tests_c3_f6_files"


func before_each() -> void:
	AdventurePlayer.saves_folder = FOLDER
	_clear()
	AdventurePlayer.forget_saves()


func after_each() -> void:
	_clear()
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	AdventurePlayer.forget_saves()


func _clear() -> void:
	var dir := DirAccess.open(FOLDER)
	if dir == null:
		return
	for folder_name in dir.get_directories():
		DirAccess.remove_absolute(FOLDER.path_join(folder_name))
	for file_name in dir.get_files():
		dir.remove(file_name)


func _record(hero := "Probe Hero", seed_text := "4242") -> Dictionary:
	var setup := AdventureSetup.new()
	setup.player_name = hero
	setup.color = "green"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = seed_text
	return setup.resolve({})


func _begin(id := "base", hero := "Probe Hero", seed_text := "4242") -> AdventurePlayer:
	var record := _record(hero, seed_text)
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	player.adventure_id = id
	return player


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _data(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _variant(player: AdventurePlayer, id: String, change: Callable) -> String:
	var data: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	data["adventure"]["id"] = id
	change.call(data)
	return JSON.stringify(data, "\t")


# ------------------------------------------------------- h4-1: whole saves --

func test_a_save_that_cannot_be_written_leaves_the_last_good_one() -> void:
	var player := _begin()
	player.gold = 111
	var path := player.autosave()
	assert_ne(path, "")
	# The write cannot land (a folder where the pending file goes, as a
	# full disk or a quota refuses it).
	var pending := Settings.pending_path(path)
	DirAccess.make_dir_recursive_absolute(pending)
	player.gold = 222
	assert_eq(player.autosave(), "", "a save that did not land says so")
	DirAccess.remove_absolute(pending)
	var back := AdventurePlayer.load_from(path)
	assert_not_null(back, "the last good save is still there")
	assert_eq(back.gold, 111, "as it was")
	for file_name in DirAccess.get_files_at(FOLDER):
		assert_false(file_name.contains(".tmp"), "no pending file left behind: " + file_name)


func test_the_last_good_save_is_kept_beside_and_taken_up_when_the_file_is_cut() -> void:
	var player := _begin()
	player.gold = 111
	var path := player.autosave()
	player.gold = 222
	assert_eq(player.autosave(), path)
	var backup := path + AdventurePlayer.BACKUP_TAIL
	assert_true(FileAccess.file_exists(backup), "the save before kept as .bak")
	assert_eq(int(_data(backup)["carried"]["gold"]), 111, "the one before")
	# A disk that filled under an older version cut the file short.
	var whole := FileAccess.get_file_as_string(path)
	_write(path, whole.left(whole.length() / 2))
	var back := AdventurePlayer.load_from(path)
	assert_not_null(back, "the backup is taken up")
	assert_eq(back.gold, 111)
	var saves := AdventurePlayer.list_saves()
	assert_eq(saves.size(), 1, "still listed")
	assert_eq(int(saves[0]["gold"]), 111, "from its backup")
	assert_eq(String(saves[0]["path"]), path, "under the save's own name")


func test_a_damaged_save_is_never_kept_over_a_good_backup() -> void:
	var player := _begin()
	player.gold = 111
	var path := player.autosave()
	player.gold = 222
	player.autosave()
	var whole := FileAccess.get_file_as_string(path)
	_write(path, whole.left(100))
	player.gold = 333
	assert_eq(player.autosave(), path)
	assert_eq(int(_data(path + AdventurePlayer.BACKUP_TAIL)["carried"]["gold"]), 111,
		"the cut file did not take the good backup's place")
	assert_eq(AdventurePlayer.load_from(path).gold, 333)


# ----------------------------------------------- h4-2: odd files beside --

func test_one_odd_file_hides_no_other_save() -> void:
	var player := _begin()
	player.autosave()
	for slot in [1, 2, 3]:
		SaveSlots.save_into(player, slot, "Named %d" % slot)
	var text := FileAccess.get_file_as_string(player.save_path())
	var odd := {
		"hero_string": _variant(player, "hero_string", func(d: Dictionary) -> void: d["hero"] = "Bob"),
		"adventure_array": _variant(player, "adventure_array", func(d: Dictionary) -> void: d["adventure"] = []),
		"clocks_array": _variant(player, "clocks_array", func(d: Dictionary) -> void: d["clocks"] = [1, 2]),
		"carried_string": _variant(player, "carried_string", func(d: Dictionary) -> void: d["carried"] = "x"),
		"world_string": _variant(player, "world_string", func(d: Dictionary) -> void: d["world"] = "x"),
		"cut": text.left(text.length() / 2),
		"empty": "",
	}
	for id in odd:
		_write(FOLDER.path_join("%s.autosave.json" % id), odd[id])
	var found := AdventurePlayer.scan_saves()
	var mine: Array = (found["saves"] as Array).filter(func(s: Dictionary) -> bool: return s["id"] == "base")
	assert_eq(mine.size(), 4, "the autosave and three slots, all listed")
	assert_eq(int(found["unreadable"]), odd.size(), "each odd file counted, none shown")
	var names: Array = SaveSlots.slots_of("base").map(func(s: Dictionary) -> String: return s["name"])
	assert_eq(names.slice(0, 4), ["Named 1", "Named 2", "Named 3", SaveSlots.EMPTY], "the slots as they are")


func test_a_slot_whose_file_cannot_be_read_is_not_shown_empty() -> void:
	var player := _begin()
	var path := SaveSlots.save_into(player, 2, "Named 2")
	_write(path, "{ not a save")
	var two: Dictionary = SaveSlots.slots_of("base")[1]
	assert_false(bool(two["empty"]), "a file is there")
	assert_true(bool(two["damaged"]))
	assert_eq(String(two["name"]), SaveSlots.DAMAGED)


# ----------------------------------------------- h5-7 / h4-8: the cost --

func test_the_lists_read_a_file_again_only_when_it_changed() -> void:
	var player := _begin()
	player.autosave()
	SaveSlots.save_into(player, 1, "One")
	AdventurePlayer.forget_saves()
	var before := AdventurePlayer.files_parsed
	assert_eq(AdventurePlayer.list_saves().size(), 2)
	assert_eq(AdventurePlayer.files_parsed - before, 2, "each file read once")
	before = AdventurePlayer.files_parsed
	AdventurePlayer.list_saves()
	SaveSlots.slots_of("base")
	assert_eq(AdventurePlayer.files_parsed - before, 0, "and not again while it is unchanged")
	player.gold = 999
	player.autosave()
	before = AdventurePlayer.files_parsed
	var saves := AdventurePlayer.list_saves()
	assert_eq(AdventurePlayer.files_parsed - before, 0, "a save just written is known as written")
	assert_eq(int(saves.filter(func(s: Dictionary) -> bool: return s["slot"] == 0)[0]["gold"]), 999)
	# Changed behind the game's back, same length, same second: read again.
	var data := _data(player.save_path())
	data["carried"]["gold"] = 998
	_write(player.save_path(), JSON.stringify(data, "\t"))
	saves = AdventurePlayer.list_saves()
	assert_eq(int(saves.filter(func(s: Dictionary) -> bool: return s["slot"] == 0)[0]["gold"]), 998)


func test_a_slot_list_reads_only_its_own_adventure() -> void:
	var player := _begin()
	SaveSlots.save_into(player, 1, "One")
	SaveSlots.save_into(player, 4, "Four")
	for i in 3:
		var other := _begin("other%d" % i, "Other %d" % i, "77")
		other.autosave()
		SaveSlots.save_into(other, 1, "Theirs")
	AdventurePlayer.forget_saves()
	var before := AdventurePlayer.files_parsed
	var rows := SaveSlots.slots_of("base")
	assert_eq(AdventurePlayer.files_parsed - before, 2, "its two slot files, no other")
	assert_eq([rows[0]["name"], rows[3]["name"]], ["One", "Four"])


# ----------------------------------------------------- h4-11: migrate --

func test_an_older_save_moves_to_the_first_free_slot_and_goes_only_once_it_is_there() -> void:
	var player := _begin()
	var data: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	data["adventure"]["id"] = "legacy_taken"
	data["carried"]["gold"] = 4321
	_write(FOLDER.path_join("legacy_taken.save.json"), JSON.stringify(data))
	data["carried"]["gold"] = 5
	data["adventure"]["slot_name"] = "Mine"
	_write(FOLDER.path_join("legacy_taken.slot01.json"), JSON.stringify(data))
	SaveSlots.migrate(FOLDER)
	assert_false(FileAccess.file_exists(FOLDER.path_join("legacy_taken.save.json")), "moved")
	var one := AdventurePlayer.load_from(FOLDER.path_join("legacy_taken.slot01.json"))
	assert_eq([one.gold, one.slot_name], [5, "Mine"], "slot 1 kept as it was")
	var two := AdventurePlayer.load_from(FOLDER.path_join("legacy_taken.slot02.json"))
	assert_not_null(two, "the older save in the first free slot")
	assert_eq([two.gold, two.slot_name], [4321, SaveSlots.LEGACY_NAME])


func test_an_older_save_that_cannot_be_read_or_written_is_left_as_it_is() -> void:
	var player := _begin()
	var data: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	data["adventure"]["id"] = "legacy_newer"
	data["version"] = AdventurePlayer.FORMAT_VERSION + 1
	_write(FOLDER.path_join("legacy_newer.save.json"), JSON.stringify(data))
	var text := JSON.stringify(player.to_dict())
	_write(FOLDER.path_join("legacy_cut.save.json"), text.left(text.length() - 10))
	data["version"] = 1
	data["adventure"]["id"] = "legacy_blocked"
	_write(FOLDER.path_join("legacy_blocked.save.json"), JSON.stringify(data))
	var pending := Settings.pending_path(FOLDER.path_join("legacy_blocked.slot01.json"))
	DirAccess.make_dir_recursive_absolute(pending)
	SaveSlots.migrate(FOLDER)
	DirAccess.remove_absolute(pending)
	for file_name in ["legacy_newer.save.json", "legacy_cut.save.json", "legacy_blocked.save.json"]:
		assert_true(FileAccess.file_exists(FOLDER.path_join(file_name)), file_name + " kept")
	assert_false(FileAccess.file_exists(FOLDER.path_join("legacy_blocked.slot01.json")))
	SaveSlots.migrate(FOLDER)
	assert_false(FileAccess.file_exists(FOLDER.path_join("legacy_blocked.save.json")),
		"moved once its slot could be written")
	assert_eq(AdventurePlayer.load_from(FOLDER.path_join("legacy_blocked.slot01.json")).slot_name,
		SaveSlots.LEGACY_NAME)


# ----------------------------------------- h4-12: two files, one slot --

func test_the_canonical_file_wins_a_slot_two_files_claim() -> void:
	var player := _begin()
	player.gold = 1
	SaveSlots.save_into(player, 1, "Named 1")
	_write(FOLDER.path_join("copy-of-base.slot01.json"),
		FileAccess.get_file_as_string(FOLDER.path_join("base.slot01.json")))
	player.gold = 4242
	SaveSlots.save_into(player, 1, "Fresh one")
	var one: Dictionary = SaveSlots.slots_of("base")[0]
	assert_eq(String(one["name"]), "Fresh one")
	assert_eq(String(one["path"]).get_file(), "base.slot01.json")
	var listed := AdventurePlayer.list_saves().filter(func(s: Dictionary) -> bool:
		return s["id"] == "base" and int(s["slot"]) == 1)
	assert_eq(listed.size(), 1, "one line for the slot")
	assert_eq(String(listed[0]["slot_name"]), "Fresh one")


# ------------------------------------------ h6-9: the autosave's name --

func test_the_autosave_carries_no_slot_s_name() -> void:
	var player := _begin()
	SaveSlots.save_into(player, 2, "Before the swamp")
	var path := player.autosave()
	assert_eq(String(_data(path)["adventure"]["slot_name"]), "", "the autosave is the autosave")
	assert_eq(String(_data(FOLDER.path_join("base.slot02.json"))["adventure"]["slot_name"]), "Before the swamp")
	var auto := AdventurePlayer.list_saves().filter(func(s: Dictionary) -> bool: return s["slot"] == 0)
	assert_eq(String(auto[0]["slot_name"]), "")


# ------------------------------------------- h4-6: the journal's limit --

func test_the_journal_stops_at_ten_thousand_lines() -> void:
	var player := _begin()
	# 1997's AddJournalEntry stopped at g_journal_entry_count < 2000; the
	# owner asked for more (2026-10-23): five times that.
	assert_eq(AdventurePlayer.JOURNAL_MOST, 10000)
	for i in AdventurePlayer.JOURNAL_MOST + 5:
		player.log_event("visit", "Visited %d" % i)
	assert_eq(player.journal.size(), AdventurePlayer.JOURNAL_MOST)
	assert_eq(String(player.journal.back()["text"]), "Visited 9999", "the lines kept; no more written")


func test_a_longer_journal_saved_before_is_kept_whole() -> void:
	var player := _begin()
	for i in AdventurePlayer.JOURNAL_MOST + 10:
		player.journal.append({"event": "visit", "text": "Visited %d" % i})
	var back := AdventurePlayer.load_from(player.autosave())
	assert_eq(back.journal.size(), AdventurePlayer.JOURNAL_MOST + 10, "nothing of a save is lost")
	back.log_event("visit", "One more")
	assert_eq(back.journal.size(), AdventurePlayer.JOURNAL_MOST + 10, "but no more written")


# ---------------------------------------------- h4-7: the player's clock --

func test_a_save_s_time_is_shown_on_the_player_s_clock() -> void:
	assert_eq(AdventurePlayer.time_at("2026-10-23T09:07:00Z", 120), "2026-10-23 11:07", "Zagreb in summer")
	assert_eq(AdventurePlayer.time_at("2026-12-31T23:30:00Z", 60), "2027-01-01 00:30", "over the year's end")
	assert_eq(AdventurePlayer.time_at("2026-10-23T09:07:00Z", -300), "2026-10-23 04:07")
	assert_eq(AdventurePlayer.time_at("", 120), "")
	assert_eq(AdventurePlayer.time_at("not a time", 120), "not a time", "shown as written")
	var bias := int(Time.get_time_zone_from_system()["bias"])
	assert_eq(AdventurePlayer.local_time("2026-10-23T09:07:00Z"), AdventurePlayer.time_at("2026-10-23T09:07:00Z", bias))
