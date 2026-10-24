extends GutTest
## THE WISE MAN, THE GUARDIAN'S GHOST AND A PLACE'S PANE ON THE SCREEN
## (adventure campaign 2026-10-23):
##  - h1-3: the wise man's pane in quest mode offered the town's quest even
##    where the town turns the hero away (a quest of its failed:
##    [TownStatus.NO_QUESTS]; 1997's `VisitTownWiseman` looks at that first).
##    It now says the town's refusal and offers no quest, however it was
##    opened.
##  - h2-3: the Ghost's "See a deck." took the amulet it named without
##    looking whether it was still held — a Leap of Fate cast from the panel
##    spent the last blue one, and blue amulets went to -1, into the save.
##    It now looks again when paying, and says so when the amulet is gone.
##  - h3-8: a place's picture was sized once, from its own lines; the
##    creatures' choices "Whose deck would you like to see?" adds later made
##    the pane 832 pixels high with Big buttons on the 800-pixel screen (the
##    Ghost's, 788): the rims and the title were cut. The picture now gives
##    way so the pane fits the screen.

const SAVES := "user://adventure_tests_c3_f2_town"

var viewport: SubViewport
var screen: WorldScreen


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	screen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)


func after_each() -> void:
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


## A real left click on [param node]'s middle, through the viewport; then
## [param after] frames.
func _click(node: Control, after := 2) -> void:
	var at := node.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	viewport.push_input(motion, true)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.position = at
		click.global_position = at
		viewport.push_input(click, true)
	await _frames(after)


func _first(kind: int) -> int:
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == kind:
			return slot
	return -1


func _button(node: Node, button_name: String) -> Button:
	return node.find_child(button_name, true, false) as Button


## The Guardian's Ghost's lair of [param color] (1 black … 5 white), the hero
## holding only [param held] amulets (`{colour: count}`); [param k] the
## size of its choices.
func _ghost(color: int, held: Dictionary, k := 1.0) -> LairPane:
	var player := screen.player
	for hue in AdventurePlayer.COLORS:
		player.amulets[hue] = int(held.get(hue, 0))
	var hero := player.tile()
	player.monsters = [{"slot": 1, "kind": "lair", "color": color, "x": hero.x * 32 + 16, "y": (hero.y + 1) * 32 + 16}]
	var made := LairEvent.begin(player, player.monsters[0])
	made["event"] = LairEvent.GHOST
	made["name"] = LairEvent.NAMES[LairEvent.GHOST]
	made["reward"] = ""
	var pane := LairPane.new()
	pane.player = player
	pane.event = made
	pane.place = LairPane.place_of(made)
	pane.k = k
	screen._visit = pane
	screen.add_child(pane)
	PaneStyle.centre(pane)
	pane.deck_wanted.connect(screen.show_creature_deck)
	await _frames(3)
	return pane


func test_a_town_that_turns_the_hero_away_offers_no_quest() -> void:
	var player := screen.player
	var village := _first(ShandalarWorld.VILLAGE)
	var destination := -1
	for slot in screen.world.sites.size():
		if TownStatus.is_town(screen.world, slot) and not TownStatus.linked(screen.world, slot):
			destination = slot
			break
	player.quest_offer = {"type": Quests.LETTER_AMULET, "destination": destination, "color": 2, "at": village}
	TownStatus.put(screen.world, village, TownStatus.NO_QUESTS)
	var wise := screen.open_wise_man(village, "quest")
	await _frames(2)
	assert_eq(wise.words(), WiseMan.REFUSAL, "the town's refusal, in the wise man's words")
	assert_null(_button(wise, "Choice_accept"), "no quest to accept")
	assert_not_null(_button(wise, "Choice_leave"), "only the way out")
	wise.choose("accept")
	assert_false(Quests.has_quest(player), "no quest taken however it is asked")


func test_a_town_that_gives_quests_still_offers_its_own() -> void:
	var player := screen.player
	var village := _first(ShandalarWorld.VILLAGE)
	var destination := -1
	for slot in screen.world.sites.size():
		if TownStatus.is_town(screen.world, slot) and not TownStatus.linked(screen.world, slot):
			destination = slot
			break
	player.quest_offer = {"type": Quests.LETTER_AMULET, "destination": destination, "color": 2, "at": village}
	var wise := screen.open_wise_man(village, "quest")
	await _frames(2)
	assert_string_contains(wise.words(), "He will reward you with a blue amulet.", "control: the offer")
	assert_not_null(_button(wise, "Choice_accept"))


