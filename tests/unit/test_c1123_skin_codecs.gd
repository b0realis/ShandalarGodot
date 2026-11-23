extends GutTest
## THE 1997 FORMATS THE SKIN BUILDER READS (builders 2026-11-23): `.pic`
## pictures and their palettes, `.spr` sprites, the wizards' window's
## bitmaps, and the text rules the lists are read by. Every file here is
## made in the test ([C1123SkinFixtures]); the same rules are pinned for
## the Python tool in `tools/test_import_original.py`.
##
## Three things are held for each decoder: it gives back what an encoder
## written apart from it put in, it refuses what is not its format in
## words, and no cut or scrambled file makes it crash or run on.

const F := preload("res://tests/support/c1123_skin_fixtures.gd")


func _codes(codes: Array, max_bits := 11) -> Dictionary:
	return SkinPicCodec._lzw(F.pack_codes(codes, max_bits), 0, max_bits)


# -------------------------------------------------------------- the LZW --

func test_literals_pass_straight_through() -> void:
	var got := _codes([72, 105, 33])
	assert_eq(got["error"], "")
	assert_eq(got["bytes"], F.bytes([72, 105, 33]))


func test_the_first_free_code_is_257_not_256() -> void:
	# A, B, then 257 = "AB": the entry made when B was read.
	assert_eq(_codes([65, 66, 257])["bytes"], F.bytes([65, 66, 65, 66]))
	# 257 straight after A is the entry being made: A and its first byte.
	assert_eq(_codes([65, 257])["bytes"], F.bytes([65, 65, 65]))


func test_code_256_is_an_empty_entry() -> void:
	assert_eq(_codes([65, 256, 66])["bytes"], F.bytes([65, 66]))
	# And the entries made around it: 257 is "A", 258 is "B".
	assert_eq(_codes([65, 256, 66, 257, 258])["bytes"], F.bytes([65, 66, 65, 66]))


func test_a_code_ahead_of_the_dictionary_is_refused() -> void:
	assert_ne(_codes([65, 300])["error"], "")


func test_a_group_must_start_with_a_literal() -> void:
	assert_ne(_codes([300])["error"], "")


func test_the_width_goes_9_10_11_and_back_with_the_dictionary() -> void:
	# 1792 literals fill a group; the next code is read at 9 bits again
	# and must be a literal — 257 there is refused.
	var codes: Array = []
	for i in 1792:
		codes.append(i % 251)
	var whole := _codes(codes + [65, 257])
	assert_eq(whole["error"], "")
	assert_eq((whole["bytes"] as PackedByteArray).size(), 1792 + 3)
	assert_ne(_codes(codes + [257])["error"], "", "a new group starts with a literal")


func test_a_real_lzw_over_runs_comes_back_whole() -> void:
	# Long enough to cross both width changes and a dictionary restart.
	var pixels := F.noise(3000, 3, 6)
	pixels.append_array(SkinPicCodec.zeros(900, 0x90))
	pixels.append_array(F.noise(2500, 4, 256))
	pixels.append_array(SkinPicCodec.zeros(700, 17))
	var codes := F.lzw_codes(F.rle_runs(pixels))
	assert_gt(codes.size(), 1792, "the fixture restarts the dictionary")
	var got := SkinPicCodec.decode(F.make_pic(100, 71, pixels, PackedByteArray(), true))
	assert_eq(got["error"], "")
	assert_eq(got["indices"], pixels)
	for max_bits in [9, 10, 12]:
		var other := SkinPicCodec.decode(F.make_pic(100, 71, pixels, PackedByteArray(), true, max_bits))
		assert_eq(other["indices"], pixels, "%d-bit codes" % max_bits)


# -------------------------------------------------------------- the RLE --

