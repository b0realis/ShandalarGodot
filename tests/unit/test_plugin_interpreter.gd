extends GutTest
## ADVENTURE PLUGINS — the interpreter ([DataRegion]) beyond what the Last
## Refuge itself uses: a quest's steps to a site and to the castle, every
## condition and effect of the closed sets, the roaming rules' switches, and
## an absent plugin answering nothing.

const Files := preload("res://tests/support/plugin_files.gd")

var player: AdventurePlayer


func before_each() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	var setup := AdventureSetup.new()
	setup.adventures = ["refuge"]
	setup.packs = ["pack-2"]
	setup.seed_text = "48271"
	setup.player_name = "Wayfarer"
	var record := setup.resolve({"pack-2": "1"})
	player = AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	assert_true((AdventureExpansions.provider("refuge") as DataRegion).travel(player))


func after_each() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)


## The prototype's interpreter on its data with [param edit] applied.
func region(edit := Callable()) -> DataRegion:
	var read := Files.read(Files.REFUGE, edit)
	assert_eq(read["problems"], [] as Array[String])
	return DataRegion.new("refuge", read["data"])


func test_steps_to_a_site_and_to_the_castle_follow_the_stages() -> void:
	var made := region(func(f: Dictionary) -> void:
		f["quests.json"]["quests"][0]["steps"] = [{"do": "accept"},
			{"do": "go", "to": {"site": 43}, "action": "quest.bread.deliver", "guidance": "quest.bread.guide", "task": "quest.bread.task", "line": "quest.harbor.line"},
			{"do": "duel", "at": "castle", "approach": {"action": "quest.mountain.confront", "line": "quest.mountain.line"}}])
	assert_eq(made.stage(player, 0), 0)
	assert_eq(made.destination(player, 0)["tile"], Quests.site_tile(player.world, 1), "the giver first")
	assert_true(made.start(player, 0))
	assert_false(made.start(player, 0), "accepted once")
	var oasis := Quests.site_tile(player.world, 43)
	assert_eq(made.destination(player, 0), {"tile": oasis, "name": "Thelon's Oasis", "slot": 43})
	assert_eq(made.destination_slot(player, 0), 43)
	var town := made.decorate_town(player, 43, {"lines": [], "actions": []})
	assert_eq(town["actions"][0][0], "refuge_deliver_0", "the go step's button at its site")
	assert_eq(town["lines"], [made.say("quest.harbor.line")], "and its line")
	assert_false(made.deliver(player, 0), "not there yet")
	player.position = oasis * 32 + Vector2i(16, 16)
	assert_true(made.deliver(player, 0))
	assert_eq(made.stage(player, 0), 2)
	assert_true(made.ready(player, 0), "the duel is the current step")
	var point: Array = player.world.expansion["castle"]
	var castle := Vector2i(point[0], point[1])
	assert_eq(made.destination(player, 0)["tile"], castle)
	var pane := made.describe(player, castle)
	assert_eq(pane["actions"][0][0], "refuge_petition_0", "the duel's approach at the castle")
	assert_true(pane["lines"].has(made.say("quest.mountain.line")))
	assert_eq(String(player.journal.back()["event"]), "quest_clue", "each stage logs its guidance")


func test_every_condition_reads_progress_the_deck_and_the_place() -> void:
	var made := region()
	var state: Dictionary = player.expansions["refuge"]
	assert_true(made.holds(player, []), "no condition: always")
	assert_true(made.holds(player, [{"not_flag": "liberated"}]))
	assert_false(made.holds(player, [{"flag": "liberated"}]))
	state["liberated"] = true
	assert_true(made.holds(player, [{"flag": "liberated"}]))
	state["liberated"] = false
	state["stages"] = {"1": 1}
	assert_true(made.holds(player, [{"stage": {"quest": 1, "min": 1, "max": 1}}]))
	assert_false(made.holds(player, [{"stage": {"quest": 1, "min": 2, "max": 8}}]))
	assert_false(made.holds(player, [{"quest_done": 3}]))
	state["quests"] = [3, 0]
	assert_true(made.holds(player, [{"quest_done": 3}]))
	assert_true(made.holds(player, [{"quests_done": 2}]))
	assert_false(made.holds(player, [{"quests_done": 3}]))
	assert_false(made.holds(player, [{"quests_done": "all"}]))
	assert_true(made.holds(player, [{"on_region": true}]))
	assert_false(made.holds(player, [{"on_region": false}]))
	var point: Array = player.world.expansion["port"]
	player.position = Vector2i(point[0], point[1]) * 32 + Vector2i(16, 16)
	assert_true(made.holds(player, [{"here": "port"}]))
	assert_false(made.holds(player, [{"here": "castle"}]))
	assert_false(made.holds(player, [{"rewards_owed": true}]))
	state["reward_choices"] = [3]
	assert_true(made.holds(player, [{"rewards_owed": true}]))
	assert_true(made.holds(player, [{"cards_pending": false}]))
	state["pending"] = ["Thallid"]
	assert_true(made.holds(player, [{"cards_pending": true}]))
	player.cards.clear()
	for i in 3: player.cards.append({"card": "Thallid", "decks": [0]})
	player.cards.append({"card": "Grizzly Bears", "decks": [0]})
	assert_true(made.holds(player, [{"deck_share": {"pack": "pack-2", "percent": 75}}]), "3 of 4")
	assert_false(made.holds(player, [{"deck_share": {"pack": "pack-2", "percent": 76}}]))
	assert_eq(made.gate_for_cards(["Thallid", "Grizzly Bears", "Forest"], {"pack": "pack-2", "percent": 34}),
		{"count": 1, "total": 2, "ready": true, "required": 1})


