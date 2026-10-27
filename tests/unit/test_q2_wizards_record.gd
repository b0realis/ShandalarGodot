extends GutTest
## THE HERO'S RECORD, HEADLESS (the quick world package, 2026-10-27, steps
## 4, 6 and 7): the wizards' record 1997's wizards' window was handed
## ([method WorldStatus.wizard_rows], adventureStats.c 1683–1789), the
## hall's places ([WizardsPicture], Statwin main.cpp), the creature page's
## exact inks and cells ([method HeroStats.record_ink], [method
## HeroStats.creature_cell], adventureStats.c 731–824) and the next duel's
## line as 1997 wrote it ([method WorldStatus.next_duel_line],
## adventureWorldUi.c 1495–1548).


## A hero on a plain world with [param towns] towns, none ruled.
func _player(towns := 6) -> AdventurePlayer:
	var world := ShandalarWorld.new()
	world.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	for i in towns:
		world.sites.append({"x": 10 + i, "y": 10, "type": ShandalarWorld.TOWN, "trade": 0, "status": 0})
	var player := AdventurePlayer.new()
	player.world = world
	return player


## [param count] towns taken by wizard [param wizard] (1 black … 5 white).
func _taps(player: AdventurePlayer, wizard: int, count: int) -> void:
	var taken := 0
	for slot in player.world.sites.size():
		if taken < count and TownStatus.ruler(player.world, slot) == 0:
			TownStatus.take(player.world, slot, wizard)
			taken += 1


func _wins(player: AdventurePlayer, row: int, hue: int, count: int) -> void:
	for i in count:
		player.log_victory(row, hue)


func _row(player: AdventurePlayer, color: String) -> Dictionary:
	for row in WorldStatus.wizard_rows(player):
		if row["color"] == color:
			return row
	return {}


## aS:1736–1738: `required = 30 + 5d + d·towns`, `X = max(5d + 20,
## required − wins)`, `staff = 30 − (required − X)` — X the life.
func test_the_staff_and_the_life_are_1997_s_formula() -> void:
	# [difficulty, towns, wins, life, staff] (the spec's vectors).
	for case in [[1, 2, 0, 37, 30], [1, 2, 13, 25, 18], [0, 0, 15, 20, 20], [3, 2, 1, 50, 29]]:
		var player := _player()
		player.difficulty = case[0]
		_taps(player, 4, case[1])
		_wins(player, 35, 4, case[2])
		var red := _row(player, "red")
		assert_eq([red["taps"], red["wins"], red["life"], red["staff"]], [case[1], case[2], case[3], case[4]],
			"d%d, %d towns, %d wins" % [case[0], case[1], case[2]])
		assert_eq(red["life"], WiseMan.castle_life(player, 4), "the life is the stronghold's own")
	assert_eq(WorldStatus.staff(0, 9, 3), 30, "full with no wins, whatever the towns")
	assert_eq(WorldStatus.staff(40, 0, 0), 20, "the life's floor: no lower than two thirds on Apprentice")


func test_the_rows_name_each_wizard_black_to_white() -> void:
	var rows := WorldStatus.wizard_rows(_player())
	assert_eq(rows.map(func(r: Dictionary) -> String: return r["name"]),
		["Black Wizard", "Blue Wizardess", "Green Wizard", "Red Wizardess", "White Wizard"])
	assert_eq(rows.map(func(r: Dictionary) -> bool: return r["feminine"]), [false, true, false, true, false])
	assert_eq(rows.map(func(r: Dictionary) -> String: return r["color"]), Array(AdventurePlayer.COLORS))


## `duel_wins_to_skull_index` (Statwin main.cpp 2720).
func test_the_skull_steps() -> void:
	var steps := {0: 0, 1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 7: 5, 8: 8, 11: 8, 12: 12, 300: 12}
	for wins in steps:
		assert_eq(WorldStatus.skull_step(wins), steps[wins], "%d wins" % wins)
	var player := _player()
	_wins(player, 1, 1, 7)
	assert_eq(_row(player, "black")["skulls"], 5, "seven wins: the five skulls")


