class_name UiChrome
extends RefCounted
## Shared 1997 window dressing: the original's beveled sandstone panel
## (Winbk_Options) as a 9-patch StyleBox, applied to every dialog, sidebar
## and zone panel — with a sandstone flat fallback when the skin is
## absent. One place to change the game's "window" look.
##
## THE LETTERING, AND THE DAY IT WAS WRONG. The original writes DARK INK
## on its light faces and pale ink on its dark ones — [OriginalDialog]
## carries both voices, measured off the art. This file used to write the
## PALE voice on a panel that is light: `Winbk_Options` measures 183/255
## mean luminance (PIL, 2026-09-03), so near-white letters with a black
## drop shadow sat on sand as a grey smear. The first exported build was
## playtested on 2026-09-03 and the report was exactly that — "all white
## text is unreadable on sand-colored menu boxes". Menu text is [constant
## INK] now, seated on a one-pixel pale shadow instead of a black one.
##
## The SKINLESS fallback moved with it: it used to be a near-black flat
## box, which is why the pale voice ever looked right in the first place.
## A player with no imported art now gets sandstone too, so ONE ink colour
## serves both grounds and neither can drift. `tests/ui/
## test_ui_chrome_contrast.gd` pins the pair.
##
## HOVER TEXT THAT FITS THE WINDOW (2026-09-18). Godot's stock tooltip is
## ONE LINE: a Label with word wrapping off inside a PopupPanel, and the
## engine only clamps the popup's POSITION to the window — a sentence of
## `tooltip_text` on the Options screen measured 1486px wide in a 1280px
## window, so the owner read *"sometimes this hovertext overflows the
## window size and cannot be read."* The deck builder's cells had shaped
## their own tooltips since playtest #8 ([method
## CardArea.Cell._make_custom_tooltip]); that shaping lives here now
## ([method shape_tooltip]), and [method watch_tooltips] applies it to
## every stock tooltip in the process: [Lifecycle] connects the tree's
## `node_added` to [method fit_tooltip], which recognises the engine's own
## label the moment it enters the tree — synchronously inside `add_child`,
## BEFORE `_gui_show_tooltip` measures the popup — and wraps it to the
## viewport it will open in. A custom tooltip that already wraps is left
## alone. `tests/ui/test_tooltips_fit_2026_09_18.gd` reads every tooltip
## of the Options screen through the same path.

## Letters on a light face — the same ink [OriginalDialog] uses.
const INK := Color8(28, 24, 26)
## The one-pixel seat under the ink: a pale offset shadow, which on
## mottled stone does what a black one does on a dark ground.
const SEAT := Color(1, 0.97, 0.90, 0.75)
## EMPHASIS on a light face — a heading, a named thing, the word a
## sentence turns on. The original emphasises with warm gold, which is
## legible on ITS dark grounds and vanishes on sandstone; the 2026-09-03
## playtest asked for "some contrasting dark color — dark purple for
## example", and dark purple is also the one hue the era's own card
## frames leave free, so an emphasised word cannot be mistaken for a
## colour cue.
const ACCENT := Color8(74, 26, 92)
## THE CHOSEN ONE OF A ROW OF TOGGLES — see [method gold_when_chosen].
## The warm gold the original emphasises with on its DARK grounds (the
## duel log's seat ink is the same), which is where a default-themed
## button's face is: [constant ACCENT] is for sandstone and would vanish
## on charcoal.
const CHOSEN := Color8(252, 206, 108)
## The skinless panel face: sandstone, so [constant INK] reads on it.
const FACE := Color8(196, 179, 146)
## Its bevel.
const FACE_EDGE := Color8(120, 100, 70)


## The universal stone panel StyleBox.
static func stone_panel(content_margin := 10.0) -> StyleBox:
	var texture := GameSkin.texture("panel_stone")
	if texture != null:
		var box := StyleBoxTexture.new()
		box.texture = texture
		# The original panel's bevel is ~8px; stretch the middle.
		box.texture_margin_left = 8
		box.texture_margin_right = 8
		box.texture_margin_top = 8
		box.texture_margin_bottom = 8
		box.set_content_margin_all(content_margin)
		return box
	return flat_panel(content_margin)


## The panel a player with NO imported art gets: the same light sandstone
## face, flat. Its own function so a test can read it without unskinning
## the process.
static func flat_panel(content_margin := 10.0) -> StyleBoxFlat:
	var flat := StyleBoxFlat.new()
	flat.bg_color = FACE
	flat.border_color = FACE_EDGE
	flat.set_border_width_all(2)
	flat.set_corner_radius_all(4)
	flat.set_content_margin_all(content_margin)
	return flat


