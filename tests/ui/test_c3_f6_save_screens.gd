extends GutTest
## THE SAVES ON SCREEN (campaign of 2026-10-23, fixer f6): the load screen
## lists every save it can read and says how many it could not (one odd
## file used to empty the list and grey Resume); picking a slot in the
## save list to name it reads no file (it re-read every save); both lists
## show a save's time on the player's clock; a first save that fails on
## Embark is told; a skin arriving refreshes the adventure's own tables;
## and a world taken up from a save with broken records runs without an
## error. Clicks are real ones, pushed through a viewport.

const FOLDER := "user://adventure_tests_c3_f6_screens"

var viewport: SubViewport


func before_each() -> void:
	AdventurePlayer.saves_folder = FOLDER
	_clear()
	AdventurePlayer.forget_saves()
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)


func after_each() -> void:
	_clear()
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	AdventurePlayer.forget_saves()


func _clear() -> void:
	for folder in [FOLDER, FOLDER + "_blocked"]:
		var dir := DirAccess.open(folder)
		if dir != null:
			for file_name in dir.get_files():
				dir.remove(file_name)
			DirAccess.remove_absolute(folder)
	if FileAccess.file_exists(FOLDER + "_blocked"):
		DirAccess.remove_absolute(FOLDER + "_blocked")


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _begin(id := "base") -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.player_name = "Probe Hero"
	setup.color = "green"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "4242"
	var record := setup.resolve({})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	player.adventure_id = id
	return player


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## A real left click on [param node]'s middle, through the viewport.
func _click(node: Control) -> void:
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
	await _frames(2)


func _load_screen() -> LoadAdventureScreen:
	var screen: LoadAdventureScreen = load("res://game/adventure/load_adventure_screen.tscn").instantiate()
	viewport.add_child(screen)
	await _frames(1)
	return screen


# ----------------------------------------------- h4-2: the load screen --

func test_the_load_screen_lists_what_it_can_and_counts_what_it_cannot() -> void:
	var player := _begin()
	player.autosave()
	_write(FOLDER.path_join("odd.autosave.json"), "{ cut sho")
	var data: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	data["adventure"]["id"] = "edited"
	data["carried"] = "oops"
	_write(FOLDER.path_join("edited.autosave.json"), JSON.stringify(data))
	var screen := await _load_screen()
	assert_eq(screen.saves.size(), 1, "the good adventure is listed")
	assert_false(screen.resume_button.disabled, "and Resume takes it up")
	var note := (screen.find_child("Note", true, false) as Label).text
	assert_string_contains(note, "2 saves could not be read")


func test_with_only_unreadable_saves_it_does_not_say_none_was_saved() -> void:
	_write(FOLDER.path_join("odd.autosave.json"), "{ cut sho")
	var screen := await _load_screen()
	assert_true(screen.saves.is_empty())
	assert_true(screen.resume_button.disabled)
	var note := (screen.find_child("Note", true, false) as Label).text
	assert_false(note.contains("No adventure has been saved yet"), note)
	assert_string_contains(note, "1 save could not be read")


# --------------------------------------------- h5-7: the save list's cost --

func test_picking_a_slot_to_name_it_reads_no_file() -> void:
	var player := _begin()
	player.autosave()
	SaveSlots.save_into(player, 1, "Named 1")
	var pane := SaveSlotsPane.new()
	pane.player = player
	viewport.add_child(pane)
	await _frames(2)
	var before := AdventurePlayer.files_parsed
	var pick := pane.find_child("Pick_2", true, false) as Button
	assert_not_null(pick)
	await _click(pick)
	assert_eq(pane.editing, 2, "the click picked the slot")
	assert_not_null(pane.find_child("SlotName", true, false), "its name to type")
	assert_eq(AdventurePlayer.files_parsed - before, 0, "and read no save to do it")
	var field := pane.find_child("SlotName", true, false) as LineEdit
	field.text = "Second"
	field.text_submitted.emit(field.text)
	await _frames(1)
	assert_string_contains(pane.note(), "Saved to slot 2: Second.")
	assert_eq(AdventurePlayer.files_parsed - before, 0, "nor to save and show the slots again")
	assert_eq(String((pane.find_child("Pick_2", true, false) as Button).text), "Second")


# ----------------------------------------------- h4-7: the player's clock --

