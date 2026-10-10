class_name FullscreenCard
extends CanvasLayer
## [QoL] Read-only, click-to-enlarge for a screen's main CardPreview.
## Uses the same renderer and chosen printing, without resizing the sidebar.
## Only the already-visible card is read; never a library or hidden hand.
##
## AND ITS TEXT IS SHARP (2026-09-30, "some say the text is a bit
## blurred"). The reader is the sidebar's 300-px [CardPreview] under a
## node `scale` of two to three — the one way to keep the two layouts
## identical — and Godot's automatic font oversampling follows the
## WINDOW's stretch, not a node's scale: the rules text was rasterised
## at 13 px and stretched. Measured under Xvfb on a 13 px label at ×3:
## 21% of its pixels were intermediate edge shades; the same label set
## at 39 px, 5%. So while the reader is open the viewport's
## `oversampling_override` is the automatic value times the reader's
## factor (6% — as crisp as native), and 0 (automatic) again the moment
## it closes. Nothing else changes: the frame and the art are bitmaps
## either way, the layout is the sidebar's to the pixel.
##
## ITS OWN `Text` TOGGLE (2026-10-10, the owner: *"as when players click
## on large card to show it fullscreen they sometimes want to examine the
## art! So they should be able to toggle off and on the large text
## rectangle. The default should be small on the full screen card."*).
## The reader used to grow the text box over the art for every card whose
## text did not fit, with no way back. Now a button at the card's bottom
## right — the Deck Builder's `Text: 1997` / `Text: full`, same words,
## same box — switches it, Enter does too (the R36's X; a pad's A while
## the pad pointer is off — on, A is the click), and the choice is kept
## ([constant FULL_TEXT_SETTING]). It starts on 1997,
## the small box. It is the reader's own: the sidebar's Expand
## ([method CardPreview.expand_wanted]) is a different view of a
## different size, and toggling one never moves the other.

signal closed

const MARGIN := 12.0
const HINT_HEIGHT := 32.0
## The reader's `Text` choice; false (the 1997 box) until the player
## switches it.
const FULL_TEXT_SETTING := "fullscreen_card_full_text"
const TOGGLE_SIZE := Vector2(124, 32)
## Between the card's right edge and the toggle beside it.
const TOGGLE_GAP := 10.0

var _source: CardPreview
var _may_open: Callable
var _shade: ColorRect
var _card: CardPreview
var _hint: Label
var _text_toggle: Button
var _previous_focus: WeakRef
var _sharpening := false


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
	_text_toggle = OriginalDialog.button(toggle_label(false), TOGGLE_SIZE)
	_text_toggle.name = "TextToggle"
	_text_toggle.toggle_mode = true
	_text_toggle.focus_mode = Control.FOCUS_NONE
	_text_toggle.tooltip_text = "The large text box over the art, or the " \
		+ "1997 one that leaves the art clear — Enter switches it too"
	_text_toggle.pressed.connect(toggle_text)
	_shade.add_child(_text_toggle)


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


## Does the player want the reader's large text box? False — the 1997
## box — until they switch it.
static func full_text_wanted() -> bool:
	return bool(Settings.get_value(FULL_TEXT_SETTING, false))


## The toggle's words: the Deck Builder's, so one switch reads the same
## in both places.
static func toggle_label(full: bool) -> String:
	return "Text: full" if full else "Text: 1997"


## Switch the open card between the 1997 text box and the large one, and
## keep the choice.
func toggle_text() -> void:
	var full := not _card.text_is_expanded()
	Settings.set_value(FULL_TEXT_SETTING, full)
	_card.set_text_expanded(full)
	_dress_toggle()


func _dress_toggle() -> void:
	var full := _card.text_is_expanded()
	_text_toggle.set_pressed_no_signal(full)
	_text_toggle.text = toggle_label(full)


