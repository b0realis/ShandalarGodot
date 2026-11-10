class_name LoadAdventureScreen
extends Control
## RESUME AN ADVENTURE: the highlighted save restores its hero and world.
## The newest eligible autosave is selected initially; without one, use the
## newest quickslot or manual save whose quest has not failed. Each adventure
## lists its blue Quickslot, autosave and ten named slots under its hero.
## Back returns to the underlying world, or to the title screen.
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
## opens on its end ([method AdventureFinale.after_load]). So does a save of
## "One life" from before its final battle was lost or while it was fought
## — a slot saved at the portal, the autosave of a game closed mid-battle:
## the Hall's file marks the battle begun or lost outside every save
## ([method HallOfFame.one_life_state]), the load settles it as a loss
## ([method FinalBattle.on_load]), and its row says "Quest failed" too
## ([method quest_failed]). Initial selection skips failed quests, but a
## player can still choose one explicitly to view its end.
##
## THE HALL OF FAME [ours] (the owner, 2026-10-27: *"Only hall of fame
## button should be inside save/load as not to clutter the main menu!"*):
## the button beside Back opens it over the list ([HallOfFamePane]); Done or
## Escape closes it, the list as it was.
##
## [QoL] DELETE (a play-tester's report and the owner, 2026-11-05: *"Is
## there a way in game to delete save files you don't want?"*): the button
## beside Back, or the Delete key, asks first ([DeleteAsk]) — the
## highlighted save alone, or every save of its adventure — and then
## removes the files with their `.bak` copies. The Hall of Fame keeps its
## lines; the list is read again.
##
## [QoL] EXPORT AND IMPORT (a player on Android asked whether he can copy
## his saves to a PC; the owner, 2026-11-06: *"Yes implement both point 1.
## And 2.!"*): Export, or Ctrl+E, writes the highlighted save's whole
## adventure — every save of it with their `.bak` copies — as one zip
## where the player chooses in the platform's own file box (on Android the
## system's, so Downloads will do; in a browser it is downloaded). Import,
## or Ctrl+I, takes such a zip from anywhere, checks all of it, and puts
## the adventure among the saves — asking first ([ReplaceAsk]) when it is
## here already, and saying so when the saves here are newer. The list is
## read again with the adventure highlighted ([AdventureTransfer]).

