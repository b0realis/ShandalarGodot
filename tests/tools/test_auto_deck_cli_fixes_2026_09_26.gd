extends GutTest
## The AutoDeck CLI's bug pass of 2026-09-26 — one pass over
## DeckLab/auto_deck_cli.gd for the promises its manual made and the
## code did not keep. Each test names the bug it pins:
##
##   * `--keep FILE --vary` at variety 0 built the same deck N times;
##   * the manifest had no column for `--packs`, the two pool toggles,
##     the list file or the sealed numbers, so "a row rebuilds its deck"
##     was true of the default pool only;
##   * `--force` wrote three new decks beside ten old ones, and the
##     Lab's `--field DIR` played all thirteen;
##   * a sealed retry's fresh deal put the `--vary` cards back;
##   * a twenty-digit `--count` saturated `to_int`;
##   * the seeds line named seeds no row held once a retry kept its own;
##   * the decks that fell short of `--distinct` were counted, not named;
##   * a `next:` line with a space in a path was not a shell line;
##   * a kept deck that needed a pack listed its cards as unknown;
##   * `--out` naming a FILE was accepted; a `--list`/`--keep` file that
##     is not there was the run's 1, not the command line's 2;
##   * `.gdignore` was written into any folder pointed at.

var cli: Object = null
var _made: Array[String] = []
var _before: Array[String] = []
var _had_value := false


func before_each() -> void:
	cli = autofree(load("res://DeckLab/auto_deck_cli.gd").new())
	_made.clear()
	_had_value = Settings.has_value("enabled_card_packs")
	_before = Settings.enabled_card_packs()


func after_each() -> void:
	for path in _made:
		var absolute := ProjectSettings.globalize_path(path)
		if DirAccess.dir_exists_absolute(absolute):
			var dir := DirAccess.open(absolute)
			dir.include_hidden = true
			for name in dir.get_files():
				dir.remove(name)
			DirAccess.remove_absolute(absolute)
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(absolute)
	_made.clear()
	if _had_value:
		Settings.set_value("enabled_card_packs", _before, false)
	elif Settings.has_value("enabled_card_packs"):
		Settings.set_value("enabled_card_packs", [] as Array[String], false)
	CardPacks._configure_registry()
	CardRegistry.ensure_loaded()


func _parse(args: Array) -> Dictionary:
	return cli.parse_args(PackedStringArray(args))


func _run(args: Array) -> int:
	return cli._main(PackedStringArray(args + ["--quiet"]))


func _out_dir() -> String:
	var path := "user://auto_deck_fixes_%d_%d" % [Time.get_ticks_usec(), _made.size()]
	_made.append(path)
	return path


func _rows_of(path: String) -> Array:
	var rows: Array = []
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		rows.append(Array(line.split(",")))
	return rows


func _cells(header: Array, row: Array) -> Dictionary:
	var out := {}
	for i in header.size():
		out[String(header[i])] = String(row[i]) if i < row.size() else ""
	return out


func _first_row(out: String) -> Dictionary:
	var rows := _rows_of(out.path_join(cli.MANIFEST_NAME))
	return _cells(rows[0], rows[1])


