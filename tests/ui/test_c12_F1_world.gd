extends GutTest
## THE WORLD SCREEN, THE BUG CAMPAIGN c12 (fixer F1, 2026-10-27):
##  - h1-1, h1-2: the entry latch ([member AdventurePlayer.entered_tile]) is
##    saved. The window closed inside a town, or the town left, then a
##    Resume: a click on the town stood on opens it again and is no new
##    arrival — no second "Visited", the quest offer not drawn again on the
##    dice the save had moved on, no creature pushed back again.
##  - h1-4: the news flash answers to its choice's first letter.
## Keys through the viewport.

## A world screen that never leaves for the title.
class Probe extends WorldScreen:
	func _go_to_title() -> void:
		_leaving = true


const SAVES := "user://adventure_tests_c12_f1_world"

var viewport: SubViewport
var screen: Probe


func before_each() -> void:
	RuledTowns.forget()
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Latch Keeper"
	setup.color = "green"
	setup.difficulty = 0
	setup.walker = "female"
	setup.seed_text = "97531"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	screen = Probe.new()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.player.monsters = [] as Array


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


func _site(kind: int) -> int:
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == kind:
			return slot
	return -1


## The hero set down on site [param slot]'s tile.
func _stand_on(slot: int) -> Vector2i:
	var site: Dictionary = screen.world.sites[slot]
	var tile := Vector2i(int(site["x"]), int(site["y"]))
	screen.player.position = tile * 32 + Vector2i(16, 16)
	return tile


## The journal's arrivals ("Visited %s") of [param player].
func _visits(player: AdventurePlayer) -> int:
	return player.journal.filter(func(line: Dictionary) -> bool: return String(line["event"]) == "visit").size()


## The place's pane closed by its own leave (the World Magic seller after it
## let go too).
func _leave(on: WorldScreen) -> void:
	on._visit.choose("leave")
	await _frames(3)
	var seller := on.find_child("WorldMagicPane", true, false) as WorldMagicPane
	if seller != null and not seller.is_queued_for_deletion():
		seller.done.emit()
		await _frames(3)


## The adventure saved last taken up again on a world screen of its own, as
## Resume and Load show it.
func _resume() -> Probe:
	var loaded := AdventurePlayer.load_from(screen.player.save_path())
	assert_not_null(loaded, "the autosave reads")
	screen.queue_free()
	await _frames(2)
	var again := Probe.new()
	again.player = loaded
	viewport.add_child(again)
	await _frames(3)
	again.player.monsters = [] as Array
	return again


# -------------------------------------------------- the latch saved --

func test_the_latch_is_saved_and_read_for_the_tile_stood_on() -> void:
	var player := screen.player
	var tile := player.tile()
	player.entered_tile = tile
	var data := player.to_dict()
	assert_eq(AdventurePlayer.from_dict(data).entered_tile, tile, "kept")
	(data["where"] as Dictionary)["entered"] = [tile.x + 1, tile.y]
	assert_eq(AdventurePlayer.from_dict(data).entered_tile, Vector2i(-1, -1),
		"a latch on another tile than the hero's is none")
	(data["where"] as Dictionary).erase("entered")
	assert_eq(AdventurePlayer.from_dict(data).entered_tile, Vector2i(-1, -1), "an old save: none")
	(data["where"] as Dictionary)["entered"] = "here"
	assert_eq(AdventurePlayer.from_dict(data).entered_tile, Vector2i(-1, -1), "a misshapen one: none")


func test_the_screen_keeps_the_latch_on_the_adventure() -> void:
	var tile := _stand_on(_site(ShandalarWorld.TOWN))
	assert_not_null(screen.visit(tile))
	assert_eq(screen.player.entered_tile, tile, "arrived: kept on the adventure")
	await _leave(screen)
	screen.player.position += Vector2i(32, 0)
	await _frames(1)
	assert_eq(screen.player.entered_tile, Vector2i(-1, -1), "forgotten as the hero stands elsewhere")