func test_rle() -> void:
	assert_eq(SkinPicCodec._rle(F.bytes([1, 2, 3])), F.bytes([1, 2, 3]), "literals")
	assert_eq(SkinPicCodec._rle(F.bytes([7, 0x90, 4])), F.bytes([7, 7, 7, 7]),
		"the count includes the byte already out")
	assert_eq(SkinPicCodec._rle(F.bytes([7, 0x90, 1, 8])), F.bytes([7, 8]), "a run of one adds nothing")
	assert_eq(SkinPicCodec._rle(F.bytes([7, 0x90, 0, 8])), F.bytes([7, 0x90, 8]), "marker, zero: a literal marker")
	assert_eq(SkinPicCodec._rle(F.bytes([7, 0x90])), F.bytes([7, 0x90]), "a trailing marker is a literal")
	assert_eq(SkinPicCodec._rle(F.bytes([0x90, 5])), F.bytes([0x90, 5]), "the first byte is never a marker")
	assert_eq(SkinPicCodec._rle(PackedByteArray()), PackedByteArray())
	assert_eq(SkinPicCodec._rle(F.bytes([7, 0x90, 200, 9]), 5), SkinPicCodec.zeros(200, 7),
		"a run begun is finished; the caller cuts")


# ------------------------------------------------------------- pictures --

func test_a_picture_and_its_palette_come_back() -> void:
	var pixels := F.noise(6 * 4, 1)
	var got := SkinPicCodec.decode(F.make_pic(6, 4, pixels, F.ramp_palette()))
	assert_eq(got["error"], "")
	assert_eq([got["width"], got["height"]], [6, 4])
	assert_eq(got["indices"], pixels)
	assert_eq(got["palette"], F.ramp_palette())
	assert_true((SkinPicCodec.decode(F.make_pic(6, 4, pixels))["palette"] as PackedByteArray).is_empty(),
		"no palette block: none")


func test_a_partial_palette_lands_at_its_own_place() -> void:
	var file := "M0".to_ascii_buffer() + F.u16(2 + 6) + F.bytes([10, 11, 1, 2, 3, 4, 5, 6])
	file.append_array(F.make_pic(1, 1, F.bytes([0])))
	var palette: PackedByteArray = SkinPicCodec.decode(file)["palette"]
	assert_eq(palette.size(), 768)
	assert_eq(palette.slice(30, 36), F.bytes([1, 2, 3, 4, 5, 6]))
	assert_eq(palette.slice(0, 30), SkinPicCodec.zeros(30))
	assert_true(SkinPicCodec.read_palette(file).is_empty(), "only a whole palette is one to lend")


func test_a_short_picture_is_filled_with_255() -> void:
	var got := SkinPicCodec.decode(F.make_pic(4, 4, F.bytes([1, 2, 3])))
	assert_eq(got["error"], "")
	assert_eq(got["indices"], F.bytes([1, 2, 3]) + SkinPicCodec.zeros(13, 255))


func test_what_is_not_a_1997_picture_is_refused_in_words() -> void:
	var png := F.bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13])
	assert_true(SkinPicCodec.is_png(png))
	assert_string_contains(SkinPicCodec.decode(png)["error"], "not a 1997 picture")
	var unknown := "C0".to_ascii_buffer() + F.u16(2) + F.bytes([1, 2])
	assert_string_contains(SkinPicCodec.decode(unknown)["error"], "never used")
	var cut := "M0".to_ascii_buffer() + F.u16(20) + F.bytes([0, 255, 1, 2, 3])
	cut.append_array(F.make_pic(1, 1, F.bytes([0])))
	assert_string_contains(SkinPicCodec.decode(cut)["error"], "palette")
	assert_string_contains(SkinPicCodec.decode(PackedByteArray())["error"], "no picture")


func test_a_picture_claiming_an_absurd_size_is_refused_unread() -> void:
	for size: Array in [[60000, 60000], [8193, 2], [2, 8193], [0, 5], [5, 0], [8000, 8000]]:
		var file := "X0".to_ascii_buffer() + F.u16(5) + F.u16(size[0]) + F.u16(size[1]) + F.bytes([11])
		var got := SkinPicCodec.decode(file)
		assert_string_contains(got["error"], "claims", "%s x %s" % size)
		assert_false(got.has("indices"))
	for max_bits in [0, 8, 13, 200]:
		var file := "X0".to_ascii_buffer() + F.u16(5) + F.u16(2) + F.u16(2) + F.bytes([max_bits])
		assert_ne(SkinPicCodec.decode(file)["error"], "", "%d-bit codes" % max_bits)


