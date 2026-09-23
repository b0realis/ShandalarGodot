extends GutTest
## The dual-land panel is generated from code and works without the 1997 skin.

var _preview: CardPreview

func before_each() -> void:
	CardRegistry.ensure_loaded()
	_preview = CardPreview.new()
	_preview.docked = true
	add_child_autofree(_preview)
	_preview.size = CardPreview.SIZE

func after_each() -> void:
	await get_tree().process_frame

func _show(card_name: String) -> void:
	_preview.show_card(CardInstance.new(CardRegistry.get_card(card_name), 7, 0))

func test_only_the_ten_original_dual_lands_get_the_panel() -> void:
	var expected := ["Tundra", "Underground Sea", "Badlands", "Taiga", "Savannah",
		"Scrubland", "Volcanic Island", "Bayou", "Plateau", "Tropical Island"]
	assert_eq(DualLandTextBox.PAIRS.size(), expected.size())
	for name in expected:
		_show(name)
		assert_true(_preview._dual_land_plate.visible, name)
		assert_eq(_preview._dual_land_plate.texture, DualLandTextBox.texture_for(name))
		assert_eq(_preview._oracle.get_theme_color("font_color"), CardPreview.RULES_INK)
		assert_eq(_preview._dual_land_plate.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_lt(_preview._dual_land_plate.get_index(), _preview._oracle.get_index())
	for name in ["Forest", "City of Brass", "Mishra's Factory", "Serra Angel", "Savannah Lions"]:
		_show(name)
		assert_false(_preview._dual_land_plate.visible, name)
		assert_null(_preview._dual_land_plate.texture)
	assert_null(DualLandTextBox.texture_for("unknown"))

func test_each_pair_matches_the_lands_printed_mana_symbols() -> void:
	for name in DualLandTextBox.PAIRS:
		var pair: String = DualLandTextBox.PAIRS[name]
		var text: String = CardRegistry.get_card(name).oracle_text
		assert_ne(pair[0], pair[1])
		for ink in pair:
			assert_true(text.contains("{%s}" % ink), name)

func test_rings_repeat_on_all_four_edges_with_readable_opaque_ink() -> void:
	for name in DualLandTextBox.PAIRS:
		var texture := DualLandTextBox.texture_for(name)
		assert_eq(DualLandTextBox.texture_for(name), texture, "cached, not regenerated on hover")
		var img := texture.get_image()
		assert_eq(img.get_size(), DualLandTextBox.TEXTURE_SIZE)
		var pair: String = DualLandTextBox.PAIRS[name]
		for band in 6:
			var inset := 3 + band * DualLandTextBox.BAND_WIDTH + 8
			var expected: Color = DualLandTextBox.INKS[pair[band % 2]]
			for point in [Vector2i(256, inset), Vector2i(256, 271 - inset),
					Vector2i(inset, 136), Vector2i(511 - inset, 136)]:
				var actual := img.get_pixelv(point)
				assert_almost_eq(actual.r, expected.r, 0.015)
				assert_almost_eq(actual.g, expected.g, 0.015)
				assert_almost_eq(actual.b, expected.b, 0.015)
				assert_eq(actual.a, 1.0)
				assert_gt(actual.get_luminance(), 0.65, "dark rules text stays readable")

func test_overlay_tracks_expansion_size_and_cannot_leak_onto_the_back() -> void:
	_show("Tundra")
	_preview._lay_out_text_box(CardPreview.TEXT_TOP_EXPANDED)
	assert_almost_eq(_preview._dual_land_plate.anchor_top, CardPreview.TEXT_TOP_EXPANDED, 0.0001)
	assert_almost_eq(_preview._dual_land_plate.anchor_bottom, CardPreview.PLATE_BOTTOM, 0.0001)
	_preview.size = CardPreview.SIZE * 1.5
	await get_tree().process_frame
	assert_almost_eq(_preview._dual_land_plate.size.x, _preview.size.x * 0.834, 0.1)
	_preview.show_back()
	assert_false(_preview._dual_land_plate.visible)
	assert_null(_preview._dual_land_plate.texture)
	_show("Bayou")
	assert_true(_preview._dual_land_plate.visible)
	assert_almost_eq(_preview._dual_land_plate.anchor_top, CardPreview.TEXT_TOP, 0.0001)

func test_overlay_also_works_without_a_skin_and_does_not_recolor_the_frame() -> void:
	# Temporarily substitute the existing cache entry, never player settings.
	var key := MiniCard.frame_skin_key(CardRegistry.get_card("Tundra"))
	var had_key := GameSkin._texture_cache.has(key)
	var saved: Variant = GameSkin._texture_cache.get(key)
	GameSkin._texture_cache[key] = null
	_show("Tundra")
	assert_true(_preview._dual_land_plate.visible)
	assert_true(_preview._text_bg.visible)
	assert_true(_preview._frame_bg.get_theme_stylebox("panel") is StyleBoxFlat)
	if had_key:
		GameSkin._texture_cache[key] = saved
	else:
		GameSkin._texture_cache.erase(key)
