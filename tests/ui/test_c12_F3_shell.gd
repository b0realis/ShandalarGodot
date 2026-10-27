extends GutTest
## THE SHELL'S SMALLER WINDOWS (the bug campaign c12): Escape closes the
## title's popups (h4-9 + h1-3), the globe says what the lobby is (h6-7),
## the Combat window holds seven or more creatures a side on one line each
## (h4-10), the Test hands turn buttons show the whole name (h4-11), and a
## draft pool saved with every card checked stays "everything" (h5-1).


# ====================================================== h4-9: the title ==

func _title() -> Node:
	var title: Node = load("res://game/main.tscn").instantiate()
	add_child_autofree(title)
	await get_tree().process_frame
	return title


func _escape() -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = "ui_cancel"
		ev.pressed = pressed
		Input.parse_input_event(ev)
	for i in 2:
		await get_tree().process_frame


func _up(popup: Variant) -> bool:
	return is_instance_valid(popup) and not (popup as Node).is_queued_for_deletion()


func test_escape_closes_a_set_badges_window() -> void:
	var title: Node = await _title()
	var badges := title.find_child("OriginalSets", true, false) as SetBadges
	assert_not_null(badges)
	badges.set_clicked.emit("arn")
	await get_tree().process_frame
	var popup := UiChrome.open_popup(title)
	assert_not_null(popup, "the set's window is up")
	await _escape()
	assert_false(_up(popup), "Escape is its OK")


func test_escape_closes_a_packs_notice_without_changing_the_pack() -> void:
	var title: Node = await _title()
	var was := CardPacks.is_enabled(CardPacks.ID)
	title._open_pack_notice(CardPacks.ID)
	var notice: Variant = title.get("_pack_notice")
	assert_true(_up(notice), "the notice is up")
	await _escape()
	assert_false(_up(notice), "Escape closes it")
	assert_eq(CardPacks.is_enabled(CardPacks.ID), was, "and touches nothing")


func test_escape_with_no_popup_leaves_the_title_be() -> void:
	var title: Node = await _title()
	await _escape()
	assert_true(is_instance_valid(title) and title.is_inside_tree())
	assert_null(UiChrome.open_popup(title))


# ======================================================== h6-7: the globe ==

func test_the_globe_says_what_the_lobby_is() -> void:
	var title: Node = await _title()
	var globe := title.find_child("Manalink", true, false) as Control
	assert_not_null(globe)
	assert_false(globe.tooltip_text.contains("coming later"), "no promise of Internet games")
	assert_string_contains(globe.tooltip_text, "local network")


# ================================================= h4-10: the Combat window ==

var _saved_position: Variant = null


func _summon(g: MtgGame, card_name: String, pid: int) -> CardInstance:
	var data := CardRegistry.get_card(card_name)
	var inst := CardInstance.new(data, g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, pid)
	return inst


func _duel() -> DuelScreen:
	_saved_position = Settings.get_value(CombatWindow.POS_SETTING, null) \
		if Settings.has_value(CombatWindow.POS_SETTING) else null
	Settings.clear_value(CombatWindow.POS_SETTING)
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.set_process(false)
	return screen


func after_each() -> void:
	if _saved_position != null:
		Settings.set_value(CombatWindow.POS_SETTING, _saved_position)
		_saved_position = null


## [param attackers] of the active player's against [param blockers] of
## the other's, every blocker aimed — the lineup in the blockers' step.
func _lineup(screen: DuelScreen, attackers: int, blockers: int) -> void:
	var g := screen.game
	# Your attack: the attackers stand in the lower lane.
	g.active_player = screen._human_seat()
	var attacking := g.active_player
	var them: Array = []
	for i in attackers:
		var a := _summon(g, "Grizzly Bears", attacking)
		a.tapped = true
		g.combat.attackers[a.id] = true
		them.append(a)
	for i in blockers:
		var b := _summon(g, "Savannah Lions", 1 - attacking)
		g.combat.blocks[b.id] = them[i % them.size()].id
	g._step_index = Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_BLOCKERS)
	screen._refresh()
	for i in 2:
		await get_tree().process_frame


func test_nine_attackers_and_eight_blockers_stay_in_the_window() -> void:
	var screen: DuelScreen = await _duel()
	await _lineup(screen, 9, 8)
	var window := screen._combat_window
	var frame := window.get_global_rect()
	assert_eq(window.size.y, CombatWindow.HEIGHT, "the window keeps the art's height")
	for lane: Control in [window._top_lane, window._bottom_lane]:
		assert_eq(lane.size.y, CombatWindow.LANE_H, "one line: the lane keeps its height")
		for card: Control in lane.get_children():
			assert_true(frame.encloses(card.get_global_rect()),
				"every card inside the window (%s in %s)" % [card.get_global_rect(), frame])
	var lanes := window.lane_ids()
	assert_eq([lanes[0].size(), lanes[1].size()], [8, 9])


func test_a_full_lane_squeezes_left_to_right_and_shows_the_last_card_whole() -> void:
	var screen: DuelScreen = await _duel()
	await _lineup(screen, 9, 1)
	var lane: Control = screen._combat_window._bottom_lane
	var cards := lane.get_children()
	var lane_rect := lane.get_global_rect()
	for i in cards.size() - 1:
		assert_lt((cards[i] as Control).position.x, (cards[i + 1] as Control).position.x,
			"in the lineup's order")
	var last := (cards[-1] as Control).get_global_rect()
	assert_almost_eq(last.end.x, lane_rect.end.x, 1.0, "the last card whole, at the lane's end")


