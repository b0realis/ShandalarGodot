extends GutTest
## THE OPTIONAL LAND ON THE WORLD SCREEN (the 0.60.13 bug campaign, X1).
## - h5-1: an optional land's pane is built by the screen
##   ([method WorldScreen.open_place]); the model-side expansion directory
##   only asks for it, so it names no screen class.
## - h1-1: the plain view (no 1997 sheets) holds the pictures it drew — the
##   anchorage, the harbor and the Ebon Crown were white boxes, their
##   textures freed as the painting returned — and draws the pennants.
## - The owner's rulings of 2026-11-03: the anchorage, the harbor and the
##   Ebon Crown push the creatures back as a town does; a campaign that chose
##   the island and cannot sail there now (adventure plugins, 2026-11-10: its
##   card pack off) is told why once a launch on the mainland.
## - Adventure plugins (2026-11-10): the prototype's pictures are decoded
##   from the plugin's bytes ([method AdventurePlugins.texture]), never
##   loaded as resources; the plain view holds the very textures it drew.

const SAVES := "user://c26_x1_expansion_screen"
const CLERIC := 8

var _pack_before: bool
var _note_before: bool


class NoSheets extends WorldArt:
	func texture(_key: String) -> Texture2D:
		return null


func before_each() -> void:
	_pack_before = CardPacks.is_enabled(FallenEmpiresPack.ID)
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	_note_before = WorldScreen.mainland_note_said
	WorldScreen.mainland_note_said = false
	AdventurePlayer.saves_folder = SAVES


func after_each() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, _pack_before)
	WorldScreen.mainland_note_said = _note_before
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file in dir.get_files(): dir.remove(file)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


## A hero of a campaign that chose the island, begun with the flag given, on
## the mainland with the anchorage placed.
func _hero() -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.adventures = ["refuge"]
	setup.packs = ["pack-2"]
	setup.seed_text = "48271"
	setup.player_name = "Wayfarer"
	var record := setup.resolve({"pack-2": "1"})
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	AdventureExpansions.initialize(hero)
	return hero


func _screen(hero: AdventurePlayer, arrival := "") -> WorldScreen:
	var screen: WorldScreen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.player = hero
	screen.world = hero.world
	screen.arrival = arrival
	add_child_autofree(screen)
	await get_tree().process_frame
	return screen


static func _tile(point: Variant) -> Vector2i:
	return Vector2i(int(point[0]), int(point[1]))


## A plain view (no 1997 sheets) of [param hero]'s world over [param tile].
func _plain_view(hero: AdventurePlayer, tile: Vector2i) -> WorldView:
	hero.world.explore_around(tile)
	var view := WorldView.new()
	view.art = NoSheets.new()
	add_child_autofree(view)
	view.size = Vector2(1280, 800)
	view.world = hero.world
	view.hero = Vector2(tile * 32 + Vector2i(16, 16))
	view.camera = view.hero
	await wait_process_frames(3)
	assert_true(view._plain, "drawn plain")
	return view


## A roaming creature in slot [param slot], [param offset] from the hero;
## whatever the slot held before is gone.
func _creature(hero: AdventurePlayer, slot: int, offset: Vector2i) -> Dictionary:
	for held in hero.monsters.duplicate():
		if int((held as Dictionary).get("slot", -1)) == slot:
			hero.monsters.erase(held)
	var at := hero.position + offset
	var creature := {"slot": slot, "kind": "creature", "creature": CLERIC, "x": at.x, "y": at.y,
		"color": 5, "heading": 0, "frame": 0}
	hero.monsters.append(creature)
	return creature


# --------------------------------------------------------------- h5-1 --

func test_the_screen_builds_the_pane_the_directory_asks_for() -> void:
	var screen := await _screen(_hero())
	var place := {"kind": "refuge_reward", "slot": -1, "name": "The Communities' Spells",
		"subtitle": "The Last Refuge", "picture": "visit_city", "lines": ["Words."],
		"actions": [["refuge_leave", "Leave", true]]}
	var pane := AdventureExpansions.show_place(screen, place)
	assert_true(pane is VisitPane, "a town's pane")
	assert_eq(pane, screen._visit, "the screen's own pane")
	assert_eq(pane.get_parent(), screen)
	assert_eq((pane as VisitPane).place, place)
	assert_true(screen.visiting(), "the world waits under it")
	assert_true((pane as VisitPane).left.is_connected(screen._left_place), "its Leave reaches the screen")


# --------------------------------------------------------------- h1-1 --

func test_the_plain_view_keeps_the_anchorage_it_drew() -> void:
	var hero := _hero()
	var port := _tile(hero.world.expansion["entries"]["refuge"])
	var view := await _plain_view(hero, port)
	var sprite: Texture2D = AdventureExpansions.map_op("refuge:port")[0]
	assert_eq(sprite, AdventurePlugins.texture("refuge", "art/refuge_port_map.png"), "decoded from the plugin's bytes")
	var held: Variant = view.get("_plain_held")
	assert_true(held is Array and (held as Array).has(sprite), "held by the view")