const TITLE := "Resume an adventure"
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
## The Hall's One-life marks as the list was read ([method
## HallOfFame.one_life_marks]).
var marks := {}
var resume_button: Button
var _list: ItemList
var _say_line: Label
var back_button: Button
var hall_button: Button
var delete_button: Button
var export_button: Button
var import_button: Button
var _hall: HallOfFamePane
var _delete_ask: DeleteAsk
var _replace_ask: ReplaceAsk
var _leaving := false
## Export's and Import's words on their buttons.
const EXPORT_TIP := "Save the highlighted save's whole adventure, every save of it, as one file you can copy to another device (Ctrl+E)."
const EXPORT_TIP_WEB := "Download the highlighted save's whole adventure, every save of it, as one file (Ctrl+E)."
const IMPORT_TIP := "Bring in an adventure exported on this or another device (Ctrl+I)."
## Whether this is the browser, where Export is a download and Import
## opens the page's own file box ([method pick_import]); a test stands in
## for it.
var on_web := OS.has_feature("web")
## The doors to the page in a browser — a script run on it, and a
## download — so a test, where no browser runs, can stand in for them.
var web_page := func(script: String) -> Variant: return JavaScriptBridge.eval(script, true)
var web_download := func(bytes: PackedByteArray, file_name: String) -> void: JavaScriptBridge.download_buffer(bytes, file_name, "application/zip")
## The browser's file box for Import: whether one is open or its file
## being read in, the file's name and size as the page said them, how far
## the read is, and the file it goes into ([method _read_page_pick]).
var _page_picking := false
var _page_file: FileAccess
var _page_name := ""
var _page_size := 0
var _page_offset := 0
## Eight megabytes a frame from the page's memory, as Options › Skin reads
## a chosen zip in ([member SkinPack.PICK_CHUNK]).
const PAGE_CHUNK := 8 << 20
## The page's half of the browser's file box for Import: an `<input
## type=file>` opened for the player, the chosen file read whole into
## `window.shandalarAdventurePick` as a Uint8Array for [method
## _read_page_pick] to pull across — the way Options › Skin's chooser
## does ([constant SkinPack.PICK_JS]). Run again while a box waits, it
## takes the earlier one off the page first; only the newest answers. `%d`
## is the largest file taken.
const PAGE_PICK_JS := """
(function () {
	var stale = window.shandalarAdventureInput;
	if (stale && stale.parentNode) { stale.parentNode.removeChild(stale); }
	window.shandalarAdventurePick = {state: "open"};
	var input = document.createElement("input");
	window.shandalarAdventureInput = input;
	input.type = "file";
	input.accept = ".zip,application/zip";
	input.style.display = "none";
	document.body.appendChild(input);
	var done = function (result) {
		if (window.shandalarAdventureInput !== input) { return; }
		window.shandalarAdventureInput = null;
		window.shandalarAdventurePick = result;
		if (input.parentNode) { input.parentNode.removeChild(input); }
	};
	input.addEventListener("change", function () {
		var file = input.files && input.files[0];
		if (!file) { done({state: "cancelled"}); return; }
		if (file.size > %d) { done({state: "big", name: file.name}); return; }
		var reader = new FileReader();
		reader.onload = function () {
			done({state: "ready", name: file.name, data: new Uint8Array(reader.result)});
		};
		reader.onerror = function () { done({state: "failed", name: file.name}); };
		reader.readAsArrayBuffer(file);
	});
	input.addEventListener("cancel", function () { done({state: "cancelled"}); });
	input.click();
})();
"""
## Whether a save's packs to switch on are built on a thread while the
## hourglass shows ([method continue_adventure]; 0.60.15): windowed —
## headless (the tests) on the spot, unless a test says so.
var packs_aside := DisplayServer.get_name() != "headless"
## The buttons' row, and the hourglass shown in its place while the cards
## load ([method _show_waiting]).
var _row: HBoxContainer
var _wait: HBoxContainer
var _hold: Control
## What the wait says: the title's own words for the same wait (`main.gd`,
## `WAITING_TEXT`).
const WAITING := "Loading cards…"


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
	_list.item_selected.connect(func(index: int) -> void: _sync_buttons(index))
	_list.item_activated.connect(func(index: int) -> void: continue_adventure(index))
	page.add_child(_list)
	_say_line = _lettering("", 15, EmbarkScreen.DIM, "font_body")
	_say_line.name = "Note"
	_say_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(_say_line)
	var row := HBoxContainer.new()
	_row = row
	row.add_theme_constant_override("separation", 16)
	back_button = UiChrome.menu_button("Back", Vector2(180, 46))
	back_button.name = "Back"
	back_button.pressed.connect(leave)
	hall_button = UiChrome.menu_button(HALL, Vector2(200, 46))
	hall_button.name = "HallButton"
	hall_button.pressed.connect(func() -> void: open_hall())
	_gild_hall_button()
	row.add_child(hall_button)
	# Export and Import beside the Hall (2026-11-06): the adventure taken
	# elsewhere and brought back; Delete, Back and Resume stay together.
	export_button = UiChrome.menu_button("Export", Vector2(150, 46))
	export_button.name = "Export"
	export_button.tooltip_text = EXPORT_TIP_WEB if on_web else EXPORT_TIP
	export_button.pressed.connect(func() -> void: pick_export())
	row.add_child(export_button)
	import_button = UiChrome.menu_button("Import", Vector2(150, 46))
	import_button.name = "Import"
	import_button.tooltip_text = IMPORT_TIP
	import_button.pressed.connect(func() -> void: pick_import())
	row.add_child(import_button)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	delete_button = UiChrome.menu_button("Delete", Vector2(160, 46))
	delete_button.name = "Delete"
	delete_button.tooltip_text = "Delete the highlighted save, or every save of its adventure (Delete key)."
	delete_button.pressed.connect(func() -> void: ask_delete())
	row.add_child(delete_button)
	row.add_child(back_button)
	resume_button = UiChrome.menu_button("Resume", Vector2(200, 46), 24, 0.6)
	resume_button.name = "Resume"
	resume_button.pressed.connect(resume)
	row.add_child(resume_button)
	page.add_child(row)
	refresh()


## Read the saves again and list them, adventure by adventure.
func refresh() -> void:
	AdventurePlayer.settle_saves()
	SaveSlots.migrate(AdventurePlayer.saves_folder)
	var scanned := AdventurePlayer.scan_saves()
	var found: Array[Dictionary] = scanned["saves"]
	unreadable = int(scanned["unreadable"])
	marks = HallOfFame.one_life_marks()
	# Adventures by newest save; each one's quickslot, autosave, named slots.
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
			if int(save["slot"]) == SaveSlots.QUICK_SLOT:
				words = "      Quickslot · saved %s · day %d · %d gold" % [when, int(save["days"]), int(save["gold"])]
			elif int(save["slot"]) == 0:
				words = "      Autosave · autosaved %s · day %d · %d gold" % [when, int(save["days"]), int(save["gold"])]
			else:
				words = "      %d. %s · saved %s · day %d" % [int(save["slot"]), String(save["slot_name"]),
					when, int(save["days"])]
			var index := _list.add_item(words + end_words(save, marks))
			if int(save["slot"]) == SaveSlots.QUICK_SLOT:
				_list.set_item_custom_fg_color(index, PaneStyle.QUICK_BLUE)
			rows.append(save)
			saves.append(save)
	var selected := initial_selection()
	_sync_buttons(selected)
	if selected >= 0:
		_list.select(selected)
	if saves.is_empty():
		_say_line.text = unreadable_note() if unreadable > 0 \
			else "No adventure has been saved yet. Shandalar on the main menu begins one, and saves it the moment its world is made; Import brings in an adventure exported on another device."
	else:
		_say_line.text = "Choose a save and Resume, or double-click it."
		if unreadable > 0:
			_say_line.text += " " + unreadable_note()


