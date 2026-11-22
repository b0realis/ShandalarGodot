extends GutTest
## THE SAVES AND THE LANDS, DAMAGED (whole-project review of 2026-11-21,
## fixer `saves`): a save's id is safe as a file name; a land's dice, a
## region's name, a quest cut short, a list of places cut short, a switch
## that is no switch and a renamed copy are each read without a script
## error and without losing the save. (Any engine or script error on the
## way fails the run.)

const FOLDER := "user://adventure_tests_review_1121_saves"

var player: AdventurePlayer
var base: Dictionary


func before_all() -> void:
	player = _begin("Probe Hero")
	base = JSON.parse_string(JSON.stringify(player.to_dict()))


func before_each() -> void:
	AdventurePlayer.saves_folder = FOLDER
	_wipe(FOLDER)
	DirAccess.make_dir_recursive_absolute(FOLDER)
	AdventurePlayer.forget_saves()


func after_each() -> void:
	for folder in [FOLDER, AdventureTransfer.STAGING]:
		_wipe(folder)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	AdventurePlayer.forget_saves()


func _wipe(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for file_name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file_name))
	DirAccess.remove_absolute(folder)


func _begin(hero: String) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.player_name = hero
	setup.color = "green"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "4242"
	var record := setup.resolve({})
	return AdventurePlayer.begin(record, AdventureSetup.make_world(record))


## The base save with [param change] made to a copy, as JSON gives it back.
func _changed(change: Callable) -> Dictionary:
	var data: Dictionary = base.duplicate(true)
	change.call(data)
	return JSON.parse_string(JSON.stringify(data))


func _a_town(world: ShandalarWorld) -> int:
	for slot in world.sites.size():
		if int(world.sites[slot]["type"]) == ShandalarWorld.TOWN:
			return slot
	return -1


# ------------------------------------------------------------ 1: the id --

func test_an_id_the_game_made_is_kept() -> void:
	for id in [player.adventure_id, AdventurePlayer.make_id("Ünï cödé!", 7), "plain_one-2", ""]:
		assert_eq(AdventurePlayer.saved_id(id), id)
	assert_true(AdventureTransfer.plain_id(player.adventure_id), "an id as the Embark makes it")


func test_an_id_with_a_path_never_leaves_the_saves_folder() -> void:
	for bad in ["../../outside/x", "a/b", "..", "C:\\x", "dot.ted", "x".repeat(300), 7, null]:
		var back := AdventurePlayer.from_dict(_changed(func(d: Dictionary) -> void: d["adventure"]["id"] = bad))
		assert_not_null(back, "the save still loads")
		var id := back.adventure_id
		assert_true(id == "" or AdventureTransfer.plain_id(id), "%s read as %s" % [str(bad).left(20), id])
		assert_eq(back.save_path().get_base_dir(), FOLDER)
		assert_false(back.save_path().get_file().trim_suffix(".autosave.json").contains("."))
	var same := AdventurePlayer.saved_id("../../outside/x")
	assert_eq(AdventurePlayer.saved_id("../../outside/x"), same, "the same id each time")


