extends GutTest

var screen: WorldScreen
const SAVES := "user://refuge_ui_tests"
const NO_PLUGINS := "user://refuge_ui_tests_no_plugins"


func before_each() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.adventures = ["refuge"]
	setup.packs = ["pack-2"]
	setup.seed_text = "12345"
	setup.player_name = "Wayfarer"
	screen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.record = setup.resolve({"pack-2": "1"})
	add_child_autofree(screen)
	await get_tree().process_frame

func after_each() -> void:
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file in dir.get_files(): dir.remove(file)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	if not AdventurePlugins.folders_override.is_empty():
		AdventurePlugins.folders_override = [] as Array[String]
		AdventurePlugins.scan()

func choose(action: String) -> void:
	screen._visit.choose(action)
	await get_tree().process_frame
	await get_tree().process_frame
	# Leaving a community may offer World Magic before returning to the map.
	# Dismiss that real pane before the fixture walks to its next destination.
	if action == "leave" and WorldScreen._alive(screen._magic_seller):
		screen._magic_seller.close()
		await get_tree().process_frame
		await get_tree().process_frame

func test_disabling_pack_closes_mainland_harbor_and_removes_its_interaction() -> void:
	var point: Array = screen.world.expansion["entries"]["refuge"].duplicate()
	var port := Vector2i(point[0], point[1])
	screen.player.position = port * 32 + Vector2i(16, 16)
	screen.show_player(screen.player)
	screen.visit(port)
	assert_true(screen.visiting())
	var revision := screen.world.appearance_revision
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(screen.visiting())
	assert_true(screen.place_at(port).is_empty())
	assert_gt(screen.world.appearance_revision, revision, "all three map caches refresh")
	assert_eq(screen.world.expansion["entries"]["refuge"], point, "saved location is kept")
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	assert_eq(screen.place_at(port).get("kind"), "region_port")

func test_fresh_disabled_campaign_gains_harbor_when_pack_is_enabled() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	var setup := AdventureSetup.new()
	setup.adventures = ["refuge"]
	setup.packs = ["pack-2"]
	setup.seed_text = "48271"
	var record := setup.resolve({"pack-2": "1"})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	screen.show_player(player)
	assert_false(screen.world.expansion.get("entries", {}).has("refuge"))
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	assert_true(screen.world.expansion.get("entries", {}).has("refuge"))

func test_rescan_pack_loss_hides_mainland_entry_and_restoration_recovers_it() -> void:
	var point: Array = screen.world.expansion["entries"]["refuge"].duplicate()
	var port := Vector2i(point[0], point[1])
	screen.player.position = port * 32 + Vector2i(16, 16)
	screen.show_player(screen.player)
	screen.visit(port)
	# Reproduce discovery losing the ZIP while its enabled preference remains.
	# No real pack files or registry definitions are changed by this UI fixture.
	var report: Dictionary = CardPacks._available[FallenEmpiresPack.ID]
	CardPacks._available.erase(FallenEmpiresPack.ID)
	CardPacks.rescanned.emit()
	await get_tree().process_frame
	assert_true(Settings.enabled_card_packs().has(FallenEmpiresPack.ID))
	assert_false(screen.visiting())
	assert_true(screen.place_at(port).is_empty())
	assert_eq(screen.world.expansion["entries"]["refuge"], point)
	CardPacks._available[FallenEmpiresPack.ID] = report
	CardPacks.rescanned.emit()
	assert_eq(screen.place_at(port).get("kind"), "region_port")

func test_disabled_pack_still_returns_home_through_the_real_ship_button() -> void:
	var point: Array = screen.world.expansion["entries"]["refuge"].duplicate()
	var port := Vector2i(point[0], point[1])
	screen.player.position = port * 32 + Vector2i(16, 16)
	screen.show_player(screen.player)
	screen.visit(port)
	await choose("refuge_sail")
	assert_true(_refuge().on_island(screen.player))
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	assert_true(screen.visiting())
	assert_true(screen._visit.place["actions"][0][2], "return remains enabled")
	await choose("refuge_sail")
	assert_false(_refuge().on_island(screen.player))
	assert_eq(screen.player.tile(), port)
	assert_false(screen.visiting(), "the vanished mainland town opens no empty pane")
	assert_true(screen.place_at(port).is_empty())
	assert_true(screen.player.regions.has("refuge"))

