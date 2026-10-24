extends GutTest
## A CREATURE MET ON THE WORLD (part B, W5, 2026-10-23): the world screen's
## hook ([method WorldScreen.meet_creature] → [method WorldEncounters.open])
## and the meeting's pane ([EncounterPane]) through the viewport — the
## world held while it lasts, the choices clicked, Escape at each step, the
## duel held over the world ([WorldDuels]) and conceded or won, the spoils'
## panes, `finished` once, the slot spent, and "Return to main menu" saving
## nothing.

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


const SAVES := "user://adventure_tests_b_w5_encounter"

var viewport: SubViewport
var screen: Probe
var results: Array = []
## The creature met (its record in the slot).
var met := {}


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Pane Walker"
	setup.color = "red"
	setup.difficulty = 0
	setup.walker = "male"
	setup.seed_text = "2468"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	screen = Probe.new()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.player.monsters = [] as Array
	screen.player.monster_timer = 4   # not a special meeting
	screen.player.gold = 1000
	_deck()
	results = []


func after_each() -> void:
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


func _deck(names: Array = []) -> void:
	var cards := names
	if cards.is_empty():
		for i in 10:
			cards.append("Mountain")
		for i in 6:
			cards.append("Lightning Bolt")
		for i in 4:
			cards.append("Hill Giant")
	screen.player.cards = []
	for card_name in cards:
		screen.player.cards.append({"card": String(card_name), "decks": [0]})
	screen.player.current_deck = 0


func _no_hints() -> void:
	for slot in screen.world.encounters:
		(slot as Dictionary)["clues"] = 7


## A creature [param row] of colour [param color] in slot 0 by the hero, met.
func _meet(row := 1, color := 1) -> EncounterPane:
	var at := screen.player.position + Vector2i(6, 0)
	met = {"slot": 0, "kind": "creature", "creature": row, "x": at.x, "y": at.y,
		"color": color, "heading": 0, "frame": 0}
	screen.player.monsters.append(met)
	var pane := screen.meet_creature(0) as EncounterPane
	assert_not_null(pane, "the meeting's pane")
	if pane != null:
		pane.finished.connect(func(result: int) -> void: results.append(result))
	await _frames()
	return pane


func _press(node: Control, button := MOUSE_BUTTON_LEFT) -> void:
	var at := node.get_global_rect().get_center()
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = button
		click.pressed = pressed
		click.button_mask = (MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) \
			if pressed else 0
		click.position = at
		click.global_position = at
		viewport.push_input(click, true)


## The tune [param key] the pane plays: none with the music off, or without
## the 1997 skin that holds it (the gate runs with no skin).
func _tune(key: String) -> String:
	return key if Settings.music_enabled() and GameSkin.sound(key) != null else ""


func _choose(pane: EncounterPane, id: String) -> void:
	var button := pane.find_child("Choice_" + id, true, false) as Button
	assert_not_null(button, "a choice %s among %s" % [id, pane.choice_ids()])
	if button != null:
		_press(button)
	await _frames()


func _escape() -> void:
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	viewport.push_input(esc, true)
	var up := esc.duplicate() as InputEventKey
	up.pressed = false
	viewport.push_input(up, true)
	await _frames()


## Whether the creature met has left its slot (the world may fill the slot
## again on its next tick: the record met is the one looked for).
func _slot_spent() -> bool:
	for held in screen.player.monsters:
		if is_same(held, met):
			return false
	return true


## Continue clicked until the meeting ends (at most [param most] times).
func _on_to_the_end(pane: Variant, most := 12) -> void:
	for i in most:
		if not is_instance_valid(pane) or (pane as EncounterPane).done():
			return
		var go := (pane as EncounterPane).find_child("Choice_go", true, false) as Button
		if go == null:
			return
		_press(go)
		await _frames()


# --------------------------------------------------------- the meeting --

func test_a_meeting_holds_the_world_and_a_bribe_spends_the_slot() -> void:
	var pane := await _meet()
	assert_true(screen.modal(), "the meeting holds the world")
	assert_eq(pane.choice_ids(), ["duel", "pay"] as Array[String])
	assert_eq(pane.stage.ground_key(), "preduel_black")
	assert_eq(pane.stage.cards_shown().size(), 2, "both stakes on the page")
	assert_eq(pane.music_key(), _tune("music_duel"))
	await _escape()
	assert_true(is_instance_valid(pane) and not pane.done(), "Escape: no flight from a met creature")
	await _choose(pane, "pay")
	await _frames(3)
	assert_eq(results, [EncounterPane.NO_DUEL], "finished once, no duel")
	assert_eq(screen.player.gold, 960)
	assert_true(_slot_spent(), "the creature is gone")
	assert_false(screen.modal(), "the world again")
	assert_false(is_instance_valid(pane) and not pane.is_queued_for_deletion(), "the pane freed itself")


