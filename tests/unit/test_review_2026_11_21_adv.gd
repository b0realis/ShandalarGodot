extends GutTest
## THE ADVENTURE'S SMOOTHNESS AND ITS SMALL BUGS (the review of 2026-11-21):
## what was made cheaper gives the same answers as before, and counts what
## it now does once; what was a bug is held.

const SAVES := "user://adventure_tests_review_adv"
const PLUGIN := "user://adventure_tests_review_adv_plugin"


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES


func after_each() -> void:
	AdventurePlayer.finish_saves()
	AdventurePlayer.later_forced = -1
	for folder in [SAVES, PLUGIN]:
		var dir := DirAccess.open(folder)
		if dir != null:
			for file_name in dir.get_files():
				dir.remove(file_name)
			DirAccess.remove_absolute(folder)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _record(seed_text := "12345") -> Dictionary:
	var setup := AdventureSetup.new()
	setup.player_name = "Mira"
	setup.color = "green"
	setup.difficulty = 1
	setup.walker = "female"
	setup.seed_text = seed_text
	return setup.resolve({})


func _begin() -> AdventurePlayer:
	var record := _record()
	return AdventurePlayer.begin(record, AdventureSetup.make_world(record))


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


# ------------------------------------------------------ what the hero sees --

## The whole map looked at, as before the review: the answer the bounded
## loop must give.
func _explored_the_old_way(page: PackedByteArray, tile: Vector2i) -> PackedByteArray:
	var out := page.duplicate()
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			var row := (y - x) - (tile.y - tile.x)
			var column := ((x + y) - (tile.x + tile.y) - (row & 1)) / 2
			if absi(row) <= 7 and absi(column) <= 3:
				out[y * ShandalarWorld.PAGE_WIDTH + x] = out[y * ShandalarWorld.PAGE_WIDTH + x] | ShandalarWorld.EXPLORED
	return out


func test_the_hero_sees_the_same_tiles_looking_only_near() -> void:
	var record := _record()
	var fresh := AdventureSetup.make_world(record).page
	var last := ShandalarWorld.TILES - 1
	var differing := 0
	for tile: Vector2i in [Vector2i(0, 0), Vector2i(last, last), Vector2i(0, last), Vector2i(last, 0),
			Vector2i(1, 2), Vector2i(31, 32), Vector2i(32, 31), Vector2i(7, 56), Vector2i(60, 3), Vector2i(33, 33)]:
		var world := ShandalarWorld.new()
		world.page = fresh.duplicate()
		world.explore_around(tile)
		if world.page != _explored_the_old_way(fresh, tile):
			differing += 1
	assert_eq(differing, 0, "the tiles marked are the ones the whole map's scan marked")


# ------------------------------------------------------------- the small map --

func test_a_plain_world_s_tiles_are_colored_by_their_terrain_alone() -> void:
	var record := _record()
	var world := AdventureSetup.make_world(record)
	assert_true(WorldTerrainPalette.uniform(world), "no appearance saved, no tints: one style for every tile")
	var differing := 0
	for code in 16:
		var original: Color = WorldView.PLAIN.get(code, WorldView.PLAIN[0])
		var once := WorldTerrainPalette.plain(world, code, original, Vector2i(3, 4))
		for tile: Vector2i in [Vector2i(0, 0), Vector2i(40, 9), Vector2i(63, 63)]:
			if WorldTerrainPalette.plain(world, code, original, tile) != once:
				differing += 1
	assert_eq(differing, 0, "asked once a terrain, the color is every tile's")
	assert_true(WorldTerrainPalette.set_tile_style(world, Vector2i(5, 5), {"ground": {"tint": "#ff0000", "strength": 0.5}}))
	assert_false(WorldTerrainPalette.uniform(world), "a tile with a style of its own: each tile asked")