## A TICK BOX, DRAWN, because the era shipped none. The 1997 dialogs have
## `button_normal/pressed/disabled` and nothing else — there is no
## checkbox sprite anywhere in `Cardart/` or `Winbk_*`, because the
## original expressed a switch as a LINE OF TEXT in a list that redrew
## with the state spelled out. That reads as plain text in a Godot
## dialog, which is what the 2026-09-04 playtest said of the Deck
## Builder's pause menu: *"only clickable text — make that GUI composed
## of buttons and of switches."*
##
## So the box is this project's, drawn in the ground's own palette:
## [constant FACE]'s lighter cousin for the well, [constant INK] for the
## rule around it, [constant ACCENT] for the tick — the same three
## colours every other lettered thing on sandstone already uses, so a
## switch cannot drift from the panel it sits on.
static func check_icon(on: bool) -> ImageTexture:
	var key := "on" if on else "off"
	if _check_icons.has(key):
		return _check_icons[key]
	var size := 18
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	# The well, then the rule around it.
	for y in range(1, size - 1):
		for x in range(1, size - 1):
			image.set_pixel(x, y, CHECK_WELL)
	for i in range(size):
		image.set_pixel(i, 0, INK)
		image.set_pixel(i, size - 1, INK)
		image.set_pixel(0, i, INK)
		image.set_pixel(size - 1, i, INK)
	if on:
		# Two strokes, three pixels thick — a tick, not a cross: the
		# short arm down to the corner, the long arm up to the right.
		_stroke(image, Vector2i(4, 9), Vector2i(7, 13))
		_stroke(image, Vector2i(7, 13), Vector2i(14, 4))
	var tex := ImageTexture.create_from_image(image)
	_check_icons[key] = tex
	return tex


## The well inside the tick box — [constant FACE] lifted, so the box
## reads as a recess in the sandstone rather than a patch on it.
const CHECK_WELL := Color8(222, 210, 184)

static var _check_icons := {}


## One three-pixel arm of the tick, clipped to the box's inside.
static func _stroke(image: Image, from: Vector2i, to: Vector2i) -> void:
	var steps := maxi(absi(to.x - from.x), absi(to.y - from.y))
	for step in range(steps + 1):
		var at := Vector2(from).lerp(Vector2(to), float(step) / float(steps))
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var x := int(round(at.x)) + dx
				var y := int(round(at.y)) + dy
				if x > 0 and y > 0 and x < image.get_width() - 1 \
						and y < image.get_height() - 1:
					image.set_pixel(x, y, ACCENT)


## Wrap [param inner] in a stone PanelContainer.
static func panel_around(inner: Control, content_margin := 10.0) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", stone_panel(content_margin))
	panel.add_child(inner)
	return panel


## A menu button dressed for the era (MagicMedieval when skinned).
##
## [param font_size] follows [param min_size] when a caller shrinks the
## button: 22pt letters in a 36pt-high button touch both rules of the
## frame, so the shell's column (which got smaller when it grew two more
## entries) passes its own size down.
## [param embolden] fakes a weight the era never shipped. `MagicMedieval`
## exists in exactly ONE cut — Regular, `usWeightClass` 400 — and there is
## no bold companion anywhere in the sources (all 28 `.ttf` files in
## `shandalar-src` checked, 2026-09-04), so a shell button that wants more
## presence cannot simply ask for one. [FontVariation] grows the outline
## instead of double-striking it, which is the difference between a
## heavier letter and a blurred one.
static func menu_button(label: String, min_size := Vector2(260, 46),
		font_size := 22, embolden := 0.0) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = min_size
	var face: Font = GameSkin.font("font_title")
	if face != null:
		if embolden > 0.0:
			var thick := FontVariation.new()
			thick.base_font = face
			thick.variation_embolden = embolden
			face = thick
		button.add_theme_font_override("font", face)
		button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_stylebox_override("normal", stone_panel(6.0))
	var hover := stone_panel(6.0)
	if hover is StyleBoxTexture:
		hover.modulate_color = Color(1.18, 1.15, 1.05)
	button.add_theme_stylebox_override("hover", hover)
	# A RING, NOT A FACE — see [method OriginalDialog.focus_ring]. An
	# opaque focus box paints over `pressed`, so a focused button could
	# not show that it had been pressed, which is the defect the pressed
	# state above exists to fix.
	button.add_theme_stylebox_override("focus", OriginalDialog.focus_ring())
	# PRESSED HAS TO LOOK PRESSED. It used to be the hover box — the same
	# lit stone — so a click on a shell button showed nothing at all, and
	# `hover_pressed` (what Godot draws while the cursor is ON a held
	# button) fell through to the default theme's grey. The original's own
	# button art darkens and inverts its bevel when depressed; this is
	# that, in the one move a modulate can make.
	var pressed := stone_panel(6.0)
	if pressed is StyleBoxTexture:
		pressed.modulate_color = Color(0.82, 0.80, 0.76)
	elif pressed is StyleBoxFlat:
		pressed.bg_color = FACE.darkened(0.18)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	shadowed_button(button)
	return button


