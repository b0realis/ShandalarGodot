class_name SkinPicCodec
extends RefCounted
## THE 1997 GAME'S PICTURE FORMAT (`.pic`, PicV3), ITS PALETTES AND ITS
## WINDOWS BITMAPS, DECODED — the port of `decode_pic`, `read_pic_palette`,
## `read_tr_palette`, `split_image_mask`, `paint`, `read_bmp` and
## `clear_colour` of `tools/import_original.py`, which holds the reasons
## (the LZW's fixed width schedule, the dictionary that starts at 257, the
## RLE marker, the mask's measured polarity). The same bytes in give the
## same pixels out; a test holds the two together on a real install.
##
## WHAT IS A FILE HERE IS UNTRUSTED: a player points the builder at a
## folder, and anything may sit in it under a 1997 name. Nothing here
## asserts, loops without a bound or trusts a length: every function
## answers with `error` set, in the player's words, and the caller leaves
## that one file out. Two bounds are tighter than the Python tool's, which
## has none of its own to speak of: a picture is at most [constant
## MAX_PIXELS] and its packed data may unfold to at most [constant
## MAX_UNPACKED] bytes (no 1997 file is within a factor of ten of either).
##
## SPEED. The pixels are never touched one channel at a time: the LZW
## keeps its dictionary as places in its own output (an entry is always
## the bytes just written plus the next one), the RLE jumps from marker to
## marker, and a palette is a table of whole RGBA pixels, so painting is
## one look-up a pixel into a [PackedInt32Array] that is then read as
## bytes. Pure functions on private data: any thread may call them.

const MAX_SIDE := SkinRecipes.PIC_MAX_SIDE
## The most pixels a picture may claim (4096 x 4096; the largest 1997
## picture is 1024 x 768).
const MAX_PIXELS := 1 << 24
## The most bytes a picture's packed data may unfold to.
const MAX_UNPACKED := 3 << 24
const LZW_FIRST_CODE := 0x0101
const RLE_MARKER := 0x90
## A PNG's first eight bytes: no 1997 file is one.
const PNG_MAGIC: Array[int] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

## Block tags as numbers (two letters, the first in the low byte).
const _C0 := 0x3043
const _E0 := 0x3045
const _M0 := 0x304D
const _M1 := 0x314D
const _X0 := 0x3058
const _X1 := 0x3158


static func _fail(why: String) -> Dictionary:
	return {"error": why}


## Whether [param data] opens as a PNG.
static func is_png(data: PackedByteArray) -> bool:
	if data.size() < 8:
		return false
	for i in 8:
		if data[i] != PNG_MAGIC[i]:
			return false
	return true


## The 768-byte palette of a `.pic`'s own `M0`/`M1` block, or an empty
## array: only a whole 0-255 palette counts. The picture is not unpacked.
static func read_palette(data: PackedByteArray) -> PackedByteArray:
	var offset := 0
	var size := data.size()
	while offset + 4 <= size:
		var tag := data.decode_u16(offset)
		var length := data.decode_u16(offset + 2)
		if tag == _X0 or tag == _X1:
			return PackedByteArray()
		if tag != _C0 and tag != _E0 and tag != _M0 and tag != _M1:
			return PackedByteArray()
		if tag == _M0 or tag == _M1:
			var start := offset + 4
			var end := mini(start + length, size)
			if end - start < 2 or data[start] != 0 or data[start + 1] != 255:
				return PackedByteArray()
			var palette := data.slice(start + 2, mini(start + 2 + 768, end))
			return palette if palette.size() == 768 else PackedByteArray()
		offset += 4 + length
	return PackedByteArray()


