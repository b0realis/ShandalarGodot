class_name PackBuilderWindow
extends Control
## CARD PACKS — the window behind Options' purple Get Card Packs... (the owner,
## 2026-11-23: *"The user would only choose which card pack from the popup
## window and do ok. Then a progress bar would show how far along he is!"*).
##
## Eleven rows: the 1997 card pictures and Packs 1 to 10, each with a
## checkbox, how it stands (Installed, Not here, Part downloaded: 312 of
## 760…) and what it costs to download and to keep. OK builds the ticked
## ones one after another ([PackBuild]): the pictures are fetched from
## Scryfall, the zip is written and checked by the game's own rules and
## put in the card folder. While that runs there is one bar for the pack
## in hand, a line for the whole job and a Stop that keeps what was
## downloaded; at the end a summary says what is in, what is not and why,
## and whether a restart is needed.
##
## An in-game modal like [method UiChrome.action_popup] — a veil over the
## host with a stone panel on it, never an OS window. It is in the popup
## group with Close as its cancel action, and takes Escape (pad B, the
## back gesture) itself: Stop while a pack is being built, Close otherwise.
## The keyboard and the D-pad walk the rows and the buttons and stay on
## the window.
##
## Everything the window asks of the game goes through a [PackBuildHost],
## so a test runs it whole against a stand-in.
##
## The lettering is plain: no seat or shadow behind it (the owner,
## 2026-11-22).

const WIDTH := 780.0
const TITLE := "Card Packs"
const INTRO := "Choose what to build. The game downloads the card pictures from Scryfall (scryfall.com), builds each pack, checks it and puts it in %s. This needs the internet and free disk space: everything together is about %s to download and %s on disk."
const NO_BROWSER := "A browser has no card folder: card packs are built by the game on a computer or a handheld."
const LOCKED_NOTE := "Nothing can be built now: %s"
const NOTHING_CHOSEN := "Nothing chosen."
const NOT_IN_BUILD := "Not in this build"
const NOT_IN_BUILD_WHY := "This build of the game does not carry the pack's card list (%s), so it cannot build the pack."
const TURN_ON := "Turn %s on in Options > Card Packs."
const ART_NOW := "The cards wear them as soon as this window closes."
const ART_RESTART := "The cards wear them from the next start of the game."
## Seconds a picture takes, the questions, the writing and the checking
## counted in, until this run has a pace of its own. Measured over a home
## line, 2026-11-23, with the questions asked in batches: Pack 5 whole —
## 288 pictures, 28.7 MB, two questions — in 59 seconds, 55 of them the
## download.
const SECONDS_PER_PICTURE := 0.21
## The same with the pause between pictures dropped: that measured figure
## less the tenth of a second the game itself waits after each picture. A
## sum, not a measurement — no run has been timed this way — so it only
## opens the estimate; the run's own pace takes over after four pictures.
const SECONDS_PER_PICTURE_UNPAUSED := 0.11
const GENTLE := "Go easy on Scryfall's servers"
const GENTLE_TIP := "Pause a little between pictures. It applies from the next start of a download."
const WHY_TITLE := "About the download"
const WHY_BODY := "Thank you, Scryfall! Every card picture here comes from scryfall.com, which shares its card data and pictures with the whole community for free.\n\nLet's be nice to their servers: with this ticked, the game asks for one thing at a time and pauses a little between pictures, so a full set of packs takes about half an hour.\n\nUnticked, only the pause between pictures is dropped; the game still asks one thing at a time and still waits whenever Scryfall asks it to."
## Failed packs the summary gives a line of their own, reason and all; any
## beyond them are named in one line. And the most room the summary takes:
## past it, it scrolls, so the window never grows off the screen.
const FAILURES_IN_FULL := 3
const SUMMARY_MOST := 190.0
## The line while the card pool takes the new packs in ([method
## PackBuildHost.settling]) — on a thread, the window alive meanwhile.
const READING := "Reading the new packs..."
## Pixels an arrow key scrolls the summary; PageUp and PageDown go most of
## a box.
const SUMMARY_STEP := 40
const BAR := Color(0.78, 0.62, 0.30)
const BAR_GROUND := Color(0.18, 0.15, 0.11)
const DIM := Color8(74, 66, 60)