## Resume, Delete and Export as row [param index] stands: a save, or
## nothing.
func _sync_buttons(index: int) -> void:
	var none := index < 0 or index >= rows.size() or rows[index].is_empty()
	resume_button.disabled = none
	delete_button.disabled = none
	export_button.disabled = none


## The end a save's row tells of (part C): " · Won: Arzakon banished for
## 1130 years", " · Quest failed" (also for a save the load would settle as
## a lost final battle, [method quest_failed]), or "" while the adventure
## goes on. [param one_life] the Hall's One-life marks, read from its file
## when not given.
static func end_words(save: Dictionary, one_life: Variant = null) -> String:
	if String(save.get("ended", "")) == AdventurePlayer.ENDED_WON:
		return WON_ROW % int(save.get("score", 0))
	if quest_failed(save, one_life):
		return FAILED_ROW
	return ""


## WHETHER [param save] OPENS ON THE QUEST-FAILED END: its adventure failed;
## or, of "One life" and not ended, its save stands at Arzakon's door or the
## Hall's marks ([param one_life], `{id: state}`, read from the Hall's file
## when not given) say its final battle began or was lost — as [method
## FinalBattle.on_load] reads it.
static func quest_failed(save: Dictionary, one_life: Variant = null) -> bool:
	var how := String(save.get("ended", ""))
	if how == AdventurePlayer.ENDED_FAILED:
		return true
	if how != "" or String(save.get("life_rule", "")) != AdventurePlayer.LIFE_ONE:
		return false
	if bool(save.get("at_door", false)):
		return true
	var known: Dictionary = one_life if one_life is Dictionary else HallOfFame.one_life_marks()
	return String(known.get(String(save.get("id", "")), "")) in HallOfFame.ONE_LIFE_STATES


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


## The newest autosave of all whose quest has not failed ([method
## quest_failed]), used for initial selection, or `{}`.
func newest_autosave() -> Dictionary:
	var best := {}
	for save in saves:
		if int(save["slot"]) == 0 and not quest_failed(save, marks) \
				and (best.is_empty() or String(save["saved"]) > String(best["saved"])):
			best = save
	return best


## [QoL] Prefer the newest eligible autosave even when a quickslot or manual
## save appears before it. Failed quests are only opened by explicit choice.
func initial_selection() -> int:
	var selected := newest_autosave()
	if selected.is_empty():
		for save in saves:
			if not quest_failed(save, marks) and (selected.is_empty() \
					or String(save["saved"]) > String(selected["saved"])):
				selected = save
	return -1 if selected.is_empty() else rows.find(selected)


# ------------------------------------------------------------- delete --

## ASK BEFORE DELETING the highlighted save ([DeleteAsk]): this save, or
## every save of its adventure when it has more than one. The ask, the one
## already open, or null when no save is highlighted.
func ask_delete() -> DeleteAsk:
	if delete_shown():
		return _delete_ask
	var save := highlighted()
	if _leaving or hall_shown() or replace_shown() or save.is_empty():
		return null
	var id := String(save["id"])
	var group := saves_of(id)
	_delete_ask = DeleteAsk.new()
	var kind := _kind_words(save)
	_delete_ask.words = "%s of %s will be deleted for good." % [kind[0].to_upper() + kind.substr(1),
		String(save["name"])]
	var world := _world_under()
	if world != null and world.player != null and world.player.adventure_id == id:
		_delete_ask.words += " It is the adventure you are playing: it is saved again as you go on."
	_delete_ask.all_count = group.size()
	add_child(_delete_ask)
	PaneStyle.centre(_delete_ask)
	var asked := _delete_ask
	asked.answered.connect(func(what: String) -> void:
		if is_instance_valid(asked):
			asked.queue_free()
		if what == DeleteAsk.THIS:
			delete_save(save)
		elif what == DeleteAsk.ALL:
			delete_adventure(id), CONNECT_DEFERRED | CONNECT_ONE_SHOT)
	return asked


## Whether the delete ask is open over the list.
func delete_shown() -> bool:
	return is_instance_valid(_delete_ask) and not _delete_ask.is_queued_for_deletion()


