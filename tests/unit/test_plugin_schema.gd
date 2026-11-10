extends GutTest
## ADVENTURE PLUGINS — the content schema, API v1 ([PluginSchema],
## game/adventure/plugins/schema_v1.json): the prototype reads clean and
## normalized, its descriptor carries what the directory reads, and every
## kind of bad content is refused with a reason that names the file and the
## place in it.

const Files := preload("res://tests/support/plugin_files.gd")


func before_each() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)


func after_each() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)


## The problems of the prototype with [param edit] applied (see
## [method Files.read]), one line.
func refusal(edit: Callable) -> String:
	var read := Files.read(Files.REFUGE, edit)
	assert_true(read["data"].is_empty(), "refused content gives no data")
	return "\n".join(read["problems"])


func test_the_schema_file_names_every_content_file_and_its_limits() -> void:
	var spec := PluginSchema.schema()
	assert_eq(int(spec["api_version"]), AdventurePlugins.API_VERSION)
	for name in PluginSchema.CONTENT:
		assert_true(spec["files"].has(name), name)
		assert_true(spec["types"].has(spec["files"][name]["type"]), name)
	assert_eq(int(spec["limits"]["text_chars"]), 4000)
	assert_eq(spec["placeholders"].keys(), PluginText.PLACEHOLDERS as Array, "one closed placeholder list for the game and the tool")


func test_the_prototype_reads_clean_and_normalized() -> void:
	var read := Files.read()
	assert_eq(read["problems"], [] as Array[String])
	var data: Dictionary = read["data"]
	assert_eq(data["id"], "refuge")
	assert_eq(data["packs"], ["pack-2"] as Array[String])
	assert_eq(data["world"]["region"], "refuge")
	assert_true(data["world"]["side"] is int, "whole numbers are ints")
	assert_eq(data["world"]["towns"]["list"].size(), 5)
	assert_eq(data["world"]["dice_salt"], 0x524546)
	assert_eq(data["quests"]["quests"].size(), 5)
	for quest in data["quests"]["quests"]:
		assert_true(quest["complete"] is Array, "a named completion resolves to its effects")
		assert_eq(quest["complete"].size(), 6)
		assert_eq(String(quest["steps"].back()["do"]), "duel")
	assert_eq(data["foes"]["foes"].size(), 6)
	for name in data["foes"]["foes"]:
		assert_eq(DataRegion.deck_of(data["foes"]["foes"][name]).size(), 40, name)
	assert_eq(data["rewards"]["bundles"].size(), 5)
	assert_gt(data["text"].size(), 100)


func test_the_descriptor_carries_what_the_directory_reads() -> void:
	var files := Files.folder(Files.REFUGE)
	var manifest := Files.manifest(files)
	var info := PluginSchema.descriptor(manifest, PluginSchema.read(manifest, files)["data"])
	assert_true(info["plugin"])
	assert_eq(info["id"], "refuge")
	assert_eq(info["pack"], "pack-2")
	assert_eq(info["packs"], ["pack-2"])
	assert_eq(info["title"], "The Last Refuge")
	assert_eq(info["castle_name"], "Ebon Crown")
	assert_eq(info["salt"], 0x46454D, "the built-in island's salt: the same island for the same seed")
	assert_eq(info["palette"], WorldTerrainPalette.LAST_REFUGE)
	assert_eq(info["required_markers"], ["port", "castle"])
	assert_eq(info["required_sites"], [1, 2, 3, 4, 5] as Array[int])
	assert_eq(info["progress_schema"], {"quests": 5, "max_stage": 2, "stage_limits": [2, 2, 0, 1, 0], "max_pending": 60,
		"flags": ["liberated"], "complete_flags": ["liberated"]}, "each quest's own stage limit (steps - 1)")
	assert_eq(info["initial_progress"], {"quests": [], "pending": [], "liberated": false}, "the built-in record's shape")
	assert_eq(info["pictures"], {"refuge_harbor": "art/refuge_harbor.png", "refuge_castle": "art/refuge_castle.png"})
	assert_eq(info["sprites"], {"port": ["art/refuge_port_map.png", 160.0], "castle": ["art/refuge_castle_map.png", 192.0]})
	assert_false(info["mana_links"])
	assert_eq(info["layout_version"], 4)
	assert_false(info.has("provider"), "a plugin names no script")
	assert_false(info.has("cards_unlock"), "a plugin withholds no cards")


func test_a_missing_content_file_and_broken_json_are_refused() -> void:
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["world.json"] = null), "world.json is missing.")
	var files := Files.folder(Files.REFUGE)
	files["quests.json"] = "{\"flags\": [".to_utf8_buffer()
	var read := PluginSchema.read(Files.manifest(files), files)
	assert_true(read["data"].is_empty())
	assert_string_contains("\n".join(read["problems"]), "quests.json: line")
	files["quests.json"] = "{\n\t\"flags\": [],\n\t\"town\": ,\n}".to_utf8_buffer()
	assert_string_contains("\n".join(PluginSchema.read(Files.manifest(files), files)["problems"]), "quests.json: line 3:",
		"lines are counted from 1, as an editor counts them")
	var deep := "[".repeat(40) + "]".repeat(40)
	files = Files.folder(Files.REFUGE)
	files["text.json"] = ("{\"a\": " + deep + "}").to_utf8_buffer()
	assert_string_contains("\n".join(PluginSchema.read(Files.manifest(files), files)["problems"]), "nests deeper than 32")


