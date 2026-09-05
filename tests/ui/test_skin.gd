extends GutTest
## Tests for the original-graphics skin loader (game/skin.gd).
##
## These pass in BOTH states of the world — with the 1997 skin imported
## (tools/import_original.py) and without it — because that dual behavior
## IS the contract: the game must be complete without original assets and
## dress up automatically with them.


func test_unknown_keys_return_null_quietly() -> void:
	assert_null(GameSkin.texture("no_such_skin_asset"))
	assert_null(GameSkin.font("no_such_font"))


func test_present_skin_assets_load_as_textures() -> void:
	if not GameSkin.is_present():
		pass_test("no original skin imported on this machine — fallback path is the test")
		return
	for key in ["card_frame_white", "card_frame_red", "duel_pattern_green",
			"card_back", "title_background"]:
		var tex := GameSkin.texture(key)
		assert_not_null(tex, key)
		if tex != null:
			assert_gt(tex.get_width(), 0, key)


func test_original_fonts_load() -> void:
	if not GameSkin.is_present():
		pass_test("no original skin imported — nothing to load")
		return
	assert_not_null(GameSkin.font("font_title"), "MagicMedieval")
	assert_not_null(GameSkin.font("font_body"), "MPlantin")


func test_cached_lookups_are_stable() -> void:
	var first := GameSkin.texture("card_frame_white")
	var second := GameSkin.texture("card_frame_white")
	assert_eq(first, second, "same cached object either way (both may be null)")
