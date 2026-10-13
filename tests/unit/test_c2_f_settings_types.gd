extends GutTest
## A SETTINGS FILE WITH THE WRONG TYPES IN IT (robustness campaign of
## 2026-10-12). `settings.cfg` is a text file the docs invite a player to
## edit, and an older build may have written a key in another type. A
## `"yes"` where a switch is read, a `"fast"` where a number is, a list
## where the table of bindings is, raised a script error on every start
## — from the typed accessors (`ai_pace`, the volumes, the switches,
## `rule`, `hand_style`, `hand_stack_pos`), from every
## `bool(Settings.get_value(...))` in the shell, from [method
## Controls.apply], and from the one-time rules migration, which then
## never finished and failed again on the next start.
##
## [method Settings.get_value] now hands every reader the type of the
## default it passed: a near value read as meant ("yes", 1, "-10"), and
## anything else the default. The run fails on any script error, so each
## test here failed before the fix on the error alone.

const PATH := "user://settings.cfg"

var _had := false
var _old := PackedByteArray()


func before_all() -> void:
	Settings.flush()
	_had = FileAccess.file_exists(PATH)
	if _had:
		_old = FileAccess.get_file_as_bytes(PATH)


func after_all() -> void:
	if _had:
		Settings.write_atomically(PATH, _old)
	elif FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	Settings.reload_file()
	Controls.apply()


## A start that finds [param body] under `[options]`.
func _boot_with(body: String) -> void:
	Settings.write_atomically(PATH, ("[options]\n" + body + "\n").to_utf8_buffer())
	Settings.reload_file()


func test_numbers_written_as_words_read_as_numbers_or_the_default() -> void:
	_boot_with('ai_pace="fast"\nmusic_volume_db="-10"\nsfx_volume_db="loud"')
	assert_eq(typeof(Settings.ai_pace()), TYPE_FLOAT)
	assert_eq(Settings.ai_pace(), 0.35, "a word that is no number: the default")
	assert_eq(Settings.music_volume_db(), -10.0, "a number in quotes is the number")
	assert_eq(Settings.sfx_volume_db(), -6.0)


func test_a_number_that_is_not_a_number_is_the_default() -> void:
	_boot_with("music_volume_db=nan\nsfx_volume_db=inf")
	assert_eq(Settings.music_volume_db(), -14.0, "nan never reaches a bus")
	assert_eq(Settings.sfx_volume_db(), -6.0)


func test_switches_read_the_words_a_hand_types() -> void:
	_boot_with('sound_enabled="off"\nmusic_enabled="on"\nfullscreen="yes"\npower_saver=0\nfullscreen_cards="maybe"')
	assert_eq(Settings.sound_enabled(), false)
	assert_eq(Settings.music_enabled(), true)
	assert_eq(Settings.fullscreen(), true)
	assert_eq(Settings.power_saver(), false, "0 is off")
	assert_eq(typeof(Settings.fullscreen_cards()), TYPE_BOOL)
	assert_eq(Settings.fullscreen_cards(), Settings.default_for("fullscreen_cards", false),
		"a word that is neither: the default")


func test_a_rules_fork_written_as_a_word() -> void:
	for preset in ["modern_mana_burn", "fifth"]:
		var rules := RulesOptions.new()
		rules.set_preset(preset)
		for fork in RulesOptions.FORKS:
			var key: String = fork["key"]
			var value := bool(rules.get_fork(key))
			# Marked as migrated: this is a reader's test, not the migration's.
			_boot_with('rules_revision=%d\nrule_%s="%s"' % [Settings.RULES_REVISION, key, "True" if value else "no"])
			assert_eq(Settings.rule(key), value, "%s, %s: the word is the choice" % [preset, key])
	var defaults := RulesOptions.new()
	defaults.set_preset(RulesOptions.DEFAULT_PRESET)
	_boot_with('rules_revision=%d\nrule_attackers_revocable="sometimes"' % Settings.RULES_REVISION)
	assert_eq(Settings.rule("attackers_revocable"), bool(defaults.get_fork("attackers_revocable")),
		"a word that is neither: the player's default")


func test_text_and_positions_of_the_wrong_kind_are_the_defaults() -> void:
	_boot_with("hand_style=2\nhand_stack_pos=5\nopp_hand_stack_pos=Vector2i(10, 20)")
	assert_eq(Settings.hand_style(), "stack")
	assert_eq(Settings.hand_stack_pos(), Vector2(1062, 412))
	assert_eq(Settings.opp_hand_stack_pos(), Vector2(10, 20), "whole-number position, read as one")


## Every `bool(Settings.get_value(KEY, true))` in the shell (the Deck
## Builder's own switches, its sound, the card reader's text) is fixed
## here, at the one place they all read.
func test_bool_of_a_stored_word_is_a_bool() -> void:
	_boot_with('deck_builder_big_cards="no"\ndeck_sound_effects="True"\nrarity_marks=[1]')
	assert_eq(bool(Settings.get_value("deck_builder_big_cards", true)), false)
	assert_eq(bool(Settings.get_value("deck_sound_effects", false)), true)
	assert_eq(bool(Settings.get_value("rarity_marks", false)), false, "a list is no switch")


