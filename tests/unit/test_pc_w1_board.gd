extends GutTest
## THE BOARD ENTERED AND WALKED (part C, stage C1, W1): [method
## DungeonBoard.enter] after [method DungeonDoors.enter] — 1997's order of
## draws on the board's own dice (dungeonEncounter.c 245–405: the floors'
## looks, a dungeon's sheet, the five creatures, the maze), the run record
## the duels read (c2 §12.5), the five creatures (dE:275–344), the moves
## and the line of sight (dE:449–696, 1420–1460), the owner's P4 keys.

var player: AdventurePlayer
var world: ShandalarWorld


func before_each() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.seed_text = "145729"
	var record := setup.resolve({})
	player = AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	world = player.world


func _names(rows: Array[int]) -> Array:
	var out := []
	for row in rows:
		out.append(CreatureBook.name_of(row))
	return out


## A hand-made board: [param open] cells open, [param events] `{cell:
## event}`, the hero on the start and looking round.
func _hand_board(open: Array, events := {}) -> DungeonBoard:
	var board := DungeonBoard.new()
	board.cells.resize(DungeonBoard.CELLS)
	board.cells.fill(0)
	board.depth.resize(DungeonBoard.CELLS)
	board.depth.fill(0)
	for at in open:
		board.cells[at.x * DungeonBoard.HEIGHT + at.y] = DungeonBoard.OPEN
	for at in events:
		board.cells[at.x * DungeonBoard.HEIGHT + at.y] = DungeonBoard.OPEN | (int(events[at]) << DungeonBoard.EVENT_SHIFT)
	board.dice = MsvcRandom.new(1)
	board.monsters = [1, 2, 3, 4, 5] as Array[int]
	board.hero = DungeonBoard.START
	board.reveal(board.hero)
	return board


# ------------------------------------------------------------ going in --

func test_a_dungeon_entered() -> void:
	var slot: Dictionary = world.encounters[7]
	var dice_before := player.dice
	var setup := DungeonDoors.enter(player, 7)
	var board := DungeonBoard.enter(player, setup, 4242)
	assert_not_null(board)
	assert_eq(board.index, 7)
	assert_false(board.castle)
	assert_eq(board.color, int(slot["color"]), "the slot's colour")
	assert_eq(board.rules, int(slot["rules"]), "the slot's rules")
	assert_eq(board.tries, 0, "the first entry")
	assert_eq(board.difficulty, 1)
	assert_eq(board.life_pool, 0, "the pool empty")
	assert_eq(board.dice_card, "")
	assert_eq(board.code, 0)
	assert_eq(board.monsters.size(), 5, "five creatures")
	assert_between(board.tiles, 1, 3, "a dungeon's sheet drawn")
	assert_eq(board.sheet, "dungeon_tiles_%d" % board.tiles)
	assert_eq(board.hero, DungeonBoard.START, "the hero at the start")
	assert_eq(board.facing, DungeonBoard.START_FACING)
	assert_true(board.seen(DungeonBoard.START) and board.seen(DungeonBoard.ENTRANCE), "the start and the door seen")
	assert_eq(board.pending, DungeonBoard.NOWHERE)
	assert_false(board.over)
	assert_eq(player.dice, dice_before, "the adventure's dice untouched")
	assert_eq(board.title(), WorldNames.dungeon_name(7))


func test_the_run_record_is_the_contract() -> void:
	var board := DungeonBoard.enter(player, DungeonDoors.enter(player, 0), 77)
	var run := board.run
	var keys := run.keys()
	keys.sort()
	assert_eq(keys, ["card_in_effect", "castle", "code", "color", "dice_card", "index", "life_pool", "monsters",
		"rules"], "c2 §12.5's keys, and the card in effect")
	assert_eq(run["index"], 0)
	assert_eq(run["castle"], true)
	assert_eq(run["color"], 1, "the black castle")
	assert_eq(run["rules"] & 3, 3, "a castle's rules 0x01 | 0x02")
	assert_eq(run["card_in_effect"], int(world.encounters[0]["card_in_effect"]))
	assert_eq(board.effect_name(), WorldClues.EFFECT_CARDS[int(world.encounters[0]["card_in_effect"])])
	# By reference: what the duels write, the board reads.
	run["life_pool"] = -4
	run["dice_card"] = "Juggernaut"
	assert_eq(board.life_pool, -4)
	assert_eq(board.dice_card, "Juggernaut")
	board.life_pool = 3
	assert_eq(run["life_pool"], 3)
	assert_same(board.monsters, run["monsters"], "one list")
	# Read and written by name, as the duels read an object (Object.get/set).
	for key in ["index", "castle", "color", "rules", "monsters", "life_pool", "dice_card", "code"]:
		assert_eq(board.get(key), run[key], "the board's %s is the record's" % key)
	board.set("dice_card", "")
	board.set("life_pool", 7)
	assert_eq([run["dice_card"], run["life_pool"]], ["", 7], "written by name into the record")