func test_a_card_on_the_page_is_read_by_a_right_click() -> void:
	var pane := await _meet()
	var read: Array = []
	pane.card_read.connect(func(card_name: String) -> void: read.append(card_name))
	var card := pane.stage.part("HeroAnte0") as Control
	assert_not_null(card)
	_press(card, MOUSE_BUTTON_RIGHT)
	await _frames()
	assert_eq(read, [String((pane.meeting["hero_ante"] as Array)[0])])


func test_the_pane_moves_by_a_drag_on_its_glass() -> void:
	var pane := await _meet()
	var title := pane.find_child("EncounterTitle", true, false) as Control
	var from := title.get_global_rect().get_center()
	var before := pane.global_position
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.position = from
	press.global_position = from
	viewport.push_input(press, true)
	var motion := InputEventMouseMotion.new()
	motion.position = from + Vector2(-60, 30)
	motion.global_position = motion.position
	motion.relative = Vector2(-60, 30)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(motion, true)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	release.button_mask = 0
	release.position = motion.position
	release.global_position = motion.position
	viewport.push_input(release, true)
	await _frames()
	assert_eq(pane.global_position, before + Vector2(-60, 30))
	assert_true(screen.modal(), "moved, not closed")


# ------------------------------------------------------------- the duel --

func test_a_conceded_duel_loses_the_stake() -> void:
	var pane := await _meet()
	var staked := String((pane.meeting["hero_ante"] as Array)[0])
	var owned := screen.player.cards.size()
	await _choose(pane, "duel")
	var host := pane.duel_host()
	assert_not_null(host, "the duel over the world")
	assert_false(pane.visible, "the pane waits hidden")
	assert_true(screen.modal())
	assert_false(screen.view.visible, "the world covered by the duel")
	assert_true(WorldLairs.held_in(screen.player, 0).size() > 0, "the creature is met only after")
	host.concede()
	await _frames()
	assert_true(pane.visible)
	assert_eq(pane.step, "lost")
	assert_eq(pane.stage.ground_key(), "lose_card")
	assert_eq(pane.stage.cards_shown(), [staked] as Array[String])
	assert_string_contains(pane.words(), "Lost this card")
	assert_eq(pane.music_key(), _tune("music_lose_duel"))
	await _on_to_the_end(pane)
	await _frames(3)
	assert_eq(results, [EncounterPane.LOST])
	assert_eq(screen.player.cards.size(), owned - 1)
	assert_eq(String(screen.player.journal[-1]["text"]), "Lost to a Witch")
	assert_true(_slot_spent())
	assert_true(screen.view.visible, "the world again")
	assert_false(screen.modal())


## The bug pass of part B (q2-1): a duel already won — its End of Duel
## window up, the pause key's Exit duel still offered — keeps its result
## when that Exit duel's Yes concedes: no stake lost, the spoils paid.
func test_a_duel_already_won_is_not_conceded() -> void:
	_no_hints()
	var pane := await _meet()
	var owned := screen.player.cards.size()
	await _choose(pane, "duel")
	var host := pane.duel_host()
	# Over, the hero the winner, the window not yet closed.
	host.duel.game.winner = 0
	host.duel.game.game_over = true
	host.concede()
	assert_false(host.conceded, "a finished duel is not conceded")
	await _frames(3)
	assert_eq(pane.step, "cards", "the spoils of a win")
	await _on_to_the_end(pane)
	await _frames(3)
	assert_eq(results, [EncounterPane.WON])
	assert_gt(screen.player.cards.size(), owned, "cards won, none lost")


func test_a_won_duel_shows_the_cards_won() -> void:
	_no_hints()
	var pane := await _meet()
	var owned := screen.player.cards.size()
	await _choose(pane, "duel")
	pane.duel_host().duel.game.concede(1)
	await _frames(3)
	assert_eq(pane.step, "cards")
	assert_eq(pane.stage.ground_key(), "win_back_cards")
	var won: Array = pane.spoils["cards"]
	assert_eq(pane.stage.cards_shown(), Array(won) as Array[String])
	assert_eq(pane.words(), "Won these cards.")
	assert_eq(pane.music_key(), _tune("music_win_duel"))
	var spoils := pane.spoils
	await _on_to_the_end(pane)
	await _frames(3)
	assert_eq(results, [EncounterPane.WON])
	assert_eq(screen.player.cards.size(), owned + won.size() + (1 if spoils["reward_card"] != "" else 0))
	assert_eq(screen.player.total_wins(), 1)
	assert_true(_slot_spent())


