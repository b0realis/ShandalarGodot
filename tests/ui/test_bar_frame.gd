extends GutTest
## `[QoL]` THE SITUATION BAR'S FRAME (2026-10-19) — the Options screen's
## `Situation Bar frame:` row, the [Settings] key behind it
## ([method DuelOptions.bar_frame]) and the four frames
## [method OriginalDialog.bar_style] draws.
##
## The owner, over a photo of the 1997 bar: *"Original 1997 shandalar has
## this border around central messages"*, then: *"Can we keep today plus
## all 3 options. Today we name ShandalarGodot, option B we name Classic,
## option A we name Classic pale and option C we name Classic thin.
## (Default is ShandalarGodot)"* and *"Lets make the setting in options."*
##
## The ridge, measured on that photo: a pale line all the way round, with a
## dark one inside it along the top and left and outside it along the
## bottom and right.


var _saved: Variant = null


func before_each() -> void:
	_saved = Settings.get_value(DuelOptions.BAR_FRAME_KEY, null) \
		if Settings.has_value(DuelOptions.BAR_FRAME_KEY) else null
	Settings.clear_value(DuelOptions.BAR_FRAME_KEY)


func after_each() -> void:
	if _saved == null:
		Settings.clear_value(DuelOptions.BAR_FRAME_KEY)
	else:
		Settings.set_value(DuelOptions.BAR_FRAME_KEY, _saved)


func _skinned() -> bool:
	return GameSkin.texture("message_panel") != null


func _bar_image(frame: String) -> Image:
	DuelOptions.set_bar_frame(frame)
	var box := OriginalDialog.bar_style(5.0) as StyleBoxTexture
	assert_not_null(box, "a ruled texture, the skin being there")
	return box.texture.get_image() if box != null else null


# ------------------------------------------------------------ the setting --

func test_the_four_frames_in_the_owners_order_and_names() -> void:
	var labels: Array[String] = []
	for row in DuelOptions.BAR_FRAMES:
		labels.append(String(row["label"]))
	assert_eq(labels, ["ShandalarGodot", "Classic", "Classic pale", "Classic thin"]
		as Array[String])
	for row in DuelOptions.BAR_FRAMES:
		assert_ne(String(row["blurb"]), "", "%s says what it is" % row["label"])


func test_shandalargodot_is_the_default_and_nothing_is_written_for_it() -> void:
	assert_eq(DuelOptions.bar_frame(), DuelOptions.BAR_FRAME_SHANDALARGODOT)
	assert_false(Settings.has_value(DuelOptions.BAR_FRAME_KEY),
		"reading writes nothing")


func test_a_frame_is_kept_and_an_unknown_one_reads_as_the_default() -> void:
	DuelOptions.set_bar_frame(DuelOptions.BAR_FRAME_CLASSIC_PALE)
	assert_eq(DuelOptions.bar_frame(), DuelOptions.BAR_FRAME_CLASSIC_PALE)
	DuelOptions.set_bar_frame("gold leaf")
	assert_eq(DuelOptions.bar_frame(), DuelOptions.BAR_FRAME_DEFAULT,
		"an unknown frame is refused into the default")
	Settings.set_value(DuelOptions.BAR_FRAME_KEY, "gold leaf")
	assert_eq(DuelOptions.bar_frame(), DuelOptions.BAR_FRAME_DEFAULT,
		"and a hand-edited one reads as it")
	Settings.set_value(DuelOptions.BAR_FRAME_KEY, 3)
	assert_eq(DuelOptions.bar_frame(), DuelOptions.BAR_FRAME_DEFAULT,
		"so does a value of the wrong kind")


# ------------------------------------------------------------- the frames --

func test_shandalargodot_is_the_rule_the_bar_has_always_worn() -> void:
	if not _skinned():
		pass_test("no original skin imported")
		return
	var img := _bar_image(DuelOptions.BAR_FRAME_SHANDALARGODOT)
	var ruled := OriginalDialog.bar_texture().get_image()
	var h := img.get_height()
	for at in [Vector2i(40, 0), Vector2i(40, 1), Vector2i(40, 2), Vector2i(0, 10),
			Vector2i(40, h - 1), Vector2i(40, h - 3), Vector2i(300, 17)]:
		assert_eq(img.get_pixel(at.x, at.y), ruled.get_pixel(at.x, at.y),
			"the same pixel at %s" % at)


