extends GutTest
## THE NINTH RULES FORK (the owner's ruling of 2026-10-13):
## RulesOptions.sacrifice_clauses_wait, Options › Rules "Forced sacrifices
## wait on the chain".
##
## Its modern answer is ON (the modern Oracle's state trigger, CR 603.8) and
## its 1997 answer OFF (the printings' "Bury ... if at any time"), but BOTH
## modern presets carry it as an exception at OFF — "leave it as is" under
## every preset — so the default changes nothing, every preset still reads
## by its name, and switching it on is a "Custom" mix. It reaches the
## Options row, Help's rules page, the duel's opening screen and the LAN
## table rules like every other implemented fork; a settings file or a
## remembered LAN table from an older build needs nothing written for it,
## because every preset answers it the same as the player default.

const KEY := "sacrifice_clauses_wait"
const OLDER_FORKS := ["mana_burn", "attackers_revocable",
	"tapped_artifacts_stop", "life_checked_at_phase_end",
	"pool_empties_on_attack", "free_damage_assignment",
	"damage_prevention_window"]

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


static func _fork() -> Dictionary:
	for fork in RulesOptions.FORKS:
		if fork["key"] == KEY:
			return fork
	return {}


# ================================================================ the fork ==

func test_the_fork_is_implemented_with_its_two_answers() -> void:
	var fork := _fork()
	assert_false(fork.is_empty(), "a fork")
	assert_true(RulesOptions.IMPLEMENTED.has(KEY), "and a live one")
	assert_eq(RulesOptions.FORKS.back()["key"], KEY, "the ninth row, after the eighth")
	assert_false(bool(fork["fifth_value"]), "1997: checked at once")
	assert_true(RulesOptions.modern_answer(fork), "modern: a state trigger on the stack")
	assert_eq(String(fork["label"]), "Forced sacrifices wait on the chain")
	assert_string_contains(String(fork["fifth"]), "Pirate Ship")
	assert_string_contains(String(fork["modern"]), "Pirate Ship")
	assert_string_contains(String(fork["modern"]), "one more use")
	for text in [String(fork["fifth"]), String(fork["modern"]), String(fork["label"])]:
		assert_false(text.contains("CR "), "no rules citation in player text: " + text)
		assert_false(text.contains("docs/"), text)
	assert_string_contains(String(fork["source"]), "603.8", "the citation lives in the source")


func test_every_preset_keeps_it_off_and_still_reads_by_name() -> void:
	for entry in RulesOptions.PRESETS:
		var rules := RulesOptions.new()
		rules.set_preset(entry["id"])
		assert_false(rules.sacrifice_clauses_wait, "%s keeps the 1997 answer" % entry["id"])
		assert_eq(rules.preset(), entry["id"], "and reads as itself")
		rules.sacrifice_clauses_wait = true
		assert_eq(rules.preset(), "custom", "%s with it on is a custom mix" % entry["id"])
		assert_eq(RulesOptions.preset_label(rules.preset()), "Custom")
	assert_eq(RulesOptions.new().preset(), "modern", "a fresh engine still reads Modern rules")
	assert_false(RulesOptions.new().sacrifice_clauses_wait)
	var stale := RulesOptions.new()
	stale.set_preset("no such preset")
	assert_eq(stale.preset(), "modern", "a stale preset name is the Modern rules preset")
	assert_false(stale.sacrifice_clauses_wait, "with its exception, not the bare edition")


func test_the_modern_edition_itself_waits() -> void:
	# set_edition is an edition's answers WITHOUT a preset's exceptions:
	# modern Magic waits, and that mix has no name.
	var rules := RulesOptions.new()
	rules.set_edition("modern")
	assert_true(rules.sacrifice_clauses_wait)
	assert_eq(rules.preset(), "custom")
	rules.set_edition("fifth")
	assert_false(rules.sacrifice_clauses_wait)
	assert_eq(rules.preset(), "fifth")


# ============================================================ the settings ==

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


static func _live() -> RulesOptions:
	var live := RulesOptions.new()
	for fork in RulesOptions.FORKS:
		live.set_fork(fork["key"], Settings.rule(fork["key"]))
	return live


## What a preset wrote under an older build: [param keys] only.
static func _older_file(preset: String, revision: int, keys: Array) -> Dictionary:
	var options := RulesOptions.new()
	options.set_preset(preset)
	var stored := {Settings.RULES_REVISION_KEY: revision}
	for key: String in keys:
		stored["rule_" + key] = options.get_fork(key)
	return stored


func test_the_player_default_is_off() -> void:
	_boot_with({"music_volume_db": -6.0})
	assert_false(Settings.rule(KEY))
	assert_null(_on_disk("rule_" + KEY), "reading a default writes nothing")
	assert_eq(_live().preset(), RulesOptions.DEFAULT_PRESET)


