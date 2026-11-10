class_name PluginsWindow
extends Control
## THE EXPANDED ADVENTURE PLUGINS' WINDOW (adventure plugins, 2026-11-10;
## the owner: *"Plugins should get their own popup window for ticking them
## as not to clutter the main embark screen. Only button to reach them at
## the bottom of pack selections."*). The Embark shows one button under its
## card packs; it opens this window over the screen, and here every plugin
## [AdventurePlugins] found is a row:
##  - A VALID ONE: a tick with its name; its version and authors; its one
##    line ("description"); its learning note in a dimmer line; and a line
##    for each card pack it needs — "Needs Pack 2 · Fallen Empires — ticked",
##    "not ticked" or "not installed", or for one installed but older than
##    the plugin asks "Needs Pack 2 · Fallen Empires 1.0 or newer — installed
##    0.9". One that needs a pack not installed, or newer than the one
##    installed, cannot be ticked, its tick greyed and saying why.
##  - A REFUSED ONE: greyed, no tick, every problem the checks found.
##  - A PLUGIN FOUND TWICE (one id in two places): the copy used and the
##    copies passed over ([member AdventurePlugins] "shadowed").
## TICKING A PLUGIN TICKS THE CARD PACKS IT NEEDS ([method
## AdventureSetup.tick_adventure]) and the line under the list says so; the
## Embark ticks their boxes ([signal packs_ticked]). Unticking a pack on the
## Embark unticks the plugins that need it — the Embark says that one.
## Rescan reads the folders again ([method AdventurePlugins.scan]), Open
## folder opens the plugins folder (as Options › Card Packs opens the card
## folder), OK closes; so do Escape and a pad's B.
##
## THE LOOK is the adventure's panes' ([PaneStyle]): rounded dark glass with
## a gold rim over a veil that keeps the screen under it from the pointer,
## the title in the 1997 lettering, the words in the body face, the buttons
## the Embark's own stone ([method UiChrome.menu_button]). A drag on the
## glass — the title, the words over and under the list, the edges — moves
## it, kept on the screen; the list scrolls when it is longer than the
## screen. The keyboard and a pad's D-pad walk the ticks and the buttons
## and stay in the window ([method _fence]).
##
## It works on the Embark's [member setup] directly: a tick takes effect as
## it is made, OK only closes.

## Card packs ticked for a plugin, by id: the Embark ticks their boxes.
signal packs_ticked(ids: Array[String])
## The ticks or the list changed (the Embark's button says the count).
signal changed
## The window closed (OK, Escape, a pad's B).
signal closed

const TITLE := "Expanded adventure plugins"
const ABOUT := "Each plugin adds a land to the adventure, reached by ship from a mainland harbor. Tick the ones this campaign takes; a plugin ticks the card packs it needs."
const NONE_FOUND := "No adventure plugins were found. Put a plugin's .zip in the folder above, then press Rescan."
const OPEN_FOLDER_ANDROID := "This device has no file manager that can open the plugins folder."
## The pane's width at most and at least, what it keeps from every edge of
## the screen, the list's least height and the room kept for its scroll bar.
const WIDTH := 780.0
const LEAST_WIDTH := 420.0
const SCREEN_MARGIN := 24.0
const LIST_LEAST := 160.0
const SCROLL_ROOM := 14.0
## The pane's glass margin, a row's well margin and the indent under a tick.
const GLASS_MARGIN := 16.0
const WELL_MARGIN := 10.0
const INDENT := 30.0

const INK := PaneStyle.INK
const DIM := PaneStyle.DIM
const GOLD := PaneStyle.GOLD
const TICKED := Color8(150, 214, 126)
const NOT_TICKED := Color8(222, 208, 118)
const MISSING := Color8(240, 120, 96)

## The Embark's choices: [member AdventureSetup.adventures] and
## [member AdventureSetup.packs] change here.
var setup: AdventureSetup = null
## The card packs installed, as the Embark reads them.
var installed: Array[String] = []
## [Tests] Called by Open folder in place of [method open_folder].
var folder_opener := Callable()

