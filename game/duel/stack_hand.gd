class_name StackHand
extends Control
## The MicroProse hand window: the original's own Hand_<colour> chrome
## wrapped around a CardPile (full card faces offset so each shows its name
## band, last card fully visible — the owner's reference screenshots /
## s30's drawHandPanel).
##
## THE CHROME IS ONE CONTINUOUS PIECE, as it is in the original: the
## patterned deck-coloured border runs unbroken down both sides from the
## title bar to the foot of the list, with the speckled title bar sitting
## INSIDE it at the top. That is a NINE-PATCH of the imported
## hand_panel_<colour> texture (see [method window_texture] for the
## measured geometry), NOT a title strip with a separate box under it.
##
## The ▲ end of the bar COLLAPSES the pile to bands only (s30's
## handCollapsed "[+]"), the ▼ end expands it — and so does a click
## anywhere else on the header that does not become a drag, or the `H`
## key (§3.6). The window drags by the middle of its title bar; position
## persists (Settings "hand_stack_pos").
##
## SIMPLIFIED: the ▲/▼ painted into the 1997 sheet are SCROLL arrows, not
## a fold. `Duel.hlp`, topic **Hands**: *"Each window has a maximum size.
## If there are too many cards in your hand to display all at once, use
## the scroll arrows at the top to see the rest. This is a **revolving**
## scroll, which means that the top cards cycle to the bottom."* Our pile
## has no maximum size and simply grows, so there is nothing to scroll
## past; the fold is s30's idea and borrows the zones until the revolving
## scroll exists. Ledgered in `docs/ROADMAP.md`.

# ---------------------------------------------------------------- geometry --
# Measured off assets/original/hand_panel_red.png (the 1997 Hand_Red.pic,
# 145x51 — s30 loads the same file as its handBg):
#   rows   0..6    patterned border
#   rows   7..28   grey speckled title bar; ▲ at x 1..9, ▼ at x 125..132
#   rows  29..35   patterned band under the bar
#   rows  36..43   ONE tan list row — the stretchable middle
#   rows  44..50   patterned foot
#   cols 134..140  patterned right border, cols 141..144 outer stone
# All five colours share that layout exactly.

## Side thickness of the window frame (7px pattern + 4px outer stone).
const BORDER := 11.0
## The whole top cap — border + title bar + the band beneath it. Drawn
## UNSTRETCHED by the nine-patch, so the bar keeps its 1997 proportions.
const TITLE_HEIGHT := 36.0
## The speckled bar itself, inside that cap: the drag handle and the
## ▲/▼ hit zones.
const BAR_TOP := 7.0
const BAR_HEIGHT := 22.0
## The patterned foot under the list.
const FOOT := 7.0
## The window is exactly its cards plus the frame, so the border is never
## covered by a row and the rows never spill past it.
const WIDTH := CardPile.WIDTH + 2.0 * BORDER
## Bar ends reserved for the ▲ (left, collapse) / ▼ (right, expand) hit
## zones — the border plus the arrow painted on the Hand_* texture.
const ARROW_ZONE := 22.0

## Sampled from the OUTER EDGE of each original Hand_<colour>.pic — the
## window's actual frame colour, used only when the 1997 skin is absent.
## (Sampling the bar's interior gave the shared tan chrome, which is why
## white looked wrong before.)
const DECK_BORDERS := {
	"white": Color8(110, 110, 112), "blue": Color8(20, 47, 109),
	"black": Color8(67, 67, 67), "red": Color8(155, 36, 28),
	"green": Color8(28, 28, 28),
}

## The shared enlarged-card preview (owned by the DuelScreen, docked).
var preview: CardPreview = null:
	set(value):
		preview = value
		_pile.preview = value

var _pile: CardPile
var _frame: NinePatchRect
var _fallback: Panel
var _frame_box: StyleBoxFlat
var _title: Label
var _title_bg: Control
var _dragging := false
var _drag_offset := Vector2.ZERO
## Where the press landed, and whether the pointer has since travelled far
## enough for the gesture to be a drag rather than a header click (§3.6).
var _drag_from := Vector2.ZERO
var _drag_moved := false
# Last populate arguments, replayed on collapse/expand.
var _hand: Array = []
var _hidden := false
var _click_cb: Callable
var _highlight_cb: Callable


