extends GutTest
## THE EMBARK SCREEN (2026-10-22, owner design): every choice of a new
## adventure on one screen over the 1997 portrait screen's dark ground —
## the face with red arrows, the name, the walker, the colour (emphasised),
## the playmat, the card packs, the difficulty, the world's seed, then
## `Adventure` or `Leave`. Works with or without the 1997 art: CI has
## neither the skin nor the 1997 faces, a dev checkout has both.

var screen: EmbarkScreen


func before_each() -> void:
	AdventureSetup.forget()
	screen = load("res://game/adventure/embark_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	AdventureSetup.forget()


func _find(node_name: String) -> Node:
	return screen.find_child(node_name, true, false)


func test_every_choice_is_on_the_one_screen() -> void:
	assert_eq((_find("Title") as Label).text, "Embark to the world of Shandalar…")
	assert_not_null(_find("Portrait"))
	assert_true(_find("PreviousFace") is RedArrow and _find("NextFace") is RedArrow, "red arrows")
	assert_eq((_find("HeroName") as LineEdit).max_length, AdventureSetup.NAME_MAX)
	for label in AdventureSetup.WALKER_LABELS:
		assert_not_null(_find("Walker" + label), label)
	for row in AdventureSetup.COLORS:
		assert_not_null(_find("Color" + String(row["name"])), String(row["name"]))
	for name in ["PlaymatColor", "PlaymatStyle", "PlaymatPreview", "WorldSeed", "Leave", "Adventure"]:
		assert_not_null(_find(name), name)
	for level in AdventureSetup.DIFFICULTIES:
		assert_not_null(_find("Difficulty" + level), level)
	var packs := get_node_or_null(^"/root/CardPacks")
	var offered := AdventureSetup.offered_packs(packs.available_ids() if packs != null else ([] as Array[String]))
	if not offered.is_empty():
		for id in offered:
			assert_not_null(_find("Pack_" + id), id)
	else:
		assert_not_null(_find("NoPacks"))
	assert_null(_find("Pack_pack-1"), "Pack 1 is never offered")
	assert_eq((_find("PacksChallenge") as Label).text,
		"These are additional challenges. The base cards are always present.")


func test_the_ground_is_the_portrait_screen_or_its_dark() -> void:
	var ground := _find("Ground")
	if GameSkin.texture(EmbarkScreen.BACKGROUND_KEY) != null:
		assert_true(ground is TextureRect, "the 1997 field")
	else:
		assert_true(ground is ColorRect and (ground as ColorRect).color == EmbarkScreen.FLAT,
			"the same dark, flat")


func test_the_heroes_come_first_then_every_other_face() -> void:
	var faces := EmbarkScreen.faces()
	assert_eq(faces.size(), PortraitLibrary.all().size(), "every face the game has")
	var seen_other := false
	for face in faces:
		var is_hero := not AdventureSetup.hero(String(face["id"])).is_empty()
		if not is_hero:
			seen_other = true
		assert_false(is_hero and seen_other, "no hero after another face")


func test_the_arrows_walk_the_faces_and_the_name_follows_until_typed() -> void:
	var faces := EmbarkScreen.faces()
	if faces.size() < 3:
		pass_test("fewer than three faces here")
		return
	var name_edit := _find("HeroName") as LineEdit
	var first := screen.setup.portrait
	(_find("NextFace") as Button).pressed.emit()
	assert_ne(screen.setup.portrait, first)
	assert_eq(name_edit.text, AdventureSetup.suggested_name(screen.setup.portrait), "the face's name")
	name_edit.text = "Hilda"
	name_edit.text_changed.emit("Hilda")
	(_find("NextFace") as Button).pressed.emit()
	assert_eq(name_edit.text, "Hilda", "a typed name stays")
	(_find("PreviousFace") as Button).pressed.emit()
	(_find("PreviousFace") as Button).pressed.emit()
	assert_eq(screen.setup.portrait, first, "back where it began")
	name_edit.text = ""
	name_edit.text_changed.emit("")
	(_find("NextFace") as Button).pressed.emit()
	assert_eq(name_edit.text, AdventureSetup.suggested_name(screen.setup.portrait), "an emptied name follows again")


func test_the_walker_follows_the_hero_until_chosen() -> void:
	screen.setup.portrait = "keleena"
	screen._show_walker()
	assert_true((_find("WalkerFemale") as Button).button_pressed)
	(_find("WalkerOther") as Button).pressed.emit()
	assert_eq(screen.setup.walker, "other")
	screen.setup.portrait = "goya"
	screen._show_walker()
	assert_true((_find("WalkerOther") as Button).button_pressed, "the pick stays")


func test_the_chosen_colour_is_emphasised_with_its_gifts() -> void:
	(_find("ColorRed") as Button).pressed.emit()
	assert_eq(screen.setup.color, "red")
	assert_true((_find("ColorRed") as Button).button_pressed)
	assert_eq((_find("ColorRed") as Button).modulate, Color.WHITE)
	assert_lt((_find("ColorBlue") as Button).modulate.v, 0.9, "the others are dimmed")
	assert_eq((_find("ColorName") as Label).text, "Red")
	assert_string_contains((_find("ColorGifts") as Label).text, "Staff of Thunder")
	assert_string_contains((_find("ColorFlavor") as Label).text, "Chaos and Combat")
	assert_eq((_find("PlaymatColor") as OptionButton).get_item_text(0), "Your color (red)")


func test_the_difficulty_shows_what_the_hero_starts_with() -> void:
	(_find("DifficultyWizard") as Button).pressed.emit()
	assert_eq(screen.setup.difficulty, 3)
	assert_eq((_find("DifficultyWord") as Label).text, "Hard game", "how hard, in plain words")
	var note := (_find("DifficultyNote") as Label).text
	assert_string_contains(note, "100 gold")
	assert_string_contains(note, "1 amulet")
	assert_string_contains(note, "45-card")
	assert_string_contains(note, "all five colors")
	(_find("DifficultyApprentice") as Button).pressed.emit()
	assert_string_contains((_find("DifficultyNote") as Label).text, "250 gold · 50 food · 4 amulets")
	var words := []
	for level in AdventureSetup.DIFFICULTIES:
		(_find("Difficulty" + level) as Button).pressed.emit()
		words.append((_find("DifficultyWord") as Label).text)
	assert_eq(words, ["Training game", "Easy game", "Normal game", "Hard game"])
	assert_eq((_find("DifficultySorcerer") as Button).tooltip_text, "Sorcerer: a normal game.")


func test_the_playmat_picks_any_ground() -> void:
	var colours := _find("PlaymatColor") as OptionButton
	var styles := _find("PlaymatStyle") as OptionButton
	assert_eq(colours.item_count, 6, "your color and the five")
	assert_eq(styles.item_count, 1 + DuelOptions.TERRITORY_TYPES.size(), "random and the three")
	colours.select(2)
	colours.item_selected.emit(2)
	styles.select(2)
	styles.item_selected.emit(2)
	assert_eq(screen.setup.playmat_color, "blue")
	assert_eq(screen.setup.playmat_type, String(DuelOptions.TERRITORY_TYPES[1]["label"]))
	assert_eq((_find("PlaymatPreview") as Control).get_child_count(), 1, "a ground in the preview")


func test_the_packs_all_and_none() -> void:
	var packs := get_node_or_null(^"/root/CardPacks")
	var offered := AdventureSetup.offered_packs(packs.available_ids() if packs != null else ([] as Array[String]))
	if offered.is_empty():
		pass_test("no packs here")
		return
	screen.choose_all_packs(true)
	assert_eq(screen.setup.packs, offered, "every pack but Pack 1")
	screen.choose_all_packs(false)
	assert_eq(screen.setup.packs, [] as Array[String])


func test_the_seed_takes_a_number_or_a_word() -> void:
	var edit := _find("WorldSeed") as LineEdit
	edit.text = "Marko 7"
	edit.text_changed.emit(edit.text)
	assert_eq(screen.setup.seed_text, "Marko 7")
	screen.setup.player_name = "Ann"
	var record := screen.setup.resolve({})
	assert_eq(record["seed"], AdventureSetup.text_seed("Marko 7"))
	assert_eq(record["seed_text"], "Marko 7")
	assert_string_contains(screen.summary(record), "World seed Marko 7.")


## As the 1997 game seeded its dice from the clock (the owner, 2026-10-22).
func test_the_seed_comes_filled_in_from_the_clock() -> void:
	var edit := _find("WorldSeed") as LineEdit
	assert_gt(AdventureSetup.parse_seed(edit.text), 0, "a seed is filled in")
	assert_eq(edit.text, screen.setup.seed_text)
	assert_eq(edit.text.length(), 6, "the time of day, as hours, minutes and seconds")
	var now := AdventureSetup.time_seed_text()
	var opened := int(edit.text.substr(0, 2)) * 3600 + int(edit.text.substr(2, 2)) * 60 + int(edit.text.substr(4, 2))
	var later := int(now.substr(0, 2)) * 3600 + int(now.substr(2, 2)) * 60 + int(now.substr(4, 2))
	assert_lte(posmod(later - opened, 86400), 5, "taken from the clock as the screen opened")


## The owner, 2026-10-22: no window over the screen — the bottom strip
## itself, the hourglass left of its middle, "Conjuration of Shandalar
## World" and one to five stars and back right of it.
func test_the_world_is_conjured_in_the_bottom_strip() -> void:
	await get_tree().process_frame
	var bar := screen.leave_button.get_parent() as Control
	var height := bar.size.y
	screen.show_generating()
	var strip := _find("Conjuration") as Control
	assert_not_null(strip, "the strip is shown")
	assert_eq(strip.get_parent(), bar, "in the bottom strip, not over the screen")
	for gone in [screen.leave_button, screen.randomize_button, screen.adventure_button, _find("WorldSeed")]:
		assert_false((gone as Control).is_visible_in_tree(), "%s gives way" % (gone as Control).name)
	assert_true(screen.leave_button.disabled and screen.adventure_button.disabled, "the choices held still")
	assert_eq((_find("Words") as Label).text, "Conjuration of Shandalar World")
	assert_eq((_find("Stars") as Label).text, "*")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_almost_eq(bar.size.y, height, 0.5, "the strip keeps its height")
	var glass := (_find("Hourglass") as Control).get_global_rect()
	var words := (_find("Words") as Control).get_global_rect()
	var stars := (_find("Stars") as Control).get_global_rect()
	var middle := bar.get_global_rect().get_center().x
	assert_true(glass.end.x <= words.position.x, "the hourglass on the left")
	assert_true(words.end.x <= stars.position.x, "the stars after the words")
	assert_almost_eq((glass.position.x + stars.end.x) * 0.5, middle, 2.0, "together in the middle")
	var wide := stars.size.x
	screen._wait_time = EmbarkScreen.STAR_STEP * 4.5
	screen._process(0.0)
	assert_eq((_find("Stars") as Label).text, "*****")
	await get_tree().process_frame
	assert_almost_eq((_find("Words") as Control).get_global_rect().position.x, words.position.x, 0.5,
		"the words stay put as the stars count")
	assert_almost_eq((_find("Stars") as Control).size.x, wide, 0.5)


## The owner, 2026-10-22: "a randomize button to the left of Adventure to
## randomize every setting in the window".
func test_randomize_draws_every_choice() -> void:
	assert_eq(screen.randomize_button.get_parent(), screen.adventure_button.get_parent())
	assert_eq(screen.randomize_button.get_index(), screen.adventure_button.get_index() - 1, "left of Adventure")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := {"portrait": {}, "player_name": {}, "walker": {}, "color": {}, "playmat_color": {},
		"playmat_type": {}, "difficulty": {}, "seed_text": {}, "packs": {}, "figure_colors": {}}
	for draw in 24:
		screen.randomize_all(rng)
		var setup := screen.setup
		for key in seen:
			(seen[key] as Dictionary)[str(setup.get(key))] = true
		assert_true(setup.walker in AdventureSetup.WALKERS)
		assert_eq(AdventureSetup.color_row(setup.color).is_empty(), false, "a colour of the five")
		assert_true(setup.difficulty >= 0 and setup.difficulty < AdventureSetup.DIFFICULTIES.size())
		assert_eq(setup.seed_text.length(), 6, "a time of day")
		assert_eq((_find("WorldSeed") as LineEdit).text, setup.seed_text, "shown")
		assert_eq((_find("HeroName") as LineEdit).text, setup.player_name, "the name, shown")
		var parts := setup.player_name.split(" ")
		assert_true(parts[0] in AdventureSetup.FIRST_NAMES and parts[1] in AdventureSetup.SURNAMES,
			"a name from the lists: %s" % setup.player_name)
		for id in screen._pack_checks:
			assert_eq((screen._pack_checks[id] as CheckBox).button_pressed, id in setup.packs, "pack %s shown" % id)
	for key in seen:
		if key == "portrait" and screen._faces.size() < 2:
			continue
		if key == "packs" and screen._pack_checks.is_empty():
			continue
		assert_gt((seen[key] as Dictionary).size(), 1, "%s is drawn" % key)


## The owner, 2026-10-22: "when game starts lets make an autosave with
## initial AdventurePlayer stats (by player name and time hash)".
func test_setting_out_saves_the_adventure() -> void:
	AdventurePlayer.saves_folder = "user://adventure_tests_embark"
	_clear_saves()
	screen.setup.player_name = "Ann Inkpot"
	screen.setup.seed_text = "4242"
	var record := screen.setup.resolve({})
	var opened := screen.set_out(record, AdventureSetup.make_world(record))
	var saves := AdventurePlayer.list_saves()
	assert_eq(saves.size(), 1, "saved as it sets out")
	assert_eq(saves[0]["name"], "Ann Inkpot")
	assert_true(String(saves[0]["path"]).get_file().begins_with("Ann-Inkpot-"), "by name and a hash")
	assert_eq(opened.player.name, "Ann Inkpot", "the world screen shows that adventure")
	assert_eq(AdventurePlayer.load_from(String(saves[0]["path"])).gold, opened.player.gold)
	opened.free()
	_clear_saves()
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _clear_saves() -> void:
	var dir := DirAccess.open(AdventurePlayer.saves_folder)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)