func _put(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(f, "can write " + path)
	f.store_string(text)
	f.close()


# ---------------------------------------------------------- --keep --vary --

func test_keep_implies_the_variety_distinct_does() -> void:
	# A held deck fixes the colors, and the fill from what is left is
	# the same fill every time at variety 0: twenty varied decks were
	# one deck twenty times.
	assert_eq(_parse(["--out", "x", "--keep", "d.deck"])["variety"], [cli.DISTINCT_VARIETY])
	assert_eq(_parse(["--out", "x", "--keep", "d.deck", "--variety", "0"])["variety"], [0],
		"a spoken variety is kept, in either order")
	assert_eq(_parse(["--out", "x", "--variety", "25", "--keep", "d.deck"])["variety"], [25])
	assert_eq(_parse(["--out", "x"])["variety"], [0], "and nothing without --keep")


func test_a_varied_run_is_varied() -> void:
	# The bug as the owner would have met it: hold a deck, vary one
	# card, ask for three — and get three different fills.
	var out := _out_dir()
	assert_eq(_run(["--out", out, "--count", "1", "--seed", "4242",
		"--sets", "4ed", "--colors", "=R", "--size", "40"]), 0)
	var held_path := out.path_join(String(_first_row(out)["file"]))
	var held := DeckModel.from_deck_list(DeckList.load_file(held_path))
	var name := ""
	for card in held.names():
		if not DeckModel._card(String(card)).is_land():
			name = String(card)
			break
	assert_ne(name, "", "a non-land card to vary")
	var varied := _out_dir()
	assert_eq(_run(["--out", varied, "--count", "3", "--seed", "4242",
		"--keep", held_path, "--vary", name]), 0)
	var rows := _rows_of(varied.path_join(cli.MANIFEST_NAME))
	assert_eq(rows.size(), 4)
	var cards := {}
	for i in range(1, 4):
		var file := varied.path_join(String(_cells(rows[0], rows[i])["file"]))
		cards[FileAccess.get_file_as_string(file)] = true
	assert_gt(cards.size(), 1, "the three fills are not one fill three times")


# ------------------------------------------------------------ manifest --

func test_the_manifest_records_the_pool_switches() -> void:
	# `--packs none` and `--packs 1` wrote the same row for two decks
	# that shared no card. The row now says the pool the deck came from:
	# the packs in force, the two toggles, the list, the sealed numbers.
	for column in ["packs", "original_cards", "completion_pack", "list",
			"boosters", "starters", "free_lands", "extras"]:
		assert_true(cli.MANIFEST_COLUMNS.has(column), column)
	assert_eq(cli.MANIFEST_COLUMNS.find("packs"), cli.MANIFEST_COLUMNS.find("pool") + 1,
		"right after the pool, where the pool is described")
	assert_eq(cli.packs_word([]), "none")
	assert_eq(cli.packs_word(["pack-1", "pack-3"]), "1,3", "spelled the way --packs takes it")
	var out := _out_dir()
	assert_eq(_run(["--out", out, "--count", "1", "--seed", "4242", "--packs", "none",
		"--completion-pack", "off"]), 0)
	var row := _first_row(out)
	assert_eq(row["packs"], "none")
	assert_eq(row["original_cards"], "on")
	assert_eq(row["completion_pack"], "off")
	assert_eq(row["list"], "")
	assert_eq(row["boosters"], "", "a sealed number only for a sealed deck")
	var sealed := _out_dir()
	assert_eq(_run(["--out", sealed, "--count", "1", "--seed", "4242", "--packs", "none",
		"--source", "sealed", "--boosters", "4", "--starters", "0"]), 0)
	var deal := _first_row(sealed)
	assert_eq(deal["boosters"], "4")
	assert_eq(deal["starters"], "0")
	assert_eq(deal["free_lands"], "0")
	assert_eq(deal["extras"], "0")
	# A pack in force is named — where one is found (the checkout's
	# sibling shandalar-packs/, never a runner).
	if CardPacks.has_pack("pack-1"):
		var packed := _out_dir()
		assert_eq(_run(["--out", packed, "--count", "1", "--seed", "4242", "--packs", "1"]), 0)
		assert_eq(_first_row(packed)["packs"], "1")


func test_a_list_source_names_its_file_in_the_row() -> void:
	var out := _out_dir()
	var list := out.path_join("pool.txt")
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out)), OK)
	_put(list, "4 Lightning Bolt\n4 Hill Giant\n4 Gray Ogre\n4 Fireball\n4 Goblin King\n4 Shivan Dragon\n")
	assert_eq(_run(["--out", out, "--count", "1", "--seed", "4242", "--source", "list",
		"--list", list, "--size", "40", "--force"]), 0)
	assert_eq(_first_row(out)["list"], "pool.txt")


# --------------------------------------------------------------- --force --

func test_force_clears_the_previous_run_and_leaves_foreign_files() -> void:
	# The Lab's `--field DIR` plays the folder: ten old decks beside
	# three new ones were thirteen under a three-row manifest.
	var out := _out_dir()
	assert_eq(_run(["--out", out, "--count", "5", "--seed", "4242"]), 0)
	_put(out.path_join("notes.txt"), "mine")
	assert_eq(_run(["--out", out, "--count", "2", "--seed", "9", "--force"]), 0)
	var dir := DirAccess.open(out)
	var decks := 0
	for name in dir.get_files():
		if name.begins_with("deck_") and name.ends_with(".deck"):
			decks += 1
	assert_eq(decks, 2, "the five are gone, the two are there")
	assert_eq(_rows_of(out.path_join(cli.MANIFEST_NAME)).size(), 3, "a header and two rows")
	assert_eq(FileAccess.get_file_as_string(out.path_join("notes.txt")), "mine", "a foreign file stays")
	assert_eq(FileAccess.get_file_as_string(out.path_join(cli.DECKLIST_NAME)).split("\n", false).size(), 2)


func test_out_that_is_a_file_is_refused() -> void:
	var out := _out_dir()
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out)), OK)
	var file := out.path_join("a_file.txt")
	_put(file, "not a folder")
	assert_eq(_run(["--out", file, "--count", "1", "--seed", "4242", "--force"]), 1)
	assert_eq(FileAccess.get_file_as_string(file), "not a folder", "untouched")


func test_the_importer_marker_goes_only_where_the_tool_writes() -> void:
	# `--out DeckLab --force` would have put a `.gdignore` beside the
	# Lab's own scripts. The marker goes into a folder this tool made or
	# one that already holds its manifest.
	var made := "res://DeckLab/results/auto_deck_fixes_test_%d" % Time.get_ticks_usec()
	_made.append(made)
	assert_eq(_run(["--out", made, "--count", "1", "--seed", "4242"]), 0)
	assert_true(FileAccess.file_exists(made.path_join(".gdignore")), "a folder it made")
	assert_eq(_run(["--out", made, "--count", "1", "--seed", "4242", "--force"]), 0)
	assert_true(FileAccess.file_exists(made.path_join(".gdignore")), "and one it filled")
	var foreign := "res://DeckLab/results/auto_deck_fixes_foreign_%d" % Time.get_ticks_usec()
	_made.append(foreign)
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(foreign)), OK)
	_put(foreign.path_join("theirs.txt"), "x")
	assert_eq(_run(["--out", foreign, "--count", "1", "--seed", "4242", "--force"]), 0)
	assert_false(FileAccess.file_exists(foreign.path_join(".gdignore")),
		"a folder that held somebody else's files gets no marker")


