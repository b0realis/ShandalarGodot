class_name DraftSession
extends Control
## [QoL] Pack opening, unpausable countdown and save-on-finish around the real builder.

signal completed(reason: String)
var pool: SealedPool
var store: DraftStore
var seconds := 1200
var builder: DraftBuilder
var deadline_ms := 0
var finished := false
var returning_to_setup := false
var reason := ""
var _clock: Label
var _bar: ProgressBar
var _opening: OriginalDialog
var _opening_elapsed := 0.0
var _opening_title: Label
var _opening_cards: Label
var _opening_art: Control
var _opening_pack := -1
var _checkpoint_at := 0
var _save_warning := ""
var _old_auto_quit := true
var _result: OriginalDialog
var _return_button: Button


class PackArt extends Control:
	var phase := 0.0
	var ground: StyleBox
	func _ready() -> void:
		ground = OriginalDialog.panel_style("panel_knot", 0)
	func _draw() -> void:
		var pips := [Color("f1e5ae"), Color("70b5db"), Color("b293c8"), Color("db8470"), Color("8ec298")]
		for i in 5:
			var centre := size * 0.5 + Vector2((i - 2) * 40, absf(i - 2) * 8)
			var card := Rect2(centre - Vector2(48, 65), Vector2(96, 130))
			draw_style_box(ground, card)
			draw_rect(card.grow(-4), pips[i].darkened(0.3), false, 2)
			var glow := 0.7 + 0.3 * sin(phase + i)
			draw_circle(centre, 14 * glow, pips[i])
			draw_arc(centre, 24, 0, TAU * glow, 48, pips[i], 1.5, true)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100
	_old_auto_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
	var ground := ColorRect.new()
	ground.color = Color("10171d")
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ground)
	_opening = OriginalDialog.create("A new pool. A new possibility.", Vector2(600, 440).min(get_viewport_rect().size - Vector2(24, 24)))
	add_child(_opening)
	_opening_art = PackArt.new()
	_opening_art.custom_minimum_size.y = 180
	_opening_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_opening.body().add_child(_opening_art)
	_opening_title = OriginalDialog.label("Opening your packs…", 22, true)
	_opening_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_opening.body().add_child(_opening_title)
	_opening_cards = OriginalDialog.label("Fresh randomness from your machine", 16)
	_opening_cards.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_opening_cards.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_opening.body().add_child(_opening_cards)
	var hint := OriginalDialog.label("The deck-building clock starts when the cards reach the table.", 14)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_opening.body().add_child(hint)
	_opening.add_button("Skip opening").pressed.connect(start_building)


func start_building() -> void:
	if builder != null or finished: return
	_opening.queue_free()
	builder = DraftBuilder.new()
	builder.draft_counts = pool.counts
	builder.input_guard = expire_if_needed
	add_child(builder)
	builder.deck.deck_name = "Draft " + Time.get_datetime_string_from_system().replace("T", " ")
	builder.refresh()
	builder.finish_requested.connect(finish.bind("done"))
	var hud := HBoxContainer.new()
	hud.name = "DraftCountdown"
	hud.anchor_left = 1
	hud.anchor_right = 1
	hud.offset_left = -300
	hud.offset_right = -12
	hud.offset_top = 10
	hud.offset_bottom = 60
	hud.z_index = 1000
	hud.add_theme_constant_override("separation", 12)
	add_child(hud)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.add_child(column)
	_clock = OriginalDialog.label("", 24, true)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_clock)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 5)
	_bar.max_value = seconds
	column.add_child(_bar)
	var done := OriginalDialog.button("Done", Vector2(84, 42))
	done.pressed.connect(finish.bind("done"))
	hud.add_child(done)
	deadline_ms = Time.get_ticks_msec() + seconds * 1000
	_checkpoint_at = Time.get_ticks_msec() + 2000
	_save_warning = store.checkpoint(builder.deck)
	_update_clock()
	if _save_warning != "": finish("save error")


func remaining_seconds() -> int:
	return maxi(0, ceili(float(deadline_ms - Time.get_ticks_msec()) / 1000.0))


func expire_if_needed() -> bool:
	if finished: return true
	if deadline_ms > 0 and Time.get_ticks_msec() >= deadline_ms:
		finish("time up")
		return true
	return false


func _update_clock() -> void:
	var remaining := remaining_seconds()
	_clock.text = "%02d:%02d" % [remaining / 60, remaining % 60]
	_clock.add_theme_color_override("font_color", Color("f29683") if remaining <= 60 else OriginalDialog.HIGHLIGHT)
	_bar.value = remaining


