class_name SgLobbyStyle
extends RefCounted
## [QoL] SGManalink's restrained stone frame, parchment sections and shared controls.
## Reuses the game's fonts and chrome; no downloaded art or platform-native dialogs.
##
## LETTERING WEARS ITS SURFACE (2026-09-18). The owner's playtest: *"In
## SGManalink some menus have black letters on dark (stone looking
## windows). That cannot be read. Please change so all lettering is
## contrasting brighter on dark windows."* A label used to take its ink
## from a flag the caller passed, and the sub-windows of the same day
## moved a dozen labels from paper sections onto the stone with the flag
## left at its default — INK on dark stone, the very thing. Now a label,
## a check box or a check button reads the surface it sits on when it
## enters the tree, the way a button does ([method dress]): [constant
## PALE] on a dark section, the stone frame or a window, [constant
## UiChrome.INK] on paper ([method seat]). A colour the caller set itself
## — gold facts, an accent warning, a green Ready — is kept. A rich text
## (a decklist) sits in a parchment well of its own, like the list beside
## it, and reads the same everywhere.

const PAPER := Color8(216, 203, 174)
const WELL := Color8(234, 223, 198)
const GOLD := Color8(187, 158, 98)
const PALE := Color8(235, 222, 191)
const MUTED := Color8(180, 180, 157)
const DARK := Color8(27, 34, 29)

## The colours a control's lettering may wear: INK on paper, PALE on
## the dark sections, the stone frame and the windows.
const INKS := ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color",
	"font_focus_color"]

## A label. [param dark_surface] is the caller's guess before the label
## is in the tree; the surface it lands on has the last word ([method
## seat]).
static func label(text: String, size := 16, dark_surface := false) -> Label:
	var node := UiChrome.body_label(text, size)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ink(node, dark_surface)
	node.add_theme_color_override("font_shadow_color", Color(0,0,0,0))
	node.add_theme_constant_override("shadow_outline_size", 0)
	if size >= 24:
		var font := GameSkin.font("font_title")
		if font != null: node.add_theme_font_override("font", font)
	node.tree_entered.connect(seat.bind(node))
	return node


## A check box or a check button: the game's tick, and lettering that
## follows the surface like a label's.
static func check(node: Button) -> void:
	UiChrome.shadowed_button(node)
	node.set_meta("sg_ink", UiChrome.INK)
	node.tree_entered.connect(seat.bind(node))


## Give [param node] the ink of the surface it sits on — [constant PALE]
## off paper, [constant UiChrome.INK] on it — unless the caller has set
## a colour of its own since the last seating: that one is kept.
static func seat(node: Control) -> void:
	if node.has_meta("sg_ink") and node.has_theme_color_override("font_color") \
			and node.get_theme_color("font_color") != node.get_meta("sg_ink"):
		return
	_ink(node, not on_paper(node))


static func _ink(node: Control, pale: bool) -> void:
	var colour: Color = PALE if pale else UiChrome.INK
	if node is Button:
		for state in INKS:
			node.add_theme_color_override(state, colour)
		# The seat is INK's: a pale one-pixel outline lifts dark letters
		# off the stone, and would smear pale ones.
		node.add_theme_color_override("font_shadow_color", UiChrome.SEAT if not pale else Color(0,0,0,0))
		node.add_theme_color_override("font_disabled_color", Color8(74, 66, 60) if not pale else MUTED)
	else:
		node.add_theme_color_override("font_color", colour)
	node.set_meta("sg_ink", colour)

static func panel(inner: Control, light := true, margin := 18.0) -> PanelContainer:
	var box := StyleBoxFlat.new()
	box.bg_color = PAPER if light else DARK
	box.border_color = GOLD.darkened(0.25)
	box.set_border_width_all(1)
	box.set_content_margin_all(margin)
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", box)
	node.set_meta("sg_light", light)
	node.add_child(inner)
	return node

static func column(parent: Node, title := "", light := true) -> VBoxContainer:
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	parent.add_child(panel(body, light))
	if not title.is_empty(): body.add_child(label(title, 22, not light))
	return body

static func row(parent: Node) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	parent.add_child(line)
	return line

## THE SUB-WINDOW (2026-09-18). The owner's playtest: *"Online windows
## should be less cluttered with only the key setting front-center and all
## the rest in sub menus or windows."* A page keeps its few key settings
## and puts the rest behind a button that opens one of these: a dimmed
## sheet over the whole viewport with a stone panel in the middle — the
## title, a Close button and the caller's column. The window is built once
## and HIDDEN, as a `top_level` child of its owner: the owner's container
## does not lay it out, the scroll it sits in does not clip it, and its
## controls stay in the tree with their state (a deck chosen in the window
## is still chosen when it opens again; a test seam finds them by name).
## `z_index` WINDOW_Z lifts it above the Master Panel's opaque sheet (500).
## Returns the column to fill; the sheet is the column's meta "sg_window".
const WINDOW_Z := 600

