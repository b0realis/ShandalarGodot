extends GutTest
## THE ACCESSIBILITY SET (the polish pass, 2026-10-28; P3 item 4 — the
## owner, round "open items": *"the accessibility set (colorblind-safe
## mana, UI scale, attack-all key)"*), each a switch in the duel screen's
## own options ([DuelScreenOptions]) and nowhere else.
##
##  * COLORBLIND-SAFE MANA: the small card's mana stripes say a colour by
##    colour alone — a red and a green slash differ only in hue. Switched
##    on, each becomes a symbol ([method MiniCard.pip]): the 1997 mana
##    symbol where the skin is imported (sun, drop, skull, fire, tree — a
##    SHAPE each), and a lettered disc where it is not.
##  * UI SCALE: the Situation Bar, the dialogs, the mini-menus and the duel
##    log wear the chosen scale; the table's cards keep theirs.
##  * THE ATTACK-ALL KEY (`duel_attack_all`, A): while attackers are being
##    chosen, every creature that may attack joins the attack; Done still
##    sends it.

var screen: DuelScreen
var _saved: Dictionary = {}
var KEYS: Array[String] = [DuelScreenOptions.COLORBLIND_KEY,
	DuelScreenOptions.UI_SCALE_KEY, DuelScreenOptions.ATTACK_ALL_KEY]


func before_each() -> void:
	_saved = {}
	for key in KEYS:
		_saved[key] = Settings.get_value(key, null) if Settings.has_value(key) else null
		Settings.clear_value(key)


func after_each() -> void:
	for key in KEYS:
		if _saved[key] == null:
			Settings.clear_value(key)
		else:
			Settings.set_value(key, _saved[key])
	await get_tree().process_frame


func _game() -> MtgGame:
	var g := MtgGame.new()
	var filler: Array = []
	for i in 30:
		filler.append("Forest")
	g.setup(filler, filler, "P0", "P1", 20, 20, 424242)
	g.start(0)
	return g


func _put(g: MtgGame, pid: int, card_name: String) -> CardInstance:
	var inst := CardInstance.new(CardRegistry.get_card(card_name), g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, pid)
	return inst


# =========================================================== colorblind --

func test_the_defaults() -> void:
	assert_false(DuelScreenOptions.colorblind_mana(), "the stripes are the 1997 look")
	assert_eq(DuelScreenOptions.ui_scale(), 1.0)
	assert_true(DuelScreenOptions.attack_all_key())


func test_off_the_stripes_are_stripes() -> void:
	var g := _game()
	var w := MiniCard.new(_put(g, 0, "Taiga"), g)
	add_child_autofree(w)
	for child in w._stripes.get_children():
		assert_false(child.has_meta(MiniCard.PIP_META), "a slash, not a symbol")
	assert_eq(w._stripes.get_child_count(), 2)


func test_on_each_colour_is_a_symbol_that_says_which() -> void:
	DuelScreenOptions.set_colorblind_mana(true)
	var g := _game()
	var w := MiniCard.new(_put(g, 0, "Taiga"), g)
	add_child_autofree(w)
	var said := []
	for child in w._stripes.get_children():
		assert_true(child.has_meta(MiniCard.PIP_META), "a symbol")
		said.append(int(child.get_meta(MiniCard.PIP_META)))
	said.sort()
	assert_eq(said, [Mtg.ManaColor.R, Mtg.ManaColor.G], "Taiga: red and green, each its own")
	# Without the 1997 sheet the disc carries its letter: the colour is
	# never the only thing that says it.
	for child in w._stripes.get_children():
		if GameSkin.texture("mana_symbols") == null:
			var letter := child.find_child("Letter", true, false) as Label
			assert_not_null(letter, "a lettered disc")
			assert_true(letter.text in ["R", "G"])


func test_a_symbol_row_leaves_the_name_its_room() -> void:
	DuelScreenOptions.set_colorblind_mana(true)
	var g := _game()
	var w := MiniCard.new(_put(g, 0, "Forest"), g)
	add_child_autofree(w)
	assert_eq(w._stripes.get_child_count(), 1)
	var pip: Control = w._stripes.get_child(0)
	assert_lte(pip.position.x + pip.size.x, w._stripes.size.x + 0.5, "inside the bar")
	assert_gte(pip.position.x, w._stripes.size.x - MiniCard.PIP_SIZE - 1.0,
		"one symbol sits at the bar's right end")


func test_a_colourless_source_is_lettered_too() -> void:
	DuelScreenOptions.set_colorblind_mana(true)
	var g := _game()
	var w := MiniCard.new(_put(g, 0, "Sol Ring"), g)
	add_child_autofree(w)
	assert_eq(w._stripes.get_child_count(), 1)
	assert_eq(int(w._stripes.get_child(0).get_meta(MiniCard.PIP_META)), Mtg.ManaColor.C)


# ============================================================== UI scale --

func _duel() -> MtgGame:
	var config := DuelConfig.hotseat_default()
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	return screen.game


func test_the_scale_is_one_of_the_offered() -> void:
	DuelScreenOptions.set_ui_scale(1.29)
	assert_eq(DuelScreenOptions.ui_scale(), 1.3, "the nearest offered")
	Settings.set_value(DuelScreenOptions.UI_SCALE_KEY, "huge")
	assert_eq(DuelScreenOptions.ui_scale(), 1.0, "nonsense reads as the default")