func test_the_lists_show_the_safe_id() -> void:
	var data := _changed(func(d: Dictionary) -> void: d["adventure"]["id"] = "../../outside/x")
	var file := FileAccess.open(FOLDER.path_join("odd.autosave.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var saves := AdventurePlayer.list_saves()
	assert_eq(saves.size(), 1)
	assert_eq(String(saves[0]["id"]), AdventurePlayer.saved_id("../../outside/x"))
	assert_true(AdventureTransfer.plain_id(String(saves[0]["id"])))
	var loaded := AdventurePlayer.load_from(String(saves[0]["path"]))
	assert_eq(loaded.autosave().get_base_dir(), FOLDER, "saved again in the saves' folder")


# ---------------------------------------------------- 2: a land's dice --

func test_a_land_whose_dice_is_no_number_is_restored_whole() -> void:
	var hero := AdventurePlayer.from_dict(_changed(func(_d: Dictionary) -> void: pass))
	var region: Dictionary = JSON.parse_string(JSON.stringify(AdventureRegions.snapshot(hero)))
	region["world"]["dice"] = [1, 2]
	region["world"]["monsters"] = []
	region["world"]["shops"] = {}
	hero.monsters = [{"slot": 0, "kind": "lair", "x": 64, "y": 64, "color": 1}]
	hero.shops = {"3": {"cards": ["Shivan Dragon"], "restock": [0]}}
	hero.step = 5
	AdventureRegions.restore(hero, region)
	assert_eq(hero.dice, hero.world.rand_state, "the world's own dice")
	assert_eq(hero.monsters, [], "the land's creatures, not the last land's")
	assert_eq(hero.shops, {}, "nor its shops")
	assert_eq(hero.step, 0)


# -------------------------------------------------- 3: a region's name --

func test_a_region_that_is_no_word_is_refused_quietly() -> void:
	for odd: Variant in [5, 5.5, [], {}, true, null]:
		var data := _changed(func(d: Dictionary) -> void: d["world"]["expansion"] = {"region": odd})
		assert_false(AdventurePlayer.readable(data), "region %s" % str(odd))
		assert_false(bool(AdventureRegions.saved_state(data)["ok"]))
	assert_true(AdventurePlayer.readable(_changed(func(d: Dictionary) -> void:
		d["world"]["expansion"] = {"region": AdventureRegions.MAINLAND})))


# ---------------------------------------------------------- 4: quests --

func test_a_quest_cut_short_is_no_quest() -> void:
	var town := _a_town(player.world)
	for cut in [{"destination": town}, {"type": 0}, {"giver": town, "color": 2}]:
		var back := AdventurePlayer.from_dict(_changed(func(d: Dictionary) -> void:
			d["record"]["quest"] = cut
			d["record"]["quest_offer"] = cut))
		assert_eq(back.quest, {})
		assert_eq(back.quest_offer, {})
		assert_false(Quests.has_quest(back))
		assert_eq(Quests.complete_at(back, town), {})
		assert_eq(Quests.offer_words(back).size(), 0)
	var whole := {"type": 0, "destination": town, "giver": town, "color": 2, "data": 1, "deadline": 900}
	var offer := {"type": 0, "destination": town, "color": 2, "at": town}
	var kept := AdventurePlayer.from_dict(_changed(func(d: Dictionary) -> void:
		d["record"]["quest"] = whole
		d["record"]["quest_offer"] = offer))
	assert_eq(kept.quest, whole, "a whole quest is kept")
	assert_eq(kept.quest_offer, offer, "a whole offer too")


# ---------------------------------------------------------- 5: places --

func test_a_list_of_places_cut_short_is_filled() -> void:
	assert_eq(player.world.sites.size(), AdventureRegions.SITE_SLOTS, "as every world is made")
	for odd: Variant in [[], [{"x": 3, "y": 4, "type": 2, "trade": 1, "status": 0}], "none", null]:
		var back := AdventurePlayer.from_dict(_changed(func(d: Dictionary) -> void: d["world"]["sites"] = odd))
		assert_not_null(back)
		assert_eq(back.world.sites.size(), AdventureRegions.SITE_SLOTS)
		assert_eq(int(back.world.sites[127]["type"]), 0, "an empty place")
		assert_eq(SaveSlots.default_name(back).left(4), "Day ")
	var long := AdventurePlayer.from_dict(_changed(func(d: Dictionary) -> void:
		for more in 40:
			d["world"]["sites"].append({"x": 1, "y": 1, "type": 2, "trade": 0, "status": 0})))
	assert_eq(long.world.sites.size(), AdventureRegions.SITE_SLOTS)
	var same := AdventurePlayer.from_dict(_changed(func(_d: Dictionary) -> void: pass))
	assert_eq(same.to_dict()["world"]["sites"], player.to_dict()["world"]["sites"], "a whole list as it was")


func test_another_lands_links_are_counted_from_cleaned_places() -> void:
	var hero := AdventurePlayer.from_dict(_changed(func(_d: Dictionary) -> void: pass))
	var before := hero.mana_links()
	hero.world.expansion["region"] = "elsewhere"
	var here := TownStatus.mana_links(hero.world)
	hero.regions[AdventureRegions.MAINLAND] = {"world": {"sites": [
		{"type": [], "status": {}}, 5, "x", null, {"type": "town", "status": TownStatus.LINKED},
		{"x": 1, "y": 1, "type": ShandalarWorld.TOWN, "status": float(TownStatus.LINKED)}]}}
	assert_eq(AdventureRegions.extra_links(hero), 1, "the one linked town")
	assert_eq(hero.mana_links(), here + 1)
	for odd: Variant in [{"world": {"sites": 5}}, {"world": 3}, {}]:
		hero.regions[AdventureRegions.MAINLAND] = odd
		assert_eq(AdventureRegions.extra_links(hero), 0)
	assert_true(before >= 0)


# -------------------------------------------------------- 6: switches --

func test_a_switch_that_is_no_switch_holds_the_land() -> void:
	var plugin := {"plugin": true, "title": "T",
		"progress_schema": {"quests": 5, "max_stage": 2, "max_pending": 60, "flags": ["liberated"]}}
	var state := {"quests": [0], "pending": [], "liberated": 3}
	assert_false(ExpansionContract.valid_progress(plugin, state))
	assert_eq(ExpansionContract.progress_state(plugin, state), ExpansionContract.CHANGED,
		"held as a changed land, the save still read")
	assert_eq(ExpansionContract.progress_state(plugin, {"quests": [0], "pending": [], "liberated": true}),
		ExpansionContract.FINE)
	assert_eq(ExpansionContract.progress_state(plugin, {"quests": "all", "pending": []}),
		ExpansionContract.BROKEN, "a shape no version wrote is damage still")


# ------------------------------------------------- 7: renamed copies --

func test_an_adventure_kept_under_another_name_is_exported() -> void:
	var hero := _begin("Goya")
	for twice in 2:
		hero.autosave()
	SaveSlots.save_into(hero, 2, "By the river")
	var id := hero.adventure_id
	for file_name in DirAccess.get_files_at(FOLDER):
		DirAccess.rename_absolute(FOLDER.path_join(file_name), FOLDER.path_join(file_name.replace(id, "copy")))
	AdventurePlayer.forget_saves()
	assert_eq(AdventureTransfer.files_of(id).size(), 0, "nothing by its own name")
	assert_eq(AdventurePlayer.list_saves().size(), 2, "and the list shows it")
	var made := AdventureTransfer.pack(id)
	assert_true(bool(made["ok"]), String(made["message"]))
	assert_eq(int(made["saves"]), 2)
	var package := AdventureTransfer.read_package(AdventureTransfer.OUTGOING)
	assert_true(bool(package["ok"]), String(package["message"]))
	assert_eq(String(package["id"]), id)
	var names: Array = (package["files"] as Dictionary).keys()
	names.sort()
	assert_eq(names, ["%s.autosave.json" % id, "%s.autosave.json.bak" % id, "%s.slot02.json" % id])


func test_a_save_by_its_own_name_comes_before_a_renamed_copy() -> void:
	var hero := _begin("Goya")
	hero.gold = 111
	hero.autosave()
	var own := hero.save_path()
	DirAccess.copy_absolute(own, FOLDER.path_join("copy.autosave.json"))
	hero.gold = 222
	hero.autosave()
	AdventurePlayer.forget_saves()
	assert_true(bool(AdventureTransfer.pack(hero.adventure_id)["ok"]))
	var package := AdventureTransfer.read_package(AdventureTransfer.OUTGOING)
	var bytes: PackedByteArray = package["files"]["%s.autosave.json" % hero.adventure_id]
	assert_eq(bytes, FileAccess.get_file_as_bytes(own), "the adventure's own file")


func test_an_older_save_renamed_becomes_a_slot_of_its_own_adventure() -> void:
	var hero := _begin("Goya")
	var id := hero.adventure_id
	assert_ne(hero.save(FOLDER.path_join("renamed.%s.json" % SaveSlots.LEGACY)), "")
	DirAccess.remove_absolute(FOLDER.path_join("renamed.%s.json.bak" % SaveSlots.LEGACY))
	AdventurePlayer.forget_saves()
	SaveSlots.migrate(FOLDER)
	assert_true(FileAccess.file_exists(SaveSlots.path_of(id, 1, FOLDER)), "slot 1 of the adventure it holds")
	assert_false(FileAccess.file_exists(SaveSlots.path_of("renamed", 1, FOLDER)))
	assert_false(FileAccess.file_exists(FOLDER.path_join("renamed.%s.json" % SaveSlots.LEGACY)))
	var slots := SaveSlots.slots_of(id, FOLDER)
	assert_eq(String(slots[0]["name"]), SaveSlots.LEGACY_NAME)
