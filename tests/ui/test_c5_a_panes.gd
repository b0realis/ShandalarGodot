extends GutTest
## THE PLACES' PANES AFTER THE PLAYTEST OF PART B (campaign c5, fixer A):
##  - P2-1: a double click's second press on a place's pane ([VisitPane]) —
##    a ruled town's "Duel the creature." standing where a news flash's
##    Continue was, the news flash, a lair — was a choice: a duel the player
##    never chose.
##  - P2-2: a double click on a lost card's Continue ([RuledTownPane])
##    skipped the next lost card's picture.
##  - H3-2 / P3-6: a lair's card lost to a full bag (the treasure, the
##    waiting rare) said nothing [ours].
##  - P4-1: with big buttons the ruled town's 1997 page was drawn small (260·k
##    kept for the words and choices; they take far less).

## A world screen that counts its saves and its ends.
class Probe extends WorldScreen:
	var saves := 0
	var titles := 0

	func _write_autosave() -> String:
		saves += 1
		return super()

	func _go_to_title() -> void:
		titles += 1
		_leaving = true


const SAVES := "user://adventure_tests_c5_a_panes"

var viewport: SubViewport
var screen: Probe
var town := -1
var left: Array = []


func before_each() -> void:
	RuledTowns.forget()
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Town Freer"
	setup.color = "green"
	setup.difficulty = 0
	setup.walker = "female"
	setup.seed_text = "97531"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	screen = Probe.new()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.set_process(false)
	screen.player.monsters = [] as Array
	town = -1
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == ShandalarWorld.TOWN:
			town = slot
			break
	TownStatus.take(screen.world, town, 4)
	_deck()
	left = []


func after_each() -> void:
	RuledTowns.forget()
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


func _deck() -> void:
	var cards: Array = []
	for i in 10:
		cards.append("Forest")
	for card_name in ["Llanowar Elves", "Grizzly Bears", "Giant Growth", "Craw Wurm", "Shanodin Dryads",
			"War Mammoth"]:
		cards.append(card_name)
	screen.player.cards = []
	for card_name in cards:
		screen.player.cards.append({"card": String(card_name), "decks": [0]})
	screen.player.current_deck = 0


## The bag at its 500 cards.
func _fill_bag() -> void:
	while screen.player.cards.size() < AdventurePlayer.BAG_MOST:
		screen.player.cards.append({"card": "Forest", "decks": []})
	assert_eq(screen.player.bag_room(), 0)


func _tile() -> Vector2i:
	var site: Dictionary = screen.world.sites[town]
	return Vector2i(int(site["x"]), int(site["y"]))


func _press(node: Control) -> void:
	var at := node.get_global_rect().get_center()
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.position = at
		click.global_position = at
		viewport.push_input(click, true)


## A double click's second press (and its release) on [param node].
func _second_press(node: Control) -> void:
	var at := node.get_global_rect().get_center()
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.double_click = pressed
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.position = at
		click.global_position = at
		viewport.push_input(click, true)
	await _frames(3)


func _click(pane: Node, id: String) -> void:
	var button := pane.find_child("Choice_" + id, true, false) as Button
	assert_not_null(button, "a choice %s" % id)
	if button != null:
		_press(button)
	await _frames(3)


func _choice(pane: Node, id: String) -> Button:
	var button := pane.find_child("Choice_" + id, true, false) as Button
	assert_not_null(button, "a choice %s" % id)
	return button


## The town visited: its pane.
func _visit() -> VisitPane:
	var pane := screen.visit(_tile())
	await _frames(2)
	return pane


func _duel_pane() -> RuledTownPane:
	return screen.find_child("RuledTownPane", true, false) as RuledTownPane


## Lair event [param kind] entered as [method WorldScreen.enter_lair] enters
## one, [param reward] the card to be found at its end.
func _enter(kind: int, reward := "") -> LairPane:
	var names := LairEvent.TREASURE_NAMES if kind < LairEvent.RUINED_TOWER else LairEvent.NAMES
	var event := {"slot": 1, "color": 3, "event": kind, "name": names[kind], "reward": reward,
		"lair_rare": "", "oasis": -1}
	var pane := LairPane.new()
	pane.player = screen.player
	pane.event = event
	pane.place = LairPane.place_of(event)
	screen._visit = pane
	screen.add_child(pane)
	PaneStyle.centre(pane)
	pane.left.connect(func(then: String) -> void:
		left.append(then)
		screen._left_lair(then, 1), WorldScreen.CLOSING)
	screen._hold()
	await _frames(2)
	return pane


# ------------------------------------------ a place's double click (P2-1) --

func test_a_double_click_s_second_press_on_a_town_s_choice_is_no_choice() -> void:
	var pane := await _visit()
	assert_eq(String(pane.place["kind"]), "ruled")
	await _second_press(_choice(pane, "duel"))
	assert_null(_duel_pane(), "no duel the player never chose")
	assert_true(is_instance_valid(pane) and screen.visiting(), "the town's pane waits")
	await _click(pane, "duel")
	var duel := _duel_pane()
	assert_not_null(duel, "a click of its own: the duel")
	duel.duel_host().concede()
	await _frames(3)


func test_a_double_click_s_second_press_on_the_news_reads_nothing() -> void:
	var news := screen.show_news([{"kind": "siege", "lines": ["The Red Wizardess sends a Dragon."],
		"town": town}])
	assert_not_null(news)
	await _frames(2)
	await _second_press(_choice(news, "continue"))
	assert_true(screen.news_shown(), "the news waits to be read")
	await _click(news, "continue")
	assert_false(screen.news_shown(), "a click of its own reads it")


