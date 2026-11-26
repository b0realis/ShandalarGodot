extends GutTest
## A CARD QUEST'S CARD IS THE HERO'S TO CHOOSE, ON SCREEN (a player's
## report, 2026-11-26: a Regrowth taken unasked on walking into the town;
## the owner: a picker) — [QuestCardPane] over the town's pane
## ([method WorldScreen.open_quest_card]):
##   1. arriving with cards that fit takes nothing: the pane lists them,
##      the ones to spare first;
##   2. the keys alone: Down, Enter chooses, Enter gives — the quest done
##      with the keeper's words naming the card;
##   3. Escape puts a chosen card back, then is "Not now": the quest under
##      way, the town's own choice opens the pane again;
##   4. a controller alone: First choice (X) points and clicks a row, A on
##      "Give this card" gives it;
##   5. arriving with no such card says why, and asks nothing;
##   6. every card of the kind at once still fits the screen.

const SAVES := "user://adventure_tests_c1127_quest_pane"

var screen: WorldScreen
var layer: Node
var destination := -1
var fits: Array[String] = []
var other := ""
var _saved_pad: Variant = null
var _saved_controls: Variant = null
## GUT's own panel over the window, put away while a test points in it.
var _gut_layer: CanvasLayer


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	TileReveal.forced = 0
	layer = get_tree().root.get_node_or_null("PadControls")
	_saved_pad = Settings.get_value(PadControls.KEY, null) if Settings.has_value(PadControls.KEY) else null
	_saved_controls = Settings.get_value(Controls.SETTINGS_KEY, null) \
		if Settings.has_value(Controls.SETTINGS_KEY) else null
	Controls.reset()
	get_viewport().gui_release_focus()
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	screen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.record = setup.resolve({})
	add_child_autofree(screen)
	await wait_process_frames(3)
	# The world's clock stands: no tick spends the quest's days.
	screen.set_process(false)
	screen._shield_until = 0
	var player := screen.player
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == ShandalarWorld.TOWN and not TownStatus.linked(screen.world, slot) \
				and not TownStatus.ruled(screen.world, slot):
			destination = slot
			break
	player.quest = {"type": Quests.CARD, "destination": destination, "giver": 0, "color": 4, "data": -1,
		"deadline": player.quest_timer + 79}
	var wanted := Quests.card_class(destination)
	var priced: Array = []
	fits.clear()
	other = ""
	for card_name in CardRegistry.all_names():
		if not CardTrade.in_adventure(String(card_name)):
			continue
		var f := CardValue.facts(CardRegistry.get_card(card_name))
		if int(f.get("color", 0)) & 16 != 0 and int(f.get("type", 0)) & wanted != 0:
			priced.append([CardValue.price_of(f), String(card_name)])
		elif other == "" and int(f.get("color", 0)) & 16 == 0 and int(f.get("type", 0)) & CardValue.LAND == 0:
			other = String(card_name)
	priced.sort()
	for entry: Array in priced:
		fits.append(String(entry[1]))


func after_each() -> void:
	if _gut_layer != null:
		_gut_layer.visible = true
	_gut_layer = null
	if _saved_pad == null:
		Settings.clear_value(PadControls.KEY)
	else:
		Settings.set_value(PadControls.KEY, _saved_pad)
	layer.apply_settings()
	Controls.reset()
	if _saved_controls != null:
		Settings.set_value(Controls.SETTINGS_KEY, _saved_controls)
		Controls.apply()
	TileReveal.forced = -1
	await wait_process_frames(2)
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _tile(slot: int) -> Vector2i:
	return Vector2i(int(screen.world.sites[slot]["x"]), int(screen.world.sites[slot]["y"]))


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.pressed = pressed
		Input.parse_input_event(key)
		Input.flush_buffered_events()


func _pad(button: int) -> void:
	for pressed in [true, false]:
		var jb := InputEventJoypadButton.new()
		jb.device = 0
		jb.button_index = button as JoyButton
		jb.pressed = pressed
		Input.parse_input_event(jb)
		Input.flush_buffered_events()
		layer.flush()
		Input.flush_buffered_events()


func _held() -> Control:
	return get_viewport().gui_get_focus_owner()


