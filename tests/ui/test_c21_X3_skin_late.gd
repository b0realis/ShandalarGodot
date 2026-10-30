extends GutTest
## A SKIN THAT ARRIVES MID-SESSION DRESSES EVERY DUEL AFTER IT (0.50.66 bug
## campaign, h4-1). The duel's warm-up ([DuelWarmup], 0.50.66) asks for each
## seat colour's exile plate and hand window before any duel — on the
## Gauntlet screen, the Magic Battle setup, arriving in the world — and the
## caches behind them ([ExilePlate], [method StackHand.window_texture], the
## small cards' title strips [method MiniCard.frame_strip]) kept the null
## they found while no skin was worn. A skin dropped on the title later
## (the first-skin path: the title is rebuilt, nothing says "next start")
## then left every duel of the session in the plain hand window, without
## exile plates, with flat strips. And the Combat Bar's keyed columns,
## kept by rectangle alone, went on handing out a zip's columns after
## another zip replaced it. Each is now kept with the picture it was made
## of, as [method OriginalDialog.stone_job]'s stones are.
##
## The same fault, the same cure, in the other pictures cut from the skin
## (the lead's follow-up): the mana symbols and the deck rows' pips
## ([ManaIcons]), the set symbols ([SetBadges]), the counters' stones
## ([CounterMarks]), the Deck Builder's filter medallions and stones
## ([FilterBar]) and a territory's measured edge ([TerritoryGround]).
##
## The skin here is a scratch folder of small fixture pictures, so the file
## runs with or without the imported 1997 skin; "no skin" is the fixture's
## places answered null in [GameSkin]'s own cache, as a session with no
## skin has them.

const SCRATCH := "user://test_c21_x3_skin_late"
const SKIN := SCRATCH + "/skin"
const KEYS: Array[String] = [GamePaths.KEY_SKIN_FOLDER, GamePaths.KEY_USE_SKIN_FOLDER]
const PALETTE: Array[Color] = [Color.BLACK, Color.WHITE, Color(0.18, 0.18, 0.18),
	Color(0.62, 0.20, 0.18), Color(0.20, 0.35, 0.70), Color(0.30, 0.62, 0.28),
	Color(0.80, 0.70, 0.30), Color(0.49, 0.35, 0.36)]

var _saved: Dictionary = {}
var _was_worn := false


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(SKIN)
	_saved = {}
	for key in KEYS:
		_saved[key] = Settings.get_value(key, null) if Settings.has_value(key) else null
		Settings.clear_value(key)
	Settings.set_value(GamePaths.KEY_SKIN_FOLDER, SKIN)
	_was_worn = GameSkin.zip_worn
	GameSkin.zip_worn = false
	GameSkin.clear_caches()


func after_each() -> void:
	for key in KEYS:
		if _saved[key] == null:
			Settings.clear_value(key)
		else:
			Settings.set_value(key, _saved[key])
	GameSkin.zip_worn = _was_worn
	_wipe(SCRATCH)
	GameSkin.clear_caches()


static func _wipe(folder: String) -> void:
	for sub in DirAccess.get_directories_at(folder):
		_wipe(folder.path_join(sub))
	for file in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)


static func _blocks(size: Vector2i, salt := 0) -> Image:
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var h := ((x / 3) * 73856093) ^ ((y / 3) * 19349663) ^ (salt * 83492791)
			img.set_pixel(x, y, PALETTE[absi(h) % PALETTE.size()])
	return img


## No skin worn for [param keys]: each place answers null, as in a session
## that started without one.
func _nothing_worn(keys: Array[String]) -> void:
	GameSkin.clear_caches()
	for key in keys:
		GameSkin._texture_cache[key] = null
		assert_null(GameSkin.texture(key), "control: %s is not worn" % key)