## The owner, 2026-10-22: the walking figure "colored — boots, pants,
## body, arms, hair, skin", chosen here, randomized, and "a default button
## that reuses the OG old game figures".
func test_the_figure_is_dressed_here_and_1997_undresses_it() -> void:
	var row := _find("FigureColors") as Control
	assert_not_null(row)
	for name in ["Hair", "Skin", "Body", "Arms", "Pants", "Boots"]:
		assert_not_null(_find("Figure" + name), name + " has a swatch")
	assert_not_null(_find("FigureOriginal"), "and 1997 its button")
	assert_not_null(_find("FigurePreview"), "the figure shown under its colours")
	screen.choose_figure_color("hair", "blond")
	screen.choose_figure_color("boots", "brown")
	assert_eq(screen.setup.figure_colors, {"hair": "blond", "boots": "brown"})
	assert_string_contains((_find("FigureHair") as Button).tooltip_text, "Blond")
	screen.setup.player_name = "Ann"
	assert_eq(screen.setup.resolve({})["hero"]["figure_colors"], {"hair": "blond", "boots": "brown"},
		"the record carries them")
	screen.open_figure_colors(0)
	var popup := _find("FigureColorsPopup") as PopupPanel
	assert_not_null(popup, "a swatch opens its colours")
	assert_eq(popup.find_children("Pick_*", "Button", true, false).size(), 1 + HeroColors.HAIR.size(),
		"1997 and the hair colours")
	popup.hide()
	(_find("FigureOriginal") as Button).pressed.emit()
	assert_eq(screen.setup.figure_colors, {}, "1997: the old game's own figure")
	assert_string_contains((_find("FigureHair") as Button).tooltip_text, "As in 1997")


