extends GutTest
## THE TRADER'S SEARCH WITHOUT A STUTTER (0.60.15, the owner's ruling of
## 2026-11-03): with Packs 2–9 each keystroke in the trader's name box
## emptied and refilled its list of up to 3,039 names and laid them out in
## one frame of 77–158 ms (M1's baseline). Now the list follows the box
## after a short pause in the typing, keeps every row whose name stays, and
## a long list (card packs) is filled a slice a frame; the trader's list is
## made once for what it depends on. What the player sees once the list is
## set — rows, order, counts, dimming, the card chosen — is as before. The
## keys here are real, pushed through the viewport.

const SAVES := "user://adventure_tests_c29_S2_trader"

var viewport: SubViewport
var screen: WorldScreen
var _packs: Array[String] = []
## The pane's own numbers (read off its script: an older pane has none).
var _pane_consts: Dictionary = (load("res://game/adventure/world/card_trade_pane.gd") as Script).get_script_constant_map()
var rows_at_once := int(_pane_consts.get("ROWS_AT_ONCE", 0))
var rows_per_frame := int(_pane_consts.get("ROWS_PER_FRAME", 0))
var typing_pause := float(_pane_consts.get("TYPING_PAUSE", 0.0))


func before_each() -> void:
	_packs = Settings.enabled_card_packs().duplicate()
	AdventureSetup.forget()
	AdventurePlayer.saves_folder = SAVES


func after_each() -> void:
	_switch(_packs)
	AdventureSetup.forget()
	CardValue.forget()
	CardShop.forget()
	CardTrade.forget()
	LairEvent.forget()
	AdventurePacks.forget()
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _switch(on: Array) -> void:
	for id in CardPacks.available_ids():
		if CardPacks.is_enabled(id) != (id in on):
			CardPacks.set_enabled(id, id in on)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _hero(selected: Array) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.seed_text = "48271"
	var ids: Array[String] = []
	ids.assign(selected)
	setup.packs = ids
	var versions := {}
	for id in ids:
		versions[id] = "1"
	var record := setup.resolve(versions)
	return AdventurePlayer.begin(record, AdventureSetup.make_world(record))


## The Nomad's trader over the world screen in a viewport of its own (the
## real keys reach its name box).
func _world_trader() -> CardTradePane:
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
	viewport.notification(Node.NOTIFICATION_VP_MOUSE_ENTER)
	screen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.player.gold = 3000
	var trader := screen.open_trade(CardTrade.BAZAAR)
	await _frames(3)
	return trader


## A trader of [param player]'s on its own (no world screen).
func _pane(player: AdventurePlayer, way := CardTrade.BAZAAR) -> CardTradePane:
	var pane := CardTradePane.new()
	pane.player = player
	pane.way = way
	add_child_autofree(pane)
	return pane


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


func _click_at(at: Vector2) -> void:
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.position = at
		click.global_position = at
		viewport.push_input(click, true)
	await _frames(2)


## The list's rows as the player reads them: "name" or "name-N", and
## whether dimmed.
func _rows(pane: CardTradePane) -> Array[String]:
	var list := pane.find_child("TradeCards", true, false) as ItemList
	var out: Array[String] = []
	for i in list.item_count:
		out.append("%s|%s" % [list.get_item_text(i), list.get_item_custom_fg_color(i) == PaneStyle.FAINT])
	return out


## The rows the list must come to for [param pane]'s cards now, as the old
## pane built them all at once (the copies owned, 1997's dimming).
func _expected(pane: CardTradePane) -> Array[String]:
	var player := pane.player
	var owned := AdventureBuilder.owned_counts(player)
	var in_deck := CardShop.counted_copies(player)
	var limit := CardShop.copies_allowed(player)
	var facts := {}
	for row in CardTrade.for_trader(player, pane.way):
		facts[row["name"]] = row["facts"]
	var out: Array[String] = []
	for card_name in pane.cards():
		var count := int(owned.get(card_name, 0))
		var faint := player.card_rule != AdventurePlayer.RULE_CLASSIC \
			and CardShop.copies_left(player, card_name, facts.get(card_name, {}), in_deck, limit) <= 0
		out.append("%s|%s" % ["%s-%d" % [card_name, count] if count > 0 else card_name, faint])
	return out