## A `.tr` text palette — lines of `<index> - <r> <g> <b>` — as 768 bytes,
## the entries it does not name black; empty when it names fewer than 200.
static func read_tr_palette(data: PackedByteArray) -> PackedByteArray:
	var table := zeros(768)
	var seen := 0
	for line in SkinText.lines(SkinText.decode(data, true)):
		var parts := SkinText.words(line.replace("-", " "))
		if parts.size() < 4:
			continue
		var values: Array[int] = []
		for i in 4:
			var word := parts[i].trim_prefix("+")
			if not SkinText.is_digits(word) or word.length() > 9:
				break
			values.append(int(word))
		if values.size() < 4:
			continue
		if values[0] > 255 or values[1] > 255 or values[2] > 255 or values[3] > 255:
			continue
		var at := values[0] * 3
		table[at] = values[1]
		table[at + 1] = values[2]
		table[at + 2] = values[3]
		seen += 1
	return table if seen >= 200 else PackedByteArray()


## A `.pic` decoded: `{error, width, height, indices, palette}` — one
## palette index a pixel, and the file's own 768-byte palette (empty when
## it carries none). A picture shorter than its size is filled with 255.
static func decode(data: PackedByteArray) -> Dictionary:
	var palette := PackedByteArray()
	var offset := 0
	var size := data.size()
	while offset + 4 <= size:
		var tag := data.decode_u16(offset)
		var length := data.decode_u16(offset + 2)
		var start := offset + 4
		if tag == _M0 or tag == _M1:
			var end := mini(start + length, size)
			if end - start < 2:
				return _fail("its palette is cut short")
			var first := data[start]
			var last := data[start + 1]
			var count := (last - first + 1) * 3
			if last < first or end - start < 2 + count:
				return _fail("its palette is cut short")
			var table := zeros(first * 3)
			table.append_array(data.slice(start + 2, start + 2 + count))
			table.append_array(zeros(768 - table.size()))
			palette = table
		elif tag == _X0 or tag == _X1:
			# The picture is the rest of the file, whatever its length says.
			if size - start < 5:
				return _fail("its picture is cut short")
			var width := data.decode_u16(start)
			var height := data.decode_u16(start + 2)
			var max_bits := data[start + 4]
			if width <= 0 or width > MAX_SIDE or height <= 0 or height > MAX_SIDE \
					or width * height > MAX_PIXELS:
				return _fail("it claims a picture of %d x %d" % [width, height])
			if max_bits < 9 or max_bits > 12:
				return _fail("its packing is not the 1997 game's")
			var unpacked := _lzw(data, start + 5, max_bits)
			if String(unpacked["error"]) != "":
				return unpacked
			var wanted := width * height
			var pixels := _rle(unpacked["bytes"], wanted)
			if pixels.size() < wanted:
				pixels.append_array(zeros(wanted - pixels.size(), 255))
			elif pixels.size() > wanted:
				pixels.resize(wanted)
			return {"error": "", "width": width, "height": height,
				"indices": pixels, "palette": palette}
		elif tag == _C0 or tag == _E0:
			return _fail("it is packed in a way the 1997 game never used")
		else:
			return _fail("it is not a 1997 picture file")
		offset += 4 + length
	return _fail("it holds no picture")


## [param count] bytes, each [param value].
static func zeros(count: int, value := 0) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(maxi(count, 0))
	out.fill(value)
	return out


