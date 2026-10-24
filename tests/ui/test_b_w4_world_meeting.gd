extends GutTest
## THE CREATURES ON THE WORLD SCREEN (part B, 2026-10-23): a creature that
## reaches the hero is met ([method WorldScreen.meet_creature]) — the walk
## stopped, the game saved with the creature still there (the owner's ruling
## 4), the meeting's pane over the world, which waits under it, and the slot
## spent once the meeting is over, the tick ended then (1997's meeting held
## its tick) and the game saved again; with no pane to hold
## ([WorldEncounters] answering null) the slot is spent at once. A town
## entered pushes the creatures back; the walk's arrival comes before the
## creatures' step; a duel's screen covers the world; quitting mid-meeting
## keeps the save made as it began. The view draws the creatures the hero
## sees among the uprights, the hero in front at one height; a cry sounds
## from where its creature stands on the screen.

const SAVES := "user://adventure_tests_b_w4_meeting"
const CLERIC := 8


## A meeting's pane as the meeting's builder makes it: `finished(result)`.
class FakeMeeting extends Control:
	signal finished(result: int)


## A world screen whose meeting is a pane of the test's own, and whose
## autosaves are counted with what the map held at each.
class Probe extends WorldScreen:
	var pane: Control = null
	var asked := -1
	var saved_monsters: Array = []

	func _open_meeting(slot: int) -> Control:
		asked = slot
		if pane != null:
			add_child(pane)
		return pane

	func _write_autosave() -> String:
		saved_monsters.append(player.monsters.duplicate(true))
		return super()


## A soundscape that keeps the cries asked of it.
class Ears extends WorldSoundscape:
	var heard: Array = []

	func cry(row: int, distance: int, at: Vector2) -> bool:
		heard.append([row, distance, at])
		return true


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
	screen.saved_monsters.clear()


func after_each() -> void:
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


## The hero's land, as one of its colours (1 black … 5 white).
func _hero_color() -> int:
	var mask := ShandalarWorld.magic_mask(screen.world.terrain(screen.player.tile().x, screen.player.tile().y))
	for hue in range(1, 6):
		if mask & (1 << hue) != 0:
			return hue
	return 0


## A creature of the hero's land's colour in slot [param slot], [param
## offset] from the hero, heading [param heading]; every other roaming slot
## held by a lair far off the hero's way (nothing refills, nothing comes).
func _meet_setup(slot: int, offset: Vector2i, heading: int) -> Dictionary:
	var player := screen.player
	var row := CreatureBook.pick(MsvcRandom.new(9), _hero_color(), 4)
	var at := player.position + offset
	var creature := {"slot": slot, "kind": "creature", "creature": row, "x": at.x, "y": at.y,
		"color": _hero_color(), "heading": heading, "frame": 0}
	player.monsters = [creature]
	for other in WorldLairs.SLOTS:
		if other != slot:
			var tile := player.tile() + Vector2i(-4, -3 + other)
			player.monsters.append({"slot": other, "kind": "lair", "x": tile.x * 32 + 16,
				"y": tile.y * 32 + 16, "color": 1})
	for i in player.world.lair_respawn.size():
		player.world.lair_respawn[i] = -1000000
	return creature


## The clock set so slot [param slot] keeps its heading this tick, and the
## hero steps on any land.
func _steady(slot: int) -> void:
	var t := screen.player.monster_timer | 0x40
	while (t + slot) & 3 == 0 or t % 3 != 0:
		t += 1
	screen.player.monster_timer = t


