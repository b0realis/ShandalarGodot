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
##
## THE SAVES BY ADVENTURE (2026-10-23, the owner: *"Add 10 named slots"*):
## each adventure under its hero's line — the autosave first ("Resume", as
## 1997's Resume Game took its slot 3), then the named slots it has
## ([SaveSlots]); the newest adventure at the top. Resume, beside Continue,
## takes up the newest autosave of all.
##
## A SAVE THAT CANNOT BE READ (campaign of 2026-10-23) hides no other: the
## list shows every save it can read, on the player's clock, and the note
## below it says how many could not be ([method AdventurePlayer.scan_saves];
## one odd file used to empty the list and grey Resume).
##
## THE END ON THE LIST (part C, 2026-10-28): a save of an adventure WON
## says so with its score — "Won: Arzakon banished for 1130 years" — and a
## save of one whose quest FAILED (a final battle lost under "One life")
## says that ([method AdventurePlayer.save_at]'s `ended` and `score`); the
## hero's line says "One life" when the adventure was begun under it. Taken
## up again, a won adventure walks on in a world at peace, a failed one
## opens on its end ([method AdventureFinale.after_load]).
##
## THE HALL OF FAME [ours] (the owner, 2026-10-27: *"Only hall of fame
## button should be inside save/load as not to clutter the main menu!"*):
## the button beside Back opens it over the list ([HallOfFamePane]); Done or
## Escape closes it, the list as it was.

const TITLE := "Continue an adventure"
const HALL := "Hall of Fame"
## A save's end on its row (part C): a won adventure with its years, a
## failed quest; and the hero's line under "One life".
const WON_ROW := " · Won: Arzakon banished for %d years"
const FAILED_ROW := " · Quest failed"
const ONE_LIFE := " · One life"

## The saves shown, as [method AdventurePlayer.list_saves] gives them, in the
## list's order.
var saves: Array[Dictionary] = []
## The save each row of the list takes up (`{}` for an adventure's line).
var rows: Array[Dictionary] = []
## How many save files could not be read, as the note says.
var unreadable := 0
var resume_button: Button
var _list: ItemList
var _say_line: Label
var continue_button: Button
var back_button: Button
var hall_button: Button
var _hall: HallOfFamePane
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
	_list.item_selected.connect(func(index: int) -> void:
		continue_button.disabled = index < 0 or index >= rows.size() or rows[index].is_empty())
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
	hall_button = UiChrome.menu_button(HALL, Vector2(200, 46))
	hall_button.name = "HallButton"
	hall_button.pressed.connect(func() -> void: open_hall())
	row.add_child(hall_button)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	resume_button = UiChrome.menu_button("Resume", Vector2(200, 46), 24, 0.6)
	resume_button.name = "Resume"
	resume_button.pressed.connect(resume)
	row.add_child(resume_button)
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


## Read the saves again and list them, adventure by adventure.
func refresh() -> void:
	SaveSlots.migrate(AdventurePlayer.saves_folder)
	var scanned := AdventurePlayer.scan_saves()
	var found: Array[Dictionary] = scanned["saves"]
	unreadable = int(scanned["unreadable"])
	# The adventures in the order of their newest save; each one's autosave,
	# then its slots by number.
	var order: Array[String] = []
	var by_id := {}
	for save in found:
		var id := String(save["id"])
		if not by_id.has(id):
			order.append(id)
			by_id[id] = []
		(by_id[id] as Array).append(save)
	saves.clear()
	rows.clear()
	_list.clear()
	for id in order:
		var group: Array = by_id[id]
		group.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["slot"]) < int(b["slot"]))
		var hero: Dictionary = group[0]
		var color := AdventureSetup.color_row(String(hero["color"]))
		var heading := _list.add_item("%s — %s, %s · World seed %s%s" % [String(hero["name"]),
			String(color.get("name", hero["color"])),
			AdventureSetup.DIFFICULTIES[clampi(int(hero["difficulty"]), 0, 3)], String(hero["seed_text"]),
			ONE_LIFE if String(hero.get("life_rule", "")) == AdventurePlayer.LIFE_ONE else ""])
		_list.set_item_selectable(heading, false)
		_list.set_item_custom_fg_color(heading, EmbarkScreen.GOLD)
		rows.append({})
		for save in group:
			var when := AdventurePlayer.local_time(String(save["saved"]))
			var words := ""
			if int(save["slot"]) == 0:
				words = "      Resume · autosaved %s · day %d · %d gold" % [when, int(save["days"]), int(save["gold"])]
			else:
				words = "      %d. %s · saved %s · day %d" % [int(save["slot"]), String(save["slot_name"]),
					when, int(save["days"])]
			_list.add_item(words + end_words(save))
			rows.append(save)
			saves.append(save)
	resume_button.disabled = newest_autosave().is_empty()
	if saves.is_empty():
		_say_line.text = unreadable_note() if unreadable > 0 \
			else "No adventure has been saved yet. Shandalar on the main menu begins one, and saves it the moment its world is made."
		continue_button.disabled = true
	else:
		_say_line.text = "Choose a save and Continue, or double-click it; Resume takes up the newest autosave."
		if unreadable > 0:
			_say_line.text += " " + unreadable_note()
		_list.select(1)
		continue_button.disabled = false


## The end a save's row tells of (part C): " · Won: Arzakon banished for
## 1130 years", " · Quest failed", or "" while the adventure goes on.
static func end_words(save: Dictionary) -> String:
	match String(save.get("ended", "")):
		AdventurePlayer.ENDED_WON:
			return WON_ROW % int(save.get("score", 0))
		AdventurePlayer.ENDED_FAILED:
			return FAILED_ROW
	return ""


## THE HALL OF FAME over the list ([HallOfFamePane]); Done or Escape closes
## it. The pane, or the one already open.
func open_hall() -> HallOfFamePane:
	if is_instance_valid(_hall) and not _hall.is_queued_for_deletion():
		return _hall
	_hall = HallOfFamePane.open(self)
	_hall.chosen.connect(func(_what: String) -> void:
		if is_instance_valid(_hall):
			_hall.queue_free(), CONNECT_DEFERRED)
	return _hall


## Whether the Hall of Fame is open over the list.
func hall_shown() -> bool:
	return is_instance_valid(_hall) and not _hall.is_queued_for_deletion()


## "2 saves could not be read …": the saves the list leaves out.
func unreadable_note() -> String:
	return "%d %s could not be read (damaged, or saved by a newer version of the game)." % [
		unreadable, "save" if unreadable == 1 else "saves"]


## The newest autosave of all, or `{}`.
func newest_autosave() -> Dictionary:
	var best := {}
	for save in saves:
		if int(save["slot"]) == 0 and (best.is_empty() or String(save["saved"]) > String(best["saved"])):
			best = save
	return best


## RESUME: the newest autosave taken up (1997's Resume Game).
func resume() -> bool:
	var newest := newest_autosave()
	return not newest.is_empty() and continue_adventure(rows.find(newest))


## TAKE THE ADVENTURE UP AGAIN: the save in row [param index] read, and its
## world screen made the current scene. False when it cannot be read.
func continue_adventure(index: int) -> bool:
	if _leaving or index < 0 or index >= rows.size() or rows[index].is_empty():
		return false
	var screen := open_save(String(rows[index]["path"]))
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
	if hall_shown():
		# The Hall over the list hears its own keys (its Escape is Done).
		return
	if event.is_action_pressed("ui_cancel"):
		# Taken even while leaving: a second Escape in the same frame finds
		# nothing left to close, not the world under the list (the bug pass
		# after the campaign, r3-2 — it left the world for the title).
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
