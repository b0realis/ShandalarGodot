extends Node
## Repeatable region invariants and independent deck/life battle baselines.
## With `--plugin FOLDER` (expansion_lab.sh copies the plugin there) the
## region is that adventure plugin, the run's only one: it must pass the
## game's own checks ([AdventurePlugins]) first, and a plugin that needs no
## card pack is taken away mid-trip (its folder emptied, as a player who
## removes it) where a pack plugin's pack is switched off.
## A SITES PLUGIN (API 2, [AdventureSites]) is no land: `--plugin` with one
## plays its places instead ([method _run_sites]) — on a fresh mainland
## and on the beacon island, every button its panes offer pressed with gold
## enough, every dungeon raised checked, the adventure saved and read back,
## and the plugin taken away (its places hidden, its progress kept).
const BEACON = preload("res://tools/expansion_testing/beacon_region.gd")
## A plugin land played to its end on the model's results, saves read back
## (the lead's ruling on review RV2).
const CAMPAIGN = preload("res://tools/expansion_testing/lab_campaign.gd")
## The plugins folder a plugin needing no pack is "removed" to.
const NO_PLUGINS := "user://expansion_lab_no_plugins"
var failures: Array[String] = []
var _plugin_folders: Array[String] = []
## The sites plugin `--plugin` named, "" for an island plugin or none.
var _sites_plugin := ""
var report := {"tool": "expansion_lab", "scenarios": [], "campaigns": [], "duels": [], "rated": false}

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var options := {"--out": "", "--region": "refuge", "--plugin": "", "--seeds": "5,37,48271", "--trips": "3", "--games": "0", "--lives": "10,20,30"}
	var index := 0
	while index < args.size():
		if args[index] not in options or index + 1 >= args.size():
			printerr("Unknown option or missing value: " + args[index])
			get_tree().quit(2)
			return
		options[args[index]] = args[index + 1]
		index += 2
	if not OS.has_feature("shandalar_test") or options["--out"] == "":
		printerr("Use ./tools/expansion_lab.sh --out NEW_DIRECTORY")
		get_tree().quit(2)
		return
	for key in ["--trips", "--games"]:
		if not String(options[key]).is_valid_int() or int(options[key]) < (1 if key == "--trips" else 0) or int(options[key]) > 100:
			printerr("Invalid count: " + key)
			get_tree().quit(2)
			return
	var seeds := integers(options["--seeds"], 0, 2147483647)
	var lives := integers(options["--lives"], 1, 100)
	if seeds.is_empty() or lives.is_empty():
		get_tree().quit(2)
		return
	# This isolated development tool registers its own fixture beside the
	# installed adventure plugins ([AdventurePlugins]); each scenario ticks
	# its land as the Embark does.
	AdventureExpansions.register_development(BEACON.ID, BEACON.descriptor())
	if String(options["--plugin"]) != "" and not _use_plugin(String(options["--plugin"]), options):
		get_tree().quit(1)
		return
	if _sites_plugin != "":
		_run_sites(_sites_plugin, seeds, String(options["--out"]))
		return
	var region: String = options["--region"]
	if not AdventureExpansions.definitions().has(region):
		printerr("Unknown region: " + region)
		get_tree().quit(2)
		return
	var service := get_tree().root.get_node("CardPacks")
	for need in AdventureExpansions.pack_ids(region):
		service.set_enabled(need, true)
	CardRegistry.ensure_loaded()
	if not AdventureExpansions.enabled(region):
		printerr("The region's card pack is unavailable; supply its local pack ZIP.")
		get_tree().quit(2)
		return
	report["version"] = ProjectSettings.get_setting("application/config/version")
	report["region"] = region
	report["seeds"] = seeds
	report["trips"] = int(options["--trips"])
	report["rules"] = "modern_mana_burn"
	report["profiles"] = "wizard, wizard; fair information"
	report["scope"] = "Scenario invariants; a plugin land's every quest and its finale won on the model's own results (no duel fought), its rewards claimed and its saves read back; deck/life baselines with --games. No ratings are written."
	var rules := RulesOptions.new()
	rules.set_preset("modern_mana_burn")
	for fork in RulesOptions.FORKS: Settings.set_rule(fork["key"], rules.get_fork(fork["key"]), false)
	for seed_value in seeds:
		for id in [region, BEACON.ID] if region != BEACON.ID else [region]:
			_scenario(id, seed_value, int(options["--trips"]))
		if bool(AdventureExpansions.definition(region).get("plugin", false)):
			var run: Dictionary = CAMPAIGN.play(region, seed_value)
			failures.append_array(run["failures"])
			report["campaigns"].append({"region": region, "seed": seed_value, "quests": run["quests"], "rewards": run["rewards"],
				"finale": run["finale"], "save_bytes": run["save_bytes"], "failures": (run["failures"] as Array).size()})
	var content := AdventureExpansions.provider(region)
	if int(options["--games"]) > 0 and content.has_method("study_decks"):
		var opponents: Array = content.call("study_decks")
		# Both hero lists are crossed with EVERY life total and EVERY opponent.
		var heroes := [list_of({"Forest": 16, "Llanowar Elves": 4, "Grizzly Bears": 4, "Giant Growth": 4, "Giant Spider": 4, "War Mammoth": 4, "Craw Wurm": 4}),
			list_of({"Plains": 16, "Savannah Lions": 4, "White Knight": 4, "Order of Leitbur": 4, "Swords to Plowshares": 4, "Crusade": 4, "Disenchant": 4})]
		report["hero_decks"] = heroes
		report["opponent_decks"] = opponents
		for h in heroes.size():
			for life in lives:
				for opponent in opponents:
					for n in int(options["--games"]):
						var config := DuelConfig.new()
						config.decks = [heroes[h], opponent["deck"]]
						config.lives = [life, int(opponent["life"])]
						config.pilots = [AiProfile.wizard(), AiProfile.wizard()]
						config.rng_seed = seeds[n % seeds.size()] + n
						config.first_player = n % 2
						config.mulligan_rule = MtgGame.MULLIGAN_1997
						var result := await HeadlessDuel.play(config)
						report["duels"].append({"hero": ["green_baseline", "white_tuned"][h], "life": life, "opponent": opponent["name"], "opponent_life": opponent["life"], "seed": config.rng_seed, "first": config.first_player, "finished": result.finished, "winner": result.winner, "turns": result.turns})
						check(result.finished, "Unfinished duel: " + str(report["duels"].back()))
						if report["duels"].size() % 12 == 0: printerr("Expansion Lab: %d duels completed" % report["duels"].size())
	_finish(String(options["--out"]), "%d scenarios; %d campaigns; %d duels; %d failures." % [report["scenarios"].size(), report["campaigns"].size(), report["duels"].size(), failures.size()])


