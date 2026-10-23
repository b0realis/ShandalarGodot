class_name LoadAdventureScreen
extends Control
## CONTINUE AN ADVENTURE (the owner, 2026-10-22: *"implement a load function
## that loads that player init autosave with the corresponding world, world
## state and all player stats"*). The title's Save / Load opens it: every
## adventure saved ([AdventurePlayer], newest first), and `Continue` takes
## the chosen one back into its world — the hero where they stood, with
## everything they carry, the world as they left it. On the Embark screen's
## dark ground, in its lettering. The world screen's options open it over
## the world ([method WorldScreen.open_load]): Back comes back to that
## world, Continue takes the place of it.

const TITLE := "Continue an adventure"

## The saves shown, as [method AdventurePlayer.list_saves] gives them.
var saves: Array[Dictionary] = []
var _list: ItemList
var _say_line: Label
var continue_button: Button
var back_button: Button
var _leaving := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var art := GameSkin.texture(EmbarkScreen.BACKGROUND_KEY)
	if art != null:
		var ground := TextureRect.new()
		ground.texture = art
		ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ground.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		ground.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(ground)
	else:
		var flat := ColorRect.new()
		flat.color = EmbarkScreen.FLAT
		flat.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(flat)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	margin.add_child(page)
	var title := _lettering(TITLE, 40, EmbarkScreen.GOLD, "font_title")
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(title)
	_list = ItemList.new()
	_list.name = "Saves"
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_font_size_override("font_size", 17)
	_list.add_theme_color_override("font_color", EmbarkScreen.PARCHMENT)
	_list.add_theme_color_override("font_selected_color", EmbarkScreen.GOLD)
	var well := StyleBoxFlat.new()
	well.bg_color = Color(0.09, 0.045, 0.04, 0.85)
	well.border_color = EmbarkScreen.GARNET
	well.set_border_width_all(2)
	well.set_corner_radius_all(6)
	well.set_content_margin_all(10)
	_list.add_theme_stylebox_override("panel", well)
	_list.item_selected.connect(func(_index: int) -> void: continue_button.disabled = false)
	_list.item_activated.connect(func(index: int) -> void: continue_adventure(index))
	page.add_child(_list)
	_say_line = _lettering("", 15, EmbarkScreen.DIM, "font_body")
	_say_line.name = "Note"
	_say_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(_say_line)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	back_button = UiChrome.menu_button("Back", Vector2(180, 46))
	back_button.name = "Back"
	back_button.pressed.connect(leave)
	row.add_child(back_button)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	continue_button = UiChrome.menu_button("Continue", Vector2(220, 46), 24, 0.6)
	continue_button.name = "Continue"
	continue_button.disabled = true
	continue_button.pressed.connect(func() -> void:
		var picked := _list.get_selected_items()
		if not picked.is_empty():
			continue_adventure(picked[0]))
	row.add_child(continue_button)
	page.add_child(row)
	refresh()


## Read the saves again and list them.
func refresh() -> void:
	saves = AdventurePlayer.list_saves()
	_list.clear()
	for save in saves:
		var color := AdventureSetup.color_row(String(save["color"]))
		var when := String(save["saved"]).replace("T", " ").trim_suffix("Z")
		_list.add_item("%s — %s, %s · World seed %s · %s %s" % [String(save["name"]),
			String(color.get("name", save["color"])),
			AdventureSetup.DIFFICULTIES[clampi(int(save["difficulty"]), 0, 3)],
			String(save["seed_text"]),
			"autosaved" if String(save.get("kind", "")) == "autosave" else "saved", when])
	if saves.is_empty():
		_say_line.text = "No adventure has been saved yet. Shandalar on the main menu begins one, and saves it the moment its world is made."
	else:
		_say_line.text = "Choose an adventure and Continue, or double-click it."
		_list.select(0)
		continue_button.disabled = false


## TAKE THE ADVENTURE UP AGAIN: the save in row [param index] read, and its
## world screen made the current scene. False when it cannot be read.
func continue_adventure(index: int) -> bool:
	if _leaving or index < 0 or index >= saves.size():
		return false
	var screen := open_save(String(saves[index]["path"]))
	if screen == null:
		_say_line.text = "That save could not be read."
		return false
	_leaving = true
	if is_inside_tree():
		var tree := get_tree()
		var over := _world_under()
		tree.root.add_child(screen)
		if tree.current_scene == self:
			tree.current_scene = screen
			queue_free()
		elif over != null and tree.current_scene == over:
			tree.current_scene = screen
			over.queue_free()
	return true


## The world screen for the adventure saved at [param path] — not yet in
## the tree — or null.
static func open_save(path: String) -> WorldScreen:
	var adventure := AdventurePlayer.load_from(path)
	if adventure == null:
		return null
	var screen: WorldScreen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.player = adventure
	screen.arrival = "%s takes up the adventure again." % adventure.name
	return screen


func leave() -> void:
	if _leaving:
		return
	_leaving = true
	if _world_under() != null:
		queue_free()
	elif is_inside_tree() and get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://game/main.tscn")


## The world this list is open over, or null.
func _world_under() -> WorldScreen:
	return get_parent() as WorldScreen


func _unhandled_input(event: InputEvent) -> void:
	if not _leaving and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		leave()


func _lettering(text: String, size: int, color: Color, font_key: String) -> Label:
	var label := Label.new()
	label.text = text
	var face := GameSkin.font(font_key)
	if face != null:
		label.add_theme_font_override("font", face)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
