extends GutTest
## TARGETS AND X IN THE DUEL LOG (the polish pass, 2026-10-28; P3 item 2 —
## the owner, round "open items": *"targets and X in the log"*).
##
## The engine's sentence for a cast is `"%s casts %s"` and for an
## activation `"%s activates %s: %s"` — no targets and no X (the SIMPLIFIED
## marker in [method MtgGame.cast_spell], `docs/duel-todo.md` §3.9). A
## trigger's already names them: `"... (targeting Serra Angel)"`. The
## engine's own log is the audit trail every engine test reads, so it
## keeps its words; the READERS — the log window, the running
## `duel_log.txt` and the Spell Chain's tooltips — add the same
## parenthesis to a cast and an activation, from the chain object the line
## was written for ([method DuelLogText.details]): `(X=3, targeting Serra
## Angel)`. A switch in the duel screen's own options
## ([constant DuelScreenOptions.LOG_TARGETS_KEY]), on by default.

var screen: DuelScreen
var _saved: Variant = null
var _had := false


func before_each() -> void:
	_had = Settings.has_value(DuelScreenOptions.LOG_TARGETS_KEY)
	_saved = Settings.get_value(DuelScreenOptions.LOG_TARGETS_KEY, null) if _had else null
	Settings.clear_value(DuelScreenOptions.LOG_TARGETS_KEY)


func after_each() -> void:
	if _had:
		Settings.set_value(DuelScreenOptions.LOG_TARGETS_KEY, _saved)
	else:
		Settings.clear_value(DuelScreenOptions.LOG_TARGETS_KEY)
	DuelLogFile.location = ""
	await get_tree().process_frame


func _test_duel() -> MtgGame:
	var position := DuelPosition.new()
	for n in ["Mountain", "Mountain", "Mountain", "Mountain", "Mountain", "Prodigal Sorcerer"]:
		position.add(0, DuelPosition.TABLE, n)
	position.add(1, DuelPosition.TABLE, "Serra Angel")
	position.add(0, DuelPosition.HAND, "Lightning Bolt")
	position.add(0, DuelPosition.HAND, "Fireball")
	position.active_player = 0
	position.step = Mtg.Step.MAIN1
	var config := DuelConfig.hotseat_default().for_test(position, 777)
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	return screen.game


func _in(g: MtgGame, pid: int, card_name: String, hand := true) -> CardInstance:
	for inst in (g.players[pid].hand if hand else g.players[pid].battlefield):
		if inst.data.card_name == card_name:
			return inst
	fail_test("no %s" % card_name)
	return null


func test_the_switch_is_on_by_default() -> void:
	assert_true(DuelScreenOptions.log_targets(), "the owner asked for it")


func test_a_cast_names_its_target_in_the_window() -> void:
	var g := await _test_duel()
	var angel := _in(g, 1, "Serra Angel", false)
	g.players[0].mana_pool.add(Mtg.ManaColor.R, 1)
	assert_eq(g.cast_spell(0, _in(g, 0, "Lightning Bolt"), [TargetRef.card(angel)]), "")
	assert_true(g.log_lines[-1].ends_with("casts Lightning Bolt"),
		"control: the engine's own sentence is unchanged: %s" % g.log_lines[-1])
	screen._open_duel_log()
	var text: String = screen._duel_log.text()
	assert_string_contains(text, "casts Lightning Bolt (targeting Serra Angel)")


func test_an_x_spell_names_its_x_and_its_target() -> void:
	var g := await _test_duel()
	screen._open_duel_log()
	g.players[0].mana_pool.add(Mtg.ManaColor.R, 4)
	assert_eq(g.cast_spell(0, _in(g, 0, "Fireball"), [TargetRef.player(1)], 3), "")
	assert_string_contains(screen._duel_log.text(),
		"casts Fireball (X=3, targeting %s)" % g.players[1].player_name,
		"line by line as well as on a refill")


func test_an_activation_names_its_target() -> void:
	var g := await _test_duel()
	var sorcerer := _in(g, 0, "Prodigal Sorcerer", false)
	var angel := _in(g, 1, "Serra Angel", false)
	assert_eq(g.activate_ability(0, sorcerer, 0, [TargetRef.card(angel)]), "")
	screen._open_duel_log()
	assert_true(screen._duel_log.text().contains("(targeting Serra Angel)"),
		"the activation's line: %s" % screen._duel_log.text().right(160))


func test_the_chain_tooltip_says_it_too() -> void:
	var g := await _test_duel()
	var angel := _in(g, 1, "Serra Angel", false)
	g.players[0].mana_pool.add(Mtg.ManaColor.R, 1)
	g.cast_spell(0, _in(g, 0, "Lightning Bolt"), [TargetRef.card(angel)])
	screen._refresh()
	var entry: Control = screen._chain_box.get_child(0)
	assert_string_contains(entry.tooltip_text, "(targeting Serra Angel)")


func test_off_the_log_reads_as_the_engine_wrote_it() -> void:
	DuelScreenOptions.set_log_targets(false)
	var g := await _test_duel()
	var angel := _in(g, 1, "Serra Angel", false)
	g.players[0].mana_pool.add(Mtg.ManaColor.R, 1)
	g.cast_spell(0, _in(g, 0, "Lightning Bolt"), [TargetRef.card(angel)])
	screen._open_duel_log()
	assert_false(screen._duel_log.text().contains("targeting"),
		"switched off: no parenthesis")


func test_the_running_file_names_them_too() -> void:
	var dir := ProjectSettings.globalize_path("user://p3_log_targets")
	DirAccess.make_dir_recursive_absolute(dir)
	DuelLogFile.location = dir
	if FileAccess.file_exists(DuelLogFile.path()):
		DirAccess.remove_absolute(DuelLogFile.path())
	var config := DuelConfig.hotseat_default()
	config.rng_seed = 4100
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	var g: MtgGame = screen.game
	var angel := CardInstance.new(CardRegistry.get_card("Serra Angel"), g._next_instance_id, 1)
	g._next_instance_id += 1
	g._instances[angel.id] = angel
	g._put_on_battlefield(angel, 1)
	var bolt := CardInstance.new(CardRegistry.get_card("Lightning Bolt"), g._next_instance_id, 0)
	g._next_instance_id += 1
	g._instances[bolt.id] = bolt
	bolt.zone = Mtg.Zone.HAND
	g.players[0].hand.append(bolt)
	g.priority_player = 0
	g.players[0].mana_pool.add(Mtg.ManaColor.R, 1)
	assert_eq(g.cast_spell(0, bolt, [TargetRef.card(angel)]), "")
	var text := FileAccess.get_file_as_string(DuelLogFile.path())
	assert_string_contains(text, "casts Lightning Bolt (targeting Serra Angel)")
	DirAccess.remove_absolute(DuelLogFile.path())
	DirAccess.remove_absolute(dir)


func test_details_are_built_from_the_chain_object() -> void:
	var g := await _test_duel()
	var angel := _in(g, 1, "Serra Angel", false)
	g.players[0].mana_pool.add(Mtg.ManaColor.R, 4)
	g.cast_spell(0, _in(g, 0, "Fireball"), [TargetRef.card(angel)], 2)
	assert_eq(DuelLogText.details(g, g.stack.back()), "X=2, targeting Serra Angel")
