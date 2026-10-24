extends GutTest
## THE ENTRY LATCH (the bug pass of part B, 2026-10-23). The place the hero
## stands on opens again at a click on it — our QoL; 1997 entered a place
## only as the hero stepped onto it — but that is no new arrival: the
## creatures near are not pushed back again, and a ruled town keeps the
## creature and the stakes it drew as the hero walked in (it drew them anew
## at every click, on the adventure's dice).

var screen: WorldScreen
const SAVES := "user://adventure_tests_entry_latch"


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	screen = WorldScreen.new()
	screen.record = setup.resolve({})
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.player.monsters = [] as Array


func after_each() -> void:
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _first(kind: int) -> int:
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == kind:
			return slot
	return -1


## The hero set down on site [param slot]'s tile.
func _stand_on(slot: int) -> Vector2i:
	var tile := Vector2i(int(screen.world.sites[slot]["x"]), int(screen.world.sites[slot]["y"]))
	screen.player.position = tile * 32 + Vector2i(16, 16)
	return tile


## The place's pane closed by its own leave.
func _close() -> void:
	screen._visit.choose("leave")
	for i in 3:
		await get_tree().process_frame
	var seller := screen.find_child("WorldMagicPane", true, false) as WorldMagicPane
	if seller != null and not seller.is_queued_for_deletion():
		seller.done.emit()
		for i in 3:
			await get_tree().process_frame


func test_a_town_opened_again_pushes_no_creature_back() -> void:
	var town := _first(ShandalarWorld.TOWN)
	var tile := _stand_on(town)
	var near := {"slot": 1, "kind": "creature", "creature": 22, "x": tile.x * 32 + 16 + 40,
		"y": tile.y * 32 + 16, "color": 3, "heading": 0, "frame": 0}
	screen.player.monsters = [near.duplicate()]
	assert_not_null(screen.visit(tile), "walked in")
	var pushed: Dictionary = screen.player.monsters[0]
	assert_ne(int(pushed["x"]), int(near["x"]), "control: a new arrival pushes the creature back")
	await _close()
	screen.player.monsters = [near.duplicate()]
	assert_true(screen.walk_to_tile(tile), "the place stood on opens again")
	assert_true(screen.visiting())
	assert_eq(int(screen.player.monsters[0]["x"]), int(near["x"]), "no creature pushed back again")


func test_a_ruled_town_opened_again_keeps_its_creature_and_stakes() -> void:
	var town := _first(ShandalarWorld.TOWN)
	TownStatus.take(screen.world, town, 4)
	var tile := _stand_on(town)
	var pane := screen.visit(tile)
	await get_tree().process_frame
	assert_not_null(pane)
	var first: Dictionary = (pane.ruled as Dictionary).duplicate(true)
	assert_gt(int(first.get("row", 0)), 0, "control: a creature drawn on entering")
	await _close()
	# Read after the close: the world ticks while no pane holds it, and its
	# roaming slots draw on the same dice (the bug pass of part B, q3-5).
	var dice := screen.player.dice
	assert_true(screen.walk_to_tile(tile), "the town stood on opens again")
	await get_tree().process_frame
	var again: Dictionary = screen._visit.ruled
	assert_eq(int(again["row"]), int(first["row"]), "the same creature")
	assert_eq(again["hero_ante"], first["hero_ante"], "the same stakes")
	assert_eq(again["creature_ante"], first["creature_ante"])
	assert_eq(screen.player.dice, dice, "no dice drawn again")


## The bug pass of part B (q1-1, q3-1): a town the hero stands on but never
## arrived at — a walk stopped on it by a meeting or the news, a teleport —
## is arrived at by the click: its quest delivered, its visit written.
func test_a_town_stood_on_but_never_entered_is_arrived_at() -> void:
	var town := _first(ShandalarWorld.TOWN)
	var tile := _stand_on(town)
	assert_false(TownStatus.visited(screen.world, town), "control: never visited")
	assert_true(screen.walk_to_tile(tile), "the click opens the town")
	assert_true(TownStatus.visited(screen.world, town), "an arrival: the town visited")


## A town arrived at, the hero stepping off its tile and back: arrived at
## again (the latch is only while the hero stays on the tile).
func test_the_latch_ends_when_the_hero_leaves_the_tile() -> void:
	var town := _first(ShandalarWorld.TOWN)
	var tile := _stand_on(town)
	screen.visit(tile)
	assert_eq(screen._entered_tile, tile, "arrived")
	await _close()
	screen.player.position += Vector2i(32, 0)
	await get_tree().process_frame
	assert_eq(screen._entered_tile, Vector2i(-1, -1), "forgotten once the hero stands elsewhere")


## The bug pass of part B (q3-2): a ruled town opened again reads the hero's
## stake from the deck as it is now — a staked card taken out of the deck
## meanwhile is no longer staked.
func test_a_ruled_town_opened_again_reads_the_stake_anew() -> void:
	var town := _first(ShandalarWorld.TOWN)
	TownStatus.take(screen.world, town, 4)
	var tile := _stand_on(town)
	var pane := screen.visit(tile)
	await get_tree().process_frame
	var staked: Array = (pane.ruled as Dictionary).get("hero_ante", []).duplicate()
	assert_false(staked.is_empty(), "control: a stake")
	await _close()
	for entry in screen.player.cards:
		if entry["card"] == staked[0]:
			entry["decks"] = []
	assert_true(screen.walk_to_tile(tile))
	await get_tree().process_frame
	var again: Dictionary = screen._visit.ruled
	assert_false((again["hero_ante"] as Array).has(staked[0]),
		"a card no longer in the deck is not staked (%s)" % [again["hero_ante"]])
