extends GutTest
## THE WORLD SCREEN AFTER THE PLAYTEST OF PART B (campaign c5, fixer A):
##  - H2-1 / P1-1: a key pressed just after a pane closed went to the world
##    — Escape saved and left for the title, a digit cast a World Magic; the
##    mouse had the after-pane shield ([constant WorldScreen.AFTER_PANE_MS]),
##    the keys none. The shield holds the keys too.
##  - H2-2: a ruled town's duel kept the town's tune playing under the duel's
##    music and the win or lose music [ours: 1997 slip].
##  - H2-4: the window closed while a news flash held the tick saved half a
##    tick; the save before the news stands.
##  - H2-5 / P2-3: the end screen's "Return to the title" button closed it
##    before its moment.
##  - P4-5: the panel's numbers lagged while a meeting was up.

const SAVES := "user://adventure_tests_c5_a_world"


## A meeting's pane as the meeting's builder makes it: `finished(result)`.
class FakeMeeting extends Control:
	signal finished(result: int)


## A world screen whose meetings and ruled towns are the test's own panes,
## and which counts its saves and its leaving.
class Probe extends WorldScreen:
	var pane: Control = null
	var asked := -1
	var saves := 0
	var titles := 0

	func _open_meeting(slot: int) -> Control:
		asked = slot
		if pane != null:
			add_child(pane)
		return pane

	func _open_ruled_pane(slot: int) -> Control:
		asked = slot
		if pane != null:
			add_child(pane)
		return pane

	func _write_autosave() -> String:
		saves += 1
		return super()

	func _go_to_title() -> void:
		titles += 1
		_leaving = true


var viewport: SubViewport
var screen: Probe


func before_each() -> void:
	RuledTowns.forget()
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Inniscor"
	setup.color = "green"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	screen = Probe.new()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	# The clock runs only when the test says.
	screen.set_process(false)
	screen.player.food = 50
	_lone_tile()
	_quiet_slots()
	screen.saves = 0


func after_each() -> void:
	RuledTowns.forget()
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


## The shield's moment after a pane closes, waited out.
func _after_pane() -> void:
	await get_tree().create_timer(WorldScreen.AFTER_PANE_MS / 1000.0 + 0.1).timeout
	await _frames(2)


## The hero set on the middle of a land tile with land all round it and no
## site within two tiles, the world explored there.
func _lone_tile() -> void:
	var world := screen.world
	for y in range(8, 56):
		for x in range(8, 56):
			if not _open_land(Vector2i(x, y)):
				continue
			screen.player.position = Vector2i(x * 32 + 16, y * 32 + 16)
			screen.show_player(screen.player)
			return
	fail_test("no lone tile in the world")


func _open_land(tile: Vector2i) -> bool:
	var world := screen.world
	for dy in range(-1, 2):
		for dx in range(-1, 3):
			if not world.is_land(tile.x + dx, tile.y + dy):
				return false
	for site in world.sites:
		if absi(int(site["x"]) - tile.x) <= 2 and absi(int(site["y"]) - tile.y) <= 2:
			return false
	return true


## Every roaming slot held by a lair off the hero's way (nothing refills,
## nothing comes); no besieger.
func _quiet_slots() -> void:
	var player := screen.player
	player.monsters = [] as Array
	for slot in WorldLairs.SLOTS:
		var tile := player.tile() + Vector2i(-4, -3 + slot)
		player.monsters.append({"slot": slot, "kind": "lair", "x": tile.x * 32 + 16, "y": tile.y * 32 + 16,
			"color": 1})
	for i in player.world.lair_respawn.size():
		player.world.lair_respawn[i] = -1000000
	player.siege_active = false


## A town of the world, by its slot.
func _a_town() -> int:
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == ShandalarWorld.TOWN:
			return slot
	return -1


func _site_tile(slot: int) -> Vector2i:
	var site: Dictionary = screen.world.sites[slot]
	return Vector2i(int(site["x"]), int(site["y"]))


func _press(node: Control) -> void:
	var at := node.get_global_rect().get_center()
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.position = at
		click.global_position = at
		viewport.push_input(click, true)


