extends GutTest
## A RULESET SAVED BEFORE THE EIGHTH FORK (campaign 2026-10-12 f-order).
##
## `RulesOptions.damage_effects_fixed_order` (the owner's ruling of
## 2026-10-12) is a new Options row, settings key and LAN table field. A
## player who saved "1997 — Fifth Edition" with an older build has the
## other seven forks stored and this one not, so it read the player default
## — the modern answer — and the Options screen called their rules
## "Custom" while the 1997 game they chose asked them about damage order.
## Settings._migrate_rules (revision 3) gives a file whose other forks
## match a preset that preset's answer; SgTableRules.upgraded does the same
## for the host's remembered LAN table. A custom mix keeps the default.

const NEW := "damage_effects_fixed_order"

var _path: String
var _existed := false
var _backup := PackedByteArray()
var _had_table := false
var _saved_table: Variant


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


static func _on_disk(key: String) -> Variant:
	var file := ConfigFile.new()
	file.load(Settings.PATH)
	if not file.has_section_key("options", key):
		return null
	return file.get_value("options", key)


## What an older build's preset wrote: every fork but the new one.
static func _older_file(preset: String, revision: int) -> Dictionary:
	var options := RulesOptions.new()
	options.set_preset(preset)
	var stored := {Settings.RULES_REVISION_KEY: revision}
	for fork in RulesOptions.FORKS:
		if fork["key"] != NEW:
			stored["rule_" + fork["key"]] = options.get_fork(fork["key"])
	return stored


static func _live() -> RulesOptions:
	var live := RulesOptions.new()
	for fork in RulesOptions.FORKS:
		live.set_fork(fork["key"], Settings.rule(fork["key"]))
	return live


func test_a_saved_1997_preset_stays_the_1997_preset() -> void:
	for revision in [1, 2]:
		_boot_with(_older_file("fifth", revision))
		assert_true(Settings.rule(NEW), "revision %d: the 1997 answer — nobody is asked" % revision)
		assert_eq(_on_disk("rule_" + NEW), true, "and the file says so")
		assert_eq(_on_disk(Settings.RULES_REVISION_KEY), Settings.RULES_REVISION)
		assert_eq(_live().preset(), "fifth", "the Options screen still names the preset")


func test_a_saved_modern_preset_needs_nothing_written() -> void:
	for preset in ["modern", "modern_mana_burn"]:
		_boot_with(_older_file(preset, 2))
		assert_false(Settings.rule(NEW), "%s: the affected one is asked" % preset)
		assert_null(_on_disk("rule_" + NEW), "%s: the default already says so" % preset)
		assert_eq(_live().preset(), preset)


func test_a_custom_mix_keeps_the_player_default() -> void:
	var stored := _older_file("fifth", 2)
	stored["rule_mana_burn"] = false
	_boot_with(stored)
	assert_false(Settings.rule(NEW), "a custom mix: the player default")
	assert_null(_on_disk("rule_" + NEW))
	assert_eq(_on_disk(Settings.RULES_REVISION_KEY), Settings.RULES_REVISION, "looked at once")


func test_a_stored_answer_is_the_player_s() -> void:
	var stored := _older_file("fifth", 2)
	stored["rule_" + NEW] = false
	_boot_with(stored)
	assert_false(Settings.rule(NEW), "the player chose to be asked")
	assert_eq(_live().preset(), "custom")


func test_a_marked_file_and_an_empty_one_are_not_touched() -> void:
	_boot_with(_older_file("fifth", Settings.RULES_REVISION))
	assert_false(Settings.rule(NEW), "already looked at: not again")
	_boot_with({"music_volume_db": -6.0})
	var writes := Settings.write_count
	Settings.reload_file()
	assert_eq(Settings.write_count, writes, "nothing stored, nothing written")
	assert_null(_on_disk(Settings.RULES_REVISION_KEY))


func test_the_preset_matching_reads_only_the_forks_it_is_given() -> void:
	var fifth := RulesOptions.new()
	fifth.set_preset("fifth")
	var known := {}
	for key: String in RulesOptions.IMPLEMENTED:
		if key != NEW: known[key] = fifth.get_fork(key)
	assert_eq(RulesOptions.preset_matching(known), "fifth")
	known["mana_burn"] = false
	assert_eq(RulesOptions.preset_matching(known), "")
	assert_eq(RulesOptions.preset_matching({"mana_burn": false}), "modern", "the first preset that fits")


# ================================================ the remembered LAN table ==

func test_a_remembered_1997_table_keeps_its_name() -> void:
	var fifth := RulesOptions.new()
	fifth.set_preset("fifth")
	var older := SgTableRules.from_options(30, fifth)
	older.forks.erase(NEW)
	assert_false(SgTableRules.valid(older), "an older build's table is not this build's shape")
	var upgraded: Dictionary = SgTableRules.upgraded(older)
	assert_true(SgTableRules.valid(upgraded))
	assert_eq(upgraded.forks.keys(), Array(RulesOptions.IMPLEMENTED), "in the wire's order")
	assert_true(upgraded.forks[NEW])
	assert_eq(SgTableRules.preset_label(upgraded), "1997 — Fifth Edition")
	assert_eq(int(upgraded.life), 30)
	# Through the host page's own reader.
	_had_table = Settings.has_value(SgTableRulesSetup.KEY)
	_saved_table = Settings.get_value(SgTableRulesSetup.KEY, null)
	Settings.set_value(SgTableRulesSetup.KEY, older)
	var remembered := SgTableRulesSetup.remembered()
	assert_eq(SgTableRules.brief(remembered), "1997 — Fifth Edition  ·  30 life")
	if _had_table:
		Settings.set_value(SgTableRulesSetup.KEY, _saved_table)
	else:
		Settings.clear_value(SgTableRulesSetup.KEY)


## Each seat's view of a LAN duel carries the table's forks
## (`SgDuelPresentation.RULES`), and the guest's projection and its duel
## opening read them from there. It was a hand-kept copy of the first
## seven, so a guest at a 1997 table saw this fork Off.
func test_every_seat_s_view_carries_every_implemented_fork() -> void:
	assert_eq(Array(SgDuelPresentation.RULES), Array(RulesOptions.IMPLEMENTED))
	assert_true(SgDuelPresentation.RULES.has(NEW))


func test_a_remembered_custom_table_takes_the_standard_answer() -> void:
	var custom := SgTableRules.standard()
	custom.forks.damage_prevention_window = true
	custom.forks.erase(NEW)
	var upgraded: Dictionary = SgTableRules.upgraded(custom)
	assert_true(SgTableRules.valid(upgraded))
	assert_false(upgraded.forks[NEW], "the standard table's answer")
	assert_true(upgraded.forks.damage_prevention_window, "the host's own choice kept")
	# A table this build wrote, or one it cannot read, is left to normalize.
	var standard := SgTableRules.standard()
	assert_eq(SgTableRules.upgraded(standard), standard)
	var stranger := {"life": 20, "forks": {"ante": true}}
	assert_eq(SgTableRules.upgraded(stranger), stranger)
	assert_eq(SgTableRules.normalize(SgTableRules.upgraded(stranger)), standard)