## The skin arrives with [param keys] (fixtures at their 1997 slot's size,
## [param salt] tells two skins apart) — [method SkinPack._arrived]'s
## [method GameSkin.clear_caches].
func _arrives(keys: Array[String], salt := 0, sizes := {}) -> void:
	for key in keys:
		_blocks(sizes.get(key, GameSkin.SIZES[key]), salt).save_png(
			ProjectSettings.globalize_path(SKIN.path_join(key + ".png")))
	GameSkin.clear_caches()
	for key in keys:
		assert_not_null(GameSkin.texture(key), "control: %s is worn now" % key)


func _same_image(a: Texture2D, b: Texture2D) -> bool:
	return a != null and b != null and a.get_image().get_data() == b.get_image().get_data()


# ----------------------------------------------------------------- tests --

func test_the_exile_plate_waits_for_the_skin() -> void:
	var keys: Array[String] = ["grave_panel_white"]
	_nothing_worn(keys)
	assert_null(ExilePlate.plate("white"), "no grave plate: no exile plate")
	_arrives(keys)
	var plate := ExilePlate.plate("white")
	assert_not_null(plate, "the skin arrived: the plate is painted (it was the null kept)")
	assert_same(ExilePlate.plate("white"), plate, "and kept: painted once")
	assert_eq(plate.get_size(), GameSkin.texture("grave_panel_white").get_size(),
		"the grave plate's own size")
	_arrives(keys, 1)
	var again := ExilePlate.plate("white")
	assert_ne(again, plate, "another skin: painted again")
	assert_false(_same_image(again, plate), "from its own grave plate's palette")


func test_the_hand_window_waits_for_the_skin() -> void:
	var keys: Array[String] = ["hand_panel_white"]
	_nothing_worn(keys)
	assert_null(StackHand.window_texture("white"), "no picture: the plain window")
	_arrives(keys)
	var window := StackHand.window_texture("white")
	assert_not_null(window, "the skin arrived: the 1997 window (it was the null kept)")
	assert_same(StackHand.window_texture("white"), window, "and kept: made once")
	assert_eq(window.get_width(), 145 + int(StackHand.BORDER), "made whole: the left border mirrored")
	_arrives(keys, 1)
	var again := StackHand.window_texture("white")
	assert_ne(again, window, "another skin: made again")
	assert_false(_same_image(again, window), "of its own picture")


func test_the_small_cards_title_strip_waits_for_the_skin() -> void:
	var lions := CardRegistry.get_card("Savannah Lions")
	assert_eq(MiniCard.frame_skin_key(lions), "card_frame_white", "control: a white card's frame")
	var keys: Array[String] = ["card_frame_white"]
	_nothing_worn(keys)
	assert_null(MiniCard.frame_strip(lions), "no frame: the flat bar")
	_arrives(keys)
	var strip := MiniCard.frame_strip(lions) as AtlasTexture
	assert_not_null(strip, "the skin arrived: the marble strip (it was the null kept)")
	assert_same(MiniCard.frame_strip(lions), strip, "and kept")
	assert_same(strip.atlas, GameSkin.texture("card_frame_white"), "cut from the frame worn")
	_arrives(keys, 1)
	var again := MiniCard.frame_strip(lions) as AtlasTexture
	assert_same(again.atlas, GameSkin.texture("card_frame_white"),
		"another skin: cut from its frame, not the one before")


func test_the_badges_and_sprites_wait_for_the_skin() -> void:
	var keys: Array[String] = ["ability_icons", "summon_sick"]
	_nothing_worn(keys)
	assert_null(MiniCard.badge_from_slot(2), "no sheet: no badge")
	assert_null(MiniCard.masked_sprite("summon_sick"), "no sheet, none of ours: no sprite")
	_arrives(keys)
	var badge := MiniCard.badge_from_slot(2)
	var sprite := MiniCard.masked_sprite("summon_sick")
	assert_not_null(badge, "the skin arrived: the badge is cut")
	assert_not_null(sprite, "and the sprite")
	assert_same(MiniCard.badge_from_slot(2), badge, "kept")
	assert_same(MiniCard.masked_sprite("summon_sick"), sprite, "kept")
	_arrives(keys, 1)
	assert_false(_same_image(MiniCard.badge_from_slot(2), badge), "another skin: its own badge")
	assert_false(_same_image(MiniCard.masked_sprite("summon_sick"), sprite), "and its own sprite")
	assert_same(MiniCard.shadow_badge(), MiniCard.shadow_badge(),
		"the shadow badge, ours, still drawn once")