func test_a_creature_that_reaches_the_hero_is_met_and_its_slot_spent() -> void:
	var player := screen.player
	_meet_setup(1, Vector2i(8, 0), 7)
	_steady(1)
	var t := player.monster_timer
	screen.advance(HeroWalk.TICK)
	assert_eq(screen.asked, 1, "the meeting asked for slot 1")
	assert_true(WorldLairs.held_in(player, 1).is_empty(), "no meeting held: the slot spent at once")
	assert_eq(player.world.lair_respawn[1], t, "stamped with the tick that met it")
	assert_eq(player.monster_timer, (t | 0x1F) + 1, "the clock on to the next 32, then the tick's end")
	assert_eq(screen.saved_monsters.size(), 2, "saved before and after")
	var before: Array = screen.saved_monsters[0]
	assert_true(before.any(func(m: Dictionary) -> bool: return int(m["slot"]) == 1),
		"the first save holds the creature (ruling 4)")
	var after: Array = screen.saved_monsters[1]
	assert_false(after.any(func(m: Dictionary) -> bool: return int(m["slot"]) == 1), "the second not")
	assert_false(screen.modal(), "the world goes on")
	# A meeting stops the walk.
	_meet_setup(3, Vector2i(10, 0), 7)
	var town := -1
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == ShandalarWorld.TOWN:
			town = slot
	assert_true(screen.walk.walk_to(Vector2i(int(screen.world.sites[town]["x"]), int(screen.world.sites[town]["y"]))))
	assert_null(screen.meet_creature(3), "no pane: none held")
	assert_false(screen.walk.is_walking(), "the walk stops at a meeting")
	assert_true(WorldLairs.held_in(player, 3).is_empty())
	assert_null(screen.meet_creature(0), "a lair is no creature to meet")


func test_a_meeting_s_pane_holds_the_world_until_it_is_over() -> void:
	var player := screen.player
	_meet_setup(2, Vector2i(0, 8), 1)
	_steady(2)
	screen.pane = FakeMeeting.new()
	var t := player.monster_timer
	screen.advance(HeroWalk.TICK)
	assert_true(screen.meeting(), "the meeting's pane is up")
	assert_true(screen.modal(), "and holds the world")
	assert_eq(player.monster_timer, t, "the tick that met it waits for its end")
	assert_false(WorldLairs.held_in(player, 2).is_empty(), "the creature stays while it lasts")
	screen._process(1.0)
	assert_eq(player.monster_timer, t, "the world waits under it")
	# Quitting now keeps the save made as it began.
	var saves := screen.saved_monsters.size()
	screen._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(screen.saved_monsters.size(), saves, "no save mid-meeting")
	var loaded := AdventurePlayer.load_from(player.save_path())
	assert_false(WorldLairs.held_in(loaded, 2).is_empty(), "loaded, the creature is there to meet again")
	screen.pane.finished.emit(WorldCreatures.WON)
	screen.pane.queue_free()
	await _frames(2)
	assert_false(screen.meeting())
	assert_true(WorldLairs.held_in(player, 2).is_empty(), "over: the slot spent")
	assert_eq(player.world.lair_respawn[2], t)
	assert_eq(player.monster_timer, (t | 0x1F) + 1, "and the tick ended")
	assert_eq(screen.saved_monsters.size(), saves + 1, "saved after")
	assert_false(screen.modal())


func test_a_duel_s_screen_covers_and_holds_the_world() -> void:
	screen.hold_for_duel(true)
	assert_true(screen.modal(), "held")
	assert_false(screen.view.visible, "the world hidden")
	assert_false(screen.hud.visible, "the panel hidden")
	var saves := screen.saved_monsters.size()
	screen._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(screen.saved_monsters.size(), saves, "no save mid-duel")
	screen.hold_for_duel(false)
	assert_false(screen.modal())
	assert_true(screen.view.visible)
	assert_true(screen.hud.visible)


func test_entering_a_town_pushes_the_creatures_back() -> void:
	var player := screen.player
	var town := -1
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == ShandalarWorld.TOWN:
			town = slot
			break
	var tile := Vector2i(int(screen.world.sites[town]["x"]), int(screen.world.sites[town]["y"]))
	player.position = tile * 32 + Vector2i(16, 16)
	var creature := _meet_setup(1, Vector2i(30, 5), 7)
	assert_not_null(screen.visit(tile), "the town's pane")
	assert_eq(Vector2i(int(creature["x"]), int(creature["y"])), player.position + Vector2i(48, 0), "pushed 48 out")


