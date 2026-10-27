extends GutTest
## THE HERO PANE'S NEW PAGES (the quick world package, 2026-10-27, steps 4
## and 6): the Wizards tab on 1997's wizards' window — the hall drawn from
## Statwin's stills when the skin has them, the record under it, the
## wizard ringed, `Statscrn.wav` only as it is opened — a beaten castle's
## click, W / J / D, and the creature page with its pictures and its "All
## creatures" switch. The pane is built alone (no world screen); the
## Statwin and creature pictures are fixtures, so this needs no skin.

const HALL_KEYS := ["wizards_ground", "creature_thumbs"]

var holder: Control
var stats: HeroStats
var _kept_cache := {}


func before_each() -> void:
	_kept_cache = GameSkin._texture_cache.duplicate()
	# Plain to start with: no hall, no creature pictures, whatever the
	# machine's skin holds.
	for key in HALL_KEYS:
		GameSkin._texture_cache[key] = null
	for color in AdventurePlayer.COLORS:
		GameSkin._texture_cache["wizards_room_" + color] = null


func after_each() -> void:
	GameSkin._texture_cache = _kept_cache


## A hero on a plain world: towns, the Red Wizardess holding two, wins
## against black and green, the Green Wizard beaten.
func _player() -> AdventurePlayer:
	var world := ShandalarWorld.new()
	world.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	for i in 6:
		world.sites.append({"x": 10 + i, "y": 10, "type": ShandalarWorld.TOWN, "trade": 0, "status": 0})
	var player := AdventurePlayer.new()
	player.world = world
	player.name = "Goya"
	player.color = "red"
	player.difficulty = 1
	TownStatus.take(world, 0, 4)
	TownStatus.take(world, 1, 4)
	for i in 13:
		player.log_victory(1, 1)
	for i in 3:
		player.log_victory(22, 3)
	player.defeated_wizards.append("green")
	return player


func _open(player: AdventurePlayer) -> HeroStats:
	holder = Control.new()
	add_child_autofree(holder)
	stats = HeroStats.new()
	stats.player = player
	holder.add_child(stats)
	await _frames(2)
	return stats


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


## Fixture pictures for every Statwin key, and the creature sheet.
func _fixtures() -> void:
	var keys := ["wizards_ground"]
	for color in AdventurePlayer.COLORS:
		for part in ["figure", "staff_lit", "staff_drained", "gems", "room"]:
			keys.append("wizards_%s_%s" % [part, color])
	for step in WorldStatus.SKULL_STEPS:
		keys.append("wizards_skulls_%d" % step)
	for key in keys:
		var image := Image.create(640, 480, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.3, 0.2, 0.4))
		GameSkin._texture_cache[key] = ImageTexture.create_from_image(image)
	var sheet := Image.create(640, 480, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.4, 0.1))
	GameSkin._texture_cache["creature_thumbs"] = ImageTexture.create_from_image(sheet)


func _text(name: String) -> String:
	var label := stats.find_child(name, true, false) as Label
	return label.text if label != null else "<no %s>" % name


func test_the_wizards_tab_reads_the_record_and_keeps_the_hero_size() -> void:
	await _open(_player())
	var hero := stats.get_combined_minimum_size()
	stats.show_tab("Wizards")
	await _frames(2)
	assert_not_null(stats.find_child("Wizards", true, false), "the record's table")
	assert_null(stats.find_child("WizardsPicture", true, false), "no hall without Statwin's stills")
	assert_eq(stats.get_combined_minimum_size(), hero, "the Hero tab's size")
	assert_eq([_text("Life_red"), _text("Domes_red"), _text("Won_red")], ["37", "2 of 3", "0"],
		"the Red Wizardess: 30 + 5 + 2 towns, two domes of three")
	assert_eq([_text("Life_black"), _text("Won_black")], ["25", "13"], "37 - 13, floored at 25")
	assert_eq([_text("Life_green"), _text("Domes_green"), _text("Won_green")], ["Beaten", "—", "3"],
		"a beaten wizard, his wins kept")
	assert_eq((stats.find_child("Wizard_red", true, false) as Label).tooltip_text,
		"She has 37 life in her stronghold and controls 2 mana domes.", "the wise man's words")


func test_the_hall_is_drawn_in_the_room_the_hero_page_leaves() -> void:
	_fixtures()
	await _open(_player())
	var hero := stats.get_combined_minimum_size()
	stats.show_wizards()
	await _frames(3)
	var hall := stats.find_child("WizardsPicture", true, false) as WizardsPicture
	assert_not_null(hall, "the hall, with the stills")
	assert_eq(stats.get_combined_minimum_size(), hero, "still the Hero tab's size")
	assert_gt(hall.size.y, 120.0, "the hall has the room left (%.0f px)" % hall.size.y)
	assert_eq(hall.rows.size(), 5)
	assert_eq(hall.room, "", "F6: the hall")
	assert_eq(hall.highlight, "", "F6 rings nobody")


