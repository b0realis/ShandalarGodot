extends GutTest
## A RULED TOWN ON THE WORLD (part B, W6, 2026-10-23): the town's pane
## ([VisitPane], the `ruled` place) — the creature drawn as it opens (never
## for the pointer's tip), the stakes and the creature's face over the
## picture, the words naming the creature, a live "Duel the creature." —
## and the world screen's hook ([method WorldScreen._open_ruled_duel] →
## [method RuledTowns.open] → [RuledTownPane]): the duel held over the world,
## the town freed or the stake lost, a draw nothing, `finished` once, the
## hero back on the map and the adventure saved; the game over with nothing
## to stake; "Return to main menu" saving nothing. Clicks and keys through
## the viewport.

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


const SAVES := "user://adventure_tests_b_w6_ruled"

var viewport: SubViewport
var screen: Probe
var town := -1
var results: Array = []


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
	screen.player.monsters = [] as Array
	town = -1
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == ShandalarWorld.TOWN:
			town = slot
			break
	TownStatus.take(screen.world, town, 4)
	_deck()
	results = []


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


func _deck(names: Array = []) -> void:
	var cards := names
	if cards.is_empty():
		for i in 10:
			cards.append("Forest")
		for card_name in ["Llanowar Elves", "Grizzly Bears", "Giant Growth", "Craw Wurm", "Shanodin Dryads",
				"War Mammoth"]:
			cards.append(card_name)
	screen.player.cards = []
	for card_name in cards:
		screen.player.cards.append({"card": String(card_name), "decks": [0]})
	screen.player.current_deck = 0


func _tile() -> Vector2i:
	var site: Dictionary = screen.world.sites[town]
	return Vector2i(int(site["x"]), int(site["y"]))


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


func _click(pane: Node, id: String) -> void:
	var button := pane.find_child("Choice_" + id, true, false) as Button
	assert_not_null(button, "a choice %s" % id)
	if button != null:
		_press(button)
	await _frames(3)


func _escape() -> void:
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	viewport.push_input(esc, true)
	var up := esc.duplicate() as InputEventKey
	up.pressed = false
	viewport.push_input(up, true)
	await _frames(3)


## The town visited: its pane.
func _visit() -> VisitPane:
	var pane := screen.visit(_tile())
	await _frames(2)
	return pane


## The town's duel pane over the world, once "Duel the creature." was taken.
func _duel_pane() -> RuledTownPane:
	var pane := screen.find_child("RuledTownPane", true, false) as RuledTownPane
	if pane != null and not pane.finished.is_connected(_on_finished):
		pane.finished.connect(_on_finished)
	return pane


func _on_finished(result: int) -> void:
	results.append(result)


# ------------------------------------------------------------- the pane --

func test_the_town_s_pane_shows_its_stakes_and_creature() -> void:
	var dice := screen.player.dice
	var tip := VisitPane.describe(screen.player, _tile())
	assert_eq(screen.player.dice, dice, "the pointer's tip draws nothing")
	assert_eq(tip["kind"], "ruled")
	var pane := await _visit()
	assert_ne(screen.player.dice, dice, "the creature drawn as the pane opens")
	var entry := pane.ruled
	var row := int(entry["row"])
	assert_true(CreatureBook.is_of(row, 4) and CreatureBook.tier(row) == 4, "a red tier-4 creature")
	assert_eq(pane.words(), "This place is ruled by the Red Wizardess.\nTo free the city you must duel this %s"
		% CreatureBook.name_of(row), "the creature named, not the wizard's")
	var shown: Array[String] = []
	shown.append_array(entry["hero_ante"])
	shown.append_array(entry["creature_ante"])
	assert_eq(pane.cards_shown(), shown, "Your ANTE, then Wizard's ANTE")
	assert_eq((entry["hero_ante"] as Array).size(), int(screen.world.sites[town]["x"]) % 3 + 1)
	assert_eq(pane.face_name(), CreatureBook.name_of(row), "its face in the tinted frame")
	var duel := pane.find_child("Choice_duel", true, false) as Button
	assert_false(duel.disabled, "a live Duel the creature.")
	assert_eq(pane.note(), "", "no 'come next' note")
	var captions: Array[String] = []
	for label in pane.find_children("RowCaption*", "Label", true, false):
		captions.append((label as Label).text)
	assert_true(captions.has("Your ANTE") and captions.has("Wizard's ANTE"), "the captions: %s" % [captions])


func test_a_card_of_the_stakes_is_read_by_a_right_click() -> void:
	var pane := await _visit()
	var read: Array = []
	pane.card_read.connect(func(card_name: String) -> void: read.append(card_name))
	var card := pane.find_child("RowCard0", true, false) as Control
	assert_not_null(card)
	_press(card, MOUSE_BUTTON_RIGHT)
	await _frames()
	assert_eq(read, [String((pane.ruled["hero_ante"] as Array)[0])])


