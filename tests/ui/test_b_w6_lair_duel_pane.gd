extends GutTest
## A LAIR'S DUEL ON THE WORLD (part B, W6, 2026-10-23): the lair's pane
## ([LairPane]) at the four duel lairs ([LairDuels]) — the hoard fanned over
## the picture, 1997's words, Leave quietly or Duel the creature; the duel held
## over the world ([WorldDuels]) while the pane waits hidden; a win's cards
## laid on `win_back_cards` with their rarities, "Won These Cards"; a loss
## straight on to the lair's end (its waiting rare); the Hall's King
## Suleiman kept when the hero leaves quietly, in play when they duel; the
## Spectre's name and life. The lair is opened as the world screen opens it
## ([method WorldScreen.enter_lair]), with the event set. Clicks and keys
## through the viewport.

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


const SAVES := "user://adventure_tests_b_w6_lair"

var viewport: SubViewport
var screen: Probe
var left: Array = []


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Hoard Seeker"
	setup.color = "black"
	setup.difficulty = 2
	setup.walker = "male"
	setup.seed_text = "24680"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	screen = Probe.new()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.player.monsters = [] as Array
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


## Lair event [param kind] entered as [method WorldScreen.enter_lair] enters
## one (its pane over the world, held, its end the world's), [param reward]
## the rare waiting at its end.
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
	pane.card_read.connect(screen.read_card)
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


func _choice_ids(pane: VisitPane) -> Array[String]:
	var out: Array[String] = []
	for child in pane.find_child("Choices", true, false).get_children():
		if not child.is_queued_for_deletion():
			out.append(String(child.name).trim_prefix("Choice_"))
	return out


# ------------------------------------------------------------ the offer --

func test_the_dragon_s_hoard_is_offered() -> void:
	var pane := await _enter(LairEvent.DRAGON)
	var setup := pane.duel_setup
	var row := int(setup["row"])
	assert_eq(CreatureBook.tier(row), 18)
	assert_eq(pane.cards_shown(), Array(setup["rares"]) as Array[String], "the hoard over the picture")
	assert_eq(pane.cards_shown().size(), 4)
	assert_eq(pane.words(), "\n".join(["You happen upon a Dragon's Lair!", "You encounter %s" % CreatureBook.called(row),
		"Dragon guarding a horde", "of valuable spells.", "Will you..."]))
	assert_eq(_choice_ids(pane), ["leave", "lair_duel"] as Array[String])
	assert_eq(pane.note(), "", "the duels are made")
	assert_eq(pane.shown_picture(), "visit_lair_black")


func test_leaving_quietly_keeps_king_suleiman() -> void:
	var pane := await _enter(LairEvent.SULTAN, "Mox Pearl")
	assert_string_contains(pane.words(), "(King Suleiman starts in play!)")
	assert_eq(screen.player.next_duel_card, "King Suleiman", "set as the Hall is entered")
	await _escape()
	assert_eq(pane.shown_card(), "Mox Pearl", "the waiting rare, found")
	assert_eq(pane.cards_shown(), [] as Array[String], "the hoard gone")
	await _escape()
	assert_eq(left, [""])
	assert_false(screen.visiting(), "the lair left")
	assert_eq(screen.player.next_duel_card, "King Suleiman", "the next duel's card stays (the quest pane shows it)")
	assert_eq(String(screen.player.cards[-1]["card"]), "Mox Pearl")


# -------------------------------------------------------------- the duel --

func test_a_won_lair_duel_lays_out_the_hoard() -> void:
	var pane := await _enter(LairEvent.SULTAN)
	var rares: Array = pane.duel_setup["rares"]
	var owned := screen.player.cards.size()
	await _click(pane, "lair_duel")
	var host := pane.duel_host()
	assert_not_null(host, "the duel over the world")
	assert_false(pane.visible, "the lair waits hidden")
	assert_true(screen.modal())
	assert_false(screen.view.visible, "the world covered")
	assert_eq(host.config.start_in_play[0], ["King Suleiman"], "the Hall's gift in play")
	assert_eq(host.config.ante_extras[1], rares)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	pane._unhandled_input(esc)
	await _frames()
	assert_eq(left, [], "Escape is the duel's, not the hidden lair's")
	host.duel.game.concede(1)
	await _frames(3)
	assert_true(pane.visible)
	assert_eq(pane.duel_step, "won")
	assert_eq(pane.shown_picture(), "win_back_cards", "Winbak01.pic")
	assert_eq(pane.cards_shown(), Array(rares) as Array[String])
	assert_eq(pane.words(), "Won These Cards")
	var captions: Array[String] = []
	for label in pane.find_children("RowCaption*", "Label", true, false):
		captions.append((label as Label).text)
	for caption in captions:
		assert_true(caption in ["Rare", "Unique"], caption)
	assert_eq(captions.size(), rares.size())
	assert_eq(screen.player.cards.size(), owned + rares.size())
	assert_eq(screen.player.next_duel_card, "", "King Suleiman spent")
	await _click(pane, "won")
	await _frames(2)
	assert_eq(left, [""], "the lair's end: nothing waiting")
	assert_false(screen.modal())
	assert_true(screen.view.visible)
	assert_eq(screen.player.total_wins(), 0, "no victory logged")


func test_a_lost_lair_duel_goes_on_to_the_waiting_rare() -> void:
	var pane := await _enter(LairEvent.SHRINE, "Mox Jet")
	var cards := screen.player.cards.duplicate(true)
	await _click(pane, "lair_duel")
	pane.duel_host().concede()
	await _frames(3)
	assert_true(pane.visible)
	assert_eq(pane.duel_step, "over")
	assert_eq(pane.shown_card(), "Mox Jet", "the lair's end: the waiting rare")
	assert_eq(screen.player.cards, cards, "nothing lost")
	await _escape()
	assert_eq(left, [""])
	assert_eq(screen.player.cards.size(), cards.size() + 1)


func test_the_spectre_in_the_arena() -> void:
	var pane := await _enter(LairEvent.ARENA)
	var row := int(pane.duel_setup["row"])
	assert_string_contains(pane.words(), "Spectre guarding a horde")
	assert_eq(pane.cards_shown().size(), 3)
	await _click(pane, "lair_duel")
	var host := pane.duel_host()
	assert_eq(host.config.player_names[1], "%s Spectre" % CreatureBook.duel_name(row))
	assert_eq(host.config.lives[1], 16 + 2 * screen.player.difficulty)
	assert_eq(host.foe, "%s Spectre" % CreatureBook.name_of(row))
	host.concede()
	await _frames(3)
	await _escape()
	assert_eq(left, [""])


func test_return_to_main_menu_saves_nothing() -> void:
	var pane := await _enter(LairEvent.DRAGON)
	await _click(pane, "lair_duel")
	var saved := screen.saves
	pane.duel_host().duel.menu_confirmed.emit()
	await _frames(3)
	assert_eq(screen.titles, 1, "to the title")
	assert_eq(screen.saves, saved, "nothing saved")
	assert_eq(left, [], "the lair never finished")
