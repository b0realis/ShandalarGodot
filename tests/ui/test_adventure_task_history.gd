extends GutTest
## Colored task history and the tester's teleport to the first ticked plugin's harbor.
var screen: WorldScreen
var previous_guides: bool
var previous_quest_pane: bool
const SAVES := "user://task_history_ui_tests"

func before_each() -> void:
	previous_guides = WorldHud.guides_wanted()
	previous_quest_pane = bool(Settings.get_value(WorldHud.QUEST_SETTING, true))
	WorldScreen.debug_campaign = false
	DuelScreen.debug_win = false
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.adventures = ["refuge"]
	setup.packs = ["pack-2"]
	setup.seed_text = "48271"
	screen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.record = setup.resolve({"pack-2": "1"})
	add_child_autofree(screen)
	await get_tree().process_frame

func after_each() -> void:
	Settings.set_value(WorldHud.GUIDES_SETTING, previous_guides)
	Settings.set_value(WorldHud.QUEST_SETTING, previous_quest_pane)
	WorldScreen.debug_campaign = false
	DuelScreen.debug_win = false
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file in dir.get_files(): dir.remove(file)
		DirAccess.remove_absolute(SAVES)

func chord() -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = KEY_2
	key.ctrl_pressed = true
	key.shift_pressed = true
	key.pressed = true
	return key

func test_debug_launcher_teleports_near_enabled_pack_2_without_rewards() -> void:
	var before := screen.player.position
	assert_false(screen._debug_port_pressed(chord()))
	assert_eq(screen.player.position, before)
	MainScreen.read_debug_win(PackedStringArray(["--debug-win"]))
	assert_true(WorldScreen.debug_campaign)
	var gold := screen.player.gold
	var food := screen.player.food
	var days := screen.player.quest_timer
	assert_true(screen._debug_port_pressed(chord()))
	var point: Array = screen.world.expansion["entries"]["refuge"]
	assert_lte(screen.player.tile().distance_to(Vector2i(point[0], point[1])), 1.0)
	assert_true(screen.world.is_land(screen.player.tile().x, screen.player.tile().y))
	assert_eq(screen.player.gold, gold)
	assert_eq(screen.player.food, food)
	assert_eq(screen.player.quest_timer, days)
	assert_false(screen.walk.is_walking())
	assert_true(screen.player.journal.back()["event"] == "debug")

func test_debug_key_refuses_disabled_pack_or_modal_and_accepts_shifted_layout() -> void:
	WorldScreen.debug_campaign = true
	var before := screen.player.position
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	assert_true(screen._debug_port_pressed(chord()))
	assert_eq(screen.player.position, before)
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	screen._duel_held = true
	assert_true(screen._debug_port_pressed(chord()))
	assert_eq(screen.player.position, before)
	screen._duel_held = false
	var key := chord()
	key.keycode = KEY_AT
	key.physical_keycode = KEY_2
	assert_true(WorldScreen._debug_port_key(key))
	key.echo = true
	assert_false(WorldScreen._debug_port_key(key))
	key.echo = false
	key.meta_pressed = true
	assert_false(WorldScreen._debug_port_key(key))

func test_debug_key_can_return_from_island_to_mainland_harbor() -> void:
	_refuge().travel(screen.player)
	screen.show_player(screen.player)
	WorldScreen.debug_campaign = true
	assert_true(screen._debug_port_pressed(chord()))
	assert_true(AdventureRegions.mainland(screen.player))
	assert_eq(screen.world, screen.player.world)
	assert_true(screen.player.regions.has("refuge"))

func test_completed_button_is_green_disabled_and_below_active_timer() -> void:
	_refuge().travel(screen.player)
	screen.show_player(screen.player)
	_refuge().finish_quest(screen.player, 0)
	screen.player.quest = {"type": Quests.LETTER_AMULET, "destination": 22, "giver": 8, "color": 2, "deadline": 10}
	screen.hud._show_hero_tab("Tasks")
	await get_tree().process_frame
	var panel := screen.hud.hero_stats
	var done := panel.find_child("Task_refuge_pledge_0", true, false) as Button
	var fresh := panel.find_child("Task_refuge_errand_8_10", true, false) as Button
	var timer := panel.find_child("Task_refuge_errand_8_10_Timer", true, false) as Label
	assert_not_null(done)
	assert_not_null(fresh)
	assert_not_null(timer)
	if done == null or fresh == null or timer == null: return
	assert_true(done.disabled)
	assert_true(done.text.begins_with("✓"))
	assert_eq(done.get_theme_color("font_disabled_color"), Color("a8d7a0"))
	assert_gt(done.get_index(), fresh.get_index())
	assert_eq(timer.get_theme_color("font_color"), Color("ff9494"))