func test_the_gems_are_his_towns_at_most_five() -> void:
	var player := _player(9)
	_taps(player, 2, 7)
	assert_eq(_row(player, "blue")["taps"], 7)
	assert_eq(_row(player, "blue")["gems"], 5, "five pieces at most (town_count, five drawn)")
	assert_eq(_row(player, "green")["gems"], 0)


func test_a_beaten_wizard_is_not_drawn_and_keeps_his_true_wins() -> void:
	var player := _player()
	_taps(player, 5, 2)
	_wins(player, 8, 5, 9)
	player.defeated_wizards.append("white")
	var white := _row(player, "white")
	assert_true(white["beaten"])
	assert_eq([white["staff"], white["gems"]], [0, 0], "no staff, no gems (progress 0)")
	assert_eq([white["wins"], white["skulls"]], [9, 8],
		"[ours: 1997 slip] his skulls are his true wins, not the last count sent")


## 1997's victory log byte is `colour·16 + kind`: a two-colour creature
## counts for the colour it was met as.
func test_a_two_colour_creature_counts_for_the_colour_it_was_met_as() -> void:
	var player := _player()
	var tusk := CreatureBook.row_named("Tusk Guardian")
	assert_true(CreatureBook.is_of(tusk, 3) and CreatureBook.is_of(tusk, 5), "control: green and white")
	_wins(player, tusk, 3, 2)
	assert_eq([_row(player, "green")["wins"], _row(player, "white")["wins"]], [2, 0])


## The hall's places, Statwin's tables.
func test_the_staff_drains_from_the_bottom_of_its_band() -> void:
	# Red: staff at 468, 80, its band 45 + 186; 18 lights lit: 111 rows lit.
	var part := WizardsPicture.drained("red", 18)
	assert_eq(part[1], Rect2(0, 45 + 111, 60, 186 - 111), "the drained picture's own rows")
	assert_eq(part[0], Rect2(468, 80 + 45 + 111, 60, 75), "drawn over the same rows of the lit one")
	assert_eq(WizardsPicture.drained("black", 30), [] as Array[Rect2], "all lit: nothing drained")
	assert_eq(WizardsPicture.drained("white", 0)[1], Rect2(0, 53, 60, 181), "none lit: the whole band")


func test_the_gems_light_their_pieces_in_order() -> void:
	var pieces := WizardsPicture.gem_pieces("white", 2)
	assert_eq(pieces.size(), 2)
	assert_eq(pieces[0], [Rect2(294 + 31, 30 + 13, 16, 15), Rect2(31, 13, 16, 15)])
	assert_eq(pieces[1][1], Rect2(3, 13, 18, 15))
	assert_eq(WizardsPicture.gem_pieces("black", 9).size(), 5, "five pieces at most")
	assert_eq(WizardsPicture.gem_pieces("green", 0).size(), 0)


func test_the_hall_is_fitted_whole_and_knows_who_stands_where() -> void:
	var hall := WizardsPicture.new()
	hall.size = Vector2(320, 300)
	var stage := hall.stage()
	assert_eq(stage.get_scale(), Vector2(0.5, 0.5), "half size: the width is the limit")
	assert_eq(stage.origin, Vector2(0, 30), "centred in the height left")
	assert_eq(hall.wizard_at(Vector2(40, 30 + 100)), "blue", "the left: the Blue Wizardess")
	assert_eq(hall.wizard_at(Vector2(300, 30 + 100)), "black", "the right: the Black Wizard")
	assert_eq(hall.wizard_at(Vector2(160, 30 + 220)), "", "the crystal ball: nobody")
	hall.free()


## aS:785–812, on an integer share.
func test_the_record_s_inks_are_1997_s_exact_rule() -> void:
	var losing_badly := HeroStats.RECORD_INKS[0]
	var losing := HeroStats.RECORD_INKS[1]
	var even := HeroStats.RECORD_INKS[2]
	var winning := HeroStats.RECORD_INKS[3]
	var big := HeroStats.RECORD_INKS[4]
	var cases := [[2, 3, losing, "exactly 40% (five games) is losing"], [9, 13, losing, "40.9% rounds down"],
		[11, 32, losing_badly, "25.6% rounds down, 21 behind"], [23, 15, even, "60.5%: even"],
		[3, 2, even, "five games, 60%"], [4, 1, winning, "80%, only 3 ahead"], [8, 1, big, "88%, 7 ahead"],
		[1, 3, even, "four games"], [0, 0, even, "none"], [6, 4, even, "60%"], [7, 4, winning, "63%"]]
	for case in cases:
		assert_eq(HeroStats.record_ink(case[0], case[1]), case[2], "%d/%d: %s" % [case[0], case[1], case[3]])
	assert_eq(HeroStats.RECORD_INKS, [Color8(15, 79, 71), Color8(191, 35, 15), Color8(91, 99, 151),
		Color8(0, 75, 187), Color8(0, 123, 255)], "1997's palette 0xBF 0xBC 0xB7 0xF4 0xF6")