## A TOGGLE THAT SAYS IT IS DOWN. Three same-faced buttons in a row
## (Hotseat / Duel the AI / AI Demo) and the default theme's `pressed`
## is the `normal` face a shade darker with the letters a shade whiter —
## "sometimes hard to see which button is selected" (the owner,
## 2026-09-17). The chosen one now wears a two-pixel ring of
## [constant CHOSEN] and letters of the same gold, on the face the theme
## already gives it; the others are untouched, so the row reads as one
## lit button among dark ones. Works on any [Button] in `toggle_mode` —
## the theme's own pressed box is duplicated and ringed, not replaced.
static func gold_when_chosen(button: Button) -> void:
	var face := button.get_theme_stylebox("pressed")
	var ring: StyleBoxFlat
	if face is StyleBoxFlat:
		ring = face.duplicate()
	else:
		# A skinned or missing face: the default theme's own depressed
		# charcoal, so the ring still has something dark to sit on.
		ring = StyleBoxFlat.new()
		ring.bg_color = Color(0, 0, 0, 0.6)
		ring.set_corner_radius_all(3)
		ring.set_content_margin_all(4)
	ring.border_color = CHOSEN
	ring.set_border_width_all(2)
	button.add_theme_stylebox_override("pressed", ring)
	button.add_theme_stylebox_override("hover_pressed", ring)
	button.add_theme_color_override("font_pressed_color", CHOSEN)
	button.add_theme_color_override("font_hover_pressed_color", CHOSEN)


## A modal EXPLANATION popup on the era's stone panel: a title, body text,
## and a single OK button that closes it. Returns the popup, already
## parented to [param host] and centred — the caller only has to keep
## going. Used by the Options screen, where clicking a rule's name opens
## the rule's own explanation.
##
## Built as a plain Control rather than an AcceptDialog: an OS window
## would open OUTSIDE the game's own frame, which is the defect the duel
## screen's dialogs were just fixed for.
static func explain_popup(host: Control, title: String, body: String,
		width := 470.0) -> Control:
	return action_popup(host, title, body, [
		{"label": "OK", "name": "OK"}
	], width)


## The same in-game modal with an action row. Each action is a Dictionary
## with `label`, optional `name`, `disabled`, `cancel` (the action Escape
## stands for on a screen that offers it, [method dismiss_popup]; a popup
## with one action needs none), and a zero-argument `callable`. The popup
## closes after any enabled action runs.
##
## THE RING STAYS ON IT AND COMES BACK (bug campaign 2026-10-12). The
## first enabled action takes the keyboard focus, and the row is FENCED:
## Left and Right walk it and wrap, Up and Down stay, Tab goes round it —
## the arrows used to walk the ring off the popup onto the buttons under
## the veil, and Enter then pressed a covered one. When the popup goes,
## the focus goes back to whatever held it before (hidden again if the
## mouse had given it) unless something new has taken it meanwhile — a
## popup that one of this one's actions opened.
static func action_popup(host: Control, title: String, body: String,
		actions: Array, width := 470.0) -> Control:
	var veil := Control.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP   # swallow clicks behind
	veil.z_index = 300
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.add_child(dim)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	var heading := body_label(title, 20)
	var title_font := GameSkin.font("font_title")
	if title_font != null:
		heading.add_theme_font_override("font", title_font)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)

	var text := body_label(body, 15)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = width - 60.0
	column.add_child(text)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var first: Button = null
	var live: Array[Button] = []
	var cancel: Button = null
	for action in actions:
		if not (action is Dictionary):
			continue
		var label := String(action.get("label", "OK"))
		var button := menu_button(label, Vector2(140, 38))
		button.name = String(action.get("name", label))
		button.disabled = bool(action.get("disabled", false))
		button.pressed.connect(_popup_action.bind(
			action.get("callable", Callable()), veil))
		row.add_child(button)
		if button.disabled:
			button.focus_mode = Control.FOCUS_NONE
		else:
			live.append(button)
		if bool(action.get("cancel", false)):
			cancel = button
		if first == null and not button.disabled:
			first = button
	if cancel == null and live.size() == 1:
		cancel = live[0]
	veil.set_meta(&"cancel_button", cancel)
	column.add_child(row)

	var panel := panel_around(column, 18.0)
	panel.custom_minimum_size.x = width
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	veil.add_child(panel)

	host.add_child(veil)
	veil.add_to_group(POPUP_GROUP)
	var viewport := host.get_viewport()
	var before: Control = viewport.gui_get_focus_owner() if viewport != null else null
	var hidden := before != null and not before.has_focus(true)
	if live.is_empty():
		# Nothing to press: the veil itself holds the ring, so it is not
		# left on a covered button either.
		veil.focus_mode = Control.FOCUS_ALL
		live.append(veil)
	_fence(live)
	(first if first != null else veil).grab_focus()
	veil.tree_exited.connect(_give_focus_back.bind(viewport,
		weakref(before) if before != null else null, hidden))
	return veil