## The owner, 2026-10-22: "move the red arrows to each side of portrait …
## move mini figurine preview below the color choices".
func test_the_arrows_flank_the_face_and_the_figure_walks_under_its_colours() -> void:
	await get_tree().process_frame
	var face := (_find("Portrait") as Control).get_global_rect()
	var back := (_find("PreviousFace") as Control).get_global_rect()
	var forward := (_find("NextFace") as Control).get_global_rect()
	assert_lte(back.end.x, face.position.x, "the arrow before on the left of the face")
	assert_gte(forward.position.x, face.end.x, "the arrow after on its right")
	assert_almost_eq(back.get_center().y, face.get_center().y, 8.0, "level with the face's middle")
	var name_band := (_find("FaceName") as Control).get_global_rect()
	assert_true(face.encloses(name_band), "the face's name on the face")
	var row := _find("FigureColors") as Control
	var figure := _find("FigurePreview") as Control
	assert_eq(figure.get_parent(), row.get_parent())
	assert_eq(figure.get_index(), row.get_index() + 1, "next under the colours")
	if figure.visible:
		# Without the 1997 sheets (CI) there is no figure to show.
		assert_gte(figure.get_global_rect().position.y, row.get_global_rect().end.y, "under the colours")
		assert_almost_eq(figure.get_global_rect().get_center().x, row.get_global_rect().get_center().x, 2.0,
			"in the middle")


