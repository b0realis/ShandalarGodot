extends GutTest
## THE MOVE LIST (the owner, 2026-10-24: "try to make it human readable and
## lapidary!"): an MPN record read as a person reads a game ([MpnMoveList]) —
## each turn under its player, one action a line under its phase, a phase
## where nothing happened left out, in the notation its class doc sets out.


## A record of [param records] (`[kind, data]` pairs) under two players.
func _document(records: Array, p1 := "White Wizard", p2 := "Black Wizard") -> Dictionary:
	var out: Array = []
	for record in records:
		out.append({"kind": record[0], "data": record[1]})
	return {"headers": {"Player.P1": p1, "Player.P2": p2, "Started": "2026-10-24T12:00:00Z"},
		"records": out, "finished": true}


func _object(id: String, card_name: String, zone: String, owner := 0, types := ["creature"]) -> Dictionary:
	return {"id": id, "name": card_name, "zone": zone, "owner": owner, "controller": owner, "types": types}


## The symbols' block every move list opens with, its blank line after.
func _legend() -> String:
	var lines: PackedStringArray = ["Symbols"]
	for entry in MpnMoveList.LEGEND:
		lines.append("  %s%s" % [String(entry[0]).rpad(16), entry[1]])
	lines.append("  " + MpnMoveList.NOT_TOLD)
	lines.append("")
	return "\n".join(lines)


func test_the_legend_explains_every_symbol_the_text_can_hold() -> void:
	var explained: PackedStringArray = []
	for entry in MpnMoveList.LEGEND:
		explained.append(String(entry[0]))
	for symbol in ["→", "⚔", "†", "✕", "↩", "↧", "⇥", "burns 1 → W 19", "#", "×2", "[B]", "uses", "X=5", "{…}", "—"]:
		assert_true(explained.has(symbol), "%s explained" % symbol)
	for mark in MpnMoveList.MARKS.values():
		assert_true(explained.has(String(mark)), "the mark %s explained" % mark)
	var text := MpnMoveList.text(_document([["state", {"turn": 1, "active": 0, "players": [{"life": 20}, {"life": 20}]}]]))
	assert_true(text.find("Symbols") < text.find("Turn 1"), "the symbols before the game")


func _lives(white: int, black: int) -> Dictionary:
	return {"players": [{"life": white}, {"life": black}]}


func test_the_spec_s_own_example_reads_as_a_game() -> void:
	var parsed := MpnCodec.parse_bytes(FileAccess.get_file_as_bytes("res://docs/mpn-examples/finished-game.mpn"))
	assert_eq(String(parsed.get("error", "")), "", "control: the example parses")
	var said := MpnMoveList.text(parsed)
	assert_eq(said, "\n".join([
		'[R "Red Wizard"]', '[G "Green Wizard"]', '[Date "2026-10-21"]', '[Result "1-0"]', "",
		_legend(),
		"Turn 1 · Red Wizard",
		"  main 1   Lightning Bolt → G 17",
		"           {Green Wizard concedes. This annotation explains the outcome; it is not an executable action.}",
		"", "1-0", ""]))


