extends GutTest
## [QoL] The Stats window's Hand page — the sample hand, drawn.
##
## [SampleHand] is pinned by `tests/unit/test_sample_hand.gd`; this
## script is about the PICTURE: that the sixth tab is there and the six
## still fit, that a deal is seven small cards of the one card size, that
## the three buttons move the sample and the page follows, that a proxy
## is plain paper here as everywhere, that the 1997 advice is spoken and
## never enforced, and that the hand survives a page swap but not a
## reopening. No 1997 skin is needed: the faces fall back like every
## other widget, and only their number and size are measured.


var screen: DeckBuilderScreen
var _had_layout_setting: bool
var _old_layout_setting: Variant


func before_each() -> void:
	_had_layout_setting = Settings.has_value(DeckBuilderScreen.BIG_CARDS_SETTING)
	_old_layout_setting = Settings.get_value(DeckBuilderScreen.BIG_CARDS_SETTING, true)
	Settings.set_value(DeckBuilderScreen.BIG_CARDS_SETTING, false, false)
	CardRegistry.ensure_loaded()
	screen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)


func after_each() -> void:
	if _had_layout_setting:
		Settings.set_value(DeckBuilderScreen.BIG_CARDS_SETTING, _old_layout_setting)
	else:
		Settings.clear_value(DeckBuilderScreen.BIG_CARDS_SETTING)