var rescan_button: Button
var open_button: Button
var ok_button: Button
var _pane: PanelContainer
var _scroll: ScrollContainer
var _list: VBoxContainer
var _message: Label
var _folder: Label
var _header: Array[Label] = []
## The rows' wrapped lines, sized to their width as the pane fits.
var _wrapped: Array[Label] = []
## id -> its tick; the ticks in the order shown.
var _ticks := {}
var _order: Array[String] = []
## The "Needs …" lines: {label, pack}.
var _needs: Array[Dictionary] = []
var _width := WIDTH
var _drag := {}
var _by_hand := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200
	visible = false
	_build()
	get_viewport().size_changed.connect(_on_resized)


# ---------------------------------------------------------------- build --

func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Veil"
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_pane = PanelContainer.new()
	_pane.name = "Pane"
	var glass := PaneStyle.glass(GLASS_MARGIN, 12)
	glass.shadow_color = Color(0, 0, 0, 0.6)
	glass.shadow_size = 10
	_pane.add_theme_stylebox_override("panel", glass)
	_pane.mouse_filter = Control.MOUSE_FILTER_STOP
	_pane.gui_input.connect(_on_pane_input)
	add_child(_pane)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 10)
	_pane.add_child(column)
	var title := PaneStyle.title(TITLE, 28)
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var about := _words(ABOUT, 15, INK, 0.0, false)
	about.name = "About"
	column.add_child(about)
	_header.append(about)
	_folder = _words("", 13, DIM, 0.0, false)
	_folder.name = "Folder"
	column.add_child(_folder)
	_header.append(_folder)
	_scroll = ScrollContainer.new()
	_scroll.name = "List"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.follow_focus = true
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.name = "Rows"
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_message = _words("", 15, GOLD, 0.0, false)
	_message.name = "Message"
	_message.visible = false
	column.add_child(_message)
	_header.append(_message)
	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	column.add_child(buttons)
	rescan_button = UiChrome.menu_button("Rescan", Vector2(150, 38), 18)
	rescan_button.name = "Rescan"
	rescan_button.tooltip_text = "Look in the plugins folders again: for a plugin added or taken away while the game runs."
	rescan_button.pressed.connect(rescan)
	buttons.add_child(rescan_button)
	open_button = UiChrome.menu_button("Open folder", Vector2(170, 38), 18)
	open_button.name = "OpenFolder"
	open_button.pressed.connect(_on_open_folder)
	if OS.has_feature("web") or OS.has_feature("android"):
		open_button.disabled = true
		open_button.focus_mode = Control.FOCUS_NONE
		if OS.has_feature("android"):
			open_button.tooltip_text = OPEN_FOLDER_ANDROID
	buttons.add_child(open_button)
	ok_button = UiChrome.menu_button("OK", Vector2(150, 38), 18)
	ok_button.name = "OK"
	ok_button.tooltip_text = "Close this window. A tick takes effect as it is made."
	ok_button.pressed.connect(close)
	buttons.add_child(ok_button)


## Body lettering, light on the dark glass, a shadow under it; wrapped at
## [param width] when [param row] (a row's line, sized as the pane fits),
## at the pane's width otherwise.
func _words(text: String, size: int, color: Color, width: float, row := true) -> Label:
	var label := Label.new()
	label.text = text
	var face := GameSkin.font("font_body")
	if face != null:
		label.add_theme_font_override("font", face)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if row:
		_wrapped.append(label)
	return label


# -------------------------------------------------------------- the rows --

## Every plugin found, a row each ([method listed]).
func _fill() -> void:
	PaneStyle.drop_children(_list)
	_wrapped.clear()
	_ticks.clear()
	_order.clear()
	_needs.clear()
	_width = _pane_width()
	var text_width := _width - 2 * GLASS_MARGIN - SCROLL_ROOM - 2 * WELL_MARGIN - INDENT
	_folder.text = "Folder: %s" % where(GamePaths.expanded_adventure_folder())
	var rows := listed()
	if rows.is_empty():
		var none := _words(NONE_FOUND, 15, DIM, text_width + INDENT)
		none.name = "NoneFound"
		_list.add_child(none)
	for i in rows.size():
		_list.add_child(_row(rows[i], i, text_width))
	_show_needs()
	_fence()


