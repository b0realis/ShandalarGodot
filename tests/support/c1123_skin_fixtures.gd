class_name C1123SkinFixtures
extends RefCounted
## TINY 1997 FILES MADE IN THE TEST, for the skin builder's tests
## (builders 2026-11-23): the encoders that are the inverse of
## [SkinPicCodec] and [SkinSprCodec], written apart from them, and a small
## made-up install laid out in a scratch folder. Nothing here comes from a
## real copy of the 1997 game.

const FACE := [137, 169]
const ROGUE := [138, 170]


# ----------------------------------------------------------------- bytes --

static func bytes(values: Array) -> PackedByteArray:
	var out := PackedByteArray()
	for value in values:
		out.append(int(value))
	return out


static func u16(value: int) -> PackedByteArray:
	return bytes([value & 0xFF, (value >> 8) & 0xFF])


static func u32(value: int) -> PackedByteArray:
	return bytes([value & 0xFF, (value >> 8) & 0xFF, (value >> 16) & 0xFF, (value >> 24) & 0xFF])


## [param count] bytes that look like noise, the same every time.
static func noise(count: int, seed_value := 7, most := 256) -> PackedByteArray:
	var out := PackedByteArray()
	var state := seed_value * 2654435761 + 12345
	for i in count:
		state = (state * 6364136223846793005 + 1442695040888963407) & 0x7FFFFFFFFFFFFFFF
		out.append((state >> 33) % most)
	return out


## 256 colours no two alike, so a wrong index is a wrong pixel.
static func ramp_palette() -> PackedByteArray:
	var out := PackedByteArray()
	for i in 256:
		out.append(i)
		out.append((i * 7) & 0xFF)
		out.append((i * 13) & 0xFF)
	return out


## The palette as a `.tr` text file.
static func tr_text(palette: PackedByteArray, from := 0, to := 255) -> PackedByteArray:
	var text := ""
	for i in range(from, to + 1):
		text += "%d - %d %d %d\r\n" % [i, palette[i * 3], palette[i * 3 + 1], palette[i * 3 + 2]]
	return text.to_ascii_buffer()


# ------------------------------------------------------------------ .pic --

## LZW codes packed the PicV3 way: low bits first, 9 bits for 256 codes,
## 10 for 512, 11 for 1024, and back to 9.
static func pack_codes(codes: Array, max_bits := 11) -> PackedByteArray:
	var out := PackedByteArray()
	var bits := 0
	var held := 0
	var width := 9
	var threshold := 0x100
	var counter := 0
	for code: int in codes:
		bits |= code << held
		held += width
		while held >= 8:
			out.append(bits & 0xFF)
			bits >>= 8
			held -= 8
		counter += 1
		if counter == threshold:
			counter = 0
			width += 1
			threshold <<= 1
			if width > max_bits:
				width = 9
				threshold = 0x100
	if held > 0:
		out.append(bits & 0xFF)
	return out


## A real LZW of [param data] in PicV3's dialect: the dictionary starts at
## 257 and is thrown away when its last code is reached.
static func lzw_codes(data: PackedByteArray, max_bits := 11) -> Array:
	var codes: Array = []
	var group := 1 + (1 << max_bits) - 257
	var table := {}
	var next_code := 257
	var in_group := 0
	var current := -1
	for byte in data:
		if current < 0:
			current = byte
			continue
		var key := (current << 8) | byte
		if table.has(key):
			current = table[key]
			continue
		codes.append(current)
		in_group += 1
		if in_group == group:
			table = {}
			next_code = 257
			in_group = 0
		else:
			table[key] = next_code
			next_code += 1
		current = byte
	if current >= 0:
		codes.append(current)
	return codes


