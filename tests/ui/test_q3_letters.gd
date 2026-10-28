extends GutTest
## A QUESTION'S CHOICES ANSWER TO THEIR FIRST LETTER (the quick world
## package, 2026-10-27, C-5 [1997]): as 1.3's text menus (`RunTextMenuAt`,
## adventure_ui.c 186–222, hotkeys 436–461), a letter moves to the next
## choice beginning with it and Enter or Space takes the one lit — on a
## place's pane ([VisitPane], [LairPane]), a creature met ([EncounterPane])
## and a ruled town's duel ([RuledTownPane]). Never a letter the rest of
## the game needs: a plain letter only, the pane on top only, no text field
## holding the keys, and a letter no choice begins with goes on unheard.
## Keys and clicks through the viewport.

## A world screen that saves nowhere and never leaves for the title.
class Probe extends WorldScreen:
	func _go_to_title() -> void:
		_leaving = true


const SAVES := "user://adventure_tests_q3_letters"

var viewport: SubViewport
var screen: Probe


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
	_deck()


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
	screen.player.cards = []
	for i in 10:
		screen.player.cards.append({"card": "Forest", "decks": [0]})
	for card_name in ["Llanowar Elves", "Grizzly Bears", "Giant Growth", "Craw Wurm", "Shanodin Dryads",
			"War Mammoth"]:
		screen.player.cards.append({"card": card_name, "decks": [0]})
	screen.player.current_deck = 0


func _site(kind: int) -> int:
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == kind:
			return slot
	return -1


func _tile(slot: int) -> Vector2i:
	var site: Dictionary = screen.world.sites[slot]
	return Vector2i(int(site["x"]), int(site["y"]))


## Key [param code] pressed and let go through the viewport, [param ctrl] held.
func _key(code: Key, ctrl := false) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.unicode = code + 32 if code >= KEY_A and code <= KEY_Z else 0
	key.ctrl_pressed = ctrl
	key.pressed = true
	viewport.push_input(key, true)
	var up := key.duplicate() as InputEventKey
	up.pressed = false
	viewport.push_input(up, true)


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


## The ids of [param pane]'s choices beginning with [param letter], in order.
func _beginning(pane: Control, letter: String) -> Array[String]:
	var out: Array[String] = []
	for child in pane.find_child("Choices", true, false).get_children():
		var button := child as Button
		if button != null and not button.disabled and VisitPane.first_letter(button.text) == letter:
			out.append(String(button.name).trim_prefix("Choice_"))
	return out


## The choice lit, its id, "" for none.
func _lit() -> String:
	var held := viewport.gui_get_focus_owner()
	return String(held.name).trim_prefix("Choice_") if held != null else ""


# ----------------------------------------------------------- a place --

func test_a_town_s_letters_move_to_its_choices_and_enter_takes_one() -> void:
	var pane := screen.visit(_tile(_site(ShandalarWorld.VILLAGE)))
	await _frames(2)
	assert_eq(_lit(), "", "nothing lit at first: the mouse's pane")
	# Buy Cards, Begin a Quest (this village has one to give), Buy 10 food.
	var bs := _beginning(pane, "B")
	assert_gte(bs.size(), 2, "%s" % [bs])
	assert_eq([bs[0], bs[-1]], ["buy", "food"])
	for id in bs:
		_key(KEY_B)
		assert_eq(_lit(), id, "B again: the next beginning with B")
	_key(KEY_B)
	assert_eq(_lit(), "buy", "and round again")
	var gold := screen.player.gold
	_key(KEY_L)
	assert_eq(_lit(), "leave", "L: Leave the village")
	assert_true(screen.visiting(), "a letter never takes a choice by itself")
	assert_eq(screen.player.gold, gold)
	_key(KEY_ENTER)
	await _frames(2)
	assert_false(screen.visiting(), "Enter takes the one lit")