static func window(owner: Control, title: String, node_name := "") -> VBoxContainer:
	var sheet := ColorRect.new()
	sheet.name = node_name if not node_name.is_empty() else "SubWindow"
	sheet.color = Color(0, 0, 0, 0.82)
	sheet.top_level = true
	sheet.z_index = WINDOW_Z
	sheet.focus_mode = Control.FOCUS_ALL
	sheet.hide()
	owner.add_child(sheet)
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	var frame := panel(column, false, 20)
	frame.add_theme_stylebox_override("panel", OriginalDialog.panel_style("panel_dark_stone", 20))
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	frame.grow_vertical = Control.GROW_DIRECTION_BOTH
	sheet.add_child(frame)
	var heading := row(column)
	var caption := label(title, 24, true)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(caption)
	var close := button("Close", func() -> void: sheet.hide(), Vector2(110, 38))
	close.name = "CloseWindow"
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	body.set_meta("sg_window", sheet)
	body.set_meta("sg_frame", frame)
	# The panel takes most of the viewport, never more than a page's width.
	# Offsets around the centre anchor, never `size`: a hidden sheet's
	# minimum sizes are stale (an autowrapped label with no width yet reads
	# one word per line) and `size` clamps to them for good — on a runner
	# without the skin the wider font made a 705 px frame on a 600 px
	# viewport. Offsets hold the wanted rect; a transient minimum only
	# grows the frame both ways until the layout settles.
	var fit := func() -> void:
		if not sheet.is_inside_tree(): return
		var view := sheet.get_viewport_rect().size
		var wanted := Vector2(minf(940, maxf(0, view.x - 48)), minf(700, maxf(0, view.y - 64))) * 0.5
		frame.offset_left = -wanted.x
		frame.offset_right = wanted.x
		frame.offset_top = -wanted.y
		frame.offset_bottom = wanted.y
	sheet.visibility_changed.connect(fit)
	sheet.resized.connect(fit)
	# A click on the sheet outside the panel closes it, like Escape — and
	# like a pad's B, which arrives as `ui_cancel` and not as a key (gap
	# review 2026-11-10, R4-11).
	sheet.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			sheet.hide()
			sheet.accept_event()
		elif (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE) \
				or (not event is InputEventKey and event.is_action_pressed("ui_cancel", false, true)):
			sheet.hide()
			sheet.accept_event())
	frame.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton: frame.accept_event())
	return body

## Show the sub-window that [method window] built [param body] in.
static func open_window(body: Control) -> void:
	var sheet: Control = body.get_meta("sg_window")
	sheet.show()
	sheet.grab_focus()

static func close_window(body: Control) -> void:
	var sheet: Control = body.get_meta("sg_window")
	sheet.hide()

static func window_open(body: Control) -> bool:
	return body != null and is_instance_valid(body) and (body.get_meta("sg_window") as Control).visible

## A BUTTON WEARS ITS SURFACE (2026-09-17): parchment buttons on the paper
## sections, the stone-grey window button everywhere else — the dark
## sections and the stone frame. No caller chooses: [method panel] marks
## the surface and [method dress] reads it when the button enters the
## tree, so a button moved to another section changes with it. Any theme
## override a caller sets before that keeps precedence.
static func button(text: String, callback: Callable, minimum := Vector2(150, 40)) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = minimum
	node.focus_mode = Control.FOCUS_ALL
	node.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	node.pressed.connect(callback)
	node.tree_entered.connect(dress.bind(node))
	return node

const BUTTON_BOXES := ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]
const BUTTON_COLOURS := ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color",
	"font_focus_color", "font_disabled_color", "font_shadow_color"]
const BUTTON_CONSTANTS := ["shadow_offset_x", "shadow_offset_y", "shadow_outline_size", "outline_size"]

## True on a paper section, false on a dark one, the stone frame or a window.
static func on_paper(node: Node) -> bool:
	var probe := node.get_parent()
	while probe != null:
		if probe.has_meta("sg_light"): return bool(probe.get_meta("sg_light"))
		probe = probe.get_parent()
	return false

