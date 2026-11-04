extends GutTest
## The game's own `-- --help` (0.60.16, the owner's ask of 2026-11-04):
## which launches ask for it, and that it names every switch the game
## reads.


func test_h_and_help_after_the_separator_ask_for_it() -> void:
	assert_true(MainScreen.wants_help(PackedStringArray(["--help"])))
	assert_true(MainScreen.wants_help(PackedStringArray(["-h"])))
	assert_true(MainScreen.wants_help(PackedStringArray(
		[AdventureExpansions.LAUNCH_FLAG, "-h"])), "beside a play switch")
	assert_false(MainScreen.wants_help(PackedStringArray()))
	assert_false(MainScreen.wants_help(PackedStringArray([MainScreen.DEBUG_WIN_FLAG])))


func test_a_tools_own_help_stays_the_tools() -> void:
	for flag in [MainScreen.DECK_LAB_FLAG, MainScreen.AUTO_DECK_FLAG,
			MainScreen.LAB_QUERY_FLAG, MainScreen.REFEREE_FLAG,
			MainScreen.VERIFY_PACK_1_FLAG]:
		assert_false(MainScreen.wants_help(PackedStringArray([flag, "--help"])),
			flag + " --help is that tool's manual")


func test_the_tool_switches_are_mains() -> void:
	var main_tools: Array[String] = [MainScreen.DECK_LAB_FLAG, MainScreen.AUTO_DECK_FLAG,
		MainScreen.LAB_QUERY_FLAG, MainScreen.REFEREE_FLAG]
	main_tools.append_array(MainScreen.VERIFY_PACK_FLAGS)
	assert_eq(LaunchHelp.TOOL_FLAGS, main_tools,
		"the autoloads' list is the title's (CardPacks reads it before the title)")


func test_it_names_every_switch_main_reads() -> void:
	var text := MainScreen.launch_help("1.2.3")
	var source := FileAccess.get_file_as_string("res://game/main.gd")
	var flags := RegEx.create_from_string("const (\\w+_FLAG) := \"(--[a-z0-9-]+)\"")
	var found := 0
	for m in flags.search_all(source):
		found += 1
		var flag := m.get_string(2)
		if flag.begins_with("--verify-pack-"):
			assert_string_contains(text, "--verify-pack-N")
			assert_true(MainScreen.VERIFY_PACK_FLAGS.has(flag), flag + " among the pack checks")
		else:
			assert_string_contains(text, flag)
	assert_gt(found, 10, "the scan found main's switches")
	for n in [1, 2, 3, 4, 5, 8, 9]:
		assert_string_contains(text, str(n), "pack check %d" % n)


func test_it_names_the_other_switches_and_the_variables() -> void:
	var text := MainScreen.launch_help("1.2.3")
	for word in [AdventureExpansions.LAUNCH_FLAG, PerfLog.FLAG, PerfLog.ENV,
			Settings.HANDHELD_ENV, "SHANDALAR_PACK_", "-h, --help", "1.2.3",
			"-- "]:
		assert_string_contains(text, word)


func test_every_line_fits_a_terminal() -> void:
	for line in MainScreen.launch_help("0.60.16").split("\n"):
		assert_lte(line.length(), 79, line)