## "" when [param got] and [param want] are the same rows, else the first
## difference (a failure names it without printing thousands of rows).
func _differ(got: Array, want: Array) -> String:
	for i in mini(got.size(), want.size()):
		if got[i] != want[i]:
			return "row %d: %s, not %s" % [i, got[i], want[i]]
	if got.size() != want.size():
		return "%d rows, not %d" % [got.size(), want.size()]
	return ""


func test_the_list_follows_the_name_box_after_a_pause_in_the_typing() -> void:
	var trader := await _world_trader()
	var box := trader.find_child("TradeSearch", true, false) as LineEdit
	var list := trader.find_child("TradeCards", true, false) as ItemList
	await _click_at(box.get_global_rect().get_center())
	assert_true(box.has_focus(), "control: clicked into the box")
	assert_almost_eq(typing_pause, 0.15, 0.001, "the owner's ~150 ms")
	# A longer pause here, so that a slow frame of a loaded test machine
	# cannot end it between two keys.
	var pause := trader.find_child("TypingPause", true, false) as Timer
	assert_not_null(pause, "the pane's typing pause")
	if pause == null:
		return
	pause.wait_time = 1.0
	var shown := trader._shown
	var rows := list.item_count
	for letter in "serra":
		await _key(OS.find_keycode_from_string(letter.to_upper()), letter)
		assert_true(is_same(trader._shown, shown), "no list made at '%s': the typing goes on" % box.text)
		assert_eq(list.item_count, rows, "the rows untouched while typing")
	assert_eq(box.text, "serra", "control: the name typed")
	assert_true(trader.cards().size() < rows, "control: the name narrows the cards")
	await get_tree().create_timer(pause.wait_time + 0.2).timeout
	await _frames(2)
	assert_false(is_same(trader._shown, shown), "the pause over: the list follows")
	assert_eq(_differ(trader._shown, trader.cards()), "", "every card of the name typed")
	assert_eq(_differ(_rows(trader), _expected(trader)), "", "and its rows")
	# One more key, one more list after the pause; Escape at once.
	await _key(KEY_BACKSPACE)
	shown = trader._shown
	await _key(KEY_ESCAPE)
	assert_true(screen.trading(), "control: Escape clears the name first")
	assert_eq(box.text, "")
	assert_false(is_same(trader._shown, shown), "Escape's whole list comes at once")
	assert_eq(_differ(trader._shown, trader.cards()), "")


func test_rows_that_stay_are_kept() -> void:
	var player := _hero([])
	player.gold = 100000
	var pane := _pane(player)
	var list := pane.find_child("TradeCards", true, false) as ItemList
	for i in list.item_count:
		list.set_item_metadata(i, i)
	pane.refresh()
	assert_eq(list.get_item_metadata(10), 10, "nothing changed: the row is the same row")
	assert_eq(list.get_item_metadata(list.item_count - 1), list.item_count - 1)
	# A trade made: only the card bought's row reads "-1" now.
	var owned := AdventureBuilder.owned_counts(player)
	var at := 20
	while owned.has(pane._shown[at]):
		at += 1
	var card: String = pane._shown[at]
	pane.choose(card)
	pane.trade_chosen()
	assert_eq(list.get_item_text(at), card + "-1", "control: the copy owned shows")
	for i in [0, at - 1, at, at + 1, list.item_count - 1]:
		assert_eq(list.get_item_metadata(i), i, "row %d kept after a trade" % i)
	assert_eq(_differ(_rows(pane), _expected(pane)), "", "the rows after the trade")
	# A narrowed name: the rows whose names stay in their places are kept.
	var keep := 0
	for i in pane._shown.size():
		if not pane._shown[i].to_lower().contains("a"):
			break
		keep += 1
	assert_gt(keep, 0, "control: the list begins with names holding an 'a'")
	pane._search.text = "a"
	pane.refresh()
	assert_eq(list.get_item_metadata(keep - 1), keep - 1, "a row whose name stays is kept")
	assert_eq(_differ(_rows(pane), _expected(pane)), "", "the base game's list: all at once, as before")


