extends GutTest
## THE CARD TRADER BY HAND (adventure campaign 2026-10-23):
##  - h3-12: after a click into "type a name", the first Escape was eaten by
##    the box and the trader stayed open. Now, as in the save slots (where
##    Escape in a name being typed puts the old name back, and the next
##    closes the list), Escape in the box with a name typed clears it — the
##    whole list again — and leaves the box; the next closes the trader.
##    With nothing typed, the first Escape closes it.
##  - h5-9: every move of the pointer over the list drew the large card
##    again, the row under it the same.
##  - h6-10: the copies in the deck were counted by hand beside the shop's
##    own count ([method CardShop.deck_counts] now); the dimmed rows (the
##    deck may hold no more) are pinned here as the rule stands.
## The pointer and the keys here are real, pushed through the viewport.

const SAVES := "user://adventure_tests_c3_f2_trader"

var viewport: SubViewport
var screen: WorldScreen


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	# The pointer is over this screen: a moving pointer reaches its controls.
	viewport.notification(Node.NOTIFICATION_VP_MOUSE_ENTER)
	screen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)


func after_each() -> void:
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _move(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	viewport.push_input(motion, true)


## A real left click at [param at], through the viewport.
func _click_at(at: Vector2) -> void:
	_move(at)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.position = at
		click.global_position = at
		viewport.push_input(click, true)
	await _frames(2)


## A real key [param code] (typing [param letter], if any), pressed and let go.
func _key(code: Key, letter := "") -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.pressed = pressed
		if letter != "":
			key.unicode = letter.unicode_at(0)
		viewport.push_input(key, true)
	await _frames(1)


func _trader() -> CardTradePane:
	screen.player.gold = 3000
	var trader := screen.open_trade(CardTrade.BAZAAR)
	await _frames(3)
	return trader


func _box(trader: CardTradePane) -> LineEdit:
	return trader.find_child("TradeSearch", true, false) as LineEdit


func test_escape_in_the_name_box_clears_it_then_closes() -> void:
	var trader := await _trader()
	var all := trader.cards().size()
	var box := _box(trader)
	await _click_at(box.get_global_rect().get_center())
	assert_true(box.has_focus(), "control: clicked into the box")
	for letter in "serra":
		await _key(OS.find_keycode_from_string(letter.to_upper()), letter)
	assert_eq(box.text, "serra", "control: a name typed")
	assert_true(trader.cards().size() < all, "control: the list narrowed")
	await _key(KEY_ESCAPE)
	await _frames(1)
	assert_true(screen.trading(), "the first Escape leaves the trader open")
	assert_eq(box.text, "", "the name typed is cleared")
	assert_false(box.has_focus(), "and the box left")
	assert_eq(trader.cards().size(), all, "the whole list again")
	await _key(KEY_ESCAPE)
	await _frames(2)
	assert_false(screen.trading(), "the next Escape closes the trader")


func test_escape_in_an_empty_name_box_closes_at_once() -> void:
	var trader := await _trader()
	var box := _box(trader)
	await _click_at(box.get_global_rect().get_center())
	assert_true(box.has_focus(), "control: clicked into the box")
	await _key(KEY_ESCAPE)
	await _frames(2)
	assert_false(screen.trading(), "nothing typed: Escape closes the trader")


func test_the_large_card_is_drawn_once_per_row() -> void:
	var trader := await _trader()
	var list := trader.find_child("TradeCards", true, false) as ItemList
	var large := trader.find_child("Large", true, false) as CardPreview
	var corner := list.get_global_rect().position
	var first := list.get_item_rect(0)
	_move(corner + first.position + Vector2(12, first.size.y / 2.0))
	await _frames(1)
	var shown := large._shown
	assert_not_null(shown, "control: the row under the pointer shown large")
	assert_eq(shown.data.card_name, trader.cards()[0])
	_move(corner + first.position + Vector2(60, first.size.y / 2.0))
	await _frames(1)
	assert_same(large._shown, shown, "the same row: the large card is not drawn again")
	var second := list.get_item_rect(1)
	_move(corner + second.position + Vector2(12, second.size.y / 2.0))
	await _frames(1)
	assert_eq(large._shown.data.card_name, trader.cards()[1], "another row: its card")


func test_a_card_the_deck_may_hold_no_more_of_is_dimmed() -> void:
	var player := screen.player
	var trader := await _trader()
	var limit := CardShop.copies_allowed(player)
	var full := ""
	var spare := ""
	# Cards of the base sets, not basic lands: the deck's own limit is theirs
	# (the c5 campaign: the others go by 1997's allowance, pinned below).
	for card_name in trader.cards():
		if AdventureBuilder.owned_counts(player).has(card_name) or not CardValue.is_base(card_name) \
				or card_name in CreatureDeck.BASICS:
			continue
		if full == "":
			full = card_name
		elif spare == "":
			spare = card_name
			break
	# Copies in the deck until it may hold no more (the limit grows with the
	# deck's size).
	while CardShop.in_deck(player, full) < CardShop.copies_allowed(player):
		player.cards.append({"card": full, "decks": [player.current_deck]})
	limit = CardShop.copies_allowed(player)
	for i in limit:
		player.cards.append({"card": spare, "decks": []})
	trader.refresh()
	var list := trader.find_child("TradeCards", true, false) as ItemList
	var shown := trader.cards()
	var at_full := shown.find(full)
	var at_spare := shown.find(spare)
	assert_eq(list.get_item_text(at_full), "%s-%d" % [full, limit], "the copies owned")
	assert_eq(list.get_item_custom_fg_color(at_full), PaneStyle.FAINT, "all in the deck: dimmed")
	assert_eq(list.get_item_text(at_spare), "%s-%d" % [spare, limit])
	assert_ne(list.get_item_custom_fg_color(at_spare), PaneStyle.FAINT, "none in the deck: not dimmed")


## The c5 campaign (P3-2, P3-3): the dimmed names follow 1997's own
## allowance (`GetRemainingAllowedCardCopies(card) <= 0`, visitLocation.c
## 3822, [method DuelSpoils.copies_left]): a basic land is never dimmed,
## however many the deck holds; a card outside the base sets has half the
## deck's limit — none under 40 cards — and is dimmed with none in the deck.
## "-N" follows a name only for a card the hero owns (visitLocation.c
## 3804–3808).
func test_the_dimming_is_1997_s_allowance_and_only_owned_cards_carry_a_count() -> void:
	var player := screen.player
	# A Magician's first deck is 40 cards since 1997's extra creature copy
	# (the quick world package, I-2): one card out of the deck in use, so
	# it is under 40 (still owned).
	for entry in player.cards:
		if String((entry as Dictionary)["card"]) != "Mountain":
			(entry as Dictionary)["decks"] = []
			break
	var trader := await _trader()
	var owned := AdventureBuilder.owned_counts(player)
	var outside := ""
	for card_name in trader.cards():
		if not owned.has(card_name) and not CardValue.is_base(card_name) and not card_name in CreatureDeck.BASICS:
			outside = card_name
			break
	assert_ne(outside, "", "control: a card outside the base sets in the Bazaar's list")
	assert_eq(CardShop.copies_allowed(player), 1, "control: the starting deck is under 40 cards, no Tome")
	assert_gt(CardShop.in_deck(player, "Mountain"), 1, "control: more Mountains in the deck than its limit")
	var list := trader.find_child("TradeCards", true, false) as ItemList
	var shown := trader.cards()
	var at_basic := shown.find("Mountain")
	var at_outside := shown.find(outside)
	assert_gt(at_basic, -1, "control: Mountain in the list")
	assert_ne(list.get_item_custom_fg_color(at_basic), PaneStyle.FAINT, "a basic land: never dimmed")
	assert_eq(list.get_item_text(at_basic), "Mountain-%d" % int(owned["Mountain"]), "owned: its count")
	assert_eq(list.get_item_custom_fg_color(at_outside), PaneStyle.FAINT, "outside the base sets, under 40: none allowed")
	assert_eq(list.get_item_text(at_outside), outside, "none owned: no count")