func test_a_double_click_s_second_press_on_a_lair_takes_no_card() -> void:
	var pane := await _enter(2, "Forest")
	await _second_press(_choice(pane, "leave"))
	assert_eq(left, [], "the lair waits")
	await _click(pane, "leave")
	await _frames(2)
	assert_eq(left, [""])


# -------------------------------------- a ruled town's lost cards (P2-2) --

func test_a_double_click_on_a_lost_card_s_continue_skips_no_picture() -> void:
	# A town whose x is 2 mod 3: three cards staked.
	TownStatus.release(screen.world, town)
	for slot in screen.world.sites.size():
		var site: Dictionary = screen.world.sites[slot]
		if int(site["type"]) in [ShandalarWorld.TOWN, ShandalarWorld.CITY] and int(site["x"]) % 3 == 2:
			town = slot
			break
	TownStatus.take(screen.world, town, 4)
	var pane := await _visit()
	var staked: Array = pane.ruled["hero_ante"]
	assert_eq(staked.size(), 3)
	await _click(pane, "duel")
	var duel := _duel_pane()
	duel.duel_host().concede()
	await _frames(3)
	assert_eq(duel.stage.cards_shown(), [String(staked[0])] as Array[String])
	await _click(duel, "go")
	assert_eq(duel.stage.cards_shown(), [String(staked[1])] as Array[String], "a click: the next")
	await _second_press(_choice(duel, "go"))
	assert_eq(duel.stage.cards_shown(), [String(staked[1])] as Array[String],
		"the double click's second press: the second card still shown")
	await _click(duel, "go")
	assert_eq(duel.stage.cards_shown(), [String(staked[2])] as Array[String], "the third, seen")
	await _click(duel, "go")
	await _frames(2)
	assert_false(screen.modal())


# ------------------------------------------- a lair's card, the bag full --

func test_a_lair_s_treasure_lost_to_a_full_bag_is_said() -> void:
	_fill_bag()
	var pane := await _enter(2, "Forest")
	assert_eq(pane.words(), LairEvent.FOUND)
	assert_eq(pane.shown_card(), "Forest")
	assert_eq(pane.note(), AdventurePlayer.BAG_FULL, "[ours] the bag full, said under it")
	await _click(pane, "leave")
	await _frames(2)
	assert_eq(left, [""])
	assert_eq(screen.player.cards.size(), AdventurePlayer.BAG_MOST, "lost, as 1997 lost it")


func test_a_lair_s_waiting_rare_lost_to_a_full_bag_is_said() -> void:
	_fill_bag()
	var pane := await _enter(LairEvent.GEMCUTTER, "Shivan Dragon")
	assert_eq(pane.note(), "", "the Gemcutter's offer first")
	await _click(pane, "leave")
	assert_eq(pane.words(), LairEvent.FOUND, "the waiting rare")
	assert_eq(pane.shown_card(), "Shivan Dragon")
	assert_eq(pane.note(), AdventurePlayer.BAG_FULL)


func test_a_lair_s_find_with_room_says_nothing_more() -> void:
	var pane := await _enter(2, "Forest")
	assert_eq(pane.words(), LairEvent.FOUND)
	assert_eq(pane.note(), "", "room in the bag: nothing more said")
	var owned := screen.player.cards.size()
	await _click(pane, "leave")
	await _frames(2)
	assert_eq(screen.player.cards.size(), owned + 1, "found")


# ----------------------------------- the ruled town's page, big (P4-1) --

func test_a_ruled_town_s_page_uses_the_room_with_big_buttons() -> void:
	screen.hud.big = true
	var pane := await _visit()
	await _click(pane, "duel")
	var duel := _duel_pane()
	assert_not_null(duel)
	assert_eq(duel.k, WorldHud.BIG)
	duel.duel_host().duel.game.concede(1)
	await _frames(6)
	assert_eq(duel.step, "freed")
	var guessed := (800.0 - 260.0 * WorldHud.BIG) / EncounterStage.PAGE.y
	gut.p("the freed page at %.3f (the old guess %.3f), the pane %s" % [duel._factor, guessed, duel.get_global_rect()])
	assert_gt(duel._factor, guessed + 0.15, "the page as large as the room the words and choices leave")
	var rect := duel.get_global_rect()
	assert_true(rect.position.y >= 0.0 and rect.end.y <= 800.0, "the pane on the screen: %s" % rect)
	assert_gt(rect.size.y, 800.0 - RuledTownPane.ROOM_MARGIN - 48.0, "the room used")
	await _click(duel, "go")
	await _frames(2)
	assert_false(screen.modal())


func test_a_ruled_town_s_page_keeps_to_the_screen_with_normal_buttons() -> void:
	var pane := await _visit()
	await _click(pane, "duel")
	var duel := _duel_pane()
	duel.duel_host().duel.game.concede(1)
	await _frames(6)
	assert_eq(duel.step, "freed")
	var rect := duel.get_global_rect()
	assert_true(rect.position.y >= 0.0 and rect.end.y <= 800.0, "the pane on the screen: %s" % rect)
	assert_true(duel._factor <= RuledTownPane.MOST + 0.001)
	await _click(duel, "go")
