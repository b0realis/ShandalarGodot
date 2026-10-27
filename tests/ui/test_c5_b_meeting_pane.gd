extends GutTest
## THE MEETING'S PANE, THE FIX PASS OF PART B (c5, 2026-10-24):
## [EncounterPane] and its page ([EncounterStage]) through the viewport —
## the big buttons' page as large as the room the words and choices leave
## (P4-1), the pane on the screen at every window and button size; the
## dungeon's plaque keeping the clue's word it was asked with (P4-4); a
## full bag's losses said — the cards won, the reward's pick not offered
## (P4-6); the page without the 1997 skin readable and placed (P4-2, P4-3),
## the skin's own look unchanged.

## A world screen that saves nowhere and never leaves for the title.
class Probe extends WorldScreen:
	func _go_to_title() -> void:
		_leaving = true


const SAVES := "user://adventure_tests_c5_b_meeting"

var viewport: SubViewport
var screen: Probe
var results: Array = []
## The skin caches a test emptied or filled: `{cache, key, had, value}`.
var _swapped: Array = []


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	await _world()


func after_each() -> void:
	for i in range(_swapped.size() - 1, -1, -1):
		var swap: Dictionary = _swapped[i]
		var cache: Dictionary = swap["cache"]
		if bool(swap["had"]):
			cache[swap["key"]] = swap["value"]
		else:
			cache.erase(swap["key"])
	_swapped.clear()
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _world() -> void:
	if screen != null and is_instance_valid(screen):
		screen.queue_free()
		await _frames(2)
	var setup := AdventureSetup.new()
	setup.player_name = "Pane Mender"
	setup.color = "red"
	setup.difficulty = 0
	setup.walker = "male"
	setup.seed_text = "2468"
	screen = Probe.new()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.player.monsters = [] as Array
	screen.player.monster_timer = 4   # not a special meeting
	screen.player.gold = 1000
	_deck()
	results = []


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


func _full_bag() -> void:
	while screen.player.cards.size() < AdventurePlayer.BAG_MOST:
		screen.player.cards.append({"card": "Plains", "decks": []})


func _hints(clues: int) -> void:
	for slot in screen.world.encounters:
		(slot as Dictionary)["clues"] = clues


## A creature [param row] of colour [param color] in slot 0 by the hero, met.
func _meet(row := 1, color := 1) -> EncounterPane:
	var at := screen.player.position + Vector2i(6, 0)
	screen.player.monsters.append({"slot": 0, "kind": "creature", "creature": row, "x": at.x, "y": at.y,
		"color": color, "heading": 0, "frame": 0})
	var pane := screen.meet_creature(0) as EncounterPane
	assert_not_null(pane, "the meeting's pane")
	if pane != null:
		pane.finished.connect(func(result: int) -> void: results.append(result))
	await _frames(3)
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


func _choose(pane: EncounterPane, id: String) -> void:
	var button := pane.find_child("Choice_" + id, true, false) as Button
	assert_not_null(button, "a choice %s among %s" % [id, pane.choice_ids()])
	if button != null:
		_press(button)
	await _frames(3)


## The duel chosen (through a special meeting's line) and won.
func _win(pane: EncounterPane) -> void:
	await _choose(pane, "duel")
	if pane.step == "special":
		await _choose(pane, "fight")
	var host := pane.duel_host()
	assert_not_null(host, "the duel over the world")
	if host != null:
		host.duel.game.concede(1)
	await _frames(3)


## Whether [param pane] lies inside the viewport.
func _on_screen(pane: Control) -> bool:
	return Rect2(Vector2.ZERO, Vector2(viewport.size)).encloses(pane.get_global_rect())


## [param cache][[param key]] set to [param value] for this test.
func _swap(cache: Dictionary, key: String, value: Variant) -> void:
	_swapped.append({"cache": cache, "key": key, "had": cache.has(key), "value": cache.get(key)})
	cache[key] = value


## The page as the skin draws it (a stand-in sheet: the code path, not
## the picture), or without the skin.
func _skin(on: bool, row: int) -> void:
	var sheet: Texture2D = null
	if on:
		sheet = ImageTexture.create_from_image(Image.create(640, 480, false, Image.FORMAT_RGBA8))
	for key in ["preduel_panels", "preduel_frame"]:
		_swap(GameSkin._texture_cache, key, sheet)
	_swap(PortraitLibrary._textures, CreatureBook.face_id(row), sheet)
	_swap(GameSkin._texture_cache, "world_amulets", null)


