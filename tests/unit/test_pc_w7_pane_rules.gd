extends GutTest
## THE PANES' OWN RULES, HEADLESS (part C, stage C2, W7): who a clue's
## "large black creatures" are ([method CluesPane.creatures_of] — every
## creature the board can set in a room, by the board's own draw), 1997's
## icons ([method CluesPane.icon_parts]: the castle's frames, the dungeon's
## marker pair), the castle-win news line's names ([method
## CastleWinPane.joined]) and the size 1997's words are fitted at without a
## new line break ([method StagePane.fit_points]).

var world: ShandalarWorld


func before_each() -> void:
	world = ShandalarWorld.new()
	for i in 15:
		world.encounters.append({"x": 10 + i, "y": 20, "clues": 0, "cards": [], "color": 1,
			"monster_flags": 0})


func test_a_small_black_dungeon_holds_the_witch_the_knight_the_warlock_and_the_vampire() -> void:
	assert_eq(CluesPane.creatures_of(world, 5), [1, 2, 3, 4] as Array[int],
		"tiers 4, 6, 8, 12: Witch, Undead Knight, Warlock, VampireLord")
	world.encounters[5]["monster_flags"] = DungeonBoard.LARGE
	assert_eq(CluesPane.creatures_of(world, 5), [3, 4, 5, 50] as Array[int],
		"large, tiers 8, 12, 16, 18: Warlock, VampireLord, Nether Fiend, Mandurang")


func test_a_castle_lists_every_creature_of_its_colour_its_rooms_may_hold_not_its_wizard() -> void:
	var black := CluesPane.creatures_of(world, 0)
	assert_eq(black, [37, 43, 6, 4, 46, 39, 44, 5] as Array[int],
		"tiers 10, 11, 12, 13, 14, 16 in the table's order, gold creatures of black too")
	assert_false(CreatureBook.castle_row(1) in black, "the wizard is shown apart")
	for row in CluesPane.creatures_of(world, 4):
		assert_ne(CreatureBook.tier(row), 13, "the white castle has no tier-13 creature")


func test_every_creature_the_board_sets_in_a_room_is_among_them() -> void:
	for color in range(1, 6):
		for index in [color - 1, 5 + color]:
			var castle: bool = int(index) < 5
			for large in [0, DungeonBoard.LARGE]:
				if castle and large != 0:
					continue
				world.encounters[index]["color"] = color
				world.encounters[index]["monster_flags"] = large
				var listed := CluesPane.creatures_of(world, index)
				var met := {}
				for seed_value in 60:
					var rows := DungeonBoard.creatures_for(MsvcRandom.new(seed_value * 7919 + 1), color, large, castle)
					for slot in 4:
						met[rows[slot]] = true
						assert_true(rows[slot] in listed, "colour %d %s: %s (row %d) listed" % [color,
							"castle" if castle else "dungeon", CreatureBook.name_of(rows[slot]), rows[slot]])
				if not castle:
					assert_eq(met.size(), listed.size(), "a dungeon's four, each met")


func test_1997_s_icons_are_the_world_s_own_frames() -> void:
	assert_eq(CluesPane.icon_parts(0), [["world_castles1", 9], ["world_castles1", 8]],
		"the black castle: its ground half, then the castle (the living look)")
	assert_eq(CluesPane.icon_parts(2), [["world_castles2", 4], ["world_castles2", 0]], "the green one")
	var pair := WorldView.dungeon_frames(5)
	assert_eq(CluesPane.icon_parts(5), [pair[1], pair[0]], "a dungeon's marker pair, ground first")
	assert_eq(CluesPane.icon_parts(15), [], "no such slot")


func test_the_news_line_names_the_towns_as_said() -> void:
	assert_eq(CastleWinPane.joined([] as Array[String]), "")
	assert_eq(CastleWinPane.joined(["Kraag Temple"] as Array[String]), "Kraag Temple")
	assert_eq(CastleWinPane.joined(["A", "B"] as Array[String]), "A and B")
	assert_eq(CastleWinPane.joined(["A", "B", "C"] as Array[String]), "A, B and C")


func test_1997_s_words_are_fitted_without_a_new_line_break() -> void:
	var text := "\n".join(CastleWin.defeated_lines(4, ["Kraag Temple", "Andor's Oasis"] as Array[String]))
	var box := CastleWinPane.WORDS_AT.size
	var points := StagePane.fit_points(text, box)
	assert_between(points, 9, 16)
	var probe := PaneStyle.label(text, points)
	var face := probe.get_theme_font("font")
	probe.free()
	for line in text.split("\n"):
		assert_true(face.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, points).x <= box.x,
			"'%s' stands on one line at %d" % [line, points])
	assert_true(StagePane.fit_points(text, box * 0.6) <= points, "a smaller box, a smaller size")
	assert_eq(StagePane.fit_points("Short", Vector2(400, 100)), 16, "room enough: the most")
