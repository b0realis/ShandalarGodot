extends GutTest
## Player report, 2026-11-26: "Non basic lands like Mishra's Factory, Strip
## Mine, etc, incorrectly use the Artifact frame."
##
## A land that makes colorless mana, none, or any color wears the land
## frame of the set that first printed it (`card_frame_land_<set code>`)
## when the skin has it, the neutral land frame when it does not, and the
## flat land color with no skin at all — never the artifact frame. The
## frames here are plain colored pictures made in the test.

const SET_KEYS: Array[String] = ["card_frame_land_arn", "card_frame_land_atq",
	"card_frame_land_leg", "card_frame_land_drk", "card_frame_land_fem", "card_frame_land_ice"]
const OLD_KEYS: Array[String] = ["card_frame_white", "card_frame_blue", "card_frame_black",
	"card_frame_red", "card_frame_green", "card_frame_gold", "card_frame_artifact",
	"card_frame_land_white", "card_frame_land_blue", "card_frame_land_black",
	"card_frame_land_red", "card_frame_land_green"]


func before_each() -> void:
	CardRegistry.ensure_loaded()
	GameSkin.clear_caches()


func after_each() -> void:
	GameSkin.clear_caches()
	await get_tree().process_frame


static func _picture(salt: int) -> ImageTexture:
	var img := Image.create_empty(228, 325, false, Image.FORMAT_RGBA8)
	img.fill(Color.from_hsv(fmod(salt * 0.071, 1.0), 0.5, 0.7))
	return ImageTexture.create_from_image(img)


## The skin worn: the twelve old frames when [param old], the six set land
## frames when [param sets]; a frame not worn is kept as missing.
func _wear(old: bool, sets: bool) -> void:
	GameSkin.clear_caches()
	var salt := 0
	for key in OLD_KEYS:
		salt += 1
		GameSkin._texture_cache[key] = _picture(salt) if old else null
	for key in SET_KEYS:
		salt += 1
		GameSkin._texture_cache[key] = _picture(salt) if sets else null


static func _land(card_name: String, script_set: String, colors: Array) -> CardData:
	var d := CardData.new(card_name, "", Mtg.CardType.LAND)
	for color: int in colors:
		d.mana(ManaAbility.new(color))
	d.set_code = script_set
	d.script_set = script_set
	return d


func _key(card_name: String) -> String:
	var d := CardRegistry.get_card(card_name)
	assert_not_null(d, card_name)
	return MiniCard.frame_skin_key(d) if d != null else ""


func test_the_skin_has_a_size_for_each_set_land_frame() -> void:
	assert_eq(MiniCard.SET_LAND_FRAMES.size(), SET_KEYS.size())
	for code in MiniCard.SET_LAND_FRAMES:
		assert_has(SET_KEYS, "card_frame_land_" + code)
		assert_eq(GameSkin.SIZES.get("card_frame_land_" + code), Vector2i(228, 325), code)
		assert_eq(SkinRecipes.MANIFEST.get("card_frame_land_" + code, []).size(), 1,
			"the skin builder imports " + code)


func test_a_colorless_land_wears_its_first_sets_land_frame() -> void:
	_wear(true, true)
	# Kept in cards/sets/4ed/, first printed in Antiquities and Arabian Nights.
	assert_eq(_key("Strip Mine"), "card_frame_land_atq")
	assert_eq(_key("Mishra's Factory"), "card_frame_land_atq")
	assert_eq(_key("Oasis"), "card_frame_land_arn", "no mana at all")
	assert_eq(_key("Urza's Tower"), "card_frame_land_atq")
	assert_eq(_key("Library of Alexandria"), "card_frame_land_arn")
	assert_eq(_key("Bazaar of Baghdad"), "card_frame_land_arn")
	assert_eq(_key("Maze of Ith"), "card_frame_land_drk")
	assert_eq(_key("The Tabernacle at Pendrell Vale"), "card_frame_land_leg")
	assert_eq(_key("City of Brass"), "card_frame_land_arn", "any color: the set's, not white")
	assert_eq(_key("Arena"), MiniCard.NEUTRAL_LAND_FRAME, "a set with no land frame of its own")


func test_lands_of_one_color_and_other_cards_keep_their_frames() -> void:
	for sets in [true, false]:
		_wear(true, sets)
		assert_eq(_key("Forest"), "card_frame_land_green")
		assert_eq(_key("Tundra"), "card_frame_land_white", "a dual shows its first color")
		assert_eq(_key("Karakas"), "card_frame_land_white")
		assert_eq(_key("Ornithopter"), "card_frame_artifact")
		assert_eq(_key("Savannah Lions"), "card_frame_white")