func test_new_task_returns_scroll_to_top_without_timer_tick_jumps() -> void:
	_refuge().travel(screen.player)
	screen.show_player(screen.player)
	screen.hud._show_hero_tab("Tasks")
	var panel := screen.hud.hero_stats
	for frame in 3: await get_tree().process_frame
	var scroll := panel.find_child("Tasks", true, false) as ScrollContainer
	assert_not_null(scroll)
	if scroll == null: return
	scroll.scroll_vertical = 500
	await get_tree().process_frame
	assert_gt(scroll.scroll_vertical, 0)
	screen.player.quest = {"type": Quests.LETTER_AMULET, "destination": 22, "giver": 8, "color": 2, "deadline": 48}
	panel.refresh()
	for frame in 3: await get_tree().process_frame
	assert_eq(scroll.scroll_vertical, 0, "new objective becomes immediately visible")
	scroll.scroll_vertical = 500
	await get_tree().process_frame
	var position := scroll.scroll_vertical
	screen.player.quest_timer += 1
	panel.refresh()
	for frame in 3: await get_tree().process_frame
	assert_eq(scroll.scroll_vertical, position, "ordinary countdown updates preserve reading position")

func test_target_click_switches_guidance_in_vanilla_with_quest_panel_open() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	var setup := AdventureSetup.new()
	setup.seed_text = "48271"
	var record := setup.resolve({})
	screen.show_player(AdventurePlayer.begin(record, AdventureSetup.make_world(record)))
	assert_true(screen.player.expansions.is_empty())
	assert_true(AdventureTasks.rows(screen.player).all(func(task: Dictionary) -> bool: return task["region"] == "mainland" and not String(task["id"]).contains("voyage:")))
	screen.hud.show_guides(true)
	Sieges.start(screen.player)
	screen.hud.show_quest_pane(true)
	screen.hud._show_hero_tab("Tasks")
	assert_true(screen.hud.quest_pane_shown())
	var panel := screen.hud.hero_stats
	var wizard := panel.find_child("Task_mainland_wizard_0", true, false) as Button
	assert_not_null(wizard)
	if wizard == null: return
	var target := wizard.get_node("GuideMark") as HeroStats.TaskGuideMark
	assert_false(target.tracking)
	assert_eq(target.mouse_filter, Control.MOUSE_FILTER_IGNORE, "target clicks reach the task button")
	wizard.pressed.emit()
	await get_tree().process_frame
	assert_eq(screen.player.tracked_task, "mainland/wizard:0")
	assert_eq(screen.guides.targets[0]["id"], "mainland/wizard:0")
	var marked := panel.find_child("Task_mainland_wizard_0", true, false) as Button
	assert_true((marked.get_node("GuideMark") as HeroStats.TaskGuideMark).tracking)
	assert_eq((marked.get_node("GuideMark") as HeroStats.TaskGuideMark).ink, WorldGuides.GOLD)
	var siege: Dictionary = AdventureTasks.rows(screen.player).filter(func(task: Dictionary) -> bool: return task["kind"] == "siege")[0]
	var node_name := "Task_" + String(siege["id"]).replace("/", "_").replace(":", "_")
	var other := panel.find_child(node_name, true, false) as Button
	other.pressed.emit()
	await get_tree().process_frame
	# Several tasks guide at once (the owner's ruling of 2026-11-03): the
	# siege's arrow joins the wizard's; a second click takes one away.
	var guided := screen.guides.targets.map(func(target: Dictionary) -> String: return target["id"])
	assert_true(guided.has(siege["id"]) and guided.has("mainland/wizard:0"), str(guided))
	marked = panel.find_child(node_name, true, false) as Button
	assert_true((marked.get_node("GuideMark") as HeroStats.TaskGuideMark).tracking)
	assert_eq((marked.get_node("GuideMark") as HeroStats.TaskGuideMark).ink, WorldGuides.SIEGE)
	var status := panel.find_child(node_name + "_Status", true, false) as Label
	assert_true(status.text.begins_with("Tracking task…"))
	assert_eq(status.get_theme_color("font_color"), WorldGuides.SIEGE)
	wizard = panel.find_child("Task_mainland_wizard_0", true, false) as Button
	assert_true((wizard.get_node("GuideMark") as HeroStats.TaskGuideMark).tracking)
	wizard.pressed.emit()
	await get_tree().process_frame
	assert_eq(screen.guides.targets.map(func(target: Dictionary) -> String: return target["id"]), [siege["id"]])
	wizard = panel.find_child("Task_mainland_wizard_0", true, false) as Button
	assert_false((wizard.get_node("GuideMark") as HeroStats.TaskGuideMark).tracking)
	assert_true(screen.hud.quest_pane_shown(), "changing tracked tasks keeps the quest status panel open")

func test_debug_shortcut_respects_cards_only_campaign() -> void:
	WorldScreen.debug_campaign = true
	screen.player.adventures = []
	var before := screen.player.position
	assert_true(screen._debug_port_pressed(chord()))
	assert_eq(screen.player.position, before)
	assert_true(AdventureRegions.mainland(screen.player))


## The Last Refuge's content, the plugin's own [DataRegion] (adventure
## plugins, 2026-11-10: the built-in scripts it replaced are gone).
func _refuge() -> DataRegion:
	return AdventureExpansions.provider("refuge") as DataRegion
