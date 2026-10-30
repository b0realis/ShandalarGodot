extends GutTest
## A FACE'S REVEAL OVER AND GONE, THE PAGE STILL CLEARED (the 0.50.66 bug
## campaign, h1-1): a summoned creature's face ([method
## EncounterStage.reveal_face]) and a ruled town's ([VisitPane]) come in
## under a [TileReveal] that frees itself when it is over, and the pages
## kept it among their parts. Read back into a typed variable the freed
## cover was a script error ("previously freed instance") that stopped the
## page's clearing half-way: the cards won stayed under the reward drawn
## next. Each part is now looked at before it is read — the stage's clear,
## its parts, its cards, its placing on a resize; the town's face, its
## dropping and its placing.

## A world screen that saves nowhere and never leaves for the title.
class Probe extends WorldScreen:
	func _write_autosave() -> String:
		return ""

	func _go_to_title() -> void:
		_leaving = true


const SAVES := "user://adventure_tests_c21_x2_reveals"

var viewport: SubViewport
var screen: Probe


func before_each() -> void:
	RuledTowns.forget()
	AdventurePlayer.saves_folder = SAVES
	TileReveal.forced = 1
	var setup := AdventureSetup.new()
	setup.player_name = "Face Keeper"
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
	TileReveal.finish_all(screen)
	screen.player.monsters = [] as Array
	screen.player.monster_timer = 4
	screen.player.gold = 1000
	screen.player.cards = []
	for i in 10:
		screen.player.cards.append({"card": "Mountain", "decks": [0]})
	for i in 6:
		screen.player.cards.append({"card": "Lightning Bolt", "decks": [0]})
	for i in 4:
		screen.player.cards.append({"card": "Hill Giant", "decks": [0]})
	screen.player.current_deck = 0
	# No dungeon's question on the cards won.
	for slot in screen.world.encounters:
		(slot as Dictionary)["clues"] = 7


func after_each() -> void:
	TileReveal.forced = -1
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


func _choose(pane: Control, id: String) -> void:
	var button := pane.find_child("Choice_" + id, true, false) as Button
	assert_not_null(button, "a choice %s" % id)
	if button != null:
		_press(button)
	await _frames()


## The names of what stands on [param stage] besides its ground.
func _on_page(stage: EncounterStage) -> Array[String]:
	var out: Array[String] = []
	for child in stage.get_children():
		if child.name != "Plain" and child.name != "Ground":
			out.append(String(child.name))
	return out


# ------------------------------------------------- a summoning meeting --

func test_a_summoned_face_s_reveal_gone_leaves_every_page_clean() -> void:
	var at := screen.player.position + Vector2i(6, 0)
	screen.player.monsters.append({"slot": 0, "kind": "creature", "creature": 1, "x": at.x, "y": at.y,
		"color": 1, "heading": 0, "frame": 0})
	var pane := screen.meet_creature(0) as EncounterPane
	assert_not_null(pane, "the meeting's pane")
	await _frames(2)
	# The Witch summons a Warlock (E:2183), as CreatureMeeting.prepare_duel
	# does on a special meeting's roll.
	pane.meeting["prepared"] = true
	pane.meeting["special"] = true
	pane.meeting["summoned"] = 3
	pane.meeting["row"] = 3
	pane.meeting["events"] = ["Witch summons a Warlock!"] as Array[String]
	await _choose(pane, "duel")
	assert_eq(pane.step, "special")
	assert_not_null(pane.stage.part("FaceReveal"), "the new face comes in")
	# The face in: the covers free themselves (TileReveal.finish).
	TileReveal.finish_all(pane)
	await _frames(2)
	assert_null(pane.stage.part("FaceReveal"), "the reveal over, no part of the page")
	assert_null(pane.stage.part("BannerReveal"))
	assert_true(pane.stage.part("NameBanner") != null, "the page's own parts still found")
	# A resize places every part again (EncounterStage._place).
	pane.stage.set_factor(pane.stage.factor * 0.9)
	await _choose(pane, "fight")
	var host := pane.duel_host()
	assert_not_null(host, "the duel over the world")
	if host == null:
		return
	host.duel.game.concede(1)
	await _frames(3)
	assert_eq(pane.result, EncounterPane.WON)
	var first := _on_page(pane.stage)
	assert_false(first.has("HeroPlaque"), "the meeting's page gone under the spoils: %s" % [first])
	assert_false(first.has("CreatureName") and pane.step == "cards", "no face on the cards won: %s" % [first])
	# A reward to show next (the dice decide whether one comes): the page
	# cleared again for it.
	pane.spoils["bag"] = 0
	pane.spoils["amulet"] = ""
	pane.spoils["bits"] = 1
	pane.spoils["rewards"] = ["A gift."] as Array[String]
	pane.spoils["reward_card"] = ""
	pane.spoils["pick_any"] = false
	pane.spoils["pick_duplicate"] = false
	await _choose(pane, "go")
	assert_eq(pane.step, "reward")
	var reward := _on_page(pane.stage)
	for part_name in reward:
		assert_false(part_name.begins_with("Won"), "nothing of the cards won under the reward: %s" % [reward])
	assert_eq(pane.stage.cards_shown(), [] as Array[String], "no card from the page before")
	assert_true(reward.has("CreatureName"), "the reward's tinted face: %s" % [reward])


# ------------------------------------------------------- a ruled town --

func _site(kind: int) -> int:
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == kind:
			return slot
	return -1


func test_a_ruled_town_s_face_reveal_gone_then_a_resize() -> void:
	var town := _site(ShandalarWorld.TOWN)
	TownStatus.take(screen.world, town, 4)
	var site: Dictionary = screen.world.sites[town]
	var pane := screen.visit(Vector2i(int(site["x"]), int(site["y"]))) as VisitPane
	assert_not_null(pane)
	var named := pane.face_name()
	assert_ne(named, "", "the creature's face over the town")
	assert_not_null(pane.find_child("FaceReveal", true, false), "its face comes in")
	TileReveal.finish_all(pane)
	await _frames(2)
	assert_null(pane.find_child("FaceReveal", true, false), "the reveal over and gone")
	assert_eq(pane.face_name(), named, "the face still read")
	# The window made shorter and taller: the parts over the picture placed
	# again (VisitPane._place_over).
	var was := pane._grow
	viewport.size = Vector2i(1280, 560)
	pane.resized.emit()
	await _frames(3)
	assert_lt(pane._grow, was, "the picture gave way")
	var face := pane.find_child("FaceName", true, false) as Control
	assert_not_null(face)
	if face != null:
		assert_almost_eq(face.position.x, VisitPane.FACE_BANNER_AT.position.x * pane._grow, 0.5,
			"the face's name placed at the new size")
	viewport.size = Vector2i(1280, 800)
	pane.resized.emit()
	await _frames(3)
	# The face taken away and shown again (VisitPane._drop_over).
	pane.show_face(0)
	assert_eq(pane.face_name(), "", "the face taken away")
	assert_null(pane.find_child("FaceBack", true, false), "with its back")
