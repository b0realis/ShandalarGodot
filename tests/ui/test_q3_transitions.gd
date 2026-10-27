extends GutTest
## THE PLACES' TRANSITIONS (the quick world package, 2026-10-27, H7 — the
## owner: *"Add, with a switch"*, *"modern smooth feeling"*): each place's
## picture comes in as 1997 brought it ([TileReveal]) — a town's zoomed in
## ([VisitPane], `AnimateVisitBackdropZoomIn`), a castle's in staggered
## tiles (`ShowWizardVisitBackdrop`), a lair's in random 5 × 5 tiles
## ([LairPane], `ShowLairBackdropTransition`), a ruled town's creature face
## after the zoom in 3 × 3 tiles over the town, a summoned creature's face
## over the one met ([EncounterStage], `DrawCreaturePortrait` modes 2 and
## 1) — while the words and the choices answer from the first frame; the
## Options' "Transitions" switch. Headless the transitions never play
## ([member TileReveal.forced] plays them here).

## A world screen that saves nowhere and never leaves for the title.
class Probe extends WorldScreen:
	func _go_to_title() -> void:
		_leaving = true


const SAVES := "user://adventure_tests_q3_transitions"

var viewport: SubViewport
var screen: Probe


func before_each() -> void:
	RuledTowns.forget()
	AdventurePlayer.saves_folder = SAVES
	TileReveal.forced = 1
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
	TileReveal.finish_all(screen)
	screen.player.monsters = [] as Array
	_deck()


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


func _art(pane: Control) -> TextureRect:
	return pane.find_child("Art", true, false) as TextureRect


# -------------------------------------------------------------- the zoom --

func test_a_town_zooms_in_and_its_choices_answer_at_once() -> void:
	var pane := screen.visit(_tile(_site(ShandalarWorld.VILLAGE)))
	assert_not_null(pane)
	var art := _art(pane)
	var zoom := art.find_child("ZoomIn", false, false) as TileReveal
	assert_not_null(zoom, "1997's AnimateVisitBackdropZoomIn")
	assert_eq(art.scale, Vector2(TileReveal.ZOOM_FROM, TileReveal.ZOOM_FROM), "from 2/8 of its size")
	assert_null(pane.find_child("PictureReveal", true, false), "no tiles for a town")
	await _frames(1)
	var leave := pane.find_child("Choice_leave", true, false) as Button
	assert_true(leave.is_visible_in_tree(), "the choices stand from the first frame")
	_press(leave)
	await _frames(2)
	assert_false(screen.visiting(), "Leave the village answered while the picture still grew")
	assert_false(is_instance_valid(zoom), "and the click ended the zoom")


func test_the_zoom_ends_by_itself_well_under_a_second() -> void:
	var pane := screen.visit(_tile(_site(ShandalarWorld.VILLAGE)))
	var art := _art(pane)
	var zoom := art.find_child("ZoomIn", false, false) as TileReveal
	assert_lt(zoom.seconds, 0.5, "short")
	zoom._process(zoom.seconds / 2.0)
	assert_between(art.scale.x, TileReveal.ZOOM_FROM, 1.0, "growing")
	zoom._process(zoom.seconds)
	assert_eq(art.scale, Vector2.ONE, "whole")
	assert_eq(art.modulate.a, 1.0)
	await _frames(1)
	assert_false(is_instance_valid(zoom), "gone")


func test_the_wise_man_zooms_in_too() -> void:
	var pane := screen.open_wise_man(_site(ShandalarWorld.TOWN), "talk")
	assert_not_null(pane)
	assert_not_null(_art(pane).find_child("ZoomIn", false, false), "Wiseman3.pic zoomed (visitLocation.c 877)")


# ------------------------------------------------------------ the tiles --