func test_no_cut_or_scrambled_picture_crashes_or_runs_on() -> void:
	var whole := F.make_pic(20, 12, F.noise(240, 5, 9), F.ramp_palette(), true)
	var started := Time.get_ticks_msec()
	for length in whole.size():
		var got := SkinPicCodec.decode(whole.slice(0, length))
		assert_true(got.has("error"))
		SkinPicCodec.read_palette(whole.slice(0, length))
	for round in 300:
		var junk := F.noise(40 + round, round)
		if round % 3 == 0:   # a real head, then noise
			junk = "X0".to_ascii_buffer() + F.u16(9) + F.u16(30) + F.u16(30) + F.bytes([11]) + junk
		var scrambled := whole.duplicate()
		scrambled[(round * 37) % scrambled.size()] = round & 0xFF
		for file: PackedByteArray in [junk, scrambled]:
			var got := SkinPicCodec.decode(file)
			if String(got["error"]) == "":
				assert_eq((got["indices"] as PackedByteArray).size(), int(got["width"]) * int(got["height"]))
	assert_lt(Time.get_ticks_msec() - started, 20000)


func test_packed_data_that_unfolds_without_end_is_stopped() -> void:
	# A stream of the longest entries a dictionary can hold, over and over.
	var codes: Array = [0]
	for group in 30:
		for i in 3839:
			codes.append(257 + i)
		codes.append(0)
	var got := SkinPicCodec._lzw(F.pack_codes(codes, 12), 0, 12)
	assert_string_contains(got["error"], "without end")


func test_palettes() -> void:
	var pic := F.make_pic(2, 2, F.bytes([1, 2, 3, 4]), F.ramp_palette())
	assert_eq(SkinPicCodec.read_palette(pic), F.ramp_palette())
	assert_true(SkinPicCodec.read_palette(F.make_pic(2, 2, F.bytes([1, 2, 3, 4]))).is_empty())
	assert_true(SkinPicCodec.read_palette("not a picture at all".to_ascii_buffer()).is_empty())
	assert_eq(SkinPicCodec.read_tr_palette(F.tr_text(F.ramp_palette())), F.ramp_palette())
	var partial := SkinPicCodec.read_tr_palette(F.tr_text(F.ramp_palette(), 1, 235))
	assert_eq(partial.slice(0, 3), F.bytes([0, 0, 0]), "an entry not named stays black")
	assert_eq(partial.slice(3, 6), F.ramp_palette().slice(3, 6))
	assert_true(SkinPicCodec.read_tr_palette(F.tr_text(F.ramp_palette(), 0, 150)).is_empty(),
		"fewer than 200 entries is no palette")
	var noisy := "junk\n300 - 1 2 3\n5 - 1 2 999\n7 - x y z\n".to_ascii_buffer() + F.tr_text(F.ramp_palette())
	assert_eq(SkinPicCodec.read_tr_palette(noisy), F.ramp_palette(), "lines that are no entry are passed over")


func test_the_mask_s_clear_value_is_measured_on_its_edge() -> void:
	var image := F.noise(6 * 5, 2)
	for pair: Array in [[255, 0], [0, 255], [3, 9]]:
		var mask := F.edge_mask(6, 5, pair[0], pair[1])
		var got := SkinPicCodec.split_image_mask(12, 5, F.masked_pixels(image, mask, 6, 5))
		assert_eq(got["error"], "")
		assert_eq(got["half"], 6)
		assert_eq(got["image"], image)
		var clear: PackedByteArray = got["clear"]
		assert_eq(clear[0], 1, "the edge is clear")
		assert_eq(clear[6 + 2], 0, "the inside is not")
		assert_eq(clear.count(1), 6 * 5 - 4 * 3)
	var flat := SkinPicCodec.split_image_mask(12, 5, F.masked_pixels(image, SkinPicCodec.zeros(30, 255), 6, 5))
	assert_eq((flat["clear"] as PackedByteArray).count(1), 0, "a mask of one value is all opaque")
	var three := F.edge_mask(6, 5, 255, 0)
	three[8] = 77
	assert_ne(SkinPicCodec.split_image_mask(12, 5, F.masked_pixels(image, three, 6, 5))["error"], "")
	assert_ne(SkinPicCodec.split_image_mask(11, 5, F.noise(55, 1))["error"], "", "an odd width")


