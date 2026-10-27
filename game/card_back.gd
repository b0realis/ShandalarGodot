class_name CardBack
extends RefCounted
## YOUR OWN CARD BACK — `[QoL]`. The owner, 2026-10-19: *"lets implement
## also an option in settings so user can use his own photo as card back
## (lets also document and tell the user what format and pixel*pixel the
## game expects the file to be!)"*.
##
## ONE PICTURE, `card_back.png` in the game's own folder ([method file],
## [method GamePaths.card_back]), and every card back in the game wears
## it — the library, a face-down card, the hidden hand of a hot-seat
## duel, the big card's empty slot — over the skin's back or the plain
## one ([method GameSkin.texture]).
##
## WHAT THE GAME EXPECTS: a PNG, JPG or WEBP, upright, the shape of a
## card. [constant SIZE] — 456x646, twice the 1997 back's 228x323 and the
## 2x skin's own — is what is kept and drawn; a bigger picture is shrunk
## to it and a smaller one stretched up (and softens). A picture of
## another shape is trimmed from the middle to a card's shape, never
## squeezed: a landscape photo loses its sides, a tall one its top and
## bottom ([method trim_rect]). Options → Card back says so under the
## row, and `docs/player-files.md` and `docs/setup.txt` say it again.
##
## CHOOSING COPIES. `Choose...` ([method adopt]) reads the picture
## wherever it is, turns it the way the camera held it (a phone stores a
## photo's pixels sideways and says so in its EXIF orientation, which
## Godot's loader does not read — [method exif_orientation]), fits it
## ([method fitted]) and saves the result as a PNG at [method file]. The
## picture itself is not touched and may move or go. `Remove`
## ([method forget]) deletes the game's copy and nothing else.
##
## A PICTURE PUT THERE BY HAND is worn too, fitted the same way as it is
## read: `card_back.png`, else `card_back.jpg`, `.jpeg` or `.webp`
## ([method candidates]) — and the bytes, not the name, say which kind it
## is. On Android that is the app's files folder, which `adb push` reaches
## ([method GamePaths.player_place]).
##
## READ ONCE A RUN ([method texture]): a card back is asked for by every
## face-down card, and a look at the disk each time would be waste.
## Choosing or removing one drops the cache; a file changed by hand is
## worn from the next start, like every other place.

## The picture kept and drawn: twice the 1997 back
## ([constant GameSkin.SIZES]), so it is a 2x picture of its slot.
const SIZE := Vector2i(456, 646)
## What counts as a card back picture, in the order a name is looked for.
const EXTENSIONS: Array[String] = ["png", "jpg", "jpeg", "webp"]
## A picture within this fraction of a card's shape is used whole and
## stretched the hair it is off — a scan of a real card back (63x88 mm)
## keeps its border — rather than trimmed.
const SHAPE_SLACK := 0.02
## The largest file read. A phone's photo is a few MB; this is far past
## any picture and short of what would stall the game reading it.
const MAX_BYTES := 64 * 1024 * 1024

## Why a file was not taken, word for word as the Options row shows it.
const NOT_A_PICTURE := "That is not a PNG, JPG or WEBP picture. (An iPhone's HEIC photo can be saved as a JPG first.)"
const TOO_BIG := "That file is over 64 MB; a picture of 456 x 646 pixels is all a card back needs."
const NOT_SAVED := "The picture could not be saved in the game's folder."
const NOT_READ := "That file could not be read."