func _stage() -> EncounterStage:
	var stage := EncounterStage.new()
	add_child_autofree(stage)
	return stage


# ------------------------------------------------------ the page's size --

## P4-1: with the big buttons the page took what 300 points × 1.6 left and
## was drawn at two thirds; now the room the words and choices really take
## is measured, and the page takes the rest.
func test_the_big_buttons_page_takes_the_room_left() -> void:
	screen.hud.big = true
	var pane := await _meet()
	assert_eq(pane.k, WorldHud.BIG)
	var room := float(viewport.size.y) - EncounterPane.ROOM_MARGIN
	assert_gt(pane._factor, 0.9, "the page no longer drawn at two thirds")
	assert_true(pane.size.y >= room - 4.0 or pane._factor >= pane._most - 0.001,
		"the pane as tall as the room (%s of %s), or the page as wide as it may be (%.3f)"
		% [pane.size.y, room, pane._factor])
	assert_true(_on_screen(pane), "on the screen: %s" % pane.get_global_rect())


func test_the_pane_fits_every_window_with_either_buttons() -> void:
	for at in [Vector2i(1024, 600), Vector2i(1280, 800), Vector2i(1920, 1080)]:
		for big in [false, true]:
			viewport.size = at
			await _world()
			screen.hud.big = big
			var pane := await _meet()
			var said := "%s, %s buttons" % [at, "big" if big else "normal"]
			assert_true(_on_screen(pane), "the meeting on the screen at %s: %s" % [said, pane.get_global_rect()])
			assert_true(pane._factor >= EncounterPane.LEAST and pane._factor <= EncounterPane.MOST, said)
			await _choose(pane, "pay")
			assert_eq(results, [EncounterPane.NO_DUEL], said)
	# The spoils' page too, at the big buttons.
	viewport.size = Vector2i(1280, 800)
	await _world()
	_hints(7)
	screen.hud.big = true
	var won := await _meet()
	await _win(won)
	assert_eq(won.step, "cards")
	assert_true(_on_screen(won), "the cards won on the screen: %s" % won.get_global_rect())
	assert_gt(won._factor, 0.9)



## The page keeps its size from step to step [ours]: the cards won, with
## fewer words under them than the meeting, are not drawn on a larger page
## than the meeting was — it gives way to more words, never swells back.
func test_the_page_does_not_swell_from_the_meeting_to_its_spoils() -> void:
	viewport.size = Vector2i(1280, 800)
	await _world()
	_hints(7)
	screen.hud.big = true
	var pane := await _meet()
	var met := pane._factor
	await _win(pane)
	assert_eq(pane.step, "cards")
	assert_lte(pane._factor, met + 0.001, "the cards' page %.3f, the meeting's %.3f" % [pane._factor, met])
	assert_gt(pane._factor, 0.9, "still the big page")

# ------------------------------------------------------ the clue's word --

## P4-4: the plaque's word is the one the choice was asked with — the clues
## known before the reveal, as 1997 counted them (E:2336–2356) — not the
## next one.
func test_the_clue_plaque_keeps_the_word_it_was_asked_with() -> void:
	_hints(0)
	var pane := await _meet()
	await _win(pane)
	assert_eq(pane.step, "cards")
	assert_eq((pane.stage.part("PlaqueClue") as Label).text, "(first clue)", "at the choice")
	await _choose(pane, "clue")
	assert_eq(pane.step, "clue")
	assert_eq((pane.stage.part("PlaqueClue") as Label).text, "(first clue)", "after the reveal")


# ---------------------------------------------------------- a full bag --

## P4-6 [ours]: the cards won that a full bag cannot hold are named as lost
## on the cards' step (1997 dropped them without a word, duel.c 1859–1867).
func test_the_cards_a_full_bag_loses_are_named() -> void:
	_hints(7)
	_full_bag()
	var pane := await _meet()
	await _win(pane)
	assert_eq(pane.step, "cards")
	var lost: Array = pane.spoils["bag_lost"]
	assert_false(lost.is_empty(), "the bag full: the cards lost")
	assert_string_contains(pane.note(), AdventurePlayer.BAG_FULL)
	for card_name in lost:
		assert_string_contains(pane.note(), String(card_name))
	assert_eq(screen.player.cards.size(), AdventurePlayer.BAG_MOST)