## THE ROWS IN THE WINDOW'S ORDER: [method AdventurePlugins.all]'s — the
## order found — the plugins that can be played first, the refused after.
static func listed() -> Array[Dictionary]:
	var good: Array[Dictionary] = []
	var refused: Array[Dictionary] = []
	for row in AdventurePlugins.all():
		if (row.get("problems", []) as Array).is_empty() and String(row.get("id", "")) != "":
			good.append(row)
		else:
			refused.append(row)
	good.append_array(refused)
	return good


## One plugin's row: a well holding its tick (or, refused, its name greyed)
## and under it its lines, as the class's header lists them.
func _row(row: Dictionary, index: int, text_width: float) -> Control:
	var id := String(row.get("id", ""))
	var problems: Array = row.get("problems", [])
	var refused := not problems.is_empty() or id == ""
	var well := PanelContainer.new()
	well.name = ("Plugin_" + id) if id != "" and not refused else "Refused_%d" % index
	well.add_theme_stylebox_override("panel", PaneStyle.well(WELL_MARGIN))
	well.tooltip_text = row_tip(row)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	var name_text := String(row.get("name", id))
	if refused:
		well.modulate = Color(1, 1, 1, 0.82)
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(INDENT - 8, 0)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(spacer)
		var title := PaneStyle.label(name_text, 19, DIM)
		title.name = "Name"
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.clip_text = true
		head.add_child(title)
		var tag := PaneStyle.label("Refused", 15, MISSING)
		tag.name = "RefusedTag"
		head.add_child(tag)
	else:
		var tick := _tick(id, name_text)
		head.add_child(tick)
	var details := VBoxContainer.new()
	details.name = "Details"
	details.add_theme_constant_override("separation", 2)
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var indent := MarginContainer.new()
	indent.add_theme_constant_override("margin_left", int(INDENT))
	indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indent.add_child(details)
	column.add_child(indent)
	var by := by_line(row)
	if by != "":
		var by_label := _words(by, 14, DIM, text_width)
		by_label.name = "By"
		details.add_child(by_label)
	var description := String(row.get("description", ""))
	if description != "":
		var words := _words(description, 15, INK if not refused else DIM, text_width)
		words.name = "Description"
		details.add_child(words)
	var note := String(row.get("learning_note", ""))
	if note != "" and not refused:
		var learning := _words(note, 13, DIM, text_width)
		learning.name = "LearningNote"
		details.add_child(learning)
	if refused:
		var wrong := _words(problems_text(problems), 14, MISSING, text_width)
		wrong.name = "Problems"
		details.add_child(wrong)
		var found := _words("Found at %s" % where(String(row.get("path", ""))), 13, DIM, text_width)
		found.name = "Where"
		details.add_child(found)
	else:
		var packs := AdventurePlugins.pack_ids(id)
		if packs.is_empty():
			var free := _words("Needs no card pack.", 14, TICKED, text_width)
			free.name = "NeedsNone"
			details.add_child(free)
		var status := {}
		for need: Variant in row.get("pack_status", []):
			if need is Dictionary:
				status[String(need.get("id", ""))] = need
		for pack in packs:
			var line := _words("", 14, INK, text_width)
			line.name = "Needs_" + pack
			details.add_child(line)
			_needs.append({"label": line, "pack": pack, "id": id, "status": status.get(pack, {})})
	var copies := copies_line(row)
	if copies != "":
		var twice := _words(copies, 13, DIM, text_width)
		twice.name = "Copies"
		details.add_child(twice)
	return well