func test_a_long_list_fills_a_slice_a_frame_and_comes_to_the_whole_list() -> void:
	_switch(["pack-8"])
	var player := _hero(["pack-8"])
	assert_gt(CardTrade.for_trader(player, CardTrade.BAZAAR).size(), rows_at_once,
		"control: Mirage's cards make a long list")
	var pane := _pane(player)
	var list := pane.find_child("TradeCards", true, false) as ItemList
	await _frames(30)
	assert_eq(_differ(_rows(pane), _expected(pane)), "", "control: the whole list once filled")
	pane._search.text = "zzz"
	pane.refresh()
	await _frames(5)
	assert_eq(list.item_count, 0, "control: no card of that name")
	pane._search.text = ""
	pane.refresh()
	var all := pane._shown.size()
	assert_eq(all, pane.cards().size(), "every card's name at once")
	assert_eq(list.item_count, rows_per_frame, "one slice of rows at once, not %d" % all)
	await _frames(1)
	assert_between(list.item_count, rows_per_frame + 1, all - 1, "a slice a frame")
	await _frames(30)
	assert_eq(_differ(_rows(pane), _expected(pane)), "", "the whole list, as built at once before")
	# A row not filled yet (an older list's name) answers no click.
	pane.color_filter = 8
	pane._sync_chips()
	pane.refresh()
	assert_gt(list.item_count, pane._shown.size(), "control: the rows past the slice not set yet")
	list.item_selected.emit(list.item_count - 1)
	assert_eq(pane.chosen, "", "a row still to fill is no choice")
	assert_false(list.is_selected(list.item_count - 1))
	await _frames(30)
	assert_eq(_differ(_rows(pane), _expected(pane)), "", "the green cards, as built at once before")
	pane.color_filter = 0
	pane._sync_chips()
	pane.refresh()
	await _frames(30)
	# The card chosen stays chosen through a slow fill, and is selected.
	var far: String = pane._shown[all - 5]
	pane.choose(far)
	pane._search.text = far.substr(0, 3)
	pane.refresh()
	pane._search.text = ""
	pane.refresh()
	await _frames(30)
	assert_eq(pane.chosen, far)
	assert_eq(Array(list.get_selected_items()), [all - 5], "the card chosen selected in its place")
	assert_eq(_differ(_rows(pane), _expected(pane)), "", "the whole list again")


func test_the_base_game_s_list_is_set_at_once_as_before() -> void:
	var player := _hero([])
	var pane := _pane(player)
	assert_lt(CardTrade.for_trader(player, CardTrade.BAZAAR).size(), 1000, "control: the base game's list")
	pane._search.text = "zzz"
	pane.refresh()
	pane._search.text = ""
	pane.refresh()
	assert_eq(_differ(_rows(pane), _expected(pane)), "", "every row the moment the list changes")


func test_a_trader_s_list_is_made_once_for_what_it_reads() -> void:
	_switch(["pack-3", "pack-8"])
	var player := _hero(["pack-3"])
	var first := CardTrade.for_trader(player, CardTrade.TOWN)
	assert_true(is_same(CardTrade.for_trader(player, CardTrade.TOWN), first), "asked again: the same list")
	assert_true(is_same(CardTrade.for_trader(player, CardTrade.MINE), first), "the same for every paid trader")
	var names := first.map(func(row: Dictionary) -> String: return row["name"])
	assert_has(names, "Necropotence", "control: Ice Age's")
	assert_eq(first.size(), AdventurePacks.add_stock(player, CardTrade.catalogue()).size(), "the very rows add_stock gives")
	var other := _hero(["pack-8"])
	var mirage := CardTrade.for_trader(other, CardTrade.TOWN)
	assert_has(mirage.map(func(row: Dictionary) -> String: return row["name"]), "Lion's Eye Diamond",
		"another campaign's packs: its own list")
	assert_does_not_have(mirage.map(func(row: Dictionary) -> String: return row["name"]), "Necropotence")
	player.all_trader_cards = true
	assert_false(is_same(CardTrade.for_trader(player, CardTrade.TOWN), first), "all trader cards: another list")
	assert_true(is_same(CardTrade.for_trader(player, CardTrade.REWARD), first), "the reward keeps the original cards")
	player.all_trader_cards = false
	_switch(["pack-8"])
	var after := CardTrade.for_trader(player, CardTrade.TOWN)
	assert_does_not_have(after.map(func(row: Dictionary) -> String: return row["name"]), "Necropotence",
		"Pack 3 switched off: the list follows the card pool")
	# By name at once (CardTrade.offered_by; read off the script: an older
	# CardTrade has none).
	var trade_script: Script = load("res://game/adventure/card_trade.gd")
	assert_true(trade_script.has_method("offered_by"), "a name looked up at once")
	if trade_script.has_method("offered_by"):
		assert_true(trade_script.call("offered_by", player, CardTrade.TOWN, "Grizzly Bears"))
		assert_false(trade_script.call("offered_by", player, CardTrade.TOWN, "Necropotence"))