func test_space_takes_the_choice_lit_too() -> void:
	var pane := screen.visit(_tile(_site(ShandalarWorld.VILLAGE)))
	await _frames(2)
	var food := screen.player.food
	for id in _beginning(pane, "B"):
		_key(KEY_B)
	assert_eq(_lit(), "food")
	_key(KEY_SPACE)
	await _frames(1)
	assert_eq(screen.player.food, food + 10, "Space bought the food")
	assert_true(is_instance_valid(pane) and screen.visiting(), "the town stays")


func test_a_disabled_choice_is_never_lit() -> void:
	# A town's food the purse cannot buy is disabled (the castle's "Yes,
	# enter the castle." stood here until part C made the board, stage C2).
	screen.player.gold = 0
	var pane := screen.visit(_tile(_site(ShandalarWorld.VILLAGE)))
	await _frames(2)
	assert_eq(pane.find_child("Choice_food", true, false).disabled, true)
	var lit: Array[String] = []
	for i in 4:
		_key(KEY_B)
		lit.append(_lit())
	assert_eq(lit[0], "buy", "B: Buy Cards")
	assert_false("food" in lit, "B again and again: never the food the purse cannot buy (%s)" % [lit])


func test_what_is_not_a_choice_s_letter_is_left_alone() -> void:
	var pane := screen.visit(_tile(_site(ShandalarWorld.VILLAGE)))
	await _frames(2)
	_key(KEY_Z)
	assert_eq(_lit(), "", "no choice begins with Z")
	_key(KEY_B, true)
	assert_eq(_lit(), "", "Ctrl+B is not a letter for a choice")
	assert_true(VisitPane.first_letter("Buy 10 food for 15 gold") == "B")
	assert_eq(VisitPane.first_letter(" Well... No."), "W", "1997's hotkey: after the leading space")
	assert_eq(VisitPane.first_letter("\"Quoted\""), "Q")
	assert_eq(VisitPane.first_letter("...more"), "")


func test_a_pane_under_another_does_not_answer() -> void:
	var pane := screen.visit(_tile(_site(ShandalarWorld.VILLAGE)))
	await _frames(2)
	var over := PanelContainer.new()
	over.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.add_child(over)
	assert_false(VisitPane.on_top(pane))
	_key(KEY_B)
	assert_eq(_lit(), "", "the pane over it has the keys")
	over.visible = false
	assert_true(VisitPane.on_top(pane), "hidden, it holds nothing")
	_key(KEY_B)
	assert_eq(_lit(), "buy")
	over.queue_free()


func test_a_text_field_keeps_its_letters() -> void:
	var pane := screen.visit(_tile(_site(ShandalarWorld.VILLAGE)))
	await _frames(2)
	var field := LineEdit.new()
	pane.add_child(field)
	field.grab_focus()
	_key(KEY_B)
	assert_eq(viewport.gui_get_focus_owner(), field, "the field kept the keys")
	assert_eq(field.text, "b", "and the letter")


func test_a_press_of_the_mouse_puts_out_the_choice_lit() -> void:
	var pane := screen.visit(_tile(_site(ShandalarWorld.VILLAGE)))
	await _frames(2)
	_key(KEY_L)
	assert_eq(_lit(), "leave")
	_press(pane.find_child("PlaceName", true, false) as Control)
	await _frames(1)
	assert_eq(_lit(), "", "the mouse's again")
	assert_true(screen.visiting())


func test_a_click_on_a_choice_once_lit_leaves_nothing_lit() -> void:
	# A town's food stays where it was pressed: lit by its letter, then put
	# out and pressed with the mouse, it is not left lit for a later Enter.
	screen.player.gold = 1000
	var pane := screen.visit(_tile(_site(ShandalarWorld.VILLAGE)))
	await _frames(2)
	for i in 4:
		if _lit() != "food":
			_key(KEY_B)
	assert_eq(_lit(), "food", "B, again, lit Buy 10 food")
	var food := screen.player.food
	_press(pane.find_child("Choice_food", true, false) as Control)
	await _frames(1)
	assert_eq(screen.player.food, food + 10, "the click bought")
	assert_eq(_lit(), "", "and nothing is lit after it")
	_key(KEY_ENTER)
	await _frames(1)
	assert_eq(screen.player.food, food + 10, "so Enter buys nothing more")