func test_painting() -> void:
	var palette := F.ramp_palette()
	var sprite := SkinPicCodec.paint(F.bytes([0, 1, 255]), SkinPicCodec.pixel_table(palette, 0))
	assert_eq(sprite, F.bytes([0, 0, 0, 0, 1, 7, 13, 255, 255, 249, 243, 255]),
		"index 0 clear, its colour kept; the rest from the palette")
	var bare := SkinPicCodec.paint(F.bytes([0, 255]), SkinPicCodec.pixel_table(palette, 255))
	assert_eq(bare, F.bytes([0, 0, 0, 255, 255, 249, 243, 0]), "a bare picture: 255 clear")
	var masked := SkinPicCodec.paint_masked(F.bytes([0, 5, 5]), palette, F.bytes([0, 0, 1]))
	assert_eq(masked, F.bytes([0, 0, 0, 255, 5, 35, 65, 255, 5, 35, 65, 0]),
		"with a mask, index 0 is a colour and the mask alone clears")


# -------------------------------------------------------------- bitmaps --

func test_a_bitmap_comes_back_top_row_first() -> void:
	var rgb := F.noise(5 * 3 * 3, 8)   # 5 wide: a padded row
	for top_down in [false, true]:
		var got := SkinPicCodec.read_bmp(F.make_bmp(5, 3, rgb, top_down))
		assert_eq(got["error"], "")
		assert_eq([got["width"], got["height"]], [5, 3])
		var pixels: PackedByteArray = got["pixels"]
		for i in 15:
			assert_eq(pixels.slice(i * 4, i * 4 + 4), rgb.slice(i * 3, i * 3 + 3) + F.bytes([255]))


func test_only_the_bitmaps_the_1997_window_read() -> void:
	var rgb := F.noise(27, 8)
	assert_ne(SkinPicCodec.read_bmp(F.make_bmp(3, 3, rgb, false, 8))["error"], "", "8 bits a pixel")
	var whole := F.make_bmp(3, 3, rgb)
	assert_ne(SkinPicCodec.read_bmp(whole.slice(0, whole.size() - 1))["error"], "", "cut short")
	assert_ne(SkinPicCodec.read_bmp("BM".to_ascii_buffer())["error"], "")
	assert_ne(SkinPicCodec.read_bmp(F.noise(100, 2))["error"], "")
	var os2 := whole.duplicate()
	os2.encode_u32(14, 12)
	assert_ne(SkinPicCodec.read_bmp(os2)["error"], "", "an OS/2 header")
	var packed := whole.duplicate()
	packed.encode_u32(30, 1)
	assert_ne(SkinPicCodec.read_bmp(packed)["error"], "", "packed")
	for size: Array in [[60000, 60000], [0, 3], [-3, 3], [8193, 1]]:
		var huge := whole.duplicate()
		huge.encode_s32(18, size[0])
		huge.encode_s32(22, size[1])
		assert_ne(SkinPicCodec.read_bmp(huge)["error"], "", "%s x %s" % size)
	for length in whole.size():
		assert_true(SkinPicCodec.read_bmp(whole.slice(0, length)).has("error"))


func test_exactly_one_colour_is_made_clear() -> void:
	var pixels := F.bytes([0, 255, 0, 255, 0, 254, 0, 255, 1, 255, 0, 255, 0, 255, 0, 255])
	assert_eq(SkinPicCodec.clear_colour(pixels, [0, 255, 0]),
		F.bytes([0, 255, 0, 0, 0, 254, 0, 255, 1, 255, 0, 255, 0, 255, 0, 0]))


# -------------------------------------------------------------- sprites --

func test_frames_come_back() -> void:
	var a := F.noise(8 * 3, 1, 250)
	var b := F.noise(5 * 2, 2, 250)
	var got := SkinSprCodec.decode(F.make_spr([[8, 3, a, 12], [5, 2, b, -1]]))
	assert_eq(got["error"], "")
	assert_eq(got["frames"], [[8, 3, a], [5, 2, b]])
	assert_eq(Array(SkinSprCodec.frame_tops(F.make_spr([[8, 3, a, 12], [5, 2, b, -1]]))), [12, -1])
	assert_eq(SkinSprCodec.decode(F.make_spr([[8, 3, a]], false))["frames"], [[8, 3, a]],
		"a file with no end mark ends at its end")