## The page's own file box, for the browser build: an `<input type=file>`
## that only a script on the page may open, inside the press that asked
## for it — [method SkinPack.pick]'s way, for a picture. What the player
## chooses waits in `window.shandalarBack` for [method web_poll]. Run
## again while a box is still waiting (the bug campaign c12, h6-5), it
## takes the earlier input off the page first and hears only the newest.
const CHOOSE_JS := """
(function () {
	var stale = window.shandalarBackInput;
	if (stale && stale.parentNode) { stale.parentNode.removeChild(stale); }
	window.shandalarBack = {state: "open"};
	var input = document.createElement("input");
	window.shandalarBackInput = input;
	input.type = "file";
	input.accept = ".png,.jpg,.jpeg,.webp,image/png,image/jpeg,image/webp";
	input.style.display = "none";
	document.body.appendChild(input);
	var done = function (result) {
		if (window.shandalarBackInput !== input) { return; }
		window.shandalarBackInput = null;
		window.shandalarBack = result;
		if (input.parentNode) { input.parentNode.removeChild(input); }
	};
	input.addEventListener("change", function () {
		var file = input.files && input.files[0];
		if (!file) { done({state: "cancelled"}); return; }
		var reader = new FileReader();
		reader.onload = function () {
			done({state: "ready", name: file.name, data: new Uint8Array(reader.result)});
		};
		reader.onerror = function () { done({state: "failed"}); };
		reader.readAsArrayBuffer(file);
	});
	input.addEventListener("cancel", function () { done({state: "cancelled"}); });
	input.click();
})();
"""

## Where the picture is kept; "" for the game's own place. The tests
## point it at a scratch folder.
static var place := ""
## Whether [member _texture] has been read this run.
static var _known := false
static var _texture: Texture2D = null
## Why the browser's last pick was not taken, or "".
static var web_refusal := ""


## The file `Choose...` writes.
static func file() -> String:
	return place if place != "" else GamePaths.card_back()


## The names a picture is looked for under, in order.
static func candidates() -> Array[String]:
	var stem := file().get_basename()
	var out: Array[String] = []
	for ext in EXTENSIONS:
		out.append("%s.%s" % [stem, ext])
	return out


## The player's picture, or "" when there is none.
static func found() -> String:
	for path in candidates():
		if FileAccess.file_exists(path):
			return path
	return ""


static func has_own() -> bool:
	return found() != ""


## The player's card back, or null — read and fitted once a run.
static func texture() -> Texture2D:
	if not _known:
		_known = true
		_texture = null
		var path := found()
		if path != "":
			var img := read(path)
			if img != null:
				_texture = GameSkin.texture_of(img, GameSkin.SIZES["card_back"])
	return _texture


## Read again at the next ask.
static func forget_cache() -> void:
	_known = false
	_texture = null


## The picture at [param path], turned upright and fitted, or null.
static func read(path: String) -> Image:
	if _size_of(path) > MAX_BYTES:
		return null
	var bytes := _bytes_of(path)
	var img := image_from_bytes(bytes)
	if img == null:
		return null
	return fitted(oriented(img, exif_orientation(bytes)))


## Options → Card back → `Choose...`: [param path] becomes the card
## back. "" when it did, else why not.
static func adopt(path: String) -> String:
	if not FileAccess.file_exists(path):
		return NOT_READ
	var size := _size_of(path)
	if size > MAX_BYTES:
		return TOO_BIG
	var bytes := _bytes_of(path)
	if bytes.is_empty():
		return NOT_READ
	return adopt_bytes(bytes)


## [method adopt] for a picture already read — the browser's.
static func adopt_bytes(bytes: PackedByteArray) -> String:
	if bytes.size() > MAX_BYTES:
		return TOO_BIG
	var img := image_from_bytes(bytes)
	if img == null:
		return NOT_A_PICTURE
	img = fitted(oriented(img, exif_orientation(bytes)))
	var target := file()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target.get_base_dir()))
	# Whole or not at all (review of 2026-10-21, nettools-6): `save_png`
	# truncated the worn back in place, so a full disk or a crash part way
	# left no back at all. A pending file, checked, then renamed over it.
	var png := img.save_png_to_buffer()
	if png.is_empty() or Settings.write_atomically(target, png) != OK:
		return NOT_SAVED
	forget_cache()
	return ""


## Options → Card back → `Remove`: the game's copy goes — every name
## [method candidates] reads, so a picture put there by hand does not
## come back in its place. The picture it was made from is not touched.
static func forget() -> void:
	for path in candidates():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	forget_cache()


