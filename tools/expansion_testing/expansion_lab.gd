extends Node
## Repeatable region invariants and independent deck/life battle baselines.
## With `--plugin FOLDER` (expansion_lab.sh copies the plugin there) the
## region is that adventure plugin, the run's only one: it must pass the
## game's own checks ([AdventurePlugins]) first, and a plugin that needs no
## card pack is taken away mid-trip (its folder emptied, as a player who
## removes it) where a pack plugin's pack is switched off.
const BEACON = preload("res://tools/expansion_testing/beacon_region.gd")
## A plugin land played to its end on the model's results, saves read back
## (the lead's ruling on review RV2).
const CAMPAIGN = preload("res://tools/expansion_testing/lab_campaign.gd")
## The plugins folder a plugin needing no pack is "removed" to.
const NO_PLUGINS := "user://expansion_lab_no_plugins"
var failures: Array[String] = []
var _plugin_folders: Array[String] = []
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
	report["failures"] = failures
	var out: String = options["--out"]
	var file := FileAccess.open(out.path_join("results.json"), FileAccess.WRITE)
	if file == null:
		printerr("Cannot write results.json")
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	var summary := "%d scenarios; %d campaigns; %d duels; %d failures.\n%s\n" % [report["scenarios"].size(), report["campaigns"].size(), report["duels"].size(), failures.size(), report["scope"]]
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
	report["plugin"] = {"id": row["id"], "version": row["version"], "name": row["name"], "kind": row["kind"]}
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
