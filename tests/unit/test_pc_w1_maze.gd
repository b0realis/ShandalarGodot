extends GutTest
## THE BOARD'S MAZE (part C, stage C1, W1): [method DungeonBoard.generate] —
## 1997's lattice, its closing-passages maze in its own dice order
## (dungeonEncounter.c 345–405), the dead ends and the rooms' events
## (`PopulateDungeonCellEvents`, 1643–1783), and the GUARD (the owner's D8:
## 1997 could draw forever). The golden vectors V1–V3, G1–G2 are the
## research's (c1 §3.6), read from the 1.3 decompilation and checked against
## an independent simulation: S is the dice's state just before the first
## closure's draw.


const V1 := ["###############", "###.d.#...2.###", "###.#.#.###.###", "#T..#.#.d....d#",
	"###.#.#######.#", "#..d#T#1......#", "#.#.###.###s#.#", "#.#...#...3.3.#", "#d###2#.#1#.#d#",
	"#T#...#.s.....#", "###.#######.###", "###.........###", "#######E#######"]
const V2 := ["###############", "###.sT#.0.3.###", "###3###1#3#3###", "#.1.3.d.#.3.0T#",
	"#d#d#######3###", "#.3.#.s.0.2.d.#", "#2#2#3#####3#0#", "#.#.d.2...0.#.#", "#s#d#####.###0#",
	"#.3.#...#.#.s.#", "###d#.#.#.#.###", "###T#.......###", "#######E#######"]
const V3 := ["###############", "###.2.d.#W3.###", "###d#d#d###3###", "#.d.#T#.s.3.0.#",
	"#0###########3#", "#.#.s.d.#...#T#", "#d#s#d#.#d#1###", "#.1.#.......s.#", "#.###d#.#0#0#d#",
	"#.d...#.#.#.2.#", "###d#.#.#d#d###", "###.0.#.#...###", "#######E#######"]
## G1's maze as the closures left it (open or solid; the events aside).
const G1 := ["###############", "###.........###", "###.#.#.#######", "#.....#...#...#",
	"#.###.#.#.#.###", "#.....#.#.....#", "#.#.#.###.###.#", "#.#.#.........#", "#.#.#####.###.#",
	"#.....#.......#", "###.#.#.#.#.###", "###...#.....###", "#######.#######"]


func _rows(board: DungeonBoard) -> Array:
	var out := []
	out.append_array(board.as_text())
	return out


## The board as open (".") or solid ("#") only.
func _shape(board: DungeonBoard) -> Array:
	var out := []
	for line in board.as_text():
		var shape := ""
		for ch in line:
			shape += "#" if ch == "#" else "."
		out.append(shape)
	return out


## The dead ends of a finished maze, in scan order: `{at, depth}`.
func _dead_ends(board: DungeonBoard) -> Array:
	var out := []
	for y in DungeonBoard.HEIGHT:
		for x in DungeonBoard.WIDTH:
			var at := Vector2i(x, y)
			if not board.is_open(at) or at == DungeonBoard.ENTRANCE:
				continue
			var ways := 0
			for way in DungeonBoard.STEPS:
				if board.is_open(at + DungeonBoard.STEPS[way]):
					ways += 1
			if ways == 1:
				out.append({"at": at, "depth": board.distance(at)})
	return out


func _depths(ends: Array) -> Array:
	var out := []
	for one in ends:
		out.append(int(one["depth"]))
	return out


# ------------------------------------------------------------ the lattice --

func test_the_lattice_is_38_rooms_and_63_passages() -> void:
	var board := DungeonBoard.new()
	board._lattice()
	var rooms := 0
	var passages := 0
	var open := 0
	for x in DungeonBoard.WIDTH:
		for y in DungeonBoard.HEIGHT:
			if not board.is_open(Vector2i(x, y)):
				continue
			open += 1
			if Vector2i(x, y) == DungeonBoard.ENTRANCE:
				continue
			if x & 1 == 1 and y & 1 == 1:
				rooms += 1
			else:
				passages += 1
	assert_eq(rooms, 38, "the rooms: odd x and odd y")
	assert_eq(passages, 63, "the passages: one coordinate odd")
	assert_eq(open, 102, "open cells, the entrance counted")
	assert_true(board.is_open(DungeonBoard.ENTRANCE) and board.is_open(DungeonBoard.START))
	for corner in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 11), Vector2i(12, 1), Vector2i(13, 11)]:
		assert_false(board.is_open(corner), "a cut corner %s is solid" % corner)
	assert_ne(_rules_broken(board, false), "", "control: the bare lattice is no maze")