## The hero holds a cheap spare card of the kind, a dear one in deck 1 and
## one that does not fit; they walk into the quest's town.
func _arrive() -> QuestCardPane:
	var player := screen.player
	player.cards = [{"card": fits[fits.size() - 1], "decks": [0]}, {"card": other, "decks": [0]},
		{"card": fits[0], "decks": []}, {"card": fits[1], "decks": []}]
	screen.visit(_tile(destination))
	await wait_process_frames(2)
	return screen._quest_card


func test_arriving_takes_nothing_and_asks_which_card() -> void:
	var player := screen.player
	var pane := await _arrive()
	assert_true(WorldScreen._alive(pane), "the pane is up")
	assert_eq(player.cards.size(), 4, "nothing taken")
	assert_true(Quests.has_quest(player), "the quest under way")
	assert_false(screen._visit.visible, "the town waits under it")
	assert_true(screen.modal())
	assert_eq(pane.names(), [fits[0], fits[1], fits[fits.size() - 1]] as Array[String],
		"the spare ones first, the cheapest on top; the deck's card last")
	var facts := (pane.find_child("Row_2", true, false) as Button).find_child("RowFacts", true, false) as Label
	assert_string_contains(facts.text, "1 owned")
	assert_string_contains(facts.text, "Deck 1")
	assert_string_contains(facts.text, "gold")
	assert_string_contains((pane.find_child("QuestCardAsks", true, false) as Label).text,
		Quests.spell_name(4, destination))
	assert_true((pane.find_child("QuestCardGive", true, false) as Button).disabled, "nothing chosen yet")
	assert_eq(pane.shown_large(), fits[0], "the first card shown large")
	var shown := get_viewport().get_visible_rect().size
	assert_lte(pane.size.x, shown.x, "inside the screen")
	assert_lte(pane.size.y, shown.y)


func test_the_keys_alone_choose_and_give() -> void:
	var player := screen.player
	var pane := await _arrive()
	assert_eq(_held(), pane.find_child("Row_0", true, false), "the first row holds the keys")
	_key(KEY_DOWN)
	_key(KEY_DOWN)
	assert_eq(_held(), pane.find_child("Row_2", true, false))
	assert_eq(pane.shown_large(), fits[fits.size() - 1], "the row the keys are on, large")
	_key(KEY_ENTER)
	var dear := fits[fits.size() - 1]
	assert_eq(pane.chosen, dear)
	assert_eq(pane.ask_text(), "Give %s? It is your only copy. It leaves Deck 1." % dear)
	assert_eq(player.cards.size(), 4, "chosen is not given")
	assert_eq(_held(), pane.find_child("QuestCardGive", true, false), "the keys on Give this card")
	var red := int(player.amulets["red"])
	_key(KEY_ENTER)
	await wait_process_frames(3)
	assert_false(WorldScreen._alive(pane), "the pane is gone")
	assert_false(Quests.has_quest(player), "the quest is done")
	assert_eq(player.cards.size(), 3)
	for entry: Dictionary in player.cards:
		assert_ne(String(entry["card"]), dear, "the card chosen went")
	assert_eq(int(player.amulets["red"]), red + 1)
	assert_true(TownStatus.linked(screen.world, destination))
	var town := screen._visit as VisitPane
	assert_true(town != null and town.visible, "the town again")
	assert_string_contains(town.words(), "The people are pleased to receive the %s spell." % dear)
	assert_null(town.find_child("Choice_" + WorldScreen.QUEST_CARD_ACTION, true, false), "no card asked any more")
	assert_eq(String(player.journal[player.journal.size() - 1].get("text", "")),
		"Completed quest at %s" % WorldNames.site_name(screen.world, destination))