func test_a_castle_comes_in_staggered_tiles() -> void:
	var pane := screen.visit(_tile(_site(ShandalarWorld.CASTLE)))
	assert_not_null(pane)
	var cover := pane.find_child("PictureReveal", true, false) as TileReveal
	assert_not_null(cover, "1997's ShowWizardVisitBackdrop")
	assert_eq(cover.order, TileReveal.Order.STAGGERED)
	assert_eq(cover.grid, TileReveal.CASTLE_GRID, "8 × 8 tiles of the 512 × 280 picture")
	assert_eq([cover.strip, cover.active], [4, 3], "strips 32 wide, three at once")
	assert_eq(cover.seconds, TileReveal.CASTLE_SECONDS)
	assert_lt(cover.seconds, 1.0, "well under a second")
	assert_null(cover.before, "under it the frame's dark ground")
	assert_null(_art(pane).find_child("ZoomIn", false, false), "no zoom for a castle")
	await _frames(1)
	assert_eq(cover.size, _art(pane).size, "over the whole picture")
	assert_eq(cover.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_string_contains(pane.words(), "Who dares to challenge", "the words at once: nothing waits")


func test_a_lair_comes_in_random_tiles() -> void:
	var hero := screen.player.tile()
	screen.player.monsters = [{"slot": 1, "kind": "lair", "color": 3,
		"x": hero.x * 32 + 16, "y": (hero.y + 1) * 32 + 16}]
	screen.player.monster_timer = 0
	var pane := screen.enter_lair(1)
	assert_not_null(pane)
	var cover := pane.find_child("PictureReveal", true, false) as TileReveal
	assert_not_null(cover, "1997's ShowLairBackdropTransition")
	assert_eq(cover.order, TileReveal.Order.RANDOM)
	assert_eq(cover.grid, TileReveal.LAIR_GRID, "5 × 5 tiles of the 512 × 280 picture")
	assert_eq(cover.seconds, TileReveal.LAIR_SECONDS)


func test_a_ruled_town_zooms_then_its_face_comes_in() -> void:
	var town := _site(ShandalarWorld.TOWN)
	TownStatus.take(screen.world, town, 4)
	var pane := screen.visit(_tile(town))
	assert_not_null(pane)
	assert_ne(pane.face_name(), "", "the creature's face over the town")
	var art := _art(pane)
	assert_not_null(art.find_child("ZoomIn", false, false), "the town zooms in (visitLocation.c 4217)")
	var face := pane.find_child("FaceReveal", true, false) as TileReveal
	assert_not_null(face, "DrawCreaturePortrait mode 2 (visitLocation.c 4286)")
	assert_eq(face.grid, TileReveal.FACE_GRID, "3 × 3 tiles of the face block")
	assert_eq(face.delay, TileReveal.ZOOM_SECONDS, "after the zoom")
	assert_eq(face.before, art.texture, "hidden under the town's own picture")
	if art.texture != null:
		var scale := art.texture.get_size() / VisitPane.PICTURE
		assert_eq(face.source, Rect2(VisitPane.FACE_AT.position * scale, VisitPane.FACE_AT.size * scale),
			"the town's picture under the face")
	await _frames(1)
	assert_eq(face.position, VisitPane.FACE_AT.position * pane._grow, "over the face's frame")
	assert_null(pane.find_child("BannerReveal", true, false), "mode 2: the banner at once")
	pane.show_face(0)
	await _frames(1)
	assert_false(is_instance_valid(face), "the face taken away takes its cover")


func test_a_summoned_creature_s_face_comes_in_over_the_one_met() -> void:
	screen.player.gold = 1000
	var at := screen.player.position + Vector2i(6, 0)
	screen.player.monsters.append({"slot": 0, "kind": "creature", "creature": 1, "x": at.x, "y": at.y,
		"color": 1, "heading": 0, "frame": 0})
	var pane := screen.meet_creature(0) as EncounterPane
	assert_not_null(pane)
	await _frames(2)
	assert_null(pane.stage.part("FaceReveal"), "the face met is drawn at once (mode 0, E:1685)")
	# The Witch summons a Warlock (E:2183), as CreatureMeeting.prepare_duel
	# would on a special meeting's roll.
	pane.meeting["prepared"] = true
	pane.meeting["special"] = true
	pane.meeting["summoned"] = 3
	pane.meeting["row"] = 3
	pane.meeting["events"] = ["Witch summons a Warlock!"] as Array[String]
	pane.choose("duel")
	assert_eq(pane.step, "special")
	var face := pane.stage.part("FaceReveal") as TileReveal
	var banner := pane.stage.part("BannerReveal") as TileReveal
	assert_not_null(face, "the new face in 3 × 3 tiles (mode 1)")
	assert_not_null(banner, "and its name banner in 2 × 2")
	assert_eq(face.grid, TileReveal.FACE_GRID)
	assert_eq(banner.grid, TileReveal.BANNER_GRID)
	var f := pane.stage.factor
	assert_eq(face.position, EncounterStage.FACE_AT.position * f)
	assert_eq(banner.position, (EncounterStage.BANNER_AT.position + Vector2(TileReveal.BANNER_TRIM, 0)) * f,
		"the banner's middle: its width less 22")
	assert_almost_eq(banner.size.x, (EncounterStage.BANNER_AT.size.x - 2 * TileReveal.BANNER_TRIM) * f, 0.01)
	assert_not_null(face.before, "the screen as it stood, the old face on it")
	var canvas := face.get_viewport_rect().size
	var pixels := face.before.get_size() / canvas
	var placed := face.get_global_rect()
	assert_eq(face.source, Rect2(placed.position * pixels, placed.size * pixels), "its place on the old screen")
	assert_true(pane.choice_ids().has("fight"), "To the duel! stands from the first frame")


# ------------------------------------------------------------ the switch --

func test_with_the_transitions_off_every_picture_is_simply_there() -> void:
	TileReveal.forced = 0
	var castle := screen.visit(_tile(_site(ShandalarWorld.CASTLE)))
	assert_null(castle.find_child("PictureReveal", true, false))
	assert_eq(_art(castle).scale, Vector2.ONE)
	castle.left.emit("")
	await _frames(2)
	var village := screen.visit(_tile(_site(ShandalarWorld.VILLAGE)))
	assert_null(_art(village).find_child("ZoomIn", false, false))
	assert_eq(_art(village).scale, Vector2.ONE)
	assert_eq(_art(village).modulate.a, 1.0)


func test_the_options_switch_is_on_by_default_and_remembered() -> void:
	var had: Variant = Settings.get_value(TileReveal.SETTING, null) if Settings.has_value(TileReveal.SETTING) else null
	Settings.clear_value(TileReveal.SETTING)
	var options: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(options)
	await _frames(1)
	var switch := options.find_child("Transitions", true, false) as CheckButton
	assert_not_null(switch, "Options → Display: Transitions")
	assert_true(switch.button_pressed, "on by default (the owner's H7)")
	assert_false(Settings.has_value(TileReveal.SETTING), "and nothing written for it")
	switch.button_pressed = false
	assert_false(Settings.transitions(), "off: every picture at once")
	Settings.reload_file()
	assert_false(Settings.transitions(), "remembered")
	switch.button_pressed = true
	assert_true(Settings.transitions())
	if had == null:
		Settings.clear_value(TileReveal.SETTING)
	else:
		Settings.set_value(TileReveal.SETTING, had)
