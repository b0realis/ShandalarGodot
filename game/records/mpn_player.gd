class_name MpnPlayer
extends Control
## [QoL] Recorded observations in the duel's own graphics. This clock moves
## through records, never through a Magic engine. No game actions are replayed.

signal closed(index: int)
var document := {}
var cursor := -1
var current_path := ""
var _state := {}
var _turns: Array[int] = []
var _checkpoints := {}
var _table: MpnDuelTable
var _stage: Control
var _play: Button
var _slider: HSlider
var _caption: Label
var _position: Label
var _timer: Timer
var _changing := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 0)
	add_child(layout)
	var stage := Control.new()
	_stage = stage
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.clip_contents = true
	layout.add_child(stage)
	_table = MpnDuelTable.new()
	stage.add_child(_table)
	_table.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	stage.resized.connect(_fit_table)
	_fit_table.call_deferred()
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	var footer := UiChrome.panel_around(body, 8)
	layout.add_child(footer)
	_caption = UiChrome.body_label("Choose an MPN recording.", 17)
	_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_caption)
	_slider = HSlider.new()
	_slider.step = 1
	_slider.value_changed.connect(func(value: float) -> void:
		if not _changing:
			stop()
			seek(int(value)))
	body.add_child(_slider)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	body.add_child(controls)
	controls.add_child(_button("|<", func() -> void: step_to(0), "First observation"))
	controls.add_child(_button("< Turn", func() -> void: jump_turn(-1), "Previous recorded turn"))
	controls.add_child(_button("<", func() -> void: step_to(cursor - 1), "Previous observation · Left"))
	_play = _button("Play", toggle_play, "Play / pause · Space")
	controls.add_child(_play)
	controls.add_child(_button(">", func() -> void: step_to(cursor + 1), "Next observation · Right"))
	controls.add_child(_button("Turn >", func() -> void: jump_turn(1), "Next recorded turn"))
	controls.add_child(_button(">|", func() -> void: step_to(_count() - 1), "Last observation"))
	var speed := OptionButton.new()
	for value in ["0.5×", "1×", "2×", "4×"]: speed.add_item(value)
	speed.select(1)
	speed.tooltip_text = "Playback pace, not the original game's timing"
	speed.item_selected.connect(func(index: int) -> void:
		_timer.wait_time = 0.7 / [0.5, 1.0, 2.0, 4.0][index])
	controls.add_child(speed)
	_position = UiChrome.body_label("", 14)
	_position.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_position.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	controls.add_child(_position)
	controls.add_child(_button("Info", _info, "Recording information and playback limits"))
	controls.add_child(_button("Export", _export_record, "Save a copy of this MPN"))
	controls.add_child(_button("History", close_player, "Return to the history viewer · Esc"))
	_timer = Timer.new()
	_timer.wait_time = 0.7
	_timer.timeout.connect(_tick)
	add_child(_timer)

func _fit_table() -> void:
	if _stage.size.x <= 0 or _stage.size.y <= 0: return
	# The original duel furniture has a fixed card/panel minimum height.
	# Fit the whole table above the toolbar, never clip the lower life panel
	# or battlefield. No live-duel dimensions or user settings are changed.
	var factor := minf(1.0, minf(_stage.size.x / 1280.0, _stage.size.y / 800.0))
	_table.scale = Vector2.ONE * factor
	_table.size = _stage.size / factor

func _button(label: String, action: Callable, hint: String) -> Button:
	var button := OriginalDialog.button(label, Vector2(46, 30))
	button.tooltip_text = hint
	button.pressed.connect(action)
	return button

func open_record(path: String, index := 0) -> bool:
	var parsed := MpnArchive.read(path)
	if parsed.error != "":
		stop()
		_caption.text = parsed.error
		return false
	open_document(parsed, path, index)
	return true

func open_document(parsed: Dictionary, path := "", index := 0) -> void:
	stop()
	document = parsed
	current_path = path
	cursor = -1
	_state.clear()
	_checkpoints.clear()
	_turns.assign([0])
	var turn := -1
	for i in _count():
		var record: Dictionary = document.records[i]
		if record.kind == "state" and record.data.has("turn"):
			if i > 0 and int(record.data.turn) != turn: _turns.append(i)
			turn = int(record.data.turn)
	_changing = true
	_slider.max_value = maxi(0, _count() - 1)
	_changing = false
	seek(index)