var game: PackBuildHost
## "choose" or "working".
var mode := "choose"

var _rows := {}               # id -> {check, state, size, status}
var _order: Array[String] = []
var _intro: Label
var _chosen: Label
var _gentle: CheckBox
var _why: Button
var _work: VBoxContainer
var _line: Label
var _bar: ProgressBar
var _overall: Label
var _summary: Label
var _summary_box: ScrollContainer
var _ok: Button
var _close: Button
var _stop: Button

var _queue: Array[String] = []
var _at := 0
var _build: PackBuild = null
var _outcomes: Array[Dictionary] = []
var _stopped := false
var _art_built := false
var _focus_before: WeakRef = null
## The last job's packs are in and the card pool is reading them.
var _settling := false
var _settle_in := 0
var _installed: Array = []
## The caches of packs that are installed are being removed ([method
## PackBuildHost.sweep]).
var _sweeping := false


## Open the window over [param host]. [param on] stands in for the game in
## tests; the game itself passes nothing.
static func open_on(host: Control, on: PackBuildHost = null) -> Control:
	if on == null and OS.has_feature("web"):
		return UiChrome.explain_popup(host, TITLE, NO_BROWSER)
	var window := PackBuilderWindow.new()
	window.game = on if on != null else PackBuildHost.new()
	window.name = "PackBuilderWindow"
	host.add_child(window)
	return window