## results.json and report.txt written to [param out] ([param head] the
## report's first line), the summary printed, the run ended: exit 0 when
## every check passed, else 1.
func _finish(out: String, head: String) -> void:
	report["failures"] = failures
	var file := FileAccess.open(out.path_join("results.json"), FileAccess.WRITE)
	if file == null:
		printerr("Cannot write results.json")
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	var summary := "%s\n%s\n" % [head, report["scope"]]
	for failure in failures: summary += failure + "\n"
	file = FileAccess.open(out.path_join("report.txt"), FileAccess.WRITE)
	if file == null:
		get_tree().quit(1)
		return
	file.store_string(summary)
	file.close()
	print(summary)
	AdventureExpansions.clear_development()
	get_tree().quit(0 if failures.is_empty() else 1)

func integers(value: String, low: int, high: int) -> Array[int]:
	var out: Array[int] = []
	for item in value.split(","):
		if not item.is_valid_int() or int(item) < low or int(item) > high:
			printerr("Invalid integer list: " + value)
			return []
		out.append(int(item))
	return out

func list_of(counts: Dictionary) -> Array:
	var out: Array = []
	for card in counts:
		for copy in counts[card]: out.append(card)
	return out

func _scenario(region: String, seed_value: int, trips: int) -> void:
	var before := failures.size()
	var started := Time.get_ticks_msec()
	var memory_before := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var setup := AdventureSetup.new()
	setup.adventures = [region] as Array[String]
	var needs := AdventureExpansions.pack_ids(region)
	var pack: String = needs[0] if not needs.is_empty() else ""
	if pack != "": setup.packs.append(pack)
	setup.seed_text = str(seed_value)
	var record := setup.resolve({pack: "1"})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	AdventureExpansions.initialize(player)
	var mainland := player.world.fingerprint()
	var links := player.mana_links()
	var island := ""
	var bytes := 0
	for trip in trips:
		var make := func() -> ShandalarWorld: return AdventureExpansions.generate(region, seed_value, player.world.color, player.difficulty)
		check(AdventureRegions.travel(player, region, make), "Travel failed: %s seed %d" % [region, seed_value])
		if AdventureRegions.id(player.world) != region: return
		if trip == 0: island = player.world.fingerprint()
		check(player.world.fingerprint() == island, "Visited terrain changed")
		var land := RegionGeography.component(player.world, player.world.start_tile())
		for place in AdventureExpansions.places(player.world):
			check(Vector2i(place["point"][0], place["point"][1]) in land, "Unreachable marker: " + str(place))
		for task in AdventureTasks.rows(player):
			if task["region"] == region and task["tile"].x >= 0:
				check(task["tile"] in land, "Unreachable objective: " + task["id"])
		check(player.mana_links() == links, "Travel changed mainland mana links")
		var text := JSON.stringify(player.to_dict())
		bytes = text.to_utf8_buffer().size()
		player = AdventurePlayer.from_dict(JSON.parse_string(text))
		check(player != null, "Save round-trip failed")
		if player == null: return
		# Disable content while on the land: returning must still be possible.
		_set_available(region, pack, false)
		check(not AdventureExpansions.enabled(region), "Fixture failed to disable region")
		check(AdventureRegions.travel(player, AdventureRegions.MAINLAND), "Return failed with disabled region")
		check(AdventureExpansions.places(player.world).all(func(place: Dictionary) -> bool: return region not in place.get("destinations", [])), "Disabled departure remains visible")
		_set_available(region, pack, true)
		check(player.world.fingerprint() == mainland, "Mainland changed")
		check(AdventureExpansions._providers.is_empty(), "Inactive provider retained")
	report["scenarios"].append({"region": region, "seed": seed_value, "trips": trips, "save_bytes": bytes, "memory_delta_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)) - memory_before, "milliseconds": Time.get_ticks_msec() - started, "failures": failures.size() - before})


## The adventure plugin in [param folder] (the run's only plugins folder) as
## the region: its row must be valid. False, said on stderr, when it is not.
func _use_plugin(folder: String, options: Dictionary) -> bool:
	_plugin_folders = [folder] as Array[String]
	AdventurePlugins.folders_override = _plugin_folders
	AdventurePlugins.scan()
	var rows := AdventurePlugins.all()
	if rows.size() != 1:
		printerr("--plugin: %d plugins found in %s; expected one." % [rows.size(), folder])
		return false
	var row: Dictionary = rows[0]
	if not (row["problems"] as Array).is_empty():
		printerr("--plugin: %s is refused:" % String(row["path"]).get_file())
		for problem in row["problems"]: printerr("  " + String(problem))
		return false
	options["--region"] = String(row["id"])
	report["plugin"] = {"id": row["id"], "version": row["version"], "name": row["name"], "kind": row["kind"],
		"plugin_kind": row.get("plugin_kind", AdventurePlugins.KIND_ISLAND)}
	if AdventurePlugins.kind(String(row["id"])) == AdventurePlugins.KIND_SITES:
		_sites_plugin = String(row["id"])
	return true


## [param region]'s content on or off as a player can take it away: its card
## pack switched off, a development fixture disabled, or — a plugin needing
## no pack — the plugin itself gone from the plugins folder.
func _set_available(region: String, pack: String, on: bool) -> void:
	if pack != "":
		get_tree().root.get_node("CardPacks").set_enabled(pack, on)
	elif AdventureExpansions._development.has(region):
		AdventureExpansions._development[region]["enabled"] = on
		AdventureExpansions.refresh()
	else:
		DirAccess.make_dir_recursive_absolute(NO_PLUGINS)
		var folders: Array[String] = [NO_PLUGINS]
		if on: folders = _plugin_folders
		AdventurePlugins.folders_override = folders
		AdventurePlugins.scan()


# ------------------------------------------------------ a sites plugin --

## A SITES PLUGIN PLAYED for each seed ([method _sites_run]); its card packs
## switched on first, as the Embark ticks them.
func _run_sites(id: String, seeds: Array[int], out: String) -> void:
	var service := get_tree().root.get_node("CardPacks")
	for need in AdventureSites.pack_ids(id):
		service.set_enabled(need, true)
	CardRegistry.ensure_loaded()
	if not AdventureSites.enabled(id):
		printerr("The sites plugin's card pack is unavailable; supply its local pack ZIP.")
		get_tree().quit(2)
		return
	report["version"] = ProjectSettings.get_setting("application/config/version")
	report["region"] = ""
	report["seeds"] = seeds
	report["sites"] = []
	report["scope"] = "A sites plugin's places: placed on a fresh mainland and on the beacon island with the 1997 world and dice untouched, every pane's buttons pressed with gold enough (each price paid and use counted, used up when its prices are), every dungeon raised checked, the adventure saved and read back, the plugin taken away (places hidden, progress and dungeons kept). No duels, no ratings."
	for seed_value in seeds:
		report["sites"].append(_sites_run(id, seed_value))
	var places := 0
	var presses := 0
	var raised := 0
	for row: Dictionary in report["sites"]:
		places += (row["places"] as Array).size()
		presses += int(row["presses"])
		raised += (row["dungeons"] as Array).size()
	_finish(out, "%d site runs; %d places; %d presses; %d dungeons raised; %d failures." % [report["sites"].size(), places, presses, raised, failures.size()])


## A hero of [param seed_value] whose campaign ticks [param lands] (and the
## card packs sites plugin [param id] needs), the lands put on the mainland.
func _sites_hero(id: String, lands: Array[String], seed_value: int) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.adventures = lands
	var versions := {}
	for pack in AdventureSites.pack_ids(id):
		setup.packs.append(pack)
		versions[pack] = "1"
	setup.seed_text = str(seed_value)
	var record := setup.resolve(versions)
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	AdventureExpansions.initialize(player)
	return player


## The tile place [param mark] (`<plugin>:<site>`) stands on in [param world], (−1, −1) for none.
static func _site_tile(world: ShandalarWorld, mark: String) -> Vector2i:
	var placed: Variant = world.expansion.get(AdventureSites.KEY, {})
	var point: Variant = (placed as Dictionary).get(mark, []) if placed is Dictionary else []
	return Vector2i(int(point[0]), int(point[1])) if point is Array and (point as Array).size() == 2 else Vector2i(-1, -1)


## One seed of sites plugin [param id]: its places on the mainland and the
## beacon island, their buttons, dungeons, saves and absence. The run's row.
func _sites_run(id: String, seed_value: int) -> Dictionary:
	var before := failures.size()
	var tag := "%s seed %d" % [id, seed_value]
	var row := {"seed": seed_value, "places": [], "presses": 0, "dungeons": [], "refused": [], "save_bytes": 0, "failures": 0}
	var info := AdventureSites.definition(id)
	for key: String in info.get("pictures", {}):
		check(AdventurePlugins.texture(id, String(info["pictures"][key])) != null, "%s: the picture %s does not decode" % [tag, key])
	var sites: Dictionary = info.get("sites", {})
	var plain := _sites_hero(id, [] as Array[String], seed_value)
	var player := _sites_hero(id, [id] as Array[String], seed_value)
	check(player.world.fingerprint() == plain.world.fingerprint(), tag + ": the 1997 mainland changed with the plugin ticked")
	check(player.dice == plain.dice and player.world.rand_state == plain.world.rand_state, tag + ": the adventure's dice were touched")
	# The mainland: every place whose where names it, and none that does not.
	for key: String in sites:
		var tile := _site_tile(player.world, id + ":" + key)
		if "mainland" in sites[key].get("where", []):
			check(tile.x >= 0, "%s: %s stands nowhere on the mainland" % [tag, key])
			if tile.x >= 0:
				_sites_place(player, id, key, tile, int(sites[key].get("gap", 3)), tag + " mainland")
				row["places"].append({"land": AdventureRegions.MAINLAND, "site": key, "tile": [tile.x, tile.y]})
		else:
			check(tile.x < 0, "%s: %s stands on the mainland, which its where does not name" % [tag, key])
	for key: String in sites:
		if "mainland" in sites[key].get("where", []) and _site_tile(player.world, id + ":" + key).x >= 0:
			_sites_press(player, id, key, tag + " mainland", row, true)
	_sites_saves(player, id, tag, row)
	# The beacon island: every place whose where names islands; those of the
	# islands alone are pressed there.
	var island := _sites_hero(id, [BEACON.ID, id] as Array[String], seed_value)
	check(AdventureExpansions.voyage(island, BEACON.ID), tag + ": the voyage to the beacon island failed")
	AdventureExpansions.entered(island)
	if AdventureRegions.id(island.world) == BEACON.ID:
		# The beacon fixture has no encounter slots; a plugin's island has the
		# five empty castle slots (IslandGenerator) and its dungeon after them.
		# The same here, so a dungeon raised on it takes a dungeon's slot.
		while island.world.encounters.size() < DungeonDoors.CASTLES:
			island.world.encounters.append({"x": 0, "y": 0, "cards": [], "clues": 0})
		for key: String in sites:
			var tile := _site_tile(island.world, id + ":" + key)
			if "islands" in sites[key].get("where", []):
				check(tile.x >= 0, "%s: %s stands nowhere on the beacon island" % [tag, key])
				if tile.x >= 0:
					_sites_place(island, id, key, tile, int(sites[key].get("gap", 3)), tag + " island")
					row["places"].append({"land": BEACON.ID, "site": key, "tile": [tile.x, tile.y]})
					if not "mainland" in sites[key].get("where", []):
						_sites_press(island, id, key, tag + " island", row, false)
			else:
				check(tile.x < 0, "%s: %s stands on an island, which its where does not name" % [tag, key])
	row["failures"] = failures.size() - before
	return row


## Place [param key] of [param id] at [param tile] of [param player]'s land
## as the map and the hero see it: a free land tile its gap away from the
## towns, its marker, its sprite, its pane.
func _sites_place(player: AdventurePlayer, id: String, key: String, tile: Vector2i, gap: int, tag: String) -> void:
	var world := player.world
	var mark := id + ":" + key
	check(world.is_land(tile.x, tile.y), "%s: %s stands on water" % [tag, key])
	check(world.tile_flags(tile.x, tile.y) & (ShandalarWorld.SITE | ShandalarWorld.ROAD | ShandalarWorld.DUNGEON) == 0,
		"%s: %s stands on a town, road or dungeon" % [tag, key])
	for site in world.sites:
		if int(site["type"]) > 0 and tile.distance_to(Vector2i(int(site["x"]), int(site["y"]))) < float(gap):
			check(false, "%s: %s stands nearer than %d tiles to a town" % [tag, key, gap])
			break
	check(AdventureExpansions.marker(world, tile) == mark, "%s: %s has no marker on its tile" % [tag, key])
	check(AdventureExpansions.map_op(mark).size() == 3, "%s: %s's sprite is not drawn" % [tag, key])
	var pane := AdventureExpansions.describe(player, tile)
	check(String(pane.get("kind", "")) == AdventureSites.PANE_KIND and String(pane.get("name", "")) != "",
		"%s: %s's pane does not open" % [tag, key])


## EVERY BUTTON place [param key]'s panes offer, pressed with gold enough
## (the hero standing on the place) until none is ready: each at most its
## prices' count (twice when it has none), 64 presses at most. Each price
## paid and use counted; an action whose prices are all paid used up and
## gone; every dungeon raised checked. [param raise_needed]: a dungeon that
## finds no room is a failure (the mainland), else a note (the beacon
## island is eight tiles wide).
func _sites_press(player: AdventurePlayer, id: String, key: String, tag: String, row: Dictionary, raise_needed: bool) -> void:
	var content := AdventureSites.provider(id)
	var tile := _site_tile(player.world, id + ":" + key)
	player.position = tile * 32 + Vector2i(16, 16)
	var pressed := {}
	for n in 64:
		player.gold = 5000000
		var choice := ""
		for action: Array in content.describe(player, key).get("actions", []):
			var button := String(action[0])
			if not button.begins_with(id + AdventureSites.ACT) or not bool(action[2]):
				continue
			var name := button.get_slice(":", 2)
			var prices: Array = content.action_of(key, name).get("prices", [])
			if int(pressed.get(name, 0)) < (prices.size() if not prices.is_empty() else 2):
				choice = name
				break
		if choice == "":
			break
		var entry := content.action_of(key, choice)
		var cost := content.price(player, key, entry)
		var uses := content.uses(player, key, choice)
		var gold := player.gold
		pressed[choice] = int(pressed.get(choice, 0)) + 1
		row["presses"] = int(row["presses"]) + 1
		if String(entry["do"]) == "copy_card":
			var cards := DataSites.copyable(player)
			check(not cards.is_empty(), "%s: %s.%s is ready with no card to copy" % [tag, key, choice])
			if cards.is_empty():
				continue
			var card := String(cards.keys()[0])
			var had := player.cards.filter(func(c: Variant) -> bool: return c is Dictionary and String(c.get("card", "")) == card).size()
			content.copy_card(player, key, choice, card)
			var has := player.cards.filter(func(c: Variant) -> bool: return c is Dictionary and String(c.get("card", "")) == card).size()
			check(has == had + 1, "%s: %s.%s did not copy %s" % [tag, key, choice, card])
			check(player.gold == gold - cost, "%s: %s.%s took %d gold, not its price %d" % [tag, key, choice, gold - player.gold, cost])
			check(content.uses(player, key, choice) == uses + 1, "%s: %s.%s's use was not counted" % [tag, key, choice])
			continue
		var gain := 0
		var spawns: Array[String] = []
		for effect: Dictionary in entry.get("effects", []):
			if effect.has("gold"):
				gain += int(effect["gold"])
			if effect.has("spawn_dungeon"):
				spawns.append(String(effect["spawn_dungeon"]))
		var after := content.do_effects(player, key, choice)
		if content.uses(player, key, choice) == uses and (after.get("lines", []) as Array).has(content.say("site.no_room")):
			check(not raise_needed, "%s: %s.%s finds no room for its dungeon" % [tag, key, choice])
			row["refused"].append({"site": key, "action": choice, "why": "no_room", "land": AdventureRegions.id(player.world)})
			pressed[choice] = 1000
			continue
		check(content.uses(player, key, choice) == uses + 1, "%s: %s.%s's use was not counted" % [tag, key, choice])
		check(player.gold == gold - cost + gain, "%s: %s.%s left %d gold, not %d" % [tag, key, choice, player.gold, gold - cost + gain])
		for dungeon in spawns:
			_sites_dungeon(player, id, dungeon, tag, row)
	for name: String in pressed:
		var entry := content.action_of(key, name)
		var prices: Array = entry.get("prices", [])
		if not prices.is_empty() and int(pressed[name]) == prices.size():
			check(content.used_up(player, key, entry), "%s: %s.%s is not used up after its %d prices" % [tag, key, name, prices.size()])
			for action: Array in content.describe(player, key).get("actions", []):
				check(String(action[0]) != id + AdventureSites.ACT + key + ":" + name, "%s: %s.%s still offered once used up" % [tag, key, name])


## Dungeon [param key] of sites plugin [param id], just raised on
## [param player]'s land: on the map, enterable, its cards, name and clues
## the plugin's, and at least its distance's min from the hero.
func _sites_dungeon(player: AdventurePlayer, id: String, key: String, tag: String, row: Dictionary) -> void:
	var content := AdventureSites.provider(id)
	var index := content.dungeon_index(player, key)
	check(index >= 0, "%s: spawn_dungeon %s raised no dungeon" % [tag, key])
	if index < 0:
		return
	var world := player.world
	var slot: Dictionary = world.encounters[index]
	var door := Vector2i(int(slot["x"]), int(slot["y"]))
	var recipe := content.dungeon(key)
	var cards: Array[String] = []
	for card: Variant in recipe.get("cards", []):
		cards.append(String(card))
	check(world.tile_flags(door.x, door.y) & ShandalarWorld.DUNGEON != 0, "%s: dungeon %s is not on the map" % [tag, key])
	check(DungeonDoors.at(world, door) == index, "%s: dungeon %s cannot be entered" % [tag, key])
	check(WorldClues.left_cards(slot) == cards, "%s: dungeon %s does not hold the plugin's cards" % [tag, key])
	check(WorldNames.dungeon_name(index, world) == String(recipe.get("name", key)), "%s: dungeon %s has another name" % [tag, key])
	check(int(slot.get("clues", 0)) == WorldClues.LOCATION | WorldClues.CREATURES | WorldClues.RULES, "%s: dungeon %s is not fully known" % [tag, key])
	var far := door.distance_to(player.tile())
	check(far >= float(recipe.get("distance", {}).get("min", 6)), "%s: dungeon %s lies %.1f tiles away, nearer than its min" % [tag, key, far])
	row["dungeons"].append({"dungeon": key, "land": AdventureRegions.id(world), "slot": index, "tile": [door.x, door.y], "distance": snappedf(far, 0.1)})


## [param player]'s adventure saved and read back (its places, progress
## and dungeons the same), then read again with the plugin taken away: the
## save opens, the places hide with their tiles kept, the progress and the
## dungeons stay.
func _sites_saves(player: AdventurePlayer, id: String, tag: String, row: Dictionary) -> void:
	var text := JSON.stringify(player.to_dict())
	row["save_bytes"] = text.to_utf8_buffer().size()
	var read := AdventurePlayer.from_dict(JSON.parse_string(text))
	check(read != null, tag + ": the save does not read back")
	if read == null:
		return
	check(read.sites == player.sites, tag + ": the plugin's progress changed in the save")
	var again := JSON.stringify(read.to_dict())
	var twice := AdventurePlayer.from_dict(JSON.parse_string(again))
	check(twice != null and JSON.stringify(twice.to_dict()) == again, tag + ": saved, read and saved again, the save changed")
	var marks := []
	for place: Dictionary in row["places"]:
		if String(place["land"]) == AdventureRegions.MAINLAND:
			var mark := id + ":" + String(place["site"])
			marks.append(mark)
			check(_site_tile(read.world, mark) == Vector2i(int(place["tile"][0]), int(place["tile"][1])), "%s: %s moved in the save" % [tag, mark])
	DirAccess.make_dir_recursive_absolute(NO_PLUGINS)
	AdventurePlugins.folders_override = [NO_PLUGINS] as Array[String]
	AdventurePlugins.scan()
	var gone := AdventurePlayer.from_dict(JSON.parse_string(text))
	check(gone != null, tag + ": the save does not open without the plugin")
	if gone != null:
		AdventureExpansions.initialize(gone)
		for mark: String in marks:
			var tile := _site_tile(gone.world, mark)
			check(tile.x >= 0, "%s: without the plugin, %s's tile was lost" % [tag, mark])
			check(AdventureExpansions.marker(gone.world, tile) == "", "%s: without the plugin, %s is still shown" % [tag, mark])
		check(gone.sites.has(id) == player.sites.has(id), tag + ": without the plugin, its progress was dropped")
		for raised: Dictionary in row["dungeons"]:
			check(DungeonDoors.at(gone.world, Vector2i(int(raised["tile"][0]), int(raised["tile"][1]))) == int(raised["slot"]),
				"%s: without the plugin, dungeon %s is gone" % [tag, raised["dungeon"]])
		check(AdventureExpansions.mainland_note(gone) == "", tag + ": a missing sites plugin gets a ship's note")
	AdventurePlugins.folders_override = _plugin_folders
	AdventurePlugins.scan()
