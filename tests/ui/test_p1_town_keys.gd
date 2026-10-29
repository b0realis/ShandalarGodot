extends GutTest
## INSIDE A TOWN, AS 1997 (the polish pass, 2026-10-28; ledger
## adventure-032; the owner's ruling of 2026-10-28: *"Inside a town: as
## 1997 — the map (M/F2), the hero (F5) and Save (Ctrl+S) open over the
## town's pane and come back to it"*). 1997's town let its right-click menu
## open the map, the stats and the save list and came back to the town
## after each (visitLocation.c 2041–2108); ours held every key at the
## town's pane (the lead's ruling A of 2026-10-23). Now M or F2, F5 and
## Ctrl+S open their screens over the town and the town comes back as it
## was — the same pane, its words and its note; every other key of the
## world stays held there.
##
## Every key here is a real one, pushed through the viewport.

class Probe extends WorldScreen:
	var walked: Array[Vector2i] = []

	func walk_to_tile(tile: Vector2i) -> bool:
		walked.append(tile)
		return super(tile)


const SAVES := "user://adventure_tests_p1_town"
const WORLD_SETTINGS: Array[String] = [WorldHud.BAR_SETTING, WorldHud.MINIMAP_SETTING,
	WorldHud.QUEST_SETTING, WorldHud.GUIDES_SETTING, WorldHud.PACE_SETTING, WorldHud.BIG_SETTING,
	WorldHud.PLACES_SETTING, WorldHud.READER_SETTING, WorldHud.NAMES_SETTING,
	"world_pane_HeroPanel", "world_pane_HelpPanel", "world_pane_QuestPane", "world_pane_Minimap"]

var viewport: SubViewport
var screen: Probe


func before_each() -> void:
	for key in WORLD_SETTINGS:
		Settings.clear_value(key)
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	viewport.notification(Viewport.NOTIFICATION_VP_MOUSE_ENTER)
	screen = Probe.new()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.player.monsters = [] as Array


func after_each() -> void:
	for key in WORLD_SETTINGS:
		Settings.clear_value(key)
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


## A real key, pressed and let go, through the viewport.
func _key(code: Key, ctrl := false) -> void:
	var press := InputEventKey.new()
	press.keycode = code
	press.physical_keycode = code
	press.ctrl_pressed = ctrl
	press.pressed = true
	viewport.push_input(press, true)
	var up := press.duplicate() as InputEventKey
	up.pressed = false
	viewport.push_input(up, true)
	await _frames(2)


func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.position = at
		click.global_position = at
		viewport.push_input(click, true)
	await _frames(2)


func _first(kind: int) -> int:
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == kind:
			return slot
	return -1


func _tile(slot: int) -> Vector2i:
	return Vector2i(int(screen.world.sites[slot]["x"]), int(screen.world.sites[slot]["y"]))


func _map() -> WorldMap:
	return screen.find_child("Map", true, false) as WorldMap


## A town's pane up, its note set by buying food: what "as it was" checks.
func _in_town() -> VisitPane:
	screen.player.gold = 500
	var pane := screen.visit(_tile(_first(ShandalarWorld.TOWN)))
	await _frames()
	pane.choose("food")
	return pane


## The town's pane is back on top, as it was.
func _town_back(pane: VisitPane, note: String, why: String) -> void:
	assert_true(is_instance_valid(pane) and not pane.is_queued_for_deletion(), why + ": the same pane")
	assert_true(pane.visible, why + ": shown")
	assert_eq(pane.process_mode, Node.PROCESS_MODE_INHERIT, why + ": awake")
	assert_true(VisitPane.on_top(pane), why + ": on top")
	assert_eq(pane.note(), note, why + ": as it was")
	assert_true(screen.town_on_top(), why + ": the town again")
	assert_true(screen.modal(), why + ": holding the world")
	assert_true(screen._shield.visible, why + ": the shield up under it")