func test_the_sound_comes_as_the_window_opens_never_as_it_is_drawn_again() -> void:
	await _open(_player())
	stats.show_wizards()
	assert_eq(stats.sounded, 1, "opened: Statscrn.wav")
	stats.refresh()
	stats.player.log_victory(8, 5)
	stats.refresh()
	await _frames(2)
	assert_eq(stats.sounded, 1, "drawn again: no sound")
	stats.show_tab("Hero")
	assert_eq(stats.sounded, 1, "another tab: none")
	(stats.find_child("Tab_Wizards", true, false) as Button).pressed.emit()
	assert_eq(stats.sounded, 2, "the Wizards tab is 1997's Wiz Stats button")
	assert_eq(stats.tab, "Wizards")
	(stats.find_child("Tab_Wizards", true, false) as Button).pressed.emit()
	assert_eq(stats.sounded, 2, "pressed again on the Wizards: no sound again")
	stats.highlight("green")
	stats.hide()
	stats.show_wizards()
	assert_eq(stats.highlighted, "", "opened again: nobody ringed")
	assert_eq(stats.sounded, 3, "and heard as it opens")


func test_a_beaten_wizard_s_castle_opens_his_room_an_unbeaten_one_nothing() -> void:
	_fixtures()
	await _open(_player())
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var black := stats.find_child("Castle_black", true, false) as Control
	assert_eq(black.mouse_filter, Control.MOUSE_FILTER_IGNORE, "an unbeaten castle is inert, as 1997's")
	black.gui_input.emit(click)
	assert_eq(stats.tab, "Hero", "nothing")
	var green := stats.find_child("Castle_green", true, false) as Control
	assert_eq(green.mouse_filter, Control.MOUSE_FILTER_STOP, "a beaten castle takes the mouse")
	assert_eq(green.tooltip_text, "Green Wizard, beaten: his room")
	green.gui_input.emit(click)
	await _frames(2)
	assert_eq([stats.tab, stats.highlighted, stats.room_shown], ["Wizards", "green", "green"])
	assert_eq(stats.sounded, 1)
	var hall := stats.find_child("WizardsPicture", true, false) as WizardsPicture
	assert_eq(hall.room, "green", "his room shown, whole")
	assert_not_null((stats.find_child("Wizard_green", true, false) as Label).get_theme_stylebox("normal"),
		"his row lit")
	# A click on the room: the hall again.
	hall.gui_input.emit(click)
	await _frames(2)
	assert_eq(stats.room_shown, "", "the room closed")
	hall = stats.find_child("WizardsPicture", true, false) as WizardsPicture
	assert_eq([hall.room, hall.highlight], ["", "green"], "the hall, the wizard still ringed")


func test_without_his_room_the_castle_rings_him_in_the_hall() -> void:
	await _open(_player())
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	(stats.find_child("Castle_green", true, false) as Control).gui_input.emit(click)
	assert_eq([stats.tab, stats.highlighted], ["Wizards", "green"])
	stats.highlight("red")
	await _frames(1)
	assert_eq(stats.highlighted, "red")
	assert_true((stats.find_child("Life_red", true, false) as Label).has_theme_stylebox_override("normal"),
		"the ringed wizard's row lit")
	assert_false((stats.find_child("Life_green", true, false) as Label).has_theme_stylebox_override("normal"))


## 1997's stats hotkeys, "Ww", "Jj", "Dd" (adventureStats.c 136–138).
func test_w_j_and_d_while_the_pane_is_open() -> void:
	await _open(_player())
	assert_false(stats.key(KEY_D), "D is the world's while nothing listens for the pane's done")
	assert_true(stats.key(KEY_W), "W")
	assert_eq([stats.tab, stats.sounded], ["Wizards", 1], "the wizards, with their sound")
	assert_true(stats.key(KEY_W), "W again: the pane's still")
	assert_eq(stats.sounded, 1, "not twice")
	assert_true(stats.key(KEY_J))
	assert_eq(stats.tab, "Journal")
	var done := [0]
	stats.done_pressed.connect(func() -> void: done[0] += 1)
	assert_true(stats.key(KEY_D))
	assert_eq(done[0], 1, "D: done")
	assert_false(stats.key(KEY_SPACE), "Space is the world's: it stops the walk")
	assert_eq(done[0], 1)
	assert_false(stats.key(KEY_A), "A is the world's")
	assert_false(stats.key(KEY_S), "S too")
	assert_false(stats.key(KEY_F5), "F5 is the host's toggle")