## Give [param button] the face of the surface it sits on. The two faces
## are the shell's parchment button and the duel window's grey one, copied
## from a fresh model so the three of them can never drift apart.
static func dress(button: Button) -> void:
	var sand := on_paper(button)
	if button.has_meta("sg_sand") and button.get_meta("sg_sand") == sand: return
	var model := UiChrome.menu_button("", button.custom_minimum_size, 18) if sand \
		else OriginalDialog.button("", button.custom_minimum_size)
	var previous: Array = button.get_meta("sg_dressed", [])
	var dressed := []
	for key in BUTTON_BOXES:
		if button.has_theme_stylebox_override(key) and not previous.has("box:" + key): continue
		if model.has_theme_stylebox_override(key):
			button.add_theme_stylebox_override(key, model.get_theme_stylebox(key))
			dressed.append("box:" + key)
		else: button.remove_theme_stylebox_override(key)
	for key in BUTTON_COLOURS:
		if button.has_theme_color_override(key) and not previous.has("colour:" + key): continue
		if model.has_theme_color_override(key):
			button.add_theme_color_override(key, model.get_theme_color(key))
			dressed.append("colour:" + key)
		else: button.remove_theme_color_override(key)
	for key in BUTTON_CONSTANTS:
		if button.has_theme_constant_override(key) and not previous.has("constant:" + key): continue
		if model.has_theme_constant_override(key):
			button.add_theme_constant_override(key, model.get_theme_constant(key))
			dressed.append("constant:" + key)
		else: button.remove_theme_constant_override(key)
	if not (button.has_theme_font_override("font") and not previous.has("font")):
		if model.has_theme_font_override("font"):
			button.add_theme_font_override("font", model.get_theme_font("font"))
			dressed.append("font")
		else: button.remove_theme_font_override("font")
	if not (button.has_theme_font_size_override("font_size") and not previous.has("font_size")):
		if model.has_theme_font_size_override("font_size"):
			button.add_theme_font_size_override("font_size", model.get_theme_font_size("font_size"))
			dressed.append("font_size")
		else: button.remove_theme_font_size_override("font_size")
	# The theme's pale focus text reads as disabled on either face.
	if not button.has_theme_color_override("font_focus_color"):
		button.add_theme_color_override("font_focus_color", UiChrome.INK)
		dressed.append("colour:font_focus_color")
	button.set_meta("sg_dressed", dressed)
	button.set_meta("sg_sand", sand)
	model.free()

static func option(node: OptionButton) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = WELL
	box.border_color = GOLD.darkened(0.4)
	box.set_border_width_all(1)
	box.set_content_margin_all(9)
	for state in ["normal", "hover", "pressed", "disabled"]:
		node.add_theme_stylebox_override(state, box)
	node.add_theme_stylebox_override("focus", OriginalDialog.focus_ring())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(state, UiChrome.INK)
	node.add_theme_color_override("font_shadow_color", Color(0,0,0,0))
	node.add_theme_font_size_override("font_size", 17)
	var font := GameSkin.font("font_body")
	if font != null: node.add_theme_font_override("font", font)

static func field(edit: LineEdit) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = WELL
	box.border_color = GOLD.darkened(0.4)
	box.set_border_width_all(1)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	edit.add_theme_stylebox_override("normal", box)
	edit.add_theme_stylebox_override("read_only", box)
	var focus := box.duplicate() as StyleBoxFlat
	focus.border_color = UiChrome.ACCENT
	focus.set_border_width_all(2)
	edit.add_theme_stylebox_override("focus", focus)
	edit.add_theme_color_override("font_color", UiChrome.INK)
	edit.add_theme_color_override("font_uneditable_color", Color8(90,80,65))
	edit.add_theme_color_override("font_placeholder_color", Color8(106,97,79))
	edit.add_theme_color_override("caret_color", UiChrome.INK)
	edit.add_theme_color_override("selection_color", Color8(94,83,55))
	edit.add_theme_color_override("font_selected_color", Color.WHITE)
	edit.add_theme_font_size_override("font_size", 17)
	var font := GameSkin.font("font_body")
	if font != null: edit.add_theme_font_override("font", font)
	edit.custom_minimum_size.y = 40
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL

static func deck_list(list: ItemList) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = WELL
	box.set_content_margin_all(8)
	list.add_theme_stylebox_override("panel", box)
	var selected := StyleBoxFlat.new()
	selected.bg_color = Color8(77,85,57)
	selected.set_content_margin_all(6)
	list.add_theme_stylebox_override("selected", selected)
	list.add_theme_stylebox_override("selected_focus", selected)
	list.add_theme_color_override("font_color", UiChrome.INK)
	list.add_theme_color_override("font_selected_color", PALE)
	list.add_theme_font_size_override("font_size", 16)
	list.add_theme_constant_override("v_separation", 10)
	var font := GameSkin.font("font_body")
	if font != null: list.add_theme_font_override("font", font)

static func rich_text(node: RichTextLabel) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = WELL
	box.set_content_margin_all(8)
	node.add_theme_stylebox_override("normal", box)
	node.add_theme_color_override("default_color", UiChrome.INK)
	node.add_theme_font_size_override("normal_font_size", 17)
	node.add_theme_constant_override("line_separation", 3)
	var font := GameSkin.font("font_body")
	if font != null: node.add_theme_font_override("normal_font", font)