func test_the_same_seed_draws_the_same_board_and_another_a_new_one() -> void:
	var setup := DungeonDoors.enter(player, 7)
	var first := DungeonBoard.enter(player, setup, 5150)
	var again := DungeonBoard.enter(player, setup, 5150)
	var other := DungeonBoard.enter(player, setup, 5151)
	assert_eq(first.as_text(), again.as_text(), "a seed injected: the same maze")
	assert_eq(first.monsters, again.monsters)
	assert_ne(first.as_text(), other.as_text(), "another seed: another maze")
	var clocked := DungeonBoard.enter(player, setup)
	var clocked_too := DungeonBoard.enter(player, setup)
	assert_ne(clocked.dice.state, clocked_too.dice.state, "the clock seeds a fresh maze each entry")


func test_entry_draws_in_1997_s_order() -> void:
	var slot: Dictionary = world.encounters[7]
	var setup := DungeonDoors.enter(player, 7)
	var board := DungeonBoard.enter(player, setup, 31337)
	# By hand: 195 looks, the sheet, the five creatures, then the maze.
	var dice := MsvcRandom.new(31337)
	var written := PackedByteArray()
	written.resize(DungeonBoard.CELLS)
	for row in DungeonBoard.HEIGHT:
		for column in DungeonBoard.WIDTH:
			written[row * DungeonBoard.HEIGHT + column] = dice.rand() & 3
	var tiles := dice.below(3) + 1
	var rows := DungeonBoard.creatures_for(dice, int(slot["color"]), int(slot["monster_flags"]), false)
	var maze := DungeonBoard.generate(dice, false, 0, 1)
	assert_eq(board.tiles, tiles, "the sheet after the looks")
	assert_eq(board.monsters, rows, "the creatures after the sheet")
	assert_eq(board.as_text(), maze.as_text(), "the maze last")
	assert_eq(board.dice.state, dice.state, "and nothing else drawn")
	# The looks: written row by row, 13 to a row; read column by column.
	for x in DungeonBoard.WIDTH:
		for y in DungeonBoard.HEIGHT:
			assert_eq(board.look(Vector2i(x, y)), int(written[x * DungeonBoard.HEIGHT + y]))
	assert_eq(board.look(Vector2i(13, 2)), 0, "1997's transposition: x 13 from y 2 never written")
	for y in DungeonBoard.HEIGHT:
		assert_eq(board.look(Vector2i(14, y)), 0, "nor any of x 14")


func test_a_castle_entered() -> void:
	var slot: Dictionary = world.encounters[2]
	var board := DungeonBoard.enter(player, DungeonDoors.enter(player, 2), 99)
	assert_true(board.castle)
	assert_eq(board.color, 3, "the green castle")
	assert_eq(board.tiles, 0, "no dungeon sheet")
	assert_eq(board.sheet, "dungeon_tiles_green", "its colour's sheet")
	assert_eq(board.monsters[DungeonBoard.WIZARD_SLOT], CreatureBook.castle_row(3), "slot 4 the Great Druid")
	var wizards := 0
	for i in board.cells.size():
		if (board.cells[i] & DungeonBoard.EVENT_MASK) >> DungeonBoard.EVENT_SHIFT == DungeonBoard.WIZARD:
			wizards += 1
	assert_eq(wizards, 1, "the wizard's room")
	assert_eq(board.rules, int(slot["rules"]))
	assert_eq(DungeonBoard.enter(player, {"index": 15}), null, "no such slot")
	assert_eq(DungeonBoard.enter(player, {}), null)