## "png", "jpg" or "webp" by what the bytes begin with, or "".
static func kind_of(bytes: PackedByteArray) -> String:
	if bytes.size() >= 8 and bytes[0] == 0x89 and bytes[1] == 0x50 \
			and bytes[2] == 0x4E and bytes[3] == 0x47:
		return "png"
	if bytes.size() >= 3 and bytes[0] == 0xFF and bytes[1] == 0xD8 and bytes[2] == 0xFF:
		return "jpg"
	if bytes.size() >= 12 and bytes.slice(0, 4).get_string_from_ascii() == "RIFF" \
			and bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
		return "webp"
	return ""


## The picture in [param bytes], or null when they are not one of the
## three kinds. The kind is checked FIRST: Godot's own loaders print an
## error for bytes they cannot read, and a stray file of another kind
## is a refusal here, not an error.
static func image_from_bytes(bytes: PackedByteArray) -> Image:
	var kind := kind_of(bytes)
	if kind == "":
		return null
	var img := Image.new()
	var err := OK
	match kind:
		"png":
			err = img.load_png_from_buffer(bytes)
		"jpg":
			err = img.load_jpg_from_buffer(bytes)
		_:
			err = img.load_webp_from_buffer(bytes)
	if err != OK or img.is_empty():
		return null
	return img


## THE CAMERA'S WAY UP. A phone stores a photo as its sensor saw it and
## writes how to turn it into the EXIF block — tag 0x0112, Orientation,
## 1 to 8 — and Godot's JPEG loader shows the pixels as stored: an
## upright portrait taken on a phone lands on its side. This reads the
## tag out of the JPEG's APP1 segment (EXIF 2.3, a TIFF header and its
## first directory), and is 1, "as stored", for anything else.
static func exif_orientation(bytes: PackedByteArray) -> int:
	if kind_of(bytes) != "jpg":
		return 1
	var at := 2
	while at + 4 <= bytes.size() and bytes[at] == 0xFF:
		var marker := bytes[at + 1]
		if marker == 0xFF:
			at += 1   # a fill byte before the marker
			continue
		if marker == 0x01 or (marker >= 0xD0 and marker <= 0xD8):
			at += 2   # a marker with no length
			continue
		if marker == 0xDA or marker == 0xD9:
			return 1   # the picture's data begins; no EXIF came before it
		var length := (bytes[at + 2] << 8) | bytes[at + 3]
		if length < 2:
			return 1
		if marker == 0xE1:
			var found_orientation := _exif_in(bytes, at + 4, at + 2 + length)
			if found_orientation != 0:
				return found_orientation
		at += 2 + length
	return 1


## The Orientation in one APP1 segment's body, [param start] to
## [param stop], or 0 when it is not EXIF or says none.
static func _exif_in(bytes: PackedByteArray, start: int, stop: int) -> int:
	stop = mini(stop, bytes.size())
	if start + 14 > stop:
		return 0
	# "Exif\0\0"
	if bytes[start] != 0x45 or bytes[start + 1] != 0x78 or bytes[start + 2] != 0x69 \
			or bytes[start + 3] != 0x66 or bytes[start + 4] != 0 or bytes[start + 5] != 0:
		return 0
	var tiff := start + 6
	var little := false
	if bytes[tiff] == 0x49 and bytes[tiff + 1] == 0x49:
		little = true
	elif bytes[tiff] != 0x4D or bytes[tiff + 1] != 0x4D:
		return 0
	var ifd := tiff + _u32(bytes, tiff + 4, little)
	if ifd + 2 > stop:
		return 0
	for i in _u16(bytes, ifd, little):
		var entry := ifd + 2 + i * 12
		if entry + 12 > stop:
			return 0
		if _u16(bytes, entry, little) == 0x0112:
			var value := _u16(bytes, entry + 8, little)
			return value if value >= 1 and value <= 8 else 0
	return 0


static func _u16(bytes: PackedByteArray, at: int, little: bool) -> int:
	if little:
		return bytes[at] | (bytes[at + 1] << 8)
	return (bytes[at] << 8) | bytes[at + 1]