func test_the_stars_go_one_to_five_and_back() -> void:
	var rows: Array[String] = []
	for step in 10:
		rows.append(EmbarkScreen.stars(step))
	assert_eq(rows, ["*", "**", "***", "****", "*****", "****", "***", "**", "*", "**"] as Array[String])


func test_the_hourglass_runs_and_turns_over() -> void:
	assert_eq(Hourglass.phase(0.0), Vector2.ZERO, "all the sand above")
	assert_almost_eq(Hourglass.phase(Hourglass.RUN * 0.5).x, 0.5, 0.001, "half run through")
	assert_almost_eq(Hourglass.phase(Hourglass.RUN + Hourglass.TURN * 0.5).y, 0.5, 0.001, "turning over")
	assert_almost_eq(Hourglass.phase(Hourglass.RUN + Hourglass.TURN + 0.26).x, 0.26 / Hourglass.RUN, 0.001,
		"and running again")


func test_a_nameless_hero_cannot_embark() -> void:
	watch_signals(screen)
	var name_edit := _find("HeroName") as LineEdit
	name_edit.text = "   "
	screen.embark()
	assert_signal_not_emitted(screen, "embarked")
	var note := _find("Note") as Label
	assert_true(note.visible)
	assert_eq(note.text, "Your hero needs a name.")
	name_edit.text_changed.emit("A")
	assert_false(note.visible, "typing clears it")


