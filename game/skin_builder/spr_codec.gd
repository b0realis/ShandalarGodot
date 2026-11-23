class_name SkinSprCodec
extends RefCounted
## THE 1997 GAME'S SPRITE FORMAT (`.spr`), DECODED — the port of
## `decode_spr`, `spr_frame_tops` and the sheet tiler `_raw_spr_sheet` of
## `tools/import_original.py`, which holds the reasons (a frame may end
## in the middle of a row; a frame wider than its cell is cut to it, not
## smeared over the next).
##
## A file is a run of frames. Each: a 16-byte header — its length in bytes
## with the header (a length of 0xFFFFFFFF ends the file), width, height,
## two numbers of which the second is the frame's anchor ([method
## frame_tops]), the count of clear rows at the top, one more — then a run
## a row: 0xFF bytes to skip, how many clear pixels lead the row, how many
## pixels follow (0xFE or 0xFF: the count is the next byte), and those
## pixels as palette indices. Index 0 is clear, and so is everything a row
## does not reach.
##
## UNTRUSTED, like every file the builder reads ([SkinPicCodec]): a bad
## length, a run past its row, a frame of an absurd size all come back as
## `error` in the player's words. A file may hold at most [constant
## MAX_FRAMES] frames of [constant MAX_PIXELS] pixels together — the
## Python tool sets no such bound, and no 1997 file is near it. Pure
## functions on private data: any thread may call them.

const MAX_SIDE := 4096
const MAX_FRAMES := 4096
## The most pixels all the frames of one file may hold together (the
## largest 1997 sheet holds 665,280).
const MAX_PIXELS := 1 << 25
const END := 0xFFFFFFFF


## Every frame of a `.spr`: `{error, frames}`, each frame `[width, height,
## indices]`.
static func decode(data: PackedByteArray) -> Dictionary:
	var frames: Array = []
	var offset := 0
	var total := data.size()
	var budget := MAX_PIXELS
	while offset + 4 <= total:
		var size := data.decode_u32(offset)
		if size == END:
			break
		if size < 16 or offset + size > total:
			return {"error": "frame %d has a wrong length" % frames.size(), "frames": []}
		var width := data.decode_u16(offset + 4)
		var height := data.decode_u16(offset + 6)
		var empty_lines := data.decode_u16(offset + 12)
		if width <= 0 or width > MAX_SIDE or height <= 0 or height > MAX_SIDE \
				or empty_lines > height:
			return {"error": "frame %d claims %d x %d" % [frames.size(), width, height],
				"frames": []}
		budget -= width * height
		if budget < 0 or frames.size() >= MAX_FRAMES:
			return {"error": "it holds more frames than any 1997 sprite", "frames": []}
		var end := offset + size
		var pixels := SkinPicCodec.zeros(width * empty_lines)
		var blank := SkinPicCodec.zeros(width)
		var pos := offset + 16
		for _row in range(empty_lines, height):
			while pos < end and data[pos] == 0xFF:
				pos += 1
			if pos + 1 >= end:
				break
			var transparent := data[pos]
			var control := data[pos + 1]
			var count := control
			pos += 2
			if control == 0xFE or control == 0xFF:
				if pos >= end:
					break
				count = data[pos]
				pos += 1
			# The frame can end here, in the middle of a row.
			if pos >= end:
				break
			if transparent + count > width:
				return {"error": "frame %d has a row wider than itself" % frames.size(),
					"frames": []}
			if transparent > 0:
				pixels.append_array(blank.slice(0, transparent))
			pixels.append_array(data.slice(pos, pos + count))
			if width - transparent - count > 0:
				pixels.append_array(blank.slice(0, width - transparent - count))
			pos += count
		var wanted := width * height
		if pixels.size() < wanted:
			pixels.append_array(SkinPicCodec.zeros(wanted - pixels.size()))
		elif pixels.size() > wanted:
			pixels.resize(wanted)
		frames.append([width, height, pixels])
		offset = end
	if frames.is_empty():
		return {"error": "it holds no frames", "frames": []}
	return {"error": "", "frames": frames}


## Every frame's anchor — the height above a sprite's foot at which the
## 1997 world draws it; -1 where the frame has none.
static func frame_tops(data: PackedByteArray) -> Array[int]:
	var tops: Array[int] = []
	var offset := 0
	var total := data.size()
	while offset + 12 <= total and tops.size() < MAX_FRAMES:
		var size := data.decode_u32(offset)
		if size == END or size < 12:
			break
		tops.append(data.decode_s16(offset + 10))
		offset += size
	return tops


## The first [param cells] of [param frames] laid on a grid of [param
## columns] cells of [param cell_w] x [param cell_h], each at its cell's
## top left and cut to it: `{width, height, indices, sizes}` — `sizes` each
## laid frame's own `[width, height]`.
static func sheet(frames: Array, cells: int, cell_w: int, cell_h: int, columns: int) -> Dictionary:
	columns = maxi(columns, 1)
	@warning_ignore("integer_division")
	var rows := (cells + columns - 1) / columns
	var width := cell_w * columns
	var height := cell_h * rows
	var used := mini(frames.size(), cells)
	var blank := SkinPicCodec.zeros(cell_w)
	var indices := PackedByteArray()
	for row in rows:
		for y in cell_h:
			for column in columns:
				var slot := row * columns + column
				if slot >= used:
					indices.append_array(blank)
					continue
				var frame: Array = frames[slot]
				var frame_w: int = frame[0]
				if y >= int(frame[1]):
					indices.append_array(blank)
					continue
				var take := mini(frame_w, cell_w)
				var pixels: PackedByteArray = frame[2]
				indices.append_array(pixels.slice(y * frame_w, y * frame_w + take))
				if take < cell_w:
					indices.append_array(blank.slice(0, cell_w - take))
	var sizes: Array = []
	for slot in used:
		sizes.append([int(frames[slot][0]), int(frames[slot][1])])
	return {"width": width, "height": height, "indices": indices, "sizes": sizes}