func _ready() -> void:
	# Anchors AND offsets: in the tree, the anchors alone would keep the
	# rect this node had before — none.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 300
	add_to_group(UiChrome.POPUP_GROUP)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	var heading := _label(TITLE, 22)
	var title_font := GameSkin.font("font_title")
	if title_font != null:
		heading.add_theme_font_override("font", title_font)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	# What an earlier run left half-written (a crash, a power cut) goes.
	game.clear_work()
	_intro = _label(_intro_text(), 14)
	_intro.name = "Intro"
	_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intro.custom_minimum_size.x = WIDTH - 60.0
	column.add_child(_intro)

	var table := GridContainer.new()
	table.name = "Rows"
	table.columns = 4
	table.add_theme_constant_override("h_separation", 14)
	table.add_theme_constant_override("v_separation", 2)
	for head: String in ["Pack", "State", "Download", "On disk"]:
		var cell := _label(head, 13)
		cell.add_theme_color_override("font_color", DIM)
		if head != "Pack" and head != "State":
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		table.add_child(cell)
	for id: String in PackRecipes.ids():
		var about := PackRecipes.about(id)
		var check := CheckBox.new()
		check.name = "Check_" + id
		check.text = String(about["title"])
		check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_dress_check(check)
		check.toggled.connect(_on_ticked.unbind(1))
		table.add_child(check)
		var state := _label("", 14)
		state.name = "State_" + id
		state.custom_minimum_size.x = 230.0
		state.mouse_filter = Control.MOUSE_FILTER_PASS
		table.add_child(state)
		var download := _label("%d pictures, %d MB" % [int(about["pictures"]), int(about["fetch_mb"])], 14)
		download.name = "Download_" + id
		download.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		table.add_child(download)
		var kept := _label("%d MB" % int(about["zip_mb"]), 14)
		kept.name = "Kept_" + id
		kept.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		table.add_child(kept)
		_rows[id] = {"check": check, "state": state, "status": {}, "cached": 0}
		_order.append(id)
	column.add_child(table)

	_chosen = _label(NOTHING_CHOSEN, 14)
	_chosen.name = "Chosen"
	_chosen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chosen.custom_minimum_size.x = WIDTH - 60.0
	column.add_child(_chosen)

	# GO EASY ON SCRYFALL'S SERVERS, and a "?" that says why (the owner,
	# 2026-11-23: "a tick on/off option to limit the download rate with a
	# question mark button besides it"). Ticked unless the player unticked
	# it, and kept in the settings.
	var gentle_row := HBoxContainer.new()
	gentle_row.add_theme_constant_override("separation", 8)
	_gentle = CheckBox.new()
	_gentle.name = "PackGentle"
	_gentle.text = GENTLE
	_gentle.tooltip_text = GENTLE_TIP
	_dress_check(_gentle)
	_gentle.set_pressed_no_signal(game.gentle())
	_gentle.toggled.connect(_on_gentle)
	gentle_row.add_child(_gentle)
	_why = UiChrome.menu_button("?", Vector2(30, 26), 15)
	_why.name = "PackGentleWhy"
	_why.tooltip_text = "Why?"
	_plain(_why)
	_why.pressed.connect(_explain)
	gentle_row.add_child(_why)
	column.add_child(gentle_row)

	_work = VBoxContainer.new()
	_work.name = "Work"
	_work.add_theme_constant_override("separation", 4)
	_work.visible = false
	_line = _label("", 15)
	_line.name = "Line"
	_line.clip_text = true
	_work.add_child(_line)
	_bar = ProgressBar.new()
	_bar.name = "Bar"
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 18)
	var ground := StyleBoxFlat.new()
	ground.bg_color = BAR_GROUND
	var fill := StyleBoxFlat.new()
	fill.bg_color = BAR
	_bar.add_theme_stylebox_override("background", ground)
	_bar.add_theme_stylebox_override("fill", fill)
	_work.add_child(_bar)
	_overall = _label("", 14)
	_overall.name = "Overall"
	_work.add_child(_overall)
	column.add_child(_work)

	_summary = _label("", 14)
	_summary.name = "Summary"
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.visible = false
	# In a box as tall as its lines up to [constant SUMMARY_MOST], which
	# scrolls past that; shown and hidden with the label.
	_summary_box = ScrollContainer.new()
	_summary_box.name = "SummaryBox"
	_summary_box.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_summary_box.custom_minimum_size.x = WIDTH - 60.0
	_summary_box.visible = false
	_summary_box.add_child(_summary)
	# A LONG SUMMARY IS READ BY THE KEYBOARD AND THE PAD (campaign
	# 2026-11-26): past [constant SUMMARY_MOST] the box scrolled by the
	# wheel alone. It now takes the ring when it has more than it shows,
	# and Up, Down, PageUp, PageDown, Home and End scroll it; at either end
	# Up and Down move the ring on, as on any row.
	_summary_box.focus_mode = Control.FOCUS_NONE
	# The ring is drawn here: the box's own focus border takes room from
	# the text, and a summary that just fit grew a scroll bar.
	_summary_box.draw.connect(_draw_summary_ring)
	_summary_box.focus_entered.connect(_summary_box.queue_redraw)
	_summary_box.focus_exited.connect(_summary_box.queue_redraw)
	_summary_box.gui_input.connect(_on_summary_input)
	_summary.minimum_size_changed.connect(_fit_summary)
	_summary.visibility_changed.connect(_fit_summary)
	column.add_child(_summary_box)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	_ok = _button("OK")
	_ok.pressed.connect(_start)
	buttons.add_child(_ok)
	_stop = _button("Stop")
	_stop.pressed.connect(stop)
	_stop.visible = false
	buttons.add_child(_stop)
	_close = _button("Close")
	_close.pressed.connect(close)
	buttons.add_child(_close)
	column.add_child(buttons)
	set_meta(&"cancel_button", _close)

	var panel := UiChrome.panel_around(column, 18.0)
	panel.name = "Panel"
	panel.custom_minimum_size.x = WIDTH
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	_refresh_rows()
	_fence()
	# The ring comes onto the window, and goes back where it was when the
	# window closes (the button that opened it, on the screen under it).
	var before := get_viewport().gui_get_focus_owner()
	_focus_before = weakref(before) if before != null and not is_ancestor_of(before) else null
	_first_focus().grab_focus()
	set_process(false)
	_sweep_caches()


func _exit_tree() -> void:
	# Gone with its screen while a pack was in hand: stopped cleanly, the
	# downloads kept, no half-written zip.
	if _build != null:
		_build.stop()
		_build = null
	# Gone between the last pack and the catalogue's reading of the folder:
	# it is read now, so what was built is not left unseen.
	if _settle_in > 0:
		_settle_in = 0
		game.settle(_installed)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel", false, true):
		return
	accept_event()
	# The explanation is on top: Escape is its OK, and nothing more.
	var popup := UiChrome.open_popup(self)
	if popup != null:
		UiChrome.dismiss_popup(popup)
	elif mode == "working":
		stop()
	else:
		close()