## The saves listed for adventure [param id].
func saves_of(id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for save in saves:
		if String(save["id"]) == id:
			out.append(save)
	return out


## DELETE [param save]: its file and its `.bak` — and on Android its copy
## left in the folder the saves came from, which would show in its place
## ([method AdventurePlayer.saves_folders]); the list read again. True
## when nothing of it is left.
func delete_save(save: Dictionary) -> bool:
	var path := String(save["path"])
	var gone := _remove_save_files(path)
	for folder in AdventurePlayer.saves_folders():
		gone = _remove_save_files(folder.path_join(path.get_file())) and gone
	refresh()
	_say_line.text = ("Deleted %s of %s." if gone else "Could not delete %s of %s.") % [
		_kind_words(save), String(save["name"])]
	return gone


## DELETE EVERY SAVE OF ADVENTURE [param id]: the files listed, and every
## file its Quickslot, autosave and ten slots would be, with their `.bak`
## copies, in every folder the saves are read from; the list read again.
## True when nothing of it is left.
func delete_adventure(id: String) -> bool:
	var hero := ""
	var paths: Array[String] = []
	for save in saves_of(id):
		hero = String(save["name"])
		paths.append(String(save["path"]))
	for folder in AdventurePlayer.saves_folders():
		paths.append(folder.path_join("%s.%s.json" % [id, AdventurePlayer.AUTOSAVE]))
		for slot in [SaveSlots.QUICK_SLOT] + range(1, SaveSlots.SLOTS + 1):
			paths.append(SaveSlots.path_of(id, slot, folder))
	var gone := true
	for path in paths:
		gone = _remove_save_files(path) and gone
	refresh()
	_say_line.text = ("Deleted every save of %s." if gone else "Could not delete every save of %s.") % (
		hero if hero != "" else id)
	return gone


## The file at [param path] and its `.bak` removed: true when neither is left.
static func _remove_save_files(path: String) -> bool:
	for file in [path, AdventurePlayer.backup_path(path)]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
	return not FileAccess.file_exists(path) and not FileAccess.file_exists(AdventurePlayer.backup_path(path))


## "the Quickslot", "the autosave", "slot 3 “By the river”" for [param save].
static func _kind_words(save: Dictionary) -> String:
	var slot := int(save["slot"])
	if slot == SaveSlots.QUICK_SLOT:
		return "the Quickslot"
	if slot == 0:
		return "the autosave"
	return "slot %d “%s”" % [slot, String(save["slot_name"])]


## The save highlighted in the list, `{}` when none is.
func highlighted() -> Dictionary:
	var picked := _list.get_selected_items()
	return {} if picked.is_empty() or picked[0] >= rows.size() else rows[picked[0]]


# ---------------------------------------------------- export and import --

## EXPORT THE HIGHLIGHTED SAVE'S ADVENTURE (the class doc): the platform's
## own file box to choose where — on Android the system's, so Downloads
## will do — opening on the player's downloads with the file's name
## filled in ([method AdventureTransfer.file_name_for]); in a browser a
## download at once ([method export_on_page]).
func pick_export() -> void:
	var save := highlighted()
	if _busy() or save.is_empty():
		return
	if on_web:
		export_on_page(String(save["id"]))
		return
	var id := String(save["id"])
	var box := FileDialog.new()
	box.name = "ExportChooser"
	box.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	# After the mode: setting the mode retitles the box.
	box.title = "Export the adventure"
	box.access = FileDialog.ACCESS_FILESYSTEM
	box.filters = PackedStringArray(["*.zip ; Exported adventures"])
	box.use_native_dialog = true
	box.size = Vector2i(760, 520)
	box.current_dir = load("res://game/skin_pack.gd").pick_start_dir()
	box.current_file = AdventureTransfer.file_name_for(String(save["name"]))
	box.file_selected.connect(func(path: String) -> void:
		box.queue_free()
		export_to(path, id))
	box.canceled.connect(box.queue_free)
	add_child(box)
	box.popup_centered()


## ADVENTURE [param id] (the highlighted save's by default) EXPORTED to
## [param dest] ([method AdventureTransfer.export_to]); the note says how
## it went. A path the player typed without `.zip` is refused rather than
## given one, which could land on another file the box never asked about
## (as Export MPN does, [method MpnFiles.export_bytes]). True when written.
func export_to(dest: String, id := "") -> bool:
	if id == "":
		id = String(highlighted().get("id", ""))
	if id == "":
		return false
	if not AdventureTransfer.is_uri(dest) and dest.get_extension().to_lower() != "zip":
		_say_line.text = "Please use a file name ending in .zip. Nothing was exported."
		return false
	var made := AdventureTransfer.export_to(id, dest)
	_say_line.text = _exported_words(made, "" if AdventureTransfer.is_uri(dest) else " in " + dest.get_file()) \
		if bool(made["ok"]) else String(made["message"])
	return bool(made["ok"])


## IN A BROWSER: adventure [param id] packed and handed to the browser as a
## download (there is no folder to choose); the note says so.
func export_on_page(id: String) -> bool:
	var made := AdventureTransfer.packed_bytes(id)
	if not bool(made["ok"]):
		_say_line.text = String(made["message"])
		return false
	var file_name := AdventureTransfer.file_name_for(String(made["hero"]))
	web_download.call(made["bytes"], file_name)
	_say_line.text = _exported_words(made, ", downloaded as " + file_name)
	return true


## "Exported Goya's adventure: 5 saves in <file>." — and how many files
## of it could not be read and were left out.
static func _exported_words(made: Dictionary, where: String) -> String:
	var count := int(made["saves"])
	var words := "Exported %s's adventure: %d %s%s." % [String(made["hero"]), count,
		"save" if count == 1 else "saves", where]
	var left := int(made.get("left_out", 0))
	if left > 0:
		words += " %d %s that could not be read %s left out." % [left, "file" if left == 1 else "files",
			"was" if left == 1 else "were"]
	return words


## IMPORT AN ADVENTURE (the class doc): the platform's own file box for a
## zip from anywhere — the downloads first — then [method import_from]; in
## a browser the page's own box ([method _pick_on_page]).
func pick_import() -> void:
	if _busy():
		return
	if on_web:
		_pick_on_page()
		return
	var box := FileDialog.new()
	box.name = "ImportChooser"
	box.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	box.title = "Choose an exported adventure"
	box.access = FileDialog.ACCESS_FILESYSTEM
	box.filters = PackedStringArray(["*.zip ; Exported adventures"])
	box.use_native_dialog = true
	box.size = Vector2i(760, 520)
	box.current_dir = load("res://game/skin_pack.gd").pick_start_dir()
	box.file_selected.connect(func(path: String) -> void:
		box.queue_free()
		import_from(path))
	box.canceled.connect(box.queue_free)
	add_child(box)
	box.popup_centered()


## THE ZIP AT [param source] IMPORTED: copied in and checked whole first
## ([method AdventureTransfer.take_in]; a refusal is the note, nothing
## written). An adventure that is here already asks Replace or Cancel
## ([ReplaceAsk]) — saying so when the saves here are newer — and the one
## being played is not written over at all. [param shown] names the file
## in the note. True when the adventure was put among the saves now
## (false while the ask is open).
func import_from(source: String, shown := "") -> bool:
	if _busy():
		return false
	var package := AdventureTransfer.take_in(source, shown)
	if not bool(package["ok"]):
		_say_line.text = String(package["message"])
		return false
	var id := String(package["id"])
	var hero := String(package["hero"])
	var world := _world_under()
	if world != null and world.player != null and world.player.adventure_id == id:
		_say_line.text = "%s's adventure is the one you are playing: import it from Save / Load on the main menu." % hero
		return false
	var here := AdventureTransfer.existing(id)
	if int(here["files"]) == 0:
		return _install(package)
	_replace_ask = ReplaceAsk.new()
	var count := int(package["saves"])
	var words := "%s's adventure is here already, with %d %s." % [hero, int(here["saves"]),
		"save" if int(here["saves"]) == 1 else "saves"] if int(here["saves"]) > 0 \
		else "Files of %s's adventure are here already." % hero
	words += " Replace them with the %d imported %s?" % [count, "save" if count == 1 else "saves"]
	if String(here["newest"]) > String(package["newest"]):
		words += " The saves here are newer: the last was saved %s, the imported ones %s." % [
			AdventurePlayer.local_time(String(here["newest"])), AdventurePlayer.local_time(String(package["newest"]))]
	_replace_ask.words = words
	add_child(_replace_ask)
	PaneStyle.centre(_replace_ask)
	var asked := _replace_ask
	asked.answered.connect(func(replace: bool) -> void:
		if is_instance_valid(asked):
			asked.queue_free()
		if replace:
			_install(package)
		else:
			_say_line.text = "Nothing was imported.", CONNECT_DEFERRED | CONNECT_ONE_SHOT)
	return false


## Whether the Replace ask is open over the list.
func replace_shown() -> bool:
	return is_instance_valid(_replace_ask) and not _replace_ask.is_queued_for_deletion()


## The checked [param package] written among the saves ([method
## AdventureTransfer.install]), the list read again with its adventure
## highlighted, and the note saying what happened.
func _install(package: Dictionary) -> bool:
	var done := AdventureTransfer.install(package)
	refresh()
	if bool(done["ok"]):
		_highlight_adventure(String(done["id"]))
	_say_line.text = String(done["message"])
	return bool(done["ok"])


## Adventure [param id]'s save highlighted: its newest autosave whose quest
## has not failed, else its newest such save, else its newest.
func _highlight_adventure(id: String) -> void:
	var best := {}
	var rank := func(save: Dictionary) -> int:
		return (0 if quest_failed(save, marks) else 2) + (1 if int(save["slot"]) == 0 else 0)
	for save in saves_of(id):
		if best.is_empty() or rank.call(save) > rank.call(best) \
				or (rank.call(save) == rank.call(best) and String(save["saved"]) > String(best["saved"])):
			best = save
	var index := rows.find(best) if not best.is_empty() else -1
	if index >= 0:
		_list.select(index)
		_list.ensure_current_is_visible()
	_sync_buttons(index)


## Whether a pane over the list, the wait, or the way out holds the list.
func _busy() -> bool:
	return _leaving or hall_shown() or delete_shown() or replace_shown()


## THE BROWSER'S BOX for Import, opened — or opened afresh when a box
## still waits with nothing read (a browser that never says a box was
## closed would otherwise hold Import dead, as Options › Skin learnt,
## [method SkinPack._pick_on_page]). Not while a chosen file is read in.
func _pick_on_page() -> void:
	if _page_file != null:
		return
	_page_picking = true
	web_page.call(PAGE_PICK_JS % AdventureTransfer.max_total_bytes)
	set_process(true)


func _process(_delta: float) -> void:
	if _page_picking:
		_read_page_pick()


## One frame of the browser's box: while it is open, wait; once the page
## has the file, pull a slice across into [constant
## AdventureTransfer.INCOMING]; when the last is in, [method import_from].
func _read_page_pick() -> void:
	if _page_file == null:
		var state := String(web_page.call(
			"window.shandalarAdventurePick ? window.shandalarAdventurePick.state : 'gone'"))
		if state == "open":
			return
		if state != "ready":
			var named := String(web_page.call("window.shandalarAdventurePick ? (window.shandalarAdventurePick.name || '') : ''"))
			named = named if named != "" else "The file"
			if state == "big":
				_say_line.text = AdventureTransfer.TOO_BIG % named
			elif state == "failed":
				_say_line.text = AdventureTransfer.NOT_READ % named
			_page_pick_over()
			return
		_page_name = String(web_page.call("window.shandalarAdventurePick.name"))
		_page_size = int(web_page.call("window.shandalarAdventurePick.data.length"))
		_page_offset = 0
		DirAccess.make_dir_recursive_absolute(AdventureTransfer.STAGING)
		_page_file = FileAccess.open(AdventureTransfer.INCOMING, FileAccess.WRITE)
		if _page_file == null:
			_say_line.text = AdventureTransfer.NOT_READ % _page_name
			_page_pick_over()
			return
	var stop := mini(_page_offset + PAGE_CHUNK, _page_size)
	if stop > _page_offset:
		var slice: Variant = web_page.call("window.shandalarAdventurePick.data.subarray(%d, %d)" % [_page_offset, stop])
		if not slice is PackedByteArray or (slice as PackedByteArray).size() != stop - _page_offset:
			_say_line.text = AdventureTransfer.NOT_READ % _page_name
			_page_pick_over()
			return
		_page_file.store_buffer(slice)
		_page_offset = stop
	if _page_offset >= _page_size:
		_page_file.close()
		_page_file = null
		_page_pick_over()
		import_from(AdventureTransfer.INCOMING, _page_name)


## The browser's box done with: the page's copy let go, the frames quiet,
## and a file half read in closed and removed.
func _page_pick_over() -> void:
	_page_picking = false
	set_process(false)
	web_page.call("window.shandalarAdventurePick = null;")
	if _page_file != null:
		_page_file.close()
		_page_file = null
		DirAccess.remove_absolute(AdventureTransfer.INCOMING)


func _exit_tree() -> void:
	if _page_picking:
		_page_pick_over()


## RESUME always takes up the highlighted save, including a manual slot.
func resume() -> bool:
	var picked := _list.get_selected_items()
	return not picked.is_empty() and continue_adventure(picked[0])


## [QoL] Gold stone for the Hall, retaining the shell's texture and feedback.
func _gild_hall_button() -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var face := hall_button.get_theme_stylebox(state).duplicate() as StyleBox
		var tint := Color(1.18, 0.98, 0.48)
		if state == "hover":
			tint = Color(1.30, 1.12, 0.62)
		elif state in ["pressed", "hover_pressed"]:
			tint = Color(0.95, 0.77, 0.36)
		if face is StyleBoxTexture:
			face.modulate_color = tint
		elif face is StyleBoxFlat:
			face.bg_color = Color(0.66, 0.46, 0.12) * tint
			face.border_color = EmbarkScreen.GOLD
		hall_button.add_theme_stylebox_override(state, face)


## TAKE THE ADVENTURE UP AGAIN: the save in row [param index] read, and its
## world screen made the current scene. False when it cannot be read.
##
## ITS PACKS SWITCHED ON BEHIND AN HOURGLASS (0.60.15, the owner's ruling of
## 2026-11-03: "Same for `resume` on load"): a save whose packs are off
## rebuilt the card pool once a pack on this thread — a frozen window of
## 1.5–2.8 s. They go on in one rebuild compiled on a thread ([method
## open_save]); the hourglass shows in the buttons' place while it runs,
## and the world is put up when the pool is ready. A start-up pool still
## building as the save is chosen is waited out the same way first (true:
## taken up once it is done, or the note says why not).
func continue_adventure(index: int) -> bool:
	if _leaving or index < 0 or index >= rows.size() or rows[index].is_empty():
		return false
	var path := String(rows[index]["path"])
	if packs_aside and CardRegistry.is_loading():
		_take_up_after_pool(path)
		return true
	return _take_up(path)


## The save at [param path] taken up ([method continue_adventure]).
func _take_up(path: String) -> bool:
	var refusal: Array[String] = []
	var screen := open_save(path, refusal, packs_aside)
	if screen == null:
		_hide_waiting()
		_leaving = false
		_say_line.text = refusal[0] if not refusal.is_empty() else "That save could not be read."
		return false
	_leaving = true
	if packs_aside and CardRegistry.is_loading():
		_show_waiting()
		_put_up_when_ready(screen)
		return true
	_put_up(screen)
	return true


## The start-up pool waited out under the hourglass, then the save taken up.
func _take_up_after_pool(path: String) -> void:
	_leaving = true
	_show_waiting()
	while CardRegistry.is_loading() and not CardRegistry.poll():
		await get_tree().process_frame
	if not is_inside_tree():
		return
	_take_up(path)


## [param screen] put up once the pool its packs went on in is ready.
func _put_up_when_ready(screen: WorldScreen) -> void:
	while not CardRegistry.poll() and CardRegistry.is_loading():
		await get_tree().process_frame
		if not is_inside_tree():
			screen.free()
			return
	_put_up(screen)


## THE WAIT, SHOWN: the hourglass and its words in the buttons' place, the
## list held still.
func _show_waiting() -> void:
	if _wait != null:
		return
	_hold = Control.new()
	_hold.name = "HoldStill"
	_hold.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hold.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_hold)
	var height := maxf(_row.size.y, 46.0)
	for child in _row.get_children():
		(child as Control).visible = false
	_wait = HBoxContainer.new()
	_wait.name = "Waiting"
	_wait.alignment = BoxContainer.ALIGNMENT_CENTER
	_wait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wait.custom_minimum_size.y = height
	_wait.add_theme_constant_override("separation", 18)
	var glass := Hourglass.new()
	glass.name = "Hourglass"
	glass.custom_minimum_size = Vector2(height, height)
	glass.reach = 1.4
	glass.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_wait.add_child(glass)
	var words := _lettering(WAITING, 24, EmbarkScreen.GOLD, "font_title")
	words.name = "Words"
	words.autowrap_mode = TextServer.AUTOWRAP_OFF
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wait.add_child(words)
	_row.add_child(_wait)
	get_viewport().gui_release_focus()