# ------------------------------------------------------- the creatures --

func test_a_dungeon_s_creatures_are_its_colour_and_size() -> void:
	var line_ups := {
		1: [["Witch", "Undead Knight", "Warlock", "VampireLord", "Nether Fiend"],
			["Warlock", "VampireLord", "Nether Fiend", "Mandurang", "Mandurang"]],
		2: [["Seer", "Merfolk Shaman", "Conjurer", "Sea Dragon", "Shapeshifter"],
			["Conjurer", "Sea Dragon", "Shapeshifter", "Whim", "Whim"]],
		3: [["Druid", "Elvish Magi", "Enchantress", "Forest Dragon", "Beastmaster"],
			["Enchantress", "Forest Dragon", "Beastmaster", "Prismat", "Prismat"]],
		4: [["Sorceress", "Sorcerer", "Troll Shaman", "Goblin Lord", "Hydra"],
			["Troll Shaman", "Goblin Lord", "Hydra", "Dracur", "Dracur"]],
		5: [["Cleric", "Priestess", "Crusader", "Paladin", "Arch Angel"],
			["Crusader", "Paladin", "Arch Angel", "Kiska-Ra", "Kiska-Ra"]]}
	for hue in line_ups:
		for start in [1, 2024, 777777]:
			assert_eq(_names(DungeonBoard.creatures_for(MsvcRandom.new(start), hue, 0x02, false)),
				line_ups[hue][0], "colour %d small" % hue)
			assert_eq(_names(DungeonBoard.creatures_for(MsvcRandom.new(start), hue, 0x83, false)),
				line_ups[hue][1], "colour %d large" % hue)


func test_a_castle_s_creatures_come_from_its_six_tiers() -> void:
	var dice := MsvcRandom.new(8086)
	var tiers_seen := {}
	for n in 60:
		for hue in range(1, 6):
			var rows := DungeonBoard.creatures_for(dice, hue, 0x81, true)
			assert_eq(rows[DungeonBoard.WIZARD_SLOT], CreatureBook.castle_row(hue), "slot 4 the castle's wizard")
			for slot in 4:
				var tier := CreatureBook.tier(rows[slot])
				assert_has(DungeonBoard.CASTLE_TIERS, tier, "a castle room's tier")
				assert_true(CreatureBook.is_of(rows[slot], hue), "of the castle's colour")
				if hue == 5:
					assert_ne(tier, 13, "white has no djinn: tier 13 drawn again")
				tiers_seen[tier] = true
	assert_eq(tiers_seen.size(), 6, "control: every tier comes up")


func test_the_dungeon_s_fifth_creature_is_never_met() -> void:
	var setup := DungeonDoors.enter(player, 7)
	for start in 30:
		var board := DungeonBoard.enter(player, setup, start)
		for i in board.cells.size():
			var event := (board.cells[i] & DungeonBoard.EVENT_MASK) >> DungeonBoard.EVENT_SHIFT
			assert_ne(DungeonBoard.monster_slot(event), DungeonBoard.WIZARD_SLOT, "no room of slot 4")
	assert_eq(DungeonBoard.monster_slot(3), 0)
	assert_eq(DungeonBoard.monster_slot(6), 3)
	assert_eq(DungeonBoard.monster_slot(15), 4)
	assert_eq(DungeonBoard.monster_slot(7), -1)


# --------------------------------------------------------------- moving --

func test_the_keys() -> void:
	for pair in [[KEY_HOME, 1], [KEY_PAGEUP, 3], [KEY_PAGEDOWN, 5], [KEY_END, 7],
			[KEY_KP_7, 1], [KEY_KP_9, 3], [KEY_KP_3, 5], [KEY_KP_1, 7],
			[KEY_UP, 1], [KEY_RIGHT, 3], [KEY_DOWN, 5], [KEY_LEFT, 7],
			[KEY_W, 1], [KEY_D, 3], [KEY_S, 5], [KEY_A, 7], [KEY_ESCAPE, 0], [KEY_Q, 0]]:
		assert_eq(DungeonBoard.direction_of_key(pair[0]), pair[1], "key %s" % OS.get_keycode_string(pair[0]))