func _walk(node: Node) -> Array:
	var out := [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out


func _fill(card_name: String, n: int) -> void:
	for i in n:
		screen.deck.add(card_name)


func _tabs() -> HBoxContainer:
	return screen._stats_pages.get_parent().get_parent().get_child(0) as HBoxContainer


## Open Stats on the Hand page.
func _open_hand_page() -> void:
	screen._run_command("Stats")
	screen._show_stats_page(5, _tabs())


func _page_labels() -> Array:
	var out := []
	for node in _walk(screen._stats_pages):
		if node is Label:
			out.append(String((node as Label).text).strip_edges())
	return out


func _page_button(text_prefix: String) -> Button:
	for node in _walk(screen._stats_pages):
		if node is Button and String((node as Button).text).begins_with(text_prefix):
			return node as Button
	return null


func _faces() -> Array:
	var out := []
	for node in _walk(screen._stats_pages):
		if node is MiniCard or node is ProxyFace:
			out.append(node)
	return out


# --------------------------------------------------------------- the tab --

func test_hand_is_the_sixth_tab_and_six_still_fit_the_window() -> void:
	screen._run_command("Stats")
	var tabs := _tabs()
	assert_eq(tabs.get_child_count(), 6, "six pages")
	assert_eq((tabs.get_child(5) as Button).text, "Hand", "and Hand is the last")
	var width := 0.0
	for tab in tabs.get_children():
		width += (tab as Button).custom_minimum_size.x
	width += 4 * (tabs.get_child_count() - 1)
	assert_true(width <= 560.0, "the row fits the 560 the scroller has: %s" % width)
	assert_eq(DeckBuilderScreen.STATS_PAGES.size(), 6, "the constant agrees")


func test_an_empty_deck_asks_for_cards_first() -> void:
	_open_hand_page()
	assert_true(_page_labels().has("Add some cards first."), str(_page_labels()))
	assert_null(screen._sample, "nothing was dealt")
	assert_eq(_faces().size(), 0)


# -------------------------------------------------------------- the deal --

func test_the_page_deals_seven_small_cards_of_the_one_size() -> void:
	_fill("Swamp", 20)
	_fill("Grizzly Bears", 20)
	_open_hand_page()
	assert_not_null(screen._sample, "dealt on first showing")
	assert_eq(screen._sample.hand.size(), 7)
	var faces := _faces()
	assert_eq(faces.size(), 7, "one face per card in hand")
	for face in faces:
		assert_true(face is MiniCard, "a card the registry has is a MiniCard")
		assert_eq((face as Control).size, MiniCard.SIZE, "at the one card size")
		assert_eq((face as Control).get_parent().custom_minimum_size, MiniCard.SIZE,
			"in a holder of the same size")
	var labels := _page_labels()
	assert_true(labels.has("Turn 1"), "the head names the turn: %s" % str(labels))
	var line := ""
	for label in labels:
		if String(label).contains("in the library"):
			line = String(label)
	assert_true(line.begins_with("7 cards in hand"), line)
	assert_true(line.contains("33 in the library"), line)
	assert_not_null(_page_button("New hand"))
	assert_not_null(_page_button("Next turn"))
	var mulligan := _page_button("Mulligan to")
	assert_not_null(mulligan)
	assert_eq(mulligan.text, "Mulligan to 6", "the button says what it costs")
	assert_false(mulligan.disabled)


func test_the_faces_are_the_cards_in_hand_in_order() -> void:
	_fill("Swamp", 8)
	_open_hand_page()
	var faces := _faces()
	for i in faces.size():
		var face := faces[i] as MiniCard
		assert_eq(face.instance.data.card_name, String(screen._sample.hand[i]))
		assert_true(face.disabled, "the holder takes the pointer, not the face")
		assert_eq(face.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_a_proxy_is_plain_paper_on_this_page_too() -> void:
	for i in 7:
		screen.deck.add_proxy("Not A Card At All")
	_open_hand_page()
	var faces := _faces()
	assert_eq(faces.size(), 7)
	for face in faces:
		assert_true(face is ProxyFace, "no registry data, so paper")
		assert_eq((face as Control).size, MiniCard.SIZE, "of the one size")
	var labels := _page_labels()
	assert_true(labels.has("No land in hand — the hand the 1997 rule offered a mulligan for."),
		"a proxy is not a land, so seven of them are a no-land hand: %s" % str(labels))


# ----------------------------------------------------------- the buttons --

func test_the_buttons_move_the_sample_and_the_page_follows() -> void:
	_fill("Swamp", 20)
	_fill("Grizzly Bears", 20)
	_open_hand_page()
	var sample: SampleHand = screen._sample
	_page_button("Mulligan to").pressed.emit()
	assert_same(screen._sample, sample, "the same deal, moved")
	assert_eq(sample.mulligans, 1)
	assert_eq(_faces().size(), 6, "six faces after the first mulligan")
	assert_eq(_page_button("Mulligan to").text, "Mulligan to 5", "and the button counts down")
	assert_true(_page_labels().has("Turn 1  —  after 1 mulligan"), str(_page_labels()))
	_page_button("Next turn").pressed.emit()
	assert_eq(sample.turn, 2)
	assert_eq(_faces().size(), 7, "a card drawn")
	assert_true(_page_labels().has("Turn 2  —  after 1 mulligan"), str(_page_labels()))
	_page_button("New hand").pressed.emit()
	assert_eq(sample.turn, 1)
	assert_eq(sample.mulligans, 0)
	assert_eq(_faces().size(), 7)
	assert_true(_page_labels().has("Turn 1"), str(_page_labels()))
	assert_eq(_page_button("Mulligan to").text, "Mulligan to 6")


func test_the_seventh_mulligan_leaves_nothing_and_greys_the_button() -> void:
	_fill("Swamp", 20)
	_fill("Grizzly Bears", 20)
	_open_hand_page()
	for i in 7:
		assert_false(_page_button("Mulligan to").disabled, "mulligan %d is offered" % (i + 1))
		_page_button("Mulligan to").pressed.emit()
	assert_eq(screen._sample.hand.size(), 0)
	assert_eq(_faces().size(), 0)
	var mulligan := _page_button("Mulligan to")
	assert_eq(mulligan.text, "Mulligan to 0")
	assert_true(mulligan.disabled, "nothing cannot be shuffled away again")
	assert_true(_page_labels().has("An empty hand — the seventh mulligan draws nothing."),
		str(_page_labels()))
	assert_false(_page_button("Next turn").disabled, "the library is still there to draw from")


func test_next_turn_greys_when_the_library_is_empty() -> void:
	_fill("Swamp", 7)
	_open_hand_page()
	assert_true(_page_button("Next turn").disabled, "seven of seven dealt, nothing under them")
	assert_true(_page_labels().has("Nothing but land in hand — the hand the 1997 rule offered a mulligan for."),
		"seven Swamps are the other 1997 hand: %s" % str(_page_labels()))


func test_the_advice_is_spoken_for_the_1997_hands_only_and_never_enforced() -> void:
	_fill("Grizzly Bears", 10)
	_open_hand_page()
	var labels := _page_labels()
	assert_true(labels.has("No land in hand — the hand the 1997 rule offered a mulligan for."),
		str(labels))
	assert_false(_page_button("New hand").disabled, "every button still works")
	assert_false(_page_button("Next turn").disabled)
	screen._sample = null
	screen.deck.clear()
	_fill("Swamp", 3)
	_fill("Grizzly Bears", 3)
	screen._refill_hand_page()
	for label in _page_labels():
		assert_false(String(label).contains("1997 rule"), "three of six says nothing: %s" % label)


# ------------------------------------------------- swapping and reopening --

func test_the_hand_survives_a_page_swap_but_not_a_reopening() -> void:
	_fill("Swamp", 20)
	_fill("Grizzly Bears", 20)
	_open_hand_page()
	var sample: SampleHand = screen._sample
	var hand: Array[String] = sample.hand.duplicate()
	screen._show_stats_page(1, _tabs())
	await get_tree().process_frame
	assert_eq(_faces().size(), 0, "the Draws page has no cards on it")
	screen._show_stats_page(5, _tabs())
	await get_tree().process_frame
	assert_same(screen._sample, sample, "the same deal came back")
	assert_eq(sample.hand, hand, "untouched")
	assert_eq(_faces().size(), 7)
	for dialog in screen.open_dialogs():
		dialog.dismiss()
	await get_tree().process_frame
	assert_eq(screen.open_dialogs().size(), 0, "closed")
	screen._run_command("Stats")
	assert_null(screen._sample, "a reopening forgets the deal: the deck may have changed")
	screen._show_stats_page(5, _tabs())
	assert_not_null(screen._sample)
	assert_true(screen._sample != sample, "a fresh one")


func test_a_thousand_hands_are_dealt_and_shown_in_place_of_the_cards() -> void:
	_fill("Mountain", 20)
	_fill("Lightning Bolt", 4)
	_fill("Hill Giant", 16)
	_open_hand_page()
	var many := screen._stats_pages.find_child("StatsThousandHands", true, false) as Button
	assert_eq(many.text, "1000 hands")
	many.pressed.emit()
	assert_eq(int(screen._trials["runs"]), 1000)
	assert_eq(_faces().size(), 0, "the count stands where the cards stood")
	var said := "\n".join(PackedStringArray(_page_labels()))
	for words in ["1000 opening hands of 7, dealt and counted", "0 lands", "7 lands", "Keepable (2-5 lands)",
			"Which lands came", "Mountain", "a source of red", "a play on turn one", "The spells seen most",
			"Hill Giant"]:
		assert_string_contains(said, words)
	assert_false(said.contains("every color your spells ask for"), "one color: no such line")
	# Nothing wider than the page.
	for node in _walk(screen._stats_pages):
		if node is HBoxContainer:
			assert_true((node as Control).get_combined_minimum_size().x <= 560.0, str(node))
	# A new hand brings the cards back.
	_page_button("New hand").pressed.emit()
	assert_true(screen._trials.is_empty())
	assert_eq(_faces().size(), 7)
