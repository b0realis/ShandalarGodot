class_name NoAutoTapMark
extends RefCounted
## THE "DON'T AUTO TAP" MARK and the switch that shows it — `[ours]`, the
## owner's design of 2026-11-11: *"Under big cards lets have another button
## to show or hide don't autotap cards. If that button is pressed a
## circular right pointing arrow that is crossed with one red line icon is
## shown on the middle right of every minicard on your table that has dont
## auto-tap enabled."*
##
## THE MARK ITSELF IS 1997's: `Don't auto tap this card`, entry 4 of the
## small card's right-click menu (`@MENU_SMALLCARD`,
## [member DuelScreen._no_auto_tap]). In 1997 the only place it showed was
## the tick in that menu, so a player had to right-click every land to find
## the ones they had locked. This switch puts the mark on the table.
##
## THE PICTURE is the tap symbol — a clockwise circular arrow whose head
## points right across the top — on a pale disc that reads on any art,
## struck through with one red line. Drawn here rather than skinned (the
## era has no sprite for it), ONCE, as a texture: the small card
## ([method for_card]), the button ([method button], faded while the marks
## are hidden) and the Help page's icon row all show the same picture.
##
## THE SWITCH is a [Settings] key of ours ([constant SHOW_KEY], off), the
## reserve strip's fifth tenant ([member DuelScreen._qol_reserve]) under
## the large card, where the owner asked for it.

## The mark's size on a small card and on the button.
const SIZE := Vector2(22, 22)
## The texture is drawn at twice that and shown smaller, so the arrow and
## the line stay smooth on the 2x skin and in Help.
const PIXELS := 44
## Where it rides on [MiniCard]: hard against the right edge, centred top
## to bottom ("the middle right"), clear of the frame's inner rule.
const CARD_INSET := 5.0
## The disc, the arrow and the line.
const DISC := Color8(250, 244, 214, 240)
const INK := Color8(28, 24, 26)
const RED := Color8(214, 28, 22)
## The arrow's arc in degrees (screen angles: 0 is right, 90 is down, so
## an increasing angle turns CLOCKWISE). It starts at the upper right and
## runs round through the bottom to the top, where the head points RIGHT
## across the gap — clear of the red line, which runs top left to bottom
## right (the first drawing put the head at the upper left, under the
## line, and at 22px it read as a "C"; caught by looking, 2026-11-11).
const ARC_FROM := -30.0
const ARC_TO := 260.0

## The switch: shown or hidden marks, kept between duels.
const SHOW_KEY := "duel_show_no_auto_tap"
const SHOW_DEFAULT := false
## The button's words, both ways. The first also says how a card is marked,
## since the menu entry is the only door onto the mark itself.
const TIP_SHOW := "Show the cards marked Don't auto tap this card (right-click a card on your table to mark it)"
const TIP_HIDE := "Hide the Don't auto tap marks"
## The button face, matching [constant ArrangeButton.FACE].
const FACE := Vector2(38, 30)

## Cache: `_textures[faded]`.
static var _textures: Dictionary = {}


static func shown() -> bool:
	return bool(Settings.get_value(SHOW_KEY, SHOW_DEFAULT))


static func set_shown(on: bool) -> void:
	Settings.set_value(SHOW_KEY, on)


## The picture, [param faded] to half strength for the button at rest.
static func texture(faded := false) -> ImageTexture:
	if _textures.has(faded):
		return _textures[faded]
	var image := Image.create_empty(PIXELS, PIXELS, false, Image.FORMAT_RGBA8)
	var samples := 4
	for py in PIXELS:
		for px in PIXELS:
			var sum := Color(0, 0, 0, 0)
			for sy in samples:
				for sx in samples:
					# Unit coordinates: the disc's centre at 0, its edge at 1.
					var u := ((px + (sx + 0.5) / samples) / PIXELS) * 2.0 - 1.0
					var v := ((py + (sy + 0.5) / samples) / PIXELS) * 2.0 - 1.0
					var c := _ink_at(Vector2(u, v))
					# Premultiplied, so the edges average without a dark fringe.
					sum += Color(c.r * c.a, c.g * c.a, c.b * c.a, c.a)
			var n := float(samples * samples)
			var a := sum.a / n
			var out := Color(0, 0, 0, 0)
			if a > 0.0:
				out = Color(sum.r / n / a, sum.g / n / a, sum.b / n / a, a)
			if faded:
				out.a *= 0.5
			image.set_pixel(px, py, out)
	_textures[faded] = ImageTexture.create_from_image(image)
	return _textures[faded]


## What colour the picture is at unit point [param p], top layer first:
## the red line, the arrow's head and arc, the rim, the disc.
static func _ink_at(p: Vector2) -> Color:
	var d := p.length()
	if d > 0.97:
		return Color(0, 0, 0, 0)
	if _segment_distance(p, Vector2(-0.70, -0.70), Vector2(0.70, 0.70)) <= 0.085:
		return RED
	var to := deg_to_rad(ARC_TO)
	var end := Vector2(cos(to), sin(to)) * 0.5
	var ahead := Vector2(-sin(to), cos(to))   # the clockwise tangent
	var out := Vector2(cos(to), sin(to))      # away from the centre
	if Geometry2D.point_is_inside_triangle(p, end + ahead * 0.46,
			end + out * 0.31, end - out * 0.31):
		return INK
	if absf(d - 0.5) <= 0.08:
		var angle := rad_to_deg(atan2(p.y, p.x))
		# Walk the angle into [ARC_FROM, ARC_FROM + 360).
		while angle < ARC_FROM:
			angle += 360.0
		while angle >= ARC_FROM + 360.0:
			angle -= 360.0
		if angle <= ARC_TO:
			return INK
	if d > 0.86:
		return INK
	return DISC


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


## The mark on a small card, placed at its middle right.
static func for_card() -> TextureRect:
	var mark := _picture()
	mark.name = "NoAutoTapMark"
	mark.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	mark.offset_left = -(SIZE.x + CARD_INSET)
	mark.offset_right = -CARD_INSET
	mark.offset_top = -SIZE.y / 2.0
	mark.offset_bottom = SIZE.y / 2.0
	return mark


static func _picture(faded := false) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture(faded)
	rect.custom_minimum_size = SIZE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## The reserve strip's switch. [param on_toggled] takes one bool; the
## button writes [constant SHOW_KEY] itself, so the caller only redraws.
static func button(on_toggled: Callable) -> Button:
	var btn := Button.new()
	btn.name = "NoAutoTapButton"
	btn.toggle_mode = true
	btn.custom_minimum_size = FACE
	btn.focus_mode = Control.FOCUS_NONE
	OriginalDialog.dress_bar_button(btn)
	var glyph := _picture()
	glyph.name = "Glyph"
	glyph.set_anchors_preset(Control.PRESET_CENTER)
	glyph.offset_left = -SIZE.x / 2.0
	glyph.offset_right = SIZE.x / 2.0
	glyph.offset_top = -SIZE.y / 2.0
	glyph.offset_bottom = SIZE.y / 2.0
	btn.add_child(glyph)
	btn.set_pressed_no_signal(shown())
	_dress(btn)
	btn.toggled.connect(func(pressed: bool) -> void:
		set_shown(pressed)
		_dress(btn))
	btn.toggled.connect(on_toggled)
	return btn


static func _dress(btn: Button) -> void:
	var glyph := btn.get_node_or_null("Glyph") as TextureRect
	if glyph != null:
		glyph.texture = texture(not btn.button_pressed)
	btn.tooltip_text = TIP_HIDE if btn.button_pressed else TIP_SHOW
