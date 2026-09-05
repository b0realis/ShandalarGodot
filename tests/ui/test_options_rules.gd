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


func test_each_row_explains_both_editions_and_cites_a_source() -> void:
	var rows := _rows()
	for fork in RulesOptions.FORKS:
		var tip: String = rows[fork["label"]].tooltip_text
		assert_string_contains(tip, "1997:")
		assert_string_contains(tip, "Modern:")
		assert_string_contains(tip, fork["source"])


func test_defaults_are_modern_except_the_owners_call_on_attackers() -> void:
	var rows := _rows()
	assert_false(rows["Mana burn"].button_pressed, "modern by default")
	assert_true(rows["Attacker selection revocable"].button_pressed,
		"attackers stay revocable by default — the owner's call")


# ================================ the preset writes the file ONCE ==
#
# `Modern rules` / `1997 — Fifth Edition` flips every fork in one
# gesture. Until 2026-09-02 the loop called `Settings.set_rule` with the
# default `persist`, so one click rewrote `user://settings.cfg` seven
# times — the sliders' bug (`test_options_sliders.gd`) in another
# widget. Now each fork is set in memory and `Settings.flush` writes once.


func _preset() -> OptionButton:
	for node in _walk(screen):
		if node is OptionButton and node.item_count == 3 \
				and node.get_item_text(2) == "Custom":
			return node
	return null


func test_the_preset_writes_the_settings_file_once() -> void:
	var preset := _preset()
	assert_not_null(preset, "the rules preset is an OptionButton with a Custom readout")
	Settings.flush()
	var before: int = Settings.write_count
	preset.item_selected.emit(1)          # 1997 — Fifth Edition
	assert_eq(Settings.write_count - before, 1,
		"seven forks, ONE write — not one per fork")
	assert_false(Settings.is_dirty(), "and nothing is left waiting")
	# The gesture did what it says: every fork now reads the 1997 way.
	for fork in RulesOptions.FORKS:
		assert_eq(Settings.rule(fork["key"]), fork["fifth_value"], fork["key"])
	before = Settings.write_count
	preset.item_selected.emit(0)          # Modern rules
	assert_eq(Settings.write_count - before, 1, "and back, in one write")
	for fork in RulesOptions.FORKS:
		assert_eq(Settings.rule(fork["key"]), not fork["fifth_value"], fork["key"])


func test_the_custom_readout_is_not_a_command() -> void:
	var preset := _preset()
	Settings.flush()
	var before: int = Settings.write_count
	preset.item_selected.emit(2)          # Custom
	assert_eq(Settings.write_count, before, "selecting the readout writes nothing")