func test_both_lists_show_a_save_s_time_on_the_player_s_clock() -> void:
	var player := _begin()
	player.autosave()
	SaveSlots.save_into(player, 1, "Named 1")
	var shown := AdventurePlayer.local_time(player.saved)
	assert_ne(shown, "")
	var pane := SaveSlotsPane.new()
	pane.player = player
	viewport.add_child(pane)
	await _frames(1)
	var row := pane.find_child("Slot_1", true, false)
	var texts: Array = row.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	assert_has(texts, shown, "the slot's time as the player's clock shows it")
	pane.queue_free()
	var screen := await _load_screen()
	var list := screen.find_child("Saves", true, false) as ItemList
	var lines: Array[String] = []
	for i in list.item_count:
		lines.append(list.get_item_text(i))
	assert_true(lines.any(func(line: String) -> bool: return line.contains("autosaved " + shown)), str(lines))


# ---------------------------------------------- h4-3: the first save --

func test_a_first_save_that_fails_is_told_on_arrival() -> void:
	# A file where the saves' folder should be: nothing can be written.
	_write(FOLDER + "_blocked", "not a folder")
	AdventurePlayer.saves_folder = FOLDER + "_blocked/adventures"
	var embark: EmbarkScreen = load("res://game/adventure/embark_screen.tscn").instantiate()
	add_child_autofree(embark)
	await _frames(1)
	embark.setup.player_name = "Ann Inkpot"
	embark.setup.seed_text = "4242"
	var record := embark.setup.resolve({})
	var opened := embark.set_out(record, AdventureSetup.make_world(record))
	assert_string_contains(opened.arrival, EmbarkScreen.NOT_SAVED)
	opened.free()
	AdventurePlayer.saves_folder = FOLDER
	var fine := embark.set_out(record, AdventureSetup.make_world(record))
	assert_false(fine.arrival.contains(EmbarkScreen.NOT_SAVED), "said only when it failed")
	fine.free()


# ------------------------------------------------ h4-13: a skin arrives --

func test_a_skin_arriving_refreshes_the_adventure_s_own_tables() -> void:
	WiseMan._words = {"sentinel": true}
	WiseMan._read = true
	CardHints._hints = [{"sentinel": true}]
	CardHints._read = true
	CardValue._imported = {"sentinel": true}
	CardValue._imported_read = true
	CardShop._stock.append({"sentinel": true})
	CardRiddle._pool.append({"sentinel": true})
	CardTrade._catalogue.append({"sentinel": true})
	LairEvent._treasures.append({"sentinel": true})
	SkinPack._arrived("skin")
	SkinPack._hide_notice()
	assert_false(WiseMan._read, "the wise men's words read again")
	assert_false(CardHints._read, "the hints")
	assert_false(CardValue._imported_read, "1997's card values")
	assert_true(CardShop._stock.is_empty(), "the shops' stock")
	assert_true(CardRiddle._pool.is_empty(), "the riddles")
	assert_true(CardTrade._catalogue.is_empty(), "the trade catalogue")
	assert_true(LairEvent._treasures.is_empty(), "the lairs' cards")


# ------------------------------------------- h4-5: broken records, live --

func test_a_world_taken_up_with_broken_records_runs_without_an_error() -> void:
	var player := _begin()
	var data: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	data["world"]["monsters"] = [5, "x", {"slot": 0, "kind": "lair", "color": 1}]
	data["carried"]["cards"].append_array(["Lightning Bolt", 5, {"card": 3}, {"decks": "x"}])
	data["record"]["journal"] = [5, "x", {"event": 3}, {"event": "duel", "won": "yes", "x": "a"}]
	data["world"]["world_magic_sites"] = [999, -1]
	var shops := {}
	for i in 20:
		shops[str(i)] = ["abc", {"cards": "x"}, [], {"cards": [1, 2], "restock": "r"}, {"restock": []}][i % 5]
	data["world"]["shops"] = shops
	var back := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(data)))
	assert_not_null(back)
	var screen: WorldScreen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.player = back
	viewport.add_child(screen)
	await _frames(2)
	for i in 40:
		screen.advance(0.5)
	screen.hud.toggle_hero()
	await _frames(1)
	screen.hud.toggle_hero()
	for slot in back.world.sites.size():
		if int(back.world.sites[slot]["type"]) in [ShandalarWorld.TOWN, ShandalarWorld.CITY]:
			CardShop.offers(back, slot)
			CardHints.current(back, slot)
	assert_eq(back.monsters.filter(func(m: Variant) -> bool: return not m is Dictionary), [],
		"every creature a record")
	screen.queue_free()
	await _frames(1)