## A valid plugin's tick, its name the tick's words: greyed, saying why,
## when a card pack it needs is not installed.
func _tick(id: String, words: String) -> CheckBox:
	var tick := CheckBox.new()
	tick.name = "Tick_" + id
	tick.text = words
	tick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tick.clip_text = true
	tick.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tick.focus_mode = Control.FOCUS_ALL
	var face := GameSkin.font("font_title")
	if face != null:
		tick.add_theme_font_override("font", face)
	tick.add_theme_font_size_override("font_size", 19)
	tick.add_theme_color_override("font_color", GOLD)
	tick.add_theme_color_override("font_hover_color", PaneStyle.LIT)
	tick.add_theme_color_override("font_pressed_color", GOLD)
	tick.add_theme_color_override("font_hover_pressed_color", PaneStyle.LIT)
	tick.add_theme_color_override("font_focus_color", PaneStyle.LIT)
	tick.add_theme_color_override("font_disabled_color", Color(DIM, 0.8))
	tick.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	tick.add_theme_constant_override("shadow_offset_x", 1)
	tick.add_theme_constant_override("shadow_offset_y", 1)
	tick.add_theme_icon_override("checked", UiChrome.check_icon(true))
	tick.add_theme_icon_override("unchecked", UiChrome.check_icon(false))
	tick.add_theme_icon_override("checked_disabled", greyed_check(true))
	tick.add_theme_icon_override("unchecked_disabled", greyed_check(false))
	tick.add_theme_stylebox_override("focus", OriginalDialog.focus_ring())
	tick.button_pressed = setup != null and id in setup.adventures
	if not AdventureSetup.can_tick(id, installed):
		tick.disabled = true
		tick.focus_mode = Control.FOCUS_NONE
		tick.tooltip_text = "%s\n%s" % [words, missing_tip(id, installed)]
	else:
		tick.tooltip_text = "%s\nTick it and this campaign sails to its land; the card packs it needs are ticked with it." % words
	tick.toggled.connect(_on_tick.bind(id))
	_ticks[id] = tick
	_order.append(id)
	return tick


## [UiChrome]'s tick box, faded: a tick that cannot be ticked looks it.
static func greyed_check(on: bool) -> Texture2D:
	var key := "on" if on else "off"
	if _greyed.has(key):
		return _greyed[key]
	# A copy: the box's own picture is shared (a headless run hands back
	# the very image the texture was made from).
	var image := UiChrome.check_icon(on).get_image().duplicate() as Image
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			image.set_pixel(x, y, Color(pixel.r, pixel.g, pixel.b, pixel.a * 0.4))
	var faded := ImageTexture.create_from_image(image)
	_greyed[key] = faded
	return faded


static var _greyed := {}


## Each "Needs …" line as the packs stand now.
func _show_needs() -> void:
	var chosen: Array[String] = setup.packs if setup != null else ([] as Array[String])
	for need in _needs:
		var pack := String(need["pack"])
		var status: Dictionary = need["status"]
		var state := pack_state(pack, chosen, installed, status)
		var label: Label = need["label"]
		label.text = needs_line(pack, state, status)
		label.add_theme_color_override("font_color",
			TICKED if state == "ticked" else (NOT_TICKED if state == "not ticked" else MISSING))


# ----------------------------------------------------------------- words --

## "ticked", "not ticked", "not installed" or "too old": pack [param pack]
## among the Embark's ticked [param chosen] and its [param offered]
## installed packs; [param status] its row of [method
## AdventurePlugins.pack_status] — installed but older than the plugin asks
## is "too old", whatever the tick (its ships would not sail).
static func pack_state(pack: String, chosen: Array[String], offered: Array[String], status := {}) -> String:
	if not pack in AdventureSetup.offered_packs(offered):
		return "not installed"
	if bool(status.get("installed", false)) and not bool(status.get("new_enough", true)):
		return "too old"
	return "ticked" if pack in chosen else "not ticked"


## "Needs Pack 2 · Fallen Empires — ticked"; a pack too old says what the
## plugin asks and what is installed: "Needs Pack 2 · Fallen Empires 1.0 or
## newer — installed 0.9".
static func needs_line(pack: String, state: String, status := {}) -> String:
	if state == "too old":
		return "Needs %s %s or newer — installed %s" % [AdventurePacks.title(pack),
			String(status.get("min_version", "")), String(status.get("version", ""))]
	return "Needs %s — %s" % [AdventurePacks.title(pack), state]


## "Version 1.0.0 · by Shandalar Godot"; what the row has of the two.
static func by_line(row: Dictionary) -> String:
	var parts: Array[String] = []
	if String(row.get("version", "")) != "":
		parts.append("Version " + String(row["version"]))
	var authors: Array = row.get("authors", [])
	if not authors.is_empty():
		parts.append("by " + _and(authors.map(func(a: Variant) -> String: return String(a))))
	return " · ".join(parts)