func _process(_delta: float) -> void:
	if _sweeping:
		# A little each frame, beside a build as well as without one.
		if not game.sweep_step():
			_sweeping = false
			if mode != "working":
				set_process(false)
		if mode != "working":
			return
	if _settling:
		if _settle_in > 0:
			_settle_in -= 1
			if _settle_in == 0:
				game.settle(_installed)
		elif not game.settling():
			_finished()
		return
	if mode != "working" or _build == null:
		return
	if _build.step():
		_show_progress()
		return
	_outcomes.append(_build.outcome)
	if _build.id == PackRecipes.BASE and bool(_build.outcome.get("ok", false)):
		_art_built = true
	# What stopped this pack would stop the next the same way (no
	# connection, a full disk): the rest are not begun.
	var halted := bool(_build.outcome.get("halts", false))
	_build = null
	_at += 1
	if _stopped or halted or _at >= _queue.size():
		_finish()
	else:
		_begin_next()


# ------------------------------------------------------------ the rows --

## How every row stands, read again from the game and the cache.
func _refresh_rows() -> void:
	var locked := game.refusal()
	for id: String in _order:
		var row: Dictionary = _rows[id]
		var check: CheckBox = row["check"]
		var state: Label = row["state"]
		var status := game.status(id)
		var total := int(PackRecipes.about(id)["pictures"])
		var cached := mini(_cached(game.cache_root().path_join(id)), total)
		row["status"] = status
		row["cached"] = cached
		state.tooltip_text = ""
		var free := true
		match String(status.get("state", "absent")):
			"installed":
				state.text = "Installed"
				free = false
			"elsewhere":
				state.text = "In use from another place"
				state.tooltip_text = "The game already has it, but not from the card folder. Building puts a copy there."
			"refused":
				state.text = "Here, but refused"
				state.tooltip_text = String(status.get("note", ""))
			_:
				state.text = "Not here"
		if free and cached > 0:
			state.text = "Part downloaded: %d of %d" % [cached, total]
		var lacking := PackRecipes.lacking(id)
		if free and lacking != "":
			# An export that left the pack's list out cannot build it.
			state.text = NOT_IN_BUILD
			state.tooltip_text = NOT_IN_BUILD_WHY % lacking
			free = false
		check.disabled = not free or locked != "" or mode == "working"
		if check.disabled and mode != "working":
			check.set_pressed_no_signal(false)
		check.focus_mode = Control.FOCUS_NONE if check.disabled else Control.FOCUS_ALL
	_intro.text = _intro_text()
	if locked != "":
		_intro.text += "\n" + LOCKED_NOTE % locked
	_on_ticked()


func _intro_text() -> String:
	var fetch := 0
	var kept := 0
	for id: String in PackRecipes.ids():
		var about := PackRecipes.about(id)
		fetch += int(about["fetch_mb"])
		kept += int(about["zip_mb"])
	return INTRO % [GamePaths.shown(game.folder()), megabytes(fetch), megabytes(kept)]


## The pictures kept under [param folder] from an earlier, unfinished run.
static func _cached(folder: String) -> int:
	var count := 0
	var dir := DirAccess.open(folder)
	if dir == null:
		return 0
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if entry != "." and entry != "..":
				count += _cached(folder.path_join(entry))
		elif entry.get_extension() == "jpg":
			count += 1
		entry = dir.get_next()
	dir.list_dir_end()
	return count


## The ids ticked, in the rows' order.
func chosen() -> Array[String]:
	var out: Array[String] = []
	for id: String in _order:
		var check: CheckBox = _rows[id]["check"]
		if check.button_pressed and not check.disabled:
			out.append(id)
	return out


