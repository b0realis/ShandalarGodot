extends GutTest
## THE BUG PASS OF PART B (2026-10-23), the world screen's share:
##  - q3-3: a step bringing the news holds the rest of its tick until the
##    news is read — the place that step reached is entered first — so the
##    quest's deadline is not judged before it (a letter delivered on its
##    last day was failed for the news read before the town was entered).

var screen: WorldScreen
const SAVES := "user://adventure_tests_c4_bugpass"


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


func test_the_deadline_waits_for_the_news_and_the_place() -> void:
	var town := _first(ShandalarWorld.TOWN)
	var village := _first(ShandalarWorld.VILLAGE)
	# A letter on its last unit: judged now, it fails.
	screen.player.quest = {"type": Quests.LETTER_LINK, "destination": town, "giver": village,
		"color": 1, "data": 0, "deadline": screen.player.quest_timer}
	screen.walk.walk_to(screen.player.tile() + Vector2i(3, 0))
	screen.walk.news.append({"kind": "siege", "lines": ["A test news."], "town": town,
		"wizard": 1, "creature": 1})
	screen._tick_left = 0.0
	screen.advance(HeroWalk.TICK)
	assert_true(screen._tick_held, "control: the tick waits for the news")
	assert_false(screen.player.quest.is_empty(), "the deadline not judged while the news waits")
	screen._after_news()
	assert_true(screen.player.quest.is_empty(), "judged once the tick's rest has run")
