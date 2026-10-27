class_name PastGamesScreen
extends Control
## [QoL] Read-only MPN history. Neither this view nor its graphical player
## runs recorded commands. The table is assembled solely from recorded values.

var document := {}
var cursor := 0
var current_path := ""
var archive_directory := "" # test seam; empty uses GamePaths
var overlay := false
var _paths: Array[String] = []
var _games: ItemList
var _events: ItemList
var _title: Label
var _notice: Label
var _position: Label
var _details: Label
var _table: VBoxContainer
var _slider: HSlider
var _play: Button
var _timer: Timer
var _export: Button
var _watch: Button
var _moves: Button
var _move_list: Control
var _player: MpnPlayer
var _library: VBoxContainer
var _detail_scroll: ScrollContainer
var _changing := false
var _state := {}
## Record index -> the folded public state there, taken while the event
## list is labelled (hunt 2026-10-21): a seek folds from the nearest one.
var _checkpoints := {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ground := ColorRect.new()
	ground.color = Color("191b20")
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ground)
	var art := GameSkin.texture("title_background")
	if art != null:
		var texture := TextureRect.new()
		texture.texture = art
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		texture.modulate = Color(0.3, 0.3, 0.3)
		texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(texture)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 16)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)
	var bar := HBoxContainer.new()
	layout.add_child(bar)
	var heading := _light("Past Games", 30)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(heading)
	bar.add_child(_button("Refresh", refresh))
	bar.add_child(_button("Info", _show_info))
	bar.add_child(_button("Open MPN…", _open_picker))
	_export = _button("Export…", _export_picker)
	_export.disabled = true
	bar.add_child(_export)
	_watch = _button("Watch duel", watch_duel)
	_watch.disabled = true
	bar.add_child(_watch)
	_moves = _button("Move list", show_move_list)
	_moves.disabled = true
	bar.add_child(_moves)
	bar.add_child(_button("Back", func() -> void:
		if overlay: queue_free()
		else: get_tree().change_scene_to_file("res://game/main.tscn")))
	layout.add_child(_light("Public history · Hidden cards stay hidden · MPN prototype", 16))
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(split)
	var library := VBoxContainer.new()
	_library = library
	library.custom_minimum_size.x = 230
	split.add_child(library)
	library.add_child(_light("Your recordings", 19))
	_games = ItemList.new()
	_games.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_games.custom_minimum_size.x = 230
	_games.item_selected.connect(_choose_game)
	library.add_child(_games)
	var folder := _light("Local duels are kept here. Both LAN players can export the same public MPN from the result screen.\nOpen a saved file to view it.", 15)
	folder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	library.add_child(folder)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	_title = _light("Choose a recording", 23)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_title)
	_notice = _light("No recorded game selected. Older diagnostic logs cannot be reconstructed as MPN.", 15)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_notice)
	var controls := HBoxContainer.new()
	right.add_child(controls)
	controls.add_child(_button("|<", func() -> void: seek(0)))
	controls.add_child(_button("<", func() -> void: seek(cursor - 1)))
	_play = _button("Play", _toggle_play)
	controls.add_child(_play)
	controls.add_child(_button(">", func() -> void: seek(cursor + 1)))
	controls.add_child(_button(">|", func() -> void: seek(_record_count() - 1)))
	_position = _light("0 / 0", 16)
	_position.clip_text = true
	_position.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_position.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	controls.add_child(_position)
	_slider = HSlider.new()
	_slider.step = 1
	_slider.value_changed.connect(func(value: float) -> void:
		if not _changing: seek(int(value)))
	right.add_child(_slider)
	_table = VBoxContainer.new()
	_table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_table.add_theme_constant_override("separation", 10)
	right.add_child(_table)
	_details = _light("Select a public card to read its recorded details.", 15)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.custom_minimum_size.y = 44
	var detail_scroll := ScrollContainer.new()
	_detail_scroll = detail_scroll
	detail_scroll.custom_minimum_size.y = 64
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(_details)
	right.add_child(detail_scroll)
	_events = ItemList.new()
	_events.custom_minimum_size.y = 130
	_events.item_selected.connect(seek)
	right.add_child(_events)
	_timer = Timer.new()
	_timer.wait_time = 0.7
	_timer.timeout.connect(func() -> void:
		if cursor + 1 >= _record_count(): _stop()
		else: seek(cursor + 1))
	add_child(_timer)
	refresh()
	resized.connect(_fit)
	_fit.call_deferred()