func test_the_chrome_wears_the_scale_and_the_table_does_not() -> void:
	DuelScreenOptions.set_ui_scale(1.3)
	await _duel()
	assert_almost_eq(screen._situation_bar.scale.x, 1.3, 0.001, "the Situation Bar")
	assert_eq(screen._ability_menu.get_theme_font_size("font_size"), roundi(14 * 1.3),
		"the mini-menus' letters")
	assert_almost_eq(screen._card_preview.scale.x, 1.0, 0.001, "the large card keeps its size")
	screen._open_duel_log()
	assert_almost_eq(screen._duel_log.scale.x, 1.3, 0.001, "the log window")
	screen._open_duel_options()
	await get_tree().process_frame
	assert_almost_eq(screen._options_dialog.scale.x, 1.3, 0.001, "a dialog")
	var rect: Rect2 = screen._options_dialog.get_global_rect()
	var room: Vector2 = screen.get_viewport_rect().size
	assert_true(rect.position.x >= -0.5 and rect.end.x <= room.x + 0.5
		and rect.position.y >= -0.5 and rect.end.y <= room.y + 0.5,
		"a scaled dialog stays on the screen: %s in %s" % [rect, room])


func test_a_change_reaches_a_duel_in_progress() -> void:
	await _duel()
	assert_almost_eq(screen._situation_bar.scale.x, 1.0, 0.001)
	DuelScreenOptions.set_ui_scale(1.15)
	screen._on_screen_options_closed()
	assert_almost_eq(screen._situation_bar.scale.x, 1.15, 0.001,
		"closing the window redresses the chrome")


func test_the_chain_keeps_clear_of_a_scaled_bar() -> void:
	DuelScreenOptions.set_ui_scale(1.5)
	var g := await _duel()
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.size = Vector2(1280, 800)
	await get_tree().process_frame
	for i in 4:
		var inst := CardInstance.new(CardRegistry.get_card("Lightning Bolt"), 95000 + i, 0)
		g._instances[inst.id] = inst
		var item := StackItem.new()
		item.kind = Mtg.StackKind.SPELL
		item.card = inst
		item.description = "Bolt %d" % i
		g.stack.append(item)
	screen._refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	var bar: Rect2 = screen._situation_bar.get_global_rect()
	for entry in screen._chain_box.get_children():
		assert_false((entry as Control).get_global_rect().intersects(bar),
			"an entry clear of the bar as it is drawn, scale and all")


# ======================================================= attack-all key --

func _attack_test(creatures: Array, sick_index := -1) -> MtgGame:
	var position := DuelPosition.new()
	for n in creatures:
		position.add(0, DuelPosition.TABLE, n)
	if sick_index >= 0:
		position.set_sick(0, sick_index, true)
	position.add(1, DuelPosition.TABLE, "Grizzly Bears")
	position.active_player = 0
	position.step = Mtg.Step.COMBAT_BEGIN
	var config := DuelConfig.hotseat_default().for_test(position, 515)
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	var g: MtgGame = screen.game
	for _i in 20:
		if g.awaiting_attackers:
			break
		g.pass_priority(g.priority_player)
	screen._refresh()
	return g


func _press_a() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_A
	ev.pressed = true
	screen._unhandled_key_input(ev)


func test_the_key_puts_every_creature_that_can_attack_into_the_attack() -> void:
	var g := await _attack_test(["Grizzly Bears", "Hill Giant", "Llanowar Elves", "Wall of Stone"], 2)
	assert_true(g.awaiting_attackers, "control: attackers are being chosen")
	assert_eq(screen.mode, DuelScreen.Mode.ATTACKERS)
	_press_a()
	var named := []
	for id in screen._selected_attackers:
		named.append(g.find_instance(id).data.card_name)
	named.sort()
	assert_eq(named, ["Grizzly Bears", "Hill Giant"],
		"the summoning-sick Elves and the Wall stay home")
	assert_true(g.awaiting_attackers, "Done still sends it: nothing declared yet")


func test_switched_off_the_key_does_nothing() -> void:
	DuelScreenOptions.set_attack_all_key(false)
	await _attack_test(["Grizzly Bears", "Hill Giant"])
	_press_a()
	assert_eq(screen._selected_attackers.size(), 0)


func test_outside_the_declaration_the_key_does_nothing() -> void:
	var position := DuelPosition.new()
	position.add(0, DuelPosition.TABLE, "Grizzly Bears")
	position.active_player = 0
	position.step = Mtg.Step.MAIN1
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = DuelConfig.hotseat_default().for_test(position, 516)
	add_child_autofree(screen)
	await get_tree().process_frame
	_press_a()
	assert_eq(screen._selected_attackers.size(), 0)
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)


func test_the_key_is_an_action_of_the_window_not_of_the_options_list() -> void:
	assert_true(InputMap.has_action(DuelScreenOptions.ATTACK_ALL_ACTION), "declared")
	assert_eq(Controls.key_text(DuelScreenOptions.ATTACK_ALL_ACTION), "A")
	assert_true(Controls.names().has(DuelScreenOptions.ATTACK_ALL_ACTION),
		"rebound and remembered like every duel key")
	for entry in Controls.ACTIONS:
		assert_ne(String(entry["name"]), DuelScreenOptions.ATTACK_ALL_ACTION,
			"not on the Options screen's list")