func test_the_ghost_pays_with_an_amulet_still_held() -> void:
	var pane := await _ghost(1, {"blue": 1})
	assert_string_contains(pane.words(), "For one blue amulet", "control: the Ghost names the blue")
	# The blue amulet is spent elsewhere while the Ghost waits.
	screen.player.amulets["blue"] = 0
	await _click(_button(pane, "Choice_ghost"))
	assert_eq(int(screen.player.amulets["blue"]), 0, "no amulet taken that is not held")
	assert_string_contains(pane.words(), LairPane.GHOST_SHORT % "blue", "the Ghost says why")
	assert_null(_button(pane, "Choice_deck_%d" % CreatureBook.of_color(1)[0]), "no deck shown unpaid")
	assert_not_null(_button(pane, "Choice_leave"), "the way out")


func test_the_ghost_takes_its_amulet_when_held() -> void:
	var pane := await _ghost(1, {"blue": 2})
	await _click(_button(pane, "Choice_ghost"))
	assert_eq(int(screen.player.amulets["blue"]), 1, "control: one blue amulet paid")
	assert_string_contains(pane.words(), "Whose deck would you like to see?")


## Whether [param pane] lies whole on the 800-pixel screen, its rims clear
## of the edges.
func _on_screen(pane: Control, what: String) -> void:
	var room := Rect2(Vector2.ZERO, Vector2(viewport.size))
	var rect := pane.get_global_rect()
	assert_true(rect.position.y >= VisitPane.ROOM_MARGIN / 2.0 - 0.5 and rect.end.y <= room.end.y - VisitPane.ROOM_MARGIN / 2.0 + 0.5,
		"%s: on the screen with room round it (%s in %s)" % [what, rect, room])


## [param pane] given up to [constant SETTLE_FRAMES] frames to lay itself
## out on the screen; it must fit once laid out, which is what this asks.
## (This test caught a real fault, 2026-10-23: under load one run in four
## held the wise man's "whose deck" at 843 px of the 800 — the choices'
## rows grew after the pane had last fitted itself, and nothing looked
## again; [VisitPane] now fits itself again as it is resized.)
const SETTLE_FRAMES := 30


func _settled(pane: Control) -> void:
	var room := float(viewport.size.y)
	for i in SETTLE_FRAMES:
		var rect := pane.get_global_rect()
		if rect.position.y >= VisitPane.ROOM_MARGIN / 2.0 - 0.5 \
				and rect.end.y <= room - VisitPane.ROOM_MARGIN / 2.0 + 0.5:
			return
		await _frames(1)


func test_whose_deck_fits_the_screen_with_big_buttons() -> void:
	for color in range(1, 6):
		var pane := await _ghost(color, {"white": 1}, WorldHud.BIG)
		_on_screen(pane, "the Ghost's offer, color %d" % color)
		var art := pane.find_child("Art", true, false) as Control
		var offered := art.size.y
		# Fitted as soon as it is laid out: the frame drawn next.
		await _click(_button(pane, "Choice_ghost"), 1)
		_on_screen(pane, "the Ghost's whose deck, color %d" % color)
		assert_true(art.size.y > 0.0 and art.size.y < offered, "the picture gives way (%.0f, was %.0f)" % [art.size.y, offered])
		# The deck seen: the choices go, the picture grows back.
		pane.deck_seen()
		await _frames(1)
		assert_almost_eq(art.size.y, offered, 1.0, "the picture as it was")
		_on_screen(pane, "the Ghost's last words, color %d" % color)
		pane.free()
		await _frames(1)
	# The wise man's gift of a look at a deck.
	var wise := WiseManPane.new()
	wise.player = screen.player
	wise.place = WiseManPane.place_of(screen.player, _first(ShandalarWorld.TOWN))
	wise.k = WorldHud.BIG
	screen.add_child(wise)
	PaneStyle.centre(wise)
	await _frames(2)
	wise.talk = {"pages": PackedStringArray(["To assist you I shall reveal to you the secret deck of any red creature.”"]),
		"then": "deck", "color": 4}
	wise._show_page(0)
	await _frames(3)
	await _settled(wise)
	_on_screen(wise, "the wise man's whose deck")