func test_a_value_of_another_kind_is_the_default_whatever_the_reader() -> void:
	_boot_with('a_table=["x"]\na_list={"k": 1}\na_count="12"\na_name=7\na_word=&"stack"')
	assert_eq(Settings.get_value("a_table", {}), {})
	assert_eq(Settings.get_value("a_list", []), [])
	assert_eq(Settings.get_value("a_count", 3), 12, "a whole number in quotes")
	assert_eq(String(Settings.get_value("a_name", "nobody")), "nobody",
		"a number is not a name: String(7) is a script error")
	assert_eq(Settings.get_value("a_word", ""), "stack", "a StringName is text")


func test_lists_stay_lists_and_a_null_default_reads_the_value_as_stored() -> void:
	_boot_with('packs=PackedStringArray("pack-2", "pack-3")\nstops=[1, 2]\nraw="anything"')
	var packs: Variant = Settings.get_value("packs", [])
	assert_eq(typeof(packs), TYPE_ARRAY, "a packed list read as an Array")
	assert_eq(packs, ["pack-2", "pack-3"])
	var stops: Variant = Settings.get_value("stops", PackedInt32Array())
	assert_true(stops is Array, "a plain list where a packed one is read: kept for the reader to check")
	assert_eq(Settings.get_value("raw", null), "anything", "null asks for the stored value")
	assert_null(Settings.get_value("c2_never_written", null),
		"and is null, quietly, for a key that is not there")
	assert_eq(Settings.get_value("raw", "x"), "anything", "text where text is read")


func test_enabled_card_packs_from_a_single_word() -> void:
	_boot_with('enabled_card_packs="pack-2"')
	assert_eq(Settings.enabled_card_packs(), [] as Array[String])


func test_the_bindings_table_written_as_a_list_leaves_the_defaults() -> void:
	_boot_with('controls=["ui_accept"]')
	Controls.apply()
	for action in Controls.names():
		assert_true(InputMap.has_action(action), action)
	var first := Controls.names()[0]
	assert_eq(InputMap.action_get_events(first).size(), Controls.defaults(first).size(),
		"the project's own keys, not none")


## The one-time rules migration reads the stored forks; a word there
## stopped it, so it ran — and failed — on every start.
func test_the_rules_migration_finishes_over_words() -> void:
	_boot_with('rule_free_damage_assignment="false"')
	assert_eq(int(Settings.get_value(Settings.RULES_REVISION_KEY, 1)), Settings.RULES_REVISION,
		"the migration finished and marked the file")
	assert_eq(Settings.rule("free_damage_assignment"), true,
		"the old preset's false moves with the preset, as for a real false")
	var text := FileAccess.get_file_as_string(PATH)
	assert_string_contains(text, "rules_revision=%d" % Settings.RULES_REVISION, "and the marker is on disk")
	# A file whose other forks read FIFTH (in words) is a custom choice and
	# keeps its false.
	var body := 'rule_free_damage_assignment="false"\n'
	for fork in RulesOptions.FORKS:
		var key: String = fork["key"]
		if key != "free_damage_assignment":
			body += 'rule_%s="%s"\n' % [key, "true" if bool(fork["fifth_value"]) else "false"]
	_boot_with(body)
	assert_eq(int(Settings.get_value(Settings.RULES_REVISION_KEY, 1)), Settings.RULES_REVISION)
	assert_eq(Settings.rule("free_damage_assignment"), false, "a mixed file is left alone")


## The [method Settings.coerce] table on its own, for the readers that
## pass a default of their own type.
func test_coerce_table() -> void:
	var cases := [
		[true, 1, false], [false, "0", true], [true, " Yes ", false], [false, "OFF", true],
		[true, 2.0, false], [true, "nope", true],
		[4, 4.0, 0], [1, true, 0], [12, "  12 ", 0], [0, "1.5", 0], [7, NAN, 7],
		[2.0, 2, 0.0], [-2.5, "-2.5", 0.0], [0.25, "fast", 0.25], [0.25, INF, 0.25],
		["abc", &"abc", ""], ["", 12, ""], [&"x", "x", &""],
		[Vector2(1, 2), Vector2i(1, 2), Vector2.ZERO], [Vector2i(1, 2), Vector2(1.9, 2.0), Vector2i.ZERO],
		[{}, ["a"], {}], [[], {"a": 1}, []],
	]
	for row in cases:
		var expected: Variant = row[0]
		var got: Variant = Settings.coerce(row[1], row[2])
		assert_eq(typeof(got), typeof(row[2]), "%s for a %s default" % [str(row[1]), type_string(typeof(row[2]))])
		assert_eq(got, expected, "%s for a %s default" % [str(row[1]), type_string(typeof(row[2]))])

