extends GutTest
## THE WORLD SCREEN after the review of 2026-11-21: the map's land painted
## once, the place under the pointer described once a tile, a town's pane
## that has given its choice set aside no more, the window closed over a
## duel that is over, and the world's own saves handed to a worker.

const SAVES := "user://adventure_tests_review_adv_ui"


## A meeting's pane with a duel that is over, as [EncounterPane] answers the
## world screen: `finished(result)`, `duel_host`, `close_out`.
class OverMeeting extends Control:
	signal finished(result: int)
	var result := 0
	var closes := true
	var closed := 0

	func duel_host() -> WorldDuels:
		return null

	func close_out() -> bool:
		if not closes:
			return false
		closed += 1
		finished.emit(result)
		queue_free()
		return true


## A world screen whose meeting is the test's own pane, and which counts its
## saves written at once.
class Probe extends WorldScreen:
	var pane: Control = null
	var saves := 0

	func _open_meeting(_slot: int) -> Control:
		if pane != null:
			add_child(pane)
		return pane

	func _write_autosave() -> String:
		saves += 1
		return super()


var viewport: SubViewport
var screen: Probe


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Ilse"
	setup.color = "white"
	setup.difficulty = 1
	setup.walker = "female"
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
	screen.player.monsters = [] as Array
	screen.saves = 0


func after_each() -> void:
	AdventurePlayer.finish_saves()
	AdventurePlayer.later_forced = -1
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


func _site(kind: int) -> Vector2i:
	for site in screen.world.sites:
		if int(site["type"]) == kind:
			return Vector2i(int(site["x"]), int(site["y"]))
	return Vector2i(-1, -1)


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## A creature beside the hero in slot [param slot], the other roaming slots
## held by lairs far off (nothing refills, nothing comes).
func _creature(slot: int) -> void:
	var player := screen.player
	var at := player.position + Vector2i(8, 0)
	player.monsters = [{"slot": slot, "kind": "creature", "creature": CreatureBook.pick(MsvcRandom.new(9), 5, 4),
		"x": at.x, "y": at.y, "color": 5, "heading": 7, "frame": 0}]
	for other in WorldLairs.SLOTS:
		if other != slot:
			var tile := player.tile() + Vector2i(-4, -3 + other)
			player.monsters.append({"slot": other, "kind": "lair", "x": tile.x * 32 + 16, "y": tile.y * 32 + 16, "color": 1})
	for i in player.world.lair_respawn.size():
		player.world.lair_respawn[i] = -1000000


# ------------------------------------------------------------------ the map --

func test_the_map_s_land_is_painted_once_not_at_every_look() -> void:
	screen.toggle_map()
	await _frames(3)
	var map: WorldMap = screen._map
	assert_true(map.visible)
	var painted := map.land_paints
	assert_gt(painted, 0, "the land is on its own layer, painted")
	for mode in [WorldMap.Mode.PLAIN, WorldMap.Mode.INFO, WorldMap.Mode.MAIN]:
		map.show_mode(mode)
		await _frames(2)
	map.walk_journal()
	await _frames(2)
	map.step_journal(-1)
	await _frames(2)
	assert_eq(map.land_paints, painted, "another mode, the journal walked: the land stays as painted")
	# New land seen is what the land shows: painted again.
	var far := _site(ShandalarWorld.CASTLE)
	screen.world.explore_around(far)
	map.queue_redraw()
	await _frames(2)
	assert_eq(map.land_paints, painted + 1, "new land seen: painted again, once")
	map.explored_only = false
	map.queue_redraw()
	await _frames(2)
	assert_eq(map.land_paints, painted + 2, "the unexplored land shown: again")
	assert_eq(map._land_shown, map._land_key(), "what is painted is what the map now shows")


# ---------------------------------------------------- the place under the pointer --

func test_the_place_under_the_pointer_is_described_once_a_tile() -> void:
	var village := _site(ShandalarWorld.VILLAGE)
	screen.world.explore_around(village)
	var before := screen.hover_reads
	var place := screen._place_hovered(village)
	for i in 20:
		screen._place_hovered(village)
	assert_eq(screen.hover_reads - before, 1, "the pointer moving over one tile: one description")
	assert_eq(place, screen.place_at(village), "and it is the place's own")
	assert_eq(String(place["kind"]), "village")
	screen._place_hovered(village + Vector2i(1, 0))
	assert_eq(screen.hover_reads - before, 2, "another tile: asked anew")
	screen._show_hero()
	screen._place_hovered(village)
	before = screen.hover_reads
	# The clock's ticks keep it a while; anything else shown asks anew.
	for i in WorldScreen.HOVER_TICKS - 1:
		screen._show_hero(true)
		screen._place_hovered(village)
	assert_eq(screen.hover_reads - before, 0, "a few ticks under a resting pointer: kept")
	screen._show_hero(true)
	screen._place_hovered(village)
	assert_eq(screen.hover_reads - before, 1, "every %d ticks all the same" % WorldScreen.HOVER_TICKS)
	screen.world.sites[VisitPane.site_slot(screen.world, village)]["type"] = ShandalarWorld.TOWN
	screen._show_hero()
	assert_eq(String(screen._place_hovered(village)["kind"]), screen.place_at(village)["kind"],
		"the hero shown anew (a pane closed, a load): what changed is named at once")
	assert_eq(screen.hover_reads - before, 2)


