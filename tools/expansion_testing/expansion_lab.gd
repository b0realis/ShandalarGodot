extends Node
## Repeatable region invariants and independent deck/life battle baselines.
const BEACON = preload("res://tools/expansion_testing/beacon_region.gd")
var failures: Array[String] = []
var report := {"tool": "expansion_lab", "scenarios": [], "duels": [], "rated": false}

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var options := {"--out": "", "--region": "refuge", "--seeds": "5,37,48271", "--trips": "3", "--games": "0", "--lives": "10,20,30"}
	var index := 0
	while index < args.size():
		if args[index] not in options or index + 1 >= args.size():
			printerr("Unknown option or missing value: " + args[index])
			get_tree().quit(2)
			return
		options[args[index]] = args[index + 1]
		index += 2
	if not OS.has_feature("shandalar_test") or options["--out"] == "":
		printerr("Use expansion_lab.sh --out NEW_DIRECTORY")
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
	AdventureExpansions.register_development(BEACON.ID, BEACON.descriptor())
	var region: String = options["--region"]
	if not AdventureExpansions.definitions().has(region):
		printerr("Unknown region: " + region)
		get_tree().quit(2)
		return
	var service := get_tree().root.get_node("CardPacks")
	service.set_enabled("pack-2", region == "refuge")
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
	report["scope"] = "Scenario invariants and deck/life baselines; not a complete human campaign simulation. No ratings are written."
	var rules := RulesOptions.new()
	rules.set_preset("modern_mana_burn")
	for fork in RulesOptions.FORKS: Settings.set_rule(fork["key"], rules.get_fork(fork["key"]), false)
	for seed_value in seeds:
		for id in [region, BEACON.ID] if region != BEACON.ID else [region]:
			_scenario(id, seed_value, int(options["--trips"]))
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
	var summary := "%d scenarios; %d duels; %d failures.\n%s\n" % [report["scenarios"].size(), report["duels"].size(), failures.size(), report["scope"]]
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
	setup.expanded_adventure = true
	var pack: String = AdventureExpansions.definition(region).get("pack", "")
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
		if pack != "": get_tree().root.get_node("CardPacks").set_enabled(pack, false)
		else:
			AdventureExpansions._development[region]["enabled"] = false
			AdventureExpansions.refresh()
		check(not AdventureExpansions.enabled(region), "Fixture failed to disable region")
		check(AdventureRegions.travel(player, AdventureRegions.MAINLAND), "Return failed with disabled region")
		check(AdventureExpansions.places(player.world).all(func(place: Dictionary) -> bool: return region not in place.get("destinations", [])), "Disabled departure remains visible")
		if pack != "": get_tree().root.get_node("CardPacks").set_enabled(pack, true)
		else:
			AdventureExpansions._development[region]["enabled"] = true
			AdventureExpansions.refresh()
		check(player.world.fingerprint() == mainland, "Mainland changed")
		check(AdventureExpansions._providers.is_empty(), "Inactive provider retained")
	report["scenarios"].append({"region": region, "seed": seed_value, "trips": trips, "save_bytes": bytes, "memory_delta_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)) - memory_before, "milliseconds": Time.get_ticks_msec() - started, "failures": failures.size() - before})