func test_a_short_lane_stays_centred() -> void:
	var screen: DuelScreen = await _duel()
	await _lineup(screen, 2, 1)
	var window := screen._combat_window
	for lane: Control in [window._top_lane, window._bottom_lane]:
		var cards := lane.get_children()
		var left := (cards[0] as Control).get_global_rect().position.x
		var right := (cards[-1] as Control).get_global_rect().end.x
		assert_almost_eq((left + right) * 0.5, lane.get_global_rect().get_center().x, 1.0,
			"centred in its lane, as the lanes always stood")


func test_a_card_in_the_window_is_still_not_a_table_card() -> void:
	# The hunt of 2026-10-21: a card in the Combat window stands for its
	# creature and the duel screen must not drag-place it — it reads a
	# card as a table card by its parent being a [SqueezeRow].
	var screen: DuelScreen = await _duel()
	await _lineup(screen, 7, 0)
	var card: Control = screen._combat_window._bottom_lane.get_child(0)
	assert_null(screen._layout_root(card))


# ===================================================== h4-11: Test hands ==

func test_the_turn_buttons_show_the_whole_name() -> void:
	var bench: TestHandsScreen = load("res://game/test_hands_screen.tscn").instantiate()
	bench.config = DuelConfig.hotseat_default()
	# Thirty-two letters: the longest name the Magic Battle screen takes.
	bench.config.player_names = ["Archmage of the Northern Wastes!", "White Wizard"]
	add_child_autofree(bench)
	for i in 2:
		await get_tree().process_frame
	for button: Button in bench._turn_buttons:
		assert_false(button.clip_text, "nothing clipped")
		var font := button.get_theme_font("font")
		var text := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			button.get_theme_font_size("font_size")).x
		var box := button.get_theme_stylebox("normal")
		assert_gte(button.size.x, text + box.get_margin(SIDE_LEFT) + box.get_margin(SIDE_RIGHT),
			"`%s` has room for its words" % button.text)
		assert_string_contains(button.tooltip_text, button.text.get_slice(" · ", 1))


# ====================================================== h5-1: draft pool ==

var _had_selection := false
var _old_selection: Variant = null
var _enabled_before: Array = []


func _keep_settings() -> void:
	_had_selection = Settings.has_value(DraftPoolConfig.SETTING)
	_old_selection = Settings.get_value(DraftPoolConfig.SETTING, [])
	_enabled_before.clear()
	for id in CardPacks.available_ids():
		if CardPacks.is_enabled(id):
			_enabled_before.append(id)


func _put_settings_back() -> void:
	for id in CardPacks.available_ids():
		CardPacks.set_enabled(id, _enabled_before.has(id))
	if _had_selection: Settings.set_value(DraftPoolConfig.SETTING, _old_selection, false)
	else: Settings.clear_value(DraftPoolConfig.SETTING)


func _pool_dialog() -> DraftPoolDialog:
	var panel := DraftPoolDialog.new()
	add_child_autofree(panel)
	await get_tree().process_frame
	return panel


func test_a_pool_saved_with_every_card_checked_takes_in_a_pack_enabled_later() -> void:
	_keep_settings()
	var pack := "pack-9"
	if not CardPacks.available_ids().has(pack):
		pending("Pack 9 is not in this build")
		return
	Settings.clear_value(DraftPoolConfig.SETTING)
	CardPacks.set_enabled(pack, false)
	var panel: DraftPoolDialog = await _pool_dialog()
	assert_false(panel.rows.has("Mogg Fanatic"), "Pack 9 is off")
	panel.choose(panel.rows.keys())
	panel._save()
	assert_false(Settings.has_value(DraftPoolConfig.SETTING),
		"every card checked is saved as everything, not as today's list")
	CardPacks.set_enabled(pack, true)
	assert_true(DraftPoolConfig.selected().has("Mogg Fanatic"),
		"so Pack 9's cards join the pool when it comes back")
	_put_settings_back()


func test_a_narrowed_pool_is_still_saved_as_its_list() -> void:
	_keep_settings()
	Settings.clear_value(DraftPoolConfig.SETTING)
	var panel: DraftPoolDialog = await _pool_dialog()
	var names: Array = panel.rows.keys()
	names.erase("Lightning Bolt")
	panel.choose(names)
	panel._save()
	assert_true(Settings.has_value(DraftPoolConfig.SETTING), "a choice is remembered")
	assert_false(DraftPoolConfig.selected().has("Lightning Bolt"))
	_put_settings_back()


func test_every_visible_card_with_a_hidden_choice_carried_keeps_the_list() -> void:
	# A choice kept for a disabled pack is a pack the player DID narrow:
	# "everything" would hand back the cards they had left out.
	_keep_settings()
	Settings.set_value(DraftPoolConfig.SETTING, ["Forest", "Force of Will"], false)
	CardPacks.set_enabled("pack-5", false)
	var panel: DraftPoolDialog = await _pool_dialog()
	panel.choose(panel.rows.keys())
	panel._save()
	assert_true(Settings.has_value(DraftPoolConfig.SETTING))
	var saved: Array = Settings.get_value(DraftPoolConfig.SETTING, [])
	assert_true(saved.has("Force of Will"), "the hidden choice is carried")
	_put_settings_back()
