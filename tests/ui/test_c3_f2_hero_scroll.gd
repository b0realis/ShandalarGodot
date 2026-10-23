extends GutTest
## THE HERO'S PANE WHILE WALKING (adventure campaign 2026-10-23, findings
## h3-5 and h3-13). The hero's pane is built again whenever what it shows
## changes — the gold, the food, the amulets, the days, the journal, the
## World Magics, the cards — and food drops every few steps: the journal
## being read (and the creature record) jumped back to its top as the hero
## walked. And the creature record showed four rows in a scroll 4 × 21
## pixels high while a row is taller: the fourth was cut in half.
##
## The lead's measure (h4-6): the journal tab open while walking, the whole
## journal was made again at every food step — 2,000 lines, 2,016 nodes,
## near half a second each time. Now a food step writes the Hero page's
## numbers in place and leaves the journal alone; the journal's lines are
## made a hundred at a time, older ones as the reader scrolls to them, and a
## new line goes on top.

const SAVES := "user://adventure_tests_c3_f2_hero"

var viewport: SubViewport
var screen: WorldScreen


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	screen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)


func after_each() -> void:
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


## The hero's pane open on [param tab].
func _open(tab: String) -> HeroStats:
	screen.hud.toggle_hero()
	var stats := screen.hud.hero_stats
	stats.show_tab(tab)
	await _frames(3)
	assert_true(screen.hud.hero_shown(), "control: the hero's pane is open")
	return stats


func _scroll(stats: HeroStats, scroll_name: String) -> ScrollContainer:
	return stats.find_child(scroll_name, true, false) as ScrollContainer


func test_the_journal_keeps_its_place_as_the_hero_walks() -> void:
	var player := screen.player
	for i in 80:
		player.log_event("visit", "Visited the town of Line %d, far along the road." % i)
	var stats := await _open("Journal")
	var scroll := _scroll(stats, "Journal")
	assert_not_null(scroll, "control: the journal")
	scroll.scroll_vertical = 300
	await _frames(2)
	assert_eq(scroll.scroll_vertical, 300, "control: read down the journal")
	# A few steps on: food eaten, the panel's numbers follow.
	player.food -= 1
	screen.hud.refresh()
	await _frames(3)
	assert_eq(_scroll(stats, "Journal").scroll_vertical, 300, "the journal is where it was read")
	player.gold += 10
	screen.hud.refresh()
	await _frames(3)
	assert_eq(_scroll(stats, "Journal").scroll_vertical, 300, "and again")
	# A new line written while reading: on top, and the place kept.
	var lines := _scroll(stats, "Journal").find_child("JournalLines", true, false) as Node
	var first := lines.get_child(0)
	player.log_event("visit", "Visited somewhere new.")
	screen.hud.refresh()
	await _frames(3)
	assert_eq(_scroll(stats, "Journal").scroll_vertical, 300, "the place kept as a line is written")
	assert_eq((lines.get_child(0) as Label).text, "Day 0: Visited somewhere new.", "the new line on top")
	assert_eq(lines.get_child(1), first, "the lines made before stay made")
	# Another tab and back: the journal starts at its top again.
	stats.show_tab("Hero")
	stats.show_tab("Journal")
	await _frames(3)
	assert_eq(_scroll(stats, "Journal").scroll_vertical, 0, "opened afresh: from the newest line")


func _fought(player: AdventurePlayer, creatures: int) -> void:
	for i in creatures:
		player.log_event("duel", "Fought creature %d." % i, {"creature": "Creature %d" % i, "won": i % 2 == 0})


func test_the_creature_record_keeps_its_place_too() -> void:
	var player := screen.player
	_fought(player, 30)
	var stats := await _open("Hero")
	var scroll := _scroll(stats, "CreatureScroll")
	assert_not_null(scroll, "control: thirty creatures scroll")
	scroll.scroll_vertical = 40
	await _frames(2)
	assert_eq(scroll.scroll_vertical, 40, "control: scrolled")
	player.food -= 1
	screen.hud.refresh()
	await _frames(3)
	assert_eq(_scroll(stats, "CreatureScroll").scroll_vertical, 40, "the record is where it was read")
	# Another duel: the page is made anew, and the record's place kept.
	_fought(player, 1)
	screen.hud.refresh()
	await _frames(3)
	assert_eq(_scroll(stats, "CreatureScroll").scroll_vertical, 40, "kept as the page is made anew")