func test_the_walk_s_arrival_comes_before_the_creatures() -> void:
	var player := screen.player
	var town := -1
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == ShandalarWorld.TOWN:
			town = slot
			break
	var tile := Vector2i(int(screen.world.sites[town]["x"]), int(screen.world.sites[town]["y"]))
	# One step short of the town's middle, walking to it.
	player.position = tile * 32 + Vector2i(15, 16)
	screen.walk.walk_to(tile)
	_meet_setup(1, Vector2i(8, 0), 7)
	_steady(1)
	screen.advance(HeroWalk.TICK)
	assert_true(screen.visiting(), "the town entered")
	assert_eq(screen.asked, -1, "no meeting that tick")
	assert_false(WorldLairs.held_in(player, 1).is_empty(), "the creature pushed back, unmet")


func test_the_view_shows_the_creatures_the_hero_sees() -> void:
	var player := screen.player
	_meet_setup(1, Vector2i(40, 0), 7)
	var far := {"slot": 3, "kind": "creature", "creature": CLERIC, "x": player.position.x + 6 * 32,
		"y": player.position.y, "color": 5, "heading": 0, "frame": 0}
	WorldCreatures.empty(player, 3)
	player.monsters.append(far)
	screen._show_hero()
	var slots: Array[int] = []
	for creature in screen.view.creatures:
		slots.append(int(creature["slot"]))
	assert_eq(slots, [1] as Array[int], "within 4 tiles only")
	await _frames(2)
	assert_eq(screen.view.movers().size(), 2, "the hero and the creature drawn")


func test_at_one_height_the_hero_stands_in_front_and_a_lower_slot_before_a_higher() -> void:
	var view := screen.view
	var hero := Vector2(screen.player.position)
	view.hero = hero
	# (+10, +10) projects to the same height as the hero's feet: (40, 0);
	# (+20, 0) higher up: (40, −20).
	var seen: Array[Dictionary] = [
		{"slot": 4, "creature": CLERIC, "x": int(hero.x) + 10, "y": int(hero.y) + 10, "heading": 0, "frame": 0, "color": 5},
		{"slot": 2, "creature": CLERIC, "x": int(hero.x) - 10, "y": int(hero.y) - 10, "heading": 0, "frame": 0, "color": 5},
		{"slot": 5, "creature": CLERIC, "x": int(hero.x) + 20, "y": int(hero.y), "heading": 0, "frame": 0, "color": 5}]
	view.creatures = seen
	view.frame(1.0)
	var order: Array = []
	for mover in view.movers():
		order.append(-1 if mover.is_empty() else int(mover["slot"]))
	assert_eq(order, [5, 4, 2, -1], "behind first: the one further up, then at the hero's height slot 4, 2, the hero")


func test_a_creature_glides_between_ticks_and_leaps_show_at_once() -> void:
	var view := screen.view
	var hero := Vector2(screen.player.position)
	var one := {"slot": 1, "creature": CLERIC, "x": int(hero.x) + 40, "y": int(hero.y), "heading": 7, "frame": 1, "color": 5}
	var first: Array[Dictionary] = [one]
	view.creatures = first
	var moved := one.duplicate()
	moved["x"] = int(hero.x) + 39
	var second: Array[Dictionary] = [moved]
	view.creatures = second
	view.frame(0.5)
	assert_eq(view._shown_creature(moved), hero + Vector2(39.5, 0), "half way between the ticks")
	var leapt := moved.duplicate()
	leapt["x"] = int(hero.x) + 200
	var third: Array[Dictionary] = [leapt]
	view.creatures = third
	view.frame(0.5)
	assert_eq(view._shown_creature(leapt), hero + Vector2(200, 0), "a leap is not slid over")


func test_a_cry_sounds_from_where_its_creature_stands() -> void:
	var ears := Ears.new()
	screen.soundscape.queue_free()
	screen.soundscape = ears
	screen.add_child(ears)
	var at := Vector2i(screen.player.position) + Vector2i(48, 0)
	screen._cry([{"slot": 1, "creature": CLERIC, "distance": 60, "x": at.x, "y": at.y}])
	assert_eq(ears.heard.size(), 1)
	assert_eq(ears.heard[0][2], screen.view.drawn_at(Vector2(at)), "on the screen where it stands [ours]")
	assert_gt((ears.heard[0][2] as Vector2).x, screen.view.feet().x, "east of the hero: to the right")