func test_a_combat_bar_column_is_the_sheet_worn() -> void:
	var keys: Array[String] = ["combat_bar"]
	_arrives(keys)
	var region := CombatBar.column_region(true)
	var first := CombatBar.keyed_texture(region, CombatBar.Fill.BLACK)
	assert_not_null(first)
	assert_same(CombatBar.keyed_texture(region, CombatBar.Fill.BLACK), first, "kept")
	assert_true(CombatBar.keyed_job(region, CombatBar.Fill.BLACK).is_empty(), "kept: no job")
	_arrives(keys, 1)
	assert_false(CombatBar.keyed_job(region, CombatBar.Fill.BLACK).is_empty(),
		"a zip replaced the zip: the column is keyed again")
	var second := CombatBar.keyed_texture(region, CombatBar.Fill.BLACK)
	assert_ne(second, first, "not the old sheet's column")
	assert_false(_same_image(second, first), "the new sheet's pixels")
	CombatBar._keyed.clear()


func test_a_duel_after_a_late_skin_is_fully_dressed() -> void:
	# The session began with no skin, and the warm-up asked for the white
	# seat's small ones (the Gauntlet screen, the Magic Battle setup).
	var keys: Array[String] = ["grave_panel_white", "hand_panel_white"]
	_nothing_worn(keys)
	var warmup := DuelWarmup.new()
	warmup._colors = ["white", "white"] as Array[String]
	warmup._small_ones()
	while not (warmup._small as Array).is_empty():
		((warmup._small as Array).pop_front() as Callable).call()
	warmup.free()
	# The skin is dropped on the title; Magic Battle, white against white.
	_arrives(keys)
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 1000.0
	config.panel_colors = ["white", "white"]
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	for pid in 2:
		var icon: TextureRect = screen._exile_icons[pid]
		assert_not_null(icon.texture, "seat %d: the exile plate" % pid)
		assert_same(icon.texture, ExilePlate.plate("white"), "seat %d: painted from the skin worn" % pid)
	var hands := 0
	for child in screen.get_children():
		if child is StackHand:
			hands += 1
			assert_not_null((child as StackHand)._frame.texture, "a hand window in the 1997 chrome")
			assert_true((child as StackHand)._frame.visible, "worn, not the plain stand-in")
	assert_gt(hands, 0, "control: the table has its hand windows")


# ------------------------------------------- the follow-up: five more --

func test_the_mana_symbols_and_pips_wait_for_the_skin() -> void:
	var keys: Array[String] = ["mana_symbols"]
	_nothing_worn(keys)
	assert_null(ManaIcons.symbol("W"), "no sheet: the braces")
	var discs := ManaIcons.color_strip(Mtg.ManaColor.W, 14)
	assert_not_null(discs, "no sheet: the deck row's flat disc")
	_arrives(keys)
	var white := ManaIcons.symbol("W")
	assert_not_null(white, "the skin arrived: the 1997 symbol (it was the null kept)")
	assert_same(ManaIcons.symbol("W"), white, "and kept")
	var pips := ManaIcons.color_strip(Mtg.ManaColor.W, 14)
	assert_false(_same_image(pips, discs), "the deck row wears the symbol, not the disc")
	_arrives(keys, 1)
	assert_false(_same_image(ManaIcons.symbol("W"), white), "another skin: its own symbol")


