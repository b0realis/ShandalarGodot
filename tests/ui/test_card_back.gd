extends GutTest
## `[QoL]` YOUR OWN CARD BACK ([CardBack], `game/card_back.gd`) and the
## Options rows that choose it (`game/options_screen.gd`,
## `_add_card_back_section`). The owner, 2026-10-19: *"lets implement also
## an option in settings so user can use his own photo as card back (lets
## also document and tell the user what format and pixel*pixel the game
## expects the file to be!)"*. The file box itself is the platform's and
## is not opened here; what it hands back ([method CardBack.adopt]) is.

const SCRATCH := "user://card_back_test"
const KEPT := SCRATCH + "/kept"
const PLACE := KEPT + "/card_back.png"
const OPTIONS := preload("res://game/options_screen.gd")

var _pinned: Dictionary
var _seasons: Variant = null


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCRATCH))
	CardBack.place = PLACE
	CardBack.forget_cache()
	_pinned = GameSkin.season_date.duplicate()
	_seasons = Settings.get_value(GameSkin.KEY_SEASONS, null) \
		if Settings.has_value(GameSkin.KEY_SEASONS) else null
	Settings.clear_value(GameSkin.KEY_SEASONS)


func after_each() -> void:
	CardBack.forget()
	CardBack.place = ""
	CardBack.forget_cache()
	GameSkin.season_date = _pinned
	if _seasons == null:
		Settings.clear_value(GameSkin.KEY_SEASONS)
	else:
		Settings.set_value(GameSkin.KEY_SEASONS, _seasons)
	_remove_tree(ProjectSettings.globalize_path(SCRATCH))


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_remove_tree(path.path_join(sub))
	for file in dir.get_files():
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


## A [param w] x [param h] picture in three bands across ([param across])
## or down: outer, middle, outer.
func _banded(w: int, h: int, across: bool, outer: Color, middle: Color) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(outer)
	if across:
		img.fill_rect(Rect2i(w / 3, 0, w - 2 * (w / 3), h), middle)
	else:
		img.fill_rect(Rect2i(0, h / 3, w, h - 2 * (h / 3)), middle)
	return img


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.25


## [param jpeg] with an EXIF APP1 segment saying [param orientation],
## in Intel ("II") or Motorola ("MM") byte order, right after its SOI.
func _with_exif(jpeg: PackedByteArray, orientation: int, little: bool) -> PackedByteArray:
	var tiff: PackedByteArray
	if little:
		tiff = PackedByteArray([0x49, 0x49, 0x2A, 0, 8, 0, 0, 0,
			1, 0,
			0x12, 0x01, 3, 0, 1, 0, 0, 0, orientation, 0, 0, 0,
			0, 0, 0, 0])
	else:
		tiff = PackedByteArray([0x4D, 0x4D, 0, 0x2A, 0, 0, 0, 8,
			0, 1,
			0x01, 0x12, 0, 3, 0, 0, 0, 1, 0, orientation, 0, 0,
			0, 0, 0, 0])
	var body := PackedByteArray([0x45, 0x78, 0x69, 0x66, 0, 0]) + tiff
	var length := body.size() + 2
	var segment := PackedByteArray([0xFF, 0xE1, length >> 8, length & 0xFF]) + body
	return jpeg.slice(0, 2) + segment + jpeg.slice(2)


func _save(img: Image, path: String) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	assert_eq(img.save_png(path), OK, "the test picture is written")
	return path


func test_a_card_back_is_twice_the_1997_back_and_a_cards_shape() -> void:
	assert_eq(CardBack.SIZE, Vector2i(GameSkin.SIZES["card_back"]) * 2)
	var aspect := float(CardBack.SIZE.x) / CardBack.SIZE.y
	var card := CardPreview.SIZE.x / CardPreview.SIZE.y
	assert_almost_eq(aspect, card, card * 0.02)


func test_the_kept_picture_lives_in_the_game_folder() -> void:
	CardBack.place = ""
	assert_eq(CardBack.file(), GamePaths.card_back())
	assert_eq(GamePaths.card_back(), GamePaths.DEFAULT_CARD_BACK, "a desktop keeps it in user://")
	CardBack.place = PLACE
	assert_eq(CardBack.candidates(), [KEPT + "/card_back.png", KEPT + "/card_back.jpg",
		KEPT + "/card_back.jpeg", KEPT + "/card_back.webp"])