func _fit() -> void:
	_library.visible = size.x >= 1000
	var compact := size.y < 700
	_notice.visible = not compact
	_events.custom_minimum_size.y = 70 if compact else 130
	_detail_scroll.custom_minimum_size.y = 30 if compact else 64

static func _light(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f0e7d6"))
	var font := GameSkin.font("font_body")
	if font != null: label.add_theme_font_override("font", font)
	return label

func _button(text: String, action: Callable) -> Button:
	var button := UiChrome.menu_button(text, Vector2(50, 36), 17)
	button.pressed.connect(action)
	return button

func refresh() -> void:
	_paths = MpnArchive.files(archive_directory)
	_games.clear()
	for path in _paths:
		# Listing does not parse entire matches or expose local paths in a
		# shared screenshot. Players' names appear after a record is opened.
		var filename := path.get_file()
		var label := filename
		if filename.length() >= 16 and filename[8] == "T" and filename[15] == "Z":
			label = "%s-%s-%s %s:%s:%s" % [filename.substr(0, 4), filename.substr(4, 2), filename.substr(6, 2), filename.substr(9, 2), filename.substr(11, 2), filename.substr(13, 2)]
		_games.add_item(label)
	if _paths.is_empty(): _games.add_item("No games recorded yet")
	if _paths.is_empty(): _games.set_item_disabled(0, true)

func _choose_game(index: int) -> void:
	if index >= 0 and index < _paths.size(): open_record(_paths[index])

func open_record(path: String) -> bool:
	_stop()
	var parsed := MpnArchive.read(path)
	if String(parsed.get("error", "")) != "":
		_notice.text = String(parsed.error)
		return false
	document = parsed
	current_path = path
	_export.disabled = false
	_watch.disabled = false
	_moves.disabled = false
	var headers: Dictionary = document.headers
	_title.text = "%s  vs  %s" % [String(headers["Player.P1"]).left(80), String(headers["Player.P2"]).left(80)]
	_notice.text = "%s · %s\nPublic observations, not a complete rules replay. %s" % [headers.Started,
		_text_or(headers.get("RulesProfile"), "Rules not specified"),
		"Finished." if document.finished else "Incomplete / stopped: no final result recorded."]
	_events.clear()
	_checkpoints.clear()
	# About 64 checkpoints whatever the length, never closer than 256
	# records: a seek folds at most one interval. apply_patch returns a new
	# state each time, so a kept one is never changed afterwards.
	var every := maxi(256, document.records.size() / 64)
	var label_state := {}
	for i in document.records.size():
		if document.records[i].kind == "state": label_state = MpnCodec.apply_patch(label_state, document.records[i].data)
		if i % every == 0: _checkpoints[i] = label_state
		_events.add_item("%d  %s" % [i + 1, event_label(document.records[i], label_state, headers, document.finished)])
	_changing = true
	_slider.max_value = maxi(0, _record_count() - 1)
	_changing = false
	_state.clear()
	cursor = -1
	seek(0)
	_play.grab_focus()
	return true

static func event_label(record: Dictionary, state := {}, headers := {}, finished := false) -> String:
	var data: Dictionary = record.data
	if record.kind == "state":
		if data.has("step"): return "Turn %s · %s" % [_number_text(state.get("turn", data.get("turn", 0))), String(data.step).replace("_", " ").capitalize()]
		return "Public table updated"
	var seat: Variant = data.get("player", "")
	var player := str(headers.get("Player." + seat, seat)) if seat in ["P1", "P2"] else "Unknown player"
	var subject := _object_label(str(data.get("object", "")), state, headers)
	match record.kind:
		"draw": return "%s draws %s card(s)" % [player, _number_text(data.get("count", 1))]
		"land": return "%s plays %s" % [player, subject]
		"cast": return "%s casts %s" % [player, subject]
		"activate": return "%s activates %s" % [player, subject]
		"discard": return "%s discards %s" % [player, subject]
		"enter": return "%s enters the battlefield" % subject
		"leave": return "%s leaves the battlefield" % subject
		"die": return "%s dies" % subject
		"tap": return "%s taps" % subject
		"untap": return "%s untaps" % subject
		"mana": return "%s produces mana" % subject
		"mana_burn": return "%s loses %s life to mana burn" % [player, _number_text(data.get("amount"))]
		"attack":
			var attackers: Array[String] = []
			if data.get("objects") is Array:
				for id in data.objects: attackers.append(_object_label(str(id), state, headers))
			return "%s attacks: %s" % [player, ", ".join(attackers)]
		"regenerate": return "%s regenerates" % subject
		"damage": return "%s → %s: %s damage" % [_object_label(str(data.get("source", "")), state, headers), _object_label(str(data.get("target", "")), state, headers), _number_text(data.get("amount"))]
		"block": return "%s blocks %s" % [_object_label(str(data.get("blocker", "")), state, headers), _object_label(str(data.get("attacker", "")), state, headers)]
		"reveal": return "Public reveal: " + JSON.stringify(data.get("cards", []))
		"result": return "Game result: " + str(data.get("result", ""))
		"close": return "Recording closed — final result recorded" if finished else "Recording stopped — no final result"
		"comment": return str(data.get("text", ""))
	return MpnCodec.summary(record)

static func _number_text(value: Variant) -> String:
	return str(int(value)) if value is int or value is float else "?"

static func _text_or(value: Variant, fallback: String) -> String:
	return value if value is String else fallback

static func _object_label(id: String, state: Dictionary, headers: Dictionary) -> String:
	if id in ["P1", "P2"]: return str(headers.get("Player." + id, id))
	if id == "": return "Unidentified public source"
	return "%s [%s]" % [state.get("objects", {}).get(id, {}).get("name", "Object"), id]

func _show_info() -> void:
	if document.is_empty(): return
	var lines: Array[String] = []
	for key in document.headers:
		lines.append("%s: %s" % [key, JSON.stringify(document.headers[key])])
	UiChrome.explain_popup(self, "Game information", "\n".join(lines))

func seek(index: int) -> void:
	if document.is_empty(): return
	index = clampi(index, 0, _record_count() - 1)
	# Adjacent playback is incremental; an arbitrary seek folds from the
	# nearest checkpoint at or before it. It folded from the initial
	# observation, and a 20,000-record history took 1-2 s for each step of
	# a drag of the seek bar (hunt 2026-10-21). No simulated actions or
	# card catalogue needed.
	if index != cursor + 1:
		_state = _fold_to(index)
	elif document.records[index].kind == "state":
		_state = MpnCodec.apply_patch(_state, document.records[index].data)
	cursor = index
	_changing = true
	_slider.value = cursor
	_changing = false
	_events.select(cursor)
	_events.ensure_current_is_visible()
	_position.text = "%d / %d · Turn %d · %s" % [cursor + 1, _record_count(), int(_state.get("turn", 0)), String(_state.get("step", "pregame")).replace("_", " ")]
	_draw_table()
	_details.text = event_label(document.records[cursor], _state, document.headers, document.finished).left(600)

func _fold_to(index: int) -> Dictionary:
	var start := -1
	for at: int in _checkpoints:
		if at <= index and at > start: start = at
	var state: Dictionary = {} if start < 0 else _checkpoints[start].duplicate(true)
	for i in range(start + 1, index + 1):
		if document.records[i].kind == "state": state = MpnCodec.apply_patch(state, document.records[i].data)
	return state


func _draw_table() -> void:
	for child in _table.get_children():
		_table.remove_child(child)
		child.queue_free()
	if not _state.has("players"): return
	var stack: Array = _state.get("stack", [])
	if not stack.is_empty():
		var names: Array[String] = []
		for item in stack: names.append(String(item.name) + " " + JSON.stringify(item.targets))
		var chain := _light("Spell Chain (bottom → top)\n" + "\n".join(names), 16)
		chain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_table.add_child(chain)
	for pid in [1, 0]:
		var group := VBoxContainer.new()
		var panel := UiChrome.panel_around(group, 10)
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_table.add_child(panel)
		var player: Dictionary = _state.players[pid]
		var name_value: String = document.headers["Player.P%d" % (pid + 1)]
		var title := UiChrome.body_label("%s  ·  %d life%s" % [name_value.left(80), int(player.life), "  ·  Active" if int(_state.get("active", -1)) == pid else ""], 21)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		group.add_child(title)
		var mana: Array[String] = []
		for color in ["W", "U", "B", "R", "G", "C"]:
			var count := int(player.mana.get(color, 0))
			if count > 0: mana.append("%s %d" % [color, count])
		var info := UiChrome.body_label("Hand: %d cards (hidden unless revealed)   ·   Library: %d   ·   Poison: %d   ·   Mana: %s" % [int(player.hand), int(player.library), int(player.get("poison", 0)), "empty" if mana.is_empty() else " · ".join(mana)], 15)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		group.add_child(info)
		var cards_scroll := ScrollContainer.new()
		cards_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		group.add_child(cards_scroll)
		var flow := HFlowContainer.new()
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		cards_scroll.add_child(flow)
		for id in _state.objects:
			var card: Dictionary = _state.objects[id]
			if int(card.controller if card.zone in ["battlefield", "phased_out", "stack"] else card.owner) != pid: continue
			var tile := Button.new()
			var compact := size.y < 700
			tile.custom_minimum_size = Vector2(140 if compact else 150, 60 if compact else 82)
			tile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var stats := "  %d/%d" % [int(card.power), int(card.toughness)] if card.creature else ""
			var fighting := ""
			if _state.get("combat", {}).get("attackers", []).has(id): fighting = " · attacking"
			for pair in _state.get("combat", {}).get("blocks", []):
				if pair[0] == id: fighting += " · blocking " + str(pair[1])
			tile.text = "%s%s\n%s · %s%s%s" % [card.name, stats, card.id, card.zone,
				" · tapped" if card.tapped else "", " · %d damage" % int(card.damage) if card.damage else ""]
			tile.text += fighting
			tile.tooltip_text = tile.text
			if compact:
				tile.text = "%s%s\n%s%s%s" % [card.name, stats, card.id,
					" · tapped" if card.tapped else "", " · %d dmg" % int(card.damage) if card.damage else ""]
				tile.text += " · attacking" if fighting.contains("attacking") else " · blocking" if fighting.contains("blocking") else ""
			tile.add_theme_font_size_override("font_size", 13 if compact else 15)
			var style := StyleBoxFlat.new()
			style.bg_color = Color("323b46") if pid == 0 else Color("493829")
			style.set_border_width_all(2)
			style.border_color = Color("c8b78e")
			style.set_corner_radius_all(5)
			style.content_margin_left = 8
			style.content_margin_right = 8
			tile.add_theme_stylebox_override("normal", style)
			tile.pressed.connect(_show_card.bind(card.duplicate(true)))
			flow.add_child(tile)
		if flow.get_child_count() == 0: group.add_child(UiChrome.body_label("No public cards in this observation.", 16))

func _show_card(card: Dictionary) -> void:
	_details.text = "%s [%s] · %s%s · %d damage · %s\n%s" % [card.name, card.id, card.zone,
		" · tapped" if card.tapped else "", int(card.damage), _text_or(card.get("printing"), ""),
		_text_or(card.get("rules_text"), "Identity is not public." if card.face_down else "Rules text not recorded.")]
	if not card.counters.is_empty(): _details.text += "\nCounters: " + JSON.stringify(card.counters)

func _record_count() -> int:
	return document.get("records", []).size()

func _toggle_play() -> void:
	if document.is_empty(): return
	if not _timer.is_stopped():
		_stop()
		return
	if cursor == _record_count() - 1: seek(0)
	_play.text = "Pause"
	_timer.start()

func _stop() -> void:
	if _timer != null: _timer.stop()
	if _play != null: _play.text = "Play"

func _open_picker() -> void:
	_stop()
	MpnFiles.choose(self, open_record)

func _export_picker() -> void:
	if document.is_empty(): return
	_stop()
	MpnFiles.export_bytes(self, FileAccess.get_file_as_bytes(current_path), current_path.get_file())

func watch_duel() -> void:
	if document.is_empty() or is_instance_valid(_player): return
	_stop()
	_player = MpnPlayer.new()
	get_parent().add_child(_player)
	_player.open_document(document, current_path, cursor)
	_player.closed.connect(func(index: int) -> void:
		show()
		seek(index)
		_player = null)
	hide()

## THE MOVE LIST (the owner, 2026-10-24: "try to make it human readable and
## lapidary!"): the open record read as a person reads a game ([MpnMoveList])
## — each turn under its player, one action a line under its phase — over
## this screen, in a table so the phases line up in any font. Copy puts its
## text on the clipboard; Save text… writes it (the record stays MPN 0.1).
func show_move_list() -> Control:
	if document.is_empty():
		return null
	_stop()
	close_move_list()
	# Read once, kept: Copy and Save text give the game shown, whatever the
	# screen under the list does meanwhile.
	var said := MpnMoveList.text(document)
	var read := MpnMoveList.read_game(document)
	var veil := ColorRect.new()
	veil.name = "MoveList"
	veil.color = Color(0, 0, 0, 0.65)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	_move_list = veil
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1e2128")
	style.border_color = Color("5a5f6b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in [SIDE_LEFT, SIDE_TOP]:
		panel.set_offset(side, 40)
	for side in [SIDE_RIGHT, SIDE_BOTTOM]:
		panel.set_offset(side, -40)
	veil.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(_light("Move list", 26))
	var body := RichTextLabel.new()
	body.name = "MoveListText"
	body.bbcode_enabled = true
	body.selection_enabled = true
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("normal_font_size", 17)
	body.add_theme_font_size_override("bold_font_size", 17)
	body.text = move_list_bbcode(read)
	column.add_child(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	var name_text := current_path.get_file().get_basename() + ".txt" if current_path != "" else "game.txt"
	var copy := _button("Copy", func() -> void: DisplayServer.clipboard_set(said))
	var save := _button("Save text…", func() -> void: MpnFiles.export_text(self, said, name_text))
	var close := _button("Close", close_move_list)
	var buttons: Array[Control] = [copy, save, close]
	for button in buttons:
		row.add_child(button)
	# THE FOCUS STAYS ON THE LIST: its three buttons in a ring, the text
	# above them — never a control under the veil, whose keys would change
	# the record behind it.
	body.focus_mode = Control.FOCUS_ALL
	for i in buttons.size():
		var here := buttons[i]
		var left := buttons[(i + buttons.size() - 1) % buttons.size()]
		var right := buttons[(i + 1) % buttons.size()]
		here.focus_neighbor_left = here.get_path_to(left)
		here.focus_neighbor_right = here.get_path_to(right)
		here.focus_previous = here.get_path_to(left)
		here.focus_next = here.get_path_to(right)
		here.focus_neighbor_top = here.get_path_to(body)
		here.focus_neighbor_bottom = here.get_path_to(here)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT]:
		body.set_focus_neighbor(side, body.get_path_to(body))
	body.focus_neighbor_bottom = body.get_path_to(close)
	body.focus_next = body.get_path_to(copy)
	body.focus_previous = body.get_path_to(close)
	close.grab_focus()
	return veil


func close_move_list() -> void:
	if is_instance_valid(_move_list):
		_move_list.queue_free()
		if is_instance_valid(_moves) and _moves.is_visible_in_tree():
			_moves.grab_focus()
	_move_list = null


func _unhandled_input(event: InputEvent) -> void:
	# The list closes on the back button of a pad, a headset or a handheld
	# too (ui_cancel), before the screen under it reads it.
	if is_instance_valid(_move_list) and not event is InputEventKey and event.is_action_pressed("ui_cancel"):
		close_move_list()
		get_viewport().set_input_as_handled()


## [param read] ([method MpnMoveList.read_game]) as the view's text: the tags,
## the symbols, then one table — the turn or the phase on the left, its
## player or the action on the right — then the result.
static func move_list_bbcode(read: Dictionary) -> String:
	var out := PackedStringArray()
	for tag_line in read.get("tags", []):
		out.append("[color=#9aa0aa]%s[/color]  %s\n" % [_bb(tag_line[0]), _bb(tag_line[1])])
	out.append("\n[b]Symbols[/b]\n[table=2]")
	for entry in MpnMoveList.LEGEND:
		out.append("[cell padding=0,0,24,0][color=#c8b273]%s[/color][/cell][cell][color=#9aa0aa]%s[/color][/cell]"
			% [_bb(entry[0]), _bb(entry[1])])
	out.append("[/table]\n[color=#9aa0aa]%s[/color]\n\n[table=2]" % _bb(MpnMoveList.NOT_TOLD))
	for turn in read.get("turns", []):
		out.append("[cell padding=0,8,24,0][b]%s[/b][/cell][cell padding=0,8,0,0][b]%s[/b][/cell]"
			% [_bb(turn["label"]), _bb(turn["player"])])
		var lines: Array = turn["lines"]
		if lines.is_empty():
			out.append("[cell][/cell][cell]—[/cell]")
		for line in lines:
			out.append("[cell padding=0,0,24,0][color=#9aa0aa]%s[/color][/cell][cell]%s[/cell]"
				% [_bb(line[0]), _bb(line[1])])
	out.append("[/table]\n\n[b]%s[/b]" % _bb(read.get("result", "")))
	return "".join(out)


## [param text] with its brackets kept out of the markup.
static func _bb(text: Variant) -> String:
	return String(text).replace("[", "[lb]")


func _exit_tree() -> void:
	if is_instance_valid(_player): _player.queue_free()

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if is_instance_valid(_move_list):
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			close_move_list()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT: seek(cursor - 1)
			KEY_RIGHT: seek(cursor + 1)
			KEY_HOME: seek(0)
			KEY_END: seek(_record_count() - 1)
			KEY_SPACE: _toggle_play()
			_: return
		get_viewport().set_input_as_handled()