func test_the_plain_view_keeps_the_harbor_and_castle_and_draws_the_pennants() -> void:
	var hero := _hero()
	assert_true(_refuge().travel(hero))
	hero.expansions["refuge"]["quests"] = [0, 1, 2, 3, 4]
	hero.expansions["refuge"]["liberated"] = true
	_refuge().refresh_appearance(hero)
	var castle := _tile(hero.world.expansion["castle"])
	var view := await _plain_view(hero, castle)
	var held: Variant = view.get("_plain_held")
	assert_true(held is Array, "the view holds what it drew")
	if not held is Array:
		return
	assert_true((held as Array).has(AdventureExpansions.map_op("refuge:castle")[0]), "the Ebon Crown's picture")
	var flag: Array = RegionPresentation.banner(hero.world, castle)
	assert_false(flag.is_empty(), "the liberated castle wears a pennant")
	assert_true((held as Array).has(flag[0]), "and the plain view draws it")
	var port := _tile(hero.world.expansion["port"])
	view.camera = Vector2(port * 32 + Vector2i(16, 16))
	hero.world.explore_around(port)
	view.hero = view.camera
	await wait_process_frames(3)
	held = view.get("_plain_held")
	assert_true(held is Array and (held as Array).has(AdventureExpansions.map_op("refuge:port")[0]), "the harbor's picture")


func test_the_plain_view_lets_go_when_the_sheets_come_back() -> void:
	var hero := _hero()
	var port := _tile(hero.world.expansion["entries"]["refuge"])
	var view := await _plain_view(hero, port)
	view.set("_plain_held", [AdventureExpansions.map_op("refuge:port")[0]])
	view._plain = false
	view._paint_ground()
	assert_eq(view.get("_plain_held"), [], "nothing held for a plain no longer drawn")


# -------------------------------------- the owner's rulings, 2026-11-03 --

func test_the_anchorage_pushes_the_creatures_back_as_a_town_does() -> void:
	var screen := await _screen(_hero())
	var port := _tile(screen.world.expansion["entries"]["refuge"])
	screen.player.position = port * 32 + Vector2i(16, 16)
	screen.show_player(screen.player)
	var near := _creature(screen.player, 0, Vector2i(30, 5))
	assert_not_null(screen.visit(port), "the anchorage's pane")
	assert_eq(String(screen._visit.place["kind"]), "region_port")
	assert_eq(Vector2i(near["x"], near["y"]), screen.player.position + Vector2i(48, 0), "pushed 48 out")


func test_the_harbor_and_the_ebon_crown_push_the_creatures_back() -> void:
	var hero := _hero()
	assert_true(_refuge().travel(hero))
	var screen := await _screen(hero)
	for kind in ["port", "castle"]:
		if WorldScreen._alive(screen._visit):
			screen._visit.queue_free()
			screen._visit = null
		await get_tree().process_frame
		var at := _tile(hero.world.expansion[kind])
		hero.position = at * 32 + Vector2i(16, 16)
		hero.entered_tile = Vector2i(-1, -1)
		screen.show_player(hero)
		var near := _creature(hero, 1, Vector2i(-20, -20))
		assert_not_null(screen.visit(at), kind)
		assert_eq(String(screen._visit.place["kind"]), "region_" + kind)
		assert_eq(Vector2i(near["x"], near["y"]), hero.position + Vector2i(-48, -48), "%s: pushed back" % kind)


func test_an_island_campaign_whose_ships_cannot_sail_is_told_why_once_a_launch() -> void:
	var hero := _hero()
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	var note := AdventureExpansions.mainland_note(hero)
	assert_eq(note, "Ships to The Last Refuge do not sail: the plugin The Last Refuge (Fallen Empires prototype) needs %s." % AdventurePacks.title(FallenEmpiresPack.ID))
	var screen := await _screen(hero, "Wayfarer takes up the adventure again.")
	assert_eq(screen._arrival.text, "Wayfarer takes up the adventure again.\n" + note,
		"under the arrival's words")
	assert_true(WorldScreen.mainland_note_said)
	screen.show_player(hero)
	assert_eq(screen._arrival.text.count(note), 1, "said once")
	assert_false(screen.hud.notice().contains("do not sail"), "and not again as a notice")
	var again := await _screen(hero, "Wayfarer takes up the adventure again.")
	assert_eq(again._arrival.text, "Wayfarer takes up the adventure again.", "once a launch")


func test_a_hero_home_without_arrival_words_hears_it_as_a_notice() -> void:
	var hero := _hero()
	assert_true(_refuge().travel(hero))
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	var screen := await _screen(hero)
	assert_false(WorldScreen.mainland_note_said, "on the island its harbor says it")
	assert_true(_refuge().travel(hero), "the free voyage home")
	screen.show_player(hero)
	assert_eq(screen.hud.notice(), AdventureExpansions.mainland_note(hero))
	assert_true(WorldScreen.mainland_note_said)


func test_an_ordinary_campaign_hears_nothing() -> void:
	var setup := AdventureSetup.new()
	setup.seed_text = "48271"
	setup.player_name = "Wayfarer"
	var record := setup.resolve({})
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	var screen := await _screen(hero, "Wayfarer takes up the adventure again.")
	assert_eq(screen._arrival.text, "Wayfarer takes up the adventure again.")
	assert_false(WorldScreen.mainland_note_said)


## The prototype plugin's interpreter ([DataRegion]).
func _refuge() -> DataRegion:
	return AdventureExpansions.provider("refuge") as DataRegion