## Every action popup's veil is in this group, so a screen whose Escape
## closes the one on top can find it ([method open_popup]).
const POPUP_GROUP := &"ui_chrome_popup"


## The popup most recently opened on [param host] and still up, or null.
static func open_popup(host: Node) -> Control:
	var found: Control = null
	for child in host.get_children():
		if child is Control and child.is_in_group(POPUP_GROUP) \
				and not child.is_queued_for_deletion():
			found = child
	return found


## Escape on a popup: its `cancel` action (or its only one) as if pressed,
## else it simply closes.
static func dismiss_popup(veil: Control) -> void:
	if not is_instance_valid(veil):
		return
	var cancel := veil.get_meta(&"cancel_button", null) as Button
	if cancel != null and is_instance_valid(cancel) and not cancel.disabled:
		cancel.pressed.emit()
	else:
		veil.queue_free()


## The ring goes round [param ring] and nowhere else.
static func _fence(ring: Array) -> void:
	var count := ring.size()
	for i in count:
		var here: Control = ring[i]
		var left: Control = ring[(i - 1 + count) % count]
		var right: Control = ring[(i + 1) % count]
		here.focus_neighbor_left = here.get_path_to(left)
		here.focus_neighbor_right = here.get_path_to(right)
		here.focus_neighbor_top = here.get_path_to(here)
		here.focus_neighbor_bottom = here.get_path_to(here)
		here.focus_previous = here.get_path_to(left)
		here.focus_next = here.get_path_to(right)


## The popup has gone: the focus back where it was, unless something has
## taken it since or the old holder has gone too.
static func _give_focus_back(viewport: Viewport, was: WeakRef, hidden: bool) -> void:
	if was == null or not is_instance_valid(viewport) or viewport.gui_get_focus_owner() != null:
		return
	var control := was.get_ref() as Control
	if control == null or not control.is_inside_tree() or not control.is_visible_in_tree() \
			or control.focus_mode == Control.FOCUS_NONE:
		return
	control.grab_focus(hidden)


static func _popup_action(callback: Callable, veil: Control) -> void:
	if callback.is_valid():
		callback.call()
	if is_instance_valid(veil):
		veil.queue_free()


## Text label in the body face — our Spectral for every player since
## 2026-10-15 ([method GameSkin.font]), in place of the era's MPlantin.
static func body_label(text: String, size := 14) -> Label:
	var label := Label.new()
	label.text = text
	var font := GameSkin.font("font_body")
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	shadowed(label)
	return label


## Menu lettering: [constant INK] with a pale one-pixel seat.
##
## This treatment was the inverse until 2026-09-03 — white letters with a
## hard black shadow, borrowed from the way [MiniCard] letters a card name
## over art (mini_card.gd:150-153). That is the right voice for a DARK
## ground and the wrong one here: every menu ground in this project is the
## original's sandstone (183/255 mean), and the first exported build was
## playtested with the report "all white text is unreadable on
## sand-colored menu boxes". See the class doc.
##
## The SEAT is what the black shadow used to be: menu text is a thin
## serif (MPlantin when this was written, our Spectral for every player
## since 2026-10-15), so the seat has to hold the glyph without eating its
## hairlines — a 1px outline and a 2px offset, now pale, which lifts dark
## letters off mottled stone the same way the dark one lifted pale ones
## off a dark ground.
static func shadowed(label: Control) -> void:
	label.add_theme_color_override("font_color", INK)
	label.add_theme_color_override("font_shadow_color", SEAT)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 1)