func test_a_wide_picture_loses_its_sides() -> void:
	var fitted := CardBack.fitted(_banded(900, 300, true, Color.RED, Color.GREEN))
	assert_eq(fitted.get_size(), CardBack.SIZE)
	for p in [Vector2i(1, 1), Vector2i(454, 1), Vector2i(1, 644), Vector2i(454, 644)]:
		assert_true(_near(fitted.get_pixelv(p), Color.GREEN), "%s is the middle" % p)


func test_a_tall_picture_loses_its_top_and_bottom() -> void:
	var fitted := CardBack.fitted(_banded(100, 1000, false, Color.RED, Color.GREEN))
	assert_eq(fitted.get_size(), CardBack.SIZE)
	for p in [Vector2i(1, 1), Vector2i(454, 1), Vector2i(1, 644), Vector2i(454, 644)]:
		assert_true(_near(fitted.get_pixelv(p), Color.GREEN), "%s is the middle" % p)


func test_a_card_shaped_picture_is_kept_whole() -> void:
	# A scan of a real card back: 488x680 is 63x88 mm, a hair off the
	# 1997 back's shape — stretched that hair, not trimmed.
	assert_eq(CardBack.trim_rect(Vector2i(488, 680)), Rect2i(0, 0, 488, 680))
	assert_eq(CardBack.trim_rect(CardBack.SIZE), Rect2i(Vector2i.ZERO, CardBack.SIZE))
	var img := Image.create(488, 680, false, Image.FORMAT_RGBA8)
	img.fill(Color.GREEN)
	img.fill_rect(Rect2i(0, 0, 20, 680), Color.BLUE)
	var fitted := CardBack.fitted(img)
	assert_true(_near(fitted.get_pixel(3, 323), Color.BLUE), "the left border stays")


func test_a_big_photo_is_brought_down_to_size() -> void:
	var fitted := CardBack.fitted(_banded(1824, 2584, true, Color.RED, Color.GREEN))
	assert_eq(fitted.get_size(), CardBack.SIZE)
	assert_eq(fitted.get_format(), Image.FORMAT_RGBA8)


func test_the_three_kinds_are_known_by_their_bytes() -> void:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.ORANGE)
	var kinds := {"png": img.save_png_to_buffer(), "jpg": img.save_jpg_to_buffer(),
		"webp": img.save_webp_to_buffer()}
	for kind in kinds:
		assert_eq(CardBack.kind_of(kinds[kind]), kind)
		assert_not_null(CardBack.image_from_bytes(kinds[kind]), kind)
	var gif := "GIF89a".to_ascii_buffer()
	gif.resize(64)
	assert_eq(CardBack.kind_of(gif), "")
	assert_null(CardBack.image_from_bytes(gif))
	assert_eq(CardBack.kind_of(PackedByteArray()), "")
	assert_eq(CardBack.adopt_bytes("hello".to_ascii_buffer()), CardBack.NOT_A_PICTURE)
	assert_false(CardBack.has_own(), "nothing was kept")


func test_a_phone_photo_is_turned_the_way_it_was_held() -> void:
	# Stored landscape, red on the left: held upright and turned 90
	# degrees clockwise to show (EXIF 6), red is at the top.
	var stored := Image.create(64, 32, false, Image.FORMAT_RGB8)
	stored.fill(Color.BLUE)
	stored.fill_rect(Rect2i(0, 0, 32, 32), Color.RED)
	var plain := stored.save_jpg_to_buffer(0.95)
	assert_eq(CardBack.exif_orientation(plain), 1, "no EXIF: as stored")
	assert_eq(CardBack.exif_orientation(stored.save_png_to_buffer()), 1, "not a JPEG")
	for little in [true, false]:
		var held := _with_exif(plain, 6, little)
		assert_eq(CardBack.exif_orientation(held), 6, "byte order %s" % ("II" if little else "MM"))
		var shown := CardBack.oriented(CardBack.image_from_bytes(held), 6)
		assert_eq(shown.get_size(), Vector2i(32, 64))
		assert_true(_near(shown.get_pixel(16, 8), Color.RED), "red is at the top")
		assert_true(_near(shown.get_pixel(16, 56), Color.BLUE))
	assert_eq(CardBack.exif_orientation(_with_exif(plain, 3, false)), 3)
	assert_eq(CardBack.exif_orientation(_with_exif(plain, 9, true)), 1, "no such orientation")