## A refused plugin's problems, all of them, one a line.
static func problems_text(problems: Array) -> String:
	var lines: Array[String] = ["Refused, so it cannot be ticked:"]
	for problem: Variant in problems:
		lines.append("• " + String(problem))
	if problems.is_empty():
		lines.append("• Its plugin.json could not be read.")
	return "\n".join(lines)


## A plugin found in more than one place: the copy used (the first found)
## and the copies passed over; "" for one found once.
static func copies_line(row: Dictionary) -> String:
	var shadowed: Array = row.get("shadowed", [])
	if shadowed.is_empty():
		return ""
	var others: Array[String] = []
	for path: Variant in shadowed:
		others.append(where(String(path)))
	return "Found more than once. The copy used: %s. Not used: %s." % [
		where(String(row.get("path", ""))), "; ".join(others)]


## WHERE A PLUGIN IS, AS THE WINDOW SAYS IT: a path as the Options screen
## shows one ([method GamePaths.shown]: "~/…" under the home folder), and a
## copy in the game's own folder of the repository (a development run's
## `res://expanded_adventure/`) by its name in "the game's own
## expanded_adventure folder" — never an absolute path into a checkout.
static func where(path: String) -> String:
	if path.begins_with("res://"):
		var folder := "res://" + AdventurePlugins.FOLDER_NAME
		var inside := path.get_file()
		if path.trim_suffix("/") == folder:
			inside = ""
		elif path.begins_with(folder + "/"):
			inside = path.trim_prefix(folder + "/")
		return "the game's own %s folder" % AdventurePlugins.FOLDER_NAME if inside == "" else \
			"%s in the game's own %s folder" % [inside, AdventurePlugins.FOLDER_NAME]
	return GamePaths.shown(path)


## The row's hover words: where it was found and its license.
static func row_tip(row: Dictionary) -> String:
	var lines: Array[String] = ["Found at %s" % where(String(row.get("path", "")))]
	if String(row.get("license", "")) != "":
		lines.append("License: " + String(row["license"]))
	return "\n".join(lines)


## Why a valid plugin's tick is greyed: the packs it needs that are not
## installed, else the first installed one older than it asks.
static func missing_tip(id: String, offered: Array[String]) -> String:
	var missing: Array[String] = []
	for pack in AdventurePlugins.pack_ids(id):
		if not pack in AdventureSetup.offered_packs(offered):
			missing.append(AdventurePacks.title(pack))
	if not missing.is_empty():
		return "Install %s in Options › Card Packs to tick this plugin." % _and(missing)
	# Installed but older than the plugin asks: the mainland note's words.
	var old := AdventureExpansions.pack_too_old(id)
	if not old.is_empty():
		return "This plugin needs %s %s or newer (installed %s). Update the pack in Options › Card Packs to tick it." % [
			String(old["title"]), String(old["min_version"]), String(old["version"])]
	return "This plugin cannot be ticked."


## The line under the list for packs ticked with plugin [param id].
static func ticked_words(id: String, packs: Array[String]) -> String:
	if packs.is_empty():
		return ""
	var titles: Array[String] = []
	for pack in packs:
		titles.append(AdventurePacks.title(pack))
	if titles.size() == 1:
		return "%s is ticked too: %s needs it." % [titles[0], plugin_name(id)]
	return "%s are ticked too: %s needs them." % [_and(titles), plugin_name(id)]


## The Embark's words for plugins [param ids] unticked with card pack
## [param pack].
static func unticked_words(ids: Array[String], pack: String) -> String:
	if ids.is_empty():
		return ""
	var names: Array[String] = []
	for id in ids:
		names.append(plugin_name(id))
	if names.size() == 1:
		return "%s is unticked too: it needs %s." % [names[0], AdventurePacks.title(pack)]
	return "%s are unticked too: they need %s." % [_and(names), AdventurePacks.title(pack)]


## A plugin's own name, else its id.
static func plugin_name(id: String) -> String:
	var row := AdventurePlugins.row(id)
	return String(row.get("name", id)) if String(row.get("name", "")) != "" else id