func test_the_set_symbols_wait_for_the_skin() -> void:
	var keys: Array[String] = ["card_set_symbols"]
	_nothing_worn(keys)
	var ours := SetBadges.symbol("drk")
	_arrives(keys)
	var printed := SetBadges.symbol("drk")
	assert_not_null(printed, "the skin arrived: the printed symbol")
	assert_false(_same_image(printed, ours), "cut from the strip, not ours kept from before")
	assert_same(SetBadges.symbol("drk"), printed, "and kept")
	_arrives(keys, 1)
	assert_false(_same_image(SetBadges.symbol("drk"), printed), "another skin: its own")


func test_the_counter_stones_wait_for_the_skin() -> void:
	var keys: Array[String] = ["card_counters"]
	_nothing_worn(keys)
	assert_null(CounterMarks.tile(0), "no strip: no stone")
	_arrives(keys)
	var stone := CounterMarks.tile(0)
	assert_not_null(stone, "the skin arrived: the stone (it was the null kept)")
	assert_same(CounterMarks.tile(0), stone, "and kept")
	_arrives(keys, 1)
	assert_false(_same_image(CounterMarks.tile(0), stone), "another skin: its own")


func test_the_filter_medallions_and_stones_wait_for_the_skin() -> void:
	var keys: Array[String] = ["filter_icons", "panel_dark_stone"]
	var small := {"panel_dark_stone": Vector2i(130, 110)}
	_nothing_worn(keys)
	assert_null(FilterBar.sheet_cell("filter_icons", 0, 0), "no sheet: the lettered stand-in")
	assert_null(FilterBar.sheet_cell("filter_icons", FilterBar.DICE_CELL[0], FilterBar.DICE_CELL[1]),
		"nor the dice drawn on its disc")
	assert_true(FilterBar._stone(Color.WHITE) is StyleBoxFlat, "no stone: the flat face")
	_arrives(keys, 0, small)
	var cell := FilterBar.sheet_cell("filter_icons", 0, 0)
	assert_not_null(cell, "the skin arrived: the medallion (it was the null kept)")
	assert_same(FilterBar.sheet_cell("filter_icons", 0, 0), cell, "and kept")
	assert_not_null(FilterBar.sheet_cell("filter_icons", FilterBar.DICE_CELL[0], FilterBar.DICE_CELL[1]),
		"the dice on the sheet's disc")
	assert_true(FilterBar._stone(Color.WHITE) is StyleBoxTexture, "the letters on stone now")
	_arrives(keys, 1, small)
	assert_false(_same_image(FilterBar.sheet_cell("filter_icons", 0, 0), cell), "another skin: its own")


func test_a_territory_is_measured_on_the_file_worn() -> void:
	var key := "duel_pattern_red"
	var framed := Image.create_empty(64, 48, false, Image.FORMAT_RGBA8)
	framed.fill(Color(0.5, 0.3, 0.3))
	for x in 64:
		framed.set_pixel(x, 0, Color.BLACK)
		framed.set_pixel(x, 47, Color.BLACK)
	for y in 48:
		framed.set_pixel(0, y, Color.BLACK)
		framed.set_pixel(63, y, Color.BLACK)
	framed.save_png(ProjectSettings.globalize_path(SKIN.path_join(key + ".png")))
	GameSkin.clear_caches()
	assert_eq(TerritoryGround._inner(key, GameSkin.texture(key)), Rect2i(1, 1, 62, 46),
		"control: a file with the conversion edge loses it")
	var bare := Image.create_empty(64, 48, false, Image.FORMAT_RGBA8)
	bare.fill(Color(0.5, 0.3, 0.3))
	bare.save_png(ProjectSettings.globalize_path(SKIN.path_join(key + ".png")))
	GameSkin.clear_caches()
	assert_eq(TerritoryGround._inner(key, GameSkin.texture(key)), Rect2i(0, 0, 64, 48),
		"a zip that replaced the zip: its file measured, not the old one's edge")
	TerritoryGround._edge_cache.erase(key)