## The same treatment for a Button/CheckButton/OptionButton, which letter
## themselves through per-state colours rather than one font_color.
## A DISABLED control stays legible — dimmed, not dissolved into the
## stone — because a greyed rules fork still has to be readable enough to
## explain why it is greyed.
static func shadowed_button(button: Control) -> void:
	for state in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, INK)
	# Godot also fades a disabled control's whole draw, so this colour has
	# to start DARKER than feels right or the row washes out into the
	# stone — a greyed rules fork must still be readable enough to say
	# what it is and why it is off.
	button.add_theme_color_override("font_disabled_color", Color8(74, 66, 60))
	button.add_theme_color_override("font_shadow_color", SEAT)
	button.add_theme_constant_override("shadow_offset_x", 2)
	button.add_theme_constant_override("shadow_offset_y", 2)
	button.add_theme_constant_override("shadow_outline_size", 1)


## Have every stock tooltip in `tree` shaped by [method fit_tooltip] as it
## appears. Safe to call twice.
static func watch_tooltips(tree: SceneTree) -> void:
	if not tree.node_added.is_connected(fit_tooltip):
		tree.node_added.connect(fit_tooltip)


## The `node_added` hook: the engine's own tooltip label — a `TooltipLabel`
## with wrapping off, inside a `TooltipPanel` hung on the control it
## describes — gets wrapped to that control's viewport. Anything else,
## including a custom tooltip a control shaped for itself, passes through.
static func fit_tooltip(node: Node) -> void:
	var label := node as Label
	if label == null or label.theme_type_variation != &"TooltipLabel" \
			or label.autowrap_mode != TextServer.AUTOWRAP_OFF:
		return
	var popup := label.get_parent() as PopupPanel
	if popup == null or popup.theme_type_variation != &"TooltipPanel":
		return
	var holder := popup.get_parent() as Control
	if holder == null:
		return
	var panel := popup.get_theme_stylebox("panel")
	shape_tooltip(label, holder.get_viewport().get_visible_rect().size,
		label.get_theme_font("font"), label.get_theme_font_size("font_size"),
		label.get_theme_constant("line_spacing"), panel)
	# The popup measures itself from its children's minimum sizes, and a
	# Label's minimum HEIGHT is its text wrapped at the width it has NOW —
	# whatever the engine's default window left it with, not the column
	# just chosen. Give the popup that column first, so the measurement
	# reads the shaped text and the reserved height is the truth.
	popup.size = Vector2i((label.custom_minimum_size + panel.get_minimum_size()).ceil())


## Wrap a tooltip label to the viewport it will open in: a column of at
## most 420px; the full width when the text would otherwise run taller
## than the viewport; and, for a pathological text that still would, as
## many lines as fit, with an ellipsis. `font`, `font_size` and `spacing`
## are the label's own theme items, read by the caller because a label
## outside the tree cannot read them for itself; `panel` is the popup's
## stylebox, whose border comes off the room. The shaped column goes into
## the label's minimum size, so a popup placed BEFORE the label is laid
## out already knows it.
static func shape_tooltip(label: Label, viewport_size: Vector2, font: Font,
		font_size: int, spacing: int, panel: StyleBox) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Leave room for the popup's own border and a margin at both edges.
	var room := viewport_size - panel.get_minimum_size() - Vector2(32, 32)
	room = room.max(Vector2.ONE)
	var width := minf(420.0, room.x)
	# Label's final minimum height is not available before it enters
	# the tree. Shape with the same font and smart word wrapping now.
	var paragraph := TextParagraph.new()
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND \
		| TextServer.BREAK_ADAPTIVE
	paragraph.width = width
	# Label counts the empty rules line on vanilla cards. A zero-width
	# space makes TextParagraph count a trailing empty line as well.
	paragraph.add_string(label.text + "\u200b", font, font_size)
	var height := paragraph.get_size().y + paragraph.get_line_count() * spacing
	# Very long text gets a wider column before we ever shorten it.
	if height > room.y:
		width = room.x
		paragraph.width = width
		height = paragraph.get_size().y + paragraph.get_line_count() * spacing
	# An arbitrarily long imported proxy name must not grow off-screen
	# either. Ordinary text keeps every line; pathological text shows as
	# many lines as fit, and a Label's minimum height counts only the
	# lines it shows, so the popup cannot inflate past them.
	if height > room.y:
		var line_height := font.get_height(font_size) + spacing
		label.max_lines_visible = maxi(1, floori(room.y / line_height))
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		height = label.max_lines_visible * line_height
	label.custom_minimum_size = Vector2(width, ceilf(height))
	# A label outside the tree wraps at the width it has, and reads it
	# back as its minimum height the moment it is mounted: give it the
	# column. One inside is sized by its popup (see [method fit_tooltip]).
	if not label.is_inside_tree():
		label.size.x = width