func test_escape_at_the_plaque_takes_the_cards() -> void:
	for slot in screen.world.encounters:
		(slot as Dictionary)["clues"] = 0
	var pane := await _meet()
	var owned := screen.player.cards.size()
	await _choose(pane, "duel")
	pane.duel_host().duel.game.concede(1)
	await _frames(3)
	assert_eq(pane.choice_ids(), ["cards", "clue"] as Array[String])
	assert_not_null(pane.stage.part("EndPlaque"), "the dungeon's plaque")
	var spoils := pane.spoils
	var hint := int(spoils["hint"])
	await _escape()
	# [ours: 1997 slip — Escape took the clue and forfeited the cards.]
	assert_eq(spoils["took"], "cards")
	assert_gte(screen.player.cards.size(), owned + (spoils["cards"] as Array).size())
	assert_ne(int(screen.world.encounters[hint]["rules"]) & WorldClues.CARDS_TAKEN, 0)
	await _on_to_the_end(pane)
	await _frames(3)
	assert_eq(results, [EncounterPane.WON])


func test_the_special_meetings_line_before_the_duel() -> void:
	screen.player.monster_timer = 0
	var pane := await _meet(10, 5)   # a Crusader
	await _choose(pane, "duel")
	assert_eq(pane.step, "special")
	assert_eq(pane.words(), "Crusader has First Strike!")
	await _choose(pane, "fight")
	var host := pane.duel_host()
	assert_not_null(host)
	assert_eq(host.config.first_player, 1)
	assert_eq(host.duel.game.active_player, 1, "the Crusader moves first")
	host.concede()
	await _on_to_the_end(pane)


func test_return_to_main_menu_saves_nothing_and_finishes_nothing() -> void:
	var pane := await _meet()
	var saved := screen.saves
	await _choose(pane, "duel")
	var host := pane.duel_host()
	host.duel.menu_confirmed.emit()
	await _frames(3)
	assert_eq(screen.titles, 1, "to the title")
	assert_eq(screen.saves, saved, "the save made as the meeting began stands")
	assert_eq(results, [], "the meeting never finished")
	assert_false(_slot_spent(), "the creature still there, to be met again")


# ------------------------------------------------- the riddle, the tribute --

func test_escape_at_the_riddle_waits_for_an_answer() -> void:
	screen.player.log_victory(1, 1)
	screen.player.log_victory(1, 1)
	var pane := await _meet()
	var owned := screen.player.cards.size()
	await _choose(pane, "riddle")
	assert_eq(pane.step, "riddle")
	assert_true(pane.choice_ids()[0].begins_with("answer_"))
	await _escape()
	# [Ours: 1997 slip — Escape was a wrong answer and lost the stake.]
	assert_eq(pane.step, "riddle", "Escape is no answer: the riddle waits")
	assert_eq(screen.player.cards.size(), owned, "nothing lost")
	assert_eq(results, [])


## The bug pass of part B (q2-2): a double click on "Answer a riddle." —
## its second press landing on the answer now standing there — answers
## nothing: the riddle waits to be read.
func test_a_double_click_answers_no_riddle_unseen() -> void:
	screen.player.log_victory(1, 1)
	screen.player.log_victory(1, 1)
	var pane := await _meet()
	var owned := screen.player.cards.size()
	var riddle := pane.find_child("Choice_riddle", true, false) as Button
	var at := riddle.get_global_rect().get_center()
	_press(riddle)
	await _frames()
	assert_eq(pane.step, "riddle", "control: the riddle asked")
	# The double click's second press, where the riddle's choice stood.
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.double_click = pressed
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.position = at
		click.global_position = at
		viewport.push_input(click, true)
	await _frames(2)
	assert_eq(pane.step, "riddle", "no answer given by the double click")
	assert_eq(screen.player.cards.size(), owned, "nothing lost")


func test_escape_at_the_tribute_takes_nothing() -> void:
	for i in 5:
		screen.player.log_victory(1, 1)
	var pane := await _meet()
	var gold := screen.player.gold
	var food := screen.player.food
	await _choose(pane, "tribute")
	assert_eq(pane.step, "tribute")
	assert_string_contains(pane.words(), "I thank you for your mercy granted.")
	assert_eq(pane.choice_ids(), ["offer", "payment", "duel"] as Array[String])
	await _escape()
	await _frames(3)
	assert_eq(results, [EncounterPane.NO_DUEL])
	assert_eq([screen.player.gold, screen.player.food], [gold, food])
	assert_true(_slot_spent())


func test_a_tribute_paid() -> void:
	for i in 5:
		screen.player.log_victory(1, 1)
	var pane := await _meet()
	var before := [screen.player.gold, screen.player.food, screen.player.amulet_count()]
	await _choose(pane, "tribute")
	await _choose(pane, "payment")
	assert_eq(pane.step, "told")
	await _choose(pane, "leave")
	await _frames(3)
	assert_eq(results, [EncounterPane.NO_DUEL])
	assert_ne([screen.player.gold, screen.player.food, screen.player.amulet_count()], before, "something paid")


# ------------------------------------------------------------- the end --

func test_nothing_to_stake_is_the_game_over() -> void:
	_deck(["Mountain", "Mountain", "Forest"])
	await _meet()
	await _frames(3)
	# The pane hands over at once: the end screen shows the 1997 words
	# (AdventureEndScreen), not this pane as well.
	assert_eq(results, [EncounterPane.GAME_OVER])