static func _u32(bytes: PackedByteArray, at: int, little: bool) -> int:
	if little:
		return _u16(bytes, at, true) | (_u16(bytes, at + 2, true) << 16)
	return (_u16(bytes, at, false) << 16) | _u16(bytes, at + 2, false)


## [param img] turned the way EXIF [param orientation] says it was held
## — the eight cases as the EXIF standard draws them. Changes and
## returns [param img].
static func oriented(img: Image, orientation: int) -> Image:
	match orientation:
		2:
			img.flip_x()
		3:
			img.rotate_180()
		4:
			img.flip_y()
		5:
			img.rotate_90(CLOCKWISE)
			img.flip_x()
		6:
			img.rotate_90(CLOCKWISE)
		7:
			img.rotate_90(CLOCKWISE)
			img.flip_y()
		8:
			img.rotate_90(COUNTERCLOCKWISE)
	return img


## [param source] as a card back: the middle of it in a card's shape
## ([method trim_rect]), at [constant SIZE]. Halved while it is twice the
## size or more (`shrink_x2` averages exactly), then Lanczos for the rest.
static func fitted(source: Image) -> Image:
	var img := source.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var cut := trim_rect(img.get_size())
	if cut.size != img.get_size():
		img = img.get_region(cut)
	while img.get_width() >= SIZE.x * 2 and img.get_height() >= SIZE.y * 2:
		img.shrink_x2()
	if img.get_size() != SIZE:
		img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
	return img


## The part of a [param size] picture a card back keeps: all of it within
## [constant SHAPE_SLACK] of a card's shape, else the middle in that shape.
static func trim_rect(size: Vector2i) -> Rect2i:
	var whole := Rect2i(Vector2i.ZERO, size)
	if size.x <= 0 or size.y <= 0:
		return whole
	var card := float(SIZE.x) / SIZE.y
	var shape := float(size.x) / size.y
	if absf(shape / card - 1.0) <= SHAPE_SLACK:
		return whole
	if shape > card:   # wider than a card: the sides go
		var w := clampi(roundi(size.y * card), 1, size.x)
		return Rect2i((size.x - w) / 2, 0, w, size.y)
	var h := clampi(roundi(size.x / card), 1, size.y)
	return Rect2i(0, (size.y - h) / 2, size.x, h)


## The browser's file box ([const CHOOSE_JS]); [method web_poll] then
## says when the player is done with it. Opened again over one still
## waiting, it replaces it (h6-5; the Options screen's `_choose_card_back`).
static func web_open() -> void:
	web_refusal = ""
	_page(CHOOSE_JS)


## Where the browser's box stands: "open", "ready", "cancelled",
## "failed", or "gone" when there is none.
static func web_state() -> String:
	return String(_page("window.shandalarBack ? window.shandalarBack.state : 'gone'"))


## One look at the browser's file box: false while it is open; true once
## it is over — the picture taken, or [member web_refusal] saying why not
## ("" for a box closed with nothing chosen).
static func web_poll() -> bool:
	var state := web_state()
	if state == "open":
		return false
	if state == "ready":
		var length := int(_page("window.shandalarBack.data.length"))
		if length > MAX_BYTES:
			web_refusal = TOO_BIG
		else:
			var data: Variant = _page("window.shandalarBack.data")
			web_refusal = adopt_bytes(data) if data is PackedByteArray else NOT_READ
	elif state == "failed":
		web_refusal = NOT_READ
	_page("window.shandalarBack = null")
	return true


## A stand-in for the page, `(script) -> Variant`: a test's, since no
## browser runs in one (h6-5). Not set, the page itself is asked.
static var page := Callable()


static func _page(script: String) -> Variant:
	if page.is_valid():
		return page.call(script)
	return JavaScriptBridge.eval(script, true)


static func _size_of(path: String) -> int:
	var handle := FileAccess.open(path, FileAccess.READ)
	if handle == null:
		return 0
	var size := handle.get_length()
	handle.close()
	return size


static func _bytes_of(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(path)
