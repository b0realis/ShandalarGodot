extends GutTest
## PART C, W8 — THE END ON THE HERO'S RECORD AND AROUND IT: the record page
## ([HeroStats]) says how long the battles so far banish Arzakon ("368 years
## so far", no lower than 0, the owner's Q-RANK) and, after the win, the
## final years; "Final Battles Lost" once one is lost at his door; the
## journal's "On the map" is a real switch ([member HeroStats.journal_map]);
## Arzakon's portal and its monument each have their own pointer
## ([constant WorldCursors.FOR_PLACE]); a skin's movie comes through
## [method GameSkin.movie] (none: null). Built alone, no world screen, no
## skin needed.

var holder: Control


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


## A hero on a plain world with a few wins logged (kinds 1, 4 and 11) and
## two sieges counted.
func _player() -> AdventurePlayer:
	var world := ShandalarWorld.new()
	world.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	for i in 4:
		world.sites.append({"x": 10 + i, "y": 10, "type": ShandalarWorld.TOWN, "trade": 0, "status": 0})
	var player := AdventurePlayer.new()
	player.world = world
	player.name = "Goya"
	player.color = "red"
	player.difficulty = 1
	player.siege_count = 2
	player.journal = [{"event": "visit", "text": "Visited Kraag Temple", "day": 1}]
	for row in [1, 4, 22]:
		player.log_victory(row, 1)
	return player


func _open(player: AdventurePlayer, map := true) -> HeroStats:
	holder = Control.new()
	add_child_autofree(holder)
	var stats := HeroStats.new()
	stats.player = player
	stats.journal_map = map
	holder.add_child(stats)
	await _frames()
	return stats


func _value(stats: HeroStats, caption: String) -> Label:
	return stats.find_child("Value_" + caption.replace(" ", "_"), true, false) as Label


func test_the_record_says_the_years_so_far_and_the_battles_lost() -> void:
	var player := _player()
	var stats := await _open(player)
	var so_far := FinalBattle.shown(player.score_so_far())
	assert_gt(so_far, 0, "a few wins: some years")
	assert_eq(_value(stats, HeroStats.BANISHED).text, HeroStats.YEARS_SO_FAR % so_far)
	assert_null(_value(stats, HeroStats.FINAL_LOST), "no battle lost yet: no line")
	player.siege_count = 400
	stats.refresh()
	assert_eq(_value(stats, HeroStats.BANISHED).text, "0 years so far", "never below 0, as the end shows it")
	player.final_attempts = 2
	stats.refresh()
	assert_eq(_value(stats, HeroStats.FINAL_LOST).text, "2", "the battles lost at his door")
	player.ended = AdventurePlayer.ENDED_WON
	player.final = {"score": 2368}
	stats.refresh()
	assert_eq(_value(stats, HeroStats.BANISHED).text, "2368 years", "won: the final years")


func test_on_the_map_is_a_switch() -> void:
	var stats := await _open(_player())
	stats.show_tab("Journal")
	await _frames()
	assert_not_null(stats.find_child("JournalOnMap", true, false), "the world's pane offers it")
	holder.queue_free()
	stats = await _open(_player(), false)
	stats.show_tab("Journal")
	await _frames()
	assert_null(stats.find_child("JournalOnMap", true, false), "a pane with no map under it does not")
	assert_not_null(stats.find_child("JournalLines", true, false), "the journal itself is there")


func test_the_portal_and_the_monument_have_their_own_pointers() -> void:
	assert_eq(WorldCursors.FOR_PLACE["portal"], WorldCursors.Kind.PORTAL)
	assert_eq(WorldCursors.FOR_PLACE["monument"], WorldCursors.Kind.MONUMENT)
	var open := WorldCursors.image(WorldCursors.Kind.PORTAL)
	var stone := WorldCursors.image(WorldCursors.Kind.MONUMENT)
	assert_eq(open.get_size(), Vector2i(WorldCursors.SIZE, WorldCursors.SIZE))
	assert_ne(open.get_data(), stone.get_data(), "open and petrified differ")
	assert_ne(open.get_data(), WorldCursors.image(WorldCursors.Kind.CASTLE).get_data(), "not a castle's")
	assert_eq(WorldCursors.hotspot(WorldCursors.Kind.PORTAL), Vector2(16, 16), "a place's middle")


func test_a_movie_the_skin_lacks_is_none() -> void:
	assert_null(GameSkin.movie("no_such_movie"), "null, nothing to play")