func test_the_small_map_looks_only_at_the_tiles_its_box_can_hold() -> void:
	var map := WorldMinimap.new()
	add_child_autofree(map)
	var record := _record()
	var world := AdventureSetup.make_world(record)
	map.world = world
	var missed := 0
	var most := 0
	for hero: Vector2 in [Vector2(16, 16), Vector2(1000, 1100), Vector2(2030, 40), Vector2(700.5, 1999)]:
		map.hero = hero
		var here := map.drawn_tile()
		var reach := int(ceil(map.size.x / (2.0 * WorldMinimap.TILE) + map.size.y / WorldMinimap.TILE)) / 2 + 3
		var box := map.ground_box()
		var span := map._tiles_in(box, here, reach)
		most = maxi(most, span.get_area())
		# Every tile the old walk drew — its diamond's left point or its
		# middle in the box — is among the tiles looked at now.
		for y in range(here.y - reach, here.y + reach + 1):
			for x in range(here.x - reach, here.x + reach + 1):
				if x < 0 or y < 0 or x >= ShandalarWorld.TILES or y >= ShandalarWorld.TILES:
					continue
				if (box.has_point(map._on_ground(Vector2(x * 32, y * 32)))
						or box.has_point(map._on_ground(Vector2(x * 32 + 16, y * 32 + 16)))) \
						and not span.has_point(Vector2i(x, y)):
					missed += 1
	assert_eq(missed, 0, "no tile the box holds is left out")
	assert_lt(most, 51 * 51 / 2, "and far fewer are looked at than the 51 x 51 before")


func test_a_sites_plugin_s_place_shows_on_the_maps_only_once_seen() -> void:
	var world := AdventureSetup.make_world(_record())
	var tile := Vector2i(2, 60)
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			if not world.is_explored(x, y):
				tile = Vector2i(x, y)
	assert_false(world.is_explored(tile.x, tile.y))
	var place := {"id": "p", "kind": "shrine", "point": [tile.x, tile.y], "name": "Shrine", "site": true}
	var harbor := {"id": "i", "kind": "port", "point": [tile.x, tile.y], "name": "Ship"}
	assert_false(WorldMinimap.place_shown(world, place), "a plugin's site on land not seen: not drawn")
	assert_true(WorldMinimap.place_shown(world, harbor), "a ship's harbor as ever")
	world.explore_around(tile)
	assert_true(WorldMinimap.place_shown(world, place), "seen: drawn")


# --------------------------------------------------------------- the tasks --

func test_the_guides_look_at_the_adventure_once() -> void:
	var player := _begin()
	var calling := WorldStatus.targets(player)
	AdventureTasks.rows(player)
	var before := AdventureTasks.looks
	var guided := AdventureTasks.guide(player, calling)
	assert_eq(AdventureTasks.looks - before, 1, "one look for the history and the rows, not two")
	before = AdventureTasks.looks
	var tracked := AdventureTasks.tracked(player)
	assert_eq(AdventureTasks.looks - before, 1)
	# The same answers after something the rows are made from changed.
	player.world.encounters[6]["clues"] = WorldClues.LOCATION
	var rows := AdventureTasks.rows(player)
	assert_true(rows.any(func(task: Dictionary) -> bool: return String(task["id"]).ends_with("dungeon:6")),
		"a dungeon learned of is a task at the next look")
	assert_eq(AdventureTasks.guide(player, calling).size(), guided.size(), "the guides as before for the same calling")
	assert_eq(AdventureTasks.tracked(player), tracked)


# ------------------------------------------------------------ the card list --

func test_a_card_list_gives_its_pick_once() -> void:
	var list := CardListPane.new()
	list.picking = true
	list.chosen = "Forest"
	var heard: Array = []
	list.picked.connect(func(card_name: String) -> void: heard.append(card_name))
	list.pick()
	list.pick()
	list.pick()
	assert_eq(heard, ["Forest"], "two activations in one frame: one card")
	list.free()


# -------------------------------------------------------------- the dungeon --

func test_a_line_said_in_a_dungeon_repaints_the_board_only_as_it_fades() -> void:
	var first := DungeonView.draw_order()
	assert_eq(first.size(), DungeonBoard.WIDTH * DungeonBoard.HEIGHT)
	assert_eq(first[0], Vector2i(DungeonBoard.WIDTH - 1, 0), "back to front, as ever")
	first.clear()
	assert_eq(DungeonView.draw_order().size(), DungeonBoard.WIDTH * DungeonBoard.HEIGHT, "the order kept is not the caller's to change")
	var view := DungeonView.new()
	view.say("A draught from below.")
	var frames := 0
	while view.said() != "" and frames < 400:
		view._process(0.05)
		frames += 1
	assert_almost_eq(float(frames), DungeonView.SAID_SECONDS / 0.05, 2.0, "the line stays as long as before")
	assert_lt(view.said_paints, int(DungeonView.SAID_FADE / 0.05) + 4, "painted again only over the fade")
	assert_gt(view.said_paints, 5, "and it does fade")
	view.free()


# -------------------------------------------------------------- the plugins --

