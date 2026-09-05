extends GutTest
## OriginalDialog — the 1997 popup chrome (game/duel/original_dialog.gd).
##
## Like test_skin.gd these pass in BOTH states of the world: with the 1997
## art imported and without it. The measured facts about the ART itself
## are asserted only when the skin is present — they are the numbers the
## component is built on, so they must not drift silently when someone
## re-imports from a different copy of the game.


func _skinned() -> bool:
	return GameSkin.texture("button_normal") != null


# ----------------------------------------------------- the art, measured --

func test_button_art_is_the_1997_three_state_set() -> void:
	if not _skinned():
		pass_test("no original skin imported")
		return
	for key in ["button_normal", "button_pressed", "button_disabled"]:
		var tex := GameSkin.texture(key)
		assert_not_null(tex, key)
		assert_eq(Vector2i(tex.get_size()), Vector2i(131, 36), key)


func test_button_art_carries_the_double_rule() -> void:
	# The era's button frame, measured on Winbk_Startduelbuttonnormal:
	# 2px HIGHLIGHT top/left, 2px SHADOW bottom/right, 3px of face, then
	# the SAME pair again at 5-6px in. A 9-patch of BUTTON_MARGIN keeps
	# both rules, so the margin must stay wider than the outer rule pair.
	if not _skinned():
		pass_test("no original skin imported")
		return
	var img := GameSkin.texture("button_normal").get_image()
	assert_eq(img.get_pixel(65, 0), OriginalDialog.HIGHLIGHT, "outer top rule")
	assert_eq(img.get_pixel(65, 5), OriginalDialog.HIGHLIGHT, "inner top rule")
	assert_eq(img.get_pixel(65, 35), OriginalDialog.SHADOW, "outer bottom rule")
	assert_eq(img.get_pixel(65, 30), OriginalDialog.SHADOW, "inner bottom rule")
	assert_eq(img.get_pixel(0, 18), OriginalDialog.HIGHLIGHT, "outer left rule")
	assert_eq(img.get_pixel(130, 18), OriginalDialog.SHADOW, "outer right rule")
	assert_gt(OriginalDialog.BUTTON_MARGIN, 6, "margin must clear both rules")


func test_pressed_art_inverts_both_rules() -> void:
	if not _skinned():
		pass_test("no original skin imported")
		return
	var img := GameSkin.texture("button_pressed").get_image()
	assert_eq(img.get_pixel(65, 0), OriginalDialog.SHADOW, "pressed sinks the top")
	assert_eq(img.get_pixel(65, 35), OriginalDialog.HIGHLIGHT, "and lifts the foot")


func test_every_named_panel_is_imported_at_its_measured_size() -> void:
	if not GameSkin.texture("panel_stone"):
		pass_test("no original skin imported")
		return
	var sizes := {
		"panel_stone": Vector2i(400, 350),
		"panel_dark_stone": Vector2i(289, 274),
		"panel_knot": Vector2i(481, 323),
		"panel_end_duel": Vector2i(272, 422),
		"big_card_panel": Vector2i(552, 402),
		"message_panel": Vector2i(600, 35),
	}
	for key in sizes:
		var tex := GameSkin.texture(key)
		assert_not_null(tex, key)
		if tex != null:
			assert_eq(Vector2i(tex.get_size()), sizes[key], key)
		assert_true(OriginalDialog.PANELS.has(key),
			"%s needs a measured PANELS row" % key)


# ---------------------------------------------------------- the frame --

func test_frame_uses_each_grounds_own_measured_bevel() -> void:
	if not GameSkin.texture("panel_dark_stone"):
		pass_test("no original skin imported")
		return
	for key in OriginalDialog.PANELS:
		var patch := OriginalDialog.frame(key)
		assert_not_null(patch, key)
		var want: int = OriginalDialog.PANELS[key]["margin"]
		assert_eq(patch.patch_margin_left, want, key)
		assert_eq(patch.patch_margin_bottom, want, key)
		patch.free()


