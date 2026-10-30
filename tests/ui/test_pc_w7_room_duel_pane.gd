extends GutTest
## BEFORE A ROOM'S DUEL (part C, stage C2, W7): [RoomDuelPane] — the
## contract the board calls (`make`, `chosen("duel")` once, the pane gone
## after), what the page shows (the creature's face, the stake or "No
## stake", the hero's cards in play, the minion and the card in effect, the
## life this duel starts with), 1997's words under it, no flight (Escape
## does nothing), "Duel" by a click, by its letter and Enter, by Enter
## alone, a double click's second press no choice, a stake drawn here only
## when none was, and the pane on the window at 1280 × 800 and 800 × 600,
## with and without the Big buttons.

var base: Dictionary
var player: AdventurePlayer
var viewport: SubViewport
var picked: Array = []


func before_all() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Delver"
	setup.color = "red"
	setup.difficulty = 2
	setup.walker = "male"
	setup.seed_text = "31337"
	var record := setup.resolve({})
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	base = JSON.parse_string(JSON.stringify(hero.to_dict()))


func before_each() -> void:
	player = AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(base)))
	_deck(_red_deck())
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	picked = []


func _red_deck() -> Array:
	var cards: Array = []
	for i in 12:
		cards.append("Mountain")
	for i in 6:
		cards.append("Lightning Bolt")
	for i in 4:
		cards.append("Hill Giant")
	return cards


func _deck(names: Array) -> void:
	player.cards = []
	for card_name in names:
		player.cards.append({"card": String(card_name), "decks": [0]})
	player.current_deck = 0


func _frames(count := 3) -> void:
	for i in count:
		await get_tree().process_frame


## The black castle's wizard's room (his minion, the castle's card in
## effect) as the board hands it over.
func _castle_run() -> Dictionary:
	var castle: Dictionary = player.world.encounters[0]
	castle["card_in_effect"] = 208
	return {"index": 0, "castle": true, "color": 1, "rules": 0x03,
		"monsters": DungeonBoard.creatures_for(MsvcRandom.new(5), 1, 0, true), "life_pool": 3,
		"dice_card": "", "code": DungeonBoard.WIZARD, "card_in_effect": 208}


## A dungeon's room barring black cards, no card in effect.
func _dungeon_run(rules := 0x11) -> Dictionary:
	(player.world.encounters[5] as Dictionary)["card_in_effect"] = -1
	return {"index": 5, "castle": false, "color": 1, "rules": rules,
		"monsters": DungeonBoard.creatures_for(MsvcRandom.new(9), 1, 0, false), "life_pool": -2,
		"dice_card": "", "code": 4, "card_in_effect": -1}


func _open(run: Dictionary, duel: Dictionary, k := 1.0) -> RoomDuelPane:
	var pane := RoomDuelPane.make(player, run, duel)
	assert_false(pane.is_inside_tree(), "make: not yet in the tree")
	pane.k = k
	pane.chosen.connect(func(what: String) -> void: picked.append(what))
	viewport.add_child(pane)
	PaneStyle.centre(pane)
	await _frames()
	return pane


func _staked(run: Dictionary) -> Dictionary:
	var duel := DungeonDuels.setup_room(player, run)
	assert_true(DungeonDuels.draw_stake(player, duel), "a stake drawn")
	return duel