func _process(delta: float) -> void:
	if finished: return
	if builder == null:
		_opening_elapsed += delta
		_opening_art.phase = _opening_elapsed * 3
		_opening_art.queue_redraw()
		var duration := minf(8.0, maxf(2.0, pool.packs.size() * 0.65))
		var index := mini(pool.packs.size() - 1, int(_opening_elapsed / duration * pool.packs.size()))
		if index != _opening_pack and index >= 0:
			_opening_pack = index
			_opening_title.text = String(pool.packs[index].title)
			_opening_cards.text = "%d cards revealed · %d of %d packs" % [pool.packs[index].cards.size(), index + 1, pool.packs.size()]
		if _opening_elapsed >= duration: start_building()
		return
	_update_clock()
	if Time.get_ticks_msec() >= deadline_ms:
		finish("time up")
	elif Time.get_ticks_msec() >= _checkpoint_at:
		_checkpoint_at = Time.get_ticks_msec() + 2000
		_save_warning = store.checkpoint(builder.deck)
		if _save_warning != "": finish("save error")


func _input(event: InputEvent) -> void:
	# Before any GUI click is delivered, even when a modal or text field is open.
	if not finished and builder != null and Time.get_ticks_msec() >= deadline_ms:
		finish("time up")
		get_viewport().set_input_as_handled()
	elif finished and event is InputEventKey and event.pressed:
		# Old text fields must not consume a final key after the freeze.
		if get_viewport().gui_get_focus_owner() != null and builder.is_ancestor_of(get_viewport().gui_get_focus_owner()):
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_inside_tree():
		if builder == null: start_building()
		finish("window closed")


func finish(why: String) -> void:
	if finished: return
	if builder == null: start_building()
	finished = true
	reason = why
	if Time.get_ticks_msec() >= deadline_ms:
		reason = "time up"
		_update_clock()
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null: focus.release_focus()
	# Freeze everything, including open dialogs, drag/drop and their callbacks.
	builder.process_mode = Node.PROCESS_MODE_DISABLED
	builder.hide()
	_save_warning = store.checkpoint(builder.deck, reason)
	_show_result()
	completed.emit(reason)


func _show_result() -> void:
	if _result != null: _result.queue_free()
	var heading := "Save needs attention" if _save_warning != "" else ("Time's up" if reason == "time up" else "Draft complete")
	_result = OriginalDialog.create(heading, Vector2(650, 430).min(get_viewport_rect().size - Vector2(24, 24)))
	_result.z_index = 1500
	add_child(_result)
	var advice := "Your deck is held in memory. Retry the save or choose the default folder below."
	if _save_warning == "":
		advice = "Your deck and dealt pool are saved."
		if builder.deck.total() < DeckModel.CASUAL_MIN_CARDS:
			advice += " " + DeckModel.TOO_FEW_CARDS
		elif builder.deck.total() < DeckModel.MIN_CARDS:
			advice += " " + DeckModel.size_advice(builder.deck.total())
	var text := "%d cards in deck · %d in sideboard\n\n%s\n\n%s" % [builder.deck.total(), builder.deck.side_total(),
		"Saved to:\n" + store.deck_path if _save_warning == "" else _save_warning,
		advice]
	var label := OriginalDialog.label(text, 17)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result.body().add_child(label)
	if _save_warning != "":
		_result.add_button("Retry save").pressed.connect(func() -> void:
			_save_warning = store.checkpoint(builder.deck, reason)
			_show_result())
		_result.add_button("Save to default folder").pressed.connect(_recover_default)
	else:
		if OS.has_feature("web"):
			_result.add_button("Download deck").pressed.connect(func() -> void:
				JavaScriptBridge.download_buffer(store.deck_text(builder.deck).to_utf8_buffer(), store.deck_path.get_file(), "text/plain"))
			_result.add_button("Download pool").pressed.connect(func() -> void:
				JavaScriptBridge.download_buffer(JSON.stringify(store.receipt, "\t").to_utf8_buffer(), store.pool_path.get_file(), "application/json"))
		else:
			_result.add_button("Open save folder").pressed.connect(func() -> void: OS.shell_show_in_file_manager(store.deck_path))
		_return_button = _result.add_button("Back to draft setup")
		_return_button.pressed.connect(return_to_setup)
		_return_button.grab_focus()


func return_to_setup() -> void:
	returning_to_setup = true
	queue_free()


func _recover_default() -> void:
	var recovery := DraftStore.new()
	var refusal := recovery.prepare(GamePaths.DEFAULT_DRAFTS, pool, store.receipt.options)
	if refusal == "": refusal = recovery.checkpoint(builder.deck, reason)
	if refusal == "": store = recovery
	_save_warning = refusal
	_show_result()


func _exit_tree() -> void:
	get_tree().auto_accept_quit = _old_auto_quit
