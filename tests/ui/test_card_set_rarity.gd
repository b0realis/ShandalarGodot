extends GutTest
## On-card set colours need only the project's own art, never an imported skin.

var _enabled: Array[String] = []

func before_each() -> void:
	_enabled.clear()
	for id in CardPacks.available_ids():
		if CardPacks.is_enabled(id): _enabled.append(id)
		CardPacks.set_enabled(id, false)
	CardRegistry.ensure_loaded()

func after_each() -> void:
	for id in CardPacks.available_ids():
		CardPacks.set_enabled(id, _enabled.has(id))
	await get_tree().process_frame

func test_white_silver_gold_and_purple_are_distinct_cached_textures() -> void:
	var original := GameSkin.set_icon("4ed")
	var bytes := original.get_image().get_data()
	var white := GameSkin.set_icon("4ed", "common")
	var silver := GameSkin.set_icon("4ed", "uncommon")
	var purple := GameSkin.set_icon("4ed", "rare", true)
	assert_ne(white, silver)
	assert_ne(silver, original)
	assert_ne(purple, original)
	assert_eq(GameSkin.set_icon("4ed", "rare"), original, "rare retains authored gold")
	assert_eq(GameSkin.set_icon("4ed", "special"), original, "unknown retains the existing glyph")
	assert_eq(GameSkin.set_icon("4ed", "mythic"), purple)
	assert_eq(GameSkin.set_icon("4ed", "uncommon", true), purple, "legendary beats uncommon")
	assert_eq(GameSkin.set_icon("4ed", "common"), white, "cache is per set and colour")
	assert_true(original.get_image().get_data() == bytes, "shared gold master is untouched")
	var white_ink := _average_ink(white)
	var silver_ink := _average_ink(silver)
	var purple_ink := _average_ink(purple)
	assert_gt(white_ink.r, silver_ink.r + 0.10, "white is brighter than silver")
	assert_almost_eq(white_ink.r, white_ink.b, 0.04, "common is neutral white, not yellow")
	assert_gt(silver_ink.b, silver_ink.r, "silver has a cool metallic cast")
	assert_gt(purple_ink.b, purple_ink.g + 0.15)
	assert_gt(purple_ink.r, purple_ink.g + 0.10)

func test_every_authored_set_keeps_its_shape_alpha_and_dark_outline() -> void:
	for code in ["2ed", "4ed", "arn", "atq", "leg", "drk", "past", "fem", "ice", "hml", "all"]:
		var source := GameSkin.set_icon(code).get_image()
		for rarity in ["common", "uncommon", "mythic"]:
			var img := GameSkin.set_icon(code, rarity).get_image()
			assert_eq(img.get_size(), source.get_size())
			var alpha_changed := false
			var dark_pixels := 0
			for y in img.get_height():
				for x in img.get_width():
					var pixel := img.get_pixel(x, y)
					if pixel.a != source.get_pixel(x, y).a: alpha_changed = true
					if pixel.a > 0.4 and pixel.v < 0.2: dark_pixels += 1
			assert_false(alpha_changed, "%s %s preserves transparent shape" % [code, rarity])
			assert_gt(dark_pixels, 0, "%s %s has an outline on pale cards" % [code, rarity])
	assert_null(GameSkin.set_icon("phpr", "rare"), "PR remains a letter-only mark")
	assert_null(GameSkin.set_icon("missing_set", "common"))

func test_preview_uses_printed_rarity_and_legendary_override() -> void:
	var preview := _preview()
	for row in [["Grizzly Bears", "common", false], ["Serra Angel", "uncommon", false],
			["Savannah Lions", "rare", false], ["Jedit Ojanen", "uncommon", true]]:
		var data := CardRegistry.get_card(row[0])
		preview.show_card(CardInstance.new(data, 7, 0))
		assert_eq(preview._set_icon.texture, GameSkin.set_icon(data.set_code, row[1], row[2]), row[0])
		assert_true(preview._set_icon.visible)