func test_the_world_magic_seller_and_not_saved_answer_to_letters() -> void:
	var ask := WorldScreen.UnsavedAsk.new()
	ask.words = "Not saved."
	screen.add_child(ask)
	await _frames(2)
	var left := [0]
	ask.answered.connect(func(leave: bool) -> void: left[0] += 1 if leave else 0)
	_key(KEY_L)
	await _frames(1)
	assert_eq(_lit(), "LeaveUnsaved", "L lights Leave without saving")
	assert_eq(left[0], 0, "a letter alone never chooses")
	_key(KEY_ENTER)
	await _frames(1)
	assert_eq(left[0], 1, "Enter takes it")
	ask.queue_free()
	await _frames(1)


func test_a_lair_answers_to_its_choices_letters() -> void:
	var hero := screen.player.tile()
	screen.player.monsters = [{"slot": 1, "kind": "lair", "color": 3,
		"x": hero.x * 32 + 16, "y": (hero.y + 1) * 32 + 16}]
	screen.player.monster_timer = 0
	var pane := screen.enter_lair(1)
	await _frames(2)
	var first: Button = null
	for child in pane.find_child("Choices", true, false).get_children():
		if child is Button and not (child as Button).disabled:
			first = child
			break
	assert_not_null(first, "the lair offers a choice")
	_key(OS.find_keycode_from_string(VisitPane.first_letter(first.text)))
	assert_eq(viewport.gui_get_focus_owner(), first, "%s lit by its letter" % first.text)


# ---------------------------------------------------- a creature met --

func test_a_creature_met_answers_to_its_choices_letters() -> void:
	screen.player.gold = 1000
	screen.player.monster_timer = 4
	var at := screen.player.position + Vector2i(6, 0)
	screen.player.monsters.append({"slot": 0, "kind": "creature", "creature": 1, "x": at.x, "y": at.y,
		"color": 1, "heading": 0, "frame": 0})
	var pane := screen.meet_creature(0) as EncounterPane
	var results: Array = []
	pane.finished.connect(func(result: int) -> void: results.append(result))
	await _frames(3)
	assert_true(pane.choice_ids().has("pay"), "a Witch takes a bribe: %s" % [pane.choice_ids()])
	_key(KEY_D)
	assert_eq(_lit(), "duel", "D: Duel this Witch.")
	_key(KEY_P)
	assert_eq(_lit(), "pay", "P: Pay … gold.")
	assert_eq(pane.step, "meeting", "still asking")
	_key(KEY_ENTER)
	await _frames(2)
	assert_eq(results, [EncounterPane.NO_DUEL], "Enter paid: the creature goes")


# ------------------------------------------------- a ruled town's duel --

func test_a_ruled_town_s_duel_answers_to_continue_s_letter() -> void:
	var town := _site(ShandalarWorld.TOWN)
	TownStatus.take(screen.world, town, 4)
	var pane := screen.visit(_tile(town))
	await _frames(2)
	_key(KEY_D)
	assert_eq(_lit(), "duel", "D: Duel the creature.")
	_key(KEY_ENTER)
	await _frames(3)
	var duel := screen.find_child("RuledTownPane", true, false) as RuledTownPane
	assert_not_null(duel, "the town's duel")
	var results: Array = []
	duel.finished.connect(func(result: int) -> void: results.append(result))
	duel.duel_host().duel.game.concede(1)
	await _frames(3)
	assert_eq(duel.step, "freed")
	_key(KEY_C)
	assert_eq(_lit(), "go", "C: Continue")
	_key(KEY_ENTER)
	await _frames(2)
	assert_eq(results, [RuledTowns.WON], "Enter went on")