func test_classic_is_the_ridge_in_pale_blue_grey_and_dark_ink() -> void:
	if not _skinned():
		pass_test("no original skin imported")
		return
	var img := _bar_image(DuelOptions.BAR_FRAME_CLASSIC)
	var w := img.get_width()
	var h := img.get_height()
	var pale := OriginalDialog.HIGHLIGHT
	var dark := OriginalDialog.INK
	for i in 2:
		# The outer line: pale on the top and left, dark on the bottom and right.
		assert_eq(img.get_pixel(40, i), pale, "top, outer row %d" % i)
		assert_eq(img.get_pixel(i, 17), pale, "left, outer column %d" % i)
		assert_eq(img.get_pixel(40, h - 1 - i), dark, "bottom, outer row %d" % i)
		assert_eq(img.get_pixel(w - 1 - i, 17), dark, "right, outer column %d" % i)
		# The inner line, the other way round.
		assert_eq(img.get_pixel(40, 2 + i), dark, "top, inner row %d" % i)
		assert_eq(img.get_pixel(2 + i, 17), dark, "left, inner column %d" % i)
		assert_eq(img.get_pixel(40, h - 3 - i), pale, "bottom, inner row %d" % i)
		assert_eq(img.get_pixel(w - 3 - i, 17), pale, "right, inner column %d" % i)
	var raw := GameSkin.texture("message_panel").get_image()
	assert_eq(img.get_pixel(40, 4), raw.get_pixel(40, 4), "the ridge stops at four")
	assert_eq(img.get_pixel(300, 17), raw.get_pixel(300, 17), "the stone inside is untouched")


func test_classic_pale_is_the_ridge_in_the_stones_own_light_and_dark() -> void:
	if not _skinned():
		pass_test("no original skin imported")
		return
	var img := _bar_image(DuelOptions.BAR_FRAME_CLASSIC_PALE)
	var h := img.get_height()
	var stone := OriginalDialog._mean_colour(GameSkin.texture("message_panel").get_image())
	var pale := img.get_pixel(40, 0)
	var dark := img.get_pixel(40, 2)
	assert_gt(pale.get_luminance(), stone.get_luminance() + 0.15, "the pale line is light")
	assert_lt(dark.get_luminance(), stone.get_luminance() - 0.15, "the dark line is dark")
	assert_gt(pale.r, pale.b, "warm, like the stone — not the dialogs' blue-grey")
	assert_ne(pale, OriginalDialog.HIGHLIGHT)
	assert_eq(img.get_pixel(40, h - 3), pale, "pale inside along the bottom")
	assert_eq(img.get_pixel(40, h - 1), dark, "dark outside along the bottom")


func test_classic_thin_is_classic_pale_with_lines_one_pixel_wide() -> void:
	if not _skinned():
		pass_test("no original skin imported")
		return
	var pale_img := _bar_image(DuelOptions.BAR_FRAME_CLASSIC_PALE)
	var img := _bar_image(DuelOptions.BAR_FRAME_CLASSIC_THIN)
	var raw := GameSkin.texture("message_panel").get_image()
	assert_eq(img.get_pixel(40, 0), pale_img.get_pixel(40, 0), "the same pale")
	assert_eq(img.get_pixel(40, 1), pale_img.get_pixel(40, 2), "then the same dark")
	assert_eq(img.get_pixel(40, 2), raw.get_pixel(40, 2), "and stone at two")


func test_a_ridge_keeps_a_pixel_of_stone_beside_what_the_bar_holds() -> void:
	if not _skinned():
		pass_test("no original skin imported")
		return
	DuelOptions.set_bar_frame(DuelOptions.BAR_FRAME_CLASSIC)
	var title := OriginalDialog.bar_style(2.0)
	assert_eq(title.content_margin_left, 5.0, "the sides clear the 4-pixel ridge")
	assert_eq(title.content_margin_right, 5.0)
	assert_eq(title.content_margin_top, 2.0,
		"the top and bottom keep what a fixed-height title bar asked for")
	DuelOptions.set_bar_frame(DuelOptions.BAR_FRAME_SHANDALARGODOT)
	assert_eq(OriginalDialog.bar_style(2.0).content_margin_left, 2.0,
		"ShandalarGodot's margins are as they were")


# ------------------------------------------------------------ where it shows --

func test_options_offers_the_four_and_shows_the_one_chosen() -> void:
	var options: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(options)
	await get_tree().process_frame
	var picker := options.find_child("BarFrame", true, false) as OptionButton
	assert_not_null(picker, "Options has the row")
	if picker == null:
		return
	assert_eq(picker.item_count, DuelOptions.BAR_FRAMES.size())
	assert_eq(picker.get_item_text(0), "ShandalarGodot")
	assert_eq(picker.selected, 0, "opens on the default")
	var preview := options.find_child("BarFramePreview", true, false) as PanelContainer
	assert_not_null(preview, "with a piece of the bar to see it on")
	picker.select(1)
	picker.item_selected.emit(1)
	assert_eq(DuelOptions.bar_frame(), DuelOptions.BAR_FRAME_CLASSIC, "the choice is kept")
	if preview != null and _skinned():
		var img: Image = (preview.get_theme_stylebox("panel") as StyleBoxTexture).texture.get_image()
		assert_eq(img.get_pixel(40, 2), OriginalDialog.INK, "and the preview wears it")


func test_a_duel_builds_its_bar_in_the_frame_chosen() -> void:
	if not _skinned():
		pass_test("no original skin imported")
		return
	DuelOptions.set_bar_frame(DuelOptions.BAR_FRAME_CLASSIC)
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var bar := screen._prompt_label.get_parent().get_parent() as PanelContainer
	var box := bar.get_theme_stylebox("panel") as StyleBoxTexture
	assert_not_null(box)
	if box != null:
		assert_eq(box.texture.get_image().get_pixel(40, 2), OriginalDialog.INK,
			"the Situation Bar wears Classic")