func test_preview_follows_the_displayed_reprints_rarity_without_mutating_the_card() -> void:
	var preview := _preview()
	var data := CardRegistry.get_card("Apprentice Wizard")
	var original_set := data.set_code
	var inst := CardInstance.new(data, 7, 0)
	assert_eq(CardRegistry.rarity_of(data.card_name, "4ed"), "common")
	assert_eq(CardRegistry.rarity_of(data.card_name, "drk"), "rare")
	preview.show_card(inst, "4ed")
	assert_eq(preview._set_icon.texture, GameSkin.set_icon("4ed", "common"))
	preview.show_card(inst, "drk")
	assert_eq(preview._set_icon.texture, GameSkin.set_icon("drk", "rare"))
	assert_eq(data.set_code, original_set)
	assert_eq(inst.data, data, "decks remain name-based")
	assert_eq(CardRegistry.rarity_of("not a card", "4ed"), "")

func test_pack_metadata_is_loaded_and_cleared_with_pack_enablement() -> void:
	var preview := _preview()
	for row in [["pack-1", "Chaos Orb", "2ed", "rare"],
			["pack-2", "Thallid", "fem", "common"]]:
		CardPacks.set_enabled(row[0], true)
		assert_eq(CardRegistry.rarity_of(row[1], row[2]), row[3])
		preview.show_card(CardInstance.new(CardRegistry.get_card(row[1]), 7, 0))
		assert_eq(preview._set_icon.texture, GameSkin.set_icon(row[2], row[3]))
		preview.show_back()
		CardPacks.set_enabled(row[0], false)
		assert_eq(CardRegistry.rarity_of(row[1], row[2]), "", "no stale disabled-pack metadata")

func test_expanding_text_preserves_the_selected_printing_and_resets_for_the_next_card() -> void:
	var preview := _preview()
	var data := CardRegistry.get_card("Apprentice Wizard")
	var inst := CardInstance.new(data, 7, 0)
	for set_code in ["drk", "4ed"]:
		preview.show_card(inst, set_code)
		var expected := GameSkin.set_icon(set_code, CardRegistry.rarity_of(data.card_name, set_code))
		for expanded in [true, false]:
			preview.set_text_expanded(expanded)
			assert_eq(preview._set_icon.texture, expected, "expanded text must not change the printing")
	preview.show_back()
	var bears := CardRegistry.get_card("Grizzly Bears")
	preview.show_card(CardInstance.new(bears, 8, 0))
	preview.set_text_expanded(true)
	assert_eq(preview._set_icon.texture,
		GameSkin.set_icon(bears.set_code, CardRegistry.rarity_of(bears.card_name, bears.set_code)),
		"the next card must not inherit the previous printing override")

func test_letter_only_set_labels_also_follow_the_scheme() -> void:
	var preview := _preview()
	preview.show_card(CardInstance.new(CardRegistry.get_card("Arena"), 7, 0))
	assert_true(preview._set_text.visible)
	assert_eq(preview._set_text.get_theme_color("font_color"), GameSkin.set_symbol_ink("rare"))
	assert_eq(GameSkin.set_symbol_ink("mythic"), GameSkin.set_symbol_ink("rare", true))
	assert_eq(GameSkin.set_symbol_ink("common"), Color.WHITE)

func test_clearing_the_skin_cache_rebuilds_variants_without_changing_their_pixels() -> void:
	var old := GameSkin.set_icon("ice", "uncommon")
	var pixels := old.get_image().get_data()
	GameSkin.clear_caches()
	var fresh := GameSkin.set_icon("ice", "uncommon")
	assert_ne(fresh, old)
	assert_true(fresh.get_image().get_data() == pixels, "reloaded pixels match")

func _preview() -> CardPreview:
	var preview := CardPreview.new()
	preview.docked = true
	add_child_autofree(preview)
	preview.size = CardPreview.SIZE
	return preview

func _average_ink(texture: Texture2D) -> Color:
	var img := texture.get_image()
	var total := Color(0, 0, 0, 0)
	var count := 0
	for y in img.get_height():
		for x in img.get_width():
			var pixel := img.get_pixel(x, y)
			if pixel.a > 0.98 and pixel.v > 0.2:
				total += pixel
				count += 1
	return total / maxf(count, 1)