func _picture_bytes() -> PackedByteArray:
	var image := Image.create(16, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	image.fill_rect(Rect2i(3, 2, 5, 7), Color(1, 0.5, 0.2, 1))
	return image.save_png_to_buffer()


func test_a_plugin_s_picture_is_measured_as_it_is_decoded() -> void:
	var bytes := _picture_bytes()
	var image := AdventurePlugins._image_of("marker.png", bytes)
	assert_not_null(image)
	assert_eq(image.get_used_rect(), Rect2i(3, 2, 5, 7))
	assert_null(AdventurePlugins._image_of("marker.ogg", bytes), "not a picture's name")
	assert_null(AdventurePlugins._image_of("marker.png", "nothing".to_utf8_buffer()), "not a picture's bytes")
	assert_null(AdventurePlugins._tune_of("tune.ogg", bytes), "a picture is no tune")


func test_a_warm_up_keeps_the_same_picture_the_first_asking_would_make() -> void:
	DirAccess.make_dir_recursive_absolute(PLUGIN)
	var bytes := _picture_bytes()
	var file := FileAccess.open(PLUGIN.path_join("marker.png"), FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var job := AdventurePlugins.WarmJob.new()
	job.revision = AdventurePlugins.revision
	job.most = AdventurePlugins.MOST_WARM_BYTES
	var key := "review_adv_test/marker.png"
	job.entries.append({"key": key, "rel": "marker.png", "tune": false, "path": PLUGIN, "kind": "folder", "top": "",
		"hash": PluginPackage.sha256(bytes)})
	job.entries.append({"key": "review_adv_test/other.png", "rel": "marker.png", "tune": false, "path": PLUGIN,
		"kind": "folder", "top": "", "hash": "not this file's hash"})
	job.run()
	assert_eq(job.done, 2)
	assert_false(job.entries[1].has("image"), "bytes that are not the scan's are not decoded")
	var told: Array = []
	AdventurePlugins._warm_then[key] = [func() -> void: told.append(key)]
	var before := AdventurePlugins.warmed
	AdventurePlugins._keep_one(job, job.entries[0])
	AdventurePlugins._keep_one(job, job.entries[1])
	assert_eq(AdventurePlugins.warmed - before, 1)
	assert_eq(told, [key], "whoever waited is told")
	var kept: Texture2D = AdventurePlugins._textures.get(key)
	assert_not_null(kept, "kept where the first asking looks")
	if kept != null:
		assert_eq(kept.get_size(), Vector2(16, 12))
		assert_eq(kept.get_meta(AdventurePlugins.USED_RECT), Rect2(3, 2, 5, 7), "its painted part with it: no read-back for the marker")
		assert_eq(AdventurePlugins.texture("review_adv_test", "marker.png"), kept, "the first asking finds it")
	assert_false(AdventurePlugins._textures.has("review_adv_test/other.png"))
	# Scanned again meanwhile: what a warm-up of before made is not kept.
	var late := AdventurePlugins.WarmJob.new()
	late.revision = AdventurePlugins.revision - 1
	late.most = AdventurePlugins.MOST_WARM_BYTES
	late.entries.append({"key": "review_adv_test/late.png", "rel": "marker.png", "tune": false, "path": PLUGIN,
		"kind": "folder", "top": "", "hash": PluginPackage.sha256(bytes)})
	late.run()
	AdventurePlugins._keep_one(late, late.entries[0])
	assert_false(AdventurePlugins._textures.has("review_adv_test/late.png"))
	AdventurePlugins._textures.erase(key)
	assert_false(AdventurePlugins.warm("no_such_plugin_review_adv"), "nothing to warm: nothing waits")


# ---------------------------------------------------- saves off the frame --

func test_saves_handed_over_are_written_in_order_with_the_same_backup() -> void:
	AdventurePlayer.later_forced = 1
	var player := _begin()
	var path := player.save_path(AdventurePlayer.AUTOSAVE)
	var heard: Array = []
	player.gold = 111
	player.save_later(path, func(written: String) -> void: heard.append(["first", written]))
	player.gold = 222
	player.save_later(path, func(written: String) -> void: heard.append(["second", written]))
	player.gold = 333
	assert_true(AdventurePlayer.saves_pending())
	AdventurePlayer.finish_saves()
	assert_false(AdventurePlayer.saves_pending())
	assert_eq(heard, [["first", path], ["second", path]], "each heard, in the order asked")
	assert_eq(int(_json(path)["carried"]["gold"]), 222, "the later save is the file — as it stood when asked, not as it stands now")
	assert_eq(int(_json(AdventurePlayer.backup_path(path))["carried"]["gold"]), 111, "the save before it is the .bak")
	# A save written at once waits for the ones handed over: never under them.
	player.gold = 444
	player.save_later(path)
	player.gold = 555
	assert_eq(player.save(path), path)
	assert_false(AdventurePlayer.saves_pending())
	assert_eq(int(_json(path)["carried"]["gold"]), 555)
	assert_eq(int(_json(AdventurePlayer.backup_path(path))["carried"]["gold"]), 444)


func test_a_save_handed_over_is_the_bytes_a_save_at_once_writes() -> void:
	var player := _begin()
	player.gold = 77
	var at_once := player.save_path("slot01")
	var later := player.save_path("slot02")
	assert_eq(player.save(at_once), at_once)
	var stamp := player.saved
	AdventurePlayer.later_forced = 1
	player.save_later(later)
	AdventurePlayer.finish_saves()
	# Only the moment written differs.
	var one := FileAccess.get_file_as_string(at_once).replace(stamp, "WHEN")
	var two := FileAccess.get_file_as_string(later).replace(player.saved, "WHEN")
	assert_eq(two, one, "the same text, tabs and order")
	assert_eq(AdventurePlayer._entry_of(later, AdventurePlayer._bytes_at(later)).get("gold"), 77, "and remembered for the lists")


func test_a_save_that_cannot_be_written_is_still_said() -> void:
	AdventurePlayer.later_forced = 1
	var player := _begin()
	DirAccess.make_dir_recursive_absolute(SAVES)
	# A file standing where the saves' folder should be.
	var blocked := SAVES.path_join("blocked")
	var file := FileAccess.open(blocked, FileAccess.WRITE)
	file.store_string("x")
	file.close()
	var heard: Array = []
	var before := player.saved
	player.save_later(blocked.path_join("hero.autosave.json"), func(written: String) -> void: heard.append(written))
	AdventurePlayer.finish_saves()
	assert_eq(heard, [""], "heard as not written")
	assert_eq(player.saved, before, "the adventure's own moment of saving is not moved on")
	AdventurePlayer.later_forced = 0
	heard.clear()
	var path := player.save_path(AdventurePlayer.AUTOSAVE)
	player.save_later(path, func(written: String) -> void: heard.append(written))
	assert_eq(heard, [path], "where no worker writes: written here and heard at once")
	assert_false(AdventurePlayer.saves_pending())


# ----------------------------------------------------- a duel that is over --

func test_a_win_whose_choice_waits_is_not_closed_out() -> void:
	var pane := EncounterPane.new()
	assert_false(pane.close_out(), "no duel settled: nothing to close out")
	pane.result = EncounterPane.WON
	pane.spoils = {"result": EncounterPane.WON, "asks": true, "took": ""}
	assert_true(pane.choice_waits(), "the cards or the clue")
	assert_false(pane.close_out(), "a win is never saved with half its spoils")
	pane.spoils = {"result": EncounterPane.WON, "pick_any": true, "picked": ""}
	assert_true(pane.choice_waits(), "a card to pick")
	pane.spoils = {"result": EncounterPane.WON, "asks": true, "took": "cards", "pick_any": true, "picked": "Forest"}
	assert_false(pane.choice_waits())
	var heard: Array = []
	pane.finished.connect(func(result: int) -> void: heard.append(result))
	pane.result = EncounterPane.LOST
	pane.spoils = {"result": EncounterPane.LOST, "lost": ["Forest"]}
	assert_true(pane.close_out(), "a loss: its pages left unread, the meeting over")
	assert_eq(heard, [EncounterPane.LOST])
	assert_false(pane.close_out(), "once")
	if is_instance_valid(pane):
		pane.free()
	var host := WorldDuels.new()
	assert_false(host.finish_over(), "no duel dealt: nothing finished")
	host.free()


# ------------------------------------------------- the page's revision --

## What [param action] did to [param world]'s page: `[the bytes changed,
## the revision moved]`.
func _wrote(world: ShandalarWorld, action: Callable) -> Array:
	var before := world.page.duplicate()
	var count := world.page_revision
	action.call()
	return [world.page != before, world.page_revision != count]


func test_every_way_of_writing_the_page_moves_its_revision() -> void:
	var player := _begin()
	var world := player.world
	var unseen := Vector2i(-1, -1)
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			if not world.is_explored(x, y) and unseen.x < 0 and (x > 20 or y > 20):
				unseen = Vector2i(x, y)
	var writers := {
		"a siege's tile seen (Sieges)": func() -> void: Sieges._explore_tile(world, unseen + Vector2i(2, 0)),
		"the hero looking around": func() -> void: world.explore_around(unseen),
		"a road joined (RegionRoads)": func() -> void: RegionRoads.join(world, world.start_tile(), world.start_tile() + Vector2i(3, 0), {}),
		"a dungeon moved (DungeonDoors)": func() -> void: DungeonDoors.move(player, 7),
		"a World Magic's town shown (CreatureMeeting)": func() -> void: _reveal(player),
		"a whole page put": func() -> void: world.page = world.page.duplicate(),
	}
	var missed: Array = []
	var changed := 0
	for name: String in writers:
		var wrote := _wrote(world, writers[name])
		if wrote[0]:
			changed += 1
		if wrote[0] and not wrote[1]:
			missed.append(name)
	assert_eq(missed, [], "no write of the page leaves its revision where it was")
	assert_gt(changed, 3, "control: these writers do write")
	# Land already seen looked at again writes nothing, and says so.
	var again := _wrote(world, func() -> void: world.explore_around(unseen))
	assert_eq(again, [false, false], "nothing new seen: no picture drawn again for it")
	# A save loaded is another world, its page written as it is read.
	var loaded := AdventurePlayer.from_dict(player.to_dict())
	assert_not_null(loaded)
	if loaded != null:
		assert_ne(loaded.world.get_instance_id(), world.get_instance_id())
		assert_eq(loaded.world.fingerprint(), world.fingerprint(), "the same land — another world to whatever drew the first")


## A World Magic's seller revealed by a creature, on land not seen.
func _reveal(player: AdventurePlayer) -> void:
	for index in player.world.world_magic_sites.size():
		var town := int(player.world.world_magic_sites[index])
		if town > 0 and not player.world.is_explored(int(player.world.sites[town]["x"]), int(player.world.sites[town]["y"])):
			CreatureMeeting.reveal_magic(player, index)
			return


## The page is bytes written in place, which no setter sees: every file
## that writes one — but the generators and the loader, whose world nothing
## has drawn yet — says so with `touch_page()` right after. A new writer that
## forgets fails here, not as a stale map in a player's game.
func test_every_file_that_writes_a_byte_of_the_page_touches_it() -> void:
	var unseen_worlds := ["res://game/adventure/world/world_generator.gd",
		"res://game/adventure/plugins/island_generator.gd", "res://game/adventure/adventure_player.gd"]
	var write := RegEx.new()
	write.compile("\\bpage\\[[^\\n]*\\]\\s*[|&^+\\-]?=[^=]")
	var forgot: Array = []
	var writers := 0
	var pending: Array = ["res://game", "res://engine", "res://cards"]
	while not pending.is_empty():
		var folder: String = pending.pop_back()
		var dir := DirAccess.open(folder)
		if dir == null:
			continue
		for sub in dir.get_directories():
			pending.append(folder.path_join(sub))
		for file_name in dir.get_files():
			var path := folder.path_join(file_name)
			if not file_name.ends_with(".gd") or path in unseen_worlds:
				continue
			var lines := FileAccess.get_file_as_string(path).split("\n")
			for i in lines.size():
				var line := lines[i]
				if line.strip_edges().begins_with("#") or write.search(line) == null or not "page[" in line:
					continue
				if not ("world.page[" in line or line.strip_edges().begins_with("page[")):
					continue
				writers += 1
				var touched := false
				for after in range(i + 1, mini(i + 6, lines.size())):
					if "touch_page()" in lines[after]:
						touched = true
				if not touched:
					forgot.append("%s:%d" % [path, i + 1])
	assert_eq(forgot, [], "every byte of the page written in place is followed by touch_page()")
	assert_gt(writers, 5, "control: the writers are found")


## A site's record and an encounter's are dictionaries written in place
## too: every such write — `…sites[slot]["status"] = …`, `slot["clues"] = …`
## in a file that reads the world's encounters — is followed by `touch()`
## before its function ends. The generators and the loader are exempt, as
## for the page.
func test_every_writer_of_a_site_s_or_an_encounter_s_record_touches_the_world() -> void:
	var unseen_worlds := ["res://game/adventure/world/world_generator.gd",
		"res://game/adventure/plugins/island_generator.gd"]
	var site_write := RegEx.new()
	site_write.compile("\\b(sites|encounters)\\[[^\\n=]*\\]\\[[^\\n=]*\\]\\s*[|&^+\\-]?=[^=]")
	var slot_write := RegEx.new()
	slot_write.compile("^\\s*slot\\[[^\\n=]*\\]\\s*[|&^+\\-]?=[^=]")
	var forgot: Array = []
	var writers := 0
	var pending: Array = ["res://game/adventure"]
	while not pending.is_empty():
		var folder: String = pending.pop_back()
		var dir := DirAccess.open(folder)
		if dir == null:
			continue
		for sub in dir.get_directories():
			pending.append(folder.path_join(sub))
		for file_name in dir.get_files():
			var path := folder.path_join(file_name)
			if not file_name.ends_with(".gd") or path in unseen_worlds:
				continue
			var text := FileAccess.get_file_as_string(path)
			var reads_encounters := "world.encounters" in text
			var lines := text.split("\n")
			for i in lines.size():
				var line := lines[i]
				if line.strip_edges().begins_with("#"):
					continue
				var writes := site_write.search(line) != null and not "player.sites[" in line \
					or (reads_encounters and slot_write.search(line) != null)
				if not writes:
					continue
				writers += 1
				var touched := false
				for after in range(i + 1, lines.size()):
					if lines[after].begins_with("func ") or lines[after].begins_with("static func "):
						break
					if "touch()" in lines[after]:
						touched = true
						break
				if not touched:
					forgot.append("%s:%d" % [path, i + 1])
	assert_eq(forgot, [], "every record written in place is followed by touch()")
	assert_gt(writers, 8, "control: the writers are found")


func test_what_reads_the_sites_reads_them_again_when_one_is_written() -> void:
	var player := _begin()
	var world := player.world
	var town := -1
	for slot in world.sites.size():
		if int(world.sites[slot]["type"]) == ShandalarWorld.TOWN:
			town = slot
			break
	var writers := {
		"a town's status (TownStatus.put)": func() -> void: TownStatus.put(world, town, TownStatus.VISITED),
		"a town taken (TownStatus.take)": func() -> void: TownStatus.take(world, town, 2),
		"a clue learned (WorldClues)": func() -> void: WorldClues.reveal(player, 6),
		"the cards taken over a clue": func() -> void: WorldClues.mark_cards_taken(world, 7),
		"a dungeon entered": func() -> void: DungeonDoors.enter(player, 8),
		"a dungeon moved": func() -> void: DungeonDoors.move(player, 9),
	}
	var missed: Array = []
	var changed := 0
	for name: String in writers:
		var before := [world.sites.hash(), world.encounters.hash()]
		var count := world.revision
		(writers[name] as Callable).call()
		var wrote := before != [world.sites.hash(), world.encounters.hash()]
		if wrote:
			changed += 1
		if wrote and world.revision == count:
			missed.append(name)
	assert_eq(missed, [], "no record written leaves the revision where it was")
	assert_gt(changed, 3, "control: these writers do write")
	# The quest pane's lines, kept by the revision, are the fresh ones.
	WorldStatus.lines(player)
	TownStatus.take(world, town, 3)
	assert_eq(WorldStatus.lines(player), WorldStatus.lines_fresh(player), "the lines kept are the lines made afresh")
	# The small map looks again.
	var map := WorldMinimap.new()
	add_child_autofree(map)
	map.world = world
	var drawn := map._drawn.duplicate()
	TownStatus.put(world, town, TownStatus.VISITED, false)
	map._follow()
	assert_ne(map._drawn, drawn, "a town's record written: the land is drawn again")


func test_the_small_map_draws_from_the_page_s_revision() -> void:
	var map := WorldMinimap.new()
	add_child_autofree(map)
	var world := AdventureSetup.make_world(_record())
	map.world = world
	map.hero = Vector2(world.start_tile() * 32 + Vector2i(16, 16))
	var drawn := map._drawn.duplicate()
	map._follow()
	assert_eq(map._drawn, drawn, "nothing written: the land stays as drawn")
	Sieges._explore_tile(world, Vector2i(60, 60) if not world.is_explored(60, 60) else Vector2i(3, 60))
	map._follow()
	assert_ne(map._drawn, drawn, "a tile seen from elsewhere: the land is drawn again")