func seek(index: int) -> void:
	if document.is_empty(): return
	index = clampi(index, 0, _count() - 1)
	var start := cursor + 1
	if index != cursor + 1:
		_state = {}
		start = 0
		for checkpoint in _checkpoints:
			if int(checkpoint) <= index and int(checkpoint) + 1 > start:
				_state = _checkpoints[checkpoint].duplicate(true)
				start = int(checkpoint) + 1
	for i in range(start, index + 1):
		var record: Dictionary = document.records[i]
		if record.kind == "state": _state = MpnCodec.apply_patch(_state, record.data)
		if i % 256 == 0 and MpnProjection.refusal(_state) == "":
			if _checkpoints.size() >= 8 and not _checkpoints.has(i): _checkpoints.erase(_checkpoints.keys()[0])
			_checkpoints[i] = _state.duplicate(true)
	cursor = index
	_table.dismiss_inspection()
	var refusal := MpnProjection.refusal(_state)
	_table.visible = refusal == ""
	if refusal == "": _table.present(_state, document.headers)
	else: stop()
	var caption := PastGamesScreen.event_label(document.records[cursor], _state, document.headers, document.finished)
	_caption.text = caption.replace("\n", " ") if refusal == "" else refusal
	_caption.tooltip_text = caption
	_position.text = "%d/%d · Turn %d · %s" % [cursor + 1, _count(), int(_state.turn), String(_state.step).replace("_", " ")]
	_position.tooltip_text = "Read-only public history. Unrecorded information is omitted."
	_changing = true
	_slider.value = cursor
	_changing = false
	if cursor == _count() - 1: stop()

func step_to(index: int) -> void:
	stop()
	seek(index)

func jump_turn(direction: int) -> void:
	stop()
	if direction > 0:
		for index in _turns:
			if index > cursor:
				seek(index)
				return
		seek(_count() - 1)
	else:
		for i in range(_turns.size() - 1, -1, -1):
			if _turns[i] < cursor:
				seek(_turns[i])
				return
		seek(0)

func toggle_play() -> void:
	if document.is_empty(): return
	if not _timer.is_stopped():
		stop()
		return
	if cursor == _count() - 1: seek(0)
	_play.text = "Pause"
	_timer.start()

func stop() -> void:
	if _timer != null: _timer.stop()
	if _play != null: _play.text = "Play"

func _tick() -> void:
	if _table.inspection_open(): return
	if cursor + 1 < _count(): seek(cursor + 1)
	else: stop()

func _count() -> int:
	return document.get("records", []).size()

func _info() -> void:
	stop()
	var lines := PackedStringArray([
		"Recorded public observations, not a running duel. Hidden cards remain hidden.",
		"Unrecorded combat choices, shields, effects and timing are omitted. Highlighted creatures are recorded attackers/blockers; arrows show recorded blocks and targets.",
		"Artwork and printed mana costs use your installed card catalogue when available. Recorded state and text take precedence. Pile and hand order are not reconstructed."])
	if not document.is_empty():
		for key in document.headers: lines.append("%s: %s" % [key, JSON.stringify(document.headers[key])])
	UiChrome.explain_popup(self, "Recorded duel", "\n\n".join(lines))

func _export_record() -> void:
	stop()
	if current_path != "": MpnFiles.export_bytes(self, FileAccess.get_file_as_bytes(current_path), current_path.get_file())

func close_player() -> void:
	stop()
	closed.emit(cursor)
	queue_free()

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo: return
	if _table.inspection_open():
		if event.keycode == KEY_ESCAPE: _table.dismiss_inspection()
		else: return
	else:
		match event.keycode:
			KEY_LEFT: step_to(cursor - 1)
			KEY_RIGHT: step_to(cursor + 1)
			KEY_HOME: step_to(0)
			KEY_END: step_to(_count() - 1)
			KEY_SPACE: toggle_play()
			KEY_ESCAPE: close_player()
			_: return
	get_viewport().set_input_as_handled()