func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, TITLE_HEIGHT + FOOT)
	z_index = 60   # floats above the board rows

	# The 1997 window, nine-patched so the pattern wraps the WHOLE window.
	_frame = NinePatchRect.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.patch_margin_left = int(BORDER)
	_frame.patch_margin_right = int(BORDER)
	_frame.patch_margin_top = int(TITLE_HEIGHT)
	_frame.patch_margin_bottom = int(FOOT)
	# The stretchable parts are the tan list row and the side borders: TILE
	# them so the stone speckle and the border pattern repeat at their own
	# scale instead of smearing over a tall window.
	_frame.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)

	# No 1997 skin: a plain frame in the deck's colour, same proportions.
	_fallback = Panel.new()
	_fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame_box = StyleBoxFlat.new()
	_frame_box.bg_color = Color(0.12, 0.10, 0.08, 0.96)
	_frame_box.border_color = Color(0.45, 0.38, 0.24)
	_frame_box.set_border_width_all(int(BORDER * 0.5))
	_fallback.add_theme_stylebox_override("panel", _frame_box)
	add_child(_fallback)
	# Until a deck colour picks a texture, the flat frame is what shows.
	_frame.visible = false

	# The speckled bar: drag handle in the middle, ▲/▼ at the ends. It is
	# TRANSPARENT — the painted bar comes from the frame behind it.
	_title_bg = Control.new()
	_title_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title_bg.offset_top = BAR_TOP
	_title_bg.offset_bottom = BAR_TOP + BAR_HEIGHT
	_title_bg.gui_input.connect(_on_title_input)
	_title_bg.mouse_default_cursor_shape = Control.CURSOR_MOVE
	add_child(_title_bg)
	_title = bar_label("Your hand")
	_title_bg.add_child(_title)

	_pile = CardPile.new()
	_pile.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_pile.offset_top = TITLE_HEIGHT
	_pile.offset_left = BORDER
	_pile.offset_right = -BORDER
	add_child(_pile)


## The window wears the DECK's dominant colour — the reference frames the
## hand in the player's colour (Hand_<colour> chrome all round).
func set_deck_color(color_name: String) -> void:
	if _frame_box != null:
		_frame_box.border_color = DECK_BORDERS.get(color_name,
			Color(0.55, 0.45, 0.30))
	var tex := window_texture(color_name)
	_frame.texture = tex
	_frame.visible = tex != null
	_fallback.visible = tex == null