## What the ticked packs cost: `{pictures, fetch_mb, need_mb, seconds}` —
## megabytes still to download, megabytes that must be free while they are
## built (the zips, and the largest download beside them), rough seconds.
func cost(ids: Array[String]) -> Dictionary:
	var pictures := 0
	var fetch_mb := 0.0
	var zips := 0
	var largest := 0.0
	for id: String in ids:
		var about := PackRecipes.about(id)
		var left := int(about["pictures"]) - int(_rows[id]["cached"])
		var mb := float(about["fetch_mb"]) * float(left) / float(maxi(int(about["pictures"]), 1))
		pictures += left
		fetch_mb += mb
		zips += int(about["zip_mb"])
		largest = maxf(largest, mb)
	return {"pictures": pictures, "fetch_mb": int(ceil(fetch_mb)),
		"need_mb": zips + int(ceil(largest)) + PackBuild.SPARE_MB,
		"seconds": int(ceil(float(pictures) * _opening_pace()))}


## Seconds a picture is reckoned at before a run has a pace of its own.
func _opening_pace() -> float:
	return SECONDS_PER_PICTURE if _gentle.button_pressed else SECONDS_PER_PICTURE_UNPAUSED


func _on_gentle(on: bool) -> void:
	game.set_gentle(on)
	_on_ticked()


## The "?": first the thanks, then the request. An OK popup over this
## window; the ring goes back to the "?" when it closes.
func _explain() -> void:
	if UiChrome.open_popup(self) != null:
		return
	# The ring on the "?" first, so that is where the popup gives it back.
	_why.grab_focus()
	var popup := UiChrome.explain_popup(self, WHY_TITLE, WHY_BODY, 560.0)
	popup.name = "PackGentleExplained"
	for node: Node in popup.find_children("*", "Label", true, false) \
			+ popup.find_children("*", "Button", true, false):
		_plain(node as Control)


func _on_ticked() -> void:
	var ids := chosen()
	_ok.disabled = ids.is_empty() or mode == "working"
	_ok.focus_mode = Control.FOCUS_NONE if _ok.disabled else Control.FOCUS_ALL
	if ids.is_empty():
		_chosen.text = NOTHING_CHOSEN
		return
	var about := cost(ids)
	var free := game.free_bytes()
	_chosen.text = "Chosen: %d. %d MB to download, about %s. Needs %s free%s." % [
		ids.size(), int(about["fetch_mb"]), span(int(about["seconds"])), megabytes(int(about["need_mb"])),
		"" if free < 0 else " (%s are free)" % megabytes(free >> 20)]


## "850 MB", "1.6 GB".
static func megabytes(mb: int) -> String:
	if mb < 1000:
		return "%d MB" % mb
	return "%.1f GB" % (float(mb) / 1024.0)


## "less than a minute", "1 minute", "12 minutes", "1 hour 5 minutes".
static func span(seconds: int) -> String:
	if seconds < 50:
		return "less than a minute"
	var minutes := int(round(float(seconds) / 60.0))
	if minutes < 60:
		return "%d minute%s" % [minutes, "" if minutes == 1 else "s"]
	var hours := int(floor(float(minutes) / 60.0))
	return "%d hour%s %d minute%s" % [hours, "" if hours == 1 else "s",
		minutes % 60, "" if minutes % 60 == 1 else "s"]


# ------------------------------------------------------------ the work --

func _start() -> void:
	var ids := chosen()
	if ids.is_empty() or mode == "working":
		return
	_summary.visible = false
	var locked := game.refusal()
	if locked != "":
		_refresh_rows()
		return
	var free := game.free_bytes()
	var about := cost(ids)
	if free >= 0 and free < int(about["need_mb"]) * 1024 * 1024:
		_summary.text = "Not enough free disk space: the chosen packs need about %s and %s are free. Choose fewer, or make room." % [
			megabytes(int(about["need_mb"])), megabytes(free >> 20)]
		_summary.visible = true
		return
	_queue = ids
	_at = 0
	_outcomes.clear()
	_stopped = false
	mode = "working"
	_ok.visible = false
	_close.visible = false
	_stop.visible = true
	_stop.disabled = false
	_work.visible = true
	for id: String in _order:
		var check: CheckBox = _rows[id]["check"]
		check.disabled = true
		check.focus_mode = Control.FOCUS_NONE
	# The pace is the build's from its start: the tick waits for the next.
	_gentle.disabled = true
	_gentle.focus_mode = Control.FOCUS_NONE
	_fence()
	_stop.grab_focus()
	set_process(true)
	_begin_next()