func _hide_waiting() -> void:
	if _wait == null:
		return
	_wait.queue_free()
	_wait = null
	_hold.queue_free()
	_hold = null
	for child in _row.get_children():
		(child as Control).visible = true


## [param screen] made the current scene, over this list's scene or the
## world it was opened over.
func _put_up(screen: WorldScreen) -> void:
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


## The world screen for the adventure saved at [param path] — not yet in
## the tree — or null.
##
## ITS CARD PACKS FIRST (0.60.13 bug campaign, h3-1; the owner, 2026-10-28:
## "resume with a notice (a missing pack refuses and says which)"): a pack
## the campaign chose that is not installed refuses it — null, and the words
## naming the pack appended to [param refusal]; one installed but switched
## off is enabled, as the Embark does, and the arrival says so ([method
## AdventurePacks.resume]).
##
## [param aside] (0.60.15): those packs go on in one rebuild compiled on a
## thread, and the screen comes back at once — not to be put in the tree
## until [method CardRegistry.poll] says the pool is ready ([method
## continue_adventure]); without it the pool is built here.
static func open_save(path: String, refusal: Array[String] = [], aside := false) -> WorldScreen:
	var adventure := AdventurePlayer.load_from(path)
	if adventure == null:
		return null
	var packs := AdventurePacks.resume(adventure, aside)
	if String(packs["refusal"]) != "":
		refusal.append(String(packs["refusal"]))
		return null
	var screen: WorldScreen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.player = adventure
	screen.arrival = "%s takes up the adventure again." % adventure.name
	var enabled := AdventurePacks.enabled_notice(packs["enabled"])
	if enabled != "":
		screen.arrival += "\n" + enabled
	var away := stranded_note(adventure)
	if away != "":
		screen.arrival += "\n" + away
	return screen