## THE TEXT ON THE SPECKLED BAR, laid out once for both windows — the
## player's own and the opponent's title plate. LIGHT GREY, as the
## original's bar reads (not the yellow an earlier pass used: that yellow
## belongs to CASTABLE CARD NAMES, and having both wear it made the title
## look like a card row), left-aligned just past the ▲ exactly as s30
## places it (`duel.go`: `elements.NewText(16, label, dp.handX+15,
## dp.handY+13)`), and trimmed rather than shrunk when it will not fit.
static func bar_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.94, 0.93, 0.90))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_constant_override("shadow_outline_size", 2)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = ARROW_ZONE + 2.0
	label.offset_right = -(ARROW_ZONE - 4.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## THE OPPONENT'S HAND — **THIS WINDOW WITH NO LIST UNDER IT**.
##
## Manual p.114: *"Only the title bar of your opponent's hand is visible;
## this is to keep you aware of how many cards are in that hand."* So it is
## not a chip, a bar or a badge: it is the SAME window as the player's own,
## drawn at its empty height (the top cap plus the foot), from the SAME
## `hand_panel_<colour>` nine-patch with the SAME patch margins, the SAME
## tiled vertical axis and the SAME label placement. Anything else and the
## two hands stop reading as one object.
##
## **WHAT THIS FIXES (the fortieth pass).** The duel screen used to build
## the opponent's counter as a `Button` with the raw 145x51 sheet as a
## plain `StyleBoxTexture` and `custom_minimum_size` of 150x22. A
## `StyleBoxTexture` with no patch margins SCALES, so the whole window —
## border, speckled bar, and the ▲ / ▼ **painted into the sheet at x 1..9
## and x 125..132** — was squashed into a strip less than half its height
## and its left arrow was crushed against the edge. That is the "opponent
## hand stack is cropped at left end" the owner reported.
##
## **AND THE ARROWS ARE THE TEXTURE'S, NOT THE LABEL'S.** The old chip drew
## `↑ Opponent (5) ↓` over a sheet that already paints both arrows, so each
## one appeared twice. The sheet's pair is the original's own, so the sheet
## keeps them and the text drops them — s30 does exactly this
## (`drawHandPanel`: the label is `Opp Hand (%d)`, no arrows, over the same
## untouched `handBg`).
##
## The WORDING is the original's: `@WINDOWTITLES` (`UIStrings.txt:155`)
## gives this window the single word **`Opponent`** — s30's `Opp Hand` is
## s30's, and `docs/duel-todo.md` §9.1 has had it listed as wrong since the
## thirty-fourth pass. The count stays, in the bracket form the player's
## own `Your hand (N)` already uses, because the count is the entire reason
## the manual gives for showing this bar at all.
static func title_plate(color_name: String, text: String) -> Control:
	var plate := Control.new()
	plate.custom_minimum_size = Vector2(WIDTH, TITLE_HEIGHT + FOOT)
	# Never stretched by the row it sits in — the window has one size, the
	# same rule the cards follow (MiniCard._init).
	plate.size_flags_horizontal = Control.SIZE_SHRINK_END
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := window_texture(color_name)
	if tex != null:
		var frame := NinePatchRect.new()
		frame.texture = tex
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.patch_margin_left = int(BORDER)
		frame.patch_margin_right = int(BORDER)
		frame.patch_margin_top = int(TITLE_HEIGHT)
		frame.patch_margin_bottom = int(FOOT)
		frame.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_child(frame)
	else:
		# No 1997 skin: the player's own flat frame, same proportions.
		var fallback := Panel.new()
		fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.12, 0.10, 0.08, 0.96)
		box.border_color = DECK_BORDERS.get(color_name, Color(0.55, 0.45, 0.30))
		box.set_border_width_all(int(BORDER * 0.5))
		fallback.add_theme_stylebox_override("panel", box)
		plate.add_child(fallback)
	var bar := Control.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_top = BAR_TOP
	bar.offset_bottom = BAR_TOP + BAR_HEIGHT
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(bar_label(text))
	plate.add_child(bar)
	return plate


## The original's Hand_<colour>.pic MADE WHOLE, ready to nine-patch.
##
## The 1997 file carries the window's top-left three quarters: the top
## border, the speckled title bar with its ▲/▼, the band under it, ONE list
## row, the foot — and, at x 134..144, the right border and the outer
## stone. It has NO left border (the file starts flush against the title
## bar), so the 11 right-hand columns are MIRRORED onto the left. The
## result is a symmetric 156x51 window that nine-patches to any height with
## the pattern unbroken down both sides. Cached per colour.
static var _window_cache: Dictionary = {}

static func window_texture(color_name: String) -> Texture2D:
	if _window_cache.has(color_name):
		return _window_cache[color_name]
	var result: Texture2D = null
	var source := GameSkin.texture("hand_panel_" + color_name)
	if source != null:
		var src := source.get_image()
		src.convert(Image.FORMAT_RGBA8)
		var edge := int(BORDER)
		var w := src.get_width()
		var h := src.get_height()
		var mirror := src.get_region(Rect2i(w - edge, 0, edge, h))
		mirror.flip_x()
		var whole := Image.create_empty(w + edge, h, false, Image.FORMAT_RGBA8)
		whole.blit_rect(mirror, Rect2i(0, 0, edge, h), Vector2i.ZERO)
		whole.blit_rect(src, Rect2i(0, 0, w, h), Vector2i(edge, 0))
		result = ImageTexture.create_from_image(whole)
	_window_cache[color_name] = result
	return result