# ----------------------------------------------------------- inside a town --

func test_a_town_that_has_given_its_choice_is_not_set_aside() -> void:
	var village := _site(ShandalarWorld.VILLAGE)
	screen.player.position = village * 32 + Vector2i(16, 16)
	var pane := screen.visit(village)
	assert_not_null(pane)
	await _frames(2)
	assert_true(screen.town_on_top(), "the town's pane on top: M, F2 and F5 open over it")
	pane.choose("leave")
	assert_true(pane.leaving, "its choice given: freed after the frame")
	assert_false(screen.town_on_top(), "nothing opens over a pane about to go")
	var key := InputEventKey.new()
	key.keycode = KEY_M
	key.pressed = true
	assert_false(screen._town_key(key), "M in the frame of the choice is not the town's")
	assert_eq(screen._town_aside, "")
	await _frames(3)
	assert_false(screen.visiting(), "the place is left")
	assert_eq(screen._town_aside, "", "and nothing stands aside for it")
	assert_false(screen._map.visible)


# ------------------------------------------------ the window closed, a duel over --

func test_the_window_closed_over_a_lost_duel_saves_the_loss() -> void:
	_creature(1)
	var pane := OverMeeting.new()
	pane.result = WorldCreatures.LOST
	screen.pane = pane
	assert_not_null(screen.meet_creature(1))
	assert_true(screen.meeting())
	var saved := screen.saves
	screen.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(pane.closed, 1, "the meeting closed out")
	assert_false(screen.meeting(), "over before the process ends, not after the frame")
	assert_true(WorldLairs.held_in(screen.player, 1).is_empty(), "the creature's slot spent: the duel cannot be met again")
	assert_gt(screen.saves - saved, 0, "and the world saved with the meeting's end")
	var written := screen.saves
	assert_false(AdventurePlayer.saves_pending())
	var monsters: Array = _json(screen.player.save_path(AdventurePlayer.AUTOSAVE)).get("monsters", [])
	var held := monsters.filter(func(creature: Variant) -> bool: return creature is Dictionary and int(creature.get("slot", -1)) == 1)
	assert_eq(held.size(), 0, "the save holds the meeting's end")
	await _frames(2)
	assert_eq(screen.saves, written, "the meeting's end is not heard a second time after the frame")


func test_the_window_closed_mid_meeting_saves_nothing_as_before() -> void:
	_creature(1)
	var pane := OverMeeting.new()
	pane.closes = false
	screen.pane = pane
	assert_not_null(screen.meet_creature(1))
	var saved := screen.saves
	screen.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_true(screen.meeting(), "a duel still played, or a win whose choice waits: the meeting stands")
	assert_eq(screen.saves, saved, "nothing saved: the save made as the meeting began stands")
	assert_false(WorldLairs.held_in(screen.player, 1).is_empty())
	pane.finished.emit(WorldCreatures.NO_DUEL)
	await _frames(2)


# ------------------------------------------------------ saves off the frame --

func test_the_world_s_own_saves_go_to_a_worker_and_are_written_before_any_reading() -> void:
	AdventurePlayer.later_forced = 1
	var before := AdventurePlayer.saves_later
	var path := screen.player.save_path(AdventurePlayer.AUTOSAVE)
	screen.player.gold = 4321
	screen._after_leaving()
	assert_eq(AdventurePlayer.saves_later - before, 1, "a place left: its save handed over")
	assert_eq(screen.saves, 0, "not written on the frame")
	screen.player.gold = 1
	# Quicksave is written at once — after the one handed over.
	assert_ne(screen.quick_save(), "")
	assert_false(AdventurePlayer.saves_pending(), "nothing is left to the worker under a save at once")
	assert_eq(int(_json(path)["carried"]["gold"]), 4321, "the adventure as it stood when the place was left")
	screen.player.gold = 99
	screen._after_leaving()
	assert_true(AdventurePlayer.saves_pending())
	screen.autosave()
	assert_false(AdventurePlayer.saves_pending(), "leaving, quitting: the world's own save at once waits for them")
	screen._after_leaving()
	screen._open_slots()
	assert_false(AdventurePlayer.saves_pending(), "the slots are read with every save written")
	await _frames(2)
	AdventurePlayer.later_forced = 0
	var written := screen.saves
	screen._after_leaving()
	assert_eq(screen.saves - written, 1, "where no worker writes, the save is written at once, as before")