func test_a_step_moves_turns_and_walls_block() -> void:
	var board := _hand_board([DungeonBoard.ENTRANCE, DungeonBoard.START, Vector2i(8, 11), Vector2i(9, 11)])
	var went := board.step(DungeonBoard.UP_LEFT)
	assert_eq(went["kind"], "blocked", "a wall does nothing")
	assert_eq(board.hero, DungeonBoard.START)
	assert_eq(board.facing, 3, "but the hero turned: facing (1 + 1) % 8 + 1")
	went = board.step(DungeonBoard.UP_RIGHT)
	assert_eq(went["kind"], "moved")
	assert_eq(went["to"], Vector2i(8, 11))
	assert_eq(board.hero, Vector2i(8, 11))
	assert_eq(board.facing, 5)
	board.step(DungeonBoard.DOWN_LEFT)
	assert_eq(board.facing, 1)
	assert_eq(board.step(99)["kind"], "busy", "no such way")


func test_the_entrance_asks_to_leave() -> void:
	var board := _hand_board([DungeonBoard.ENTRANCE, DungeonBoard.START])
	var went := board.step(DungeonBoard.DOWN_RIGHT)
	assert_eq(went["kind"], "out", "the door: the pane asks Leave?")
	assert_eq(board.hero, DungeonBoard.START, "the hero still inside until the board closes")
	assert_false(board.over)
	var left := board.close(player)
	assert_true(board.over)
	assert_eq(board.step(DungeonBoard.UP_RIGHT)["kind"], "busy", "no steps after")
	assert_eq(left["words"], [] as Array[String], "a dungeon says nothing")


func test_seeing_down_the_corridors() -> void:
	# Start (7, 11): east to (10, 11), then a wall; north (7, 10), (7, 9) and
	# a wall; west a wall at once.
	var open := [DungeonBoard.ENTRANCE, DungeonBoard.START, Vector2i(8, 11), Vector2i(9, 11), Vector2i(10, 11),
		Vector2i(7, 10), Vector2i(7, 9), Vector2i(12, 11), Vector2i(7, 7), Vector2i(8, 9)]
	var board := _hand_board(open)
	for at in [DungeonBoard.START, DungeonBoard.ENTRANCE, Vector2i(8, 11), Vector2i(9, 11), Vector2i(10, 11),
			Vector2i(7, 10), Vector2i(7, 9)]:
		assert_true(board.seen(at), "%s in a straight open line" % at)
	assert_false(board.seen(Vector2i(12, 11)), "past the wall at (11, 11)")
	assert_false(board.seen(Vector2i(7, 7)), "past the wall at (7, 8)")
	assert_false(board.seen(Vector2i(8, 9)), "round a corner")
	assert_false(board.seen(Vector2i(11, 11)), "walls are never marked")
	assert_false(board.reveal(DungeonBoard.START), "nothing new from where the hero stands")
	board.step(DungeonBoard.UP_LEFT)
	board.step(DungeonBoard.UP_LEFT)
	assert_true(board.seen(Vector2i(8, 9)), "seen from (7, 9)")


func test_an_event_waits_before_the_hero() -> void:
	var board := _hand_board([DungeonBoard.ENTRANCE, DungeonBoard.START], {Vector2i(8, 11): 4})
	assert_true(board.seen(Vector2i(8, 11)), "the room is seen, its creature with it")
	var went := board.step(DungeonBoard.UP_RIGHT)
	assert_eq(went, {"kind": "event", "event": 4, "to": Vector2i(8, 11)})
	assert_eq(board.hero, DungeonBoard.START, "the hero before it")
	assert_eq(board.pending, Vector2i(8, 11))
	assert_eq(board.code, 4, "the cell's code for the duels")
	assert_eq(board.room_creature(board.code), board.monsters[1], "slot 1's creature")
	assert_eq(board.step(DungeonBoard.DOWN_RIGHT)["kind"], "busy", "no step while its page is open")