## Rebuild from the hand (see CardPile.populate for the callbacks).
func populate(hand: Array, hidden: bool, click_cb: Callable,
		highlight_cb: Callable) -> void:
	_hand = hand.duplicate()
	_hidden = hidden
	_click_cb = click_cb
	_highlight_cb = highlight_cb
	var suffix := " [+]" if _pile.collapsed else ""   # s30's collapsed marker
	_title.text = "Your hand (%d)%s" % [hand.size(), suffix]
	_pile.populate(hand, hidden, click_cb, highlight_cb)
	custom_minimum_size = Vector2(WIDTH,
		TITLE_HEIGHT + _pile.pile_height(hand.size(), hidden) + FOOT)
	size = custom_minimum_size
	_clamp_on_screen()


# ------------------------------------------- title bar: drag & collapse --

func _on_title_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Bar ends toggle the pile (the painted ▲/▼ arrows); the
			# middle is the drag handle.
			var local_x: float = event.position.x
			if local_x < ARROW_ZONE:
				_set_collapsed(true)
				return
			if local_x > _title_bg.size.x - ARROW_ZONE:
				_set_collapsed(false)
				return
			_dragging = true
			_drag_moved = false
			_drag_from = get_global_mouse_position()
			_drag_offset = _drag_from - global_position
		else:
			if _dragging:
				# A PRESS THAT NEVER BECAME A DRAG IS A CLICK (§3.6), and
				# a click on the header toggles the hand. Both gestures
				# live on the same pixels because both references put them
				# there: `Duel.hlp`, topic **Hands**, is explicit that this
				# bar is the drag handle — *"To move a hand window, click
				# and drag on the bar at the top of the window"* — and s30
				# binds a plain click on the whole header to
				# `toggleHand()` (`duel.go:1681-1686`), having no drag of
				# its own to protect. Telling them apart by MOVEMENT keeps
				# the 1997 gesture intact and costs the s30 one nothing.
				if _drag_moved:
					Settings.set_value("hand_stack_pos", position)
				else:
					toggle_collapsed()
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		# DRAG_SLOP, not "any motion at all": a mouse moves a pixel or two
		# under the finger during an ordinary click, and without the
		# threshold every header click would be read as a one-pixel drag
		# and toggle nothing.
		if get_global_mouse_position().distance_to(_drag_from) > DRAG_SLOP:
			_drag_moved = true
		# THE SLOP GATES THE MOVEMENT, not just the flag. It used to gate
		# only `_drag_moved`, so the pixel or two a mouse travels under
		# the finger during a click nudged the window — and the release
		# branch above, seeing `_drag_moved == false`, then toggled the
		# hand and never saved the new corner. The window drifted on every
		# header click and snapped back next duel.
		if not _drag_moved:
			return
		global_position = get_global_mouse_position() - _drag_offset
		_clamp_on_screen()


## How far the pointer must travel between press and release before the
## gesture counts as a DRAG rather than a click on the header.
const DRAG_SLOP := 3.0


## Is the card list hidden? (The header bar always stays.)
func is_collapsed() -> bool:
	return _pile.collapsed


## Fold the list away, or unfold it — s30's `toggleHand`
## (`duel.go:1673-1677`): *"Collapsing hides the hand card list so it no
## longer covers the player's attackers during combat, while the header
## bar stays visible so the hand can be expanded again."* That is the
## whole reason the control exists, and it is why §3.6 wanted it on a KEY:
## the moment you need it is the moment your own attackers are underneath
## it, mid-declaration, with the pointer busy picking creatures.
func toggle_collapsed() -> void:
	_set_collapsed(not _pile.collapsed)


func _set_collapsed(value: bool) -> void:
	if _pile.collapsed == value:
		return
	_pile.collapsed = value
	populate(_hand, _hidden, _click_cb, _highlight_cb)


func _clamp_on_screen() -> void:
	if get_parent() == null:
		return
	var view := get_viewport_rect().size
	position.x = clampf(position.x, 0.0, maxf(0.0, view.x - size.x))
	position.y = clampf(position.y, 0.0, maxf(0.0, view.y - TITLE_HEIGHT))