func _begin_next() -> void:
	_build = PackBuild.new()
	_build.gentle = _gentle.button_pressed
	# Its card list is read on a thread: the bar and Stop stay alive.
	_build.aside = true
	_build.start(_queue[_at], game)
	_show_progress()


func _show_progress() -> void:
	if _build == null:
		return
	var words := _build.line()
	_line.text = _build.title if words == "" else "%s — %s" % [_build.title, words]
	_bar.value = _build.fraction()
	var left := _seconds_left()
	_overall.text = "Pack %d of %d%s" % [_at + 1, _queue.size(),
		"" if left < 0 else " · about %s left" % span(left)]


## Rough seconds until the whole job is done: this pack's pace for what it
## still has to fetch, and for the packs after it.
func _seconds_left() -> int:
	if _build == null or _build.fetch == null or _build.phase == "preparing":
		return -1
	var fetch := _build.fetch
	var pace := _opening_pace()
	if fetch.fetched >= 4:
		pace = float(game.now_msec() - fetch.started_msec) / 1000.0 / float(fetch.fetched)
	var pictures := fetch.pictures_total - fetch.pictures_done
	for i in range(_at + 1, _queue.size()):
		var id := _queue[i]
		pictures += int(PackRecipes.about(id)["pictures"]) - int(_rows[id]["cached"])
	return int(ceil(float(pictures) * pace))


## Stop: the pack in hand is stopped cleanly and the rest are not begun.
func stop() -> void:
	if mode != "working":
		return
	_stopped = true
	_stop.disabled = true
	if _build != null:
		_build.stop()


func _finish() -> void:
	var installed: Array = []
	for outcome: Dictionary in _outcomes:
		if bool(outcome.get("ok", false)):
			installed.append(String(outcome["id"]))
	# The catalogue reads the card folder again when a numbered pack came
	# in. The window says so first and asks two frames later — reading the
	# folder is one go of a few tenths of a second — and the card pool is
	# then rebuilt on a thread, the window waiting for it ([method
	# _process]). With nothing new there is nothing to wait for.
	var new_packs := false
	for id: String in installed:
		new_packs = new_packs or id != PackRecipes.BASE
	if not new_packs:
		game.settle(installed)
		_finished()
		return
	_settling = true
	_settle_in = 2
	_installed = installed
	_line.text = READING
	_bar.value = 1.0
	_overall.text = ""
	_stop.disabled = true


## The job is over and the card pool has the new packs: back to choosing,
## with the summary.
func _finished() -> void:
	_settling = false
	set_process(_sweeping)
	mode = "choose"
	_work.visible = false
	_stop.visible = false
	_ok.visible = true
	_close.visible = true
	_gentle.disabled = false
	_gentle.focus_mode = Control.FOCUS_ALL
	for id: String in _order:
		(_rows[id]["check"] as CheckBox).set_pressed_no_signal(false)
	_refresh_rows()
	_summary.text = summary()
	_summary.visible = true
	_fit_summary()
	_fence()
	_close.grab_focus()
	# A pack whose tidying Stop cut short is installed now: its cache goes.
	_sweep_caches()


## What came of the last job, in words: what is in, what is not and why,
## and whether a restart is needed.
func summary() -> String:
	var lines := PackedStringArray()
	var packs := PackedStringArray()
	var art := false
	for outcome: Dictionary in _outcomes:
		if not bool(outcome.get("ok", false)):
			continue
		if String(outcome["id"]) == PackRecipes.BASE:
			art = true
		else:
			packs.append(String(outcome["title"]))
	if not packs.is_empty():
		lines.append("Installed: %s. %s No restart is needed." % [", ".join(packs),
			TURN_ON % ("it" if packs.size() == 1 else "them")])
	if art:
		lines.append("Installed: %s. %s" % [PackRecipes.BASE_TITLE,
			ART_RESTART if game.art_needs_restart() else ART_NOW])
	var failed := 0
	var more := PackedStringArray()
	for outcome: Dictionary in _outcomes:
		if bool(outcome.get("ok", false)):
			continue
		failed += 1
		if failed <= FAILURES_IN_FULL:
			lines.append("Not finished: %s. %s" % [String(outcome["title"]), String(outcome["text"])])
		else:
			more.append(String(outcome["title"]))
	if not more.is_empty():
		lines.append("Not finished either: %s." % ", ".join(more))
	var waiting := PackedStringArray()
	for i in range(_outcomes.size(), _queue.size()):
		waiting.append(String(PackRecipes.about(_queue[i])["title"]))
	if not waiting.is_empty():
		lines.append("Not started: %s." % ", ".join(waiting))
	return "\n".join(lines)


