class_name DuelMiniHelp
extends Control
## THE DUEL'S MINI HELP — what `Help...` on every duel mini-menu opens
## (the owner's ruling of 2026-10-13: *"Maybe here we only keep focused mini
## help hover over and leave the main help as is reachable from the main
## menu."*). The full Help screen stays the main menu's — it closes to the
## title, so a duel cannot open it — and in a duel each menu's `Help...`
## shows a small panel over the table with the short help for exactly the
## thing that was right-clicked. The words are [method HelpPages.mini]'s
## (and [method HelpPages.mini_phase], [method HelpPages.mini_card]): this
## file is only the panel.
##
## IT FEELS LIKE A HOVER HELP: small, on the menu's own dark stone, opened
## where the menu stood and kept on the screen, and NOTHING IS DIMMED. The
## control itself is a transparent catcher over the whole duel: the table
## stays in view, but no click, hover or wheel reaches it, and a click or
## tap anywhere outside the panel closes it.
##
## WAYS OUT — every one hands the keyboard/pad focus back to whatever held
## it before ([method dismiss]):
##   - the Close button (the focus starts on it, so Enter, Space and a
##     pad's A with the pad pointer off press it);
##   - Escape and the pad's B (`duel_cancel`), routed here by the duel
##     ([method answer]);
##   - a click or tap outside the panel — on its RELEASE, and never in the
##     first [constant SETTLE_MS] or on a double click's second press, the
##     graveyard view's rule against a doubled press closing what it opened;
##   - the menu key again: a right click (LB under the pad pointer, a long
##     press on a touchscreen) anywhere, inside the panel or out;
##   - the pause key, which closes it and goes on to the duel's pause menu,
##     as the card reader does ([method FullscreenCard._input]).
##
## THE DUEL WAITS while it is up: [method DuelScreen.mini_help_open] stops
## the computer's clock, the automatic pass and a standing Run to / Done
## order, and the duel's keys reach nothing but this panel. At an
## SGManalink table it is the local screen's alone: nothing is sent, and
## the other seat waits for nothing.
##
## READABLE ON A SMALL SCREEN. The duel is laid out on a 1280x800 canvas
## and a 640x480 handheld draws that canvas at half size, so the panel's
## letters grow by [method reading_scale] when the window shows the canvas
## smaller than it is laid out — never past [constant MAX_SCALE], never
## smaller than at a desk — and a text taller than the screen allows
## scrolls (wheel, a finger's drag, the pad's right stick, the arrows).

## Emitted once, as the panel closes.
signal closed

## Over every window of the duel (the dialogs 200, the end-of-duel 250,
## the splash 260), under the pause menu (270) the pause key opens after
## closing this.
const Z := 265
## The panel's width at a desk, before [method reading_scale].
const WIDTH := 380.0
## What the panel keeps from every edge of the screen.
const SCREEN_MARGIN := 8.0
## The panel opens this far right of the spot the menu stood at.
const GAP := 6.0
## A press this soon after opening is the opening press arriving twice.
const SETTLE_MS := 250
## The most the letters grow on a small window.
const MAX_SCALE := 1.75
## The tallest the panel grows, as a share of the screen's height; a longer
## text scrolls inside it.
const MAX_HEIGHT_SHARE := 0.7
const TITLE_SIZE := 17
const BODY_SIZE := 15
const MORE_SIZE := 13
const BUTTON_SIZE := Vector2(96, 26)
const PAD := 12.0
## The panel's last line: where the whole story is.
const MORE := "More in Help on the main menu: %s"
## The panel's one button.
const CLOSE := "Close"

## What the panel shows: the subject ([constant HelpPages.MINI_SUBJECTS],
## `phase` or `card help`) and its `{title, text, page}`.
var subject := ""
var entry: Dictionary = {}

var _anchor := Vector2.ZERO
var _panel: PanelContainer = null
var _scroll: ScrollContainer = null
var _title: Label = null
var _body: Label = null
var _more: Label = null
var _close: Button = null
var _scale := 1.0
var _open := false
var _opened_ms := 0
var _press_taken := false
var _before: WeakRef = null
var _hide_focus := false


func _init() -> void:
	name = "MiniHelp"
	# THE CATCHER: transparent, but it takes the pointer over the whole
	# duel, so nothing under it is clicked, hovered or scrolled.
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	z_index = Z


