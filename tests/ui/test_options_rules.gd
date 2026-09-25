extends GutTest
## The Options screen's RULES section: the 1997 (Fifth Edition) forks, the
## preset that flips them together, and the rule that a fork with no
## implementation behind it is shown DISABLED rather than offered as a
## switch that does nothing.


var screen: Control
var _saved := {}


func before_each() -> void:
	# The real settings file must not be written by a test.
	for fork in RulesOptions.FORKS:
		var key: String = "rule_" + fork["key"]
		_saved[key] = Settings.get_value(key, null) if Settings.has_value(key) else null
		Settings.clear_value(key)
	screen = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	for key in _saved:
		if _saved[key] == null:
			Settings.clear_value(key)
		else:
			Settings.set_value(key, _saved[key])


func _rows() -> Dictionary:
	var found := {}
	for node in _walk(screen):
		if node is CheckButton:
			found[node.text] = node
	return found


func _walk(node: Node) -> Array:
	var out := [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out


func test_every_fork_has_a_row() -> void:
	var rows := _rows()
	for fork in RulesOptions.FORKS:
		assert_true(rows.has(fork["label"]),
			"%s is on the Options screen" % fork["key"])


func test_unimplemented_forks_are_disabled() -> void:
	var rows := _rows()
	for fork in RulesOptions.FORKS:
		var row: CheckButton = rows[fork["label"]]
		var live: bool = RulesOptions.IMPLEMENTED.has(fork["key"])
		assert_eq(row.disabled, not live,
			"%s is %s" % [fork["key"], "switchable" if live else "greyed out"])


func test_the_live_forks_are_switchable() -> void:
	assert_eq(RulesOptions.IMPLEMENTED.size(), 7)
	var rows := _rows()
	assert_false(rows["Mana burn"].disabled, "mana burn really works")
	assert_false(rows["Attacker selection revocable"].disabled,
		"and so does revocable attackers")
	assert_false(rows["Free combat damage division"].disabled,
		"and the 1997 damage division (docs/duel-todo.md §1.4)")


func test_each_row_explains_both_editions_without_developer_sources() -> void:
	var rows := _rows()
	for fork in RulesOptions.FORKS:
		var tip: String = rows[fork["label"]].tooltip_text
		assert_string_contains(tip, "1997:")
		assert_string_contains(tip, "Modern:")
		assert_false(tip.contains("Source:"))
		assert_false(tip.contains("docs/"))


func test_player_defaults_enable_mana_burn_and_revocable_attackers() -> void:
	var rows := _rows()
	assert_true(rows["Mana burn"].button_pressed, "mana burn on for a fresh player")
	assert_false(Settings.has_value("rule_mana_burn"), "reading a default does not save it")
	assert_true(rows["Attacker selection revocable"].button_pressed,
		"attackers stay revocable by default — the owner's call")


func test_saved_mana_burn_off_overrides_the_player_default() -> void:
	Settings.set_rule("mana_burn", false)
	assert_false(Settings.rule("mana_burn"))
	assert_false(RulesOptions.new().mana_burn, "engine's modern preset is unchanged")


# ================================ the preset writes the file ONCE ==
#
# `Modern rules` / `1997 — Fifth Edition` flips every fork in one
# gesture. Until 2026-09-02 the loop called `Settings.set_rule` with the
# default `persist`, so one click rewrote `user://settings.cfg` seven
# times — the sliders' bug (`test_options_sliders.gd`) in another
# widget. Now each fork is set in memory and `Settings.flush` writes once.


func _preset() -> OptionButton:
	for node in _walk(screen):
		if node is OptionButton \
				and node.item_count == RulesOptions.PRESETS.size() + 1 \
				and node.get_item_text(node.item_count - 1) == RulesOptions.CUSTOM_LABEL:
			return node
	return null


## The preset box's row for a preset id.
func _row_of(id: String) -> int:
	for index in RulesOptions.PRESETS.size():
		if RulesOptions.PRESETS[index]["id"] == id:
			return index
	return -1


func test_the_preset_writes_the_settings_file_once() -> void:
	var preset := _preset()
	assert_not_null(preset, "the rules preset is an OptionButton with a Custom readout")
	Settings.flush()
	var before: int = Settings.write_count
	preset.item_selected.emit(_row_of("fifth"))          # 1997 — Fifth Edition
	assert_eq(Settings.write_count - before, 1,
		"seven forks, ONE write — not one per fork")
	assert_false(Settings.is_dirty(), "and nothing is left waiting")
	# The gesture did what it says: every fork now reads the 1997 way.
	for fork in RulesOptions.FORKS:
		assert_eq(Settings.rule(fork["key"]), fork["fifth_value"], fork["key"])
	before = Settings.write_count
	preset.item_selected.emit(_row_of("modern"))          # Modern rules
	assert_eq(Settings.write_count - before, 1, "and back, in one write")
	for fork in RulesOptions.FORKS:
		assert_eq(Settings.rule(fork["key"]), RulesOptions.modern_answer(fork), fork["key"])


func test_the_custom_readout_is_not_a_command() -> void:
	var preset := _preset()
	Settings.flush()
	var before: int = Settings.write_count
	preset.item_selected.emit(RulesOptions.PRESETS.size())          # Custom
	assert_eq(Settings.write_count, before, "selecting the readout writes nothing")


# ============================== the named default, and "Custom" ==
#
# Since 2026-09-13 a fresh player's flags are modern with mana burn ON,
# and until 2026-09-25 the box read "Custom" for a player who had chosen
# nothing. The owner's word: that one mix is a preset with a name of its
# own, and *"all other mix and match should be custom"*.


func test_a_fresh_player_reads_the_named_default_not_custom() -> void:
	var preset := _preset()
	assert_eq(preset.selected, _row_of("modern_mana_burn"))
	assert_eq(preset.get_item_text(preset.selected), "Modern rules, mana burn on")
	assert_ne(preset.get_item_text(preset.selected), RulesOptions.CUSTOM_LABEL)
	# The box shows the four rows in RulesOptions' order, the readout last.
	var labels: Array = []
	for index in preset.item_count:
		labels.append(preset.get_item_text(index))
	assert_eq(labels, ["Modern rules", "Modern rules, mana burn on",
		"1997 — Fifth Edition", "Custom"])


func test_choosing_the_named_default_writes_once_and_burns_mana() -> void:
	var preset := _preset()
	preset.item_selected.emit(_row_of("modern"))
	assert_false(Settings.rule("mana_burn"), "plain modern turns the burn off")
	Settings.flush()
	var before: int = Settings.write_count
	preset.item_selected.emit(_row_of("modern_mana_burn"))
	assert_eq(Settings.write_count - before, 1, "seven forks, ONE write")
	assert_true(Settings.rule("mana_burn"))
	for fork in RulesOptions.FORKS:
		if fork["key"] != "mana_burn":
			assert_eq(Settings.rule(fork["key"]), RulesOptions.modern_answer(fork), fork["key"])
	assert_true(_rows()["Mana burn"].button_pressed, "and the row shows it")


func test_one_more_flip_reads_custom_and_flipping_back_reads_the_name() -> void:
	var preset := _preset()
	var rows := _rows()
	assert_eq(preset.selected, _row_of("modern_mana_burn"))
	rows["Tapped artifacts stop working"].button_pressed = true
	assert_eq(preset.get_item_text(preset.selected), "Custom",
		"mana burn plus one more 1997 answer is a custom mix")
	rows["Tapped artifacts stop working"].button_pressed = false
	assert_eq(preset.selected, _row_of("modern_mana_burn"), "and back")
	rows["Mana burn"].button_pressed = false
	assert_eq(preset.selected, _row_of("modern"), "no burn at all is plain modern")