func test_m_and_f2_open_the_map_over_the_town_and_come_back() -> void:
	var pane := await _in_town()
	var note := pane.note()
	assert_ne(note, "")
	assert_true(screen.town_on_top())
	for open_key in [KEY_M, KEY_F2]:
		await _key(open_key)
		assert_true(_map().visible, "%s: the map" % OS.get_keycode_string(open_key))
		assert_false(pane.visible, "the town steps aside under the map")
		assert_true(is_instance_valid(pane), "not left")
		assert_false(screen._shield.visible, "the map's buttons take their clicks")
		var timer := screen.player.monster_timer
		screen._process(1.0)
		assert_eq(screen.player.monster_timer, timer, "the world waits")
		await _key(KEY_ESCAPE)
		assert_false(_map().visible, "Escape closes the map")
		_town_back(pane, note, "after the map")
	# The map's own M closes it too, and its Done.
	await _key(KEY_M)
	await _key(KEY_M)
	assert_false(_map().visible)
	_town_back(pane, note, "M again")
	await _key(KEY_M)
	_map().closed.emit()
	await _frames()
	_town_back(pane, note, "the map's Done")


func test_the_map_over_the_town_keeps_its_own_keys() -> void:
	var pane := await _in_town()
	for slot in screen.world.sites.size():
		if TownStatus.is_town(screen.world, slot):
			TownStatus.put(screen.world, slot, TownStatus.VISITED)
	await _key(KEY_M)
	await _key(KEY_C)
	assert_true(screen.city_list_shown(), "C: the map's City Info, as on the world")
	await _key(KEY_ESCAPE)
	assert_false(screen.city_list_shown())
	assert_true(_map().visible, "the map still up")
	await _key(KEY_S, true)
	var slots := screen.find_child("SaveSlots", true, false) as SaveSlotsPane
	assert_not_null(slots, "Ctrl+S on the map: the slots")
	if slots != null:
		slots.done.emit()
		await _frames()
	await _key(KEY_ESCAPE)
	assert_false(_map().visible)
	assert_true(pane.visible and screen.town_on_top(), "and the town again")
	assert_eq(screen.walked, [] as Array[Vector2i], "no walk on the way")


func test_f5_opens_the_hero_over_the_town_and_comes_back() -> void:
	var pane := await _in_town()
	var note := pane.note()
	var hud := screen.hud
	await _key(KEY_F5)
	assert_true(hud.hero_shown(), "F5: the hero's pane")
	assert_true(pane.visible, "the town stays in view under it")
	assert_lt(pane.get_index(), hud.get_index(), "under the panel, so the hero's pane floats over it")
	assert_eq(pane.process_mode, Node.PROCESS_MODE_DISABLED, "the town still and deaf under it")
	assert_false(screen._shield.visible, "the hero's pane takes its clicks")
	assert_true(screen.modal(), "the world still held")
	var timer := screen.player.monster_timer
	screen._process(1.0)
	assert_eq(screen.player.monster_timer, timer, "the world waits")
	# Its tabs answer the mouse and its own letters.
	await _key(KEY_J)
	assert_eq(hud.hero_stats.tab, "Journal", "J: the journal")
	# Every other key of the world stays held.
	var at := screen.player.position
	screen.player.world_magics.append("Leap of Fate")
	screen.player.amulets["blue"] = 3
	for code in [KEY_F1, KEY_F3, KEY_F4, KEY_H, KEY_L, KEY_2, KEY_N, KEY_M]:
		await _key(code)
	assert_false(screen.building() or screen.city_list_shown() or screen.clues_shown() or screen.loading(),
		"F1, F3, F4, L: nothing")
	assert_false(hud.help_shown(), "H: nothing")
	assert_false(_map().visible, "M: nothing over the hero's pane")
	assert_eq(screen.player.position, at, "2: no cast")
	assert_true(hud.minimap_shown(), "N: the small map untouched")
	assert_true(hud.hero_shown(), "the hero's pane still up")
	# A click on the town's own Leave does nothing while the pane is over it.
	var leave := pane.find_child("Choice_leave", true, false) as Control
	await _click(leave.get_global_rect().get_center())
	assert_true(is_instance_valid(pane) and not pane.is_queued_for_deletion(), "the town is not left under it")
	await _key(KEY_F5)
	assert_false(hud.hero_shown(), "F5 again: closed")
	_town_back(pane, note, "after the hero")
	assert_gt(pane.get_index(), hud.get_index(), "over the panel again")
	# Escape closes it too, and the pane's own D.
	await _key(KEY_F5)
	await _key(KEY_ESCAPE)
	assert_false(hud.hero_shown(), "Escape: closed")
	_town_back(pane, note, "Escape")
	await _key(KEY_F5)
	await _key(KEY_D)
	assert_false(hud.hero_shown(), "D: closed")
	await _frames()
	_town_back(pane, note, "D")


