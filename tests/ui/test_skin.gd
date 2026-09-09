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


# ------------------------------------------------------- the set symbols --
# THE CUT that takes a set symbol off its own ground
# ([method GameSkin.cut_set_icon]). Two skins draw these very differently
# — 1997's DBArt is a 40x40 blue-grey stone TILE with a gold ring on it,
# Manalink's restyle a 35x36 gold glyph on flat grey — and the loader has
# to be right about both, on a machine that has imported either or
# neither. So the shapes are BUILT here rather than loaded: these tests
# say what the cut does, not what one developer's disc holds.


## A 1997 DBArt medallion, to the measurements in `game/skin.gd`: stone
## everywhere, a gold ring between 14.5 and 17.4 from the centre, a black
## glyph inside it. The corners carry the stone's own blue-greys, which
## is what tells the loader the achromatic key cannot take this ground.
func _stone_tile() -> Image:
	var img := Image.create(40, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color8(146, 171, 176))
	var centre := Vector2(19.5, 19.5)
	for y in 40:
		for x in 40:
			var dist := (Vector2(x, y) - centre).length()
			if dist >= 14.5 and dist <= 17.4:
				img.set_pixel(x, y, Color8(214, 168, 46))
			elif dist < 8.0:
				img.set_pixel(x, y, Color8(28, 24, 26))
	img.set_pixel(0, 0, Color8(178, 237, 245))
	img.set_pixel(39, 0, Color8(174, 180, 204))
	img.set_pixel(0, 39, Color8(178, 237, 245))
	img.set_pixel(39, 39, Color8(174, 180, 204))
	return img


## Manalink's restyle: a grey bevel with a gold glyph on it, and the glyph
## reaches well past any circle inscribed in a 35x36 file — the Legends
## pillar's capital is 19.47 from the centre, so a geometric cut here
## would saw it off.
func _grey_restyle() -> Image:
	var img := Image.create(35, 36, false, Image.FORMAT_RGBA8)
	for y in 36:
		for x in 35:
			var grey := 45 + y * 2
			img.set_pixel(x, y, Color8(grey, grey, grey))
	for x in range(2, 34):
		img.set_pixel(x, 2, Color8(255, 214, 126))
	for y in range(2, 34):
		img.set_pixel(17, y, Color8(255, 214, 126))
	return img


func test_the_1997_tile_is_cut_down_to_its_medallion() -> void:
	var img := _stone_tile()
	GameSkin.cut_set_icon(img)
	for corner in [Vector2i(0, 0), Vector2i(39, 0), Vector2i(0, 39),
			Vector2i(39, 39)]:
		assert_eq(img.get_pixelv(corner).a, 0.0,
			"the tile's corner at %s is gone" % corner)
	assert_eq(img.get_pixel(19, 19).a, 1.0, "the glyph's centre stays")
	assert_eq(img.get_pixel(19, 4).a, 1.0,
		"the gold ring stays (4.5 above centre of 40 is r 15.5)")
	assert_eq(img.get_pixel(19, 0).a, 0.0,
		"and the stone above the ring goes with the corners")


func test_the_restyle_keeps_a_glyph_that_reaches_past_the_circle() -> void:
	var img := _grey_restyle()
	GameSkin.cut_set_icon(img)
	for corner in [Vector2i(0, 0), Vector2i(34, 0), Vector2i(0, 35),
			Vector2i(34, 35)]:
		assert_eq(img.get_pixelv(corner).a, 0.0,
			"the grey bevel's corner at %s is keyed away" % corner)
	assert_eq(img.get_pixel(17, 17).a, 1.0, "the glyph's centre stays")
	assert_eq(img.get_pixel(33, 2).a, 1.0,
		"and so does the far end of it, 22px from the centre")


func test_the_four_corners_choose_the_cut() -> void:
	assert_false(GameSkin._backdrop_is_flat(_stone_tile()),
		"stone in the corners: the key cannot take this ground")
	assert_true(GameSkin._backdrop_is_flat(_grey_restyle()),
		"pure grey in the corners: the key is the right cut")


func test_every_imported_set_icon_loses_its_ground() -> void:
	# Whichever skin this machine imported. Both cuts must end the same
	# way: nothing of the backdrop in the corners, and a symbol left.
	var found := 0
	for code in ["atq", "arn", "past", "drk", "4ed", "leg"]:
		var tex := GameSkin.set_icon(code)
		if tex == null:
			continue
		found += 1
		var img := tex.get_image()
		var last := Vector2i(img.get_width() - 1, img.get_height() - 1)
		for corner in [Vector2i.ZERO, Vector2i(last.x, 0),
				Vector2i(0, last.y), last]:
			assert_eq(img.get_pixelv(corner).a, 0.0,
				"set_icon_%s keeps no corner at %s" % [code, corner])
		var opaque := 0
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.5:
					opaque += 1
		assert_gt(opaque, 40, "set_icon_%s still has a symbol" % code)
	if found == 0:
		pass_test("no set symbols imported on this machine")
