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


# ------------------------------------------------------- the order of faces --
# THE FALLBACK CHAIN, 2026-09-09: the player's imported skin, then a
# development checkout's `assets/original`, then the face this project
# ships (`GameSkin.our_font`, `game/art/fonts/`), then Godot's own
# default. Ours is a FLOOR and not a preference — an imported MPlantin
# must still win outright, because it is what a player who went and found
# their own copy of the 1997 game came for.
#
# Both states of the world are one test: the machine either has a
# `font_body.ttf` in a skin directory or it does not, and the chain says
# something different and checkable in each case. Nothing here is skipped
# on either kind of machine.

func test_an_imported_face_beats_ours_and_ours_beats_godots_default() -> void:
	var ours := GameSkin.our_font("font_body")
	assert_not_null(ours, "the floor is in the checkout on every machine")
	var chosen := GameSkin.font("font_body")
	assert_not_null(chosen,
		"font_body can no longer come back empty — that is what the floor "
		+ "is for")
	if GameSkin._find("font_body.ttf") != "":
		assert_ne(chosen, ours,
			"a skin supplies font_body and it must be what renders")
		assert_ne(chosen.get_font_name(), "Spectral",
			"the imported face, not the shipped one")
	else:
		assert_eq(chosen, ours,
			"nothing imported: the shipped face is what renders")
		assert_eq(chosen.get_font_name(), "Spectral")


func test_the_floor_answers_only_the_keys_it_has_a_face_for() -> void:
	# A floor that guessed would be worse than none: the original's title
	# face is a blackletter and this project ships no stand-in for it, so
	# `font_title` still falls through to Godot's default without a skin.
	assert_null(GameSkin.our_font("font_title"))
	assert_null(GameSkin.our_font("no_such_font"))
	if GameSkin._find("font_title.ttf") == "":
		assert_null(GameSkin.font("font_title"),
			"no skin and no floor for this key — the caller gets the "
			+ "engine default, exactly as before")


func test_a_skin_arriving_re_resolves_the_face_but_not_ours() -> void:
	# `clear_caches` is what [SkinPack] calls the moment a zip is dropped
	# on the window. The chosen face has to be looked up again (a skin may
	# now supply one); what this project ships cannot have changed, and is
	# deliberately kept in a cache of its own.
	var before := GameSkin.our_font("font_body")
	GameSkin.clear_caches()
	assert_eq(GameSkin.our_font("font_body"), before,
		"a skin arriving cannot change what this project ships")
	assert_not_null(GameSkin.font("font_body"), "and the floor is still there")


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


# ------------------------------------------------- ours, and where it sits --
# THE ORDER, 2026-09-09. `game/art/` holds pictures this project DREW —
# the six set glyphs and the damage dagger — and the loader reaches them
# through [method GameSkin.our_art]. They sit BETWEEN the two states this
# file already tests: after every skin directory (an imported 1997 file
# still wins) and before the code-drawn fallback (a machine with no skin
# is no longer left with nothing). These tests pin that sandwich.

## Every key `game/art/` answers, and the size each file is authored at.
const OURS := {
	"set_icon_atq": Vector2i(48, 48),
	"set_icon_arn": Vector2i(48, 48),
	"set_icon_past": Vector2i(48, 48),
	"set_icon_drk": Vector2i(48, 48),
	"set_icon_4ed": Vector2i(48, 48),
	"set_icon_leg": Vector2i(48, 48),
	"damage_marker": Vector2i(64, 40),
}


func test_our_own_art_answers_every_key_it_claims() -> void:
	# Runs the same on every machine, skin or no skin: these files are in
	# the pack, not on the player's disk.
	for key in OURS:
		var tex := GameSkin.our_art(String(key))
		assert_not_null(tex, "game/art/%s.png" % key)
		if tex != null:
			assert_eq(Vector2i(tex.get_width(), tex.get_height()),
				OURS[key], "%s is the size it was drawn at" % key)


func test_our_own_art_says_nothing_about_a_key_we_never_drew() -> void:
	assert_null(GameSkin.our_art("no_such_picture"))
	assert_null(GameSkin.our_art("card_back"),
		"the card back is the skin's business, not ours")