# ------------------------------------------------------ the golden vectors --

func test_v1_a_dungeon_on_apprentice() -> void:
	var dice := MsvcRandom.new(12345)
	var board := DungeonBoard.generate(dice, false, 0, 0)
	assert_eq(_rows(board), V1, "V1's board, cell by cell")
	assert_eq(board.attempts, 79, "79 closures tried")
	assert_eq(board.restarts, 0)
	assert_eq(dice.state, 1770234080, "the dice end where 1997's do")
	var depths := _depths(_dead_ends(board))
	assert_eq(depths.min(), 20, "the shallowest dead end")
	assert_eq(depths.max(), 26, "the deepest")


func test_v2_a_dungeon_entered_again_on_sorcerer() -> void:
	var dice := MsvcRandom.new(0xC0FFEE)
	var board := DungeonBoard.generate(dice, false, 1, 2)
	assert_eq(_rows(board), V2, "V2's board")
	assert_eq(board.attempts, 47)
	assert_eq(dice.state, 3010283339)
	var depths := _depths(_dead_ends(board))
	assert_eq([depths.min(), depths.max()], [16, 22])


func test_v3_a_castle_on_wizard() -> void:
	var dice := MsvcRandom.new(777)
	var board := DungeonBoard.generate(dice, true, 0, 3)
	assert_eq(_rows(board), V3, "V3's board")
	assert_eq(board.attempts, 54)
	assert_eq(dice.state, 3557842311)
	var ends := _dead_ends(board)
	assert_eq([_depths(ends).min(), _depths(ends).max()], [28, 38])
	assert_eq(board.event_at(ends[0]["at"]), DungeonBoard.WIZARD, "the wizard: the first dead end in scan order")
	for one in ends.slice(1):
		assert_eq(board.event_at(one["at"]), DungeonBoard.TREASURE, "every other dead end a treasure")


func test_g1_the_guard_restarts_a_stuck_maze() -> void:
	var dice := MsvcRandom.new(0xF6AA20FA)
	var board := DungeonBoard.generate(dice, false, 0, 0)
	assert_not_null(board, "finished")
	assert_eq(board.restarts, 1, "the GUARD started again once")
	assert_eq(board.attempts, 538, "538 closures in all")
	assert_eq(board.maze_dice, 3631614288, "the dice as the last closure was judged")
	assert_eq(_shape(board), G1, "G1's maze")


func test_g2_the_guard_restarts_a_stuck_maze() -> void:
	var dice := MsvcRandom.new(0x47E53272)
	var board := DungeonBoard.generate(dice, false, 0, 0)
	assert_eq(board.restarts, 1)
	assert_eq(board.attempts, 495)
	assert_eq(board.maze_dice, 1205868905)


func test_1997_s_own_loop_never_ends_on_the_stuck_starts() -> void:
	for start in [0xF6AA20FA, 0x47E53272]:
		assert_null(DungeonBoard.generate(MsvcRandom.new(start), false, 0, 0, false),
			"unguarded, %X draws past %d closures" % [start, DungeonBoard.UNGUARDED_MOST])


func test_the_guard_changes_no_maze_1997_finishes() -> void:
	var dice := MsvcRandom.new(20261027)
	var compared := 0
	for n in 150:
		var start := dice.rand() << 16 | dice.rand()
		var level := n % 4
		var castle := n % 3 == 0
		var free := MsvcRandom.new(start)
		var as_1997 := DungeonBoard.generate(free, castle, n % 2, level, false)
		if as_1997 == null:
			continue
		var guarded := MsvcRandom.new(start)
		var ours := DungeonBoard.generate(guarded, castle, n % 2, level)
		compared += 1
		assert_eq(ours.restarts, 0, "no restart on %X" % start)
		assert_eq(_rows(ours), _rows(as_1997), "the same maze from %X" % start)
		assert_eq(guarded.state, free.state, "the same dice after it")
	assert_gt(compared, 140, "control: the starts 1997 finishes")


