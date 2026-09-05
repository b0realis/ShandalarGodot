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

	var ok := menu_button("OK", Vector2(140, 38))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(ok)
	column.add_child(row)

	var panel := panel_around(column, 18.0)
	panel.custom_minimum_size.x = width
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	veil.add_child(panel)

	ok.pressed.connect(veil.queue_free)
	host.add_child(veil)
	ok.grab_focus()
	return veil


## Text label in the era's body font.
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
## The SEAT is what the black shadow used to be: menu text is MPlantin, a
## thin serif, so the seat has to hold the glyph without eating its
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