## A skin directory of one file, pointed at through the `skin_folder` key
## exactly as a player would — the FIRST place [method
## GameSkin.search_dirs] looks — and a stand-in of an unmistakable size so
## the answer says which source it came from. [param key] is the skin key
## to plant, [param call] fetches it back.
func _planted(key: String, call: Callable) -> Vector2i:
	var dir := "user://test_skin_%d" % Time.get_ticks_usec()
	var absolute := ProjectSettings.globalize_path(dir)
	DirAccess.make_dir_recursive_absolute(absolute)
	var stand_in := Image.create_empty(9, 9, false, Image.FORMAT_RGBA8)
	stand_in.fill(Color(0, 0, 0, 0))
	stand_in.set_pixel(4, 4, Color(1, 0, 1, 1))
	stand_in.save_png(absolute.path_join("%s.png" % key))
	var was: Variant = Settings.get_value(GamePaths.KEY_SKIN_FOLDER, "")
	Settings.set_value(GamePaths.KEY_SKIN_FOLDER, dir, false)
	GameSkin.clear_caches()
	# AND THE DERIVED CACHES, which `clear_caches` deliberately does not
	# reach (a skin arriving mid-game restarts the duel screen instead).
	# Without this the test passes alone and fails in the suite, because a
	# neighbour has already cut the real sprite and the planted file is
	# never read — which is exactly how it first failed, 2026-09-10.
	MiniCard._masked_cache.clear()
	var tex: Texture2D = call.call()
	var size := Vector2i(tex.get_width(), tex.get_height()) if tex != null \
		else Vector2i.ZERO
	Settings.set_value(GamePaths.KEY_SKIN_FOLDER, was, false)
	GameSkin.clear_caches()
	MiniCard._masked_cache.clear()
	DirAccess.remove_absolute(absolute.path_join("%s.png" % key))
	DirAccess.remove_absolute(absolute)
	return size


func test_an_imported_skin_beats_ours() -> void:
	# The rule for every picture this project ships: ours is a FLOOR, and
	# a file the player imported stands on top of it. The dagger arrives
	# through [method MiniCard.masked_sprite], which SPLITS a 1997 sprite
	# into its image and mask halves — so a planted 9x9 comes back 4x9,
	# and that halving is itself the proof the imported file is what was
	# read (ours is 64x40 and carries real alpha, so it is never split).
	assert_eq(_planted("damage_marker",
		func() -> Texture2D: return MiniCard.damage_marker_texture()),
		Vector2i(4, 9), "the skin's own file, halved by the mask split")


## THE SET SYMBOL IS THE ONE EXCEPTION, and it is deliberate (the owner,
## 2026-09-10: *"Lets always use our own designed glyphs and thats it for
## all players. Simplest."*). The enlarged card's symbol box is 14x17
## PIXELS and the three possible sources read very differently there —
## Manalink's restyle fills it, ours fills 77% of its tile, and 1997's own
## is a black glyph inside a gold ring on a stone disc, which at that size
## is a dark smudge whatever you crop off it. So every player gets the
## same six glyphs rather than one player getting a legible anvil and
## another a smudge. What it costs is stated at the site: a player who
## imported their own disc does not see their disc's medallions HERE —
## though they do still see the printed expansion symbols on the title
## row, which come off a different sheet ([method SetBadges.symbol]).
func test_the_set_symbol_is_ours_even_when_a_skin_has_one() -> void:
	assert_eq(_planted("set_icon_atq",
		func() -> Texture2D: return GameSkin.set_icon("atq")),
		Vector2i(48, 48), "ours, at the size draw_our_art.gd writes")


func test_ours_stands_when_no_skin_has_the_key() -> void:
	# The other half, and it can only be READ on a machine with nothing
	# imported — which is the state a player who has run no tools is in,
	# and the state this suite must pass in either way.
	if GameSkin._find("set_icon_atq.png") != "":
		pass_test("a skin on this machine supplies set_icon_atq, "
			+ "and by the order above it wins")
		return
	GameSkin.clear_caches()
	var tex := GameSkin.set_icon("atq")
	assert_not_null(tex, "ours stands in")
	if tex != null:
		assert_eq(Vector2i(tex.get_width(), tex.get_height()),
			Vector2i(48, 48), "the file this project drew")


func test_the_dagger_reaches_the_card_with_no_skin_at_all() -> void:
	# [method MiniCard.masked_sprite] is the one accessor every dagger on
	# the table goes through, and until 2026-09-09 it simply returned null
	# with no skin, so a wounded creature wore a number and no mark.
	if GameSkin.texture("damage_marker") != null:
		pass_test("a skin on this machine supplies the dagger")
		return
	MiniCard._masked_cache.clear()
	assert_not_null(MiniCard.damage_marker_texture(), "ours stands in")


func test_a_key_with_no_drawing_anywhere_is_still_quietly_null() -> void:
	# The contract at the top of this file is unchanged by any of the
	# above: an asset nobody has is null, never an error.
	assert_null(GameSkin.set_icon("no_such_set"))