func test_only_a_ground_wider_than_its_window_may_tile() -> void:
	if not GameSkin.texture("big_card_panel"):
		pass_test("no original skin imported")
		return
	# A dialog ground can be smaller than the dialog, and a second tile
	# would show its join — no 1997 window has a seam. Only the Situation
	# Bar, which is never as wide as its own 600px stone, lays one tile.
	for key in OriginalDialog.PANELS:
		var patch := OriginalDialog.frame(key)
		var want := NinePatchRect.AXIS_STRETCH_MODE_TILE \
			if key == "message_panel" else NinePatchRect.AXIS_STRETCH_MODE_STRETCH
		assert_eq(patch.axis_stretch_horizontal, want, key)
		patch.free()


func test_panel_style_falls_back_without_crashing() -> void:
	var box := OriginalDialog.panel_style("no_such_ground", 7.0)
	assert_not_null(box)
	assert_eq(box.content_margin_left, 7.0)


# ------------------------------------------------- the Situation Bar rule --

func test_bar_texture_rules_the_borderless_stone() -> void:
	# Winbk_Telluser has NO frame of its own (every edge row is plain
	# texture), so the bar draws one — and the rule it draws is the ART'S,
	# measured on `Winbk_Startduelbutton` (assets/original/button_normal.png,
	# 131x36): rows 0 AND 1 pure HIGHLIGHT right across the top, columns 0
	# and 1 down the left, the last two rows and columns pure SHADOW, and
	# NO black outline anywhere.
	#
	# THE OWNER'S PLAYTEST, 2026-09-03: *"In the central message I am
	# missing the lighter border."* It was a single pale pixel two in from
	# a 1px black outline — a hairline on a dark board, and not what any
	# 1997 ground does.
	if GameSkin.texture("message_panel") == null:
		pass_test("no original skin imported")
		return
	var tex := OriginalDialog.bar_texture()
	assert_not_null(tex)
	var img := tex.get_image()
	var h := img.get_height()
	var w := img.get_width()
	assert_eq(OriginalDialog.RULE_WIDTH, 2, "two pixels, as the art draws it")
	for i in OriginalDialog.RULE_WIDTH:
		assert_eq(img.get_pixel(40, i), OriginalDialog.HIGHLIGHT,
			"row %d of the top rule is pale" % i)
		assert_eq(img.get_pixel(i, 10), OriginalDialog.HIGHLIGHT,
			"column %d of the left rule is pale" % i)
		assert_eq(img.get_pixel(40, h - 1 - i), OriginalDialog.SHADOW,
			"row %d from the foot is slate" % i)
		assert_eq(img.get_pixel(w - 1 - i, 10), OriginalDialog.SHADOW,
			"column %d from the right is slate" % i)
	assert_ne(img.get_pixel(40, OriginalDialog.RULE_WIDTH),
		OriginalDialog.HIGHLIGHT, "and the rule stops at two")


func test_the_rule_is_mitred_the_way_the_button_art_is() -> void:
	# The art steps the pale band down one pixel per column into the slate
	# one at the top-right (x=w-1 is slate at y=0 while x=w-2 is still
	# pale; at y=1 both are slate), and mirrors it at the bottom-left.
	if GameSkin.texture("message_panel") == null:
		pass_test("no original skin imported")
		return
	var img := OriginalDialog.bar_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	assert_eq(img.get_pixel(w - 1, 0), OriginalDialog.SHADOW)
	assert_eq(img.get_pixel(w - 2, 0), OriginalDialog.HIGHLIGHT)
	assert_eq(img.get_pixel(w - 2, 1), OriginalDialog.SHADOW)
	assert_eq(img.get_pixel(0, h - 1), OriginalDialog.SHADOW)
	assert_eq(img.get_pixel(0, h - 2), OriginalDialog.HIGHLIGHT)


func test_bar_texture_leaves_the_stone_between_the_rules() -> void:
	if GameSkin.texture("message_panel") == null:
		pass_test("no original skin imported")
		return
	var ruled := OriginalDialog.bar_texture().get_image()
	var raw := GameSkin.texture("message_panel").get_image()
	assert_eq(ruled.get_pixel(300, 17), raw.get_pixel(300, 17),
		"the middle of the bar is untouched original stone")


