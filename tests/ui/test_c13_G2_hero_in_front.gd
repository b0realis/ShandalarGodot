extends GutTest
## Needs the imported 1997 skin — THE HERO IN FRONT ON A PLACE'S OWN TILE
## (part C stage C3, h3-5; the owner's ruling of round C3: "hero in front —
## drawn over the building on its own tile"). A place stands with its foot
## on its tile's middle row, the hero's feet there, and 1997 queued the hero
## after its equals: on Arzakon's portal the hero was wholly hidden, on a
## castle mostly. Now a castle or the portal on the hero's own tile is not
## drawn again over them ([method WorldView.hero_parts]); a tile away it
## stands in front as before, a creature on that spot is drawn as 1997 drew
## it, and a town stands as 1997 drew it (the owner, 2026-10-28: "only the
## portal and castles").

var view: WorldView
var world: ShandalarWorld
var portal: Vector2i
var castle := Vector2i(-1, -1)
var town := Vector2i(-1, -1)


func before_each() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "4242"
	world = AdventureSetup.make_world(setup.resolve({}))
	portal = FinalBattle.portal_tile(world)
	for site in world.sites:
		var at := Vector2i(int(site["x"]), int(site["y"]))
		if int(site["type"]) == ShandalarWorld.CASTLE and castle.x < 0:
			castle = at
		elif int(site["type"]) == ShandalarWorld.TOWN and town.x < 0 and TownStatus.ruler(world, world.sites.find(site)) == 0:
			town = at
	view = WorldView.new()
	add_child_autofree(view)
	view.size = Vector2(1280, 800)
	view.fog = false
	view.zoom = 1.0
	view.world = world
	view.portal = {"x": portal.x, "y": portal.y, "state": FinalBattle.PORTAL_OPEN}


## The hero at world point [param at], the camera on them, the pictures
## drawn; the hero's frame on the pictures.
func _stand(at: Vector2) -> Rect2:
	view.hero = at
	view.hero = at
	view.camera = at
	await wait_process_frames(3)
	var key := "world_ego_m"
	return Rect2(view._hero_at() - Vector2(77, 61), view.art.frame_rect(key, view._hero_frame()).size)


func _middle(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * 32 + 16, tile.y * 32 + 16)


## Whether [param parts] draw any of [param sheets] over the figure.
func _covers(parts: Array, sheets: Array) -> bool:
	for part in parts:
		if part[0] in sheets:
			return true
	return false


func _parts(figure: Rect2) -> Array:
	assert_true(view.has_method("hero_parts"), "the parts over the hero, the hero's own tile's place left out")
	return view.call("hero_parts", figure) if view.has_method("hero_parts") else view._in_front_of(view._hero_at().y, figure)


func test_on_the_portal_the_hero_stands_in_front_of_it() -> void:
	assert_true(view.art.ready(), "the 1997 sheets")
	var gate: Array = [GameSkin.our_art(WorldView.portal_key(FinalBattle.PORTAL_OPEN, false, false)),
		GameSkin.our_art(WorldView.portal_key(FinalBattle.PORTAL_OPEN, false, true))]
	var figure := await _stand(_middle(portal))
	assert_true(_covers(view._in_front_of(view._hero_at().y, figure), gate),
		"1997's queue: the portal at the hero's height, over them")
	assert_false(_covers(_parts(figure), gate), "the hero drawn over the portal on its tile")
	figure = await _stand(_middle(portal) + Vector2(8, -8))
	assert_false(_covers(_parts(figure), gate), "anywhere on the tile, behind its middle row too")
	view.portal = {"x": portal.x, "y": portal.y, "state": FinalBattle.PORTAL_PETRIFIED}
	var stone: Array = [GameSkin.our_art(WorldView.portal_key(FinalBattle.PORTAL_PETRIFIED, false, false)),
		GameSkin.our_art(WorldView.portal_key(FinalBattle.PORTAL_PETRIFIED, false, true))]
	figure = await _stand(_middle(portal))
	assert_false(_covers(_parts(figure), stone), "and over the monument")
	figure = await _stand(_middle(portal + Vector2i(1, 0)))
	assert_true(_covers(_parts(figure), stone), "a tile behind it: the monument in front, as before")


func test_on_a_castle_the_hero_stands_in_front_and_a_town_is_1997_s() -> void:
	assert_gt(castle.x, -1, "a castle")
	assert_gt(town.x, -1, "a town")
	var castles: Array = [view.art.texture("world_castles1"), view.art.texture("world_castles2")]
	var figure := await _stand(_middle(castle))
	assert_true(_covers(view._in_front_of(view._hero_at().y, figure), castles), "1997: the castle over the hero")
	assert_false(_covers(_parts(figure), castles), "the hero over the castle on its tile")
	figure = await _stand(_middle(castle + Vector2i(1, 0)))
	assert_true(_covers(_parts(figure), castles), "a tile behind it: the castle in front, as before")
	var towns: Array = []
	for sheet in WorldView.LOCATION_SHEETS:
		towns.append(view.art.texture(String(sheet[1])))
	figure = await _stand(_middle(town))
	assert_true(_covers(view._in_front_of(view._hero_at().y, figure), towns), "1997: the town over the hero")
	assert_true(_covers(_parts(figure), towns), "the owner: a town stands as 1997 drew it")