func test_a_ruleset_saved_by_an_older_build_keeps_its_preset() -> void:
	# 0.50.20 stored seven forks (revision 2); a 0.50.21 build before this
	# fork stored eight (revision 3). Neither knew this one; every preset
	# answers it OFF, which is also the player default, so the preset reads
	# back by its name and nothing is written for it.
	var older := [[2, OLDER_FORKS], [3, OLDER_FORKS + ["damage_effects_fixed_order"]]]
	for row in older:
		for preset in ["modern", "modern_mana_burn", "fifth"]:
			_boot_with(_older_file(preset, int(row[0]), row[1]))
			assert_false(Settings.rule(KEY), "%s/r%d: off" % [preset, row[0]])
			assert_eq(_live().preset(), preset, "%s/r%d: the Options screen still names it" % [preset, row[0]])
			assert_null(_on_disk("rule_" + KEY), "%s/r%d: nothing written for it" % [preset, row[0]])


func test_a_stored_answer_is_the_player_s() -> void:
	var stored := _older_file("fifth", Settings.RULES_REVISION,
		OLDER_FORKS + ["damage_effects_fixed_order"])
	stored["rule_" + KEY] = true
	_boot_with(stored)
	assert_true(Settings.rule(KEY))
	assert_eq(_live().preset(), "custom")


# ======================================================== the LAN table ==

func test_the_lan_table_carries_the_fork() -> void:
	var standard := SgTableRules.standard()
	assert_true(standard.forks.has(KEY))
	assert_false(standard.forks[KEY], "the standard table checks at once")
	assert_true(SgDuelPresentation.RULES.has(KEY), "every seat's view carries it")
	var custom := SgTableRules.standard()
	custom.forks[KEY] = true
	assert_true(SgTableRules.valid(custom))
	assert_eq(SgTableRules.brief(custom), "Custom  ·  20 life")
	assert_string_contains(SgTableRules.summary(custom), "Forced sacrifices wait on the chain: on")
	var game := MtgGame.new()
	SgTableRules.apply(game, custom)
	assert_true(game.rules.sacrifice_clauses_wait, "the referee's game plays it")


func test_a_remembered_older_table_keeps_its_preset() -> void:
	for preset in ["modern", "modern_mana_burn", "fifth"]:
		var options := RulesOptions.new()
		options.set_preset(preset)
		var older := SgTableRules.from_options(30, options)
		older.forks.erase(KEY)
		older.forks.erase("damage_effects_fixed_order")
		assert_false(SgTableRules.valid(older), "an older build's table is not this build's shape")
		var upgraded: Dictionary = SgTableRules.upgraded(older)
		assert_true(SgTableRules.valid(upgraded), preset)
		assert_false(upgraded.forks[KEY], preset)
		assert_eq(SgTableRules.preset_label(upgraded), RulesOptions.preset_label(preset))


# ======================================================= the screens ==

func test_help_s_rules_page_explains_it() -> void:
	var text := ""
	for page: Dictionary in HelpPages.pages():
		if String(page.get("title", "")) != "Which rules this game plays by":
			continue
		for block: Dictionary in page["blocks"]:
			text += String(block.get("text", "")) + "\n"
	assert_string_contains(text, "Forced sacrifices wait on the chain")
	assert_string_contains(text, "one more use")


func test_the_options_row_flips_the_readout_to_custom_and_back() -> void:
	var saved := {}
	for fork in RulesOptions.FORKS:
		var key: String = "rule_" + fork["key"]
		saved[key] = Settings.get_value(key, null) if Settings.has_value(key) else null
		Settings.clear_value(key)
	var screen: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var row: CheckButton = null
	var preset: OptionButton = null
	var stack: Array[Node] = [screen]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CheckButton and node.text == "Forced sacrifices wait on the chain":
			row = node
		elif node is OptionButton and node.item_count == RulesOptions.PRESETS.size() + 1:
			preset = node
		stack.append_array(node.get_children())
	assert_not_null(row, "the Options row")
	assert_not_null(preset)
	assert_false(row.disabled, "switchable")
	assert_false(row.button_pressed, "off by default")
	assert_eq(preset.get_item_text(preset.selected), "Modern rules, mana burn on")
	row.button_pressed = true
	assert_true(Settings.rule(KEY))
	assert_eq(preset.get_item_text(preset.selected), "Custom")
	row.button_pressed = false
	assert_eq(preset.get_item_text(preset.selected), "Modern rules, mana burn on", "and back")
	for key in saved:
		if saved[key] == null:
			Settings.clear_value(key)
		else:
			Settings.set_value(key, saved[key])