func test_every_mark_of_the_notation() -> void:
	var records := [
		["state", {"turn": 1, "active": 0, "step": "upkeep", "objects": [], "stack": [],
			"players": [{"life": 20}, {"life": 20}]}],
		["state", {"step": "draw"}],
		["draw", {"player": "P1", "count": 1}],
		["state", {"step": "main1", "objects": [_object("o1", "Plains", "battlefield", 0, ["land"])]}],
		["land", {"player": "P1", "object": "o1"}],
		["state", {"objects": [_object("o2", "Holy Strength", "stack", 0, ["enchantment"]),
			_object("o3", "Savannah Lions", "battlefield")],
			"stack": [{"source": "o2", "name": "Holy Strength", "targets": [{"object": "o3"}]}]}],
		["cast", {"player": "P1", "object": "o2"}],
		["state", {"objects": [_object("o4", "Holy Strength", "stack", 0, ["enchantment"])],
			"stack": [{"source": "o4", "name": "Holy Strength", "targets": [{"object": "o3"}]}]}],
		["cast", {"player": "P1", "object": "o4"}],
		["state", {"step": "declare_attackers", "objects": [_object("o5", "White Knight", "battlefield")]}],
		["attack", {"player": "P1", "objects": ["o3", "o5"]}],
		["state", {"step": "declare_blockers", "objects": [_object("o6", "Wall of Bone", "battlefield", 1),
			_object("o7", "Wall of Bone", "battlefield", 1)]}],
		["block", {"attacker": "o5", "blocker": "o6"}],
		["block", {"attacker": "o5", "blocker": "o7"}],
		["state", {"step": "combat_damage", "players": [{"life": 20}, {"life": 16}],
			"objects": [_object("o5", "White Knight", "graveyard")]}],
		["damage", {"source": "o3", "target": "P2", "amount": 4}],
		["die", {"object": "o5", "player": "P1"}],
		["state", {"step": "main2", "objects": [_object("o8", "Swords to Plowshares", "stack", 1, ["instant"])],
			"stack": [{"source": "o8", "name": "Swords to Plowshares", "targets": [{"object": "o3"}]}]}],
		["cast", {"player": "P2", "object": "o8"}],
		["state", {"objects": [_object("o3", "Savannah Lions", "exile")], "players": [{"life": 24}, {"life": 16}]}],
		["leave", {"object": "o3"}],
		["state", {"step": "end"}],
		["discard", {"player": "P1", "object": "o1"}],
		["comment", {"text": "a fine turn"}],
		["state", {"turn": 2, "active": 1, "step": "untap"}],
		["state", {"step": "main1", "objects": [_object("o9", "Fireball", "stack", 1, ["sorcery"])],
			"stack": [{"source": "o9", "name": "Fireball", "x": 30, "targets": [{"player": "P1"}]}]}],
		["cast", {"player": "P2", "object": "o9"}],
		["state", _lives(-6, 16)],
		["damage", {"source": "o9", "target": "P1", "amount": 30}],
		["result", {"result": "0-1"}],
	]
	var said := MpnMoveList.text(_document(records))
	assert_eq(said, "\n".join([
		'[W "White Wizard"]', '[B "Black Wizard"]', '[Date "2026-10-24"]', '[Result "0-1"]', "",
		_legend(),
		"Turn 1 · White Wizard",
		"  main 1   Plains",
		"           Holy Strength → Savannah Lions ×2",
		"  combat   ⚔ Savannah Lions, White Knight",
		"           Wall of Bone ×2 block White Knight † → B 16",
		"  main 2   [B] Swords to Plowshares → Savannah Lions ✕",
		"           W +4 → 24",
		"  end      discards Plains",
		"           {a fine turn}",
		"Turn 2 · Black Wizard",
		"  main 1   Fireball X=30 → W -6#",
		"", "0-1", ""]), "every mark, its place, the phases kept and the empty ones left out")


func test_the_tags_fall_back_and_a_record_before_turn_one() -> void:
	assert_eq(MpnMoveList.tags_of({"Player.P1": "Blue Wizard", "Player.P2": "Black Wizard"}),
		["P1", "P2"] as Array[String], "the same first letter: P1, P2")
	var records := [
		["state", {"turn": 0, "active": 1, "step": "pregame", "players": [{"life": 20}, {"life": 20}]}],
		["draw", {"player": "P2", "count": 7}],
	]
	var read := MpnMoveList.read_game(_document(records, "Blue Wizard", "Black Wizard"))
	assert_eq(read["turns"][0]["heading"], "Before the game · Black Wizard (P2)", "the seat, the tags being P1, P2")
	assert_eq(read["turns"][0]["lines"], [["pregame", "draws 7"]], "the turn's player's own draw of seven")
	assert_eq(read["result"], "* (unfinished)", "no result recorded")
	assert_eq(read["tags"][-1], ["Result", "*"])


func test_the_view_opens_on_a_record_and_escape_closes_it() -> void:
	var folder := "user://mpn_move_list_view"
	DirAccess.make_dir_recursive_absolute(folder)
	var bytes := FileAccess.get_file_as_bytes("res://docs/mpn-examples/finished-game.mpn")
	var file := FileAccess.open(folder.path_join("20261021T183100Z-example.mpn"), FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var screen: PastGamesScreen = load("res://game/records/past_games.tscn").instantiate()
	screen.archive_directory = folder
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_true(screen.open_record(folder.path_join("20261021T183100Z-example.mpn")))
	var view := screen.show_move_list()
	assert_not_null(view, "the move list over the screen")
	var body := screen.find_child("MoveListText", true, false) as RichTextLabel
	assert_string_contains(body.get_parsed_text(), "Lightning Bolt → G 17")
	assert_string_contains(body.get_parsed_text(), "Turn 1")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	screen._unhandled_key_input(escape)
	await get_tree().process_frame
	assert_false(is_instance_valid(view) and not view.is_queued_for_deletion(), "Escape closes it")
	for name_text in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(name_text))
	DirAccess.remove_absolute(folder)