## PicV3's RLE with no runs: a 0x90 followed by 0 (the first byte bare,
## as the format has it).
static func rle_escape(data: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	for i in data.size():
		out.append(data[i])
		if data[i] == 0x90 and i > 0:
			out.append(0)
	return out


## PicV3's RLE with runs of three or more packed.
static func rle_runs(data: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	var i := 0
	var total := data.size()
	while i < total:
		var value := data[i]
		var run := 1
		while i + run < total and data[i + run] == value and run < 255:
			run += 1
		if value == 0x90 or run < 3:
			out.append(value)
			if value == 0x90 and i > 0:
				out.append(0)
			i += 1
			continue
		out.append(value)
		out.append(0x90)
		out.append(run)
		i += run
	return out


## A `.pic` holding [param pixels]; with [param palette] its own `M0`
## block. [param packed]: a real LZW over RLE runs, else literal codes.
static func make_pic(width: int, height: int, pixels: PackedByteArray,
		palette := PackedByteArray(), packed := false, max_bits := 11) -> PackedByteArray:
	var out := PackedByteArray()
	if not palette.is_empty():
		out.append_array("M0".to_ascii_buffer())
		out.append_array(u16(2 + palette.size()))
		out.append_array(bytes([0, 255]))
		out.append_array(palette)
	var codes: Array = []
	if packed:
		codes = lzw_codes(rle_runs(pixels), max_bits)
	else:
		codes = Array(rle_escape(pixels))
	var stream := pack_codes(codes, max_bits)
	out.append_array("X0".to_ascii_buffer())
	out.append_array(u16((5 + stream.size()) & 0xFFFF))
	out.append_array(u16(width))
	out.append_array(u16(height))
	out.append(max_bits)
	out.append_array(stream)
	return out


## An image half and a mask half side by side, row by row.
static func masked_pixels(image: PackedByteArray, mask: PackedByteArray, width: int,
		height: int) -> PackedByteArray:
	var out := PackedByteArray()
	for y in height:
		out.append_array(image.slice(y * width, (y + 1) * width))
		out.append_array(mask.slice(y * width, (y + 1) * width))
	return out


## A mask of [param width] x [param height]: [param clear] on its outer
## edge, [param opaque] inside.
static func edge_mask(width: int, height: int, clear: int, opaque: int) -> PackedByteArray:
	var out := PackedByteArray()
	for y in height:
		for x in width:
			var edge := x == 0 or y == 0 or x == width - 1 or y == height - 1
			out.append(clear if edge else opaque)
	return out


## A face picture of [param cell] with its mask beside it.
static func face_pic(seed_value: int, cell: Array, clear := 255, opaque := 0) -> PackedByteArray:
	var w := int(cell[0])
	var h := int(cell[1])
	var image := noise(w * h, seed_value, 200)
	return make_pic(w * 2, h, masked_pixels(image, edge_mask(w, h, clear, opaque), w, h),
		PackedByteArray(), true)


# ------------------------------------------------------------------ .spr --

## A `.spr` of [param frames], each `[width, height, pixels]` or `[width,
## height, pixels, top]`: no clear rows above, one run a row.
static func make_spr(frames: Array, end_mark := true) -> PackedByteArray:
	var out := PackedByteArray()
	for frame: Array in frames:
		var width := int(frame[0])
		var height := int(frame[1])
		var pixels: PackedByteArray = frame[2]
		var top := int(frame[3]) if frame.size() > 3 else 0
		var body := PackedByteArray()
		for y in height:
			body.append_array(bytes([0, 0xFE, width]))
			body.append_array(pixels.slice(y * width, (y + 1) * width))
		out.append_array(spr_frame(width, height, body, top))
	if end_mark:
		out.append_array(u32(0xFFFFFFFF))
	return out


## One frame: its 16-byte header and [param body] as it is.
static func spr_frame(width: int, height: int, body: PackedByteArray, top := 0,
		empty_lines := 0) -> PackedByteArray:
	var out := u32(body.size() + 16)
	out.append_array(u16(width))
	out.append_array(u16(height))
	out.append_array(u16(0))
	out.append_array(u16(top & 0xFFFF))
	out.append_array(u16(empty_lines))
	out.append_array(u16(0))
	out.append_array(body)
	return out


# ------------------------------------------------------------------ .bmp --

## A 24-bit Windows bitmap of [param rgb] (rows top to bottom), stored
## bottom-up unless [param top_down].
static func make_bmp(width: int, height: int, rgb: PackedByteArray, top_down := false,
		bits := 24) -> PackedByteArray:
	var stride := (width * 3 + 3) & ~3
	var out := "BM".to_ascii_buffer()
	out.append_array(u32(54 + stride * height))
	out.append_array(u32(0))
	out.append_array(u32(54))
	out.append_array(u32(40))
	out.append_array(u32(width))
	out.append_array(u32((-height if top_down else height) & 0xFFFFFFFF))
	out.append_array(u16(1))
	out.append_array(u16(bits))
	out.append_array(u32(0))
	out.append_array(u32(stride * height))
	out.append_array(u32(0))
	out.append_array(u32(0))
	out.append_array(u32(0))
	out.append_array(u32(0))
	for row in height:
		var y := row if top_down else height - 1 - row
		for x in width:
			var at := (y * width + x) * 3
			out.append(rgb[at + 2])
			out.append(rgb[at + 1])
			out.append(rgb[at])
		for _pad in stride - width * 3:
			out.append(0)
	return out


# ------------------------------------------------------------- an install --

static func write_file(path: String, data: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(data)
	file.close()


## Delete [param folder] and everything in it.
static func remove_tree(folder: String) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	dir.include_hidden = true
	for sub in dir.get_directories():
		remove_tree(folder.path_join(sub))
	for file in dir.get_files():
		DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)


## One row of a 1997 program's card table, 72 bytes.
static func card_row(short_name: String, id: int, type := 1, code := 0x401000, rarity := 1,
		ai := 0) -> PackedByteArray:
	var row := PackedByteArray()
	row.resize(72)
	row.fill(0)
	var name := short_name.to_ascii_buffer()
	for i in mini(name.size(), 19):
		row[1 + i] = name[i]
	row.encode_u16(0x24, id)
	row[0x28] = type
	row.encode_s8(0x2a, 2)
	row.encode_s8(0x2b, 1)
	row.encode_s8(0x2c, -1)
	row.encode_s16(0x2e, 3)
	row.encode_s16(0x30, -1)
	row.encode_u32(0x34, code)
	row.encode_u32(0x38, 0x80000001)
	row.encode_u32(0x3c, 0x200)
	row[0x40] = rarity
	row[0x42] = 4
	row.encode_s32(0x44, ai)
	return row


## A made-up install under [param root], and what a build of it must
## give: `{palette, world_palette, title, summon, wav, ttf, rogue_image}`.
## Folder and file names in mixed case, as a real one has them.
static func make_install(root: String) -> Dictionary:
	var palette := ramp_palette()
	var world := PackedByteArray()
	for i in 256:
		world.append((i * 3) & 0xFF)
		world.append(255 - i)
		world.append((i * 5) & 0xFF)
	# The duel palette and the adventure's.
	write_file(root.path_join("Duelpalall.tr"), tr_text(palette))
	write_file(root.path_join("Todpal.tr"), tr_text(world))
	write_file(root.path_join("Advfac64.pic"), make_pic(4, 2, noise(8, 3), world))
	# A screen with its own palette, and a bare picture that takes the duel's.
	var title := noise(12 * 8, 11)
	write_file(root.path_join("Title.PIC"), make_pic(12, 8, title, world, true))
	var summon := noise(10 * 5, 5, 250)
	summon[7] = 255
	write_file(root.path_join("Cardart/Summon.pic"), make_pic(10, 5, summon))
	# Sprites: the adventure's button strip and one world sheet.
	var cells: Array = []
	for i in 16:
		cells.append([48, 48, noise(48 * 48, 20 + i, 250)])
	write_file(root.path_join("Statbutt.spr"), make_spr(cells))
	var tiles: Array = []
	for i in 6:
		tiles.append([128, 64, noise(128 * 64, 40 + i, 250), 60 + i if i == 0 else -1])
	tiles.append([3, 1, bytes([1, 1, 1])])
	write_file(root.path_join("Spr/Landtile.spr"), make_spr(tiles))
	# The wizards' window: an opaque hall and a figure on pure green.
	var hall := noise(6 * 4 * 3, 9)
	write_file(root.path_join("Statwin/Wizbg.bmp"), make_bmp(6, 4, hall))
	var figure := noise(5 * 3 * 3, 13)
	for at in [0, 3, 12]:
		figure[at * 3] = 0
		figure[at * 3 + 1] = 255
		figure[at * 3 + 2] = 0
	write_file(root.path_join("Statwin/Blu-Sprt.bmp"), make_bmp(5, 3, figure))
	# A sound, three namesakes of the duel's click, and the font.
	var wav := noise(3000, 17)
	write_file(root.path_join("Sound/Dueltune.wav"), wav)
	write_file(root.path_join("Duelsounds/Button.wav"), noise(64, 18))
	write_file(root.path_join("autoplay/Button.wav"), noise(8, 19))
	var ttf := noise(900, 21)
	write_file(root.path_join("Magim___.ttf"), ttf)
	# Faces: one player sheet, the Facemaker's, two rogues and an end cap.
	var faces: Array = []
	for i in 2:
		faces.append([FACE[0], FACE[1], noise(FACE[0] * FACE[1], 60 + i, 250)])
	faces.append([20, 10, noise(200, 70, 250)])
	write_file(root.path_join("16faces.spr"), make_spr(faces))
	write_file(root.path_join("Pedstls.pic"), make_pic(4, 2, noise(8, 4), palette))
	write_file(root.path_join("Face.pic"), face_pic(80, FACE, 0, 255))
	write_file(root.path_join("Faces/001.pic"), face_pic(81, ROGUE))
	write_file(root.path_join("Faces/002.pic"), face_pic(82, ROGUE))
	write_file(root.path_join("Faces/000.pic"), face_pic(81, ROGUE))
	# The deck builder's medallions, for the sheet laid from cells.
	for i in (SkinRecipes.PIC_SHEETS["filter_icons"][0] as Array).size():
		write_file(root.path_join("Dbart").path_join(SkinRecipes.PIC_SHEETS["filter_icons"][0][i]),
			make_pic(40, 40, noise(1600, 100 + i, 250)))
	# The program's card table and the lists.
	var program := noise(500, 23, 200)
	for row in [card_row("Swamp", 1), card_row("Island", 2), card_row("Forest", 3),
			card_row("Mountain", 4), card_row("Plains", 5), card_row("Air Element", 6, 2, 0x402000, 2, -2),
			card_row("Nameless", 99)]:
		program.append_array(row)
	program.append_array(noise(40, 24, 30))
	write_file(root.path_join("Shandalar.exe"), program)
	write_file(root.path_join("Info.csv"), ("Id,Name,a,b,c,d,e,f,Occuran.\r\n1,Swamp,,,,,,,Common\r\n"
		+ "2,Island,,,,,,,Common\r\n3,Forest,,,,,,,Common\r\n4,Mountain,,,,,,,Common\r\n"
		+ "5,Plains,,,,,,,Common\r\n6,\"Air Elemental, the \"\"Great\"\"\",,,,,,,Rare\r\n").to_ascii_buffer())
	write_file(root.path_join("Concise.csv"), "1 1 0\r\n6 2 0\r\nnot a row\r\n".to_ascii_buffer())
	write_file(root.path_join("Hints.txt"), (".6 2 AB (a pair)\r\nThe Elemental flies over Islands.\r\n\r\n"
		+ ".1 -1 D\r\nSwamps are black.\r\n.77 1 A\r\nNobody.\r\n").to_ascii_buffer())
	var blocks := ""
	for i in 4:
		blocks += "; news %d\r\nSTARTBLOCK\r\nNews %d first.\r\nNews %d second.\r\nENDBLOCK\r\n" % [i, i, i]
	blocks += "STARTBLOCK\r\nA tale, page one.\r\n\r\n\r\n\r\nPage two.\r\n\r\n\r\n\r\nENDBLOCK\r\n"
	write_file(root.path_join("Advblocks.txt"), blocks.to_ascii_buffer())
	# The coin toss, carried along.
	write_file(root.path_join("Duelart/Cointoss_Heads.avi"), noise(700, 25))
	return {"palette": palette, "world_palette": world, "title": title, "summon": summon,
		"wav": wav, "ttf": ttf}


## The entries of the zip at [param path]: name -> bytes.
static func read_zip(path: String) -> Dictionary:
	var out := {}
	var reader := ZIPReader.new()
	if reader.open(path) != OK:
		return out
	for name in reader.get_files():
		out[name] = reader.read_file(name)
	reader.close()
	return out


## A PNG's pixels as RGBA bytes, with its size and whether it is stored
## with an alpha channel: `{width, height, alpha, rgba}`.
static func png(data: PackedByteArray) -> Dictionary:
	var image := Image.new()
	if image.load_png_from_buffer(data) != OK:
		return {"width": 0, "height": 0, "alpha": false, "rgba": PackedByteArray()}
	var alpha := image.get_format() == Image.FORMAT_RGBA8
	image.convert(Image.FORMAT_RGBA8)
	return {"width": image.get_width(), "height": image.get_height(), "alpha": alpha,
		"rgba": image.get_data()}