## The summary's box as tall as the summary, up to [constant SUMMARY_MOST].
func _fit_summary() -> void:
	var had_ring := _summary_box.has_focus()
	_summary_box.visible = _summary.visible
	var tall := _summary.get_combined_minimum_size().y
	_summary_box.custom_minimum_size.y = minf(tall, SUMMARY_MOST)
	# The ring only when there is more than the box shows.
	var wanted := Control.FOCUS_ALL if _summary.visible and tall > SUMMARY_MOST else Control.FOCUS_NONE
	if _summary_box.focus_mode != wanted:
		_summary_box.focus_mode = wanted
		if is_node_ready():
			_fence()
	# The ring is never left on a box that went or scrolls no more.
	if had_ring and wanted == Control.FOCUS_NONE and is_node_ready():
		(_close if _close.visible else _stop).grab_focus()


## Whether the summary's box takes the ring: it has more than it shows.
func summary_scrolls() -> bool:
	return _summary_box.visible and _summary_box.focus_mode == Control.FOCUS_ALL


func _draw_summary_ring() -> void:
	if _summary_box.has_focus():
		_summary_box.draw_style_box(OriginalDialog.focus_ring(), Rect2(Vector2.ZERO, _summary_box.size))


## The keys on the summary's box while it has the ring.
func _on_summary_input(event: InputEvent) -> void:
	if not summary_scrolls():
		return
	var bar := _summary_box.get_v_scroll_bar()
	var most := int(maxf(bar.max_value - bar.page, 0.0))
	var at := _summary_box.scroll_vertical
	var to := at
	var page := int(maxf(_summary_box.size.y - SUMMARY_STEP, SUMMARY_STEP))
	if event.is_action_pressed("ui_down", true):
		to = at + SUMMARY_STEP
	elif event.is_action_pressed("ui_up", true):
		to = at - SUMMARY_STEP
	elif event.is_action_pressed("ui_page_down", true):
		to = at + page
	elif event.is_action_pressed("ui_page_up", true):
		to = at - page
	elif event.is_action_pressed("ui_home", true):
		to = 0
	elif event.is_action_pressed("ui_end", true):
		to = most
	else:
		return
	to = clampi(to, 0, most)
	if to == at:
		# At the end already: Up and Down move the ring on.
		return
	_summary_box.scroll_vertical = to
	accept_event()


## The caches of packs that are installed, removed a little each frame
## ([method PackBuildHost.stale_caches]).
func _sweep_caches() -> void:
	if _sweeping:
		return
	var stale := game.stale_caches()
	if stale.is_empty():
		return
	game.sweep(stale)
	_sweeping = true
	set_process(true)


## Close the window. While a pack is being built this is Stop first.
func close() -> void:
	if mode == "working":
		stop()
		return
	var wear := _art_built
	var on := game
	var back := _focus_before.get_ref() as Control if _focus_before != null else null
	queue_free()
	if back != null and back.is_inside_tree() and back.is_visible_in_tree() \
			and back.focus_mode != Control.FOCUS_NONE:
		back.grab_focus()
	if wear:
		on.wear_art()


# ------------------------------------------------------------ the look --