## THE EMBARK BUTTON'S HOVER WORDS: what the plugins are and how many are
## ticked of those found.
static func button_tip(ticked: int, rows: Array[Dictionary]) -> String:
	var refused := 0
	for row in rows:
		if not (row.get("problems", []) as Array).is_empty():
			refused += 1
	var count := "No adventure plugins found." if rows.is_empty() else \
		"%d ticked of %d found%s." % [ticked, rows.size(), "" if refused == 0 else " (%d refused)" % refused]
	return "New lands for the adventure, each reached by ship from a mainland harbor: open the window to tick them.\n" + count


static func _and(words: Array) -> String:
	if words.size() <= 1:
		return "" if words.is_empty() else String(words[0])
	var head: Array[String] = []
	for i in words.size() - 1:
		head.append(String(words[i]))
	return "%s and %s" % [", ".join(head), String(words.back())]


# ------------------------------------------------------------- choices --

## Plugin [param id] ticked or not: ticked, its card packs with it (the
## line under the list says so, the Embark ticks their boxes).
func choose(id: String, on: bool) -> void:
	if setup == null:
		return
	if on:
		if not AdventureSetup.can_tick(id, installed):
			if _ticks.has(id):
				(_ticks[id] as CheckBox).set_pressed_no_signal(false)
			return
		var packs := setup.tick_adventure(id, installed)
		say(ticked_words(id, packs))
		if not packs.is_empty():
			packs_ticked.emit(packs)
	else:
		setup.adventures.erase(id)
		say("")
	if _ticks.has(id) and (_ticks[id] as CheckBox).button_pressed != on:
		(_ticks[id] as CheckBox).set_pressed_no_signal(on)
	_show_needs()
	changed.emit()


func _on_tick(on: bool, id: String) -> void:
	choose(id, on)


## The line under the list; hidden while it has nothing to say.
func say(text: String) -> void:
	_message.text = text
	_message.visible = text != ""
	if visible:
		_fit()


## Whether the window is up.
func shown() -> bool:
	return visible


## RESCAN: the folders read again; a ticked plugin no longer found (or now
## refused) is unticked, and the line says so.
func rescan() -> void:
	var names := {}
	if setup != null:
		for id in setup.adventures:
			names[id] = plugin_name(id)
	AdventurePlugins.scan()
	var gone := _prune()
	_fill()
	var count := AdventurePlugins.all().size()
	var words := "Rescanned: %s found." % ("no plugin" if count == 0 else ("1 plugin" if count == 1 else "%d plugins" % count))
	for id in gone:
		words += " %s is no longer found or cannot be read, so it is unticked." % String(names.get(id, id))
	say(words)
	_fit()
	focus_first()
	changed.emit()


## The ticked plugins that can no longer be ticked, unticked; their ids.
func _prune() -> Array[String]:
	var gone: Array[String] = []
	if setup == null:
		return gone
	for id in setup.adventures.duplicate():
		if not AdventureSetup.can_tick(id, installed):
			setup.adventures.erase(id)
			gone.append(id)
	return gone


func _on_open_folder() -> void:
	if folder_opener.is_valid():
		folder_opener.call()
	else:
		open_folder()


## The plugins folder ([method GamePaths.expanded_adventure_folder]) opened
## in the system's file manager, made first when it is not there yet (as
## Options › Card Packs opens the card folder).
static func open_folder() -> void:
	if OS.has_feature("web"):
		return
	var full := ProjectSettings.globalize_path(GamePaths.expanded_adventure_folder())
	DirAccess.make_dir_recursive_absolute(full)
	OS.shell_open(full)


# ------------------------------------------------------- open and close --

## THE WINDOW OPENS over the screen: its rows as the registry and the
## Embark's ticks stand, fitted to the screen, the keyboard on the first
## tick (OK when there is none).
func open() -> void:
	if not is_inside_tree():
		return
	if not _prune().is_empty():
		changed.emit()
	_fill()
	_message.text = ""
	_message.visible = false
	visible = true
	_fit(true)
	_fit.call_deferred(true)
	focus_first()


## OK, Escape, a pad's B: the window closes.
func close() -> void:
	if not visible:
		return
	visible = false
	_drag = {}
	closed.emit()