# --------------------------------------------------- what every maze holds --

func test_every_maze_keeps_1997_s_rules() -> void:
	var dice := MsvcRandom.new(1997)
	var broken := []
	for n in 1000:
		var start := dice.rand() << 16 | dice.rand()
		var castle := n % 2 == 1
		var board := DungeonBoard.generate(MsvcRandom.new(start), castle, n % 3, n % 4)
		if board == null:
			broken.append("%X: no maze" % start)
			continue
		var wrong := _rules_broken(board, castle)
		if wrong != "":
			broken.append("%X: %s" % [start, wrong])
	assert_eq(broken, [], "1,000 mazes: every open cell reached, three dead ends or more, each at depth 16 or more on a row of its own, no event shallower than 8 or at the deepest dead end's depth, none at the entrance or the start, a castle's wizard at its first dead end")


## What [param board] breaks of 1997's rules, "" for nothing.
func _rules_broken(board: DungeonBoard, castle: bool) -> String:
	for x in DungeonBoard.WIDTH:
		for y in DungeonBoard.HEIGHT:
			if board.is_open(Vector2i(x, y)) and board.distance(Vector2i(x, y)) == 0:
				return "(%d, %d) unreachable" % [x, y]
	var ends := _dead_ends(board)
	if ends.size() < DungeonBoard.DEAD_ENDS:
		return "%d dead ends" % ends.size()
	var rows := {}
	var at_ends := {}
	for one in ends:
		var at: Vector2i = one["at"]
		if int(one["depth"]) < DungeonBoard.DEAD_END_DEPTH:
			return "a dead end at depth %d" % one["depth"]
		if rows.has(at.y):
			return "two dead ends on row %d" % at.y
		if at.x & 1 == 0 or at.y & 1 == 0:
			return "a dead end %s not a room" % at
		rows[at.y] = true
		at_ends[at] = true
	var deepest: int = _depths(ends).max()
	var wizards := 0
	for x in DungeonBoard.WIDTH:
		for y in DungeonBoard.HEIGHT:
			var at := Vector2i(x, y)
			var event := board.event_at(at)
			if event == DungeonBoard.WIZARD:
				wizards += 1
			if event == 0 or at_ends.has(at):
				continue
			if board.distance(at) < DungeonBoard.EVENT_DEPTH or board.distance(at) >= deepest or event > 6:
				return "event %d at %s, depth %d" % [event, at, board.distance(at)]
	if board.event_at(DungeonBoard.ENTRANCE) != 0 or board.event_at(DungeonBoard.START) != 0:
		return "an event at the entrance or the start"
	if castle and (wizards != 1 or board.event_at(ends[0]["at"]) != DungeonBoard.WIZARD):
		return "the wizard not alone at the first dead end"
	if not castle and wizards != 0:
		return "a wizard in a dungeon"
	return ""


func test_the_rooms_grow_denser_entry_by_entry() -> void:
	var counts := []
	for times in 4:
		var rooms := 0
		for n in 40:
			var board := DungeonBoard.generate(MsvcRandom.new(9000 + n), false, times, 0)
			for i in board.cells.size():
				var event := (board.cells[i] & DungeonBoard.EVENT_MASK) >> DungeonBoard.EVENT_SHIFT
				if event != 0 and event != DungeonBoard.TREASURE:
					rooms += 1
		counts.append(rooms)
	# m = 5, 4, 3, 2: every 5th layer of depth, then every 4th, 3rd, 2nd.
	assert_lt(counts[0], counts[1], "a second entry is denser")
	assert_lt(counts[1], counts[3], "and the fourth denser still")
	assert_lt(counts[2], counts[3])


func test_the_event_formula_on_a_hand_judged_cell() -> void:
	# C's division toward zero: a cell shallower than the shallowest dead
	# end divides a negative number.
	assert_eq(DungeonBoard._toward_zero(-5, 4), -1)
	assert_eq(DungeonBoard._toward_zero(5, 4), 1)
	assert_eq(DungeonBoard._toward_zero(-3, 4), 0)