func test_a_cut_short_exif_block_reads_as_stored() -> void:
	var stored := Image.create(8, 8, false, Image.FORMAT_RGB8)
	var held := _with_exif(stored.save_jpg_to_buffer(), 6, true)
	# The segment's length cut to before its one entry ends.
	held[4] = 0
	held[5] = 20
	assert_eq(CardBack.exif_orientation(held), 1)
	assert_eq(CardBack.exif_orientation(held.slice(0, 24)), 1, "a file that stops inside it")


func test_choosing_a_picture_keeps_a_fitted_copy() -> void:
	var photo := _save(_banded(600, 400, true, Color.RED, Color.GREEN), SCRATCH + "/photo.png")
	assert_eq(CardBack.adopt(photo), "")
	assert_true(FileAccess.file_exists(PLACE), "the copy is kept")
	var kept := Image.load_from_file(ProjectSettings.globalize_path(PLACE))
	assert_eq(kept.get_size(), CardBack.SIZE, "kept at the size it is drawn")
	assert_true(FileAccess.file_exists(photo), "the photo itself is not touched")
	var back := GameSkin.texture("card_back")
	assert_not_null(back)
	assert_eq(back, CardBack.texture(), "every card back is it")
	if back != null:
		assert_eq(Vector2i(back.get_width(), back.get_height()), Vector2i(GameSkin.SIZES["card_back"]),
			"drawn at the 1997 back's size, like the 2x skin's")
		assert_eq(GameSkin.scale_of(back), 2)


func test_your_back_is_worn_over_the_seasons() -> void:
	GameSkin.season_date = {"month": 10, "day": 31}
	var moon := GameSkin.our_art("card_back_moon")
	assert_eq(GameSkin.texture("card_back"), moon)
	CardBack.adopt(_save(_banded(300, 420, true, Color.RED, Color.GREEN), SCRATCH + "/mine.png"))
	assert_eq(GameSkin.texture("card_back"), CardBack.texture())
	CardBack.forget()
	assert_eq(GameSkin.texture("card_back"), moon, "and the season again once it is gone")


func test_removing_it_brings_back_the_back_there_was() -> void:
	var before := GameSkin.texture("card_back")
	var photo := _save(_banded(300, 420, true, Color.RED, Color.GREEN), SCRATCH + "/mine.png")
	CardBack.adopt(photo)
	assert_true(CardBack.has_own())
	CardBack.forget()
	assert_false(CardBack.has_own())
	assert_false(FileAccess.file_exists(PLACE))
	assert_true(FileAccess.file_exists(photo), "only the game's copy goes")
	assert_eq(GameSkin.texture("card_back"), before)
	assert_eq(GameSkin.texture("card_back"), GameSkin.skin_texture("card_back"))


func test_a_picture_put_there_by_hand_is_worn_and_fitted() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(KEPT))
	var img := _banded(900, 300, true, Color.RED, Color.GREEN)
	var jpg := FileAccess.open(KEPT + "/card_back.jpg", FileAccess.WRITE)
	jpg.store_buffer(img.save_jpg_to_buffer(0.95))
	jpg.close()
	assert_eq(CardBack.found(), KEPT + "/card_back.jpg")
	var back := CardBack.texture()
	assert_not_null(back)
	if back != null:
		assert_eq(back.get_image().get_size(), CardBack.SIZE)
		assert_true(_near(back.get_image().get_pixel(2, 2), Color.GREEN), "trimmed as it is read")
	# The bytes say what it is, not the name: a JPEG called card_back.png.
	CardBack.forget()
	var misnamed := FileAccess.open(PLACE, FileAccess.WRITE)
	misnamed.store_buffer(img.save_jpg_to_buffer(0.95))
	misnamed.close()
	assert_not_null(CardBack.texture())


func test_what_is_not_a_picture_is_refused_with_why() -> void:
	assert_eq(CardBack.adopt(SCRATCH + "/not_there.png"), CardBack.NOT_READ)
	var notes := FileAccess.open(SCRATCH + "/notes.png", FileAccess.WRITE)
	notes.store_string("not a picture at all")
	notes.close()
	assert_eq(CardBack.adopt(SCRATCH + "/notes.png"), CardBack.NOT_A_PICTURE)
	assert_string_contains(CardBack.NOT_A_PICTURE, "PNG, JPG or WEBP")
	assert_false(CardBack.has_own())