# ------------------------------------------------------------- numbers --

func test_a_whole_number_that_is_not_one_is_refused() -> void:
	# `is_valid_int` is true of twenty digits and `to_int` saturates.
	assert_true(cli.is_whole_number("42"))
	assert_true(cli.is_whole_number("-7"))
	assert_true(cli.is_whole_number("999999999999999999"), "eighteen digits fit")
	assert_false(cli.is_whole_number("9999999999999999999999"))
	assert_false(cli.is_whole_number("4.0"))
	assert_string_contains(str(_parse(["--out", "x", "--count", "99999999999999999999"]).error),
		"--count takes a whole number")
	assert_string_contains(str(_parse(["--out", "x", "--count", "1000000"]).error),
		"--count must be <= 999,999")
	assert_false(_parse(["--out", "x", "--count", "999999"]).has("error"))


func test_the_seeds_line_names_the_seeds_the_rows_hold() -> void:
	# With --distinct a deck keeps a retry's seed, past the run's own
	# stride; the line names the least and the most seed written.
	var out := _out_dir()
	assert_eq(_run(["--out", out, "--count", "3", "--seed", "4242", "--distinct", "1"]), 0)
	var rows := _rows_of(out.path_join(cli.MANIFEST_NAME))
	var low := 0
	var high := 0
	for i in range(1, rows.size()):
		var seed_value := int(_cells(rows[0], rows[i])["seed"])
		low = seed_value if i == 1 else mini(low, seed_value)
		high = maxi(high, seed_value)
	assert_eq(low, 4242, "the first deck holds the base seed")
	assert_gte(high, low)
	assert_true(FileAccess.file_exists(out.path_join(cli.MANIFEST_NAME)))


func test_the_decks_short_of_distinct_are_named() -> void:
	assert_eq(cli.short_list(PackedStringArray(["a (5%)", "b (7%)"])), "a (5%), b (7%)")
	var many := PackedStringArray()
	for i in 11:
		many.append("deck_%d" % i)
	var line: String = cli.short_list(many)
	assert_string_contains(line, "deck_7")
	assert_false(line.contains("deck_8"))
	assert_string_ends_with(line, "and 3 more")


# ---------------------------------------------------------- the next: --

func test_the_next_line_is_a_shell_line() -> void:
	assert_eq(cli.shell_word("out/decks"), "out/decks")
	assert_eq(cli.shell_word("my decks"), "'my decks'")
	assert_eq(cli.shell_word("it's"), "'it'\\''s'")
	var line: String = cli.next_step_line("my decks", null, "held deck.deck")
	assert_string_contains(line, "--field 'my decks'")
	assert_string_contains(line, "--field 'held deck.deck'")
	assert_string_contains(cli.next_step_line("out", null, ""), "--field out ")


# ------------------------------------------------------------- refusals --

func test_a_kept_deck_that_needs_a_pack_names_the_pack() -> void:
	# The `--sets` refusal's own standard: a pack the line did not put
	# on is a switch to add, not a list of cards the game lacks.
	if CardPacks.is_enabled("pack-3"):
		pass_test("Ice Age is on in this run; the refusal is for a pack that is not")
		return
	var out := _out_dir()
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out)), OK)
	var kept := out.path_join("ice.deck")
	_put(kept, "# requires-pack: pack-3\n20 Mountain\n4 Zuran Orb\n")
	assert_eq(_run(["--out", out, "--count", "1", "--seed", "4242", "--keep", kept, "--force"]), 2)
	assert_eq(cli.missing_packs_message(["pack-3"] as Array[String]),
		"needs card pack 3, which is not in play — add `--packs 3`, or `--packs all` for every pack found")
	assert_eq(cli.missing_packs_message([] as Array[String]), "")


func test_a_file_that_is_not_there_is_a_wrong_command_line() -> void:
	var out := _out_dir()
	assert_eq(_run(["--out", out, "--count", "1", "--keep", "user://no_such.deck"]), 2)
	assert_eq(_run(["--out", out, "--count", "1", "--source", "list",
		"--list", "user://no_such.txt"]), 2)
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(out)),
		"refused before the output folder is made")


func test_the_hints_say_where_a_relative_path_lands_and_what_quiet_does() -> void:
	assert_string_contains(String(cli.FLAG_HINTS["--out"]), "under the project root")
	assert_string_contains(String(cli.TOGGLE_HINTS["--quiet"]), "the report still prints")
	assert_false(String(cli.TOGGLE_HINTS["--quiet"]).contains("errors only"))
