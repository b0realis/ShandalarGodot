extends GutTest
## THE DUEL HELD OVER THE WORLD AFTER THE PLAYTEST OF PART B (campaign c5,
## fixer A; [WorldDuels]):
##  - H1-2: Pause → Return to main menu on a duel already over (its End of
##    Duel window up) went to the title with the result thrown away — a
##    win's cards gone, a loss undone by the reload. Its result stands, as
##    Exit duel's does (q2-1): what it brought is shown, then the adventure
##    is saved and left.
##  - H1-3: a held duel over before it was handed back (headless, the hero
##    at life 0) ended before the pane had connected: the pane stayed hidden
##    and the world held for good.
##  - H1-4 / H2-6: the questions are a meeting's: at a lair the hero stakes
##    nothing (no "your ante is lost"), and the save is the lair's entering.

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


const SAVES := "user://adventure_tests_c5_a_duels"

var viewport: SubViewport
var screen: Probe
var results: Array = []
var left: Array = []
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
	screen.set_process(false)
	screen.player.monsters = [] as Array
	screen.player.monster_timer = 4   # not a special meeting
	screen.player.gold = 1000
	for slot in screen.world.encounters:
		(slot as Dictionary)["clues"] = 7
	_deck()
	results = []
	left = []


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


func _deck() -> void:
	screen.player.cards = []
	for i in 10:
		screen.player.cards.append({"card": "Mountain", "decks": [0]})
	for i in 6:
		screen.player.cards.append({"card": "Lightning Bolt", "decks": [0]})
	for i in 4:
		screen.player.cards.append({"card": "Hill Giant", "decks": [0]})
	screen.player.current_deck = 0


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