## The keyboard on the first tick that can be ticked, else on OK.
func focus_first() -> void:
	if not visible or not is_inside_tree():
		return
	for id in _order:
		var tick: CheckBox = _ticks[id]
		if not tick.disabled and not tick.is_queued_for_deletion():
			tick.grab_focus()
			return
	ok_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	close()


## THE RING STAYS IN THE WINDOW: Up and Down (and Tab) walk the ticks that
## can be ticked and on to the buttons and round; Left and Right walk the
## buttons (a tick keeps them).
func _fence() -> void:
	var ring: Array[Control] = []
	for id in _order:
		var tick: CheckBox = _ticks[id]
		if not tick.disabled:
			ring.append(tick)
	var first_button := ring.size()
	var buttons: Array[Control] = []
	for button: Button in [rescan_button, open_button, ok_button]:
		if not button.disabled and button.focus_mode != Control.FOCUS_NONE:
			buttons.append(button)
	ring.append_array(buttons)
	var count := ring.size()
	for i in count:
		var here := ring[i]
		var up := ring[(i - 1 + count) % count]
		var down := ring[(i + 1) % count]
		here.focus_neighbor_top = here.get_path_to(up)
		here.focus_neighbor_bottom = here.get_path_to(down)
		here.focus_previous = here.get_path_to(up)
		here.focus_next = here.get_path_to(down)
		if i < first_button:
			here.focus_neighbor_left = here.get_path_to(here)
			here.focus_neighbor_right = here.get_path_to(here)
	for i in buttons.size():
		var here := buttons[i]
		here.focus_neighbor_left = here.get_path_to(buttons[(i - 1 + buttons.size()) % buttons.size()])
		here.focus_neighbor_right = here.get_path_to(buttons[(i + 1) % buttons.size()])


# ------------------------------------------------------------- fitting --

func _pane_width() -> float:
	var room := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 800)
	return clampf(room.x - 2 * SCREEN_MARGIN, LEAST_WIDTH, WIDTH)


## THE PANE FITTED: as wide as [constant WIDTH] allows, the list as tall as
## its rows up to what the screen leaves (then it scrolls), in the middle
## of the screen as it opens ([param recentre]) — or where it was dragged,
## kept on the screen; a line said under the list never moves it.
func _fit(recentre := false) -> void:
	if not is_inside_tree() or _pane == null:
		return
	var room := get_viewport_rect().size
	var inner := _width - 2 * GLASS_MARGIN
	for label in _header:
		label.custom_minimum_size.x = inner
		label.size = Vector2(inner, 0)
		label.update_minimum_size()
	for label in _wrapped:
		if is_instance_valid(label):
			label.size = Vector2(label.custom_minimum_size.x, 0)
			label.update_minimum_size()
	var want := _list.get_combined_minimum_size().y
	_scroll.custom_minimum_size = Vector2(inner, 0)
	_pane.custom_minimum_size = Vector2(_width, 0)
	var chrome := _pane.get_combined_minimum_size().y
	var most := maxf(room.y - 2 * SCREEN_MARGIN - chrome, 80.0)
	_scroll.custom_minimum_size.y = clampf(want, minf(LIST_LEAST, most), most)
	_pane.reset_size()
	_place(((room - _pane.size) / 2.0).floor() if recentre and not _by_hand else _pane.position)


func _place(at: Vector2) -> void:
	var room := get_viewport_rect().size
	at.x = clampf(at.x, 0.0, maxf(room.x - _pane.size.x, 0.0))
	at.y = clampf(at.y, 0.0, maxf(room.y - _pane.size.y, 0.0))
	_pane.position = at


func _on_resized() -> void:
	if visible:
		_fit(true)


## A DRAG ON THE GLASS MOVES THE PANE — the title, the words over and under
## the list and the edges; the list itself scrolls and its ticks tick.
func _on_pane_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.button_index == MOUSE_BUTTON_LEFT:
		if press.pressed and not _scroll.get_global_rect().has_point(press.global_position):
			_drag = {"grip": press.global_position - _pane.global_position}
			_pane.accept_event()
		elif not press.pressed and not _drag.is_empty():
			_drag = {}
			_pane.accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and not _drag.is_empty():
		_place(motion.global_position - Vector2(_drag["grip"]) - global_position)
		_by_hand = true
		_pane.accept_event()