## PicV3's LZW from [param start] to the end of [param data]: `{error,
## bytes}`. Codes least-significant bit first, 9 bits for 256 codes, 10
## for 512, 11 for 1024 (and 12 for 2048 where [param max_bits] allows),
## then the width and the dictionary start over together; the dictionary's
## first free code is 257, and 256 is an empty entry.
static func _lzw(data: PackedByteArray, start: int, max_bits: int) -> Dictionary:
	var out := PackedByteArray()
	var limit := 1 << max_bits
	# Where each entry's bytes lie in `out`, and how many they are.
	var at_of := PackedInt32Array()
	at_of.resize(limit)
	var len_of := PackedInt32Array()
	len_of.resize(limit)
	var bits := 0
	var held := 0
	var width := 9
	var mask := 0x1FF
	var threshold := 0x100
	var counter := 0
	var cursor := 0          # 0: the next code starts a group
	var prev_at := 0
	var prev_len := 0
	var size := data.size()
	var i := start
	while i < size:
		bits |= data[i] << held
		held += 8
		i += 1
		while held >= width:
			var code := bits & mask
			bits >>= width
			held -= width
			counter += 1
			if counter == threshold:
				counter = 0
				width += 1
				threshold <<= 1
				if width > max_bits:
					width = 9
					threshold = 0x100
				mask = (1 << width) - 1
			if cursor == 0:
				if code > 255:
					return _fail("its picture data is damaged")
				cursor = LZW_FIRST_CODE
				prev_at = out.size()
				prev_len = 1
				out.append(code)
				continue
			var entry_at := out.size()
			var entry_len := 1
			if code < 256:
				out.append(code)
			elif code == 256:
				entry_len = 0
			elif code < cursor:
				entry_len = len_of[code]
				if entry_len > 0:
					var from := at_of[code]
					out.append_array(out.slice(from, from + entry_len))
			elif code == cursor:
				# The entry being made right now: the last one and its own
				# first byte again.
				entry_len = prev_len + 1 if prev_len > 0 else 0
				if prev_len > 0:
					out.append_array(out.slice(prev_at, prev_at + prev_len))
					out.append(out[prev_at])
			else:
				return _fail("its picture data is damaged")
			# The new entry is the last one plus this one's first byte —
			# which is exactly what now lies at the last one's place.
			at_of[cursor] = prev_at
			len_of[cursor] = prev_len + (1 if entry_len > 0 else 0)
			cursor += 1
			prev_at = entry_at
			prev_len = entry_len
			if cursor >= limit:
				cursor = 0
				if out.size() > MAX_UNPACKED:
					return _fail("its picture data unfolds without end")
	if out.size() > MAX_UNPACKED:
		return _fail("its picture data unfolds without end")
	return {"error": "", "bytes": out}


## PicV3's RLE: `0x90 <count>` repeats the byte before it until there are
## [code]count[/code] of it, `0x90 0x00` is a literal 0x90. Stops once
## [param wanted] bytes are out (more would be cut off anyway).
static func _rle(data: PackedByteArray, wanted := -1) -> PackedByteArray:
	var total := data.size()
	if total == 0:
		return PackedByteArray()
	if data.find(RLE_MARKER, 1) < 0:
		return data
	var out := PackedByteArray()
	out.append(data[0])
	var index := 1
	while index < total:
		if wanted >= 0 and out.size() >= wanted:
			break
		var at := data.find(RLE_MARKER, index)
		if at < 0:
			out.append_array(data.slice(index))
			break
		if at > index:
			out.append_array(data.slice(index, at))
		index = at
		if index + 1 >= total:
			out.append(RLE_MARKER)
		elif data[index + 1] == 0:
			out.append(RLE_MARKER)
			index += 1
		else:
			var count := data[index + 1]
			index += 1
			if count > 1:
				out.append_array(zeros(count - 1, out[out.size() - 1]))
		index += 1
	return out


## An `<image><mask>` picture cut in two: `{error, half, image, clear}` —
## the left half's indices, and the mask as one byte a pixel, 1 where the
## picture is CLEAR. Which of the mask's two values means clear is
## measured: the one that holds most of the mask's outer edge. A mask of
## one value is all opaque.
static func split_image_mask(width: int, height: int, indices: PackedByteArray) -> Dictionary:
	if width % 2 != 0:
		return _fail("its width is odd, so it is not a picture beside its mask")
	var half := width >> 1
	var image := PackedByteArray()
	var mask := PackedByteArray()
	for y in height:
		var row := y * width
		image.append_array(indices.slice(row, row + half))
		mask.append_array(indices.slice(row + half, row + width))
	var values: Array[int] = []
	for value in 256:
		if mask.has(value):
			values.append(value)
			if values.size() > 2:
				return _fail("its mask half is not a mask")
	var clear := zeros(mask.size())
	if values.size() < 2:
		return {"error": "", "half": half, "image": image, "clear": clear}
	var border := [0, 0]
	for x in half:
		for y: int in [0, height - 1]:
			border[0 if mask[y * half + x] == values[0] else 1] += 1
	for y in height:
		for x: int in [0, half - 1]:
			border[0 if mask[y * half + x] == values[0] else 1] += 1
	# Python's `max` keeps the first of two equal counts, and its
	# dictionary is in the order the values were first met on the edge.
	var clear_value := values[0] if border[0] > border[1] else values[1]
	if border[0] == border[1]:
		clear_value = mask[0]
	for i in mask.size():
		if mask[i] == clear_value:
			clear[i] = 1
	return {"error": "", "half": half, "image": image, "clear": clear}