func test_embarking_records_and_remembers_the_hero() -> void:
	watch_signals(screen)
	(_find("HeroName") as LineEdit).text = "Hilda of the Hills"
	screen.choose_color("green")
	screen.choose_difficulty(1)
	screen.choose_walker("female")
	(_find("WorldSeed") as LineEdit).text_changed.emit("4242")
	screen.embark()
	assert_signal_emitted(screen, "embarked")
	var record: Dictionary = get_signal_parameters(screen, "embarked")[0]
	assert_eq(record["hero"]["name"], "Hilda of the Hills")
	assert_eq(record["hero"]["walker"], "female")
	assert_eq(record["color"], "green")
	assert_eq(record["difficulty"], 1)
	assert_eq(record["seed"], 4242)
	assert_eq(record["start"]["gold"], 200)
	var back := AdventureSetup.restore([] as Array[String])
	assert_eq([back.player_name, back.color, back.difficulty, back.walker],
		["Hilda of the Hills", "green", 1, "female"], "kept for the next visit")
	assert_string_contains(screen.summary(record), "Hilda of the Hills sets out as a green mage, at Magician level: an easy game.")
	assert_string_contains(screen.summary(record), "World seed 4242.")


func test_a_second_visit_opens_on_the_first_hero() -> void:
	(_find("HeroName") as LineEdit).text = "Second Sight"
	screen.choose_color("blue")
	screen.embark()
	var again: EmbarkScreen = load("res://game/adventure/embark_screen.tscn").instantiate()
	add_child_autofree(again)
	await get_tree().process_frame
	assert_eq((again.find_child("HeroName", true, false) as LineEdit).text, "Second Sight")
	assert_eq((again.find_child("ColorName", true, false) as Label).text, "Blue")


