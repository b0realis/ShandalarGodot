extends GutTest
## THE DON'T AUTO TAP MARKS ON THE TABLE (the owner, 2026-11-11): *"Under
## big cards lets have another button to show or hide don't autotap cards.
## If that button is pressed a circular right pointing arrow that is
## crossed with one red line icon is shown on the middle right of every
## minicard on your table that has dont auto-tap enabled."*
##
## The switch is the reserve strip's fifth button ([NoAutoTapMark.button],
## [member DuelScreen._no_auto_tap_button]); the mark is
## [member MiniCard.no_auto_tap]; a marked card stands out of its pile
## while the marks are shown, so the mark at its middle right is not
## covered by the card in front of it.

var screen: DuelScreen
var _saved: Variant = null
var _had := false
const SCREEN := Vector2(1280, 800)


func before_each() -> void:
	_had = Settings.has_value(NoAutoTapMark.SHOW_KEY)
	_saved = Settings.get_value(NoAutoTapMark.SHOW_KEY, null)
	Settings.set_value(NoAutoTapMark.SHOW_KEY, false)


func after_each() -> void:
	if _had:
		Settings.set_value(NoAutoTapMark.SHOW_KEY, _saved)
	else:
		Settings.clear_value(NoAutoTapMark.SHOW_KEY)
	await get_tree().process_frame


func _open(config: DuelConfig = null) -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	if config != null:
		screen.config = config
	add_child_autofree(screen)
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.size = SCREEN
	await get_tree().process_frame
	await get_tree().process_frame


## Seat [param pid]'s table holds [param names], in order; nothing else.
func _table(pid: int, names: Array) -> Array:
	var g: MtgGame = screen.game
	g.players[pid].battlefield.clear()
	var out: Array = []
	var next := 95010 + pid * 100
	for card_name in names:
		var c := CardInstance.new(CardRegistry.get_card(card_name), next, pid)
		next += 1
		g._instances[c.id] = c
		g._put_on_battlefield(c, pid)
		out.append(c)
	screen._refresh()
	return out


func _mini_for(node: Node, inst: CardInstance) -> MiniCard:
	if node is MiniCard and (node as MiniCard).instance == inst:
		return node
	for child in node.get_children():
		var found := _mini_for(child, inst)
		if found != null:
			return found
	return null


func _in_pile(inst: CardInstance) -> bool:
	var node: Node = _mini_for(screen, inst)
	while node != null:
		if node is CardPile:
			return true
		node = node.get_parent()
	return false


func _press(on: bool) -> void:
	screen._no_auto_tap_button.button_pressed = on
	await get_tree().process_frame


# ------------------------------------------------------------ the switch --

func test_the_switch_stands_under_the_large_card() -> void:
	await _open()
	var btn := screen._no_auto_tap_button
	assert_not_null(btn)
	assert_eq(btn.get_parent(), screen._qol_reserve)
	assert_true(btn.toggle_mode, "show, then hide")
	assert_false(btn.button_pressed, "off at first")
	assert_eq(btn.tooltip_text, NoAutoTapMark.TIP_SHOW, "and it says how a card is marked")
	var card: Rect2 = screen._card_preview.get_global_rect()
	var rect := btn.get_global_rect()
	assert_gte(rect.position.y, card.end.y - 0.5, "under the card")
	assert_true(rect.position.x >= card.position.x - 0.5 and rect.end.x <= card.end.x + 0.5,
		"within the card's column: %s under %s" % [rect, card])


func test_five_buttons_and_a_test_duels_strip_share_one_row_untouched() -> void:
	var position := DuelPosition.new()
	position.add(0, DuelPosition.TABLE, "Forest")
	position.active_player = 0
	position.step = Mtg.Step.MAIN1
	await _open(DuelConfig.hotseat_default().for_test(position, 6061))
	var controls: Array = [screen._no_auto_tap_button, screen._screen_options_button,
		screen._log_button, screen._expand_button, screen._arrange_button]
	var strip: Node = screen._qol_reserve.find_child("TestStrip", true, false)
	assert_not_null(strip, "control: a test duel's strip")
	for child in strip.get_children():
		controls.append(child)
	for i in controls.size():
		for j in range(i + 1, controls.size()):
			var a: Rect2 = (controls[i] as Control).get_global_rect()
			var b: Rect2 = (controls[j] as Control).get_global_rect()
			assert_false(a.intersects(b), "%s clear of %s (%s vs %s)"
				% [(controls[i] as Node).name, (controls[j] as Node).name, a, b])
			assert_almost_eq(a.position.y, b.position.y, 8.0, "one row")
	var strip_rect := (screen._qol_reserve as Control).get_global_rect()
	for c in controls:
		assert_true(strip_rect.encloses((c as Control).get_global_rect()),
			"%s inside the strip" % (c as Node).name)


func test_a_lan_tables_longest_badge_word_fits_the_left_end() -> void:
	# SgDuelView's connection badge shares the strip's left end with the
	# five buttons; its words at the strip's label size.
	for word in ["Online", "Tournament", "Suspended", "Reconnect", "Sending…", "Offline"]:
		var badge := Button.new()
		badge.text = word
		badge.custom_minimum_size = Vector2(DuelScreen.STRIP_LEFT_ROOM, 30)
		OriginalDialog.dress_bar_button(badge)
		badge.add_theme_font_size_override("font_size", DuelScreen.STRIP_LABEL_FONT)
		add_child_autofree(badge)
		var right := 4.0 + badge.get_combined_minimum_size().x
		var fifth_left := CardPreview.SIZE.x - (ArrangeButton.FACE.x + DuelScreen.STRIP_GAP) * 5
		assert_lt(right, fifth_left, "%s ends at %s, the fifth button starts at %s"
			% [word, right, fifth_left])