## [param by_key] is the `duel_read` action (R / R3; 2026-10-02, the R36
## Ultra tester: *"an easy way to bring a card up full-size when you need
## to read it"*): a deliberate keystroke, so it opens the reader whether or
## not the click-to-enlarge switch is on. The screen's own gate (what is
## in the way) applies to both.
func open_card(by_key: bool = false) -> bool:
	if is_open() or not _readable():
		return false
	if not by_key and not Settings.fullscreen_cards():
		return false
	if _may_open.is_valid() and not _may_open.call():
		return false
	var read := Controls.text("duel_read")
	_hint.text = "Click / tap to close · Esc / Cancel" \
		+ ("" if read == Controls.UNBOUND else " · " + read) + " · Enter: text"
	var focus := get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focus) if focus != null else null
	# The card is a back while the reader is shut ([method dismiss]), so
	# this sets the box without laying a face out twice.
	_card.set_text_expanded(full_text_wanted())
	_dress_toggle()
	_card.show_card(_source._shown, _source._shown_printing_set)
	_shade.show()
	_fit()
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
	if live: get_viewport().oversampling_override = 0.0
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
	if is_open():
		_sharpen(factor)
	_card.position = Vector2((area.x - CardPreview.SIZE.x * factor) * 0.5,
		MARGIN + (available.y - CardPreview.SIZE.y * factor) * 0.5)
	_hint.position = Vector2(MARGIN, area.y - MARGIN - HINT_HEIGHT)
	_hint.size = Vector2(maxf(1.0, area.x - MARGIN * 2), HINT_HEIGHT)
	# The toggle stands at the card's bottom right, beside it, where it
	# covers neither the art nor the power and toughness. A screen with no
	# room beside the card (a portrait phone) has it at the right of the
	# hint's row instead, and the hint gives it the room.
	var toggle := _text_toggle.get_combined_minimum_size().max(TOGGLE_SIZE)
	_text_toggle.size = toggle
	var card_end := _card.position + CardPreview.SIZE * factor
	if area.x - MARGIN - card_end.x >= TOGGLE_GAP + toggle.x:
		_text_toggle.position = Vector2(card_end.x + TOGGLE_GAP, card_end.y - toggle.y)
	else:
		_text_toggle.position = Vector2(area.x - MARGIN - toggle.x,
			area.y - MARGIN - HINT_HEIGHT + (HINT_HEIGHT - toggle.y) * 0.5)
		_hint.size.x = maxf(1.0, _text_toggle.position.x - MARGIN * 2)


## Fonts rasterised for the reader's scale, not the window's (see the
## top of the file): the automatic value is read with the override off,
## then multiplied. A resize while open comes back through [method _fit];
## so does EACH CHANGE OF THE OVERRIDE — the viewport says `size_changed`
## for it, which is what the flag is for (the first run without it was a
## stack overflow).
func _sharpen(factor: float) -> void:
	var viewport := get_viewport()
	if viewport == null or _sharpening:
		return
	_sharpening = true
	viewport.oversampling_override = 0.0
	var wanted := viewport.get_oversampling() * factor
	if not is_equal_approx(viewport.oversampling_override, wanted):
		viewport.oversampling_override = wanted
	_sharpening = false


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
	# The pointer reaches the reader's own controls — the toggle, which
	# lights under it and is clicked like any button — and nothing else:
	# the shade stops it there.
	if event is InputEventMouseMotion:
		return
	if event is InputEventMouseButton and _text_toggle.get_global_rect().has_point(event.position):
		return
	get_viewport().set_input_as_handled()
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			dismiss()
	elif Controls.pressed(event, "duel_cancel") or Controls.pressed(event, "duel_read") \
			or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		dismiss()
	elif event.is_action_pressed("ui_accept"):
		toggle_text()


func _touch_translator_active() -> bool:
	# SceneTree command-line tools parse DuelScreen before autoload names
	# are registered. Resolve the optional runtime node only when needed.
	var touch := get_node_or_null("/root/TouchControls")
	return touch != null and touch.is_active()