## [param palette] (768 bytes) as 256 whole pixels, opaque but for the
## index [param clear_index] (-1: none), whose colour is kept under alpha
## 0. With [param all_clear] every entry is clear.
static func pixel_table(palette: PackedByteArray, clear_index := -1,
		all_clear := false) -> PackedInt32Array:
	var table := PackedInt32Array()
	table.resize(256)
	for i in 256:
		var value := palette[i * 3] | (palette[i * 3 + 1] << 8) | (palette[i * 3 + 2] << 16)
		if not all_clear and i != clear_index:
			value -= 0x1000000   # alpha 255, as a signed 32-bit number
		table[i] = value
	return table


## Palette indices as RGBA bytes, a look-up a pixel ([method pixel_table]).
static func paint(indices: PackedByteArray, table: PackedInt32Array) -> PackedByteArray:
	var n := indices.size()
	var out := PackedInt32Array()
	out.resize(n)
	for i in n:
		out[i] = table[indices[i]]
	return out.to_byte_array()


## The same with a mask: index 0 is a real colour, and a pixel is clear
## where [param clear] is 1.
static func paint_masked(indices: PackedByteArray, palette: PackedByteArray,
		clear: PackedByteArray) -> PackedByteArray:
	var opaque := pixel_table(palette)
	var through := pixel_table(palette, -1, true)
	var n := indices.size()
	var out := PackedInt32Array()
	out.resize(n)
	for i in n:
		out[i] = through[indices[i]] if clear[i] == 1 else opaque[indices[i]]
	return out.to_byte_array()


## A Windows bitmap as the 1997 wizards' window read it: `{error, width,
## height, pixels}`, RGBA rows top to bottom, all opaque. Only 24 bits a
## pixel, not packed, with a 40-byte header or larger.
static func read_bmp(data: PackedByteArray) -> Dictionary:
	var size := data.size()
	if size < 54 or data[0] != 0x42 or data[1] != 0x4D:
		return _fail("it is not a Windows bitmap")
	var offset := data.decode_u32(10)
	if data.decode_u32(14) < 40:
		return _fail("it is a bitmap of a kind the 1997 game did not use")
	var width := data.decode_s32(18)
	var height := data.decode_s32(22)
	if data.decode_u16(28) != 24 or data.decode_u32(30) != 0:
		return _fail("it is not a plain 24-bit bitmap")
	var top_down := height < 0
	height = absi(height)
	if width <= 0 or height == 0 or width > MAX_SIDE or height > MAX_SIDE \
			or width * height > MAX_PIXELS:
		return _fail("it claims a picture of %d x %d" % [width, height])
	var stride := (width * 3 + 3) & ~3
	if offset + stride * height > size:
		return _fail("it is cut short")
	var out := PackedInt32Array()
	out.resize(width * height)
	var at := 0
	for y in height:
		var p := offset + stride * (y if top_down else height - 1 - y)
		for x in width:
			out[at] = (data[p + 2] | (data[p + 1] << 8) | (data[p] << 16)) - 0x1000000
			at += 1
			p += 3
	return {"error": "", "width": width, "height": height, "pixels": out.to_byte_array()}


## Every pixel of exactly the colour [param rgb] (three numbers) made
## clear, its colour kept: what the wizards' window skipped as it drew.
static func clear_colour(pixels: PackedByteArray, rgb: Array) -> PackedByteArray:
	var words := pixels.to_int32_array()
	var key := int(rgb[0]) | (int(rgb[1]) << 8) | (int(rgb[2]) << 16)
	var opaque := key - 0x1000000
	var at := words.find(opaque)
	while at >= 0:
		words[at] = key
		at = words.find(opaque, at + 1)
	return words.to_byte_array()
