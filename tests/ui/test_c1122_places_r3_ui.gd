extends GutTest
## A PLACE'S JOURNEY ON THE WORLD SCREEN (places, API 3, round 3 of
## 2026-11-22): the `teleport` effect pressed through the visit pane — the
## pane closes, the hero stands beside the target, no pane opens by itself,
## and the world is saved as on leaving a place.

const INN := preload("res://tests/support/c1122_places_fixture.gd")
const ROOT := "user://c1122_places_r3_ui_tests"
const SAVES := "user://c1122_places_r3_ui_saves"


class Probe extends WorldScreen:
	var saves := 0
	var tile_at_save: Array = []

	func _write_autosave() -> String:
		saves += 1
		tile_at_save.append(player.tile())
		return super()

	func _go_to_title() -> void:
		_leaving = true


var viewport: SubViewport
var screen: Probe


func before_each() -> void:
	INN.install(ROOT, INN.sites_r3())
	AdventurePlugins.folders_override = [ROOT] as Array[String]
	AdventurePlugins.scan()
	AdventurePlayer.saves_folder = SAVES
	TileReveal.forced = 0
	var setup := AdventureSetup.new()
	setup.player_name = "Inniscor"
	setup.seed_text = "12345"
	setup.adventures = ["inn"] as Array[String]
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	screen = Probe.new()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.set_process(false)
	screen.player.monsters = [] as Array
	screen.player.food = 50
	var point: Array = screen.world.expansion[AdventureSites.KEY]["inn:inn"]
	screen.player.position = Vector2i(int(point[0]), int(point[1])) * 32 + Vector2i(16, 16)
	screen.saves = 0
	screen.tile_at_save = []


func after_each() -> void:
	await _frames()
	AdventurePlayer.finish_saves()
	TileReveal.forced = -1
	INN.remove(SAVES)
	INN.remove(ROOT)
	AdventurePlugins.folders_override = [] as Array[String]
	AdventurePlugins.scan()
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


func inn() -> DataSites:
	return AdventureSites.provider("inn")


func _press(tail: String) -> void:
	var pane: VisitPane = screen._visit
	assert_not_null(pane, "a pane is open for " + tail)
	if pane == null:
		return
	for action: Array in pane.place.get("actions", []):
		if String(action[0]).ends_with(tail):
			pane.choose(String(action[0]))
			await _frames(2)
			return
	fail_test("the pane has no button %s" % tail)


func test_a_journey_sets_the_hero_down_beside_the_town_and_closes_the_pane() -> void:
	var player := screen.player
	var from := player.tile()
	var landing := inn().teleport_tile(player, "inn", {"to": "nearest_town"})
	assert_ne(landing, Vector2i(-1, -1), "control: there is a way")
	var gold := player.gold
	player.step = 5
	screen.open_place(inn().describe(player, "inn", "guild"))
	await _frames(2)
	await _press(":inn:travel")
	assert_eq(player.tile(), landing, "the hero stands beside the town")
	assert_ne(player.tile(), from)
	assert_eq(player.gold, gold + 1, "its other effects were applied first")
	assert_eq(player.step, 0)
	assert_eq(player.entered_tile, Vector2i(-1, -1), "the entry latch is cleared")
	assert_false(screen.visiting(), "the pane is closed, and none opened by itself")
	assert_false(screen.modal(), "nothing holds the world")
	assert_true(screen.world.is_explored(landing.x, landing.y), "the land around is seen")
	AdventurePlayer.finish_saves()
	await _frames(3)
	screen.autosave()
	assert_gt(screen.saves, 0)
	assert_eq(screen.tile_at_save[-1], landing, "saved where the hero was set down")


func test_a_journey_that_leads_nowhere_keeps_the_hero_and_the_gold() -> void:
	var player := screen.player
	var from := player.tile()
	player.gold = 50
	screen.open_place(inn().describe(player, "inn", "guild"))
	await _frames(2)
	await _press(":inn:to_cellar")
	assert_eq(player.tile(), from)
	assert_eq(player.gold, 50)
	assert_true(screen.visiting(), "the place says why")
	assert_eq(String(screen._visit.place["lines"][0]), "There is no way there from here.")


func test_carrying_the_hero_never_sets_them_on_water() -> void:
	var from := screen.player.tile()
	for y in 64:
		for x in 64:
			if not screen.world.is_land(x, y):
				screen.carry_hero_to(Vector2i(x, y))
				assert_eq(screen.player.tile(), from)
				return