## [QoL] A HERO TAKEN UP ON A LAND WHOSE PLUGIN IS MISSING (adventure
## plugins, 2026-11-10; the plugin spec's §0.5) OR HELD — installed in a
## version that cannot read the land as it was saved ([method
## AdventureExpansions.held]; the reviewers' RV2-5): the save opens all the
## same, and the arrival says why the land is quiet and the way home in the
## words of its port's own pane ([method AdventureExpansions.stranded_place]).
## On the mainland the world says it itself ([method
## AdventureExpansions.mainland_note]). "" for a hero on the mainland or on
## a land its plugin reads.
static func stranded_note(adventure: AdventurePlayer) -> String:
	if adventure == null or adventure.world == null or AdventureRegions.mainland(adventure):
		return ""
	var id := AdventureRegions.id(adventure.world)
	if AdventureExpansions.known(id) and not AdventureExpansions.held(adventure, id):
		return ""
	var lines: Array = AdventureExpansions.stranded_place(adventure, "port").get("lines", [])
	return " ".join(PackedStringArray(lines))


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
	if hall_shown() or delete_shown() or replace_shown():
		# The Hall over the list hears its own keys (its Escape is Done),
		# and so do the delete ask (its Escape keeps the save) and the
		# Replace ask (its Escape cancels the import).
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_DELETE:
		get_viewport().set_input_as_handled()
		ask_delete()
		return
	# Ctrl+E exports, Ctrl+I imports (2026-11-06): no key of the list's own.
	if key != null and key.pressed and not key.echo and key.ctrl_pressed and not key.alt_pressed \
			and key.keycode in [KEY_E, KEY_I]:
		get_viewport().set_input_as_handled()
		if key.keycode == KEY_E:
			pick_export()
		else:
			pick_import()
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


