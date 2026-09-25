extends GutTest
## Settings._migrate_rules: the one fork whose MODERN answer moved.
##
## Free combat damage division was the 1997 answer and, since Foundations
## (November 2024), the modern one too; builds before 2026-09-18 had the
## "Modern rules" preset write `rule_free_damage_assignment = false` (the
## 2009-2024 order). Left in the file, that false would keep the order in
## force and show the preset as "Custom" for a player who never chose it.
## So the file is looked at ONCE (a revision marker): if every stored fork
## reads modern, the false was the preset's and moves with the preset; a
## mixed file is a custom choice and is left alone; a file that never
## stored the fork is not written at all.

var _path: String
var _existed := false
var _backup := PackedByteArray()


func before_each() -> void:
	# The suite profile's settings file is shared: copy it out byte for
	# byte and put it back, whatever the test wrote.
	Settings.flush()
	_path = ProjectSettings.globalize_path(Settings.PATH)
	_existed = FileAccess.file_exists(_path)
	if _existed:
		_backup = FileAccess.get_file_as_bytes(_path)


func after_each() -> void:
	if _existed:
		var file := FileAccess.open(_path, FileAccess.WRITE)
		file.store_buffer(_backup)
		file.close()
	elif FileAccess.file_exists(_path):
		DirAccess.remove_absolute(_path)
	Settings.reload()


## Put exactly these keys in the file and read it as a fresh boot would.
func _boot_with(values: Dictionary) -> void:
	var file := ConfigFile.new()
	for key in values:
		file.set_value("options", key, values[key])
	assert_eq(file.save(Settings.PATH), OK)
	Settings.reload()


static func _on_disk(key: String) -> Variant:
	var file := ConfigFile.new()
	file.load(Settings.PATH)
	if not file.has_section_key("options", key):
		return null
	return file.get_value("options", key)


func test_an_older_modern_preset_file_moves_with_the_preset() -> void:
	# What the old "Modern rules" preset wrote: every fork's old modern
	# answer, the division order included.
	var stored := {}
	for fork in RulesOptions.FORKS:
		stored["rule_" + fork["key"]] = not bool(fork["fifth_value"])
	assert_false(stored["rule_free_damage_assignment"], "the old modern answer")
	_boot_with(stored)
	assert_true(Settings.rule("free_damage_assignment"), "the division is free again")
	assert_eq(_on_disk("rule_free_damage_assignment"), true, "and the file says so")
	assert_eq(_on_disk(Settings.RULES_REVISION_KEY), Settings.RULES_REVISION)
	var live := RulesOptions.new()
	for fork in RulesOptions.FORKS:
		live.set_fork(fork["key"], Settings.rule(fork["key"]))
	assert_eq(live.preset(), "modern", "the Options preset still reads Modern")


func test_a_file_with_only_the_one_fork_stored_is_the_presets_too() -> void:
	# A player who never touched the other switches: nothing stored for
	# them means the built-in modern answer, so the false is the preset's.
	_boot_with({"rule_free_damage_assignment": false})
	assert_true(Settings.rule("free_damage_assignment"))
	assert_eq(_on_disk(Settings.RULES_REVISION_KEY), Settings.RULES_REVISION)


func test_a_mixed_file_is_a_custom_choice_and_is_left_alone() -> void:
	# Mana burn on is the 1997 answer; with the order also on this player
	# built their own ruleset, and the order stays theirs.
	_boot_with({"rule_free_damage_assignment": false, "rule_mana_burn": true})
	assert_false(Settings.rule("free_damage_assignment"), "a custom choice keeps")
	assert_eq(_on_disk("rule_free_damage_assignment"), false)
	assert_eq(_on_disk(Settings.RULES_REVISION_KEY), Settings.RULES_REVISION,
		"looked at once, all the same")


func test_the_1997_preset_file_needs_nothing_but_the_marker() -> void:
	var stored := {}
	for fork in RulesOptions.FORKS:
		stored["rule_" + fork["key"]] = bool(fork["fifth_value"])
	_boot_with(stored)
	for fork in RulesOptions.FORKS:
		assert_eq(Settings.rule(fork["key"]), bool(fork["fifth_value"]), fork["key"])
	assert_eq(_on_disk(Settings.RULES_REVISION_KEY), Settings.RULES_REVISION)


func test_a_file_without_the_fork_is_not_written() -> void:
	_boot_with({"music_volume_db": -6.0})
	var writes := Settings.write_count
	Settings.reload()
	assert_eq(Settings.write_count, writes, "nothing to migrate, nothing written")
	assert_null(_on_disk(Settings.RULES_REVISION_KEY))
	assert_true(Settings.rule("free_damage_assignment"), "the built-in default")


func test_a_marked_file_is_not_looked_at_again() -> void:
	# After the migration the player switched the 2009-2024 order back on
	# from an all-modern file: that is their choice now, and a later boot
	# must not "correct" it a second time.
	_boot_with({"rule_free_damage_assignment": false,
		Settings.RULES_REVISION_KEY: Settings.RULES_REVISION})
	assert_false(Settings.rule("free_damage_assignment"))
	assert_eq(_on_disk("rule_free_damage_assignment"), false)