## The same when the cards are taken over the dungeon's clue: said on the
## bag's note that follows.
func test_the_cards_taken_over_the_clue_a_full_bag_loses_are_named() -> void:
	_hints(0)
	_full_bag()
	var pane := await _meet()
	await _win(pane)
	assert_eq(pane.choice_ids(), ["cards", "clue"] as Array[String])
	assert_eq(pane.note(), "", "nothing lost before the choice")
	await _choose(pane, "cards")
	assert_eq(pane.step, "bag")
	var lost: Array = pane.spoils["bag_lost"]
	assert_false(lost.is_empty())
	assert_string_contains(pane.note(), AdventurePlayer.BAG_FULL)
	for card_name in lost:
		assert_string_contains(pane.note(), String(card_name))


## P4-6 [ours]: "any card of your choice" with the bag full: no list whose
## pick would vanish — the full bag is said, and the meeting goes on.
func test_a_full_bag_offers_no_card_to_pick() -> void:
	_hints(7)
	_full_bag()
	screen.player.monster_timer = 0   # a special meeting: the reward
	var pane := await _meet(44, 1)   # a Lord of Fate: any card of your choice
	await _win(pane)
	var bits := int(pane.spoils.get("bits", 0))
	assert_ne(bits & CreatureBook.REWARD_ANY_CARD, 0, "the reward: a card of one's choice (%x)" % bits)
	var said: Array[String] = []
	for i in 12:
		if not is_instance_valid(pane) or pane.done():
			break
		assert_null(pane.card_list(), "no list to pick from at %s" % pane.step)
		if pane.card_list() != null:
			break
		said.append(pane.words())
		var go := pane.find_child("Choice_go", true, false) as Button
		if go == null:
			break
		_press(go)
		await _frames(3)
	await _frames(3)
	assert_true(said.has(AdventurePlayer.BAG_FULL + "\nThe card of your choice is lost."), "%s" % [said])
	assert_eq(results, [EncounterPane.WON], "the meeting over")
	assert_eq(screen.player.cards.size(), AdventurePlayer.BAG_MOST)


# ---------------------------------------------------- the page's pieces --

## P4-2, P4-3: without the 1997 skin the quest scroll's words are lettered
## in the panes' ink (dark brown was unreadable on the plain box); the purse
## boxes stand apart, each saying what it counts; the face is a disc of the
## creature's colour; the amulet a stone of its own.
func test_the_page_without_the_skin() -> void:
	_skin(false, 25)
	var stage := _stage()
	stage.set("hue", 3)
	stage.purse(screen.player)
	stage.scroll(["Next Duel: First Move"] as Array[String])
	stage.creature_face(25)   # a Forest Dragon
	stage.amulet("red")
	var ink := (stage.part("ScrollWords") as Label).get_theme_color("font_color")
	assert_eq(ink, PaneStyle.INK, "the scroll's words readable on the plain box")
	var player := screen.player
	assert_eq((stage.part("Gold") as Label).text, "Gold %d" % player.gold)
	assert_eq((stage.part("Food") as Label).text, "Food %d" % player.food)
	assert_eq((stage.part("Deck") as Label).text, "Deck %d/%d" % [player.deck_cards().size(), player.cards.size()])
	assert_eq((stage.part("Life") as Label).text, "Life %d" % player.mana_links())
	var boxes: Array[Rect2] = []
	for part_name in ["GoldPanel", "FoodPanel", "DeckPanel", "LifePanel"]:
		boxes.append((stage.part(part_name) as Control).get_rect())
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			assert_false(boxes[i].intersects(boxes[j]), "the purse boxes apart: %s, %s" % [boxes[i], boxes[j]])
	for i in boxes.size():
		assert_true(Rect2(Vector2.ZERO, EncounterStage.PAGE).encloses(boxes[i]), "on the page")
	var disc := stage.part("FaceDisc") as Panel
	assert_not_null(disc, "a disc where the face would be")
	if disc != null:
		var face := disc.get_theme_stylebox("panel") as StyleBoxFlat
		assert_eq(face.bg_color, WorldArt.AMULET_INKS[2].darkened(EncounterStage.FACE_DIM), "of the creature's colour")
	var stone := stage.part("Amulet") as Panel
	assert_not_null(stone, "the amulet a stone, not a bare square")
	if stone != null:
		var cut := stone.get_theme_stylebox("panel") as StyleBoxFlat
		assert_eq(cut.bg_color, WorldArt.AMULET_INKS[3], "of the amulet's colour")
		assert_gt(cut.corner_radius_top_left, 0, "rounded")