func test_the_choice_is_kept_between_duels() -> void:
	await _open()
	await _press(true)
	assert_true(NoAutoTapMark.shown())
	assert_eq(screen._no_auto_tap_button.tooltip_text, NoAutoTapMark.TIP_HIDE)
	var second: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(second)
	await get_tree().process_frame
	assert_true(second._no_auto_tap_button.button_pressed, "the next duel opens with the marks shown")
	assert_true(second._show_no_auto_tap)


# -------------------------------------------------------------- the mark --

func test_a_marked_card_wears_the_mark_only_while_the_switch_shows_it() -> void:
	await _open()
	var cards := _table(0, ["Forest", "Sol Ring"])
	screen._no_auto_tap[cards[1].id] = true
	screen._refresh()
	assert_false(_mini_for(screen, cards[1]).no_auto_tap, "hidden by default")
	await _press(true)
	assert_true(_mini_for(screen, cards[1]).no_auto_tap, "shown")
	assert_false(_mini_for(screen, cards[0]).no_auto_tap, "an unmarked Forest wears none")
	await _press(false)
	assert_false(_mini_for(screen, cards[1]).no_auto_tap, "hidden again")


func test_the_mark_rides_at_the_cards_middle_right() -> void:
	await _open()
	var ring: CardInstance = _table(0, ["Sol Ring"])[0]
	screen._no_auto_tap[ring.id] = true
	await _press(true)
	await get_tree().process_frame
	var w := _mini_for(screen, ring)
	var mark := w.find_child("NoAutoTapMark", false, false) as Control
	assert_not_null(mark)
	assert_true(mark.visible)
	var card := Rect2(Vector2.ZERO, MiniCard.SIZE)
	var at := Rect2(mark.position, mark.size)
	assert_almost_eq(at.get_center().y, card.get_center().y, 1.0, "centred top to bottom")
	assert_almost_eq(at.end.x, card.end.x - NoAutoTapMark.CARD_INSET, 1.0, "against the right edge")
	assert_eq(at.size, NoAutoTapMark.SIZE)
	assert_lt(mark.get_index(), w._damage_icon.get_index(), "drawn under the damage marker")


func test_an_opponents_card_never_wears_it() -> void:
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]   # seat 1 is the computer
	config.pace = 0.0
	await _open(config)
	assert_false(screen._is_human(1), "control: seat 1 is the computer")
	var theirs: CardInstance = _table(1, ["Sol Ring"])[0]
	screen._no_auto_tap[theirs.id] = true   # a mark only a seat at the screen can set
	await _press(true)
	assert_false(_mini_for(screen, theirs).no_auto_tap)


func test_a_marked_land_stands_out_of_its_pile_while_shown() -> void:
	await _open()
	# The rule an enchanted card or one with counters already follows: the
	# marked card takes a slot of its own where it stands in the row.
	var forests := _table(0, ["Forest", "Forest", "Forest"])
	screen._no_auto_tap[forests[0].id] = true
	screen._refresh()
	for f in forests:
		assert_true(_in_pile(f), "control: three Forests share a pile")
	await _press(true)
	assert_false(_in_pile(forests[0]), "the marked Forest stands on its own")
	assert_true(_mini_for(screen, forests[0]).no_auto_tap)
	assert_true(_in_pile(forests[1]) and _in_pile(forests[2]), "the other two stay piled")
	await _press(false)
	assert_true(_in_pile(forests[0]), "back in its pile once the marks are hidden")


func test_the_card_menu_mark_shows_at_once() -> void:
	await _open()
	var ring: CardInstance = _table(0, ["Sol Ring"])[0]
	await _press(true)
	screen._card_menu_inst = ring
	screen._on_card_menu_chosen(DuelScreen.CARD_MENU_NO_AUTO_TAP)
	assert_true(screen._no_auto_tap.has(ring.id))
	assert_true(_mini_for(screen, ring).no_auto_tap, "the tick puts the mark on the card")
	screen._card_menu_inst = ring
	screen._on_card_menu_chosen(DuelScreen.CARD_MENU_NO_AUTO_TAP)
	assert_false(_mini_for(screen, ring).no_auto_tap, "and taking it off takes the mark away")


func test_showing_no_marks_says_how_to_make_one() -> void:
	await _open()
	_table(0, ["Forest"])
	await _press(true)
	assert_eq(screen._prompt_label.text, DuelScreen.NO_AUTO_TAP_NONE)
	var forest: CardInstance = screen.game.players[0].battlefield[0]
	screen._no_auto_tap[forest.id] = true
	await _press(false)
	await _press(true)
	assert_eq(screen._prompt_label.text, "Don't auto tap marks: on")


# ----------------------------------------------------------- the picture --

func test_the_picture_is_a_struck_through_tap_arrow() -> void:
	var tex := NoAutoTapMark.texture()
	assert_eq(tex.get_size(), Vector2(NoAutoTapMark.PIXELS, NoAutoTapMark.PIXELS))
	var image := tex.get_image()
	var mid := NoAutoTapMark.PIXELS / 2
	var red := image.get_pixel(mid, mid)
	assert_gt(red.r, 0.6, "the red line crosses the centre")
	assert_lt(red.g, 0.3)
	assert_eq(image.get_pixel(0, 0).a, 0.0, "round: the corner is clear")
	var faded := NoAutoTapMark.texture(true).get_image()
	assert_almost_eq(faded.get_pixel(mid, mid).a, red.a * 0.5, 0.02, "the button's resting face is faded")
	assert_eq(HelpPages.icon_texture({"src": HelpPages.SRC_NO_AUTO_TAP}), tex,
		"Help shows the same picture")