func _key(code: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = code
	press.physical_keycode = code
	press.pressed = true
	viewport.push_input(press, true)
	var up := press.duplicate() as InputEventKey
	up.pressed = false
	viewport.push_input(up, true)
	await _frames()


func _escape() -> void:
	await _key(KEY_ESCAPE)


func _number(strip: String) -> String:
	var row := screen.hud.find_child("Strip_" + strip, true, false)
	assert_not_null(row, "the panel's %s" % strip)
	var shown := row.find_child("Number", true, false) as Label if row != null else null
	return shown.text if shown != null else ""


# ------------------------------------------ the keys after a pane (H2-1) --

func test_a_key_just_after_a_pane_closed_is_not_the_world_s() -> void:
	var player := screen.player
	player.world_magics.append("Leap of Fate")
	player.amulets["blue"] = 3
	var at := player.position
	assert_not_null(screen.show_city_list(), "a pane over the world")
	await _escape()
	assert_false(screen.city_list_shown(), "its own Escape closed it")
	await _key(KEY_2)
	assert_eq(player.position, at, "2 a moment after: no Leap of Fate")
	assert_eq(int(player.amulets["blue"]), 3, "nothing risked")
	await _escape()
	assert_eq(screen.titles, 0, "a second Escape a moment after: still in the world")
	assert_false(screen._leaving)
	await _after_pane()
	await _escape()
	assert_eq(screen.titles, 1, "the moment over, Escape leaves as before")


func test_the_map_still_hears_its_keys_after_a_pane_over_it() -> void:
	# Ruling B: under the map only its keys act, and none of them leaves the
	# world — the map's Escape closes the map, at once as before.
	screen.toggle_map()
	assert_true(screen._map.visible)
	await _key(KEY_C)
	assert_true(screen.city_list_shown(), "C: the map's City Info")
	await _escape()
	assert_false(screen.city_list_shown())
	assert_true(screen._map.visible, "the map stays up")
	await _escape()
	assert_false(screen._map.visible, "Escape: the map closed")
	assert_eq(screen.titles, 0)


# ------------------------------------------ the ruled town's tune (H2-2) --

func test_a_ruled_town_s_duel_rests_the_town_s_tune() -> void:
	var town := _a_town()
	TownStatus.take(screen.world, town, 4)
	var tile := _site_tile(town)
	screen.player.position = tile * 32 + Vector2i(16, 16)
	screen.show_player(screen.player)
	screen.soundscape.hear_places()
	var visit := screen.visit(tile)
	await _frames()
	assert_eq(screen.soundscape.site, town, "the town's tune at the town")
	assert_gt(screen.soundscape.level, 0)
	var pane := FakeMeeting.new()
	screen.pane = pane
	visit.choose("duel")
	await _frames()
	assert_eq(screen.asked, town, "the town's duel")
	assert_true(screen.meeting())
	assert_eq(screen.soundscape.level, 0, "[ours: 1997 slip] its tune rests under the duel")
	assert_eq(screen.soundscape.site, -1)
	pane.finished.emit(RuledTowns.LOST)
	await _frames()
	assert_false(screen.meeting())
	assert_eq(screen.soundscape.site, town, "and is heard again as the town's pane is done")
	assert_gt(screen.soundscape.level, 0)


# ----------------------------------------- the window under a news (H2-4) --

func test_closing_the_window_under_a_news_flash_saves_nothing() -> void:
	var player := screen.player
	player.siege_timer = 63
	player.monster_timer = 96 * 10
	assert_true(screen.walk.walk_to(player.tile() + Vector2i(2, 0)))
	screen.advance(HeroWalk.TICK)
	await _frames()
	var news := screen.find_child("NewsFlashPane", false, false) as NewsFlashPane
	assert_not_null(news, "the news holds the tick")
	assert_true(screen.news_shown())
	screen._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(screen.saves, 0, "the save before the news stands: its dice bring the news again")
	var button := news.find_child("Choice_continue", true, false) as Button
	_press(button)
	await _frames(3)
	assert_false(screen.news_shown(), "read")
	screen._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(screen.saves, 1, "read, the window's close saves as before")


# ----------------------------------------- the end screen's button (H2-5) --

func test_the_end_screen_s_button_waits_its_moment_too() -> void:
	var end := screen.show_end(["Your Righteous Quest has Failed"])
	await _frames(3)
	var button := end.find_child("ReturnToTitle", true, false) as Button
	assert_not_null(button)
	assert_false(end.ready_to_close())
	_press(button)
	await _frames(3)
	assert_eq(screen.titles, 0, "a click on the button at once: the end stays")
	assert_true(screen.ended())
	await get_tree().create_timer(AdventureEndScreen.GUARD_MS / 1000.0 + 0.05).timeout
	_press(button)
	await _frames(3)
	assert_eq(screen.titles, 1, "after its moment: the title")
	assert_eq(screen.saves, 0, "without a save")


# ------------------------------------------ the panel in a meeting (P4-5) --

func test_the_panel_follows_what_a_meeting_pays() -> void:
	var player := screen.player
	for i in player.monsters.size():
		if int(player.monsters[i]["slot"]) == 1:
			player.monsters[i] = {"slot": 1, "kind": "creature", "creature": 1,
				"x": player.position.x + 4, "y": player.position.y, "color": 1, "heading": 0, "frame": 0}
	var pane := FakeMeeting.new()
	screen.pane = pane
	assert_eq(screen.meet_creature(1), pane, "met")
	assert_true(screen.meeting())
	screen._process(0.016)
	assert_eq(_number("food"), str(player.food))
	# A tribute paid: "You take 40 food.", gold given.
	player.food += 40
	player.gold += 25
	screen._process(0.016)
	assert_eq(_number("food"), str(player.food), "the food taken, on the panel at once")
	assert_eq(_number("gold"), str(player.gold), "the gold, too")
	pane.finished.emit(WorldCreatures.NO_DUEL)
	await _frames(3)
	assert_false(screen.meeting())
