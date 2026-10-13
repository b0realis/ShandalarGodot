extends GutTest
## A RULE CHOSEN ON A FRESH PROFILE IS THE PLAYER'S (repository check
## 2026-10-13, finding c1-2).
##
## Settings._migrate_rules looks at a settings file once and marks it with
## `rules_revision`. A file with no rules fork stored has nothing to look
## at, and it used to leave without the marker — so the first rule a
## player set on this build was read, at the next start, as a file from an
## older build and run through the old files' migrations: "Free damage
## assignment" turned off came back on (revision 2), and a row left at the
## player default in an otherwise 1997 mix was rewritten to the 1997 answer
## (revision 3). The marker now goes into memory at that first look, so the
## first save carries it; nothing is written at the start itself.

var _path: String
var _existed := false
var _backup := PackedByteArray()


func before_each() -> void:
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
	Settings.reload_file()


func _boot_with(values: Dictionary) -> void:
	var file := ConfigFile.new()
	for key in values:
		file.set_value("options", key, values[key])
	assert_eq(file.save(Settings.PATH), OK)
	Settings.reload_file()


## A first start: no settings file at all.
func _boot_without_a_file() -> void:
	if FileAccess.file_exists(Settings.PATH):
		assert_eq(DirAccess.remove_absolute(_path), OK)
	Settings.reload_file()


static func _on_disk(key: String) -> Variant:
	var file := ConfigFile.new()
	file.load(Settings.PATH)
	if not file.has_section_key("options", key):
		return null
	return file.get_value("options", key)


## The probe's first case: some other setting stored, no rule. The player
## turns "Free damage assignment" off on the Options screen (one row,
## written at once). The next start keeps it off.
func test_a_rule_set_on_a_fresh_profile_survives_the_next_start() -> void:
	_boot_with({"music_volume_db": -6.0})
	assert_true(Settings.rule("free_damage_assignment"), "control: the default is on")
	Settings.set_rule("free_damage_assignment", false)
	assert_eq(_on_disk(Settings.RULES_REVISION_KEY), Settings.RULES_REVISION,
		"the first save carries the marker")
	Settings.reload_file()   # the next start
	assert_false(Settings.rule("free_damage_assignment"),
		"the player's own choice, made on this build, stays at the next start")
	assert_eq(_on_disk("rule_free_damage_assignment"), false)


## The same on a first start with no settings file at all.
func test_a_rule_set_on_a_first_start_survives_the_next_start() -> void:
	_boot_without_a_file()
	Settings.set_rule("free_damage_assignment", false)
	Settings.reload_file()
	assert_false(Settings.rule("free_damage_assignment"),
		"a first start's choice stays at the next start")


## The probe's second case: every fork set row by row to its 1997 answer
## EXCEPT "Fixed order for damage effects" (1997 rules, but asked about the
## order). The next start leaves that row alone.
func test_a_custom_mix_built_row_by_row_stays_custom() -> void:
	_boot_with({"music_volume_db": -6.0})
	var fifth := RulesOptions.new()
	fifth.set_preset("fifth")
	for key: String in RulesOptions.IMPLEMENTED:
		if key == "damage_effects_fixed_order":
			continue
		if Settings.rule(key) != fifth.get_fork(key):
			Settings.set_rule(key, fifth.get_fork(key))
	assert_false(Settings.rule("damage_effects_fixed_order"), "control: left at the player default (asked)")
	Settings.reload_file()   # the next start
	assert_false(Settings.rule("damage_effects_fixed_order"),
		"a row the player never touched keeps the player default at the next start")
	assert_null(_on_disk("rule_damage_effects_fixed_order"), "and nothing was written for it")
	for key: String in RulesOptions.IMPLEMENTED:
		if key != "damage_effects_fixed_order":
			assert_eq(Settings.rule(key), fifth.get_fork(key), key + " keeps its 1997 answer")


## Nothing is written at the start itself: a file with no rule stored is
## left exactly as it was until the player saves something.
func test_the_start_itself_writes_nothing() -> void:
	_boot_with({"music_volume_db": -6.0})
	var bytes := FileAccess.get_file_as_bytes(Settings.PATH)
	var writes := Settings.write_count
	Settings.reload_file()
	assert_eq(Settings.write_count, writes, "no write at the start")
	assert_eq(FileAccess.get_file_as_bytes(Settings.PATH), bytes, "the file is as it was")
	assert_null(_on_disk(Settings.RULES_REVISION_KEY))


## The older builds' files are still looked at: a revision-1 file whose
## stored forks all read the old modern answers still moves with the preset
## (the revision-2 migration), so the marker in memory did not stop it.
func test_an_older_file_is_still_migrated() -> void:
	_boot_with({"rule_free_damage_assignment": false})
	assert_true(Settings.rule("free_damage_assignment"), "the old preset's false moves with the preset")
	assert_eq(_on_disk(Settings.RULES_REVISION_KEY), Settings.RULES_REVISION, "and the file is marked")