func test_shapes_are_checked_with_the_place_named() -> void:
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["world.json"]["side"] = "big"), "world.json.side: a whole number is needed.")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["world.json"]["side"] = 99), "world.json.side: 99 is outside 8..32.")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["world.json"]["sides"] = 1), "world.json: unknown field sides.")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["world.json"]["generator"] = "continent"), "world.json.generator: one of island is needed.")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["quests.json"]["quests"][0]["steps"][1]["do"] = "fly"), "quests.json.quests[0].steps[1].do")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["quests.json"]["finale"]["conditions"].append({"flag": "liberated", "not_flag": "liberated"})),
		"an object with one of")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["quests.json"]["finale"]["effects"].append({"summon": true})), "summon is not one of")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["quests.json"]["quests"][1]["steps"][1]["to"] = {"town": 3}), "none of its forms fits")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["quests.json"]["quests"][0]["banner"] = "gold"), "six hex digits")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["text.json"]["story.origin"] = "x".repeat(4001)), "at most 4000")


func test_text_keys_and_placeholders_are_checked() -> void:
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["text.json"].erase("quest.bread.title")), "quests.json.quests[0].title: text.json has no quest.bread.title.")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["text.json"]["status.free"] = "Free, {name}!"), "text.json: status.free: unknown placeholder {name}")
	var read := Files.read(Files.REFUGE, func(f: Dictionary) -> void: f["text.json"]["status.free"] = "A brace { alone, and {} too.")
	assert_eq(read["problems"], [] as Array[String], "braces that are not a placeholder are words")


func test_cards_must_be_base_game_or_of_a_required_pack() -> void:
	var foe := func(card: String) -> Callable:
		return func(f: Dictionary) -> void: f["foes.json"]["foes"]["sporekeeper"]["deck"][card] = 1
	assert_string_contains(refusal(foe.call("Not A Real Card")), "Not A Real Card is not a card of the base game or of a required pack (pack-2).")
	var other := AdventurePacks.owner_of("Necropotence")
	assert_eq(other, "pack-3", "an Ice Age card")
	assert_string_contains(refusal(foe.call("Necropotence")), "Necropotence is not a card")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["rewards.json"]["bundles"][0]["cards"].append("Not A Real Card")), "rewards.json.bundles[0].cards[6]")
	assert_true(PluginSchema.card_known("Lightning Bolt", []), "a base-game card")
	assert_true(PluginSchema.card_known("Thallid", ["pack-2"]), "a required pack's card")
	assert_false(PluginSchema.card_known("Thallid", []), "a pack card without its pack")
	assert_eq(PluginSchema.pack_cards("pack-2"), FallenEmpiresPack.names(), "the trusted list, never a zip's word")


func test_names_between_files_must_exist() -> void:
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["quests.json"]["quests"][2]["foe"] = "nobody"), "quests.json: quests[2].foe: foes.json has no nobody.")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["quests.json"]["finale"]["foe"] = "nobody"), "finale.foe: foes.json has no nobody.")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["foes.json"]["roaming"]["decks"][0]["foe"] = "nobody"), "roaming.decks[0].foe: no foe nobody.")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["quests.json"]["finale"]["conditions"].append({"flag": "crowned"})), "the flag crowned is not declared")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["quests.json"]["quests"][1]["steps"][1]["to"]["objective"] = "reef"), "the objective reef is not in world.json objectives")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["quests.json"]["quests"][0]["complete"] = "medal"), "completions has no medal")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["quests.json"]["finale"]["conditions"].append({"quest_done": 9})), "quest 9 is named; there are 5.")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["quests.json"]["finale"]["conditions"][2]["deck_share"]["pack"] = "pack-3"), "deck_share names pack-3, which the manifest does not require.")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["quests.json"]["flags"].append("port")), "flags: port is a reserved name.")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["rewards.json"] = null), "a reward_choice needs rewards.json bundles.")