func test_a_creature_s_picture_is_its_cell_on_the_sheet() -> void:
	assert_eq(HeroStats.creature_cell(1), Rect2(1, 4, 78, 59), "the Witch")
	assert_eq(HeroStats.creature_cell(9), Rect2(1, 68, 78, 59), "the second line")
	assert_eq(HeroStats.creature_cell(55), Rect2(481, 388, 78, 59), "Arzakon")


## The record is tallied by row; an older save's line has only a name.
func test_the_record_counts_by_row_and_reads_an_old_line_by_its_name() -> void:
	var player := _player()
	player.log_event("duel", "Defeated a Witch", {"won": true, "creature": "Witch", "row": 1})
	player.log_event("duel", "Defeated a Witch", {"won": true, "creature": "Witch"})
	player.log_event("duel", "Lost to a Hydra", {"won": false, "creature": "Hydra", "row": 33})
	player.log_event("duel", "Lost to a Shade", {"won": false, "creature": "Shade"})
	var kept := HeroStats.record(player)
	assert_eq(kept["rows"], {1: [2, 0], 33: [0, 1]}, "the old line found its row by name")
	assert_eq(kept["creatures"]["Shade"], [0, 1], "a name the table does not know stays by name")
	player.log_event("duel", "Defeated Arzakon", {"won": true, "creature": "Arzakon", "row": 56})
	assert_eq(HeroStats.record(player)["rows"][55], [1, 0], "Arzakon's second row: his one cell")
	player.journal.pop_back()
	var stats := HeroStats.new()
	var cells := stats.creature_cells(kept)
	assert_eq(cells.map(func(c: Dictionary) -> Variant: return c["row"]), [1, 33, 0],
		"the table's order, the unknown after")
	stats.show_all_creatures = true
	cells = stats.creature_cells(kept)
	assert_eq(cells.size(), HeroStats.CREATURE_LAST + 1, "the whole grid, and the unknown")
	assert_false(cells[1]["fought"], "the Undead Knight never fought: a blank cell")
	assert_true(cells[32]["fought"], "the Hydra, row 33")
	stats.free()


func test_the_next_duel_s_two_figures_stand_apart() -> void:
	var player := _player()
	player.next_duel_life_carried = -2
	player.next_duel_life = 3
	assert_eq(WorldStatus.next_duel_line(player), "Next Duel: -2 lives, +3 lives", "never summed (+1)")
	player.next_duel_life_carried = 0
	player.next_duel_life = 2
	assert_eq(WorldStatus.next_duel_line(player), "Next Duel: +2 lives")
	player.next_duel_life = 0
	player.next_duel_life_carried = 4
	player.next_duel_card = "Lord of Atlantis"
	assert_eq(WorldStatus.next_duel_line(player), "Next Duel: +4 lives, Lord of Atlantis")
	player.next_duel_card = ""
	player.next_duel_first_move = true
	assert_eq(WorldStatus.next_duel_line(player), "Next Duel: +4 lives, First Move")
	# The icons, one a part, in the line's order.
	player.next_duel_life_carried = -2
	player.next_duel_life = 3
	assert_eq(QuestClock.gifts(player).map(func(g: Array) -> int: return g[0]), [59, 58, 57],
		"the skull for the lives carried, the ankh for the gift's, the dagger")
	player.next_duel_life_carried = 5
	assert_eq(QuestClock.gifts(player)[0], [59, "Next duel: 5 more lives, carried from the last"],
		"1997's skull for carried lives more or fewer")