func test_four_rows_of_the_creature_record_show_whole() -> void:
	var player := screen.player
	_fought(player, 15)
	var stats := await _open("Hero")
	var scroll := _scroll(stats, "CreatureScroll")
	assert_not_null(scroll, "control: five rows scroll")
	var list := scroll.find_child("Creatures", true, false) as GridContainer
	var fourth := list.get_child(9) as Control
	var fifth := list.get_child(12) as Control
	var bottom := fourth.get_global_rect().end.y - scroll.get_global_rect().position.y
	assert_true(bottom <= scroll.size.y + 0.5, "the fourth row whole (%.1f of %.1f)" % [bottom, scroll.size.y])
	var top := fifth.get_global_rect().position.y - scroll.get_global_rect().position.y
	assert_true(top >= scroll.size.y - 0.5, "the fifth row below, to be scrolled to (%.1f, %.1f)" % [top, scroll.size.y])


func test_a_long_journal_is_made_as_it_is_read() -> void:
	var player := screen.player
	for i in 2000:
		player.log_event("visit", "Visited the town of Line %d, far along the road." % i)
	var stats := await _open("Journal")
	var lines := stats.find_child("JournalLines", true, false) as Node
	assert_eq(lines.get_child_count(), HeroStats.JOURNAL_STEP, "the newest lines made first, not all 2,000")
	assert_eq((lines.get_child(0) as Label).text, "Day 0: Visited the town of Line 1999, far along the road.")
	# A food step: nothing on the journal page is made again.
	var made := lines.get_child(5)
	player.food -= 1
	var started := Time.get_ticks_usec()
	screen.hud.refresh()
	var spent := (Time.get_ticks_usec() - started) / 1000.0
	await _frames(2)
	assert_eq(lines.get_child(5), made, "a food step leaves the journal's lines be")
	assert_lt(spent, 20.0, "a food step costs next to nothing (%.1f ms)" % spent)
	# Scrolled down near the end of what is made: the next older lines.
	var scroll := _scroll(stats, "Journal")
	var bar := scroll.get_v_scroll_bar()
	scroll.scroll_vertical = int(bar.max_value)
	await _frames(3)
	assert_eq(lines.get_child_count(), 2 * HeroStats.JOURNAL_STEP, "the next hundred, older")
	assert_eq((lines.get_child(HeroStats.JOURNAL_STEP) as Label).text,
		"Day 0: Visited the town of Line %d, far along the road." % (1999 - HeroStats.JOURNAL_STEP))


func test_a_food_step_writes_the_hero_page_s_numbers_in_place() -> void:
	var player := screen.player
	var stats := await _open("Hero")
	var food := stats.find_child("Number_food", true, false) as Label
	var face := stats.find_child("HeroName", true, false)
	assert_eq(food.text, str(player.food), "control: the food")
	player.food -= 3
	player.gold += 25
	player.amulets["green"] = int(player.amulets.get("green", 0)) + 1
	screen.hud.refresh()
	await _frames(2)
	assert_eq(food.text, str(player.food), "the food, written again in place")
	assert_eq((stats.find_child("Number_gold", true, false) as Label).text, str(player.gold), "the gold")
	assert_eq((stats.find_child("Number_green", true, false) as Label).text, str(player.amulets["green"]), "an amulet")
	assert_eq(stats.find_child("HeroName", true, false), face, "the page itself not made again")
	# A duel written in the journal: the record changes, the page is made anew.
	player.log_event("duel", "Fought a creature.", {"creature": "Wolf", "won": true})
	screen.hud.refresh()
	await _frames(2)
	assert_eq((stats.find_child("Value_Overall_Won_Loss", true, false) as Label).text, "1/0", "the record follows")