func test_escape_puts_the_card_back_then_is_not_now() -> void:
	var player := screen.player
	var pane := await _arrive()
	_key(KEY_ENTER)
	assert_eq(pane.chosen, fits[0])
	_key(KEY_ESCAPE)
	assert_eq(pane.chosen, "", "the card put back")
	assert_true(WorldScreen._alive(pane), "the pane stays")
	_key(KEY_ESCAPE)
	await wait_process_frames(3)
	assert_false(WorldScreen._alive(pane), "Not now")
	assert_eq(player.cards.size(), 4, "nothing given")
	assert_true(Quests.has_quest(player), "the quest still under way")
	var town := screen._visit as VisitPane
	assert_true(town.visible, "the town's pane")
	assert_string_contains(town.words(), Quests.NOT_GIVEN_WORDS % Quests.spell_name(4, destination))
	# The town's own choice opens it again; so does coming back to the town.
	var choice := town.find_child("Choice_" + WorldScreen.QUEST_CARD_ACTION, true, false) as Button
	assert_not_null(choice, "Give a card for the quest")
	assert_eq(choice.text, WorldScreen.QUEST_CARD_CHOICE)
	choice.pressed.emit()
	await wait_process_frames(2)
	assert_true(WorldScreen._alive(screen._quest_card), "the pane again")
	(screen._quest_card.find_child("QuestCardNotNow", true, false) as Button).pressed.emit()
	await wait_process_frames(3)
	assert_false(WorldScreen._alive(screen._quest_card))
	assert_eq(player.cards.size(), 4)
	assert_true(Quests.has_quest(player))


func test_a_controller_alone_chooses_and_gives() -> void:
	_gut_layer = get_tree().root.find_child("GutLayer", true, false) as CanvasLayer
	if _gut_layer != null:
		_gut_layer.visible = false
	Settings.set_value(PadControls.KEY, PadControls.ON)
	layer.apply_settings()
	var player := screen.player
	var pane := await _arrive()
	# First choice: the pointer on the first row, then that row taken.
	_pad(JOY_BUTTON_X)
	await wait_process_frames(2)
	assert_true(layer.is_on(pane.find_child("Row_0", true, false)), "the pointer on the first row")
	_pad(JOY_BUTTON_X)
	await wait_process_frames(2)
	assert_eq(pane.chosen, fits[0])
	assert_eq(player.cards.size(), 4)
	# Down the rows by the D-pad: a hop a row.
	_pad(JOY_BUTTON_DPAD_DOWN)
	await wait_process_frames(1)
	assert_true(layer.is_on(pane.find_child("Row_1", true, false)), "the D-pad hops to the next row")
	_pad(JOY_BUTTON_A)
	await wait_process_frames(2)
	assert_eq(pane.chosen, fits[1], "A chooses the row under the pointer")
	layer.point_at(pane.find_child("QuestCardGive", true, false))
	layer.flush()
	await wait_process_frames(1)
	_pad(JOY_BUTTON_A)
	await wait_process_frames(3)
	assert_false(WorldScreen._alive(pane))
	assert_false(Quests.has_quest(player), "given")
	assert_eq(player.cards.size(), 3)
	for entry: Dictionary in player.cards:
		assert_ne(String(entry["card"]), fits[1])


func test_arriving_with_no_such_card_says_why() -> void:
	var player := screen.player
	player.cards = [{"card": other, "decks": [0]}]
	var town := screen.visit(_tile(destination))
	await wait_process_frames(2)
	assert_false(WorldScreen._alive(screen._quest_card), "nothing asked")
	assert_true(town.visible)
	assert_eq(town.words(), Quests.NO_CARD_WORDS % Quests.spell_name(4, destination))
	assert_null(town.find_child("Choice_" + WorldScreen.QUEST_CARD_ACTION, true, false))
	assert_true(Quests.has_quest(player))
	assert_eq(player.cards.size(), 1)


func test_every_card_of_the_kind_at_once() -> void:
	var player := screen.player
	player.cards = []
	for card_name in fits:
		player.cards.append({"card": card_name, "decks": []})
		player.cards.append({"card": card_name, "decks": [1]})
	var began := Time.get_ticks_msec()
	screen.visit(_tile(destination))
	var took := Time.get_ticks_msec() - began
	await wait_process_frames(2)
	var pane := screen._quest_card
	assert_eq(pane.names().size(), fits.size(), "a row a name")
	gut.p("%d rows in %d ms" % [fits.size(), took])
	var shown := get_viewport().get_visible_rect().size
	assert_lte(pane.size.x, shown.x, "inside the screen")
	assert_lte(pane.size.y, shown.y)
	# The keys walk past the rows in sight: the list follows.
	for i in 14:
		_key(KEY_DOWN)
	await wait_process_frames(2)
	var row := pane.find_child("Row_%d" % mini(14, fits.size() - 1), true, false) as Button
	assert_eq(_held(), row)
	var well := (pane.find_child("QuestCards", true, false) as Control).get_global_rect()
	assert_true(well.grow(2).encloses(row.get_global_rect()), "the row the keys are on is in sight")