func test_every_effect_changes_only_what_it_names() -> void:
	var made := region()
	var state: Dictionary = player.expansions["refuge"]
	player.gold = 5
	player.food = 3
	made.apply(player, [{"gold": -20}, {"food": 4}], -1)
	assert_eq(player.gold, 0, "never below nothing")
	assert_eq(player.food, 7)
	made.apply(player, [{"set_flag": "liberated"}], -1)
	assert_true(state["liberated"])
	made.apply(player, [{"set_stage": {"quest": 3, "value": 1}}], -1)
	assert_eq(made.stage(player, 3), 1)
	made.apply(player, [{"reward_choice": true}], -1)
	assert_eq(state.get("reward_choices", []), [], "the finale owes no reward choice")
	made.apply(player, [{"reward_choice": true}], 4)
	assert_eq(state["reward_choices"], [4])
	made.apply(player, [{"log_clue": {"text": "story.vault", "quest": false}}], -1)
	assert_eq(player.journal.back()["text"], made.say("story.vault"))
	made.apply(player, [{"log_event": {"event": "omen", "text": "quest.done_log", "done": true}}], 2)
	assert_eq(player.journal.back()["event"], "omen")
	assert_string_contains(player.journal.back()["text"], made.say("quest.masters.title"), "with the quest's own words")
	state["pending"] = ["Thallid"]
	made.apply(player, [{"claim_cards": true}], -1)
	assert_eq(state["pending"], [])
	state["quests"] = [1]
	var revision := player.world.appearance_revision
	made.apply(player, [{"refresh_appearance": true}], -1)
	assert_gt(player.world.appearance_revision, revision)
	assert_eq(player.world.expansion["freed_communities"], [1])
	assert_true(player.world.expansion["liberated"])
	assert_eq(player.world.expansion["banners"].size(), 2, "the freed community's and the castle's")


func test_the_roaming_rules_switches() -> void:
	var meeting := {"color": 3, "kind": 1, "row": 8, "slot": 2, "wins": 0}
	var never := region(func(f: Dictionary) -> void:
		f["foes.json"]["roaming"]["skip"]["every"] = 0
		f["foes.json"]["roaming"]["ante"] = "creature")
	var found := meeting.duplicate()
	never.roaming_encounter(player, found)
	assert_eq(found["regional_name"], "Havenwood Spores", "green, the creature's own color")
	assert_eq(found["regional_life"], 30)
	assert_false(found.has("creature_ante"), "the creature keeps its own ante")
	var others := region(func(f: Dictionary) -> void:
		f["foes.json"]["roaming"]["skip"]["every"] = 0
		f["foes.json"]["roaming"]["decks"][4]["colors"] = ["red"])
	var green := meeting.duplicate()
	others.roaming_encounter(player, green)
	assert_false(green.has("regional_deck"), "no deck for its color: the creature's own")
	var town := meeting.duplicate()
	town["town"] = 1
	never.roaming_encounter(player, town)
	assert_false(town.has("regional_deck"), "a town's encounter stays exact")
	assert_eq(never.roaming_tier(player, 3), 12)
	var tame := region(func(f: Dictionary) -> void: f["foes.json"].erase("roaming"))
	assert_eq(tame.roaming_tier(player, 3), 3, "no roaming rules, no change")
	assert_eq(tame.study_decks().size(), 1, "the finale's deck alone")


func test_an_absent_plugin_answers_nothing() -> void:
	var gone := DataRegion.new("nobody_here")
	assert_true(gone.data().is_empty())
	assert_eq(gone.describe(player, player.tile()), {})
	assert_eq(gone.status_lines(player), [] as Array[String])
	assert_null(gone.generate(1, 1, 1))
	assert_null(gone.music())
	assert_eq(gone.tales(player), [])
	assert_eq(gone.news(player), "")
	var place := {"lines": ["x"], "actions": []}
	assert_eq(gone.decorate_town(player, 1, place), place)
	assert_false(gone.available())


func test_the_refuge_has_no_music_and_the_interpreter_streams_a_track_by_name() -> void:
	assert_null((AdventureExpansions.provider("refuge") as DataRegion).music(), "the prototype ships no track")
	var made := region()
	made.data()["world"]["music"] = "music/none.ogg"
	assert_null(made.music(), "a track the plugin does not hold plays nothing")


## The review of 2026-11-10 (RV2-1): a quest is owed one reward choice,
## however many its effects ask for — two would make the save unreadable.
func test_a_quest_is_owed_one_reward_choice_however_its_effects_ask() -> void:
	var made := region()
	var state: Dictionary = player.expansions["refuge"]
	made.apply(player, [{"reward_choice": true}, {"reward_choice": true}], 2)
	assert_eq(state["reward_choices"], [2])
	made.apply(player, [{"reward_choice": true}], 2)
	assert_eq(state["reward_choices"], [2], "still owed once")
	made.apply(player, [{"reward_choice": true}], 3)
	assert_eq(state["reward_choices"], [2, 3])