## The lines of turn [param index] of [param records] read under two players.
func _lines(records: Array, index := 0, p1 := "White Wizard", p2 := "Black Wizard") -> Array:
	return MpnMoveList.read_game(_document(records, p1, p2))["turns"][index]["lines"]


const START := {"turn": 1, "active": 0, "step": "main1", "objects": [], "stack": [],
	"players": [{"life": 20}, {"life": 20}]}


func test_an_extra_turn_keeps_its_player_and_a_whole_state_is_no_new_turn() -> void:
	var records := [
		["state", {"turn": 1, "active": 1, "step": "main1", "objects": [], "stack": [], "players": [{"life": 20}, {"life": 20}]}],
		["state", {"turn": 2, "step": "main1", "objects": [_object("o1", "Island", "battlefield", 1, ["land"])]}],
		["land", {"player": "P2", "object": "o1"}],
		["state", {"turn": 2, "active": 1, "step": "main1", "objects": [], "stack": [], "players": [{"life": 20}, {"life": 20}]}],
	]
	var read := MpnMoveList.read_game(_document(records))
	assert_eq(read["turns"].size(), 2, "the same turn repeated whole is no new turn")
	assert_eq(read["turns"][1]["heading"], "Turn 2 · Black Wizard", "an extra turn: its player carries over")
	assert_eq(read["turns"][1]["lines"], [["main 1", "Island"]], "its own action, no [B]")


func test_deaths_their_phase_and_which_card_died() -> void:
	var records := [
		["state", START],
		["state", {"objects": [_object("o1", "Giant Growth", "stack", 0, ["instant"]), _object("o2", "Timber Wolves", "battlefield"),
			_object("o3", "Prismatic Dragon", "graveyard", 1)],
			"stack": [{"source": "o1", "name": "Giant Growth", "targets": [{"object": "o2"}]}]}],
		["cast", {"player": "P1", "object": "o1"}],
		["die", {"object": "o3"}],
		["state", {"step": "declare_attackers", "objects": [_object("o4", "Island", "graveyard", 0, ["land"])]}],
		["die", {"object": "o4"}],
		["die", {"object": "o4"}],
	]
	assert_eq(_lines(records), [["main 1", "Giant Growth → Timber Wolves; † Prismatic Dragon"],
		["combat", "† Island"]], "the other card's death after '; ', a later phase's on a line of its own, told once")


func test_blocks_join_by_their_attacker_and_a_permanent_deals_damage() -> void:
	var records := [
		["state", START],
		["state", {"step": "declare_attackers", "objects": [_object("o1", "Water Elemental", "battlefield"),
			_object("o2", "Water Elemental", "battlefield"), _object("o3", "Zombie", "battlefield", 1),
			_object("o4", "Ghoul", "battlefield", 1), _object("o5", "Dingus Egg", "battlefield", 1, ["artifact"])]}],
		["attack", {"player": "P1", "objects": ["o1", "o2"]}],
		["block", {"attacker": "o1", "blocker": "o3"}],
		["block", {"attacker": "o2", "blocker": "o4"}],
		["state", {"step": "main2", "players": [{"life": 18}, {"life": 20}]}],
		["damage", {"source": "o5", "target": "P1", "amount": 2}],
	]
	assert_eq(_lines(records), [["combat", "⚔ Water Elemental ×2"], ["", "Zombie blocks Water Elemental"],
		["", "Ghoul blocks Water Elemental"], ["main 2", "[B] Dingus Egg deals 2 → W 18"]],
		"two attackers of one name blocked apart; the Egg's damage by its controller")