func test_a_face_down_card_wears_the_new_back() -> void:
	var lions := CardInstance.new(CardRegistry.get_card("Savannah Lions"), 1, 0)
	var card := MiniCard.new(lions)
	add_child_autofree(card)
	card.face_down = true
	CardBack.adopt(_save(_banded(300, 420, true, Color.RED, Color.GREEN), SCRATCH + "/mine.png"))
	card.refresh()
	var box := card.get_theme_stylebox("normal") as StyleBoxTexture
	assert_not_null(box, "a picture back")
	if box != null:
		assert_eq(box.texture, CardBack.texture(), "the shared box was not the old back's")
	var other := MiniCard.new(lions)
	add_child_autofree(other)
	other.face_down = true
	var other_box := other.get_theme_stylebox("normal") as StyleBoxTexture
	assert_not_null(other_box)
	if other_box != null:
		assert_eq(other_box.texture, CardBack.texture())


func test_the_rows_words() -> void:
	assert_eq(OPTIONS.card_back_line("~/x/card_back.png", true, true),
		"Your picture: ~/x/card_back.png", "yours first, whatever the day")
	assert_eq(OPTIONS.card_back_line("", true, true), "The season's back")
	assert_eq(OPTIONS.card_back_line("", false, true), "The skin's back")
	assert_eq(OPTIONS.card_back_line("", false, false), "The game's plain back")


func test_the_options_rows() -> void:
	var screen: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var status := screen.find_child("CardBackStatus", true, false) as Label
	var remove := screen.find_child("RemoveCardBack", true, false) as Button
	var note := screen.find_child("CardBackNote", true, false) as Label
	assert_not_null(screen.find_child("ChooseCardBack", true, false))
	assert_not_null(status)
	assert_not_null(remove)
	assert_not_null(note)
	if status == null or remove == null or note == null:
		return
	assert_false(status.text.begins_with("Your picture"))
	assert_false(remove.visible, "nothing of yours to remove")
	assert_string_contains(note.text, "PNG, JPG or WEBP")
	assert_string_contains(note.text, "456 x 646")
	CardBack.adopt(_save(_banded(300, 420, true, Color.RED, Color.GREEN), SCRATCH + "/mine.png"))
	screen._refresh_card_back()
	assert_true(status.text.begins_with("Your picture: "))
	assert_true(status.text.ends_with("card_back.png"))
	assert_true(remove.visible)
	var thumb := screen.find_child("CardBackThumb", true, false) as Panel
	var box := thumb.get_theme_stylebox("panel") as StyleBoxTexture
	assert_not_null(box)
	if box != null:
		assert_eq(box.texture, CardBack.texture(), "the small card is yours")
	remove.pressed.emit()
	assert_false(CardBack.has_own())
	assert_false(remove.visible)
	assert_false(status.text.begins_with("Your picture"))


func test_a_refusal_is_said_on_the_screen() -> void:
	var screen: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var problem := screen.find_child("CardBackProblem", true, false) as Label
	assert_not_null(problem)
	if problem == null:
		return
	assert_false(problem.visible)
	screen._show_card_back_problem(CardBack.adopt(SCRATCH + "/not_there.png"))
	assert_true(problem.visible)
	assert_eq(problem.text, CardBack.NOT_READ)


func test_the_seasons_switch_is_a_view_of_its_key() -> void:
	var screen: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var seasons := screen.find_child("SeasonalBacks", true, false) as CheckButton
	assert_not_null(seasons)
	if seasons == null:
		return
	assert_true(seasons.button_pressed, "on by default")
	assert_false(Settings.has_value(GameSkin.KEY_SEASONS), "and the default is not written")
	seasons.button_pressed = false
	assert_eq(Settings.get_value(GameSkin.KEY_SEASONS, true), false)
	assert_false(GameSkin.seasons_on())
	seasons.button_pressed = true
	assert_false(Settings.has_value(GameSkin.KEY_SEASONS), "back on clears it")
	assert_true(GameSkin.seasons_on())