func test_bar_style_survives_a_missing_skin() -> void:
	var box := OriginalDialog.bar_style(5.0)
	assert_not_null(box)
	assert_eq(box.content_margin_top, 5.0)


# --------------------------------------------------------- the button --

func test_button_wears_a_distinct_style_per_state() -> void:
	var btn := OriginalDialog.button("Done")
	add_child_autofree(btn)
	assert_eq(btn.text, "Done")
	for state in ["normal", "hover", "pressed", "disabled"]:
		assert_not_null(btn.get_theme_stylebox(state), state)
	assert_ne(btn.get_theme_stylebox("normal").texture if _skinned() else null,
		btn.get_theme_stylebox("pressed").texture if _skinned() else 1,
		"pressed must not reuse the normal art")


func test_button_letters_in_dark_ink_like_the_originals_own_done() -> void:
	var btn := OriginalDialog.button("Done")
	add_child_autofree(btn)
	assert_eq(btn.get_theme_color("font_color"), OriginalDialog.INK)


func test_button_face_tiles_rather_than_smears() -> void:
	if not _skinned():
		pass_test("no original skin imported")
		return
	var btn := OriginalDialog.button("A very much wider button", Vector2(320, 26))
	add_child_autofree(btn)
	var box: StyleBoxTexture = btn.get_theme_stylebox("normal")
	assert_eq(box.axis_stretch_horizontal, StyleBoxTexture.AXIS_STRETCH_MODE_TILE)
	assert_eq(box.texture_margin_left, float(OriginalDialog.BUTTON_MARGIN))


# --------------------------------------------------------- the text --

func test_pale_text_carries_the_hard_one_pixel_shadow() -> void:
	var lab := OriginalDialog.label("Fast Effects?...Discard Phase", 15)
	add_child_autofree(lab)
	assert_eq(lab.get_theme_color("font_color"), OriginalDialog.HIGHLIGHT)
	assert_eq(lab.get_theme_color("font_shadow_color"), OriginalDialog.INK)
	assert_eq(lab.get_theme_constant("shadow_offset_x"), 1)
	assert_eq(lab.get_theme_constant("shadow_offset_y"), 1)


func test_choice_lines_light_up_under_the_pointer() -> void:
	var line := OriginalDialog.choice_line("1/6 Wall.")
	add_child_autofree(line)
	assert_true(line.flat)
	assert_eq(line.get_theme_color("font_color"), OriginalDialog.CHOICE)
	assert_eq(line.get_theme_color("font_hover_color"), OriginalDialog.CHOICE_LIT)


# --------------------------------------------------------- the dialog --

func test_dialog_centres_itself_at_the_size_asked_for() -> void:
	var holder := Control.new()
	holder.size = Vector2(1280, 800)
	add_child_autofree(holder)
	var dialog := OriginalDialog.create("Start of Duel", Vector2(400, 300))
	holder.add_child(dialog)
	assert_eq(dialog.size, Vector2(400, 300))
	assert_almost_eq(dialog.position.x, (1280.0 - 400.0) / 2.0, 1.0)
	assert_almost_eq(dialog.position.y, (800.0 - 300.0) / 2.0, 1.0)


func test_dialog_body_and_buttons_are_addressable() -> void:
	var dialog := OriginalDialog.create("", Vector2(300, 200))
	add_child_autofree(dialog)
	dialog.body().add_child(OriginalDialog.label("Select target card."))
	var ok := dialog.add_button("OK")
	var cancel := dialog.add_button("Cancel")
	assert_eq(dialog.body().get_child_count(), 1)
	assert_eq(ok.get_parent(), cancel.get_parent(),
		"both buttons share the dialog's foot row")
	assert_eq(cancel.get_parent().get_child_count(), 2)


func test_dismiss_reports_once_and_frees() -> void:
	var dialog := OriginalDialog.create("", Vector2(200, 120))
	# autofree as well: `queue_free` is deferred, and GUT counts a child
	# still waiting on the queue as unfreed at the end of the script.
	add_child_autofree(dialog)
	watch_signals(dialog)
	dialog.dismiss()
	assert_signal_emit_count(dialog, "closed", 1)
	assert_true(dialog.is_queued_for_deletion())
