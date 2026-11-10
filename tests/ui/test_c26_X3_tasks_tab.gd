extends GutTest
## THE TASKS TAB CHOOSES THE ARROWS (the owner's ruling of 2026-11-03;
## 0.60.13 bug campaign, c26, fixer X3): a click on a task adds its arrow, a
## second takes it away, Automatic guidance clears the choice, and the
## portal's own arrow has its switch here. And the Hero page names no region
## in an ordinary campaign ("Region only with an island").

const SAVES := "user://adventure_tests_c26_x3_tasks"

var screen: WorldScreen
var _guides_before: bool
var _portal_before: bool


func before_each() -> void:
	_guides_before = WorldHud.guides_wanted()
	_portal_before = WorldGuides.portal_wanted()
	Settings.set_value(WorldHud.GUIDES_SETTING, true)
	WorldGuides.want_portal(true)
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.seed_text = "48271"
	setup.player_name = "Wayfarer"
	screen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.record = setup.resolve({})
	add_child_autofree(screen)
	await _frames(3)


func after_each() -> void:
	Settings.set_value(WorldHud.GUIDES_SETTING, _guides_before)
	WorldGuides.want_portal(_portal_before)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file in dir.get_files(): dir.remove(file)
		DirAccess.remove_absolute(SAVES)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _button(name: String) -> Button:
	return screen.hud.hero_stats.find_child(name, true, false) as Button


func _press(name: String) -> void:
	var button := _button(name)
	assert_not_null(button, name)
	if button != null: button.pressed.emit()
	await _frames(2)


func _guided() -> Array:
	return screen.guides.targets.map(func(target: Dictionary) -> String: return target.get("id", target.get("name", "")))


func test_clicks_add_and_take_away_arrows_and_automatic_clears_them() -> void:
	Sieges.start(screen.player)
	screen._show_hero()
	screen.hud._show_hero_tab("Tasks")
	await _frames(2)
	assert_eq(screen.guides.targets.size(), 1, "Automatic guidance: one arrow")
	assert_eq(screen.guides.targets[0]["kind"], "siege")
	assert_true(_button("TaskAutomatic").text.ends_with("✓"))
	await _press("Task_mainland_wizard_0")
	await _press("Task_mainland_wizard_2")
	var both := _guided()
	both.sort()
	assert_eq(both, ["mainland/wizard:0", "mainland/wizard:2"], "an arrow for each chosen task, none automatic")
	assert_false(_button("TaskAutomatic").text.ends_with("✓"))
	for id in ["0", "2"]:
		assert_true((_button("Task_mainland_wizard_" + id).get_node("GuideMark") as HeroStats.TaskGuideMark).tracking, "wizard " + id)
		var status := screen.hud.hero_stats.find_child("Task_mainland_wizard_%s_Status" % id, true, false) as Label
		assert_true(status.text.begins_with("Tracking task…"))
	await _press("Task_mainland_wizard_0")
	assert_eq(_guided(), ["mainland/wizard:2"], "a second click takes its arrow away")
	assert_false((_button("Task_mainland_wizard_0").get_node("GuideMark") as HeroStats.TaskGuideMark).tracking)
	await _press("TaskAutomatic")
	assert_eq(screen.guides.targets.size(), 1)
	assert_eq(screen.guides.targets[0]["kind"], "siege", "Automatic guidance again")
	assert_true(_button("TaskAutomatic").text.ends_with("✓"))


func test_the_portal_arrow_switch() -> void:
	var player := screen.player
	player.portal = {"x": 31, "y": 31, "state": FinalBattle.PORTAL_OPEN}
	Sieges.start(player)
	screen._show_hero()
	screen.hud._show_hero_tab("Tasks")
	await _frames(2)
	var kinds := screen.guides.drawn().map(func(target: Dictionary) -> String: return target["kind"])
	assert_eq(kinds, ["siege", "portal"], "the portal's own arrow over the automatic one")
	var switch := _button("TaskPortalArrow")
	assert_not_null(switch)
	if switch == null: return
	assert_eq(switch.text, "Portal arrow ✓")
	assert_eq((switch.get_node("GuideMark") as HeroStats.TaskGuideMark).ink, WorldGuides.PORTAL)
	await _press("TaskPortalArrow")
	assert_false(WorldGuides.portal_wanted())
	assert_eq(_button("TaskPortalArrow").text, "Portal arrow")
	kinds = screen.guides.drawn().map(func(target: Dictionary) -> String: return target["kind"])
	assert_eq(kinds, ["siege"], "switched off")
	await _press("Task_mainland_finale")
	kinds = screen.guides.drawn().map(func(target: Dictionary) -> String: return target["kind"])
	assert_eq(kinds, ["portal"], "the portal task chosen: its arrow shows with the switch off")
	await _press("TaskPortalArrow")
	assert_true(WorldGuides.portal_wanted())


func test_the_hero_page_names_no_region_in_an_ordinary_campaign() -> void:
	screen.hud.toggle_hero()
	var stats := screen.hud.hero_stats
	stats.show_tab("Hero")
	await _frames(3)
	var road := stats.find_child("Number_road", true, false) as Label
	assert_not_null(road)
	if road == null: return
	assert_string_contains(road.text, "World seed 48271")
	assert_false(road.text.contains("Shandalar"), road.text)


func _headings(text: String) -> int:
	return screen.hud.hero_stats.find_children("*", "Label", true, false).filter(func(label: Label) -> bool: return label.text == text).size()


func test_the_known_clues_heading_only_with_a_clue() -> void:
	screen.player.known_clues.clear()
	screen.hud._show_hero_tab("Tasks")
	await _frames(2)
	assert_eq(_headings("Known clues"), 0, "no clue known: no heading")
	screen.player.log_clue("The World Magic Fruit of Sustenance may be found in Kraag Temple.")
	screen.hud.hero_stats.refresh()
	await _frames(2)
	assert_eq(_headings("Known clues"), 1)
