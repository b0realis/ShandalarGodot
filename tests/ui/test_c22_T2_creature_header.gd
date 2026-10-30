extends GutTest
## A CREATURE'S PANE NAMES IT ONCE (the owner, 2026-10-30: "Yes, header =
## kind", after "And correct for all similar so titles are not
## duplicated!"): the meeting's pane ([EncounterPane]) and the room duel's
## ([RoomDuelPane]) showed the creature's name in their header and again on
## its face's banner. Now the header says only what it is — "Creature", a
## castle's wizard "Wizard" — in one line, and the banner keeps the name, at
## 1280 × 800 with and without Big buttons.

## A world screen that saves nowhere and never leaves for the title.
class Probe extends WorldScreen:
	func _write_autosave() -> String:
		return ""

	func _go_to_title() -> void:
		_leaving = true


const SAVES := "user://adventure_tests_c22_t2_creatures"

var viewport: SubViewport
var screen: Probe


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	TileReveal.forced = 0


func after_each() -> void:
	await _frames()
	TileReveal.forced = -1
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


## A world at 1280 × 800, Big buttons [param big], a red deck in use.
func _world(big := false) -> void:
	if viewport != null and is_instance_valid(viewport):
		viewport.queue_free()
		await _frames()
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	var setup := AdventureSetup.new()
	setup.player_name = "Inniscor"
	setup.color = "red"
	setup.difficulty = 2
	setup.walker = "male"
	setup.seed_text = "2468"
	screen = Probe.new()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.set_process(false)
	screen.hud.big = big
	screen.player.monsters = [] as Array
	screen.player.monster_timer = 4
	screen.player.cards = []
	for card_name in ["Mountain", "Mountain", "Mountain", "Mountain", "Mountain", "Mountain", "Mountain",
			"Mountain", "Mountain", "Mountain", "Lightning Bolt", "Lightning Bolt", "Lightning Bolt",
			"Lightning Bolt", "Hill Giant", "Hill Giant", "Hill Giant", "Hill Giant"]:
		screen.player.cards.append({"card": card_name, "decks": [0]})
	screen.player.current_deck = 0


## The words over the page: the pane's labels above its picture.
func _header(pane: Control) -> Array[String]:
	var out: Array[String] = []
	for child in pane.find_child("Column", false, false).get_children():
		if String(child.name) == "Picture":
			break
		if child is Label and (child as Label).visible and (child as Label).text != "":
			out.append((child as Label).text)
	return out


## How many shown labels in [param pane] read exactly [param text].
func _labels_reading(pane: Node, text: String) -> int:
	var count := 0
	for node in pane.find_children("*", "Label", true, false):
		var label := node as Label
		if label.is_visible_in_tree() and label.text == text:
			count += 1
	return count


func _assert_named_once(pane: Control, stage: EncounterStage, row: int, kind: String, why: String) -> void:
	var creature := CreatureBook.name_of(row)
	assert_eq(_header(pane), [kind] as Array[String], "%s: the header says what it is, in one line" % why)
	var banner := stage.part("CreatureName") as Label
	assert_not_null(banner, "%s: its face's banner" % why)
	if banner != null:
		assert_eq(banner.text, creature, "%s: the banner names it" % why)
	assert_eq(_labels_reading(pane, creature), 1, "%s: %s named once" % [why, creature])


# ----------------------------------------------------------- the meeting --

func test_a_creature_met_is_named_once_on_its_banner() -> void:
	for big in [false, true]:
		for row in [1, 30]:
			await _world(big)
			var at := screen.player.position + Vector2i(6, 0)
			screen.player.monsters.append({"slot": 0, "kind": "creature", "creature": row, "x": at.x, "y": at.y,
				"color": 4, "heading": 0, "frame": 0})
			var pane := screen.meet_creature(0) as EncounterPane
			assert_not_null(pane, "the meeting's pane")
			if pane == null:
				return
			await _frames()
			_assert_named_once(pane, pane.stage, row, "Creature", "a meeting, Big buttons %s" % big)


# --------------------------------------------------------- the room duel --

## The room duel's pane for [param run], as the board hands it over.
func _room_duel(run: Dictionary, big: bool) -> RoomDuelPane:
	var duel := DungeonDuels.setup_room(screen.player, run)
	assert_true(DungeonDuels.draw_stake(screen.player, duel), "a stake drawn")
	var pane := RoomDuelPane.make(screen.player, run, duel)
	pane.k = WorldHud.BIG if big else 1.0
	viewport.add_child(pane)
	PaneStyle.centre(pane)
	await _frames(3)
	return pane


func test_a_room_s_creature_and_a_castle_s_wizard_are_named_once() -> void:
	for big in [false, true]:
		await _world(big)
		var castle := {"index": 0, "castle": true, "color": 1, "rules": 0x03,
			"monsters": DungeonBoard.creatures_for(MsvcRandom.new(5), 1, 0, true), "life_pool": 3,
			"dice_card": "", "code": DungeonBoard.WIZARD, "card_in_effect": -1}
		var wizard := await _room_duel(castle, big)
		_assert_named_once(wizard, wizard.stage, int(wizard.duel["row"]), "Wizard",
			"a castle's wizard, Big buttons %s" % big)
		PaneStyle.drop(wizard)
		var dungeon := {"index": 5, "castle": false, "color": 1, "rules": 0,
			"monsters": DungeonBoard.creatures_for(MsvcRandom.new(9), 1, 0, false), "life_pool": 0,
			"dice_card": "", "code": 4, "card_in_effect": -1}
		var room := await _room_duel(dungeon, big)
		_assert_named_once(room, room.stage, int(room.duel["row"]), "Creature",
			"a dungeon room's creature, Big buttons %s" % big)
		PaneStyle.drop(room)