func test_clear_rows_runs_and_padding() -> void:
	# Two clear rows on top, a row of [2 clear, 3 pixels], 0xFF padding
	# before the next, whose count is the short form; the last row absent.
	var body := F.bytes([2, 0xFE, 3, 9, 8, 7, 0xFF, 0xFF, 1, 2, 5, 6])
	var data := F.spr_frame(6, 5, body, 0, 2) + F.u32(0xFFFFFFFF)
	var got := SkinSprCodec.decode(data)
	assert_eq(got["error"], "")
	assert_eq(got["frames"][0][2], F.bytes([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 9, 8, 7, 0, 0, 5, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0]))


func test_a_frame_may_end_in_the_middle_of_a_row() -> void:
	var rows := PackedByteArray()
	for _row in 2:
		rows.append_array(F.bytes([0, 0xFE, 8]) + SkinPicCodec.zeros(8, 7))
	var data := F.spr_frame(8, 4, rows + F.bytes([0xFF, 0xCD, 0xCD])) + F.u32(0xFFFFFFFF)
	var got := SkinSprCodec.decode(data)
	assert_eq(got["error"], "", "the fill after the last row is not a run")
	var pixels: PackedByteArray = got["frames"][0][2]
	assert_eq(pixels.slice(0, 16), SkinPicCodec.zeros(16, 7))
	assert_eq(pixels.slice(16), SkinPicCodec.zeros(16), "the rows the frame never held are clear")


func test_what_is_not_a_sprite_is_refused_in_words() -> void:
	var wide := F.spr_frame(8, 2, F.bytes([0, 0xFE, 200]) + SkinPicCodec.zeros(200, 7)) + F.u32(0xFFFFFFFF)
	assert_string_contains(SkinSprCodec.decode(wide)["error"], "wider")
	assert_string_contains(SkinSprCodec.decode(F.u32(0xFFFFFFFF))["error"], "no frames")
	assert_string_contains(SkinSprCodec.decode(PackedByteArray())["error"], "no frames")
	assert_string_contains(SkinSprCodec.decode(F.u32(8) + F.noise(8, 1))["error"], "length")
	assert_string_contains(SkinSprCodec.decode(F.u32(4000) + F.noise(20, 1))["error"], "length")
	for size: Array in [[0, 4], [4, 0], [5000, 4], [4, 5000]]:
		var data := F.spr_frame(size[0], size[1], PackedByteArray()) + F.u32(0xFFFFFFFF)
		assert_string_contains(SkinSprCodec.decode(data)["error"], "claims", "%s x %s" % size)
	var too_clear := F.spr_frame(4, 4, PackedByteArray(), 0, 9) + F.u32(0xFFFFFFFF)
	assert_ne(SkinSprCodec.decode(too_clear)["error"], "", "more clear rows than rows")


func test_a_file_of_endless_huge_frames_is_stopped() -> void:
	# Sixteen bytes a frame, each claiming 4096 x 4096 of clear rows.
	var data := PackedByteArray()
	for i in 50:
		data.append_array(F.spr_frame(4096, 4096, PackedByteArray(), 0, 4096))
	var started := Time.get_ticks_msec()
	assert_string_contains(SkinSprCodec.decode(data)["error"], "more frames")
	assert_lt(Time.get_ticks_msec() - started, 5000)


func test_no_cut_or_scrambled_sprite_crashes_or_runs_on() -> void:
	var whole := F.make_spr([[9, 4, F.noise(36, 1, 250), 3], [6, 6, F.noise(36, 2, 250)]])
	var started := Time.get_ticks_msec()
	for length in whole.size():
		assert_true(SkinSprCodec.decode(whole.slice(0, length)).has("error"))
		SkinSprCodec.frame_tops(whole.slice(0, length))
	for round in 300:
		var scrambled := whole.duplicate()
		scrambled[(round * 13) % scrambled.size()] = (round * 7) & 0xFF
		for file: PackedByteArray in [F.noise(30 + round, round), scrambled]:
			var got := SkinSprCodec.decode(file)
			for frame: Array in got["frames"]:
				assert_eq((frame[2] as PackedByteArray).size(), int(frame[0]) * int(frame[1]))
			SkinSprCodec.frame_tops(file)
	assert_lt(Time.get_ticks_msec() - started, 20000)