## §0.5 of the plugin spec: a save whose plugin is gone opens; at the
## island's port the game's own "Ship home" pane sails home, stale plugin
## buttons do nothing, and the progress waits for the plugin's return.
func test_a_saved_island_whose_plugin_is_missing_sails_home_and_keeps_its_rewards() -> void:
	assert_true(_refuge().travel(screen.player))
	screen.player.expansions["refuge"]["pending"] = ["Thallid"]
	screen.player.expansions["refuge"]["quests"] = [0]
	screen.player.expansions["refuge"]["reward_choices"] = [0]
	var saved := screen.player.to_dict()
	DirAccess.make_dir_recursive_absolute(NO_PLUGINS)
	AdventurePlugins.folders_override = [NO_PLUGINS] as Array[String]
	AdventurePlugins.scan()
	assert_false(AdventurePlugins.valid("refuge"), "the plugin is gone")
	var loaded := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(saved)))
	assert_not_null(loaded, "the save still opens")
	if loaded == null: return
	screen.show_player(loaded)
	var port: Array = loaded.world.expansion["port"]
	screen.visit(Vector2i(port[0], port[1]))
	assert_true(screen.visiting())
	assert_eq(screen._visit.place["actions"][0][0], AdventureExpansions.HOME_ACTION)
	assert_true(screen._visit.place["actions"][0][2], "the ship home is always offered")
	var cards := loaded.cards.duplicate(true)
	# Stale/direct actions cannot collect or advance the missing land's content.
	for stale in ["refuge_claim", "refuge_accept_1", "refuge_reward_0"]:
		assert_false(AdventureExpansions.act(screen, stale, {}), stale)
	assert_eq(loaded.cards, cards)
	assert_eq(loaded.expansions["refuge"]["pending"], ["Thallid"])
	assert_eq(loaded.expansions["refuge"]["reward_choices"], [0])
	await choose(AdventureExpansions.HOME_ACTION)
	assert_true(AdventureRegions.mainland(screen.player))
	assert_false(screen.visiting())
	assert_true(screen.player.regions.has("refuge"))
	AdventurePlugins.folders_override = [] as Array[String]
	AdventurePlugins.scan()
	assert_true(AdventurePlugins.valid("refuge"), "reinstalled")
	assert_eq(screen.player.expansions["refuge"]["pending"], ["Thallid"], "its progress kept byte for byte")
	assert_eq(screen.player.expansions["refuge"]["reward_choices"], [0])
	DirAccess.remove_absolute(NO_PLUGINS)

func test_harbor_buttons_sail_and_return_through_real_visit_pane() -> void:
	var coords: Array = screen.world.expansion["entries"]["refuge"]
	var port := Vector2i(coords[0], coords[1])
	screen.player.position = port * 32 + Vector2i(16, 16)
	screen.show_player(screen.player)
	var pane := screen.visit(port)
	assert_not_null(pane)
	assert_eq(pane.place["kind"], "region_port")
	assert_eq(pane._art.texture, AdventureExpansions.picture("refuge_harbor"))
	assert_eq(pane.place["actions"][0][1], "Sail to the Island")
	await choose("refuge_sail")
	assert_true(_refuge().on_island(screen.player))
	assert_eq(screen._visit.place["actions"][0][1], "Sail to Shandalar")
	assert_true(screen.visiting())
	assert_eq(screen.walk.player, screen.player)
	await choose("refuge_leave")
	assert_false(screen.visiting())
	screen.visit(screen.player.tile(), false)
	await choose("refuge_sail")
	assert_false(_refuge().on_island(screen.player))
	assert_eq(screen.player.tile(), port)
	assert_not_null(AdventurePlayer.load_from(screen.player.save_path()))

func test_town_petition_opens_full_duel_and_result_only_rewards_once() -> void:
	assert_true(_refuge().travel(screen.player))
	var town: Dictionary = screen.player.world.sites[1]
	screen.player.position = Vector2i(town["x"], town["y"]) * 32 + Vector2i(16, 16)
	screen.show_player(screen.player)
	var pane := screen.visit(screen.player.tile())
	assert_eq(pane.place["name"], _refuge().giver_name(0))
	await choose("refuge_quest")
	assert_eq(screen._visit.place["name"], "The Bread Road")
	await choose("refuge_accept_0")
	assert_false(_refuge().ready(screen.player, 0))
	await choose("refuge_back")
	await choose("leave")
	var destination: Vector2i = _refuge().destination(screen.player, 0)["tile"]
	screen.player.position = destination * 32 + Vector2i(16, 16)
	screen.visit(destination, false)
	await choose("refuge_deliver_0")
	assert_true(_refuge().ready(screen.player, 0))
	await choose("refuge_leave")
	screen.player.position = Vector2i(town["x"], town["y"]) * 32 + Vector2i(16, 16)
	screen.visit(screen.player.tile(), false)
	await choose("refuge_quest")
	await choose("refuge_fight")
	var host: WorldDuels
	for node in screen.get_children():
		if node is WorldDuels: host = node
	assert_not_null(host, "the existing duel host is used")
	assert_true(screen._duel_held)
	if host == null: return
	# Settle a finished report through the same signal as DuelScreen.
	var report := DuelReport.new()
	report.finished = true
	report.result = DuelReport.WIN
	report.winner = 0
	host.ended.emit(report)
	screen.hold_for_duel(false)
	host.queue_free()
	await get_tree().process_frame
	assert_true(_refuge().completed(screen.player, 0))
	assert_eq(screen._visit.place["subtitle"], "Victory")
	await choose("refuge_back")
	assert_eq(screen._visit.place["name"], _refuge().giver_name(0))
	assert_true(Sieges.calm(screen.player))