func test_a_skin_built_before_the_set_frames_falls_back_to_the_neutral_land() -> void:
	_wear(true, false)
	for card_name in ["Strip Mine", "Mishra's Factory", "Oasis", "Maze of Ith", "City of Brass",
			"Library of Alexandria", "The Tabernacle at Pendrell Vale", "Arena"]:
		assert_eq(_key(card_name), MiniCard.NEUTRAL_LAND_FRAME, card_name)
		var strip := MiniCard.frame_strip(CardRegistry.get_card(card_name)) as AtlasTexture
		assert_not_null(strip, card_name)
		assert_same(strip.atlas, GameSkin.texture(MiniCard.NEUTRAL_LAND_FRAME), card_name)
	assert_true(MiniCard.NEUTRAL_LAND_FRAME in OLD_KEYS, "a frame every skin has")


func test_no_land_in_the_pool_wears_the_artifact_frame() -> void:
	for worn in [[true, true], [true, false], [false, false]]:
		_wear(worn[0], worn[1])
		var wrong: Array[String] = []
		for card_name: String in CardRegistry.all_names():
			var d := CardRegistry.get_card(card_name)
			if d == null or not d.is_land() or d.set_code == CommunityCard.SET_CODE:
				continue
			var key := MiniCard.frame_skin_key(d)
			if not key.begins_with("card_frame_land_"):
				wrong.append("%s: %s" % [card_name, key])
		assert_eq(wrong, [] as Array[String], "skin %s" % [worn])


func test_colorless_first_then_a_color_and_later_sets() -> void:
	var pain := _land("Test Pain Land", "ice", [Mtg.ManaColor.C, Mtg.ManaColor.W, Mtg.ManaColor.U])
	var later := _land("Test Waste", "tmp", [Mtg.ManaColor.C])
	var silent := _land("Test Vault", "fem", [])
	var rainbow := _land("Test Rainbow", "vis", Mtg.WUBRG)
	_wear(true, true)
	assert_eq(MiniCard.land_frame_set(pain), "ice")
	assert_eq(MiniCard.land_frame_set(later), "")
	assert_eq(MiniCard.frame_skin_key(pain), "card_frame_land_ice")
	assert_eq(MiniCard.frame_skin_key(silent), "card_frame_land_fem")
	assert_eq(MiniCard.frame_skin_key(later), MiniCard.NEUTRAL_LAND_FRAME)
	assert_eq(MiniCard.frame_skin_key(rainbow), MiniCard.NEUTRAL_LAND_FRAME)
	_wear(true, false)
	assert_eq(MiniCard.frame_skin_key(pain), "card_frame_land_white", "no set frame: its first color")
	assert_eq(MiniCard.frame_skin_key(silent), MiniCard.NEUTRAL_LAND_FRAME)
	assert_eq(MiniCard.frame_skin_key(later), MiniCard.NEUTRAL_LAND_FRAME)


func test_with_no_skin_a_land_reads_as_a_land() -> void:
	_wear(false, false)
	var artifact := MiniCard.frame_color(CardRegistry.get_card("Ornithopter"))
	for card_name in ["Strip Mine", "Mishra's Factory", "Oasis", "City of Brass", "Forest"]:
		var d := CardRegistry.get_card(card_name)
		assert_null(GameSkin.texture(MiniCard.frame_skin_key(d)), card_name)
		assert_null(MiniCard.frame_strip(d), card_name + ": the flat bar")
		assert_eq(MiniCard.frame_color(d), MiniCard.FRAME_LAND, card_name)
		assert_ne(MiniCard.frame_color(d), artifact, card_name)
	var preview := CardPreview.new()
	preview.docked = true
	add_child_autofree(preview)
	preview.size = CardPreview.SIZE
	preview.show_card(CardInstance.new(CardRegistry.get_card("Strip Mine"), 7, 0))
	var box := preview._frame_bg.get_theme_stylebox("panel") as StyleBoxFlat
	assert_not_null(box, "the flat frame")
	if box != null:
		assert_eq(box.border_color, MiniCard.FRAME_LAND)


func test_the_enlarged_card_and_the_title_strip_wear_the_set_frame() -> void:
	_wear(true, true)
	var mine := CardRegistry.get_card("Strip Mine")
	var worn := GameSkin.texture("card_frame_land_atq")
	var strip := MiniCard.frame_strip(mine) as AtlasTexture
	assert_not_null(strip)
	assert_same(strip.atlas, worn, "the title strip (small cards, hand rows, the deck builder's drag)")
	var preview := CardPreview.new()
	preview.docked = true
	add_child_autofree(preview)
	preview.size = CardPreview.SIZE
	preview.show_card(CardInstance.new(mine, 7, 0))
	var box := preview._frame_bg.get_theme_stylebox("panel") as StyleBoxTexture
	assert_not_null(box, "the skinned frame")
	if box != null:
		assert_same(box.texture, worn)
	# The skin loses the six (an older zip chosen): the same card, the neutral land.
	_wear(true, false)
	preview.show_card(CardInstance.new(mine, 8, 0))
	box = preview._frame_bg.get_theme_stylebox("panel") as StyleBoxTexture
	assert_not_null(box)
	if box != null:
		assert_same(box.texture, GameSkin.texture(MiniCard.NEUTRAL_LAND_FRAME))
