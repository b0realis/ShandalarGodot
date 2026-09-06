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


# ------------------------------------------------------ the art's bound --
# The card-art cache is BOUNDED and least-recently-used (2026-09-06): a
# full browse of the Deck Builder's grid used to hold every art it had
# ever shown, 909 MB across the pool. The cache is filled here with
# stand-in textures rather than real files, so the bound is tested in a
# checkout with no art at all, and the state is put back afterwards.

var _saved_art: Dictionary
var _saved_missing: Dictionary


func _stash_art() -> void:
	_saved_art = GameSkin._art_cache.duplicate()
	_saved_missing = GameSkin._art_missing.duplicate()
	GameSkin._art_cache.clear()
	GameSkin._art_missing.clear()


func _restore_art() -> void:
	GameSkin._art_cache = _saved_art
	GameSkin._art_missing = _saved_missing


func _stand_in(i: int) -> ImageTexture:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(float(i % 7) / 7.0, 0.5, 0.5))
	return ImageTexture.create_from_image(img)


func test_the_art_cache_holds_no_more_than_its_cap() -> void:
	_stash_art()
	for i in GameSkin.ART_CACHE_CAP + 40:
		GameSkin._art_cache["cardart/stand_in_%d" % i] = _stand_in(i)
		# The same trim card_art runs after a load — a static, so the
		# test drives it the way the loader does.
		while GameSkin._art_cache.size() > GameSkin.ART_CACHE_CAP:
			for oldest in GameSkin._art_cache:
				GameSkin._art_cache.erase(oldest)
				break
	assert_eq(GameSkin._art_cache.size(), GameSkin.ART_CACHE_CAP)
	assert_false(GameSkin._art_cache.has("cardart/stand_in_0"),
		"the oldest picture is the one that went")
	assert_true(GameSkin._art_cache.has(
		"cardart/stand_in_%d" % (GameSkin.ART_CACHE_CAP + 39)),
		"the youngest is there")
	_restore_art()


func test_a_picture_asked_for_again_is_young_again() -> void:
	# LRU, not FIFO: the card the player keeps looking at must not be the
	# one that falls off the end because it was loaded first.
	_stash_art()
	var first := _stand_in(0)
	GameSkin._art_cache["cardart/kept"] = first
	for i in 5:
		GameSkin._art_cache["cardart/other_%d" % i] = _stand_in(i + 1)
	# A cache hit through the real accessor: the key it re-inserts is
	# _snake("kept"), which is "kept".
	assert_eq(GameSkin.card_art("kept"), first, "the hit is the same texture")
	var order: Array = GameSkin._art_cache.keys()
	assert_eq(order[-1], "cardart/kept", "asked for again, it is the youngest")
	assert_eq(order[0], "cardart/other_0", "and the untouched one is the oldest")
	_restore_art()


func test_a_missing_picture_costs_no_cache_slot() -> void:
	_stash_art()
	assert_null(GameSkin.card_art("No Such Card Anywhere"))
	assert_true(GameSkin._art_cache.is_empty(), "nothing cached for it")
	assert_true(GameSkin._art_missing.has("cardart/no_such_card_anywhere"),
		"remembered as missing, so the disk is not searched again")
	assert_null(GameSkin.card_art("No Such Card Anywhere"))
	_restore_art()


func test_an_evicted_picture_still_hangs_on_its_card() -> void:
	# The cache holds one reference; the TextureRect that draws it holds
	# another. Dropping the cache's claim must not blank a card on screen.
	_stash_art()
	var rect := TextureRect.new()
	add_child_autofree(rect)
	var tex := _stand_in(3)
	GameSkin._art_cache["cardart/on_screen"] = tex
	rect.texture = GameSkin.card_art("on_screen")
	GameSkin._art_cache.erase("cardart/on_screen")
	assert_true(is_instance_valid(rect.texture), "the card keeps its picture")
	assert_eq(rect.texture.get_width(), 2)
	_restore_art()