func test_castle_art_scale_and_count_gate_are_visible() -> void:
	assert_true(_refuge().travel(screen.player))
	var point: Array = screen.player.world.expansion["castle"]
	screen.player.position = Vector2i(point[0], point[1]) * 32 + Vector2i(16, 16)
	screen.show_player(screen.player)
	var pane := screen.visit(screen.player.tile())
	assert_eq(pane._art.texture, AdventureExpansions.picture("refuge_castle"))
	assert_false(pane.place["actions"][0][2])
	var gate := _refuge().deck_gate(screen.player)
	assert_string_contains(pane.place["lines"][1], "%d of %d nonland cards are from Fallen Empires" % [gate["count"], gate["total"]])
	assert_string_contains(pane.place["lines"][2], "at least %d Fallen Empires nonlands" % maxi(1, ceili(float(gate["total"]) / 2.0)))
	assert_string_contains(pane.place["lines"][2], "All lands are excluded")
	assert_eq(AdventureExpansions.map_op("refuge:castle")[1].size.x, 192.0)
	assert_eq(AdventureExpansions.map_op("refuge:port")[1].size.x, 160.0)

func test_island_dungeon_visit_opens_and_leaves_the_existing_board() -> void:
	assert_true(_refuge().travel(screen.player))
	var dungeon: Dictionary = screen.player.world.encounters[5]
	screen.player.position = Vector2i(dungeon["x"], dungeon["y"]) * 32 + Vector2i(16, 16)
	screen.show_player(screen.player)
	var pane := screen.visit(screen.player.tile())
	assert_eq(pane.place["kind"], "dungeon")
	assert_eq(pane.place["name"], "Vaults of the First Crossing")
	await choose("enter")
	assert_true(screen._board is DungeonPane)
	var dungeon_pane: DungeonPane = screen._board
	if dungeon_pane == null: return
	assert_eq(dungeon_pane.board.title(), "Vaults of the First Crossing")
	if dungeon_pane.step == "box": dungeon_pane.choose("go")
	dungeon_pane.choose("go")
	dungeon_pane.choose("leave")
	dungeon_pane.choose("leave")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_null(screen._board)
	assert_false(screen.player.expansions["refuge"]["liberated"])
	assert_eq(screen.player.expansions["refuge"]["quests"], [])

func test_added_village_offers_a_local_quest_separate_from_mainland_and_pledges() -> void:
	var mainland_quest := {"type": Quests.LETTER_AMULET, "destination": 8,
		"giver": 16, "color": 1, "data": -1, "deadline": 80}
	screen.player.quest = mainland_quest.duplicate()
	assert_true(_refuge().travel(screen.player))
	assert_true(screen.player.quest.is_empty())
	var village: Dictionary = screen.player.world.sites[8]
	screen.player.position = Vector2i(village["x"], village["y"]) * 32 + Vector2i(16, 16)
	screen.show_player(screen.player)
	var pane := screen.visit(screen.player.tile())
	assert_eq(pane.place["kind"], "village")
	assert_true(Quests.offered(screen.player, 8))
	assert_ne(Quests.accept(screen.player, 8), "")
	var local_quest := screen.player.quest.duplicate(true)
	assert_eq(local_quest["giver"], 8)
	var destination := int(local_quest["destination"])
	assert_gt(screen.player.world.sites[destination]["type"], 0)
	if int(local_quest["type"]) >= 0:
		assert_eq(WorldStatus.targets(screen.player)[0]["kind"], "quest")
	assert_true(_refuge().travel(screen.player))
	assert_eq(screen.player.quest, mainland_quest)
	assert_true(_refuge().travel(screen.player))
	assert_eq(screen.player.quest, local_quest)
	assert_eq(screen.player.expansions["refuge"]["quests"], [])