func test_extra_draws_are_told_and_a_land_put_into_play() -> void:
	var records := [
		["state", START],
		["state", {"step": "draw"}],
		["draw", {"player": "P1", "count": 1}],
		["draw", {"player": "P1", "count": 1}],
		["draw", {"player": "P2", "count": 1}],
		["state", {"step": "main1", "objects": [_object("o1", "Forest", "battlefield", 0, ["land"]),
			_object("o2", "Plains", "battlefield", 0, ["land"])]}],
		["enter", {"player": "P1", "object": "o1"}],
		["enter", {"player": "P1", "object": "o2"}],
		["land", {"player": "P1", "object": "o2"}],
	]
	assert_eq(_lines(records), [["draw", "draws 1"], ["", "[B] draws 1"], ["main 1", "+Forest"], ["", "Plains"]],
		"the turn's first draw untold, the others told; a land put into play, a land played")


func test_counts_and_repeats_are_kept_apart() -> void:
	var records := [
		["state", START],
		["state", {"step": "declare_attackers", "objects": [_object("o1", "Goblin", "battlefield"),
			_object("o2", "Goblin", "battlefield")]}],
		["attack", {"player": "P1", "objects": ["o1", "o2"]}],
		["attack", {"player": "P1", "objects": ["o1"]}],
	]
	assert_eq(_lines(records), [["combat", "⚔ Goblin ×2"], ["", "⚔ Goblin"]], "two Goblins, then one: no ×3")


func test_mate_only_on_the_life_that_ended_the_game() -> void:
	var records := [
		["state", START],
		["state", _lives(0, 20)],
		["comment", {"text": "at 0"}],
		["state", {"step": "main2", "players": [{"life": 4}, {"life": 20}]}],
		["comment", {"text": "back from 0"}],
		["state", _lives(-2, 20)],
		["result", {"result": "0-1"}],
	]
	var lines := _lines(records)
	assert_eq(lines[0][1], "W −20 → 0", "0, and the game goes on: no mate")
	assert_eq(lines[-1][1], "W −6 → -2#", "the life that ended it")


func test_odd_values_read_as_missing_never_as_errors() -> void:
	var records := [
		["state", {"turn": "one", "active": [1], "step": 5, "objects": ["o1", {"id": 7}], "stack": [3, {"source": []}],
			"players": [{"life": "x"}, 4]}],
		["state", {"turn": 1, "active": 0, "objects": [_object("o1", "Island", "battlefield", 0, ["land"])]}],
		["land", {"player": 1, "object": "o1"}],
		["cast", {"player": "P1", "object": ["o1"]}],
		["attack", {"objects": "o1"}],
		["block", {"attacker": 3, "blocker": "o1"}],
		["damage", {"target": {"player": "P2"}, "amount": "3"}],
		["draw", {"count": []}],
		["reveal", {"cards": "Island"}],
		["comment", {"text": {"x": 1}}],
	]
	var said := MpnMoveList.text(_document(records))
	assert_string_contains(said, "Turn 1 · White Wizard")
	assert_string_contains(said, "Island", "a land without a player still told")


func test_names_are_one_line_and_tags_take_the_first_letter() -> void:
	assert_eq(MpnMoveList.tags_of({"Player.P1": "#1 Wizard", "Player.P2": "→ Black"}), ["W", "B"] as Array[String],
		"the first letter, not a digit or a symbol")
	assert_eq(MpnMoveList.tags_of({"Player.P1": "Ann", "Player.P2": ""}), ["P1", "P2"] as Array[String],
		"a name without a letter: P1, P2")
	var records := [["state", START], ["comment", {"text": "ok\nTurn 2 · Black\n  main 1   Black Lotus"}]]
	var said := MpnMoveList.text(_document(records, "Ann \"the\" Bold", "Bo"))
	assert_false(said.contains("\nTurn 2"), "a line break cannot forge a turn")
	assert_string_contains(said, '[A "Ann \\"the\\" Bold"]', "a quote escaped in its tag line")


## THE CONFORMANCE PAIRS (docs/mpn-move-list.md §9): each example record
## renders to its move list byte for byte — the test another implementation
## is held to.
func test_the_examples_render_to_their_move_lists_byte_for_byte() -> void:
	for example in ["knights-and-raiders", "mandurang-and-hydra"]:
		var record := FileAccess.get_file_as_bytes("res://docs/mpn-examples/%s.mpn" % example)
		var parsed := MpnCodec.parse_bytes(record)
		assert_eq(String(parsed.get("error", "")), "", "%s parses" % example)
		var expected := FileAccess.get_file_as_string("res://docs/mpn-examples/%s.txt" % example)
		assert_eq(MpnMoveList.text(parsed), expected, "%s renders to its move list" % example)
