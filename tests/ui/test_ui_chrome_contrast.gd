extends GutTest
## TEXT MUST CONTRAST WITH THE THING IT IS DRAWN ON.
##
## The menus wear the original's `Winbk_Options` sandstone panel, whose
## face measures **183/255 mean luminance** (PIL, 2026-09-03) — a LIGHT
## ground. Until that day every menu label and button was lettered in
## near-white with a black drop shadow, which is the voice for the DARK
## grounds (the duel's Situation Bar), and the first exported build was
## unreadable: the owner's playtest report was "all white text is
## unreadable on sand-colored menu boxes".
##
## The original's own rule is the one now followed here and in
## [OriginalDialog]: **dark ink on a light face**, pale ink on a dark one.
## These tests pin the pair to each other so the two halves cannot drift
## apart again — including the SKINLESS fallback, which used to be a
## near-black flat box and is now sandstone, so one text colour serves
## both grounds.

## Rec. 709 relative luminance, the WCAG contrast input.
func _luminance(c: Color) -> float:
	var parts := []
	for channel in [c.r, c.g, c.b]:
		parts.append(channel / 12.92 if channel <= 0.04045
			else pow((channel + 0.055) / 1.055, 2.4))
	return 0.2126 * parts[0] + 0.7152 * parts[1] + 0.0722 * parts[2]


func _contrast(a: Color, b: Color) -> float:
	var high := maxf(_luminance(a), _luminance(b))
	var low := minf(_luminance(a), _luminance(b))
	return (high + 0.05) / (low + 0.05)


func test_menu_ink_is_dark() -> void:
	assert_lt(_luminance(UiChrome.INK), 0.05, "menu text is dark ink")


func test_the_skinless_panel_is_a_light_face_like_the_originals() -> void:
	var flat := UiChrome.flat_panel(10.0)
	assert_gt(_luminance(flat.bg_color), 0.35,
		"a player with no imported art still gets a LIGHT panel, so the "
		+ "one ink colour reads on both grounds")


func test_ink_and_the_skinless_face_clear_the_wcag_bar() -> void:
	assert_gt(_contrast(UiChrome.INK, UiChrome.flat_panel().bg_color), 4.5)


func test_a_disabled_row_is_dimmed_but_still_dark_enough_to_read() -> void:
	var button := Button.new()
	UiChrome.shadowed_button(button)
	var disabled: Color = button.get_theme_color("font_disabled_color")
	assert_gt(_contrast(disabled, UiChrome.flat_panel().bg_color), 3.0,
		"a greyed rules fork still has to say why it is greyed")
	button.free()


func test_every_letter_state_of_a_menu_button_is_ink() -> void:
	var button := UiChrome.menu_button("Magic Battle")
	for state in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color"]:
		assert_lt(_luminance(button.get_theme_color(state)), 0.05, state)
	button.free()


func test_a_label_gets_the_same_ink_and_a_pale_seat_not_a_black_one() -> void:
	var label := Label.new()
	UiChrome.shadowed(label)
	assert_eq(label.get_theme_color("font_color"), UiChrome.INK)
	assert_gt(_luminance(label.get_theme_color("font_shadow_color")), 0.5,
		"the seat under dark ink is PALE — a black shadow under black "
		+ "letters only fattens them")
	label.free()


## A PRESS HAS TO BE VISIBLE WHILE THE CURSOR IS STILL ON THE BUTTON.
##
## Godot draws `hover_pressed` for a button held down with the pointer on
## it, and falls back to the DEFAULT theme's box when nobody overrides it
## — so a fully dressed 1997 button showed a grey default while held and
## only snapped to its depressed art once the pointer left. The
## 2026-09-03 playtest called it: "the button press animations should be
## immediate (now nothing happens under the cursor — button reads pressed
## only when the cursor is moved away)".
func test_a_menu_button_has_a_pressed_look_that_is_not_its_hover_look() -> void:
	var button := UiChrome.menu_button("Magic Battle")
	var pressed := button.get_theme_stylebox("pressed")
	var hover := button.get_theme_stylebox("hover")
	assert_ne(pressed, hover, "pressing must not look like hovering")
	assert_eq(button.get_theme_stylebox("hover_pressed"), pressed,
		"and held-under-the-cursor is the same picture as held")
	button.free()


func test_every_era_button_answers_the_cursor_that_is_still_on_it() -> void:
	for button in [OriginalDialog.button("Done", Vector2(80, 30)),
			OriginalDialog.dress_bar_button(Button.new())]:
		assert_true(button.has_theme_stylebox_override("hover_pressed"),
			"a held button draws its own art, not the default theme's")
		assert_eq(button.get_theme_stylebox("hover_pressed"),
			button.get_theme_stylebox("pressed"))
		button.free()


func test_focus_does_not_paint_over_the_press() -> void:
	# Godot draws `focus` ON TOP of the draw-mode box, so an opaque focus
	# stylebox hides `pressed` and `hover_pressed` — undoing the fix above
	# for every button that has focus, and `explain_popup` focuses its OK
	# button as it opens. Measured by the Deck Builder pass, 2026-09-03.
	var button := UiChrome.menu_button("Go!")
	var focus: StyleBox = button.get_theme_stylebox("focus")
	assert_true(focus is StyleBoxFlat, "a ring, not a face")
	assert_false((focus as StyleBoxFlat).draw_center,
		"it must not fill, or it covers whatever is under it")
	assert_ne(focus, button.get_theme_stylebox("pressed"))
	button.free()
	for era in [OriginalDialog.button("Done", Vector2(80, 30)),
			OriginalDialog.dress_bar_button(Button.new())]:
		var ring: StyleBox = era.get_theme_stylebox("focus")
		assert_true(ring is StyleBoxFlat and not (ring as StyleBoxFlat).draw_center,
			"the era buttons wear the same ring")
		era.free()