## The pane hears its letters itself, before the world, and only while it
## shows.
func test_the_pane_hears_its_letters_before_the_world() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(800, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	stats = HeroStats.new()
	stats.player = _player()
	viewport.add_child(stats)
	await _frames(2)
	var heard := [0]
	var world := _Listener.new()
	world.heard = heard
	viewport.add_child(world)
	_press(viewport, KEY_J)
	assert_eq([stats.tab, heard[0]], ["Journal", 0], "J: the journal, the world never hears it")
	_press(viewport, KEY_W, true)
	assert_eq([stats.tab, heard[0]], ["Journal", 1], "Ctrl+W is not the pane's")
	stats.visible = false
	_press(viewport, KEY_W)
	assert_eq([stats.tab, heard[0]], ["Journal", 2], "hidden: W is the world's again")


func _press(viewport: SubViewport, keycode: Key, ctrl := false) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.pressed = true
	press.ctrl_pressed = ctrl
	viewport.push_input(press)


## Stands in for the world's keys: counts what reaches `_unhandled_input`.
class _Listener extends Node:
	var heard: Array

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and (event as InputEventKey).pressed:
			heard[0] += 1


func test_f6_rings_nobody_a_castle_rings_its_wizard() -> void:
	await _open(_player())
	stats.show_wizards("red")
	assert_eq(stats.highlighted, "red")
	stats.show_tab("Wizards")
	assert_eq(stats.highlighted, "red", "the tab shown again keeps him")
	stats.show_tab("Hero")
	stats.show_tab("Wizards")
	assert_eq(stats.highlighted, "", "turned to from another tab, as F6: nobody")


func _fight(player: AdventurePlayer, row: int, won: bool) -> void:
	player.log_event("duel", "Fought.", {"creature": CreatureBook.name_of(row), "row": row, "won": won})


func test_the_creature_page_in_words_without_the_pictures() -> void:
	var player := _player()
	_fight(player, 33, true)
	_fight(player, 1, true)
	_fight(player, 1, false)
	await _open(player)
	var list := stats.find_child("Creatures", true, false) as GridContainer
	assert_eq(list.get_child_count(), 2)
	assert_eq((list.get_child(0) as Label).text, "1/1 Witch", "the table's order: the Witch first")
	assert_eq((list.get_child(1) as Label).text, "1/0 Hydra")
	assert_eq((list.get_child(0) as Label).get_theme_color("font_color"), HeroStats.RECORD_INKS[2])


func test_the_creature_page_with_its_pictures_and_the_whole_grid() -> void:
	_fixtures()
	var player := _player()
	for row in [1, 2, 3, 4, 5, 6, 7, 8]:
		_fight(player, row, row % 2 == 0)
	await _open(player)
	var cell := stats.find_child("Creature_1", true, false) as Control
	assert_not_null(cell, "the Witch's cell")
	var picture := cell.find_child("Picture", true, false) as TextureRect
	assert_eq((picture.texture as AtlasTexture).region, HeroStats.creature_cell(1), "her picture")
	assert_eq((cell.find_child("Score", true, false) as Label).text, "0/1")
	assert_eq((cell.find_child("Name", true, false) as Label).text, "Witch")
	var scroll := stats.find_child("CreatureScroll", true, false) as ScrollContainer
	assert_not_null(scroll, "eight creatures: three rows, two in sight")
	var list := scroll.find_child("Creatures", true, false) as GridContainer
	await _frames(2)
	var third := list.get_child(6) as Control
	var second := list.get_child(3) as Control
	var top := scroll.get_global_rect().position.y
	assert_true(second.get_global_rect().end.y - top <= scroll.size.y + 0.5, "the second row whole")
	assert_true(third.get_global_rect().position.y - top >= scroll.size.y - 0.5, "the third to scroll to")
	assert_eq(scroll.scroll_vertical_custom_step,
		second.get_global_rect().position.y - (list.get_child(0) as Control).get_global_rect().position.y,
		"a row a wheel step, as 1997's bar")
	# The switch on the page itself: the whole grid, blank cells for the
	# creatures never fought.
	var all := stats.find_child("AllCreatures", true, false) as Button
	all.button_pressed = true
	await _frames(2)
	assert_true(stats.show_all_creatures)
	list = stats.find_child("Creatures", true, false) as GridContainer
	assert_eq(list.get_child_count(), HeroStats.CREATURE_LAST, "fifty-five cells")
	var blank := list.get_child(20) as Control
	assert_null(((blank.find_child("Picture", true, false) as TextureRect).texture), "never fought: blank")
	assert_eq((blank.find_child("Name", true, false) as Label).text, "")
	assert_true((stats.find_child("AllCreatures", true, false) as Button).button_pressed, "the switch kept")
	assert_eq((stats.find_child("Creature_8", true, false).find_child("Score", true, false) as Label).text, "1/0",
		"a fought one still shows")


func test_no_creature_fought_says_so_and_the_switch_still_shows_the_grid() -> void:
	await _open(_player())
	assert_null(stats.find_child("Creatures", true, false))
	stats.show_all_creatures = true
	stats.refresh()
	await _frames(1)
	var list := stats.find_child("Creatures", true, false) as GridContainer
	assert_eq(list.get_child_count(), HeroStats.CREATURE_LAST, "every cell blank")