func test_the_mouse_s_quadrants() -> void:
	assert_eq(DungeonBoard.direction_toward(Vector2(10, -10)), DungeonBoard.UP_RIGHT, "right and up: +x")
	assert_eq(DungeonBoard.direction_toward(Vector2(10, 10)), DungeonBoard.DOWN_RIGHT, "right and down: +y")
	assert_eq(DungeonBoard.direction_toward(Vector2(-10, 10)), DungeonBoard.DOWN_LEFT, "left and down: −x")
	assert_eq(DungeonBoard.direction_toward(Vector2(-10, -10)), DungeonBoard.UP_LEFT, "left and up: −y")
	assert_eq(DungeonBoard.direction_toward(Vector2.ZERO), DungeonBoard.UP_RIGHT, "on the hero: right and up")
	assert_eq(DungeonBoard.direction_toward(Vector2(0, 5)), DungeonBoard.DOWN_RIGHT, "dx 0 counts as right")
	assert_eq(DungeonBoard.direction_toward(Vector2(-5, 0)), DungeonBoard.UP_LEFT, "dy 0 counts as up")


func test_cells_and_the_page() -> void:
	assert_eq(DungeonBoard.cell_to_page(Vector2i(0, 0)), Vector2i(-96, 272))
	assert_eq(DungeonBoard.cell_to_page(Vector2i(14, 12)), Vector2i(736, 240))
	assert_eq(DungeonBoard.cell_to_page(DungeonBoard.ENTRANCE), Vector2i(512, 352))
	assert_eq(DungeonBoard.cell_to_page(DungeonBoard.START), Vector2i(480, 336))
	for x in DungeonBoard.WIDTH:
		for y in DungeonBoard.HEIGHT:
			var anchor := Vector2(DungeonBoard.cell_to_page(Vector2i(x, y)))
			assert_eq(DungeonBoard.page_to_cell(anchor), Vector2i(x, y), "the anchor of (%d, %d)" % [x, y])
			assert_eq(DungeonBoard.page_to_cell(anchor + Vector2(12, 0)), Vector2i(x, y), "inside its diamond")
			assert_eq(DungeonBoard.page_to_cell(anchor + Vector2(0, 6)), Vector2i(x, y))


func test_a_click_along_a_seen_corridor() -> void:
	var open := [DungeonBoard.ENTRANCE, DungeonBoard.START, Vector2i(8, 11), Vector2i(9, 11), Vector2i(10, 11),
		Vector2i(7, 10), Vector2i(7, 9), Vector2i(12, 11)]
	var board := _hand_board(open, {Vector2i(7, 9): DungeonBoard.TREASURE})
	assert_eq(board.walk_toward(Vector2i(10, 11)), [3, 3, 3] as Array[int], "three steps east")
	assert_eq(board.walk_toward(Vector2i(8, 11)), [3] as Array[int], "a neighbour: one step")
	assert_eq(board.walk_toward(Vector2i(7, 9)), [1, 1] as Array[int], "up to the treasure")
	assert_eq(board.walk_toward(Vector2i(7, 8)), [] as Array[int], "a wall")
	assert_eq(board.walk_toward(Vector2i(12, 11)), [] as Array[int], "past a wall")
	assert_eq(board.walk_toward(Vector2i(8, 10)), [] as Array[int], "not in line")
	assert_eq(board.walk_toward(DungeonBoard.START), [] as Array[int], "the hero's own cell")
	assert_eq(board.walk_toward(DungeonBoard.ENTRANCE), [5] as Array[int], "the door: one step, then the question")
	board.cells[Vector2i(9, 11).x * DungeonBoard.HEIGHT + 11] |= DungeonBoard.SCROLL << DungeonBoard.EVENT_SHIFT
	assert_eq(board.walk_toward(Vector2i(10, 11)), [3, 3] as Array[int], "the walk stops at the first event")


func test_rooms_left() -> void:
	var board := _hand_board([DungeonBoard.ENTRANCE, DungeonBoard.START], {Vector2i(8, 11): 3, Vector2i(9, 11): 6,
		Vector2i(10, 11): DungeonBoard.TREASURE, Vector2i(7, 10): DungeonBoard.DICE, Vector2i(7, 9): DungeonBoard.SCROLL,
		Vector2i(7, 7): DungeonBoard.WIZARD})
	assert_eq(board.rooms_left(), {"creatures": 3, "treasures": 1, "dice": 1, "scrolls": 1})