## Show [param words] (`{title, text, page}`) for [param what] over
## [param host], beside [param at] (screen coordinates — where the menu
## stood). Takes the focus, remembering who had it.
func open_on(host: Control, what: String, words: Dictionary, at: Vector2) -> void:
	subject = what
	entry = words
	_anchor = at
	var viewport := host.get_viewport()
	var before: Control = viewport.gui_get_focus_owner() if viewport != null else null
	_before = weakref(before) if before != null else null
	_hide_focus = before != null and not before.has_focus(true)
	host.add_child(self)
	# PICKING IS TREE ORDER, whatever the z ([GraveyardView.Z]): the last
	# child is the one a click finds first.
	host.move_child(self, -1)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_fit()
	_open = true
	_opened_ms = Time.get_ticks_msec()
	_close.grab_focus()
	# A resized window (a Deck docked, a desktop window dragged) re-fits
	# the panel once the duel under it has taken the new size.
	resized.connect(_fit)


func is_open() -> bool:
	return _open


## The words on the panel, as the player reads them (tests read this).
func shown_text() -> String:
	if _title == null:
		return ""
	return "\n".join([_title.text, _body.text, _more.text])


## The panel's rectangle on the screen.
func panel_rect() -> Rect2:
	return _panel.get_global_rect() if _panel != null else Rect2()


## Close, hand the focus back, emit [signal closed] once.
func dismiss() -> void:
	if not _open:
		return
	_open = false
	var viewport := get_viewport()
	visible = false
	if _close != null and _close.has_focus():
		_close.release_focus()
	_give_focus_back(viewport)
	closed.emit()
	queue_free()


## A keystroke or pad button the duel routed here while the panel is up
## ([method DuelScreen._on_control]): Escape, the pad's B, the pause key
## and the accept keys close it; everything else is swallowed by the duel.
func answer(event: InputEvent) -> void:
	if not _open:
		return
	if Controls.pressed(event, "duel_cancel") or Controls.pressed(event, "duel_pause") \
			or event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept") \
			or (event is InputEventKey and event.pressed and not event.echo
				and event.keycode == KEY_ESCAPE):
		dismiss()


## How much bigger the letters are drawn on a window that shows the
## 1280x800 canvas at [param window_px] instead of [param logical]: the
## inverse of the window's shrink, 1 at a desk or larger, at most
## [constant MAX_SCALE].
static func reading_scale(window_px: Vector2, logical: Vector2) -> float:
	if window_px.x <= 0.0 or window_px.y <= 0.0 or logical.x <= 0.0 or logical.y <= 0.0:
		return 1.0
	var shown := minf(window_px.x / logical.x, window_px.y / logical.y)
	return clampf(1.0 / shown, 1.0, MAX_SCALE)


## Where a panel of [param panel_size] goes beside [param anchor] inside
## [param room]: to the right of the spot, moved left and up as far as it
## must to stay [param margin] inside every edge.
static func place(anchor: Vector2, panel_size: Vector2, room: Vector2,
		margin := SCREEN_MARGIN) -> Vector2:
	var at := anchor + Vector2(GAP, 0)
	at.x = minf(at.x, room.x - margin - panel_size.x)
	at.y = minf(at.y, room.y - margin - panel_size.y)
	return Vector2(maxf(at.x, margin), maxf(at.y, margin))


# ------------------------------------------------------------- building --

func _build() -> void:
	_scale = _window_scale()
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel",
		OriginalDialog.panel_style("panel_dark_stone", PAD * _scale))
	_panel.gui_input.connect(_on_panel_input)
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", roundi(8 * _scale))
	_panel.add_child(column)
	_title = OriginalDialog.wrapped(String(entry.get("title", "")),
		roundi(TITLE_SIZE * _scale), true)
	column.add_child(_title)
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	column.add_child(_scroll)
	_body = OriginalDialog.wrapped(String(entry.get("text", "")),
		roundi(BODY_SIZE * _scale))
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)
	var page := String(entry.get("page", ""))
	_more = OriginalDialog.wrapped(MORE % page if page != "" else "",
		roundi(MORE_SIZE * _scale))
	_more.add_theme_color_override("font_color", OriginalDialog.CHOICE)
	_more.visible = page != ""
	column.add_child(_more)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(row)
	_close = OriginalDialog.button(CLOSE, BUTTON_SIZE * _scale)
	_close.name = "Close"
	_close.add_theme_font_size_override("font_size", roundi(14 * _scale))
	_close.pressed.connect(dismiss)
	_close.gui_input.connect(_on_close_input)
	row.add_child(_close)
	# THE RING STAYS ON THE PANEL: the arrows and the D-pad scroll the
	# text ([method _on_close_input]) and never walk the focus off onto
	# the duel underneath.
	var own := _close.get_path_to(_close)
	_close.focus_neighbor_left = own
	_close.focus_neighbor_right = own
	_close.focus_neighbor_top = own
	_close.focus_neighbor_bottom = own
	_close.focus_next = own
	_close.focus_previous = own