## The ring walks the rows that can be ticked, the tick under them with
## its "?" to the right, and the buttons — and stays on the window.
func _fence() -> void:
	var column: Array[Control] = []
	for id: String in _order:
		var check: CheckBox = _rows[id]["check"]
		if not check.disabled:
			column.append(check)
	# Under the rows: the tick, or its "?" alone while the tick is held.
	column.append(_why if _gentle.disabled else _gentle)
	# And the summary under that, when it scrolls.
	if summary_scrolls():
		column.append(_summary_box)
	var buttons: Array[Control] = []
	for button: Button in [_ok, _stop, _close]:
		if button.visible and not button.disabled:
			buttons.append(button)
	if buttons.is_empty():
		return
	for i in column.size():
		var here := column[i]
		var up: Control = column[i - 1] if i > 0 else here
		var down: Control = column[i + 1] if i + 1 < column.size() else buttons[0]
		here.focus_neighbor_top = here.get_path_to(up)
		here.focus_neighbor_bottom = here.get_path_to(down)
		here.focus_neighbor_left = here.get_path_to(here)
		here.focus_neighbor_right = here.get_path_to(here)
		here.focus_previous = here.get_path_to(up if up != here else buttons[-1])
		here.focus_next = here.get_path_to(down)
	var under_tick: Control = _summary_box if summary_scrolls() else buttons[0]
	if not _gentle.disabled:
		# The "?" beside the tick: right of it, and the same way up and down.
		_gentle.focus_neighbor_right = _gentle.get_path_to(_why)
		_gentle.focus_next = _gentle.get_path_to(_why)
		_why.focus_neighbor_left = _why.get_path_to(_gentle)
		_why.focus_neighbor_right = _why.get_path_to(_why)
		_why.focus_neighbor_top = _why.get_path_to(_gentle.get_node(_gentle.focus_neighbor_top))
		_why.focus_neighbor_bottom = _why.get_path_to(under_tick)
		_why.focus_previous = _why.get_path_to(_gentle)
		_why.focus_next = _why.get_path_to(under_tick)
		if _gentle.get_node(_gentle.focus_neighbor_top) == _gentle:
			_why.focus_neighbor_top = _why.get_path_to(_why)
	for i in buttons.size():
		var here := buttons[i]
		var left := buttons[(i - 1 + buttons.size()) % buttons.size()]
		var right := buttons[(i + 1) % buttons.size()]
		var above: Control = column[-1]
		here.focus_neighbor_left = here.get_path_to(left)
		here.focus_neighbor_right = here.get_path_to(right)
		here.focus_neighbor_top = here.get_path_to(above)
		here.focus_neighbor_bottom = here.get_path_to(here)
		here.focus_previous = here.get_path_to(left if i > 0 else (_why if not _gentle.disabled else above))
		here.focus_next = here.get_path_to(right if i + 1 < buttons.size() else column[0])


func _first_focus() -> Control:
	for id: String in _order:
		var check: CheckBox = _rows[id]["check"]
		if not check.disabled:
			return check
	return _close


## A label in the body face, dark ink, nothing behind the letters.
static func _label(text: String, size: int) -> Label:
	var label := UiChrome.body_label(text, size)
	_plain(label)
	return label


static func _button(text: String) -> Button:
	var button := UiChrome.menu_button(text, Vector2(140, 38))
	button.name = text
	_plain(button)
	return button


## No seat, shadow or outline behind the letters.
static func _plain(control: Control) -> void:
	control.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	control.add_theme_constant_override("shadow_offset_x", 0)
	control.add_theme_constant_override("shadow_offset_y", 0)
	control.add_theme_constant_override("shadow_outline_size", 0)
	control.add_theme_constant_override("outline_size", 0)


func _dress_check(check: CheckBox) -> void:
	var font := GameSkin.font("font_body")
	if font != null:
		check.add_theme_font_override("font", font)
	check.add_theme_font_size_override("font_size", 15)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color", "font_hover_pressed_color"]:
		check.add_theme_color_override(state, UiChrome.INK)
	check.add_theme_color_override("font_disabled_color", DIM)
	for icon: String in ["checked", "checked_disabled"]:
		check.add_theme_icon_override(icon, UiChrome.check_icon(true))
	for icon: String in ["unchecked", "unchecked_disabled"]:
		check.add_theme_icon_override(icon, UiChrome.check_icon(false))
	var none := StyleBoxEmpty.new()
	none.content_margin_left = 4.0
	none.content_margin_right = 4.0
	for box: String in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		check.add_theme_stylebox_override(box, none)
	check.add_theme_stylebox_override("focus", OriginalDialog.focus_ring())
	_plain(check)