## h1-2: a town left — the autosave made as the hero stands on it — then
## Resume: a click on it opens it again, no new arrival.
func test_a_town_left_then_resumed_is_no_new_arrival() -> void:
	var town := _site(ShandalarWorld.TOWN)
	var tile := _stand_on(town)
	assert_not_null(screen.visit(tile), "arrived")
	assert_eq(_visits(screen.player), 1)
	await _leave(screen)
	assert_eq(screen.player.tile(), tile, "control: the hero still stands on the town")
	var again := await _resume()
	var dice := again.player.dice
	var offer := again.player.quest_offer.duplicate()
	var near := {"slot": 1, "kind": "creature", "creature": 22, "x": tile.x * 32 + 16 + 40,
		"y": tile.y * 32 + 16, "color": 3, "heading": 0, "frame": 0}
	again.player.monsters = [near.duplicate()]
	assert_true(again.walk_to_tile(tile), "the town stood on opens again")
	assert_true(again.visiting())
	assert_eq(_visits(again.player), 1, "no second Visited line")
	assert_eq(again.player.dice, dice, "nothing drawn again: no quest, trade, hint or shop")
	assert_eq(again.player.quest_offer, offer)
	assert_eq(int(again.player.monsters[0]["x"]), int(near["x"]), "no creature pushed back again")


## h1-1: the window closed with the town's pane up saves mid-visit; after a
## Resume the click on the town keeps the quest it offered (a new arrival
## drew it again on the dice the save had moved on: a re-roll).
func test_the_window_closed_in_town_keeps_its_quest_offer() -> void:
	var village := _site(ShandalarWorld.VILLAGE)
	var tile := _stand_on(village)
	screen.player.last_town = -1
	assert_not_null(screen.visit(tile), "arrived")
	var offer := screen.player.quest_offer.duplicate()
	assert_false(offer.is_empty(), "control: the village offers a quest")
	screen._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	var again := await _resume()
	assert_eq(again.player.quest_offer, offer, "saved with the offer")
	assert_true(again.walk_to_tile(tile))
	assert_eq(again.player.quest_offer, offer, "the same quest offered")
	assert_eq(_visits(again.player), 1, "no second Visited line")


## A town the hero stands on but never arrived at is still arrived at after
## a Resume (the latch is kept, not made up).
func test_a_town_never_arrived_at_is_arrived_at_after_a_resume() -> void:
	var town := _site(ShandalarWorld.TOWN)
	var tile := _stand_on(town)
	screen.autosave()
	var again := await _resume()
	assert_eq(again.player.entered_tile, Vector2i(-1, -1))
	assert_true(again.walk_to_tile(tile))
	assert_eq(_visits(again.player), 1, "arrived")


# ------------------------------------------------- the news's letter --

func _key(code: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.unicode = code + 32 if code >= KEY_A and code <= KEY_Z else 0
	key.pressed = true
	viewport.push_input(key, true)
	var up := key.duplicate() as InputEventKey
	up.pressed = false
	viewport.push_input(up, true)


func _lit() -> String:
	var held := viewport.gui_get_focus_owner()
	return String(held.name).trim_prefix("Choice_") if held != null else ""


## h1-4: C lights Continue; Enter then reads on. A letter no choice begins
## with lights nothing and leaves the news up.
func test_the_news_flash_answers_to_its_first_letter() -> void:
	var town := _site(ShandalarWorld.TOWN)
	var news := screen.show_news([{"kind": "siege", "town": town,
		"lines": ["Black Wizard sends a Witch to attack %s!" % WorldNames.site_name(screen.world, town)]}])
	await _frames(2)
	assert_not_null(news)
	_key(KEY_Z)
	assert_eq(_lit(), "", "Z: no choice begins with it")
	assert_true(screen.news_shown())
	_key(KEY_C)
	assert_eq(_lit(), "continue", "C: Continue")
	assert_true(screen.news_shown(), "a letter never takes a choice by itself")
	_key(KEY_ENTER)
	await _frames(2)
	assert_false(screen.news_shown(), "Enter reads on")