## Size the panel to its words and put it beside the anchor, on screen.
func _fit() -> void:
	if _panel == null or not is_inside_tree():
		return
	var room := size
	var width := minf(WIDTH * _scale, room.x - 2 * SCREEN_MARGIN)
	var inner := maxf(1.0, width - 2 * PAD * _scale)
	_panel.custom_minimum_size = Vector2(width, 0)
	# A folded line knows its height only once it knows its width — give
	# each its column now rather than after the containers' next sort
	# (the measurement [method OriginalDialog.fit_height] makes).
	for line in [_title, _body, _more]:
		line.size = Vector2(inner, 0)
		line.update_minimum_size()
	var body_height: float = _body.get_minimum_size().y
	_scroll.custom_minimum_size = Vector2(inner, 0)
	_panel.size = Vector2(width, 0)
	var chrome: float = _panel.get_combined_minimum_size().y
	var tallest: float = minf(room.y * MAX_HEIGHT_SHARE, room.y - 2 * SCREEN_MARGIN)
	var line_height: float = _body.get_line_height() if _body.get_line_count() > 0 \
		else BODY_SIZE * _scale
	var view := clampf(tallest - chrome, minf(line_height, body_height), body_height)
	_scroll.custom_minimum_size = Vector2(inner, view)
	_panel.reset_size()
	_panel.size = Vector2(width, _panel.get_combined_minimum_size().y)
	var local := get_global_transform().affine_inverse() * _anchor
	_panel.position = place(local, _panel.size, room)


func _window_scale() -> float:
	var viewport := get_viewport()
	if viewport is Window:
		return reading_scale(Vector2((viewport as Window).size),
			viewport.get_visible_rect().size)
	return 1.0


# ---------------------------------------------------------------- input --

## The catcher: everything the pointer does outside the panel lands here.
func _gui_input(event: InputEvent) -> void:
	if not _open:
		return
	accept_event()
	var mb := event as InputEventMouseButton
	if mb == null:
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		if mb.pressed:
			dismiss()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		# The opening press arriving twice — a doubled tap, a Steam Input
		# copy — or a double click's second half: neither is a decision.
		_press_taken = not mb.double_click \
			and Time.get_ticks_msec() - _opened_ms >= SETTLE_MS
	elif _press_taken:
		_press_taken = false
		dismiss()


## Inside the panel: the menu key again closes it; a left click on the
## words does nothing (a finger dragging them scrolls).
func _on_panel_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		_panel.accept_event()
		dismiss()


## The arrows, Page Up/Down and the D-pad (with the pad pointer off) move
## the text, not the focus.
func _on_close_input(event: InputEvent) -> void:
	var step := 0.0
	if event.is_action_pressed("ui_up", true):
		step = -1.0
	elif event.is_action_pressed("ui_down", true):
		step = 1.0
	elif event.is_action_pressed("ui_page_up", true):
		step = -4.0
	elif event.is_action_pressed("ui_page_down", true):
		step = 4.0
	elif event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_right", true):
		_close.accept_event()
		return
	if step == 0.0:
		return
	_close.accept_event()
	_scroll.scroll_vertical += roundi(step * BODY_SIZE * _scale * 2.0)


## The focus back where it was — hidden again if the mouse had given it —
## unless something has taken it meanwhile or the old holder is gone
## ([method UiChrome._give_focus_back], the popups' own rule).
func _give_focus_back(viewport: Viewport) -> void:
	if _before == null or viewport == null:
		return
	var owner_now := viewport.gui_get_focus_owner()
	if owner_now != null and owner_now != _close:
		return
	var control := _before.get_ref() as Control
	if control == null or not control.is_inside_tree() or not control.is_visible_in_tree() \
			or control.focus_mode == Control.FOCUS_NONE:
		return
	control.grab_focus(_hide_focus)