func test_the_hero_s_journal_on_the_map_from_inside_a_town() -> void:
	var pane := await _in_town()
	var note := pane.note()
	await _key(KEY_F5)
	screen.walk_journal()
	await _frames()
	assert_false(screen.hud.hero_shown(), "the hero's pane gives way")
	assert_true(_map().visible, "the map, over the town")
	assert_eq(_map().mode, WorldMap.Mode.JOURNAL, "on the journal")
	assert_false(pane.visible)
	await _key(KEY_ESCAPE)
	assert_false(_map().visible, "Escape closes the map")
	_town_back(pane, note, "after the journal")


func test_ctrl_s_saves_over_the_town_and_comes_back() -> void:
	var pane := await _in_town()
	var note := pane.note()
	await _key(KEY_S, true)
	var slots := screen.find_child("SaveSlots", true, false) as SaveSlotsPane
	assert_not_null(slots, "Ctrl+S: the ten slots over the town")
	assert_true(pane.visible, "the town in view under them")
	assert_eq(pane.process_mode, Node.PROCESS_MODE_DISABLED, "still and deaf under them")
	assert_gt(slots.get_index(), pane.get_index(), "over it")
	var path := slots.save_into(1, "In town")
	assert_true(FileAccess.file_exists(path), "saved inside the town")
	await _key(KEY_ESCAPE)
	assert_false(is_instance_valid(slots) and not slots.is_queued_for_deletion(), "Escape closes the slots")
	_town_back(pane, note, "after the save")
	await _key(KEY_S, true)
	slots = screen.find_child("SaveSlots", true, false) as SaveSlotsPane
	(slots.find_child("SaveDone", true, false) as BaseButton).pressed.emit()
	await _frames()
	_town_back(pane, note, "Done")


func test_every_other_key_stays_held_in_the_town() -> void:
	var pane := await _in_town()
	var hud := screen.hud
	var at := screen.player.position
	screen.player.world_magics.append("Leap of Fate")
	screen.player.amulets["blue"] = 3
	for code in [KEY_F1, KEY_F3, KEY_F4, KEY_F6, KEY_H, KEY_N, KEY_2, KEY_SPACE, KEY_HOME]:
		await _key(code)
	assert_false(screen.building() or screen.city_list_shown() or screen.clues_shown(), "F1, F3, F4: nothing")
	assert_false(hud.hero_shown() or hud.help_shown(), "F6, H: nothing")
	assert_true(hud.minimap_shown(), "N: nothing")
	assert_eq(screen.player.position, at, "2: no cast")
	assert_true(pane.visible and screen.town_on_top(), "the town as it was")
	# The panel's own buttons stay at rest: only the keys open over the town.
	assert_true(hud.resting)
	screen.toggle_map()
	screen.toggle_hero()
	assert_null(screen.save_now(), "the panel's Save stays held")
	assert_false(_map().visible or hud.hero_shown())


func test_not_over_the_town_s_shop() -> void:
	var pane := await _in_town()
	pane.choose("buy")
	await _frames()
	assert_true(screen.shopping(), "the shop over the world")
	assert_false(screen.town_on_top())
	await _key(KEY_M)
	await _key(KEY_F5)
	assert_false(_map().visible or screen.hud.hero_shown(), "the shop's keys stay the shop's")


func test_a_castle_s_pane_is_no_town() -> void:
	var castle := screen.visit(_tile(_first(ShandalarWorld.CASTLE)))
	await _frames()
	assert_not_null(castle)
	assert_false(screen.town_on_top())
	await _key(KEY_M)
	await _key(KEY_F5)
	await _key(KEY_S, true)
	assert_false(_map().visible or screen.hud.hero_shown(), "a castle's pane holds its keys")
	assert_null(screen.find_child("SaveSlots", true, false), "no save from a castle's door")


func test_help_says_the_town_s_keys() -> void:
	var keys := "\n".join(screen.hud.key_lines())
	assert_string_contains(keys, "In a town: M or F2, F5, Ctrl+S open over the town; close them to come back")