## DELETE, ASKED (the class doc): the save's words, then Delete this save,
## All its saves (when its adventure has more than one) and Keep; Escape,
## or K, keeps it. The choices answer to their first letter, as the
## world's asks do ([method VisitPane.letter_choice]).
class DeleteAsk extends PanelContainer:
	## [param what] [constant THIS], [constant ALL], or "" for Keep.
	signal answered(what: String)

	const THIS := "this"
	const ALL := "all"

	## The words over the choices.
	var words := ""
	## How many saves its adventure has: All its saves shows above one.
	var all_count := 1
	var _choices: HBoxContainer

	func _ready() -> void:
		name = "DeleteAsk"
		mouse_filter = Control.MOUSE_FILTER_STOP
		add_theme_stylebox_override("panel", PaneStyle.glass(16.0))
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 10)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(column)
		column.add_child(PaneStyle.title("Delete save?", 24))
		column.add_child(PaneStyle.wrapped(words + " This cannot be undone.", 16, 440.0))
		var choices := HBoxContainer.new()
		_choices = choices
		choices.alignment = BoxContainer.ALIGNMENT_CENTER
		choices.add_theme_constant_override("separation", 10)
		choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var this_one := PaneStyle.button("Delete this save", "DeleteThis")
		this_one.pressed.connect(func() -> void: answered.emit(THIS))
		choices.add_child(this_one)
		if all_count > 1:
			var every := PaneStyle.button("All its saves (%d)" % all_count, "DeleteAll")
			every.pressed.connect(func() -> void: answered.emit(ALL))
			choices.add_child(every)
		var keep := PaneStyle.button("Keep", "Keep")
		keep.pressed.connect(func() -> void: answered.emit(""))
		choices.add_child(keep)
		column.add_child(choices)

	func _input(event: InputEvent) -> void:
		VisitPane.drop_letter(_choices, event)

	func _unhandled_input(input: InputEvent) -> void:
		if input.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			answered.emit("")
		elif VisitPane.letter_choice(self, _choices, input):
			get_viewport().set_input_as_handled()


