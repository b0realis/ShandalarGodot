class_name FullscreenCard
extends CanvasLayer
## [QoL] Read-only, click-to-enlarge for a screen's main CardPreview.
## Uses the same renderer and chosen printing, without resizing the sidebar.
## Only the already-visible card is read; never a library or hidden hand.

signal closed

const MARGIN := 12.0
const HINT_HEIGHT := 32.0

var _source: CardPreview
var _may_open: Callable
var _shade: ColorRect
var _card: CardPreview
var _hint: Label
var _previous_focus: WeakRef


func _init() -> void:
	layer = 100
	_shade = ColorRect.new()
	_shade.color = Color(0.025, 0.02, 0.015, 0.97)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_shade.focus_mode = Control.FOCUS_ALL
	_shade.hide()
	add_child(_shade)
	_card = CardPreview.new()
	_card.docked = true
	# All rules fit in this reading view, independently of the sidebar's
	# Expand toggle. This does not change that preference or its layout.
	_card.set_text_expanded(true)
	_shade.add_child(_card)
	_hint = UiChrome.body_label("Click / tap to close · Esc / Cancel", 20)
	_hint.add_theme_color_override("font_color", Color(0.93, 0.89, 0.79))
	_hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.clip_text = true
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.add_child(_hint)


func _ready() -> void:
	set_process_input(false)
	get_viewport().size_changed.connect(_fit)


## Attach once, to the large showcase only, not hover cards or choosers.
func watch(source: CardPreview, may_open: Callable) -> void:
	_source = source
	_may_open = may_open
	if Settings.fullscreen_cards() and source.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		source.mouse_filter = Control.MOUSE_FILTER_PASS
	source.gui_input.connect(_source_input)
	source.face_changed.connect(_source_changed)
	source.visibility_changed.connect(_source_changed)
	source.tree_exiting.connect(dismiss)


func is_open() -> bool:
	return _shade.visible


func open_card() -> bool:
	if is_open() or not Settings.fullscreen_cards() or not _readable():
		return false
	if _may_open.is_valid() and not _may_open.call():
		return false
	var focus := get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focus) if focus != null else null
	_card.show_card(_source._shown, _source._shown_printing_set)
	_fit()
	_shade.show()
	_shade.grab_focus()
	set_process_input(true)
	return true


func dismiss() -> void:
	if not is_open():
		return
	# A screen's later-added overlay leaves the tree before its showcase.
	# The source's tree_exiting signal must not restore focus or resume play
	# after the overlay's controls have already left the viewport.
	var live := _shade.is_inside_tree()
	_shade.hide()
	if live: _shade.release_focus()
	set_process_input(false)
	# Do not retain a formerly visible hand card behind a closed overlay.
	_card.show_back()
	if live and _previous_focus != null:
		var focus := _previous_focus.get_ref() as Control
		if is_instance_valid(focus) and focus.is_inside_tree() and focus.is_visible_in_tree():
			focus.grab_focus()
	_previous_focus = null
	if live: closed.emit()


func _readable() -> bool:
	return is_instance_valid(_source) and _source.is_visible_in_tree() \
		and _source._shown != null


func _source_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and open_card():
		_source.accept_event()


func _source_changed() -> void:
	if not is_open():
		return
	if not _readable() or _source._shown != _card._shown \
			or _source._shown_printing_set != _card._shown_printing_set:
		dismiss()
	else:
		_card.show_card(_source._shown, _source._shown_printing_set)


func _fit() -> void:
	var area := get_viewport().get_visible_rect().size
	_shade.size = area
	var available := (area - Vector2(MARGIN * 2, MARGIN * 2 + HINT_HEIGHT)).max(Vector2.ONE)
	var factor := minf(available.x / CardPreview.SIZE.x, available.y / CardPreview.SIZE.y)
	_card.scale = Vector2.ONE * factor
	_card.position = Vector2((area.x - CardPreview.SIZE.x * factor) * 0.5,
		MARGIN + (available.y - CardPreview.SIZE.y * factor) * 0.5)
	_hint.position = Vector2(MARGIN, area.y - MARGIN - HINT_HEIGHT)
	_hint.size = Vector2(maxf(1.0, area.x - MARGIN * 2), HINT_HEIGHT)


func _input(event: InputEvent) -> void:
	# TouchControls owns the raw touch and emits exactly one mouse click on
	# lift. Let it swallow Godot's duplicate emulated mouse events as usual.
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION \
			and _touch_translator_active():
		return
	if not is_open():
		return
	get_viewport().set_input_as_handled()
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			dismiss()
	elif Controls.pressed(event, "duel_cancel") \
			or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		dismiss()


func _touch_translator_active() -> bool:
	# SceneTree command-line tools parse DuelScreen before autoload names
	# are registered. Resolve the optional runtime node only when needed.
	var touch := get_node_or_null("/root/TouchControls")
	return touch != null and touch.is_active()