## The owner (2026-10-27): the scroll's words belong in the middle of the
## parchment — 1997 centred them on (543, 409), between the two rolls — and
## many lines stay inside, a size smaller; without the skin, inside its box.
## The purse's numbers stand on 1997's points too.
func test_the_scroll_s_words_stand_in_the_middle_and_fit() -> void:
	var many: Array[String] = ["Next Duel: +3 lives, First Move", "Black Wizard: 1 of 3 mana taps",
		"Blue Wizardess: 1 of 3 mana taps", "Green Wizard: 1 of 3 mana taps",
		"Red Wizardess: 1 of 3 mana taps", "White Wizard: 1 of 3 mana taps"]
	for skin in [true, false]:
		_skin(skin, 25)
		for lines in [["Red Wizardess: 1 of 3 mana taps"] as Array[String], many]:
			var stage := _stage()
			stage.scroll(lines)
			var words := stage.part("ScrollWords") as Label
			var place := EncounterStage.SCROLL_WORDS if skin else EncounterStage.PLAIN_SCROLL_AT.grow(-8)
			var shown := words.get_rect()
			if lines.size() == 1:
				assert_eq(shown, place, "one line: the parchment between the rolls, skin %s" % skin)
			var picture := EncounterStage.SCROLL_AT if skin else EncounterStage.PLAIN_SCROLL_AT
			assert_true(picture.encloses(shown), "%s inside the scroll %s" % [shown, picture])
			assert_eq(words.vertical_alignment, VERTICAL_ALIGNMENT_CENTER, "centred in it")
			var points := words.get_theme_font_size("font_size")
			var high := EncounterStage._words_high(words, shown.size.x, points)
			assert_lte(high, shown.size.y + 1.0, "%d lines inside (%d points), skin %s" % [lines.size(), points, skin])
			if skin:
				assert_almost_eq(shown.get_center().y, 409.0, 3.0, "about 1997's point")
	_skin(true, 25)
	var purse := _stage()
	purse.purse(screen.player)
	assert_eq((purse.part("Gold") as Control).get_rect().get_center(), EncounterStage.GOLD_POINT)
	assert_eq((purse.part("Life") as Control).get_rect().get_center(), EncounterStage.LIFE_POINT)


## With the skin, the page is 1997's as before: the bare numbers at 1997's
## places, the scroll's dark ink, the face's own picture.
func test_the_page_with_the_skin_is_unchanged() -> void:
	_skin(true, 25)
	var stage := _stage()
	stage.purse(screen.player)
	stage.scroll(["Next Duel: First Move"] as Array[String])
	stage.creature_face(25)
	var ink := (stage.part("ScrollWords") as Label).get_theme_color("font_color")
	assert_eq(ink, Color8(40, 24, 12), "the 1997 scroll's dark ink")
	assert_eq((stage.part("Gold") as Label).text, str(screen.player.gold))
	assert_eq((stage.part("Life") as Label).text, str(screen.player.mana_links()))
	assert_eq((stage.part("GoldPanel") as Control).get_rect(), EncounterStage.GOLD_AT)
	assert_eq((stage.part("FoodPanel") as Control).get_rect(), EncounterStage.FOOD_AT)
	assert_eq((stage.part("DeckPanel") as Control).get_rect(), EncounterStage.DECK_AT)
	assert_eq((stage.part("LifePanel") as Control).get_rect(), EncounterStage.LIFE_AT)
	assert_null(stage.part("FaceDisc"), "the face's own picture")
	assert_not_null(stage.part("Face"))