func test_escape_and_leave_go_back_only_from_the_scene() -> void:
	# Held by a test, the screen is not the tree's scene: Leave marks it
	# leaving and does not swap the scene out from under the runner.
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	screen._unhandled_input(escape)
	assert_true(screen._leaving)
	assert_true(screen.is_inside_tree(), "still here: the runner's tree is untouched")
	screen.leave()
	assert_true(screen.is_inside_tree(), "a second Leave is a no-op")


func test_the_title_menu_opens_it() -> void:
	var title: Node = load("res://game/main.tscn").instantiate()
	add_child_autofree(title)
	await get_tree().process_frame
	var door: Button = null
	for n in title.find_children("*", "Button", true, false):
		if (n as Button).text == "Shandalar":
			door = n
	assert_not_null(door)
	var targets := []
	for connection in door.pressed.get_connections():
		targets.append_array((connection["callable"] as Callable).get_bound_arguments())
	assert_has(targets, "res://game/adventure/embark_screen.tscn")


## WITHOUT THE 1997 ART — the ground and the five symbols are the skin's;
## a skin that lacks them (CI, a player who never imported one) gets the
## same dark, flat, and a disc of each colour with its letter.
func test_without_the_1997_art_the_screen_is_whole() -> void:
	GameSkin._texture_cache[EmbarkScreen.BACKGROUND_KEY] = null
	GameSkin._texture_cache["stat_buttons"] = null
	var bare: EmbarkScreen = load("res://game/adventure/embark_screen.tscn").instantiate()
	add_child_autofree(bare)
	await get_tree().process_frame
	GameSkin.clear_caches()
	var ground := bare.find_child("Ground", true, false)
	assert_true(ground is ColorRect and (ground as ColorRect).color == EmbarkScreen.FLAT)
	var letters := []
	for row in AdventureSetup.COLORS:
		var button := bare.find_child("Color" + String(row["name"]), true, false) as Button
		var disc := button.get_child(0)
		assert_true(disc is Panel, String(row["name"]))
		letters.append((disc.get_child(0) as Label).text)
	assert_eq(letters, ["W", "U", "B", "R", "G"])


## THE THREE WINDOWS ARE ONE SIZE AND LINED UP (the owner, 2026-10-22):
## the same width and height, the same top and bottom, and the row's
## edges are the edges of `Leave` and `Adventure`.
func test_the_three_windows_are_one_size_and_lined_up() -> void:
	screen.size = Vector2(1280, 800)
	for i in 3:
		await get_tree().process_frame
	var panels: Array[Control] = []
	for name in ["HeroPanel", "MagicPanel", "JourneyPanel"]:
		panels.append(_find(name) as Control)
	for panel in panels:
		assert_almost_eq(panel.size.x, panels[0].size.x, 1.0, "%s width" % panel.name)
		assert_almost_eq(panel.size.y, panels[0].size.y, 1.0, "%s height" % panel.name)
		assert_almost_eq(panel.global_position.y, panels[0].global_position.y, 1.0, "%s top" % panel.name)
	var leave := _find("Leave") as Control
	var go := _find("Adventure") as Control
	assert_almost_eq(panels[0].global_position.x, leave.global_position.x, 1.0, "left edges")
	assert_almost_eq(panels[2].get_global_rect().end.x, go.get_global_rect().end.x, 1.0, "right edges")
	assert_lt(panels[0].get_global_rect().end.y, leave.global_position.y, "above the buttons")