func test_draw_loss_and_retry_keep_pledges_and_rewards_honest() -> void:
	assert_true(_refuge().travel(screen.player))
	var town: Dictionary = screen.player.world.sites[3]
	screen.player.position = Vector2i(town["x"], town["y"]) * 32 + Vector2i(16, 16)
	screen.show_player(screen.player)
	screen.visit(screen.player.tile())
	var gold := screen.player.gold
	var cards := screen.player.cards.size()
	for result in [DuelReport.DRAW, DuelReport.LOSS, DuelReport.WIN]:
		await choose("refuge_quest")
		await choose("refuge_fight")
		var host: WorldDuels
		for child in screen.get_children():
			if child is WorldDuels and not child.is_queued_for_deletion(): host = child
		assert_not_null(host)
		if host == null: return
		var report := DuelReport.new()
		report.finished = true
		report.result = result
		report.winner = 0 if result == DuelReport.WIN else 1
		host._finish(report)
		await get_tree().process_frame
		assert_false(screen._duel_held)
		assert_true(screen.visiting())
		assert_eq(_refuge().completed(screen.player, 2), result == DuelReport.WIN)
		if result != DuelReport.WIN:
			assert_eq(screen.player.gold, gold)
			assert_eq(screen.player.cards.size(), cards)
		await choose("refuge_back")
	assert_eq(screen.player.gold, gold + 40)
	await choose("refuge_quest")
	assert_false(screen._visit.place["actions"].any(func(action: Array) -> bool: return action[0] == "refuge_fight"), "completed pledge cannot be farmed")
	var saved := AdventurePlayer.load_from(screen.player.save_path())
	assert_not_null(saved)
	if saved == null: return
	assert_true(_refuge().completed(saved, 2))

func test_survey_village_objective_and_reward_choice_use_real_buttons() -> void:
	assert_true(_refuge().travel(screen.player))
	for quest in [1, 3]:
		var tile := Quests.site_tile(screen.player.world, quest + 1)
		screen.player.position = tile * 32 + Vector2i(16, 16)
		screen.show_player(screen.player)
		screen.visit(tile, false)
		await choose("refuge_quest")
		await choose("refuge_accept_%d" % quest)
		await choose("refuge_back")
		await choose("leave")
		tile = _refuge().destination(screen.player, quest)["tile"]
		screen.player.position = tile * 32 + Vector2i(16, 16)
		screen.visit(tile, false)
		if quest == 1:
			assert_eq(screen._visit.place["actions"][0][0], "refuge_deliver_1")
			await choose("refuge_deliver_1")
			assert_true(_refuge().ready(screen.player, 1))
		else:
			assert_eq(screen._visit.place["actions"][0][0], "refuge_petition_3")
			await choose("refuge_petition_3")
			assert_true(screen._visit.place["actions"][0][2], "the confrontation is offered at the village")
		await choose("refuge_leave")
	assert_true(_refuge().finish_quest(screen.player, 2))
	var tile := Quests.site_tile(screen.player.world, 3)
	screen.player.position = tile * 32 + Vector2i(16, 16)
	screen.visit(tile, false)
	await choose("refuge_quest")
	await choose("refuge_reward")
	assert_eq(screen._visit.place["name"], "The Communities' Spells")
	var before := screen.player.cards.size()
	await choose("refuge_reward_4")
	assert_eq(screen.player.cards.size(), before + 6)
	assert_true(screen.player.expansions["refuge"]["reward_choices"].is_empty())
	await choose("refuge_reward_999")
	assert_eq(screen.player.cards.size(), before + 6)

func test_tasks_tab_tracks_selected_petition_and_updates_world_guides() -> void:
	assert_true(_refuge().travel(screen.player))
	screen.show_player(screen.player)
	var panel := HeroStats.new()
	panel.player = screen.player
	add_child_autofree(panel)
	panel.tab = "Tasks"
	panel.refresh()
	await get_tree().process_frame
	var button := panel.find_child("Task_refuge_pledge_0", true, false) as Button
	assert_not_null(button)
	if button == null: return
	button.pressed.emit()
	await get_tree().process_frame
	assert_eq(screen.player.tracked_task, "refuge/pledge:0")
	screen._show_hero()
	assert_eq(screen.guides.targets.size(), 1)
	assert_eq(screen.guides.targets[0]["tile"], Quests.site_tile(screen.player.world, 1))
	assert_true(_refuge().start(screen.player, 0))
	screen._show_hero()
	var point: Array = screen.player.world.expansion["port"]
	assert_eq(screen.guides.targets[0]["tile"], Vector2i(point[0], point[1]))

## The prototype plugin's interpreter ([DataRegion]).
func _refuge() -> DataRegion:
	return AdventureExpansions.provider("refuge") as DataRegion