func test_a_sheet_cuts_a_frame_to_its_cell() -> void:
	# Three frames on a 2-column grid of 4 x 2 cells: one wider and taller
	# than its cell, one smaller, one exact.
	var big := F.bytes([1, 1, 1, 1, 9, 9, 1, 1, 1, 1, 9, 9, 8, 8, 8, 8, 8, 8])   # 6 x 3
	var small := F.bytes([2, 2])                                                  # 2 x 1
	var exact := F.bytes([3, 3, 3, 3, 3, 3, 3, 3])                                # 4 x 2
	var sheet := SkinSprCodec.sheet([[6, 3, big], [2, 1, small], [4, 2, exact], [4, 2, exact]], 3, 4, 2, 2)
	assert_eq([sheet["width"], sheet["height"]], [8, 4])
	assert_eq(sheet["indices"], F.bytes([
		1, 1, 1, 1, 2, 2, 0, 0,
		1, 1, 1, 1, 0, 0, 0, 0,
		3, 3, 3, 3, 0, 0, 0, 0,
		3, 3, 3, 3, 0, 0, 0, 0]), "cut, not smeared; the frame past the cells left out")
	assert_eq(sheet["sizes"], [[6, 3], [2, 1], [4, 2]])
	var column := SkinSprCodec.sheet([[2, 1, small], [2, 1, small]], 2, 2, 1, 1)
	assert_eq([column["width"], column["height"]], [2, 2], "one column: frame N is row N")


# ----------------------------------------------------------------- text --

func test_text_is_read_by_python_s_rules() -> void:
	assert_eq(SkinText.decode(F.bytes([65, 0x85, 0xE9, 0x81])), "A\u0085é\u0081", "Latin-1")
	assert_eq(SkinText.decode(F.bytes([65, 0x85, 0xE9, 0x81]), true), "A…é�", "Windows-1252")
	assert_eq(Array(SkinText.lines("a\r\nb\rc\n\nd\u0085e")), ["a", "b", "c", "", "d", "e"])
	assert_eq(Array(SkinText.lines("one\n")), ["one"])
	assert_eq(SkinText.strip(" \t x y\r\n"), "x y")
	assert_eq(SkinText.strip("\u0001x"), "\u0001x", "a control character is not white space")
	assert_eq(Array(SkinText.words("  a\tbb   c  ")), ["a", "bb", "c"])
	assert_true(SkinText.is_digits("0123"))
	for no in ["", "-1", "1.5", "１２", " 1"]:
		assert_false(SkinText.is_digits(no), no)


func test_csv_rows_are_cut_as_python_cuts_them() -> void:
	var rows := SkinText.csv_rows(PackedStringArray([
		"1,Swamp,,x", "2,\"Air, the \"\"Great\"\"\",y", "", "3,\"open", "still\",z", "4,a\"b,", "5,\"q\"tail,w"]))
	assert_eq(rows, [["1", "Swamp", "", "x"], ["2", "Air, the \"Great\"", "y"], [],
		["3", "openstill", "z"], ["4", "a\"b", ""], ["5", "qtail", "w"]])
	assert_eq(SkinText.csv_rows(PackedStringArray(["1,\"never closed"])), [["1", "never closed"]])


func test_json_is_written_strictly() -> void:
	var text := SkinText.json({"b": [1, -2, true, null], "a": "q\"\\\n\t\u0001é"}, true)
	assert_eq(text, "{\"a\": \"q\\\"\\\\\\n\\t\\u0001é\", \"b\": [1, -2, true, null]}")
	assert_eq(JSON.parse_string(text), {"a": "q\"\\\n\t\u0001é", "b": [1.0, -2.0, true, null]})
	assert_eq(SkinText.json({"b": 1, "a": 2}), "{\"b\": 1, \"a\": 2}", "unsorted: as made")
	assert_eq(SkinText.json(4294967295), "4294967295")
