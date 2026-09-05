class_name ArrangeButton
extends Button
## THE ARRANGE CONTROL — the toggle that straightens the table, and the
## first tenant of the sidebar's QoL reserve (`DuelScreen._qol_reserve`).
##
## THE COMMAND IS 1997's. `@MENU_TERRITORY`
## (`shandalar-src/Program/UIStrings.txt:908`) entries 15-16 are
## `Arrange your cards\tDblClk` / `Arrange opponent's cards\tDblClk`, and
## `Duel.hlp`, topic **Territory**, is the whole specification:
##
##   *"**Arrange Cards** straightens up the cards in play in the territory
##   where you right-clicked. This has no effect on the duel, it just makes
##   things neater."*
##
## Two things follow. It is ON DEMAND — the original sorts nothing by
## itself, and its hand window only scrolls (`Duel.hlp`, topic **Hands**)
## — and it is INERT, which is why this control may be a pure view switch
## with no engine call behind it.
##
## WHAT IS OURS. The original's arrange is a one-way command; ours is a
## TOGGLE, on the owner's design (2026-08-31): *"clicked would sort the
## table, unclick would return to previous state it was before sorting."*
## Untoggling restores the play order exactly, because the play order
## never went anywhere — see [method DuelScreen._display_order]. The 1997
## table ships no "unarrange" string, so this single control has to serve
## both ways, exactly as the Stops' `Mark this phase to always stop` does
## (`docs/duel-todo.md` §6.1).
##
## THE ICON is drawn here rather than imported: `Program/DuelArt/` has no
## arrange icon, because in 1997 the command lived in a text menu and had
## no icon to import. Three cards, askew when the toggle is off and
## squared up when it is on — the picture `Duel.hlp` describes in words.

## The button face, the icon inside it, and one card of the icon. Sized
## against `OriginalDialog.bar_button`'s 4px patch margin plus its 5px
## content margin, so the glyph never touches the stone's inner rule.
const FACE := Vector2(38, 30)
const GLYPH := Vector2i(24, 18)
const CARD_W := 6
const CARD_H := 12
const CARD_GAP := 3

## How far each card is knocked off the baseline when the table is NOT
## arranged, left to right. Fixed offsets — nothing on this icon is random.
const ASKEW: Array[int] = [3, -2, 4]

## Cache: `_glyphs[arranged]`.
static var _glyphs: Dictionary = {}


## The control, ready to add to the reserve strip. [param on_toggled] takes
## one bool.
static func create(on_toggled: Callable) -> ArrangeButton:
	var btn := ArrangeButton.new()
	btn.toggle_mode = true
	btn.custom_minimum_size = FACE
	btn.focus_mode = Control.FOCUS_NONE
	# The era's own stone, from the one place that chrome is defined. It
	# falls back to a flat button when the original skin is absent, which
	# is the same condition that leaves the whole table unskinned.
	OriginalDialog.dress_bar_button(btn)
	btn.icon = glyph(false)
	# `Arrange your cards`, verbatim — the table's own words for the
	# command, minus the `\tDblClk` accelerator, which is not our gesture.
	btn.tooltip_text = "Arrange your cards"
	btn.toggled.connect(btn._on_toggled)
	btn.toggled.connect(on_toggled)
	return btn


func _on_toggled(pressed: bool) -> void:
	icon = glyph(pressed)


## Show [param on] without firing `toggled`. The table-wide control reads
## back per-territory flags that the `@MENU_TERRITORY` entries can also
## set, so it has to be able to follow them without calling the handler
## that set them.
func set_arranged(on: bool) -> void:
	if button_pressed == on:
		return
	set_pressed_no_signal(on)
	icon = glyph(on)


## The icon: three cards, [param arranged] or askew. Cached per state.
static func glyph(arranged: bool) -> ImageTexture:
	if _glyphs.has(arranged):
		return _glyphs[arranged]
	var img := Image.create_empty(GLYPH.x, GLYPH.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var span := 3 * CARD_W + 2 * CARD_GAP
	var left := int((GLYPH.x - span) * 0.5)
	var base := int((GLYPH.y - CARD_H) * 0.5)
	for i in 3:
		var x0 := left + i * (CARD_W + CARD_GAP)
		var y0: int = base + (0 if arranged else ASKEW[i])
		for y in range(y0, y0 + CARD_H):
			if y < 0 or y >= GLYPH.y:
				continue
			for x in range(x0, x0 + CARD_W):
				var edge := x == x0 or x == x0 + CARD_W - 1 \
					or y == y0 or y == y0 + CARD_H - 1
				img.set_pixel(x, y, OriginalDialog.INK if edge
					else OriginalDialog.HIGHLIGHT)
	_glyphs[arranged] = ImageTexture.create_from_image(img)
	return _glyphs[arranged]
