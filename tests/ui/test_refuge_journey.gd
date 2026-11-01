extends GutTest

var screen: WorldScreen
const SAVES := "user://refuge_ui_tests"

func before_each() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.seed_text = "12345"
	setup.player_name = "Wayfarer"
	screen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.record = setup.resolve({})
	add_child_autofree(screen)
	await get_tree().process_frame

func after_each() -> void:
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file in dir.get_files(): dir.remove(file)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)

func choose(action: String) -> void:
	screen._visit.choose(action)
	await get_tree().process_frame
	await get_tree().process_frame

func test_harbor_buttons_sail_and_return_through_real_visit_pane() -> void:
	var coords: Array = screen.world.expansion["port"]
	var port := Vector2i(coords[0], coords[1])
	screen.player.position = port * 32 + Vector2i(16, 16)
	screen.show_player(screen.player)
	var pane := screen.visit(port)
	assert_not_null(pane)
	assert_eq(pane.place["kind"], "refuge_port")
	assert_eq(pane._art.texture, RefugeArt.HARBOR)
	assert_eq(pane.place["actions"][0][1], "Sail to the Island")
	await choose("refuge_sail")
	assert_true(RefugeCampaign.on_island(screen.player))
	assert_eq(screen._visit.place["actions"][0][1], "Sail to Shandalar")
	assert_true(screen.visiting())
	assert_eq(screen.walk.player, screen.player)
	await choose("refuge_leave")
	assert_false(screen.visiting())
	screen.visit(screen.player.tile(), false)
	await choose("refuge_sail")
	assert_false(RefugeCampaign.on_island(screen.player))
	assert_eq(screen.player.tile(), port)
	assert_not_null(AdventurePlayer.load_from(screen.player.save_path()))

func test_town_petition_opens_full_duel_and_result_only_rewards_once() -> void:
	assert_true(RefugeCampaign.travel(screen.player))
	var town: Dictionary = screen.player.world.sites[1]
	screen.player.position = Vector2i(town["x"], town["y"]) * 32 + Vector2i(16, 16)
	screen.show_player(screen.player)
	var pane := screen.visit(screen.player.tile())
	assert_eq(pane.place["name"], RefugeWorld.TOWNS[0])
	await choose("refuge_quest")
	assert_eq(screen._visit.place["name"], "The Bread Road")
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
	assert_true(RefugeCampaign.completed(screen.player, 0))
	assert_eq(screen._visit.place["subtitle"], "Victory")
	await choose("refuge_back")
	assert_eq(screen._visit.place["name"], RefugeWorld.TOWNS[0])
	assert_true(Sieges.calm(screen.player))

func test_castle_art_scale_and_count_gate_are_visible() -> void:
	assert_true(RefugeCampaign.travel(screen.player))
	var point: Array = screen.player.world.expansion["castle"]
	screen.player.position = Vector2i(point[0], point[1]) * 32 + Vector2i(16, 16)
	screen.show_player(screen.player)
	var pane := screen.visit(screen.player.tile())
	assert_eq(pane._art.texture, RefugeArt.CASTLE)
	assert_false(pane.place["actions"][0][2])
	var gate := RefugeCampaign.deck_gate(screen.player)
	assert_string_contains(pane.place["lines"][1], "%d of %d nonland cards are from Fallen Empires" % [gate["count"], gate["total"]])
	assert_string_contains(pane.place["lines"][2], "at least %d Fallen Empires nonlands" % maxi(1, ceili(float(gate["total"]) / 2.0)))
	assert_string_contains(pane.place["lines"][2], "All lands are excluded")
	assert_eq(RefugeArt.map_op("castle")[1].size.x, 192.0)
	assert_eq(RefugeArt.map_op("port")[1].size.x, 160.0)

func test_island_dungeon_visit_opens_and_leaves_the_existing_board() -> void:
	assert_true(RefugeCampaign.travel(screen.player))
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
	assert_false(screen.player.refuge["liberated"])
	assert_eq(screen.player.refuge["quests"], [])

func test_added_village_offers_a_local_quest_separate_from_mainland_and_pledges() -> void:
	var mainland_quest := {"type": Quests.LETTER_AMULET, "destination": 8,
		"giver": 16, "color": 1, "data": -1, "deadline": 80}
	screen.player.quest = mainland_quest.duplicate()
	assert_true(RefugeCampaign.travel(screen.player))
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
	assert_true(RefugeCampaign.travel(screen.player))
	assert_eq(screen.player.quest, mainland_quest)
	assert_true(RefugeCampaign.travel(screen.player))
	assert_eq(screen.player.quest, local_quest)
	assert_eq(screen.player.refuge["quests"], [])

func test_draw_loss_and_retry_keep_pledges_and_rewards_honest() -> void:
	assert_true(RefugeCampaign.travel(screen.player))
	var town: Dictionary = screen.player.world.sites[1]
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
		assert_eq(RefugeCampaign.completed(screen.player, 0), result == DuelReport.WIN)
		if result != DuelReport.WIN:
			assert_eq(screen.player.gold, gold)
			assert_eq(screen.player.cards.size(), cards)
		await choose("refuge_back")
	assert_eq(screen.player.gold, gold + 100)
	await choose("refuge_quest")
	assert_false(screen._visit.place["actions"][0][2], "completed pledge cannot be farmed")
	var saved := AdventurePlayer.load_from(screen.player.save_path())
	assert_not_null(saved)
	if saved == null: return
	assert_true(RefugeCampaign.completed(saved, 0))