func _key(code: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	viewport.push_input(down, true)
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	viewport.push_input(up, true)
	await _frames()


func _press(node: Control, double := false) -> void:
	var at := node.get_global_rect().get_center()
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.double_click = double and pressed
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.position = at
		click.global_position = at
		viewport.push_input(click, true)
	await _frames()


# ------------------------------------------------------------- the page --

func test_the_wizard_s_room_shows_his_face_the_stake_his_minion_and_the_card_in_effect() -> void:
	var run := _castle_run()
	run["dice_card"] = "Hill Giant"
	var duel := _staked(run)
	var pane := await _open(run, duel)
	assert_eq(pane.stage.ground_key(), "preduel_black", "the meeting's ground of the castle's colour")
	# The owner, 2026-10-30: "Yes, header = kind" — the banner names him.
	assert_eq(pane.title_text(), "Wizard", "the header says what he is")
	assert_eq(pane.subtitle_text(), "", "nothing under it")
	assert_not_null(pane.stage.part("CreatureName"), "its face's banner")
	var shown := pane.stage.cards_shown()
	assert_eq(String((duel["hero_ante"] as Array)[0]), pane.stake(), "the stake drawn is the one shown")
	assert_has(shown, pane.stake(), "the stake on the page")
	assert_not_null(pane.stage.part("Stake"))
	assert_ne(String(duel["minion"]), "", "a castle's wizard has his minion")
	assert_has(shown, String(duel["minion"]), "the minion under In Play")
	assert_has(shown, "Rod of Ruin", "the card in effect")
	assert_not_null(pane.stage.part("EffectFrame"), "in the board's marble frame")
	assert_has(shown, "Hill Giant", "the dice's card: the hero's in play")
	assert_eq((pane.stage.part("InPlayWords") as Label).text, RoomDuelPane.IN_PLAY)
	assert_eq(pane.words(), "\n".join(PackedStringArray(DungeonDuels.words(duel))), "1997's words under it")
	assert_eq(pane.choice_ids(), ["duel"] as Array[String], "one way on")
	assert_eq(pane.note(), "", "a stake: no note")
	var life := pane.stage.part("Life") as Label
	assert_true(life.text.ends_with(str(DungeonDuels.hero_life(player, run))),
		"the purse's life is this duel's: %s" % life.text)


func test_a_ban_that_leaves_nothing_to_stake_says_no_stake() -> void:
	var black: Array = []
	for i in 10:
		black.append("Swamp")
	for i in 6:
		black.append("Dark Ritual")
	_deck(black)
	var run := _dungeon_run()
	var duel := _staked(run)
	var pane := await _open(run, duel)
	assert_true(pane.stakes_nothing(), "cards to stake, none allowed")
	assert_eq(pane.stake(), "")
	assert_eq((pane.stage.part("NoStake") as Label).text, RoomDuelPane.NO_STAKE)
	assert_eq(pane.note(), RoomDuelPane.NO_STAKE_NOTE)
	assert_null(pane.stage.part("Minion"), "a dungeon never has a minion")
	assert_null(pane.stage.part("InPlayPlaque"), "nothing in play: no plaque")
	assert_eq(pane.stage.cards_shown(), [] as Array[String])


func test_the_pane_draws_nothing_the_stake_is_the_caller_s() -> void:
	var run := _dungeon_run(0x01)
	var duel := _staked(run)
	var stake := String((duel["hero_ante"] as Array)[0])
	var dice := player.dice
	var pane := await _open(run, duel)
	assert_eq(player.dice, dice, "no dice drawn by the pane")
	assert_eq(duel["hero_ante"], [stake], "the stake untouched")
	assert_eq(pane.stake(), stake, "the card shown is the card at stake")


func test_with_nothing_to_stake_at_all_it_says_1997_s_words_and_the_caller_reads_no_ante() -> void:
	_deck(["Mountain", "Mountain", "Mountain"])
	var run := _dungeon_run(0x01)
	var duel := DungeonDuels.setup_room(player, run)
	assert_false(DungeonDuels.draw_stake(player, duel), "the game over: the caller's end")
	var pane := await _open(run, duel)
	assert_true(bool(duel.get("no_ante", false)), "no_ante for the caller")
	assert_eq(pane.words(), CreatureMeeting.NO_ANTE[0])
	pane.choose(RoomDuelPane.DUEL)
	assert_eq(picked, [RoomDuelPane.DUEL], "still the one answer: the caller takes the end")


# ------------------------------------------------------------- the way on --

func test_escape_does_nothing_and_duel_answers_once() -> void:
	var run := _castle_run()
	var pane := await _open(run, _staked(run))
	await _key(KEY_ESCAPE)
	assert_true(is_instance_valid(pane) and pane.is_inside_tree(), "Escape: no flight")
	assert_eq(picked, [], "nothing chosen")
	pane.choose(RoomDuelPane.DUEL)
	assert_eq(picked, [RoomDuelPane.DUEL], "Duel")
	assert_true(pane.was_chosen())
	assert_false(pane.is_inside_tree(), "the pane takes itself away")
	pane.choose(RoomDuelPane.DUEL)
	assert_eq(picked.size(), 1, "once")


func test_a_click_on_duel_answers() -> void:
	var run := _castle_run()
	var pane := await _open(run, _staked(run))
	await _press(pane.choice("duel"))
	assert_eq(picked, [RoomDuelPane.DUEL])


func test_its_letter_lights_duel_and_enter_takes_it() -> void:
	var run := _castle_run()
	var pane := await _open(run, _staked(run))
	await _key(KEY_D)
	assert_eq(viewport.gui_get_focus_owner(), pane.choice("duel"), "D lights Duel")
	assert_eq(picked, [], "a letter never takes a choice by itself")
	await _key(KEY_ENTER)
	assert_eq(picked, [RoomDuelPane.DUEL])


func test_enter_alone_takes_the_only_choice() -> void:
	var run := _castle_run()
	await _open(run, _staked(run))
	await _key(KEY_ENTER)
	assert_eq(picked, [RoomDuelPane.DUEL])


## The board under the pane, hearing what keys reach it.
class Board extends Control:
	var heard: Array[int] = []

	func _unhandled_input(input: InputEvent) -> void:
		var key := input as InputEventKey
		if key != null and key.pressed:
			heard.append(key.keycode)


func test_the_board_under_it_hears_no_key() -> void:
	var board := Board.new()
	viewport.add_child(board)
	var run := _castle_run()
	await _open(run, _staked(run))
	for code in [KEY_UP, KEY_W, KEY_HOME, KEY_KP_7, KEY_ESCAPE, KEY_X]:
		await _key(code)
	assert_eq(board.heard, [] as Array[int], "no step, no leaving under the room's pane")
	assert_eq(picked, [], "and nothing chosen")


func test_a_double_click_s_second_press_is_no_choice() -> void:
	var run := _castle_run()
	var pane := await _open(run, _staked(run))
	await _press(pane.choice("duel"), true)
	assert_eq(picked, [], "the second press of a double click chooses nothing")


# ------------------------------------------------------------- the fit --

func test_the_pane_fits_the_window_with_and_without_big_buttons() -> void:
	for size in [Vector2i(1280, 800), Vector2i(800, 600)]:
		for k in [1.0, WorldHud.BIG]:
			viewport.size = size
			var run := _castle_run()
			run["dice_card"] = "Hill Giant"
			var pane := await _open(run, _staked(run), k)
			await _frames(4)
			var room := Rect2(Vector2.ZERO, Vector2(size))
			assert_true(room.encloses(pane.get_rect()), "%s at k %s: %s inside %s" % [size, k, pane.get_rect(), room])
			assert_true(pane.factor() >= StagePane.LEAST - 0.001 and pane.factor() <= StagePane.MOST + 0.001,
				"the page between the least and the most: %s" % pane.factor())
			pane.free()