## REPLACE, ASKED (the class doc): an adventure imported that is here
## already — the words say how many saves each side has and whether the
## saves here are newer — then Replace and Cancel; Escape, or C, cancels.
## The choices answer to their first letter, as [DeleteAsk]'s do.
class ReplaceAsk extends PanelContainer:
	## [param replace] true for Replace, false for Cancel.
	signal answered(replace: bool)

	## The words over the choices.
	var words := ""
	var _choices: HBoxContainer

	func _ready() -> void:
		name = "ReplaceAsk"
		mouse_filter = Control.MOUSE_FILTER_STOP
		add_theme_stylebox_override("panel", PaneStyle.glass(16.0))
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 10)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(column)
		column.add_child(PaneStyle.title("Replace saves?", 24))
		column.add_child(PaneStyle.wrapped(words + " The saves here are deleted; this cannot be undone.", 16, 440.0))
		var choices := HBoxContainer.new()
		_choices = choices
		choices.alignment = BoxContainer.ALIGNMENT_CENTER
		choices.add_theme_constant_override("separation", 10)
		choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var replace := PaneStyle.button("Replace", "Replace")
		replace.pressed.connect(func() -> void: answered.emit(true))
		choices.add_child(replace)
		var cancel := PaneStyle.button("Cancel", "Cancel")
		cancel.pressed.connect(func() -> void: answered.emit(false))
		choices.add_child(cancel)
		column.add_child(choices)

	func _input(event: InputEvent) -> void:
		VisitPane.drop_letter(_choices, event)

	func _unhandled_input(input: InputEvent) -> void:
		if input.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			answered.emit(false)
		elif VisitPane.letter_choice(self, _choices, input):
			get_viewport().set_input_as_handled()
