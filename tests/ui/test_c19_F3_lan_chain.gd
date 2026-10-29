extends GameTest
## THE LAN TABLE'S TARGETS AND X (0.50.65 bug campaign, k3-5). At an
## SGManalink table the host's chain labels already name each target (the
## projection's second line, `SgDuelProjection`), so the Spell Chain's
## tooltip named them twice when the duel screen's own reading added
## `(X=3, targeting Serra Angel)` after them; and the host's history lines
## ("P0 casts Lightning Bolt.") never matched a chain object's
## description, so the log named nothing. [SgDuelView] now adds only the X
## on the chain and finds the cast's object on the projected chain for the
## log.

var referee: SgPracticeMatch
var revision := 1
var _had := false
var _saved: Variant = null


func before_each() -> void:
	super()
	_had = Settings.has_value(DuelScreenOptions.LOG_TARGETS_KEY)
	_saved = Settings.get_value(DuelScreenOptions.LOG_TARGETS_KEY, null) if _had else null
	Settings.clear_value(DuelScreenOptions.LOG_TARGETS_KEY)
	referee = SgPracticeMatch.new(42)
	referee.game = g
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	revision = 1


func after_each() -> void:
	referee = null
	g = null
	if _had:
		Settings.set_value(DuelScreenOptions.LOG_TARGETS_KEY, _saved)
	else:
		Settings.clear_value(DuelScreenOptions.LOG_TARGETS_KEY)
	await get_tree().process_frame


func _room() -> Dictionary:
	return {"id": "r1", "name": "Pack screen", "seat": 0, "names": ["One", "Two"],
		"revision": revision, "ready": [true, true], "connected": [true, true],
		"game": referee.view(0), "deck_names": referee.deck_names.duplicate(), "deck": {}}


func _screen() -> SgDuelView:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var screen := SgDuelView.new()
	screen.stops.from_masks(PackedInt32Array([255, 255, 255, 255]))
	viewport.add_child(screen)
	screen.present(_room(), true, false)
	return screen


func _present(screen: SgDuelView) -> void:
	revision += 1
	screen.present(_room(), true, false)
	for i in 4: await get_tree().process_frame


func test_the_chain_names_the_target_once_and_adds_the_x() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var angel := put_battlefield(1, "Serra Angel")
	var fireball := give_hand(0, "Fireball")
	add_mana(0, Mtg.ManaColor.R, 4)
	assert_ok(g.cast_spell(0, fireball, [TargetRef.card(angel)], 3))
	var screen := _screen()
	for i in 8: await get_tree().process_frame
	var item: StackItem = screen.game.stack.back()
	assert_true(item.description.contains("Serra Angel"), "control: the host's label names it")
	var words := screen._chain_words(item)
	assert_eq(words.count("Serra Angel"), 1, "the target named once: %s" % words)
	assert_true(words.contains("X=3"), "the X the host's label leaves out: %s" % words)
	Settings.set_value(DuelScreenOptions.LOG_TARGETS_KEY, false)
	assert_eq(screen._chain_words(item), item.description, "switched off: the host's words alone")


func test_the_log_names_the_target_of_a_cast_at_the_table() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var angel := put_battlefield(1, "Serra Angel")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R, 1)
	var screen := _screen()
	for i in 4: await get_tree().process_frame
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(angel)]))
	await _present(screen)
	screen._open_duel_log()
	await get_tree().process_frame
	var text: String = screen._duel_log.text()
	assert_true(text.contains("casts Lightning Bolt. (targeting Serra Angel)"),
		"the log names the target at a LAN table: %s" % text.right(300))


func test_an_x_spell_names_its_x_in_the_log() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var angel := put_battlefield(1, "Serra Angel")
	var fireball := give_hand(0, "Fireball")
	add_mana(0, Mtg.ManaColor.R, 4)
	var screen := _screen()
	for i in 4: await get_tree().process_frame
	assert_ok(g.cast_spell(0, fireball, [TargetRef.card(angel)], 3))
	await _present(screen)
	screen._open_duel_log()
	await get_tree().process_frame
	assert_true(screen._duel_log.text().contains("casts Fireball. (X=3, targeting Serra Angel)"),
		screen._duel_log.text().right(300))


func test_switched_off_the_log_reads_as_the_host_wrote_it() -> void:
	Settings.set_value(DuelScreenOptions.LOG_TARGETS_KEY, false)
	advance_to_step(Mtg.Step.MAIN1)
	var angel := put_battlefield(1, "Serra Angel")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R, 1)
	var screen := _screen()
	for i in 4: await get_tree().process_frame
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(angel)]))
	await _present(screen)
	screen._open_duel_log()
	await get_tree().process_frame
	var text: String = screen._duel_log.text()
	assert_true(text.contains("casts Lightning Bolt."), "control: the line is there")
	assert_false(text.contains("targeting"), "switched off, nothing added")