func test_each_entry_draws_a_new_creature_and_never_mind_leaves() -> void:
	var pane := await _visit()
	var dice := screen.player.dice
	var saved := screen.saves
	await _click(pane, "leave")
	assert_false(screen.visiting(), "Never mind: back on the map")
	assert_eq(screen.saves, saved + 1, "saved as the town is left")
	pane = await _visit()
	assert_ne(screen.player.dice, dice, "drawn again on the second entry")
	await _escape()
	assert_false(screen.visiting(), "Escape is Never mind")
	assert_true(TownStatus.ruled(screen.world, town))


# -------------------------------------------------------------- the duel --

func test_a_won_duel_frees_the_town() -> void:
	var pane := await _visit()
	var entry := pane.ruled
	var won := String((entry["creature_ante"] as Array)[0])
	var owned := screen.player.cards.size()
	var saved := screen.saves
	await _click(pane, "duel")
	var duel := _duel_pane()
	assert_not_null(duel, "the town's duel over the world")
	assert_true(screen.meeting(), "held as a meeting")
	assert_eq(screen.saves, saved + 1, "[ours] saved as the duel begins")
	var host := duel.duel_host()
	assert_not_null(host, "the duel is up")
	assert_false(duel.visible, "the pane waits hidden")
	assert_false(screen.view.visible, "the world covered")
	assert_true(CreatureBook.MINIONS[4].has(String((host.config.start_in_play[1] as Array)[0])),
		"the Red Wizardess's minion in play")
	assert_eq(host.config.ante_cards[0], entry["hero_ante"])
	host.duel.game.concede(1)
	await _frames(3)
	assert_true(duel.visible)
	assert_eq(duel.step, "freed")
	assert_eq(duel.stage.ground_key(), "town_freed")
	var name := WorldNames.site_name(screen.world, town)
	assert_eq(duel.words(), "%s is freed! The people rejoice." % name)
	assert_false(TownStatus.ruled(screen.world, town), "freed")
	await _click(duel, "go")
	await _frames(2)
	assert_eq(results, [RuledTowns.WON], "finished once")
	assert_false(screen.modal(), "back on the map")
	assert_true(screen.view.visible)
	assert_eq(screen.player.cards.size(), owned + 1)
	assert_eq(screen.player.cards[-1], {"card": won, "decks": [0]}, "into the deck in use")
	assert_eq(String(screen.player.journal[-1]["text"]), "Freed %s" % name)
	assert_eq(screen.saves, saved + 2, "and saved again as the town is left")
	var reloaded := AdventurePlayer.load_from(screen.player.save_path())
	assert_false(TownStatus.ruled(reloaded.world, town), "the save holds the town freed")


func test_a_lost_duel_loses_each_staked_card() -> void:
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
	var owned := screen.player.cards.size()
	await _click(pane, "duel")
	var duel := _duel_pane()
	duel.duel_host().concede()
	await _frames(3)
	for i in 3:
		assert_eq(duel.step, "lost")
		assert_eq(duel.stage.ground_key(), "lose_card")
		assert_eq(duel.stage.cards_shown(), [String(staked[i])] as Array[String], "a card at a time")
		assert_eq(duel.words(), "Lost this card")
		await _escape()
	await _frames(2)
	assert_eq(results, [RuledTowns.LOST])
	assert_eq(screen.player.cards.size(), owned - 3)
	assert_true(TownStatus.ruled(screen.world, town), "still ruled")
	assert_false(screen.modal())


## [Ours: 1997 slip — a draw lost the stake.]
func test_a_drawn_duel_changes_nothing() -> void:
	var pane := await _visit()
	var cards := screen.player.cards.duplicate(true)
	await _click(pane, "duel")
	var duel := _duel_pane()
	var report := DuelReport.new()
	report.finished = true
	report.result = DuelReport.DRAW
	duel.duel_host()._finish(report)
	await _frames(3)
	assert_eq(results, [RuledTowns.DRAWN], "finished at once")
	assert_eq(screen.player.cards, cards)
	assert_true(TownStatus.ruled(screen.world, town))
	assert_false(screen.modal(), "back on the map")


func test_return_to_main_menu_saves_nothing_and_finishes_nothing() -> void:
	var pane := await _visit()
	await _click(pane, "duel")
	var duel := _duel_pane()
	var saved := screen.saves
	duel.duel_host().duel.menu_confirmed.emit()
	await _frames(3)
	assert_eq(screen.titles, 1, "to the title")
	assert_eq(screen.saves, saved, "nothing saved")
	assert_eq(results, [])
	assert_true(TownStatus.ruled(screen.world, town))


# ------------------------------------------------------------- the end --

func test_nothing_to_stake_is_the_game_over() -> void:
	_deck(["Forest", "Forest", "Forest"])
	var pane := await _visit()
	assert_false(is_instance_valid(pane) and pane.visible, "the town's pane never shows")
	await _frames(3)
	# The town's duel pane hands over at once (GAME_OVER, 3): the world's end
	# screen shows the 1997 words (AdventureEndScreen), not the pane as well.
	assert_true(screen.ended(), "the adventure's end screen")
	assert_true(screen.lost(), "the adventure is over")
	assert_null(_duel_pane(), "the town's duel pane gone")
