class_name ExpandButton
extends Button
## The Showcase's `Expand` toggle, as a control you can see.
##
## THE FEATURE IS THE ORIGINAL'S; ONLY THE DOOR IS OURS. `Duel.hlp`,
## topic **Showcase**: *"If the whole text of a card does not fit into the
## text area of the Showcase, you can fix that. Right-click on the text
## area, then click on the **Expand** toggle. This causes the text area to
## grow, when necessary, to display the entire card text."* That is
## `@MENU_FULLCARD` entry 1 and the setting the 1997 executable calls
## `ExpandTextBoxOnBigCard`, both of which this project already had.
##
## What it did not have was a door anybody finds. The 2026-09-05 playtest
## reported the SYMPTOM — long card text clipping — rather than the cause,
## which is exactly what happens when a fix is hidden behind a right-click
## on an unmarked region. `[QoL]`: the button is ours, the behaviour is
## 1997's, and both doors write the same key so they cannot disagree.
##
## THE GLYPH is the card's text box with arrows leaving it top and bottom
## — the box growing, which is the one thing the toggle does. Drawn rather
## than skinned because the era has no sprite for it: its own menu entry
## was a line of text in a popup, and there is no icon to port.

## The button face, matching [constant ArrangeButton.FACE] exactly — the
## two sit in one column under the large card and a column of differing
## widths reads as a mistake.
const FACE := Vector2(38, 30)
## The drawn glyph inside it.
const GLYPH := Vector2i(24, 18)
## The text box: full width, sitting low in the glyph the way a card's
## rules box sits low on a card.
const BOX := Rect2i(2, 9, 20, 7)
## Ink and its pale seat, the pair every drawn control here uses.
const INK := Color8(28, 24, 26)
const LIT := Color8(250, 244, 214)


static func create(on_toggled: Callable) -> ExpandButton:
	var btn := ExpandButton.new()
	btn.toggle_mode = true
	btn.custom_minimum_size = FACE
	btn.focus_mode = Control.FOCUS_NONE
	# The same stone as its neighbour, from the one place chrome is
	# defined; falls back to a flat button with no skin imported.
	OriginalDialog.dress_bar_button(btn)
	btn.button_pressed = CardPreview.expand_wanted()
	btn.icon = glyph(btn.button_pressed)
	btn.tooltip_text = "Expand the card's text box when the text does not fit"
	btn.toggled.connect(btn._on_toggled)
	btn.toggled.connect(on_toggled)
	return btn


func _on_toggled(pressed: bool) -> void:
	icon = glyph(pressed)
	tooltip_text = "Expand the card's text box when the text does not fit" \
		if not pressed else "Show the card's text box at its 1997 size"


## Follow the setting without firing `toggled` — the duel's
## `@MENU_FULLCARD` entry writes the same key, and this button has to be
## able to show what that did.
func set_expanded(on: bool) -> void:
	if button_pressed == on:
		return
	set_pressed_no_signal(on)
	icon = glyph(on)


## The box, and — when [param on] — the arrows that grow it.
static func glyph(on: bool) -> ImageTexture:
	var image := Image.create_empty(GLYPH.x, GLYPH.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var top := BOX.position.y if not on else 4
	# The box outline: pale fill, ink rule, so it reads as a text plate.
	for y in range(top, BOX.end.y):
		for x in range(BOX.position.x, BOX.end.x):
			var edge := y == top or y == BOX.end.y - 1 \
				or x == BOX.position.x or x == BOX.end.x - 1
			image.set_pixel(x, y, INK if edge else LIT)
	if on:
		# Grown: two ruled lines inside, showing text the box now holds.
		for y in [top + 3, top + 6, top + 9]:
			if y < BOX.end.y - 2:
				for x in range(BOX.position.x + 2, BOX.end.x - 2):
					image.set_pixel(x, y, INK)
	else:
		# Unexpanded: an arrow above the box pointing UP — the direction
		# the box grows, since a card's rules plate already runs to the
		# bottom border and there is nowhere else for it to go. The apex
		# is the NARROW end, so it belongs at the top: writing it the
		# other way round drew a tidy arrow pointing at the box instead
		# of away from it (caught by looking, 2026-09-05).
		for i in range(4):
			for x in range(GLYPH.x / 2 - i, GLYPH.x / 2 + i + 1):
				var y := 2 + i
				if y >= 0 and y < top:
					image.set_pixel(x, y, INK)
	return ImageTexture.create_from_image(image)