func test_the_world_and_the_stage_machine_hold_together() -> void:
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["world.json"]["places"]["list"][0]["slot"] = 1), "slot 1 is taken twice (towns and places)")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["world.json"]["villages"]["slot_step"] = 11), "slot 22 is taken twice (places and villages)")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["world.json"]["villages"]["names"].pop_back()), "villages.names holds 8 names for up to 9 villages")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["world.json"]["dungeon"]["from"] = 10), "reaches past the source's 15 dungeons")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["quests.json"]["quests"][0]["giver"] = 8), "slot 8 is not a town or place of world.json")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["quests.json"]["quests"][1]["giver"] = 1), "slot 1 already gives quest 0")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["quests.json"]["quests"][0]["steps"].reverse()), "the last step must be the duel")
	var two_duels := func(f: Dictionary) -> void:
		f["quests.json"]["quests"][2]["steps"].push_front({"do": "go", "to": "port", "action": "quest.accept", "guidance": "guide.petition", "task": "task.petition"})
		f["quests.json"]["quests"][2]["steps"].push_front({"do": "duel"})
	assert_string_contains(refusal(two_duels), "the duel ends the quest; it must be the last step")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["quests.json"]["quests"][2]["steps"].push_front({"do": "go", "to": "port"})), "a go step needs action")
	var late_accept := func(f: Dictionary) -> void:
		f["quests.json"]["quests"][2]["steps"].insert(0, {"do": "go", "to": "port", "action": "quest.accept", "guidance": "guide.petition", "task": "task.petition"})
		f["quests.json"]["quests"][2]["steps"].insert(1, {"do": "accept"})
	assert_string_contains(refusal(late_accept), "only a quest's first step may be accept")


func test_pictures_files_and_palettes_are_checked() -> void:
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["places.json"]["pictures"]["harbor"] = "art/refuge_harbor.png"), "a picture key begins with the plugin id and _")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["places.json"]["pictures"]["refuge_moon"] = "art/moon.png"), "the plugin has no file art/moon.png")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["places.json"]["markers"]["port"]["sprite"]["file"] = "art/port.gd"), "must end in .png")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["places.json"]["markers"]["castle"]["picture"] = "refuge_moon"), "refuge_moon is neither a picture of places.json nor a skin picture")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["world.json"]["music"] = "music/theme.mp3"), "must end in .ogg")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["plugin.json"]["region"]["palette"] = "neon"), "region.palette: neon is not a built-in palette.")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["plugin.json"]["region"]["palette"] = {"grass": [2, 1, 1, 1]}), "grass: four numbers")
	var read := Files.read(Files.REFUGE, func(f: Dictionary) -> void: f["plugin.json"]["region"]["palette"] = {"name": "Dusk", "water": [0.6, 1.0, 0.9, 0.8]})
	assert_eq(read["problems"], [] as Array[String], "a palette object")


## The review of 2026-11-10 (RV2-1, RV2-2): content that would write a
## progress record the save check refuses is refused at load instead.
func test_a_quest_owes_one_reward_choice_and_the_finale_none() -> void:
	assert_string_contains(refusal(func(f: Dictionary) -> void: (f["quests.json"]["completions"]["pledge"] as Array).push_front({"reward_choice": true})),
		"quests.json: quests[0].complete: one reward_choice at most; a quest owes one reward choice.")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["quests.json"]["finale"]["effects"].append({"reward_choice": true})),
		"quests.json: finale.effects: a reward_choice belongs to a quest's completion, not the finale.")


func test_a_set_stage_stays_inside_its_quests_steps() -> void:
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["quests.json"]["quests"][2]["complete"] = [{"set_stage": {"quest": 4, "value": 3}}]),
		"quests.json: quests[2].complete: set_stage: quest 4 has 1 step; its stage goes up to 0.")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["quests.json"]["finale"]["effects"].append({"set_stage": {"quest": 0, "value": 3}})),
		"quests.json: finale.effects: set_stage: quest 0 has 3 steps; its stage goes up to 2.")
	var read := Files.read(Files.REFUGE, func(f: Dictionary) -> void: f["quests.json"]["quests"][2]["complete"] = [{"set_stage": {"quest": 0, "value": 2}}])
	assert_eq(read["problems"], [] as Array[String], "a stage inside the steps")


func test_only_the_finale_sets_its_flag() -> void:
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["quests.json"]["quests"][2]["complete"] = [{"set_flag": "liberated"}]),
		"quests.json: quests[2].complete: set_flag: liberated is the finale's flag; only the finale's effects set it.")
	assert_string_contains(refusal(func(f: Dictionary) -> void: f["quests.json"]["completions"]["pledge"].append({"set_flag": "liberated"})),
		"quests.json: quests[0].complete: set_flag: liberated is the finale's flag")


func test_the_waiting_cards_allowed_follow_the_rewards_owed() -> void:
	var files := Files.folder(Files.REFUGE)
	var big := Files.read(Files.REFUGE, func(f: Dictionary) -> void:
		f["rewards.json"]["count"] = 15
		for bundle in f["rewards.json"]["bundles"]:
			while bundle["cards"].size() < 15: bundle["cards"].append(bundle["cards"][0]))
	assert_eq(big["problems"], [] as Array[String])
	var manifest := Files.manifest(files)
	assert_eq(PluginSchema.descriptor(manifest, big["data"])["progress_schema"]["max_pending"], 75, "five quests owing fifteen cards each")
	assert_eq(PluginSchema.descriptor(manifest, Files.read()["data"])["progress_schema"]["max_pending"], 60, "never below the built-in sixty")
