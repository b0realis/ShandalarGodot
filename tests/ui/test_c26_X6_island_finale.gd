extends GutTest
## The 0.60.13 bug campaign (c26), h2-1: an adventure taken up again settles
## its end wherever the save stands. A One-life adventure whose final battle
## began or was lost, saved earlier on the island, opens on the quest-failed
## end (it walked on, and the hero could sail home and fight Arzakon again);
## a won adventure saved roaming the island asks End or Return to Shandalar
## again (the owner's ruling of 2026-10-28). The questions at Arzakon's door
## and at the fifth wizard's fall stay on the mainland. Each save is taken
## up through the world's own load ([method WorldScreen._ready] calls
## [method AdventureFinale.after_load]).

const SAVES := "user://adventure_tests_c26_x6_finale"
const HALL := "user://adventure_tests_c26_x6_finale_hall"


## A world screen that counts its saves.
class Probe extends WorldScreen:
	var saves := 0

	func _write_autosave() -> String:
		saves += 1
		return super()


var _pack_before: bool
var viewport: SubViewport


func before_each() -> void:
	_pack_before = CardPacks.is_enabled(FallenEmpiresPack.ID)
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	AdventurePlayer.saves_folder = SAVES
	HallOfFame.file = HALL + "/hall_of_fame.json"
	AdventureFinale.movie_forced = 0
	TileReveal.forced = 0
	_clear()


func after_each() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, _pack_before)
	AdventureFinale.movie_forced = -1
	TileReveal.forced = -1
	_clear()
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	HallOfFame.file = HallOfFame.FILE
	AdventurePlayer.forget_saves()


func _clear() -> void:
	for folder in [SAVES, HALL]:
		var dir := DirAccess.open(folder)
		if dir == null:
			continue
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(folder)


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


## An island campaign's hero under [param life_rule], on the mainland.
func _hero(life_rule: String) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.adventures = ["refuge"]
	setup.packs = ["pack-2"]
	setup.seed_text = "48271"
	setup.player_name = "Ysolde Starfall"
	setup.life_rule = life_rule
	var record := setup.resolve({"pack-2": "1"})
	return AdventurePlayer.begin(record, AdventureSetup.make_world(record))


## [param player]'s save taken up again: read back, and the world opened
## on it as the load opens it.
func _load(player: AdventurePlayer) -> Probe:
	var loaded := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	assert_not_null(loaded, "the save reads back")
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	var screen := Probe.new()
	screen.player = loaded
	viewport.add_child(screen)
	await _frames(3)
	screen.set_process(false)
	return screen


func test_a_lost_one_life_battle_settles_an_island_save() -> void:
	for on_island in [false, true]:
		var hero := _hero(AdventurePlayer.LIFE_ONE)
		if on_island:
			assert_true(_refuge().travel(hero), "sailed to the island")
		var lines := hero.journal.size()
		# Later, from another save: the final battle began and was lost.
		HallOfFame.mark_one_life(hero.adventure_id, HallOfFame.FAILED)
		var screen: Probe = await _load(hero)
		var loaded := screen.player
		assert_eq(AdventureRegions.mainland(loaded), not on_island)
		assert_eq(loaded.ended, AdventurePlayer.ENDED_FAILED, "the quest failed (island=%s)" % on_island)
		assert_true(screen.ended(), "its end, never the world (island=%s)" % on_island)
		assert_eq(screen.saves, 1, "saved so (island=%s)" % on_island)
		assert_eq(loaded.journal.size(), lines + 1, "the lost battle in the journal")
		assert_eq(String(loaded.final.get("result", "")), FinalBattle.FAILED_END)
		viewport.queue_free()
		await _frames()


func test_a_won_adventure_saved_on_the_island_asks_end_or_return_again() -> void:
	var hero := _hero(AdventurePlayer.LIFE_RELOAD)
	hero.defeated_wizards.assign(AdventurePlayer.COLORS)
	hero.ended = AdventurePlayer.ENDED_WON
	hero.final = {"result": FinalBattle.WON, "score": 1130, "days": 40, "wins": 30}
	FinalBattle.open_portal(hero, false)
	FinalBattle.roam(hero)
	assert_true(_refuge().travel(hero), "roaming on: sailed to the island")
	var lines := hero.journal.size()
	var screen: Probe = await _load(hero)
	var finale := AdventureFinale.showing(screen)
	assert_not_null(finale, "the owner's ruling: asked again on the island too")
	if finale == null:
		return
	await _frames()
	assert_eq(finale.step, AdventureFinale.HALL)
	assert_not_null(finale.find_child("Choice_" + AdventureFinale.ENDED, true, false))
	assert_not_null(finale.find_child("Choice_" + AdventureFinale.ROAMING, true, false))
	assert_true(screen.modal())
	finale._shown_at -= 100000
	finale.last_choice(AdventureFinale.ROAMING)
	await _frames()
	assert_false(screen.modal(), "Return to Shandalar: the hero walks on")
	assert_false(AdventureRegions.mainland(screen.player), "where the save stood")
	assert_eq(screen.player.journal.size(), lines, "the roaming line written once, before")
	assert_eq(screen.player.ended, AdventurePlayer.ENDED_WON)


func test_the_questions_at_the_door_and_the_fifth_fall_stay_on_the_mainland() -> void:
	var hero := _hero(AdventurePlayer.LIFE_RELOAD)
	hero.defeated_wizards.assign(AdventurePlayer.COLORS)
	assert_true(_refuge().travel(hero))
	var screen: Probe = await _load(hero)
	assert_null(AdventureFinale.showing(screen), "no portal opens on the island")
	assert_false(screen.ended())
	assert_eq(screen.saves, 0)

## The prototype plugin's interpreter ([DataRegion]).
func _refuge() -> DataRegion:
	return AdventureExpansions.provider("refuge") as DataRegion