## Lair event [param kind] entered as [method WorldScreen.enter_lair] enters
## one, [param reward] the rare waiting at its end.
func _enter(kind: int, reward := "") -> LairPane:
	var event := {"slot": 1, "color": 1, "event": kind, "name": LairEvent.NAMES[kind], "reward": reward,
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


func _choose(pane: Node, id: String) -> void:
	var button := pane.find_child("Choice_" + id, true, false) as Button
	assert_not_null(button, "a choice %s" % id)
	if button != null:
		_press(button)
	await _frames(3)


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


func _slot_spent() -> bool:
	for held in screen.player.monsters:
		if is_same(held, met):
			return false
	return true


## No mana link and no gift: the hero's life 0 (a loss before anyone acts).
func _no_life() -> void:
	for slot in screen.world.sites.size():
		TownStatus.put(screen.world, slot, TownStatus.LINKED, false)
	screen.player.next_duel_life = 0
	assert_eq(CreatureMeeting.hero_life(screen.player), 0)


# ----------------------------------------- the menu after the end (H1-2) --

func test_return_to_main_menu_after_a_won_duel_keeps_the_win() -> void:
	var pane := await _meet()
	var owned := screen.player.cards.size()
	await _choose(pane, "duel")
	var host := pane.duel_host()
	# Over, the hero the winner, the End of Duel window not yet closed.
	host.duel.game.winner = 0
	host.duel.game.game_over = true
	var saved := screen.saves
	host.duel.menu_confirmed.emit()
	assert_false(host.conceded, "the win kept, not conceded")
	await _frames(3)
	assert_eq(screen.titles, 0, "not to the title with the result unsettled")
	assert_eq(pane.step, "cards", "the spoils of the win")
	await _on_to_the_end(pane)
	await _frames(3)
	assert_eq(results, [EncounterPane.WON], "the meeting finished, a win")
	assert_gt(screen.player.cards.size(), owned, "its cards kept")
	assert_true(_slot_spent(), "the creature met")
	screen._process(0.016)
	await _frames(2)
	assert_eq(screen.titles, 1, "then the title, as asked")
	assert_gt(screen.saves, saved + 1, "the adventure saved with the win")
	var reloaded := AdventurePlayer.load_from(screen.player.save_path())
	assert_eq(reloaded.cards.size(), screen.player.cards.size(), "the save holds the cards won")


func test_return_to_main_menu_after_a_lost_duel_keeps_the_loss() -> void:
	var pane := await _meet()
	var owned := screen.player.cards.size()
	await _choose(pane, "duel")
	var host := pane.duel_host()
	host.duel.game.winner = 1
	host.duel.game.game_over = true
	host.duel.menu_confirmed.emit()
	await _frames(3)
	assert_eq(screen.titles, 0)
	assert_eq(pane.step, "lost", "the stake's picture")
	await _on_to_the_end(pane)
	await _frames(3)
	assert_eq(results, [EncounterPane.LOST])
	assert_eq(screen.player.cards.size(), owned - 1, "the stake lost, not undone")
	screen._process(0.016)
	await _frames(2)
	assert_eq(screen.titles, 1)
	var reloaded := AdventurePlayer.load_from(screen.player.save_path())
	assert_eq(reloaded.cards.size(), owned - 1, "the save holds the loss")


func test_the_questions_say_so_once_the_duel_is_over() -> void:
	var pane := await _meet()
	await _choose(pane, "duel")
	var host := pane.duel_host()
	var duel := host.duel
	assert_eq(duel.menu_question, WorldDuels.MENU % host.foe, "mid-duel: the meeting's question")
	duel.game.concede(1)
	assert_eq(duel.menu_question, WorldDuels.MENU_OVER, "over: its result stands")
	assert_eq(duel.leave_question, WorldDuels.LEAVE_OVER)
	await _frames(3)
	await _on_to_the_end(pane)


func test_return_to_main_menu_mid_duel_still_saves_nothing() -> void:
	var pane := await _meet()
	var saved := screen.saves
	await _choose(pane, "duel")
	pane.duel_host().duel.menu_confirmed.emit()
	await _frames(3)
	assert_eq(screen.titles, 1, "to the title (ruling 4)")
	assert_eq(screen.saves, saved, "the save made as the meeting began stands")
	assert_eq(results, [])
	assert_false(_slot_spent())


# ----------------------------------------- over before it is held (H1-3) --

func test_a_meeting_s_duel_over_as_it_is_dealt_reaches_its_pane() -> void:
	_no_life()
	var pane := await _meet()
	await _choose(pane, "duel")
	await _frames(3)
	assert_ne(pane.step, "duel", "the meeting heard its duel's end")
	assert_eq(pane.step, "lost", "a loss: the stake's picture")
	assert_true(pane.visible)
	assert_false(screen._duel_held, "the world no longer under a duel")
	await _on_to_the_end(pane)
	await _frames(3)
	assert_eq(results, [EncounterPane.LOST])
	assert_false(screen.modal(), "the world again")


func test_a_lair_s_duel_over_as_it_is_dealt_reaches_its_pane() -> void:
	_no_life()
	var pane := await _enter(LairEvent.DRAGON)
	await _choose(pane, "lair_duel")
	await _frames(3)
	assert_eq(left, [""], "the lair heard its duel's end, and is left: nothing waiting")
	assert_false(screen._duel_held, "the world no longer under a duel")
	assert_false(screen.modal(), "the world again")


# ------------------------------------------ a lair's questions (H1-4, H2-6) --

func test_a_lair_s_duel_asks_a_lair_s_questions() -> void:
	var pane := await _enter(LairEvent.DRAGON)
	await _choose(pane, "lair_duel")
	var host := pane.duel_host()
	assert_not_null(host)
	var duel := host.duel
	assert_eq(duel.leave_question, WorldDuels.LEAVE_UNSTAKED % host.foe, "the hero stakes nothing here")
	assert_false("ante" in duel.leave_question, "no ante to lose")
	assert_eq(duel.menu_question, WorldDuels.MENU_LAIR, "saved as the lair was entered, the lair spent")
	host.concede()
	await _frames(3)


func test_a_meeting_s_duel_asks_as_before() -> void:
	var pane := await _meet()
	await _choose(pane, "duel")
	var host := pane.duel_host()
	assert_eq(host.duel.leave_question, WorldDuels.LEAVE % host.foe, "the stake is lost on a concede")
	assert_eq(host.duel.menu_question, WorldDuels.MENU % host.foe)
	host.concede()
	await _frames(3)
	await _on_to_the_end(pane)
